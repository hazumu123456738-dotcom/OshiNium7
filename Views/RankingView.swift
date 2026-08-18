//
//  RankingView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import SwiftUI
import NukeUI
import FirebaseAuth

// ★ ホーム画面の王冠アイコンから開く、選択中グループ内のランキング画面。
//   専用のFirestoreコレクションは持たず、既に購読済みのpostViewModel.posts /
//   eventViewModel.eventsをその場で集計して表示する（新しい書き込み・リスナーは増やさない）
struct RankingView: View {
    let group: IdolGroup?

    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var profiles: [String: ChatViewModel.RemoteUserProfile] = [:]
    // ★ グッズ・投稿いいねランキングはpostViewModel.postsを集計元にしており、そちらは
    //   既にブロック済みユーザーの投稿を除外済み。一方コミュニティ貢献度ランキングは
    //   eventViewModel.eventsを直接集計するため、ここだけ別途ブロック一覧を見て除外する
    @State private var blockedUids: Set<String> = []

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2
    private let goldColor = Color(red: 0.85, green: 0.65, blue: 0.20)
    private let silverColor = Color(red: 0.62, green: 0.65, blue: 0.68)
    private let bronzeColor = Color(red: 0.72, green: 0.48, blue: 0.30)

    private var groupPosts: [Post] {
        guard let group else { return [] }
        return postViewModel.posts.filter { $0.groupId == group.id }
    }

    // ★ 発見(全画面調査)：以前はここが全期間の集計だったのに、下のbadgeExplanationCardの
    //   文言は「今月いいねを一番集めた人」と説明しており、実際のバッジ付与ロジック
    //   (PostViewModel.monthlyGoodsRanking/monthlyLikeRanking)は今月分だけを見ている。
    //   そのため画面上の1位と実際にバッジが付いている人が食い違って見えることがあった。
    //   バッジロジックと同じ「今月」の絞り込みに揃える
    private var monthlyGroupPosts: [Post] {
        let calendar = Calendar.current
        let now = Date()
        return groupPosts.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
    }

    // ★ グッズ・ペンライトの投稿を、いいね数が多い順に並べたもの(今月分のみ)
    private var goodsRanking: [Post] {
        Array(
            monthlyGroupPosts
                .filter { $0.goodsKind != nil }
                .sorted { $0.likedBy.count > $1.likedBy.count }
                .prefix(5)
        )
    }

    // ★ 投稿者ごとの被いいね数合計ランキング(今月分のみ、バッジ付与ロジックと同じ集計)
    private var userLikeRanking: [(uid: String, value: Int)] {
        postViewModel.monthlyLikeRanking(groupId: group?.id ?? "")
            .prefix(5)
            .map { (uid: $0.uid, value: $0.total) }
    }

