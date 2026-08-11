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
    private var isLiked: Bool {
        guard let currentUid else { return false }
        return post.likedBy.contains(currentUid)
    }
    private var isSaved: Bool { savedPostViewModel.isSaved(post.id) }

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
                        fallbackIconURL: authorProfile?.iconURL
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

            // ★ キャプション等が無い画像単体の投稿では、ヘッダーの「…」ボタンと画像の間が
            //   VStackの標準spacing(6pt)だけになり、物理的に近すぎて「…」を狙ったタップが
            //   画像側のダブルタップ(いいね)判定に化けやすかった。ここだけ余分に間隔を空ける
            mediaView
                .padding(.top, 10)

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
        .confirmationDialog(
            "「\(post.packingTemplateName ?? "持ち物リスト")」をテンプレートに保存しますか？",
            isPresented: $showSaveTemplateConfirm,
            titleVisibility: .visible
        ) {
            Button("保存する") { saveAsTemplate() }
            Button("キャンセル", role: .cancel) {}
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
                    colors: [Color(red: 0.60, green: 0.45, blue: 0.90), Color(red: 0.85, green: 0.50, blue: 0.85)],
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
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "¥" + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
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
            postViewModel.likeIfNotAlready(post: post, uid: currentUid)
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
                        postViewModel.deletePost(post)
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

    private var avatar: some View {
        Group {
            if let url = authorProfile?.iconURL.flatMap(URL.init) {
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
            } else {
                ZStack {
                    Color.black.opacity(0.85)
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
        }
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
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)

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
            .scaleEffect(mediaZoomScale)
            .zIndex(mediaZoomScale > 1 ? 1 : 0)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        mediaZoomScale = max(1, min(mediaLastZoomScale * value, 3))
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
                if let currentUid {
                    postViewModel.likeIfNotAlready(post: post, uid: currentUid)
                }
                heartDriver.trigger()
            }
            .overlay {
                DoubleTapHeartOverlay(isActive: heartDriver.isActive, scale: heartDriver.scale, rotation: heartDriver.rotation)
            }
            .accessibilityLabel("投稿画像")
            .accessibilityHint("ダブルタップでいいね、ピンチで拡大できます")
        }
    }

    // MARK: - フッター（いいね・コメント・シェア）

    // ★ Instagramのように、画像の左下から始まる横並びのアイコン列にする。
    //   アバター分の字下げは付けず、画像と同じ左端に揃える
    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                guard let currentUid else { return }
                postViewModel.toggleLike(post: post, uid: currentUid)
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
                showComments = true
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
            SharePostSheet(post: post, shareText: shareText)
        }
    }

    // ★ 投稿にはウェブ上の固有URLが無いため、キャプション本文をシェアする
    //   （EventDetailViewのShareLinkと同じ考え方）
    private var shareText: String {
        var lines: [String] = []
        if let name = authorProfile?.displayName, !name.isEmpty {
            lines.append("\(name)さんの投稿（\(post.groupName)）")
        } else {
            lines.append("\(post.groupName)への投稿")
        }
        if let caption = post.caption, !caption.isEmpty {
            lines.append(caption)
        }
        if let mediaURL = post.mediaURL, !mediaURL.isEmpty {
            lines.append(mediaURL)
        }
        lines.append("via OshiNium")
        return lines.joined(separator: "\n")
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
                if let mediaURL = post.mediaURL, let url = URL(string: mediaURL) {
                    HStack(spacing: 10) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(.systemGray6)
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Text("画像・動画は変更できません")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
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
                        postViewModel.updateCaption(post, newCaption: caption)
                        dismiss()
                    }
                    .disabled(caption.count > maxLength)
                    .fontWeight(.semibold)
                    .foregroundColor(accentColor)
                }
            }
        }
    }
}
