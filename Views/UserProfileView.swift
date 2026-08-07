//
//  UserProfileView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import UIKit
import FirebaseFirestore
import FirebaseAuth
import NukeUI

// ★ 他ユーザーのプロフィール閲覧用。マイページタブ（MyPageTab）と見た目・構成を揃え、
//   違いは「編集」→「フォロー」、「シェア」→「メッセージ」に置き換わる点と、
//   右上の「…」設定ボタンが無い点だけにする（編集・ログアウトの導線はここには置かない）
struct UserProfileView: View {
    let uid: String
    var fallbackName: String = "名無しさん"
    var fallbackIconURL: String? = nil

    @EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var postViewModel: PostViewModel

    @State private var settings: UserSettings = .empty
    @State private var isLoading = true

    @State private var groups: [IdolGroup] = []
    @State private var groupsLoaded = false

    @State private var followerCount = 0
    @State private var followingCount = 0

    @State private var selectedPage = 0

    // ★ 通報・ブロック（相手プロフィール画面からいつでも呼べる導線。グループのオーナーかどうかは問わない）
    @State private var showReportDialog = false
    @State private var showReportThanks = false
    @State private var amIBlockingThem = false
    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false

    // ★ MyPageTabと同じ理由：TabView(.page)は自身で高さを取らないため、
    //   ヘッダー（カード＋切り替えバー）と画面全体の高さをそれぞれ測定し、その差分を割り当てる
    @State private var scrollAreaHeight: CGFloat? = nil
    @State private var headerAreaHeight: CGFloat? = nil

    private var pageAreaHeight: CGFloat? {
        guard let scrollAreaHeight, let headerAreaHeight else { return nil }
        return max(scrollAreaHeight - headerAreaHeight, 300)
    }

    private let accentColor = Color.oshiniumPrimary
    private var myUid: String? { Auth.auth().currentUser?.uid }
    private var isMe: Bool { myUid == uid }

