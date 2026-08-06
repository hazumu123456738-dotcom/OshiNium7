//
//  GoodsPenlightHubView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI
import FirebaseAuth
import NukeUI

// ★ 旧「応援ペンライト」ツールの入り口を拡張した「推し活ペンライト・グッズ」ハブ。
//   ①ライブ会場で使う発光モード（既存のPenlightModeViewをそのまま流用）と、
//   ②オリジナルでデコレーションしたペンライト・手作りグッズを見せ合うショーケース、
//   の2つを1つのツールにまとめる。ショーケースは横3列のカードで縦に積み重なっていき、
//   被いいね数の多いユーザーはランキング上位3名として表彰・バッジ付与される
struct GoodsPenlightHubView: View {
    let group: IdolGroup?

    @EnvironmentObject var postViewModel: PostViewModel
    @State private var showPenlightMode = false
    @State private var showComposer = false

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private let accentColor = Color(red: 0.60, green: 0.45, blue: 0.90)
    private let accentColor2 = Color(red: 0.85, green: 0.50, blue: 0.85)
    private let gridSpacing: CGFloat = 10

    private var tileSide: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return max((screenWidth - 32 - gridSpacing * 2) / 3, 0)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: gridSpacing), GridItem(.flexible(), spacing: gridSpacing), GridItem(.flexible(), spacing: gridSpacing)]
    }

    private var groupPosts: [Post] {
        guard let group else { return [] }
        return postViewModel.goodsPosts(groupId: group.id)
    }

    private var ranking: [(uid: String, total: Int)] {
        guard let group else { return [] }
        return postViewModel.goodsRanking(groupId: group.id)
    }

    var body: some View {
        Group {
            if let group {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        lightModeCard
                        if !ranking.isEmpty {
                            rankingCard
                        }
                        showcaseSection(group: group)
                    }
                    .padding(16)
                    .padding(.bottom, customTabBarHeight)
                }
                .background(Color.appBackground.ignoresSafeArea())
            } else {
                noGroupState
            }
        }
        .navigationTitle("推し活ペンライト・グッズ")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPenlightMode) {
            PenlightModeView()
        }
        .sheet(isPresented: $showComposer) {
            if let group {
                NavigationStack {
                    PostComposerView(group: group, initialKind: .penlight)
                }
            }
        }
    }

    // MARK: - 発光モードへの入り口

    private var lightModeCard: some View {
        Button {
            showPenlightMode = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "flashlight.on.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("発光モード")
                        .font(.system(size: 14, weight: .bold))
                    Text("会場で振れる応援ペンライト")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - ランキング（被いいね上位3名）

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("いいねランキング", systemImage: "medal.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(ranking.prefix(3).enumerated()), id: \.element.uid) { index, entry in
                    rankingRow(rank: index, uid: entry.uid, total: entry.total)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func rankingRow(rank: Int, uid: String, total: Int) -> some View {
        let tier: GoodsRankBadgeTier = rank == 0 ? .gold : (rank == 1 ? .silver : .bronze)
        return NavigationLink {
            UserProfileView(uid: uid)
        } label: {
            HStack(spacing: 10) {
                GoodsRankBadgeView(tier: tier, size: 26)
                GoodsPosterNameLabel(uid: uid)
                Spacer(minLength: 0)
                Text("\(total)いいね")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - ショーケース（横3列グリッド）

    private func showcaseSection(group: IdolGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(group.name)のペンライト・グッズ", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showComposer = true
                } label: {
                    Label("投稿する", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }

            if groupPosts.isEmpty {
                emptyShowcaseState
            } else {
                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    ForEach(groupPosts) { post in
                        showcaseCard(post)
                    }
                }
            }
        }
    }

    private var emptyShowcaseState: some View {
        VStack(spacing: 8) {
            Image(systemName: "flashlight.off.fill")
                .font(.system(size: 28))
                .foregroundColor(accentColor.opacity(0.3))
                .accessibilityHidden(true)
            Text("まだ投稿がありません")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func showcaseCard(_ post: Post) -> some View {
        NavigationLink {
            GoodsPostDetailView(post: post)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                LazyImage(url: URL(string: post.mediaURL ?? "")) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                    }
                }
                .frame(width: tileSide, height: tileSide)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipped()
                .accessibilityHidden(true)

                Text(post.goodsTitle ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.55))
                        .accessibilityHidden(true)
                    Text("\(post.likedBy.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(post.goodsTitle ?? "")、\(post.likedBy.count)いいね")
            .frame(width: tileSide, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var noGroupState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "flashlight.on.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
                .accessibilityHidden(true)
            Text("ホーム画面でグループを選択してください")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// ★ ランキング行に出す投稿者名。users/{uid}を直接見て取得する軽量ラベル
private struct GoodsPosterNameLabel: View {
    let uid: String
    @State private var name: String = "…"

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary)
            .task {
                if let profile = await ChatViewModel.fetchUserProfile(uid: uid) {
                    name = profile.displayName
                }
            }
    }
}
