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
    @State private var showShareSheet = false
    @State private var mediaZoomScale: CGFloat = 1
    @State private var mediaLastZoomScale: CGFloat = 1
    @State private var showReportDialog = false
    @State private var showCaptionEdit = false
    @State private var showDoubleTapHeart = false

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

                VStack(alignment: .leading, spacing: 6) {
                    header

                    if let kind = post.goodsKind, let title = post.goodsTitle {
                        goodsKindBadge(kind: kind, title: title)
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
                }
            }

            mediaView

            footer
        }
        .padding(.vertical, 12)
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
            }
        }
        .animation(.easeInOut(duration: 0.2), value: didSaveTemplate)
        .confirmationDialog(
            "この投稿を報告しますか？",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            ForEach(["スパム・宣伝", "嫌がらせ・誹謗中傷", "不適切な内容", "その他"], id: \.self) { reason in
                Button(reason) {
                    ModerationService.reportPost(
                        postId: post.id,
                        groupId: post.groupId,
                        caption: post.caption ?? "",
                        authorUid: post.authorUid,
                        reason: reason
                    )
                }
            }
            Button("キャンセル", role: .cancel) {}
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

    // MARK: - 持ち物リストカード（テンプレート投稿。長押しで自分のテンプレートに保存できる。
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
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSaveTemplateConfirm = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("長押しでマイテンプレートに保存できます")
    }

    private func saveAsTemplate() {
        guard let currentUid, let items = post.packingTemplateItems, !items.isEmpty else { return }
        let name = post.packingTemplateName ?? "持ち物リスト"

        PackingTemplateViewModel.save(uid: currentUid, name: name, items: items) { error in
            guard error == nil else { return }
            DispatchQueue.main.async {
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

    private func captionAttributedString(_ caption: String) -> AttributedString {
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
            Menu {
                Button {
                    showShareSheet = true
                } label: {
                    Label("シェア", systemImage: "square.and.arrow.up")
                }
                if post.authorUid == currentUid {
                    Button {
                        showCaptionEdit = true
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        postViewModel.deletePost(post)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } else {
                    Button {
                        showReportDialog = true
                    } label: {
                        Label("報告する", systemImage: "exclamationmark.bubble")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(post.authorUid == currentUid ? "投稿を削除" : "投稿を報告")
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

    // MARK: - メディア

    // ★ Threadsのように、メディアが無いテキストのみの投稿もあるため、その場合は何も描画しない
    @ViewBuilder
    private var mediaView: some View {
        if post.mediaType == "video" {
            if isPlayingVideo, let mediaURL = post.mediaURL, let url = URL(string: mediaURL) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 340)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 340)
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                }
            }
            .frame(height: 340)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    showDoubleTapHeart = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showDoubleTapHeart = false
                    }
                }
            }
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 10)
                    .scaleEffect(showDoubleTapHeart ? 1 : 0.4)
                    .opacity(showDoubleTapHeart ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
