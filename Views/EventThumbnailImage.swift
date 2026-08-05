//
//  EventThumbnailImage.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import NukeUI

// ★ イベント画像の解決ロジック（予定に登録された画像URLがあればそれを使う）。
//   ビュー側でサイズやフォールバック先が異なるため、URL解決だけを共通化する。
enum EventImageResolver {
    static func resolvedURL(for event: Event) -> URL? {
        if let thumb = event.thumbnailURL, let url = URL(string: thumb) { return url }
        if let first = event.imageURLs?.first, let url = URL(string: first) { return url }
        return nil
    }

    // ★ 予定に画像URLが登録されていない場合（AIで追加した予定など）、
    //   公式サイトのURLから og:image / twitter:image をスクレイピングして拾ってくる。
    //   DayEventListViewではこのフォールバックで画像が表示できていたのに、
    //   他の画面（イベント当日ハブ・イベント詳細）では直接フィールドしか見ておらず
    //   強制的にグループアイコンへ落ちてしまっていたのを解消する
    static func resolveImageURL(for event: Event) async -> URL? {
        if let direct = resolvedURL(for: event) { return direct }
        guard let officialURL = event.officialURL, !officialURL.isEmpty else { return nil }

        return await withCheckedContinuation { continuation in
            EventImageFetcher.fetchImageURL(from: officialURL) { url in
                continuation.resume(returning: url)
            }
        }
    }
}

// ★ イベントのサムネイル画像。予定情報に画像がなければ、そのイベントが属する
//   グループ設定で登録されているアイコン画像にフォールバックする。それもなければ
//   アクセントカラーのグラデーションを表示する。
struct EventThumbnailImage: View {
    let event: Event
    let group: IdolGroup?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 16

    // ★ 予定に画像URLが直接登録されていない場合、公式URLから拾ってきた画像
    @State private var scrapedURL: URL?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var resolvedURL: URL? {
        EventImageResolver.resolvedURL(for: event) ?? scrapedURL
    }

    var body: some View {
        Group {
            if let url = resolvedURL {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: event.id) {
            guard EventImageResolver.resolvedURL(for: event) == nil else { return }
            scrapedURL = await EventImageResolver.resolveImageURL(for: event)
        }
    }

    @ViewBuilder
    private var fallback: some View {
        if let data = group?.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [accentColor.opacity(0.85), accentColor2.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: "sparkles")
                    .font(.system(size: min(width, height) * 0.24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: width, height: height)
        }
    }
}
