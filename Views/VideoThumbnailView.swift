//
//  VideoThumbnailView.swift
//  OshiNium7
//

import SwiftUI
import AVFoundation

// ★ 動画投稿のサムネイル抽出結果を1度だけ生成してURLごとに使い回すためのキャッシュ。
//   NSCacheはメモリ逼迫時に自動で古いものから解放されるため、明示的な上限管理は不要
final class VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() {}

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
}

// ★ 動画投稿は再生前、以前はColor.black.opacity(0.85)の単なる黒塗りだけで、
//   ホームのタイムライン(PostFeedCard)・マイページ/プロフィールの投稿グリッド
//   (MyPageTab/UserProfileView)のどこでも「真っ黒なカード」にしか見えなかった。
//   AVAssetImageGeneratorで動画の先頭付近のフレームを1枚だけ非同期に抽出し、
//   実際のサムネイルとして背景に敷く。抽出できるまで／失敗した場合は
//   従来通りColor.black.opacity(0.85)にフォールバックする（呼び出し側の見た目を崩さない）
struct VideoThumbnailView: View {
    let url: URL

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black.opacity(0.85)
            }
        }
        .task(id: url) {
            await loadThumbnailIfNeeded()
        }
    }

    @MainActor
    private func loadThumbnailIfNeeded() async {
        if let cached = VideoThumbnailCache.shared.image(for: url) {
            thumbnail = cached
            return
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)

        do {
            let result = try await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600))
            let image = UIImage(cgImage: result.image)
            VideoThumbnailCache.shared.store(image, for: url)
            thumbnail = image
        } catch {
            // ★ 抽出失敗時はthumbnailがnilのままなのでbody側のフォールバック(黒塗り)が出る
        }
    }
}
