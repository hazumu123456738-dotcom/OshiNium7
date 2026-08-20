//
//  PostFeedCard.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import UIKit
import AVKit
import FirebaseAuth
import NukeUI

struct PostFeedCard: View {
    let post: Post

    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var savedPostViewModel: SavedPostViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var navState: AppNavigationState

    @State private var authorProfile: ChatViewModel.RemoteUserProfile?
    @State private var isPlayingVideo = false
    @State private var showComments = false
    @State private var showHashtagSearch = false
    @State private var tappedHashtag = ""
    @State private var showSaveTemplateConfirm = false
    @State private var didSaveTemplate = false
    @State private var templateSaveErrorMessage: String?
    @State private var showTemplatePremiumUpgrade = false
    @State private var showShareSheet = false
    @State private var mediaZoomScale: CGFloat = 1
    @State private var mediaLastZoomScale: CGFloat = 1
    // ★ ピンチした指の位置を中心に拡大されるようにするための起点（.centerだと常に画像の
    //   中央基準で拡大され、右上をピンチしても中央が拡大されてしまっていた）
    @State private var mediaZoomAnchor: UnitPoint = .center
    // ★ 動画の全画面表示（YouTubeの全画面表示に近いもの）用
    @State private var fullScreenVideoURL: IdentifiableURL?
    // ★ 画像タップ時の全画面表示用。ZoomableChatImage（ChatImageViewerView.swift）を
    //   そのまま再利用するため、ここでは表示するURLだけを持たせる
    @State private var fullScreenImageURL: IdentifiableURL?
    @State private var showReportDialog = false
    @State private var showPostMenu = false
    @State private var showReportThanks = false
    @State private var showCaptionEdit = false
    // ★ 複数枚投稿(post.mediaItems)用。現在表示中のページ番号(右上の「1/3」表示に使う)と、
    //   ページごとの動画再生中フラグ(単一動画のisPlayingVideoとは別に、ページごとに持つ必要がある)
    @State private var carouselPage = 0
    @State private var playingCarouselIndices: Set<Int> = []
    @StateObject private var heartDriver = DoubleTapHeartDriver()

    private let accentColor = Color.oshiniumPrimary

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    // ★ 匿名ログインはタイムラインの閲覧のみで、いいね・保存はできない
    //   （firestore.rules側では匿名も普通の認証済みユーザーと同じ書き込み権限を持つため、
    //   ここでのUI側ブロックが実質的な唯一の防波堤。抜けを作らないよう各操作の入口ごとに確認する）
    private var isAnonymous: Bool { Auth.auth().currentUser?.isAnonymous ?? false }
    @State private var showAnonymousGate = false
    private var isLiked: Bool {
        guard let currentUid else { return false }
        return post.likedBy.contains(currentUid)
    }
    private var isSaved: Bool { savedPostViewModel.isSaved(post.id) }

    // ★ ヘッダーとmediaViewの間に、バッジ・キャプション・持ち物リストのいずれかが
    //   挟まるかどうか。挟まらない場合だけmediaViewの上に余分な間隔を追加する
    private var hasContentBetweenHeaderAndMedia: Bool {
        post.goodsKind != nil && post.goodsTitle != nil
            || post.expenseAmount != nil && post.expenseCategory != nil
            || post.caption?.isEmpty == false
            || post.packingTemplateItems?.isEmpty == false
    }

    // ★ Threadsと同じく、左にアバター1列・右にコンテンツ列という構成にする。
    //   個別カードの白背景・影は持たず、外側（HomeViewのtimelineSection）が
    //   投稿全体を1枚の白いコンテナにまとめ、投稿同士は罫線（Divider）だけで区切る。
    //   ★ 画像だけはアバター分の字下げから外し、カード全体の左右マージンを揃えた
    //     フルワイドで表示する（字下げしたままだと画像が小さく、左右の余白も
    //     不揃いになってしまうため）。テキスト部分（ヘッダー・本文）はThreads同様に字下げを保つ
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink {
                    UserProfileView(
                        uid: post.authorUid,
                        fallbackName: authorProfile?.displayName ?? "名無しさん",
                        fallbackIconURL: displayIconURLString
                    )
                } label: {
                    avatar
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(authorProfile?.displayName ?? "名無しさん")さんのプロフィール")

                header
            }

