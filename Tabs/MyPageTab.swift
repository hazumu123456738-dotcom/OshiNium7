//
//  MyPageTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI
import UIKit
import FirebaseAuth
import NukeUI

struct MyPageTab: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    // ★ ここで独自にインスタンスを作ると、ChatRoomView等が参照するアプリ共有の
    //   UserSettingsViewModel と別物になり、名前などが同期されなくなるためEnvironmentObjectで共有する
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var savedPostViewModel: SavedPostViewModel
    @EnvironmentObject var followViewModel: FollowViewModel

    // ★ ホーム画面で選択中のグループ。連動して、投稿タブもそのグループの投稿だけを表示する
    let selectedGroup: IdolGroup?

    @State private var showEditProfile = false
    @State private var showShareProfile = false
    @State private var showComposer = false
    @State private var showGroupManager = false
    @State private var showManageMenu = false
    @State private var selectedPage = 0

    // ★ プル・トゥ・リフレッシュをプロフィールカードより上（画面最上部）から
    //   引っ張れるようにするため、画面全体をScrollViewで包む。TabView(.page)は自身で
    //   高さを取らないため、ヘッダー（カード＋切り替えバー）と画面全体の高さを
    //   それぞれ最初の1回だけ測定し、その差分をTabViewに割り当てる。
    //   ★ GeometryReaderでScrollView全体を「包む」方式は、他の兄弟ビューの固定サイズに
    //     引っ張られて計測値が実際より小さくなることがあるため使わず、ScrollView自体の
    //     .background(GeometryReader)として計測する（カレンダータブで実際に踏んだ問題を回避）
    @State private var scrollAreaHeight: CGFloat? = nil
    @State private var headerAreaHeight: CGFloat? = nil

    private var pageAreaHeight: CGFloat? {
        guard let scrollAreaHeight, let headerAreaHeight else { return nil }
        return max(scrollAreaHeight - headerAreaHeight, 300)
    }

    private let accentColor = Color.oshiniumPrimary

    private var myUid: String? { Auth.auth().currentUser?.uid }
    // ★ マイページはグループを切り替えても内容が変わらない共通ページにする。
    //   以前は選択中グループでフィルタしていたため、グループを切り替えると
    //   投稿数やいいね数が変わって見えてしまっていた
    private var myPosts: [Post] {
        guard let myUid else { return [] }
        return postViewModel.posts(authorUid: myUid)
    }
    private var totalLikesReceived: Int {
        myPosts.reduce(0) { $0 + $1.likedBy.count }
    }

    var body: some View {
        NavigationStack {
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

                    // ★ pageAreaHeightが確定するまではTabViewを生成しない。
                    //   仮の高さで先に生成すると、各ページ内部のグリッドレイアウトが
                    //   ズレたまま固定されてしまう
                    if let pageAreaHeight {
                        TabView(selection: $selectedPage) {
                            postsPage.tag(0)
                            groupsPage.tag(1)
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
            // ★ プロフィールカードより上（画面最上部）から引っ張って再読み込みできるようにする
            .refreshable {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            .background(Color.appBackground.ignoresSafeArea())
            // ★ 表示名はプロフィールカードの中にすでに大きく出ているため、
            //   ナビゲーションバーには重ねて「マイページ」の文字を出さない。
            //   その分プロフィールカードを画面上部に詰めて表示できるようにする
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ★ 投稿グリッド・グループグリッドの中にあった「投稿する」「グループを追加」タイルを
                //   左上のツールバーに移動。その分グリッドは実際の投稿・グループだけを詰めて表示する
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("投稿する")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showGroupManager = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("推しグループを追加")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        savedPostsList
                    } label: {
                        Image(systemName: "bookmark")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("保存した投稿")
                }
                // ★ ログアウトはカレンダータブと同じ「…」管理メニューの中の一機能にする
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showManageMenu = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("設定")
                }
            }
        }
        .onAppear {
            settingsVM.loadSettings()
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationStack {
                UserSettingsView(viewModel: settingsVM)
            }
        }
        .sheet(isPresented: $showShareProfile) {
            NavigationStack {
                ShareProfileView(
                    uid: myUid ?? "",
                    displayName: settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName,
                    iconURL: settingsVM.settings.iconURL.isEmpty ? nil : settingsVM.settings.iconURL
                )
            }
        }
        .sheet(isPresented: $showComposer) {
            NavigationStack {
                PostComposerView(defaultGroupId: selectedGroup?.id)
                    .environmentObject(groupViewModel)
                    .environmentObject(postViewModel)
                    .environmentObject(settingsVM)
            }
        }
        .sheet(isPresented: $showGroupManager) {
            GroupsTab()
                .environmentObject(groupViewModel)
        }
        .sheet(isPresented: $showManageMenu) {
            MyPageManageMenuView {
                authViewModel.logout()
            }
        }
    }

    // MARK: - プロフィールカード（アイコン・統計・自己紹介・編集ボタンをまとめた高級感のあるカード）
    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                iconView

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(settingsVM.settings.displayName.isEmpty ? "名前未設定" : settingsVM.settings.displayName)
                            .font(.system(size: 17, weight: .bold))

                        // ★ 月末集計でアプリ全体の被いいね数が上位5%に入っていた月だけ、
                        //   コミュニティ貢献者の証としてこのブローチが着く
                        if let myUid, postViewModel.isTopContributor(uid: myUid) {
                            CommunityContributorBrooch()
                        }

                        // ★ 「推し活ペンライト・グッズ」のいずれかのグループで
                        //   被いいねランキング3位以内に入っていると着くバッジ
                        if let myUid, let tier = postViewModel.bestGoodsBadge(uid: myUid) {
                            GoodsRankBadgeView(tier: tier)
                        }
                    }

                    if !settingsVM.settings.bio.isEmpty {
                        Text(settingsVM.settings.bio)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            // ★ 以前はアイコン横の狭いスペースに横スクロールで詰め込んでいたため、
            //   スクロールしないと「参加グループ」まで見えなかった。カード全幅を使う
            //   独立した行にし、Spacerで均等配置することでスクロール無しで全部入り切るようにする
            statsRow

            if !cleanedSNSLinks.isEmpty {
                snsBadgeRow
            }

            profileActionButtons
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
        )
    }

    private var cleanedSNSLinks: [String] {
        settingsVM.settings.snsLinks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    // ★ 「参加グループ」は表示不要になったため外し、残り4項目
    //   （投稿・いいね・フォロワー・フォロー中）を等幅4列＋区切り線で規則的に揃える
    private var statsRow: some View {
        HStack(spacing: 0) {
            // ★ 下のグリッドは画像・動画がある投稿しかサムネイル表示できないため、
            //   文字だけの呟きも含めた全投稿を日時順に見られる一覧をここから開けるようにする
            NavigationLink {
                myPostsList
            } label: {
                statColumn(count: myPosts.count, label: "投稿")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            statDivider

            if let myUid {
                NavigationLink {
                    likedPostsList(uid: myUid)
                } label: {
                    statColumn(count: totalLikesReceived, label: "いいね")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                statColumn(count: totalLikesReceived, label: "いいね")
                    .frame(maxWidth: .infinity)
            }

            if let myUid {
                statDivider

                NavigationLink {
                    FollowListView(uid: myUid, kind: "followers")
                } label: {
                    statColumn(count: followViewModel.followerIds.count, label: "フォロワー")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                statDivider

                NavigationLink {
                    FollowListView(uid: myUid, kind: "following")
                } label: {
                    statColumn(count: followViewModel.followingIds.count, label: "フォロー中")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
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

    private var iconView: some View {
        Group {
            if let url = URL(string: settingsVM.settings.iconURL), !settingsVM.settings.iconURL.isEmpty {
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
                Text(String(settingsVM.settings.displayName.prefix(1)))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - 編集・シェアボタン（以前は1つの「プロフィールを編集」ボタンだったが、
    //   自分を認知してもらう＝フォローしてもらうための「プロフィールをシェア」を
    //   独立したボタンとして分割した）
    private var profileActionButtons: some View {
        HStack(spacing: 10) {
            editProfileButton
            shareProfileButton
        }
    }

    private var editProfileButton: some View {
        Button {
            showEditProfile = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .accessibilityHidden(true)
                Text("編集")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                LinearGradient(
                    colors: [accentColor, Color.oshiniumPrimary2],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
        }
    }

    private var shareProfileButton: some View {
        Button {
            showShareProfile = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "qrcode")
                    .accessibilityHidden(true)
                Text("シェア")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Capsule().stroke(accentColor, lineWidth: 1.3))
        }
    }


    // MARK: - 投稿／参加グループ 切り替えバー
    private var pageSwitcher: some View {
        HStack(spacing: 0) {
            pageIconButton(icon: "square.grid.2x2.fill", label: "投稿", index: 0)
            pageIconButton(icon: "sparkles", label: "参加グループ", index: 1)
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

    // MARK: - ページ1：投稿グリッド
    private var postsPage: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: gridSpacing),
                    GridItem(.flexible(), spacing: gridSpacing),
                    GridItem(.flexible(), spacing: gridSpacing)
                ],
                spacing: gridSpacing
            ) {
                ForEach(myPosts) { post in
                    NavigationLink {
                        myPostDetail(post)
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
        // ★ プル・トゥ・リフレッシュは画面全体（外側のScrollView）が担うため、
        //   ここでは重ねて付けない
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
                // ★ Threadsのようなテキストのみの投稿は、キャプションをそのままタイルに敷いて見せる
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
        .accessibilityLabel(postAccessibilityLabel(post))
    }

    // ★ ビデオ投稿はサムネイルにテキストが無く、そのままだと「いいね数」しか読み上げられない。
    //   種類（動画／画像／キャプション）が伝わるよう明示的なラベルを組み立てる
    private func postAccessibilityLabel(_ post: Post) -> String {
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

    private func myPostDetail(_ post: Post) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PostFeedCard(post: post)

                Button(role: .destructive) {
                    postViewModel.deletePost(post)
                } label: {
                    Text("投稿を削除")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 「いいね」タップ時：自分がいいねした投稿一覧（Threadsスタイルの1枚のコンテナ）

    private func likedPostsList(uid: String) -> some View {
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

    // ★ 自分の全投稿を日時順に見られる一覧。下のグリッドは画像・動画のある投稿しか
    //   サムネイル表示できないため、文字だけの呟きもここでなら振り返れる
    private var myPostsList: some View {
        let mine = myPosts.sorted { $0.createdAt > $1.createdAt }

        return ScrollView {
            if mine.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("まだ投稿がありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(mine.enumerated()), id: \.element.id) { index, post in
                        PostFeedCard(post: post)
                        if index != mine.count - 1 {
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
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ★ 保存（ブックマーク）した投稿の一覧。likedPostsListと同じ構成
    private var savedPostsList: some View {
        let saved = postViewModel.posts
            .filter { savedPostViewModel.savedPostIds.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }

        return ScrollView {
            if saved.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("保存した投稿はまだありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(saved.enumerated()), id: \.element.id) { index, post in
                        PostFeedCard(post: post)
                        if index != saved.count - 1 {
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
        .navigationTitle("保存した投稿")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - ページ2：参加グループ一覧（丸みのあるカードグリッド）
    private var groupsPage: some View {
        ScrollView {
            groupsSection
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
        }
        // ★ プル・トゥ・リフレッシュは画面全体（外側のScrollView）が担うため、
        //   ここでは重ねて付けない
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if groupViewModel.groups.isEmpty {
                Text("まだ参加しているグループがありません。まずは推しのグループを追加しましょう")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: gridSpacing),
                    GridItem(.flexible(), spacing: gridSpacing),
                    GridItem(.flexible(), spacing: gridSpacing)
                ],
                spacing: gridSpacing
            ) {
                ForEach(groupViewModel.groups) { group in
                    NavigationLink {
                        GroupDetailView(group: group)
                    } label: {
                        groupTile(for: group, side: tileSide)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private let gridSpacing: CGFloat = 10

    private var tileSide: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return max((screenWidth - 32 - gridSpacing * 2) / 3, 0)
    }

    // MARK: - 参加グループタイル（角丸カード＋柔らかい影）
    private func groupTile(for group: IdolGroup, side: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let data = group.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
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
                .frame(width: side, height: side)
                Text(String(group.name.prefix(1)))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: side, height: side)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.5), Color.black.opacity(0)],
                startPoint: .bottom,
                endPoint: .center
            )
            .frame(width: side, height: side * 0.55)

            Text(group.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
