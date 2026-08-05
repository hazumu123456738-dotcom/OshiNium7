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
    @EnvironmentObject var settingsVM: UserSettingsViewModel
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
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var isCaptionFocused: Bool
    @FocusState private var isTitleFocused: Bool

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)
    private let accentColor2 = Color(red: 0.90, green: 0.60, blue: 0.95)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                kindPicker

                composerCard

                if kind != .normal {
                    goodsTitleCard
                }

                if !groupViewModel.groups.isEmpty {
                    groupChips
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                postButton
            }
            .padding(16)
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
        .onChange(of: pickerItem) { newItem in
            loadPickedMedia(newItem)
        }
        // ★ 「通常の投稿」で動画を選んだ後にペンライト・グッズへ切り替えると、
        //   ショーケースは画像前提（LazyImage）なので動画のままだと表示が壊れる。
        //   種類を切り替えた時点で、選択済みの動画は一旦クリアして選び直させる
        .onChange(of: kind) { newKind in
            if newKind != .normal, selectedVideoURL != nil {
                pickerItem = nil
                selectedVideoURL = nil
            }
        }
    }

    // MARK: - 投稿の種類（通常／ペンライト／グッズ）

    private var kindPicker: some View {
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
                    .frame(maxWidth: .infinity)
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
    }

    // MARK: - 投稿カード（自分のアバター＋テキスト欄＋メディアをひとまとめにする）

    private var composerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            myAvatar

            VStack(alignment: .leading, spacing: 12) {
                TextField(captionPlaceholder, text: $caption, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(3...10)
                    .focused($isCaptionFocused)

                if kind == .normal {
                    Text("#ハッシュタグを付けると検索で見つけやすくなります")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                mediaPicker
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

    private var captionPlaceholder: String {
        kind == .normal ? "推しへの想いを書こう" : "こだわりポイントなど（任意）"
    }

    private var myAvatar: some View {
        Group {
            if let url = URL(string: settingsVM.settings.iconURL), !settingsVM.settings.iconURL.isEmpty {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        myAvatarPlaceholder
                    }
                }
            } else {
                myAvatarPlaceholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
    }

    private var myAvatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay(
                Text(String((settingsVM.settings.displayName.isEmpty ? "?" : settingsVM.settings.displayName).prefix(1)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - ペンライト・グッズの名前（この種類の時だけ必須で出す）

    private var goodsTitleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(kind.rawValue)の名前", systemImage: kind.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("例：手作りグラデーションペンライト", text: $goodsTitle)
                .font(.system(size: 15))
                .focused($isTitleFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.appCardBackground))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(accentColor.opacity(0.06))
        )
    }

    // MARK: - メディア選択（任意。Threadsのように文字だけでも投稿できる。
    //   写真・ステッカー画像など何でも選べるよう、アイコン1つの控えめな追加ボタンにする）

    @ViewBuilder
    private var mediaPicker: some View {
        if isLoadingMedia || selectedImage != nil || selectedVideoURL != nil {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemGray6))

                if isLoadingMedia {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                } else if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else if let selectedVideoURL {
                    VideoPlayer(player: AVPlayer(url: selectedVideoURL))
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if !isLoadingMedia {
                    Button {
                        pickerItem = nil
                        selectedImage = nil
                        selectedVideoURL = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .padding(10)
                    .accessibilityLabel("選択したメディアを削除")
                }
            }
        } else {
            PhotosPicker(selection: $pickerItem, matching: kind == .normal ? .any(of: [.images, .videos]) : .any(of: [.images])) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold))
                    if kind != .normal {
                        Text("写真を選ぶ（必須）")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundColor(accentColor)
                .padding(.horizontal, kind == .normal ? 0 : 14)
                .frame(height: 36)
                .background(
                    Group {
                        if kind != .normal {
                            Capsule().fill(accentColor.opacity(0.1))
                        }
                    }
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("画像・動画を選択")
        }
    }

    // MARK: - グループ選択チップ

    private var groupChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("どの推しの投稿？")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

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
                                            Capsule().fill(Color.appCardBackground)
                                        }
                                    }
                                )
                                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                        }
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
                        selectedImage = uiImage
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

                await MainActor.run {
                    isPosting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = "投稿に失敗しました。もう一度お試しください。"
                }
            }
        }
    }
}
