//
//  PostComposerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import PhotosUI
import AVKit
import FirebaseAuth
import UniformTypeIdentifiers

// ★ PhotosPickerItemから動画をローカルURLとして受け取るためのTransferableラッパー
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            if FileManager.default.fileExists(atPath: copy.path) {
                try? FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// ★ アプリ内の「投稿」を作るための唯一の画面。推し活タイムラインへの通常投稿も、
//   「推し活ペンライト・グッズ」ツールへの投稿も、この1つの画面から同じPostとして作られる
//   （別のコレクション・別の専用フォームは持たない）。種類を「通常／ペンライト／グッズ」から
//   選ぶだけで、あとの入力項目・見た目はすべて共通にすることで、どこから投稿を始めても
//   迷わない・洗練された1つの体験にする
struct PostComposerView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.dismiss) private var dismiss

    // ★ ホームで選択中のグループがあれば、投稿先の初期値としてそれを使う
    var defaultGroupId: String? = nil
    // ★ 「推し活ペンライト・グッズ」ツールの「投稿する」から開いた場合、
    //   最初から種類をペンライト・グッズ寄りに合わせておく
    var initialKind: PostKind = .normal

    @State private var kind: PostKind
    @State private var goodsTitle: String = ""
    @State private var selectedGroupId: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var caption: String = ""
    @State private var isLoadingMedia = false
    // ★ 写真を選んだ直後にInstagramのように切り取り・位置調整できるようにする
    @State private var imagePendingCrop: UIImage?
    @State private var showCropView = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var isCaptionFocused: Bool
    @FocusState private var isTitleFocused: Bool

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2
    private let maxVideoBytes = 50 * 1024 * 1024

    enum PostKind: String, CaseIterable, Identifiable {
        case normal = "通常の投稿"
        case penlight = "ペンライト"
        case goods = "グッズ"

        var id: String { rawValue }
        var goodsValue: String? { self == .normal ? nil : rawValue }
        var icon: String {
            switch self {
            case .normal: return "text.bubble.fill"
            case .penlight: return "flashlight.on.fill"
            case .goods: return "gift.fill"
            }
        }
    }

    init(defaultGroupId: String? = nil, initialKind: PostKind = .normal) {
        self.defaultGroupId = defaultGroupId
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }

    // ★ Instagramの新規投稿画面と同じ「画像→キャプション→その他オプション→共有」という
    //   縦の流れに揃える。画像だけは左右のマージンを持たず画面幅いっぱい（edge-to-edge）にし、
    //   それ以外のブロックは通常のマージンを持つカードとして下に積む
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mediaSection

                VStack(alignment: .leading, spacing: 16) {
                    captionField

                    optionsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    postButton
                }
                .padding(16)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("投稿を作成")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") { dismiss() }
            }
        }
        .onAppear {
            if selectedGroupId == nil {
                selectedGroupId = defaultGroupId ?? groupViewModel.groups.first?.id
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            loadPickedMedia(newItem)
        }
        // ★ 「通常の投稿」で動画を選んだ後にペンライト・グッズへ切り替えると、
        //   ショーケースは画像前提（LazyImage）なので動画のままだと表示が壊れる。
        //   種類を切り替えた時点で、選択済みの動画は一旦クリアして選び直させる
        .onChange(of: kind) { _, newKind in
            if newKind != .normal, selectedVideoURL != nil {
                pickerItem = nil
                selectedVideoURL = nil
            }
        }
        .fullScreenCover(isPresented: $showCropView) {
            if let imagePendingCrop {
                ImageCropView(
                    image: imagePendingCrop,
                    onCancel: {
                        showCropView = false
                        self.imagePendingCrop = nil
                        pickerItem = nil
                    },
                    onDone: { cropped in
                        selectedImage = cropped
                        showCropView = false
                        self.imagePendingCrop = nil
                    }
                )
            }
        }
    }

    // MARK: - 投稿の種類（通常／ペンライト／グッズ）

    // ★ 3種類とも均等幅(maxWidth:.infinity)で並べていたため、テキストが収まりきらず
    //   画面端で見切れていた。内容に合わせた幅で横スクロールできるようにする
    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PostKind.allCases) { option in
                    let isSelected = kind == option
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { kind = option }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .accessibilityHidden(true)
                            Text(option.rawValue)
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                        Group {
                            if isSelected {
                                Capsule().fill(
                                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                                )
                            } else {
                                Capsule().fill(Color.appCardBackground)
                            }
                        }
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.12 : 0.04), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - キャプション（Instagramと同じく、アバターを伴わない独立した入力欄にする）

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(captionPlaceholder, text: $caption, axis: .vertical)
                .font(.system(size: 16))
                .lineLimit(3...10)
                .focused($isCaptionFocused)

            if kind == .normal {
                Text("#ハッシュタグを付けると検索で見つけやすくなります")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .onTapGesture { isCaptionFocused = true }
    }

    private var hasMedia: Bool { selectedImage != nil || selectedVideoURL != nil }

    private var captionPlaceholder: String {
        kind == .normal ? "推しへの想いを書こう" : "こだわりポイントなど（任意）"
    }

    // MARK: - その他オプション（種類・グッズ名・投稿先グループを、Instagramの
    //   投稿オプション一覧のように1枚のカードに行として積む）

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            optionRow(icon: "square.grid.2x2.fill", title: "投稿の種類") {
                kindPicker
            }

            if kind != .normal {
                Divider().padding(.leading, 44)
                optionRow(icon: kind.icon, title: "\(kind.rawValue)の名前") {
                    TextField("例：手作りグラデーションペンライト", text: $goodsTitle)
                        .font(.system(size: 15))
                        .focused($isTitleFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray6)))
                }
            }

            if !groupViewModel.groups.isEmpty {
                Divider().padding(.leading, 44)
                optionRow(icon: "person.2.fill", title: "どの推しの投稿？") {
                    groupChips
                }
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func optionRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - メディア表示・選択（Instagramの新規投稿画面と同じく、画面最上部に
    //   左右マージン無しのedge-to-edgeで置く。通常投稿は任意、ペンライト・グッズは必須）

    @ViewBuilder
    private var mediaSection: some View {
        if isLoadingMedia || hasMedia {
            ZStack(alignment: .topTrailing) {
                Color(.systemGray6)

                if isLoadingMedia {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 340)
                } else if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 400)
                        .clipped()
                } else if let selectedVideoURL {
                    VideoPlayer(player: AVPlayer(url: selectedVideoURL))
                        .frame(height: 400)
                }

                if !isLoadingMedia {
                    Button {
                        pickerItem = nil
                        selectedImage = nil
                        selectedVideoURL = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .padding(14)
                    .accessibilityLabel("選択したメディアを削除")
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        } else {
            // ★ ペンライト・グッズは写真が必須、通常投稿は任意（文字だけの投稿もできる）
            PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .semibold))
                    Text(kind == .normal ? "写真・動画を追加（任意）" : "写真を選ぶ（必須）")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(accentColor)
                .frame(maxWidth: .infinity)
                .frame(height: kind == .normal ? 130 : 170)
                .background(accentColor.opacity(0.06))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(kind == .normal ? "画像・動画を選択" : "画像を選択")
        }
    }

    // MARK: - グループ選択チップ

    private var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groupViewModel.groups) { group in
                    let isSelected = group.id == selectedGroupId
                    Button {
                        selectedGroupId = group.id
                    } label: {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule().fill(
                                            LinearGradient(
                                                colors: [accentColor, accentColor2],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    } else {
                                        Capsule().fill(Color(.systemGray6))
                                    }
                                }
                            )
                    }
                }
            }
        }
    }

    // MARK: - 投稿ボタン

    private var postButton: some View {
        Button(action: post) {
            HStack(spacing: 6) {
                if isPosting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .accessibilityHidden(true)
                }
                Text(isPosting ? "投稿しています…" : "投稿する")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .opacity(canPost ? 1 : 0.5)
        }
        .disabled(!canPost || isPosting)
    }

    // ★ 通常投稿はThreadsのように文字だけでもよいが、ペンライト・グッズは
    //   ショーケースに並べる写真と名前が要になるため、両方必須にする
    private var canPost: Bool {
        let hasMedia = selectedImage != nil || selectedVideoURL != nil
        guard selectedGroupId != nil else { return false }
        if kind == .normal {
            let hasText = !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasMedia || hasText
        } else {
            return hasMedia && !goodsTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - メディア読み込み

    private func loadPickedMedia(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selectedImage = nil
        selectedVideoURL = nil
        errorMessage = nil
        isLoadingMedia = true

        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }

        Task {
            if isVideo {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    let attributes = try? FileManager.default.attributesOfItem(atPath: movie.url.path)
                    let size = attributes?[.size] as? Int
                    await MainActor.run {
                        if let size, size > maxVideoBytes {
                            errorMessage = "動画のサイズが大きすぎます（50MBまで）。短い動画を選んでください。"
                        } else {
                            selectedVideoURL = movie.url
                        }
                        isLoadingMedia = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "動画の読み込みに失敗しました"
                        isLoadingMedia = false
                    }
                }
            } else {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        // ★ すぐに確定させず、Instagramのように切り取り画面を挟んでから
                        //   selectedImageへ反映する（ImageCropView.onDone側で設定）
                        imagePendingCrop = uiImage
                        showCropView = true
                        isLoadingMedia = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "画像の読み込みに失敗しました"
                        isLoadingMedia = false
                    }
                }
            }
        }
    }

    // MARK: - 投稿処理

    private func post() {
        guard let uid = Auth.auth().currentUser?.uid,
              let groupId = selectedGroupId,
              let group = groupViewModel.groups.first(where: { $0.id == groupId })
        else { return }

        isPosting = true
        errorMessage = nil

        Task {
            do {
                // ★ 写真・動画は任意なので、選ばれていなければ nil のままテキストのみで投稿する
                var mediaURL: String?
                var mediaType: String?

                if let selectedImage {
                    mediaURL = try await ImageStorageService.shared.uploadPostImage(selectedImage, uid: uid)
                    mediaType = "image"
                } else if let selectedVideoURL {
                    mediaURL = try await ImageStorageService.shared.uploadPostVideo(fileURL: selectedVideoURL, uid: uid)
                    mediaType = "video"
                }

                postViewModel.createPost(
                    groupId: groupId,
                    groupName: group.name,
                    mediaURL: mediaURL,
                    mediaType: mediaType,
                    caption: caption,
                    authorUid: uid,
                    goodsKind: kind.goodsValue,
                    goodsTitle: kind == .normal ? nil : goodsTitle
                )
                AnalyticsManager.logPostCreated(groupId: groupId, hasMedia: mediaURL != nil, goodsKind: kind.goodsValue)

                await MainActor.run {
                    isPosting = false
                    dismiss()
                }
            } catch {
                CrashReportManager.recordNonFatal(error)
                await MainActor.run {
                    isPosting = false
                    errorMessage = "投稿に失敗しました。もう一度お試しください。"
                }
            }
        }
    }
}
