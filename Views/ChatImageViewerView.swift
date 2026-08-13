//
//  ChatImageViewerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI
import NukeUI
import AVKit

// ★ .fullScreenCover(item:)にURLをそのまま渡せるようにするための薄いラッパー
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// ★ 複数枚まとめ送信された画像を、まとめてスワイプで見られる全画面ギャラリーに
//   渡すためのコンテキスト。.fullScreenCover(item:)用
struct ChatImageGalleryContext: Identifiable {
    let id = UUID()
    let urls: [URL]
    let initialIndex: Int
}

// ★ チャット（グループ／DM）の動画付きメッセージ用バブル。PostFeedCardの動画表示と同じく
//   最初は再生アイコン付きのプレースホルダーを見せ、タップで初めてAVPlayerを生成して再生する
//   （一覧内で多数のAVPlayerを同時生成しないための遅延生成方式）。
//   ダブルタップのハートリアクションは呼び出し側からonDoubleTapで受け取り、
//   単一タップ（再生開始）と同じビューに両方のタップジェスチャーを付けることで、
//   SwiftUI標準の「回数の多い方から順に判定される」仕組みで衝突を防ぐ
struct ChatVideoBubble: View {
    let videoURL: URL
    var onDoubleTap: () -> Void = {}

    @State private var isPlaying = false

    var body: some View {
        Group {
            if isPlaying {
                VideoPlayer(player: AVPlayer(url: videoURL))
            } else {
                ZStack {
                    VideoThumbnailView(url: videoURL)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                }
                .contentShape(Rectangle())
            }
        }
        .frame(width: 220, height: 280)
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture(count: 1) {
            if !isPlaying { isPlaying = true }
        }
        .accessibilityLabel(isPlaying ? "動画再生中" : "動画を再生")
        .accessibilityAddTraits(.isButton)
    }
}

// ★ ピンチ拡大・ダブルタップ拡大縮小・ドラッグ移動ができる画像1枚分の表示。
//   チャットの単体表示（ChatImageViewerView）・ギャラリー表示（ChatImageGalleryView）に加え、
//   投稿の全画面表示（PostImageFullScreenView）からも再利用するためinternalにしてある。
//   ★ 以前はMagnificationGestureのみでscaleEffectにanchorを渡していなかったため、
//   常に画像中央基準で拡大され、右上をピンチしても中央が拡大されてしまっていた。
//   iOS17のMagnifyGestureが返すstartAnchor（ピンチ開始位置の相対座標）をそのままanchorに渡し、
//   実際につまんだ位置を中心に拡大されるようにする（PostFeedCardの投稿インライン画像と同じ修正）
struct ZoomableChatImage: View {
    let imageURL: URL

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var zoomAnchor: UnitPoint = .center

    var body: some View {
        LazyImage(url: imageURL) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView().tint(.white)
            }
        }
        .scaleEffect(scale, anchor: zoomAnchor)
        .offset(offset)
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    zoomAnchor = value.startAnchor
                    scale = max(1, min(lastScale * value.magnification, 5))
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale <= 1 {
                        withAnimation { offset = .zero }
                        lastOffset = .zero
                    }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard scale > 1 else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if scale > 1 {
                    scale = 1
                    lastScale = 1
                    offset = .zero
                    lastOffset = .zero
                    zoomAnchor = .center
                } else {
                    scale = 2.5
                    lastScale = 2.5
                }
            }
        }
    }
}

// ★ 動画をタップした時の全画面表示（YouTubeの全画面表示に近い、黒背景いっぱいに動画を敷いた見せ方）。
//   投稿の動画（単体・複数枚投稿の両方）から開く。閉じるボタンのほかは、AVKit標準の
//   再生コントロール（再生/一時停止・シークバー）をそのまま使う
struct PostVideoFullScreenView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(videoURL: URL) {
        self.videoURL = videoURL
        _player = State(initialValue: AVPlayer(url: videoURL))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear { player.play() }
                .onDisappear { player.pause() }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .accessibilityLabel("閉じる")
                    .padding(.leading, 16)
                    .padding(.top, 8)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// ★ チャット（グループ／DM）で画像をタップした時の全画面表示。黒背景に画像全体を
//   見切れなく表示し、ピンチで拡大・ダブルタップで拡大縮小・ドラッグで移動できる
//   （Instagram DM等の画像プレビューと同じ操作感）
struct ChatImageViewerView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZoomableChatImage(imageURL: imageURL)

            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                Spacer()
            }
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(10)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .accessibilityLabel("閉じる")
        .padding(.leading, 16)
        .padding(.top, 8)
    }
}

// ★ 複数枚まとめて送信された画像を、横スワイプで1枚ずつ全画面表示するギャラリー。
//   チャット一覧側で「重なった写真束」としてまとめて表示されたメッセージをタップした時に開く
struct ChatImageGalleryView: View {
    let imageURLs: [URL]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int

    init(imageURLs: [URL], initialIndex: Int = 0) {
        self.imageURLs = imageURLs
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    ZoomableChatImage(imageURL: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .accessibilityLabel("閉じる")
                    .padding(.leading, 16)

                    Spacer()

                    Text("\(currentIndex + 1) / \(imageURLs.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .padding(.trailing, 16)
                        .accessibilityLabel("\(imageURLs.count)枚中\(currentIndex + 1)枚目")
                }
                .padding(.top, 8)
                Spacer()
            }
        }
    }
}
