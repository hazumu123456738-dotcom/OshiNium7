//
//  ChatComponents.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI
import PhotosUI

// ★ ChatRoomView・DirectMessageThreadView・OpenChatRoomView・AnonymousChatRoomViewの
//   4画面でそれぞれ個別にコピーされていた見た目・入力バーをここに集約する。
//   4画面は「誰がメンバーか」「モデレーション権限」「既読/1通制限」など業務ロジックの部分は
//   はっきり異なる（特に匿名版は発言者情報を一切見せない設計）ため、画面そのものを
//   1つに統合するのではなく、純粋に見た目だけの部品（吹き出しの色・リアクション・入力バー）
//   だけをここに切り出している

// MARK: - 吹き出しの背景（送信者本人なら指定のグラデーション、相手ならグレー）

func chatBubbleBackground(isMine: Bool, primary: Color, primary2: Color) -> AnyShapeStyle {
    if isMine {
        return AnyShapeStyle(
            LinearGradient(colors: [primary, primary2], startPoint: .leading, endPoint: .trailing)
        )
    } else {
        return AnyShapeStyle(Color(.systemGray5))
    }
}

// MARK: - Instagram DM風のダブルタップ・ハートリアクション

struct ChatReactionBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(Color(red: 0.95, green: 0.35, blue: 0.55))
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        )
        .offset(y: 10)
    }
}

// MARK: - テキストのみの入力バー（公開/匿名トークルーム用。画像・動画添付は無い）

struct ChatTextOnlyInputBar: View {
    @Binding var inputText: String
    let placeholder: String
    let accentColor: Color
    let onSend: () -> Void

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $inputText, axis: .vertical)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...4)

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(canSend ? accentColor : Color.gray.opacity(0.4))
            }
            .disabled(!canSend)
            .accessibilityLabel("送信")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.appCardBackground
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3)
        )
    }
}

// MARK: - 画像・動画添付できる入力バー（グループチャット・DM用）

struct ChatMediaInputBar: View {
    @Binding var inputText: String
    @Binding var selectedMedia: [SelectedChatMedia]
    @Binding var isSending: Bool
    let accentColor: Color
    let placeholder: String
    let onSend: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingMedia = false
    @State private var mediaErrorMessage: String?

    // ★ chatMediaのStorageルールと同じ上限（25MB）に合わせている
    private let maxVideoBytes = 25 * 1024 * 1024

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedMedia.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if let mediaErrorMessage {
                Text(mediaErrorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
            }

            if !selectedMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedMedia.enumerated()), id: \.offset) { index, media in
                            ZStack(alignment: .topTrailing) {
                                mediaThumbnail(media)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Button {
                                    selectedMedia.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 6, y: -6)
                                .accessibilityLabel("このメディアを削除")
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                    if isLoadingMedia {
                        ProgressView().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20))
                            .foregroundColor(accentColor)
                    }
                }
                .accessibilityLabel("画像・動画を選択（複数可）")
                .disabled(isSending || isLoadingMedia)

                TextField(placeholder, text: $inputText, axis: .vertical)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .lineLimit(1...4)

                Button {
                    onSend()
                } label: {
                    if isSending {
                        ProgressView().frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(canSend ? accentColor : Color.gray.opacity(0.4))
                    }
                }
                .disabled(!canSend || isSending)
                .accessibilityLabel("送信")
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
        .background(
            Color.appCardBackground
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3)
        )
        .onChange(of: pickerItems) { newItems in
            guard !newItems.isEmpty else { return }
            mediaErrorMessage = nil
            isLoadingMedia = true
            Task {
                var media: [SelectedChatMedia] = []
                for item in newItems {
                    let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                    if isVideo {
                        if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                            let attributes = try? FileManager.default.attributesOfItem(atPath: movie.url.path)
                            let size = attributes?[.size] as? Int
                            if let size, size > maxVideoBytes {
                                await MainActor.run {
                                    mediaErrorMessage = "動画のサイズが大きすぎます（25MBまで）"
                                }
                            } else {
                                media.append(.video(movie.url))
                            }
                        }
                    } else if let data = try? await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) {
                        media.append(.image(image))
                    }
                }
                await MainActor.run {
                    selectedMedia = media
                    isLoadingMedia = false
                    // ★ 送信後にselectedMediaが親側で空にされてもpickerItemsは
                    //   残ったままだと同じ写真を選び直せなくなるため、変換完了のたびにクリアする
                    pickerItems = []
                }
            }
        }
    }

    @ViewBuilder
    private func mediaThumbnail(_ media: SelectedChatMedia) -> some View {
        switch media {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .video:
            ZStack {
                Color.black.opacity(0.85)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}