    private var visiblePosts: [Post] {
        postViewModel.posts(authorUid: uid)
    }
    // ★ グリッドは画像・動画のある投稿だけ、文字だけの呟きは専用の「つぶやき」ページで見せる
    //   （MyPageTabと同じ構成に揃える）
    private var visiblePostsWithMedia: [Post] {
        visiblePosts.filter { $0.mediaURL != nil }
    }
    private var visibleTweets: [Post] {
        visiblePosts.filter { $0.mediaURL == nil }.sorted { $0.createdAt > $1.createdAt }
    }
    private var totalLikesReceived: Int {
        visiblePosts.reduce(0) { $0 + $1.likedBy.count }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    profileCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    pageSwitcher
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                .background(
                    GeometryReader { headerGeo in
                        Color.clear
                            .onAppear {
                                if headerAreaHeight == nil {
                                    headerAreaHeight = headerGeo.size.height
                                }
                            }
                    }
                )

                if let pageAreaHeight {
                    TabView(selection: $selectedPage) {
                        postsPage.tag(0)
                        tweetsPage.tag(1)
                        groupsPage.tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: pageAreaHeight)
                }
            }
        }
        .background(
            GeometryReader { scrollGeo in
                Color.clear
                    .onAppear {
                        if scrollAreaHeight == nil {
                            scrollAreaHeight = scrollGeo.size.height
                        }
                    }
            }
        )
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isMe {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showReportDialog = true
                        } label: {
                            Label("報告する", systemImage: "exclamationmark.bubble")
                        }

                        if amIBlockingThem {
                            Button {
                                showUnblockConfirm = true
                            } label: {
                                Label("ブロックを解除", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        } else {
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("ブロックする", systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("その他の操作")
                }
            }
        }
        .onAppear {
            loadProfile()
            loadGroups()
            if !isMe { refreshBlockState() }
        }
        .task(id: uid) {
            let counts = await FollowViewModel.fetchCounts(for: uid)
            followerCount = counts.followers
            followingCount = counts.following
        }
        .sheet(isPresented: $showReportDialog) {
            ReportComposerSheet(title: "\(displayName)さんを報告") { reason, detail in
                ModerationService.reportUser(reportedUid: uid, reportedName: displayName, reason: reason, detail: detail)
                showReportThanksBriefly()
            }
        }
        .overlay(alignment: .top) {
            if showReportThanks {
                ReportThanksToast()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showReportThanks)
        .alert("\(displayName)さんをブロックしますか？", isPresented: $showBlockConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("ブロックする", role: .destructive) {
                ModerationService.blockUser(uid) { _ in refreshBlockState() }
            }
        } message: {
            Text("ブロックすると、お互いにメッセージを送れなくなります")
        }
        .alert("\(displayName)さんのブロックを解除しますか？", isPresented: $showUnblockConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("解除する") {
                ModerationService.unblockUser(uid) { _ in refreshBlockState() }
            }
        }
    }

    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
        }
    }

    private func refreshBlockState() {
        ModerationService.amIBlocking(uid) { blocking in
            amIBlockingThem = blocking
        }
    }

    // MARK: - プロフィールカード（MyPageTabのプロフィールカードと同じ構成）
    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                iconView

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 17, weight: .bold))

                        // ★ このプロフィール画面にはMyPageTabのような「今表示中のグループ」の
                        //   概念が無いため、参加中のいずれかのグループで今月トップならバッジを出す
                        if postViewModel.isMonthlyMVP(uid: uid) {
                            CommunityContributorBrooch()
                        }

                        if let tier = postViewModel.bestGoodsBadge(uid: uid) {
                            GoodsRankBadgeView(tier: tier)
                        }

                        if let tier = postViewModel.bestTemplateBadge(uid: uid) {
                            TemplateRankBadgeView(tier: tier)
                        }
                    }

                    if !settings.bio.isEmpty {
                        Text(settings.bio)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            statsRow

            if !cleanedSNSLinks.isEmpty {
                snsBadgeRow
            }

            if !isMe {
                actionButtonsRow
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
        )
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(count: visiblePosts.count, label: "投稿")
                .frame(maxWidth: .infinity)

            statDivider

            // ★ 「いいねした投稿」は本人だけが見られるプライベートな情報にする
            //   （Instagram等と同じ考え方）。他ユーザーのプロフィールでは数字だけを表示し、
            //   タップしても遷移しないようにする
            Group {
                if isMe {
                    NavigationLink {
                        likedPostsList
                    } label: {
                        statColumn(count: totalLikesReceived, label: "いいね")
                    }
                    .buttonStyle(.plain)
                } else {
                    statColumn(count: totalLikesReceived, label: "いいね")
                }
            }
            .frame(maxWidth: .infinity)

            statDivider

            NavigationLink {
                FollowListView(uid: uid, kind: "followers")
            } label: {
                statColumn(count: followerCount, label: "フォロワー")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            statDivider

            NavigationLink {
                FollowListView(uid: uid, kind: "following")
            } label: {
                statColumn(count: followingCount, label: "フォロー中")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.06))
        )
    }

    private var statDivider: some View {
        Divider()
            .frame(height: 26)
    }

    private func statColumn(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var snsBadgeRow: some View {
        HStack(spacing: 10) {
            ForEach(cleanedSNSLinks, id: \.self) { link in
                let platform = SNSPlatform.detect(from: link)
                if let url = URL(string: link) {
                    Link(destination: url) {
                        SNSBadgeIcon(platform: platform, size: 34)
                    }
                } else {
                    SNSBadgeIcon(platform: platform, size: 34)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - フォロー・メッセージボタン（マイページの「編集」「シェア」に相当する行。
    //   相互フォローでなくてもメッセージは送れる。その場合は相手のDM一覧に
    //   「メッセージリクエスト」として表示される）

    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            followButton
            messageButton
        }
    }

    private var isFollowing: Bool { followViewModel.isFollowing(uid) }
    private var isMutual: Bool { followViewModel.isMutual(uid) }

    private var followButton: some View {
        Button {
            guard let myUid else { return }
            if isFollowing {
                followViewModel.unfollow(myUid: myUid, targetUid: uid)
                followerCount = max(0, followerCount - 1)
            } else {
                followViewModel.follow(
                    myUid: myUid,
                    targetUid: uid,
                    myName: settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName,
                    myIconURL: settingsVM.settings.iconURL.isEmpty ? nil : settingsVM.settings.iconURL
                )
                followerCount += 1
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isFollowing ? "checkmark" : "person.badge.plus")
                    .accessibilityHidden(true)
                Text(isFollowing ? (isMutual ? "フォロー中（相互）" : "フォロー中") : "フォロー")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isFollowing ? accentColor : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                Group {
                    if isFollowing {
                        Capsule().stroke(accentColor, lineWidth: 1.3)
                    } else {
                        Capsule().fill(
                            LinearGradient(
                                colors: [accentColor, Color.oshiniumPrimary2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }
            )
        }
    }

    private var messageButton: some View {
        NavigationLink {
            DirectMessageThreadView(
                otherUid: uid,
                otherName: displayName,
                otherIconURL: resolvedIconURL.isEmpty ? nil : resolvedIconURL
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "message.fill")
                    .accessibilityHidden(true)
                Text("メッセージ")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Capsule().stroke(accentColor, lineWidth: 1.3))
        }
    }

    // MARK: - 投稿／参加グループ 切り替えバー（MyPageTabと同じ見た目）
    private var pageSwitcher: some View {
        HStack(spacing: 0) {
            pageIconButton(icon: "square.grid.2x2.fill", label: "投稿", index: 0)
            pageIconButton(icon: "text.bubble.fill", label: "つぶやき", index: 1)
            pageIconButton(icon: "sparkles", label: "参加グループ", index: 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func pageIconButton(icon: String, label: String, index: Int) -> some View {
        let isSelected = selectedPage == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPage = index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(isSelected ? accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: - ページ1：投稿グリッド（Instagramのプロフィールグリッド風。非公開アカウントの場合は
    //   フォローしていない相手には表示されない——firestore.rulesのposts側で実際に
    //   絞り込まれるため、ここではPostViewModel.posts(authorUid:)の結果をそのまま出すだけでよい）

    private var isHiddenByPrivacy: Bool {
        !isMe && settings.isPrivateAccount && !isFollowing
    }

    private var postsPage: some View {
        ScrollView {
            if isHiddenByPrivacy {
                privacyLockedState
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            } else if visiblePostsWithMedia.isEmpty {
                Text("まだ投稿がありません")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: gridSpacing),
                        GridItem(.flexible(), spacing: gridSpacing),
                        GridItem(.flexible(), spacing: gridSpacing)
                    ],
                    spacing: gridSpacing
                ) {
                    ForEach(visiblePostsWithMedia) { post in
                        NavigationLink {
                            PostPagerView(posts: visiblePostsWithMedia, initialPostId: post.id)
                        } label: {
                            postTile(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - ページ2：つぶやき（画像・動画を含まない投稿。非公開アカウントの絞り込みは投稿ページと同じ）
    private var tweetsPage: some View {
        ScrollView {
            if isHiddenByPrivacy {
                privacyLockedState
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            } else if visibleTweets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 30))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("まだつぶやきがありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleTweets.enumerated()), id: \.element.id) { index, post in
                        PostFeedCard(post: post)
                        if index != visibleTweets.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
        }
    }

    private var privacyLockedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.5))
                .accessibilityHidden(true)
            Text("このアカウントは非公開です")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Text("フォローすると投稿が見られるようになります")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private let gridSpacing: CGFloat = 10

    private var tileSide: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return max((screenWidth - 32 - gridSpacing * 2) / 3, 0)
    }

    private func postTile(_ post: Post) -> some View {
        ZStack(alignment: .bottomLeading) {
            if post.mediaType == "video" {
                Color.black.opacity(0.85)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.9))
                    .accessibilityHidden(true)
            } else if let mediaURL = post.mediaURL, let url = URL(string: mediaURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray6)
                    }
                }
            } else {
                LinearGradient(
                    colors: [accentColor, Color.oshiniumPrimary2],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Text(post.caption.nonEmptyOrNil ?? "投稿")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0)],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(height: tileSide * 0.5)

            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .accessibilityHidden(true)
                Text("\(post.likedBy.count)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(8)
        }
        .frame(width: tileSide, height: tileSide)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(profilePostAccessibilityLabel(post))
    }

    private func profilePostAccessibilityLabel(_ post: Post) -> String {
        let kind: String
        if post.mediaType == "video" {
            kind = "動画の投稿"
        } else if post.mediaURL != nil {
            kind = "画像の投稿"
        } else {
            kind = post.caption.nonEmptyOrNil ?? "テキスト投稿"
        }
        return "\(kind)、いいね\(post.likedBy.count)件"
    }

    // MARK: - 「いいね」タップ時：この相手がいいねした投稿一覧
    private var likedPostsList: some View {
        let liked = postViewModel.likedPosts(uid: uid)

        return ScrollView {
            if liked.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "heart")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("いいねした投稿はまだありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(liked.enumerated()), id: \.element.id) { index, post in
                        PostFeedCard(post: post)
                        if index != liked.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
                .padding(16)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("いいねした投稿")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - SNSリンク

    private var cleanedSNSLinks: [String] {
        settings.snsLinks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - ページ2：推しているグループ一覧（丸みのあるカードグリッド）

    private var groupsPage: some View {
        ScrollView {
            groupsSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !groupsLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if groups.isEmpty {
                Text("参加しているグループがありません")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: gridSpacing),
                        GridItem(.flexible(), spacing: gridSpacing),
                        GridItem(.flexible(), spacing: gridSpacing)
                    ],
                    spacing: gridSpacing
                ) {
                    ForEach(groups) { group in
                        NavigationLink {
                            GroupDetailView(group: group)
                        } label: {
                            groupTile(for: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func groupTile(for group: IdolGroup) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let data = group.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: tileSide, height: tileSide)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color.oshiniumPrimary,
                        Color.oshiniumPrimary2
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: tileSide, height: tileSide)
                Text(String(group.name.prefix(1)))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: tileSide, height: tileSide)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.5), Color.black.opacity(0)],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(width: tileSide, height: tileSide * 0.55)

            Text(group.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(width: tileSide, height: tileSide)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private var displayName: String {
        settings.displayName.isEmpty ? fallbackName : settings.displayName
    }

    private var resolvedIconURL: String {
        settings.iconURL.isEmpty ? (fallbackIconURL ?? "") : settings.iconURL
    }

    private var iconView: some View {
        Group {
            if let url = URL(string: resolvedIconURL), !resolvedIconURL.isEmpty {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 78, height: 78)
                            .clipShape(Circle())
                    } else {
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.oshiniumPrimary,
                        Color.oshiniumPrimary2
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 78, height: 78)
            .overlay(
                Text(String(displayName.prefix(1)))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - 読み込み

    private func loadProfile() {
        Firestore.firestore().collection("users").document(uid).getDocument { snapshot, error in
            guard let data = snapshot?.data() else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            let loaded = UserSettings(
                displayName: data["displayName"] as? String ?? "",
                bio: data["bio"] as? String ?? "",
                iconURL: data["iconURL"] as? String ?? "",
                birthday: data["birthday"] as? String ?? "",
                snsLinks: data["snsLinks"] as? [String] ?? [],
                defaultNotifyMinutes: data["defaultNotifyMinutes"] as? Int,
                isPrivateAccount: data["isPrivateAccount"] as? Bool ?? false
            )

            DispatchQueue.main.async {
                self.settings = loaded
                self.isLoading = false
            }
        }
    }

    // MARK: - 参加グループ一覧の単発取得

    private func loadGroups() {
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("selectedGroups")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { self.groupsLoaded = true }
                    return
                }

                let loaded: [IdolGroup] = docs.map { doc in
                    let data = doc.data()

                    var imageData: Data? = nil
                    if let raw = data["imageData"] as? Data {
                        imageData = raw
                    } else if let base64 = data["imageData"] as? String {
                        imageData = Data(base64Encoded: base64)
                    }

                    return IdolGroup(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Unknown",
                        imageData: imageData,
                        reading: data["reading"] as? String,
                        fandom: data["fandom"] as? String,
                        concept: data["concept"] as? String,
                        history: data["history"] as? String,
                        groupDescription: data["groupDescription"] as? String,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                    )
                }

                DispatchQueue.main.async {
                    self.groups = loaded
                    self.groupsLoaded = true
                }
            }
    }
}
