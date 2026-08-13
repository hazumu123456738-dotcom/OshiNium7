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
    // ★ 大きなメイン表示（mediaHero）が今どのページ（何枚目）を表示しているか。
    //   複数枚選択時のサムネイル一覧（mediaThumbnailStrip）からのタップ選択・
    //   削除時のクランプ処理の両方で使う
    @State private var heroPage: Int = 0
    // ★ メイン表示の画像をタップした時の全画面表示用。まだアップロード前のローカルUIImageのため、
    //   投稿済み画像の全画面表示（ChatImageViewerView、URLベース）とは別の軽量な実装を持つ
    @State private var fullScreenImage: IdentifiableImage?
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
    //   積み重ねではなくFormによるネイティブなinset-groupedリストに統一する。
    //   ★ 2026/08/13：画像・動画は以前「小さな正方形サムネイルを左上に置く」だけの控えめな
    //   表示だったが、実際のInstagramの新規投稿画面のように画面中央に大きく表示するよう変更した
    //   （メディア未選択時も、同じ大きな枠に点線の空の型枠を表示する）。複数枚選択時は
    //   その大きな枠自体がページめくり式のカルーセルになり、下に並び替え・削除用の
    //   小さなサムネイル一覧を添える。キャプション・種類・投稿先などはApple設定画面と同じ
    //   「アイコン＋ラベル＋右側の値」の行として並べる（ここは変更なし）
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
                        heroPage = 0
                        showCropView = false
                        self.imagePendingCrop = nil
                    }
                )
            }
        }
        .fullScreenCover(item: $fullScreenImage) { item in
            ComposerImageFullScreenView(image: item.image)
        }
    }

    private var hasMedia: Bool { !selectedMediaItems.isEmpty }

    private var captionPlaceholder: String {
        kind == .normal ? "推しへの想いを書こう" : "こだわりポイントなど（任意）"
    }

    // MARK: - メディア（Instagram風：画面中央に大きく表示。通常の投稿は複数枚選べる）

    private var maxSelectionCount: Int { kind == .normal ? 10 : 1 }

    @ViewBuilder
    private var mediaRow: some View {
        VStack(spacing: 10) {
            mediaHero
            if selectedMediaItems.count > 1 {
                mediaThumbnailStrip
            }
        }
        .padding(.vertical, 6)
    }

    // ★ メディア未選択時は点線の空の型枠、選択済みならページめくり式のカルーセルを
    //   同じ大きな正方形の枠に表示する。枠のサイズはFormのSection幅いっぱい（正方形）にする
    @ViewBuilder
    private var mediaHero: some View {
        ZStack {
            if isLoadingMedia {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemGray6))
                ProgressView()
            } else if selectedMediaItems.isEmpty {
                emptyMediaPlaceholder
            } else {
                TabView(selection: $heroPage) {
                    ForEach(Array(selectedMediaItems.enumerated()), id: \.element.id) { index, item in
                        heroMediaContent(item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: selectedMediaItems.count > 1 ? .always : .never))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    heroRemoveButton
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func heroMediaContent(_ item: ComposerMediaItem) -> some View {
        switch item {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    fullScreenImage = IdentifiableImage(image: image)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("タップで全画面表示")
        case .video(let url):
            ZStack {
                VideoThumbnailView(url: url)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyMediaPlaceholder: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: maxSelectionCount,
            matching: .any(of: [.images, .videos])
        ) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                Text(kind == .normal ? "任意" : "必須")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .normal ? "画像・動画を選択（複数枚可・任意）" : "画像を選択（必須）")
    }

    // ★ 今カルーセルで表示中の1枚だけを削除するボタン。大きな枠の右上に重ねて置く
    private var heroRemoveButton: some View {
        Button {
            removeMedia(at: heroPage)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.55), in: Circle())
        }
        .padding(10)
        .accessibilityLabel("表示中のメディアを削除")
    }

    // ★ 複数枚選んだ時だけ出す、並び替え・個別削除・追加用の小さなサムネイル一覧。
    //   Instagramの複数枚投稿編集画面と同じく、大きなカルーセルの下に添える
    private var mediaThumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedMediaItems.enumerated()), id: \.element.id) { index, item in
                    thumbnailChip(item, index: index)
                }

                if selectedMediaItems.count < maxSelectionCount {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: maxSelectionCount,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentColor)
                            .frame(width: 52, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("メディアを追加")
                }
            }
        }
    }

    private func thumbnailChip(_ item: ComposerMediaItem, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch item {
                case .image(let image):
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .video(let url):
                    ZStack {
                        VideoThumbnailView(url: url)
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(index == heroPage ? accentColor : .clear, lineWidth: 2)
            )
            .onTapGesture { heroPage = index }

            Button {
                removeMedia(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 15, height: 15)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .offset(x: 4, y: -4)
            .accessibilityLabel("このメディアを削除")
        }
    }

    // ★ 削除後、カルーセルのページ番号が配列の範囲外にならないようクランプする
    private func removeMedia(at index: Int) {
        guard selectedMediaItems.indices.contains(index) else { return }
        selectedMediaItems.remove(at: index)
        heroPage = min(heroPage, max(0, selectedMediaItems.count - 1))
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
                heroPage = 0
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

// ★ .fullScreenCover(item:)にUIImageをそのまま渡せるようにするための薄いラッパー
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// ★ 投稿画面のメイン表示（mediaHero）をタップした時の、選択中画像の全画面表示。
//   投稿済み画像の全画面表示（ChatImageViewerView）と同じ「黒背景＋ピンチした位置を起点に
//   ズーム＋左上の閉じるボタン」という見た目・操作感に揃えるが、こちらはまだアップロード前の
//   ローカルUIImageを直接表示するため、LazyImage(url:)ではなくImage(uiImage:)を使う
struct ComposerImageFullScreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var zoomAnchor: UnitPoint = .center

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
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
