//
//  PostComposerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import PhotosUI
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

    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.dismiss) private var dismiss

    // ★ 投稿先グループは呼び出し元(その時点でホームなどで選択中だったグループ)で確定させ、
    //   この画面自体では選ばせない。別グループの投稿画面と誤認して意図しないグループへ
    //   投稿してしまう事故を防ぐため（以前はここにグループ選択のMenuがあった）
    let group: IdolGroup
    // ★ 「推し活ペンライト・グッズ」ツールの「投稿する」から開いた場合、
    //   最初から種類をペンライト・グッズ寄りに合わせておく
    var initialKind: PostKind = .normal

    // ★ 複数枚投稿(画像・動画混在可)対応。選んだ順序を保つため1本の配列にまとめて持つ
    enum ComposerMediaItem: Identifiable {
        case image(UIImage)
        case video(URL)

        var id: String {
            switch self {
            case .image(let image): return "img_\(ObjectIdentifier(image).hashValue)"
            case .video(let url): return "vid_\(url.absoluteString)"
            }
        }
    }

    @State private var kind: PostKind
    @State private var goodsTitle: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedMediaItems: [ComposerMediaItem] = []
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

    init(group: IdolGroup, initialKind: PostKind = .normal) {
        self.group = group
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }

    // ★ デザインコンセプト「高級感×白×純正アップル×少しの立体感」に合わせ、独自カードの
    //   積み重ねではなくFormによるネイティブなinset-groupedリストに統一する。画像はInstagramの
    //   実際の新規投稿画面のように画面を占領しない小さな正方形サムネイルとして左上に置き、
    //   キャプション・種類・投稿先などはApple設定画面と同じ「アイコン＋ラベル＋右側の値」の
    //   行として並べる
    var body: some View {
        Form {
            Section {
                mediaRow
            }

            Section {
                captionRow
                hashtagQuickAction
            }

            Section {
                kindRow
                if kind != .normal {
                    goodsNameRow
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { postButtonBar }
        .navigationTitle("\(group.name)へ投稿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") { dismiss() }
            }
        }
        .onChange(of: pickerItems) { _, newItems in
            loadPickedMedia(newItems)
        }
        // ★ 「通常の投稿」で複数枚・動画を選んだ後にペンライト・グッズへ切り替えると、
        //   ショーケースは画像1枚前提（LazyImage）なので崩れてしまう。種類を切り替えた時点で、
        //   選択済みが1枚の画像でなければ一旦クリアして選び直させる
        .onChange(of: kind) { _, newKind in
            if newKind != .normal {
                let isSingleImage: Bool = {
                    if case .image = selectedMediaItems.first, selectedMediaItems.count == 1 { return true }
                    return false
                }()
                if !isSingleImage {
                    pickerItems = []
                    selectedMediaItems = []
                }
            }
        }
        .fullScreenCover(isPresented: $showCropView) {
            if let imagePendingCrop {
                ImageCropView(
                    image: imagePendingCrop,
                    onCancel: {
                        showCropView = false
                        self.imagePendingCrop = nil
                        pickerItems = []
                    },
                    onDone: { cropped in
                        selectedMediaItems = [.image(cropped)]
                        showCropView = false
                        self.imagePendingCrop = nil
                    }
                )
            }
        }
    }

    private var hasMedia: Bool { !selectedMediaItems.isEmpty }

    private var captionPlaceholder: String {
        kind == .normal ? "推しへの想いを書こう" : "こだわりポイントなど（任意）"
    }

    // MARK: - メディア（小さな正方形サムネイル。画面全体を占領しない。通常の投稿は複数枚選べる）

    private var maxSelectionCount: Int { kind == .normal ? 10 : 1 }

    @ViewBuilder
    private var mediaRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedMediaItems.enumerated()), id: \.element.id) { index, item in
                    mediaThumbnail(item, index: index)
                }

                if isLoadingMedia {
                    ProgressView()
                        .frame(width: 100, height: 100)
                }

                if selectedMediaItems.count < maxSelectionCount {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: maxSelectionCount,
                        matching: .any(of: [.images, .videos])
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                            Text(selectedMediaItems.isEmpty ? (kind == .normal ? "任意" : "必須") : "追加")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(accentColor)
                        .frame(width: 100, height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(kind == .normal ? "画像・動画を選択（複数枚可・任意）" : "画像を選択（必須）")
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func mediaThumbnail(_ item: ComposerMediaItem, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            switch item {
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .video:
                ZStack {
                    Color.black
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            mediaRemoveBadge(index: index)
        }
    }

    private func mediaRemoveBadge(index: Int) -> some View {
        Button {
            selectedMediaItems.remove(at: index)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.black.opacity(0.55), in: Circle())
        }
        .padding(5)
        .accessibilityLabel("選択したメディアを削除")
    }

    // MARK: - キャプション（Apple純正のブランドマーク＋テキストのみのシンプルな行）

    private var captionRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)

            TextField(captionPlaceholder, text: $caption, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...8)
                .focused($isCaptionFocused)
        }
        .padding(.vertical, 4)
    }

    private var hashtagQuickAction: some View {
        Button {
            if !caption.isEmpty, let last = caption.last, last != " ", last != "\n" {
                caption += " "
            }
            caption += "#"
            isCaptionFocused = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "number")
                    .font(.system(size: 11, weight: .semibold))
                Text("ハッシュタグを追加")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(accentColor.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .padding(.leading, 36)
    }

    // MARK: - オプション行（Apple設定画面と同じ「アイコン＋ラベル＋右側の値／Menu」形式）

    private var kindRow: some View {
        HStack {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text("投稿の種類")
                .font(.system(size: 15))
            Spacer()
            Menu {
                ForEach(PostKind.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { kind = option }
                    } label: {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(kind.rawValue)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private var goodsNameRow: some View {
        HStack {
            Image(systemName: kind.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text("\(kind.rawValue)の名前")
                .font(.system(size: 15))
            Spacer()
            TextField("例：手作りグラデーションペンライト", text: $goodsTitle)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .focused($isTitleFocused)
        }
    }

    // MARK: - 投稿ボタン（Formの外、常に画面下に固定表示する）

    private var postButtonBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: post) {
                HStack(spacing: 6) {
                    if isPosting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .accessibilityHidden(true)
                    }
                    Text(isPosting ? "投稿しています…" : "投稿する")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    (canPost && !isPosting)
                        ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.gray.opacity(0.35))
                )
                .clipShape(Capsule())
            }
            .disabled(!canPost || isPosting)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // ★ 通常投稿はThreadsのように文字だけでもよいが、ペンライト・グッズは
    //   ショーケースに並べる写真と名前が要になるため、両方必須にする
    private var canPost: Bool {
        let hasMedia = !selectedMediaItems.isEmpty
        if kind == .normal {
            let hasText = !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasMedia || hasText
        } else {
            return hasMedia && !goodsTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: - メディア読み込み

    private func loadPickedMedia(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        errorMessage = nil

        // ★ 画像1枚だけを選んだ場合は、これまで通りInstagramのような切り取り画面を挟む。
        //   複数枚・動画を含む選択は、切り取りを挟まず選んだ順のまま読み込む
        if items.count == 1, let single = items.first,
           !single.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            isLoadingMedia = true
            Task {
                if let data = try? await single.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
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
            return
        }

        selectedMediaItems = []
        isLoadingMedia = true

        Task {
            var loaded: [ComposerMediaItem] = []
            var loadErrorText: String?

            for item in items {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                if isVideo {
                    if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                        let attributes = try? FileManager.default.attributesOfItem(atPath: movie.url.path)
                        let size = attributes?[.size] as? Int
                        if let size, size > maxVideoBytes {
                            loadErrorText = "動画のサイズが大きすぎるため、一部の動画は除外しました（50MBまで）"
                        } else {
                            loaded.append(.video(movie.url))
                        }
                    } else {
                        loadErrorText = "読み込めなかった動画があります"
                    }
                } else {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        loaded.append(.image(uiImage))
                    } else {
                        loadErrorText = "読み込めなかった画像があります"
                    }
                }
            }

            await MainActor.run {
                selectedMediaItems = loaded
                errorMessage = loadErrorText
                isLoadingMedia = false
            }
        }
    }

    // MARK: - 投稿処理

    private func post() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        isPosting = true
        errorMessage = nil

        Task {
            do {
                // ★ 写真・動画は任意なので、選ばれていなければ空のままテキストのみで投稿する。
                //   複数枚選んだ場合は選んだ順のままアップロードし、mediaItemsに全件、
                //   mediaURL/mediaTypeには（既存画面がそのまま動くよう）1枚目を入れる
                var uploadedItems: [PostMediaItem] = []
                for item in selectedMediaItems {
                    switch item {
                    case .image(let image):
                        let url = try await ImageStorageService.shared.uploadPostImage(image, uid: uid)
                        uploadedItems.append(PostMediaItem(url: url, type: "image"))
                    case .video(let videoURL):
                        let url = try await ImageStorageService.shared.uploadPostVideo(fileURL: videoURL, uid: uid)
                        uploadedItems.append(PostMediaItem(url: url, type: "video"))
                    }
                }

                // ★ 以前はcreatePostの完了を待たずに即dismiss()していたため、制限ユーザーへの
                //   書き込み拒否やネットワーク断で投稿が実際には保存されなくても、
                //   画面上は投稿が成功したかのように閉じてしまっていた。completionで
                //   保存結果を確認してから閉じる／エラー表示するように直す
                let saveError: Error? = await withCheckedContinuation { continuation in
                    postViewModel.createPost(
                        groupId: group.id,
                        groupName: group.name,
                        mediaURL: uploadedItems.first?.url,
                        mediaType: uploadedItems.first?.type,
                        mediaItems: uploadedItems,
                        caption: caption,
                        authorUid: uid,
                        goodsKind: kind.goodsValue,
                        goodsTitle: kind == .normal ? nil : goodsTitle
                    ) { error in
                        continuation.resume(returning: error)
                    }
                }

                if let saveError {
                    await MainActor.run {
                        isPosting = false
                        errorMessage = "投稿の保存に失敗しました。もう一度お試しください。"
                    }
                    CrashReportManager.recordNonFatal(saveError)
                    return
                }

                AnalyticsManager.logPostCreated(groupId: group.id, hasMedia: !uploadedItems.isEmpty, goodsKind: kind.goodsValue)

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