    // ★ コミュニティカレンダーへの予定追加数ランキング（秘密の予定は個人的なメモなので対象外）
    private var eventContributionRanking: [(uid: String, value: Int)] {
        guard let group else { return [] }
        var counts: [String: Int] = [:]
        for event in eventViewModel.events where event.groupId == group.id && !event.isSecret {
            guard let uid = event.creatorUid, !blockedUids.contains(uid) else { continue }
            counts[uid, default: 0] += 1
        }
        return Array(
            counts.sorted { $0.value > $1.value }
                .prefix(5)
                .map { (uid: $0.key, value: $0.value) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if group == nil {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        badgeExplanationCard

                        rankingSection(title: "グッズ・ペンライトいいねランキング", icon: "gift.fill") {
                            if goodsRanking.isEmpty {
                                emptyRow("まだグッズ・ペンライトの投稿がありません")
                            } else {
                                ForEach(Array(goodsRanking.enumerated()), id: \.element.id) { index, post in
                                    goodsRankRow(rank: index + 1, post: post)
                                }
                            }
                        }

                        rankingSection(title: "投稿いいね数ランキング", icon: "heart.fill") {
                            if userLikeRanking.isEmpty {
                                emptyRow("まだ投稿がありません")
                            } else {
                                ForEach(Array(userLikeRanking.enumerated()), id: \.offset) { index, entry in
                                    userRankRow(rank: index + 1, uid: entry.uid, value: entry.value, unit: "いいね")
                                }
                            }
                        }

                        rankingSection(title: "コミュニティ貢献度ランキング", icon: "calendar.badge.plus") {
                            if eventContributionRanking.isEmpty {
                                emptyRow("まだ予定の追加がありません")
                            } else {
                                ForEach(Array(eventContributionRanking.enumerated()), id: \.offset) { index, entry in
                                    userRankRow(rank: index + 1, uid: entry.uid, value: entry.value, unit: "件追加")
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("ランキング")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .task {
                ModerationService.fetchBlockedUids { uids in
                    DispatchQueue.main.async {
                        blockedUids = uids
                    }
                }
                await loadProfiles()
            }
        }
    }

    // MARK: - 空状態（グループ未選択）

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown")
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
            Text("グループを選択すると、ランキングが表示されます")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - 「1位になるとどうなるか」の詳しい説明
    //   ★ ランキングの3セクションのうち、実際にバッジが付与されるのは上2つだけ
    //   （グッズ・ペンライト＝金銀バッジ、投稿いいね数＝ダイアモンドバッジ）。
    //   コミュニティ貢献度は現状バッジ付与の対象外のため、無い物をあると誤解させないよう
    //   正直にそう明記する。バッジは月ごとにリセットされ、プロフィールの名前の横に表示される
    private var badgeExplanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(goldColor)
                Text("ランキング1位・2位になるともらえるバッジ")
                    .font(.system(size: 14, weight: .bold))
            }

            badgeExplanationRow(
                badge: AnyView(simpleDiamondIcon(
                    color: goldColor,
                    secondaryColor: Color(red: 0.97, green: 0.85, blue: 0.55)
                )),
                title: "グッズ・ペンライトいいねランキング",
                detail: "今月、いいねを一番集めたグッズ・ペンライト投稿の投稿者に金バッジ、2位に銀バッジが付きます。"
            )

            badgeExplanationRow(
                badge: AnyView(simpleDiamondIcon(color: accentColor, secondaryColor: accentColor2)),
                title: "投稿いいね数ランキング",
                detail: "そのグループで今月一番いいねを集めた投稿者に、ダイアモンドバッジが付きます。"
            )

            badgeExplanationRow(
                badge: AnyView(simpleDiamondIcon(
                    color: Color(red: 0.55, green: 0.55, blue: 0.58),
                    secondaryColor: Color(red: 0.82, green: 0.83, blue: 0.85)
                )),
                title: "コミュニティ貢献度ランキング",
                detail: "現在この項目にはバッジはありません(予定を追加した件数の目安として表示しています)。"
            )

            Text("バッジは毎月リセットされ、プロフィールの名前の横に表示されます。バッジの対象になれるのはグループのメンバー全員です。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ 「もらえるバッジ」説明カードだけで使う、立体的なダイヤモンドアイコン。
    //   オシニウムタブ(OshiNiumTabView.originalTabButton)と同じBrilliantDiamondIcon
    //   (BrilliantGemShape=カット面のあるダイヤモンド輪郭+BrilliantGemFacetLines=
    //   ファセット線)を流用し、アプリの「顔」であるオシニウムタブと世界観を揃える。
    //   単色のsystemImageと違い、グラデーション+光沢のハイライト+影を重ねることで
    //   宝石らしい立体感を出す
    private func simpleDiamondIcon(color: Color, secondaryColor: Color) -> some View {
        ZStack {
            BrilliantDiamondIcon(
                fill: AnyShapeStyle(
                    LinearGradient(colors: [secondaryColor, color], startPoint: .topLeading, endPoint: .bottomTrailing)
                ),
                strokeColor: .white
            )

            // 光沢(左上のハイライト)を重ね、より立体的に見せる
            BrilliantGemShape()
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0)], startPoint: .topLeading, endPoint: .center)
                )
                .blendMode(.plusLighter)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(width: 32, height: 32)
        .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 2)
    }

    private func badgeExplanationRow(badge: AnyView, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            badge
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - セクション共通の見出し＋カード

    private func rankingSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }

            VStack(spacing: 8) {
                content()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [accentColor.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .glossyHighlight(cornerRadius: 20)
    }

    // ★ 1位の行だけ、金色の光沢感のある背景で軽く強調する(2位以下との差を視覚的に出す)
    @ViewBuilder
    private func rankRowBackground(rank: Int) -> some View {
        if rank == 1 {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [goldColor.opacity(0.16), goldColor.opacity(0.04)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(goldColor.opacity(0.35), lineWidth: 1)
                )
        } else {
            Color.clear
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    // MARK: - グッズ・ペンライトの行（投稿の写真＋名前＋いいね数）

    private func goodsRankRow(rank: Int, post: Post) -> some View {
        HStack(spacing: 12) {
            rankBadge(rank)

            if let urlString = post.mediaURL, let url = URL(string: urlString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray6)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.goodsTitle ?? post.goodsKind ?? "グッズ")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(profiles[post.authorUid]?.displayName ?? "…")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.55))
                Text("\(post.likedBy.count)")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(6)
        .background(rankRowBackground(rank: rank))
    }

    // MARK: - ユーザー単位の行（被いいね数・貢献度で共通利用）

    private func userRankRow(rank: Int, uid: String, value: Int, unit: String) -> some View {
        NavigationLink {
            UserProfileView(
                uid: uid,
                fallbackName: profiles[uid]?.displayName ?? "名無しさん",
                fallbackIconURL: profiles[uid]?.iconURL
            )
        } label: {
            HStack(spacing: 12) {
                rankBadge(rank)

                userAvatar(uid, ringColor: rank == 1 ? goldColor : nil)

                Text(profiles[uid]?.displayName ?? "…")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Spacer(minLength: 8)

                Text("\(value)\(unit)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(rank == 1 ? goldColor : accentColor)
            }
            .padding(8)
            .background(rankRowBackground(rank: rank))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func userAvatar(_ uid: String, ringColor: Color? = nil) -> some View {
        Group {
            if let url = profiles[uid]?.iconURL.flatMap(URL.init) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray4)
                    }
                }
            } else {
                Color(.systemGray4)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(ringColor ?? .clear, lineWidth: ringColor == nil ? 0 : 2)
        )
        .shadow(color: (ringColor ?? .clear).opacity(0.5), radius: ringColor == nil ? 0 : 5, x: 0, y: 0)
    }

    // ★ 1〜3位は金・銀・銅のメダル風バッジ(グラデーション+光沢)、4位以降は単なる番号にする。
    //   1位だけ王冠を一回り大きくし、微かな光彩(shadow)を添えて「殿堂」感を出す
    private func rankBadge(_ rank: Int) -> some View {
        let color: Color = rank == 1 ? goldColor : (rank == 2 ? silverColor : (rank == 3 ? bronzeColor : .secondary))
        return Group {
            if rank <= 3 {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.65)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: color.opacity(rank == 1 ? 0.55 : 0.25), radius: rank == 1 ? 6 : 3, x: 0, y: 2)
                    Image(systemName: "crown.fill")
                        .font(.system(size: rank == 1 ? 14 : 12))
                        .foregroundColor(.white)
                }
            } else {
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: rank == 1 ? 30 : 26, height: rank == 1 ? 30 : 26)
    }

    // MARK: - 表示に必要なユーザープロフィールをまとめて取得

    private func loadProfiles() async {
        var uids = Set(goodsRanking.map(\.authorUid))
        uids.formUnion(userLikeRanking.map(\.uid))
        uids.formUnion(eventContributionRanking.map(\.uid))
        uids.subtract(profiles.keys)
        guard !uids.isEmpty else { return }

        await withTaskGroup(of: (String, ChatViewModel.RemoteUserProfile?).self) { taskGroup in
            for uid in uids {
                taskGroup.addTask {
                    (uid, await ChatViewModel.fetchUserProfile(uid: uid))
                }
            }
            for await (uid, profile) in taskGroup {
                if let profile {
                    profiles[uid] = profile
                }
            }
        }
    }
}