            // ★ キャプション・ハッシュタグ・バッジ類は、ユーザーネームの真下ではなく
            //   アイコン（アバター）の真下に来るよう、あえてheaderと同じHStackの中に
            //   字下げして入れず、この外側のVStackの高さで揃える
            if let kind = post.goodsKind, let title = post.goodsTitle {
                goodsKindBadge(kind: kind, title: title)
            }

            if let amount = post.expenseAmount, let category = post.expenseCategory {
                expenseBadge(amount: amount, category: category)
            }

            if let caption = post.caption, !caption.isEmpty {
                Text(captionAttributedString(caption))
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == hashtagURLScheme else { return .systemAction }
                        let path = url.path
                        tappedHashtag = path.hasPrefix("/") ? String(path.dropFirst()) : path
                        showHashtagSearch = true
                        return .handled
                    })
            }

            if let items = post.packingTemplateItems, !items.isEmpty {
                packingListCard(name: post.packingTemplateName ?? "持ち物リスト", items: items)
            }

            // ★ キャプション・バッジ等が無い画像単体の投稿では、ヘッダーの「…」ボタン
            //   （44×44のタップ領域）と画像の間がVStackの標準spacing(6pt)しか空かず、
            //   物理的に近すぎて「…」を狙ったタップが画像側のダブルタップ(いいね)判定に
            //   化けてしまう不具合があった。キャプション等が挟まる場合はその分の余白で
            //   十分足りるが、何も挟まらない場合だけ、はっきり分かる間隔を追加で確保する
            mediaView
                .padding(.top, hasContentBetweenHeaderAndMedia ? 10 : 22)

            footer
        }
        .padding(.vertical, 10)
        .task {
            authorProfile = await ChatViewModel.fetchUserProfile(uid: post.authorUid)
        }
        .sheet(isPresented: $showHashtagSearch) {
            PostSearchView(
                selectedGroup: IdolGroup(id: post.groupId, name: post.groupName),
                initialQuery: tappedHashtag
            )
        }
        .sheet(isPresented: $showCaptionEdit) {
            PostCaptionEditSheet(post: post)
        }
        .fullScreenCover(item: $fullScreenVideoURL) { item in
            PostVideoFullScreenView(videoURL: item.url)
        }
        .fullScreenCover(item: $fullScreenImageURL) { item in
            ChatImageViewerView(imageURL: item.url)
        }
        .sheet(isPresented: $showSaveTemplateConfirm) {
            PackingTemplateSaveConfirmSheet(
                templateName: post.packingTemplateName ?? "持ち物リスト",
                items: post.packingTemplateItems ?? [],
                onConfirm: saveAsTemplate
            )
        }
        .alert("テンプレートの上限に達しました", isPresented: Binding(
            get: { templateSaveErrorMessage != nil },
            set: { if !$0 { templateSaveErrorMessage = nil } }
        )) {
            Button("キャンセル", role: .cancel) { templateSaveErrorMessage = nil }
            Button("アップグレード") {
                templateSaveErrorMessage = nil
                showTemplatePremiumUpgrade = true
            }
        } message: {
            Text(templateSaveErrorMessage ?? "")
        }
        .sheet(isPresented: $showTemplatePremiumUpgrade) {
            PremiumUpgradeView()
        }
        .overlay(alignment: .top) {
            if didSaveTemplate {
                Text("マイテンプレートに保存しました")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showReportThanks {
                ReportThanksToast()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: didSaveTemplate)
        .animation(.easeInOut(duration: 0.2), value: showReportThanks)
        .sheet(isPresented: $showReportDialog) {
            ReportComposerSheet(title: "この投稿を報告") { reason, detail in
                ModerationService.reportPost(
                    postId: post.id,
                    groupId: post.groupId,
                    caption: post.caption ?? "",
                    authorUid: post.authorUid,
                    reason: reason,
                    detail: detail
                )
                showReportThanksBriefly()
            }
        }
    }

    // ★ 数秒だけ「ご協力ありがとうございます」を表示してから自動的に消す
    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
        }
    }

    // MARK: - ペンライト・グッズの種類バッジ（「推し活ペンライト・グッズ」ツールからの投稿。
    //   専用コレクションは持たず通常の投稿として扱うため、タイムライン上でもここで一目で分かるようにする）

    private func goodsKindBadge(kind: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind == "ペンライト" ? "flashlight.on.fill" : "gift.fill")
                .font(.system(size: 10, weight: .semibold))
                .accessibilityHidden(true)
            Text("\(kind)：\(title)")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color.oshiniumGoodsAccent, Color.oshiniumGoodsAccent2],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        )
    }

    // MARK: - 推し活の金額バッジ（「推し活費用シミュレーター」ツールからの投稿）

    private func expenseBadge(amount: Int, category: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "yensign.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .accessibilityHidden(true)
            Text("\(category)に\(yenText(amount))")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Color.oshiniumPrimary, Color.oshiniumPrimary2], startPoint: .leading, endPoint: .trailing)
            )
        )
    }

    private func yenText(_ amount: Int) -> String {
        "¥" + (CachedFormatters.number(style: .decimal).string(from: NSNumber(value: amount)) ?? "\(amount)")
    }

    // MARK: - 持ち物リストカード（テンプレート投稿。タップで自分のテンプレートに保存できる。
    //   保存すると、自分の投稿でない限りお礼として投稿にいいねが付く）

    private func packingListCard(name: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(name, systemImage: "checklist")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.40, green: 0.72, blue: 0.55))

            VStack(alignment: .leading, spacing: 5) {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(item)
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.40, green: 0.72, blue: 0.55).opacity(0.08))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSaveTemplateConfirm = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップでマイテンプレートに保存できます")
    }

    private func saveAsTemplate() {
        guard let currentUid, let items = post.packingTemplateItems, !items.isEmpty else { return }
        let name = post.packingTemplateName ?? "持ち物リスト"

        PackingTemplateViewModel.save(uid: currentUid, name: name, items: items) { error in
            DispatchQueue.main.async {
                if let error {
                    templateSaveErrorMessage = error.localizedDescription
                    return
                }
                didSaveTemplate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    didSaveTemplate = false
                }
            }
        }

        if post.authorUid != currentUid {
            postViewModel.likeIfNotAlready(post: post, uid: currentUid, actorName: settingsVM.settings.displayName, actorIconURL: settingsVM.settings.iconURL)
        }
    }

    // MARK: - ハッシュタグ（キャプション中の「#〇〇」をアクセントカラーでハイライトし、
    //   タップするとそのグループ内でハッシュタグ検索できるようにする。カスタムURLスキームに
    //   タグを載せてAttributedStringのリンクとして扱うことで、Text内の一部分だけタップ可能にする）

    private let hashtagURLScheme = "oshinium-tag"

    // ★ 投稿本文の各行先頭についた余分な空白（全角スペース含む）を取り除く。
    //   これが残っていると、キャプションやハッシュタグが左端から不自然にずれて、
    //   中央寄りに見えてしまう（VStack自体はalignment: .leadingで正しく左詰めなので、
    //   見た目のズレの原因は本文テキストそのものに含まれる先頭空白であることが多い）
    private func normalizedCaption(_ caption: String) -> String {
        caption
            .components(separatedBy: "\n")
            .map { line -> String in
                var trimmed = Substring(line)
                while let first = trimmed.first, first == " " || first == "\t" || first == "\u{3000}" {
                    trimmed = trimmed.dropFirst()
                }
                return String(trimmed)
            }
            .joined(separator: "\n")
    }

    private func captionAttributedString(_ rawCaption: String) -> AttributedString {
        let caption = normalizedCaption(rawCaption)
        let matches = HashtagParser.matches(in: caption)
        guard !matches.isEmpty else { return AttributedString(caption) }

        let nsCaption = caption as NSString

        var result = AttributedString()
        var lastEnd = 0

        for match in matches {
            let range = match.range
            if range.location > lastEnd {
                result += AttributedString(nsCaption.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd)))
            }

            let tag = nsCaption.substring(with: range)
            var tagAttr = AttributedString(tag)
            tagAttr.foregroundColor = accentColor
            tagAttr.font = .system(size: 14, weight: .semibold)
            if let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
               let url = URL(string: "\(hashtagURLScheme):///\(encoded)") {
                tagAttr.link = url
            }
            result += tagAttr

            lastEnd = range.location + range.length
        }

        if lastEnd < nsCaption.length {
            result += AttributedString(nsCaption.substring(from: lastEnd))
        }

        return result
    }

    // MARK: - ヘッダー（ユーザー名・グループ名・時刻を1行にまとめる、Threadsの並び方）

    private var header: some View {
        HStack(spacing: 6) {
            Text(authorProfile?.displayName ?? "名無しさん")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(post.groupName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.oshiniumPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(relativeTime(post.createdAt))
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // ★ 自分の投稿なら削除、他人の投稿なら報告できる「…」メニュー
            //   （チャットの通報導線と同じ仕組みをタイムラインの投稿本体にも展開する）
            //   ★ 以前は`Menu`を使っていたが、ScrollView/LazyVStack内では初回タップの
            //   認識が不安定になることがあり、「反応が悪い」→焦って連打→意図せず
            //   画像のダブルタップ(いいね)判定に化ける、という体験に繋がっていた。
            //   Menu自身の内部ジェスチャーに頼らない、単純なButton+confirmationDialogに
            //   置き換えることで、タップの取りこぼしが起きにくい確実な挙動にする
            Button {
                showPostMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(post.authorUid == currentUid ? "投稿を削除" : "投稿を報告")
            .confirmationDialog("", isPresented: $showPostMenu, titleVisibility: .hidden) {
                Button("シェア") {
                    showShareSheet = true
                }
                if post.authorUid == currentUid {
                    Button("編集") {
                        showCaptionEdit = true
                    }
                    Button("削除", role: .destructive) {
                        postViewModel.deletePost(post) { error in
                            if error != nil { navState.showToast("削除できませんでした") }
                        }
                    }
                } else {
                    Button("報告する", role: .destructive) {
                        showReportDialog = true
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    // ★ 2026/08/15追加：authorProfileは.taskで1度だけ取得するため、マイページで
    //   自分のアイコンを変更しても、このカードが再マウントされない限り古いアイコンの
    //   ままだった（5タブ常時マウント構成のため、タブを切り替えるだけでは再マウントされない）。
    //   自分自身の投稿については、常に最新のsettingsVM.settings.iconURL
    //   （EnvironmentObject、マイページの変更が即座に反映される）を優先する
    private var displayIconURLString: String? {
        if post.authorUid == currentUid, !settingsVM.settings.iconURL.isEmpty {
            return settingsVM.settings.iconURL
        }
        return authorProfile?.iconURL
    }

    private var avatar: some View {
        Group {
            if let url = displayIconURLString.flatMap(URL.init) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray4))
            .overlay(
                Text(String((authorProfile?.displayName ?? "?").prefix(1)))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - メディア（複数枚投稿）

    // ★ Instagramと同じく、横スワイプでページ送りできるカルーセルにし、右上に
    //   「1/3」のようなバッジを重ねて複数枚投稿であることが一目で伝わるようにする
    private func multiMediaCarousel(_ items: [PostMediaItem]) -> some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $carouselPage) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    carouselPageView(item, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("\(carouselPage + 1)/\(items.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(10)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(items.count)枚のうち\(carouselPage + 1)枚目の投稿メディア")
    }

    @ViewBuilder
    private func carouselPageView(_ item: PostMediaItem, index: Int) -> some View {
        if item.type == "video", let url = URL(string: item.url) {
            if playingCarouselIndices.contains(index) {
                VideoPlayer(player: AVPlayer(url: url))
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        fullScreenVideoButton(url: url)
                    }
            } else {
                ZStack {
                    VideoThumbnailView(url: url)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.9))
                }
                .contentShape(Rectangle())
                .onTapGesture { playingCarouselIndices.insert(index) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("動画を再生")
                .accessibilityAddTraits(.isButton)
            }
        } else if let url = URL(string: item.url) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(.systemGray6)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                fullScreenImageURL = IdentifiableURL(url: url)
            }
            .accessibilityLabel("投稿画像")
            .accessibilityHint("タップで全画面表示")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                fullScreenImageURL = IdentifiableURL(url: url)
            }
        }
    }

    // ★ YouTubeの全画面表示ボタンに近い、動画の隅に置く「全画面で開く」ボタン
    private func fullScreenVideoButton(url: URL) -> some View {
        Button {
            fullScreenVideoURL = IdentifiableURL(url: url)
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(7)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
        .accessibilityLabel("全画面で再生")
        .padding(10)
    }

    // MARK: - メディア

    // ★ Threadsのように、メディアが無いテキストのみの投稿もあるため、その場合は何も描画しない
    @ViewBuilder
    private var mediaView: some View {
        if let items = post.mediaItems, items.count > 1 {
            multiMediaCarousel(items)
        } else if post.mediaType == "video" {
            if isPlayingVideo, let mediaURL = post.mediaURL, let url = URL(string: mediaURL) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        fullScreenVideoButton(url: url)
                    }
            } else {
                ZStack {
                    Group {
                        if let mediaURL = post.mediaURL, let thumbURL = URL(string: mediaURL) {
                            VideoThumbnailView(url: thumbURL)
                        } else {
                            Color.black.opacity(0.85)
                        }
                    }
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))
                }
                .contentShape(Rectangle())
                .onTapGesture { isPlayingVideo = true }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("動画を再生")
                .accessibilityAddTraits(.isButton)
            }
        } else if let mediaURL = post.mediaURL, let url = URL(string: mediaURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipped()
            // ★ 別画面を開くのではなく、その場でピンチした分だけ拡大され、
            //   指を離すと元の大きさに戻る（虫眼鏡のような一時的な拡大）。
            //   拡大中は下の投稿に隠れないようzIndexを上げる
            //   ★ MagnificationGesture（拡大率の値しか渡さない）からMagnifyGesture（iOS17〜。
            //   ピンチを始めた位置をstartAnchorとして渡してくれる）に変更した。以前は
            //   scaleEffectのanchorを指定しておらず既定の.center固定だったため、画像の右上を
            //   ピンチしても必ず画像の中央を基準に拡大されてしまっていた（ピンチした場所と
            //   拡大の中心がずれる）。ピンチ開始位置をanchorに使うことで、指でつまんだ場所が
            //   そのまま拡大の中心になるようにする
            .scaleEffect(mediaZoomScale, anchor: mediaZoomAnchor)
            .zIndex(mediaZoomScale > 1 ? 1 : 0)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        mediaZoomAnchor = value.startAnchor
                        mediaZoomScale = max(1, min(mediaLastZoomScale * value.magnification, 3))
                    }
                    .onEnded { _ in
                        mediaLastZoomScale = 1
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            mediaZoomScale = 1
                        }
                    }
            )
            // ★ Instagramと同じく、画像をダブルタップすると常に「いいね」を付ける
            //   （外す方向へは切り替えない一方向の操作）。合わせてハートを一瞬大きく表示して
            //   タップが効いたことを視覚的に伝える
            .onTapGesture(count: 2) {
                if isAnonymous {
                    showAnonymousGate = true
                } else if let currentUid {
                    postViewModel.likeIfNotAlready(post: post, uid: currentUid, actorName: settingsVM.settings.displayName, actorIconURL: settingsVM.settings.iconURL)
                    heartDriver.trigger()
                }
            }
            // ★ シングルタップでは、その場のピンチ拡大（一時的で指を離すと戻る）とは別に、
            //   YouTubeの動画全画面表示と同じ考え方で画像も全画面表示を開く。
            //   全画面側（ZoomableChatImage）は自由な位置を起点にしたピンチ拡大ができる
            .onTapGesture(count: 1) {
                fullScreenImageURL = IdentifiableURL(url: url)
            }
            .overlay {
                DoubleTapHeartOverlay(isActive: heartDriver.isActive, scale: heartDriver.scale, rotation: heartDriver.rotation)
            }
            .accessibilityLabel("投稿画像")
            .accessibilityHint("タップで全画面表示、ダブルタップでいいね")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                fullScreenImageURL = IdentifiableURL(url: url)
            }
        }
    }

    // MARK: - フッター（いいね・コメント・シェア）

    // ★ Instagramのように、画像の左下から始まる横並びのアイコン列にする。
    //   アバター分の字下げは付けず、画像と同じ左端に揃える
    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                if isAnonymous {
                    showAnonymousGate = true
                    return
                }
                guard let currentUid else { return }
                postViewModel.toggleLike(post: post, uid: currentUid, actorName: settingsVM.settings.displayName, actorIconURL: settingsVM.settings.iconURL)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isLiked ? Color(red: 0.95, green: 0.35, blue: 0.55) : .secondary)
                    Text("\(post.likedBy.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isLiked ? "いいね済み" : "いいね")
            .accessibilityValue("\(post.likedBy.count)件")
            .accessibilityAddTraits(.isButton)

            Button {
                if isAnonymous {
                    showAnonymousGate = true
                } else {
                    showComments = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(post.commentCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("コメント")
            .accessibilityValue("\(post.commentCount)件")
            .accessibilityAddTraits(.isButton)

            Spacer(minLength: 0)

            Button {
                if isAnonymous {
                    showAnonymousGate = true
                    return
                }
                guard let currentUid else { return }
                savedPostViewModel.toggleSave(post: post, uid: currentUid)
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSaved ? accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "保存済み" : "投稿を保存")
        }
        .padding(.top, 4)
        .sheet(isPresented: $showComments) {
            PostCommentsSheet(post: post)
        }
        .sheet(isPresented: $showShareSheet) {
            SharePostSheet(post: post, authorName: authorProfile?.displayName ?? "名無しさん")
        }
        // ★ .fullScreenCoverはスワイプで閉じる操作が無く、「ログイン/新規登録する」
        //   （＝匿名セッションの終了）しか選べない一方通行の画面になってしまう。
        //   いいね/保存/コメントはどれも元々.sheetだった操作の代わりに出すゲートなので、
        //   同じ.sheetにして「やっぱり閲覧を続ける」という選択肢を残す
        .sheet(isPresented: $showAnonymousGate) {
            AnonymousLockedView()
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// ★ 「…」メニューの「編集」から開くキャプション編集シート。
//   画像・動画・投稿先グループは変更できず、キャプションのみ書き換えられる
//   （firestore.rulesもcaption以外のフィールド変更は拒否する）
private struct PostCaptionEditSheet: View {
    let post: Post

    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var navState: AppNavigationState
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String

    private let accentColor = Color.oshiniumPrimary
    private let maxLength = 500

    init(post: Post) {
        self.post = post
        _caption = State(initialValue: post.caption ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                // ★ 2026/08/13：投稿作成画面(PostComposerView)をInstagram風の画面中央・大きな
                //   表示に変更したのに合わせ、こちらの見た目も揃える。ただし編集できるのは
                //   キャプションのみで、画像・動画自体は変更できない（追加・削除・入れ替えの
                //   操作は一切持たせない、あくまで確認用の読み取り専用表示）
                if let items = post.mediaItems, items.count > 1 {
                    editMediaCarousel(items)
                    editMediaLockedNotice
                } else if let mediaURL = post.mediaURL, let url = URL(string: mediaURL) {
                    editMediaHero(url: url, isVideo: post.mediaType == "video")
                    editMediaLockedNotice
                }

                ZStack(alignment: .topLeading) {
                    if caption.isEmpty {
                        Text("キャプションを入力")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.top, 10)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $caption)
                        .font(.system(size: 14))
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )

                Text("\(caption.count)/\(maxLength)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("投稿を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        postViewModel.updateCaption(post, newCaption: caption) { error in
                            if error != nil {
                                navState.showToast("保存できませんでした")
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(caption.count > maxLength)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
        }
    }

    // ★ PostComposerView.mediaHeroと同じ「画面幅いっぱいの正方形・角丸20」の枠に揃える。
    //   タップしても何も起きない（追加・削除・差し替えの導線を一切持たない）読み取り専用表示
    private func editMediaHero(url: URL, isVideo: Bool) -> some View {
        Group {
            if isVideo {
                ZStack {
                    VideoThumbnailView(url: url)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                }
            } else {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
    }

    // ★ 複数枚投稿の場合は、editMediaHeroと同じ大きな枠でページめくり式のカルーセルにする。
    //   並び替え・削除用のサムネイル一覧（PostComposerView.mediaThumbnailStrip相当）は
    //   編集不可のためあえて付けない
    private func editMediaCarousel(_ items: [PostMediaItem]) -> some View {
        TabView {
            ForEach(items) { item in
                Group {
                    if item.type == "video", let url = URL(string: item.url) {
                        ZStack {
                            VideoThumbnailView(url: url)
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    } else if let url = URL(string: item.url) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(.systemGray6)
                            }
                        }
                    }
                }
                .clipped()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
    }

    private var editMediaLockedNotice: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("画像・動画は変更できません")
                .font(.system(size: 12))
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - 持ち物テンプレート保存の確認シート
//   ★ 2026/08/21：以前は標準の.confirmationDialog（下からせり上がるシステムのアクションシート）
//   を使っていたが、アプリのデザインコンセプト（高級感×白×純正アップル×少しの立体感）と
//   見た目が揃っていなかったため、AddMethodSelectView等と同じ自作シートのスタイルに揃えた
private struct PackingTemplateSaveConfirmSheet: View {
    let templateName: String
    let items: [String]
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 58, height: 58)
                    Image(systemName: "checklist")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                Text("テンプレートに保存")
                    .font(.system(size: 18, weight: .bold))

                Text("「\(templateName)」をマイテンプレートに保存すると、いつでも自分の持ち物チェックリストとして使えます")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 28)

            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items.prefix(4), id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 9))
                                .foregroundColor(accentColor.opacity(0.6))
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                    if items.count > 4 {
                        Text("ほか\(items.count - 4)件")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentColor.opacity(0.08))
                )
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    Text("保存する")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [accentColor, accentColor.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                            )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(backgroundView)
        .presentationDetents([.height(items.isEmpty ? 300 : 440)])
        .presentationCornerRadius(36)
        .presentationDragIndicator(.visible)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 36)
            .fill(Color.appBackground)
            .overlay(
                ZStack {
                    Circle()
                        .fill(Color.appCardBackground.opacity(0.6))
                        .blur(radius: 40)
                        .offset(x: -120, y: -140)

                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .blur(radius: 60)
                        .offset(x: 140, y: 60)
                }
            )
    }
}
