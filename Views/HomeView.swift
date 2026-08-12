//
//  HomeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import SwiftUI
import UIKit
import FirebaseAuth

struct HomeView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var navState: AppNavigationState
    @EnvironmentObject var notificationViewModel: AppNotificationViewModel

    @Binding var selectedDate: Date
    @Binding var selectedGroup: IdolGroup?
    @Binding var showAddEvent: Bool

    @State private var showPostSearch = false
    @State private var showRanking = false
    // ★ 上に引っ張って再読み込みしている間だけ、OshiNiumの文字が左から描かれる
    //   独自ローディング表示を出す。投稿はFirestoreのリスナーで既に常に最新なので、
    //   ここでの「再読み込み」は改めて取得し直すというより「最新であることの確認演出」
    @State private var isRefreshing = false

    // ★ ホームの「今日の予定」「直近1週間の予定」は複数カレンダー（プライベート／コミュニティ／
    //   共有カレンダー）を横断表示するため、カレンダータブと違って「どのカレンダーの予定か」が
    //   一見して分からず「カレンダータブに出ていない」という誤解を招いていた。行にラベルを出すために
    //   FullCalendarTab.swiftと同じパターンでローカルに保持する
    @StateObject private var calendarViewModel = CalendarViewModel()

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    var isOwner: Bool = true

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        mainContent
        .onAppear {
            if selectedGroup == nil {
                selectedGroup = groupViewModel.groups.first
            }
            startCalendarListeningIfNeeded()
        }
        .onChange(of: groupViewModel.groups) { _, newGroups in
            selectedGroup = newGroups.first
        }
        .onChange(of: selectedGroup?.id) { _, _ in
            startCalendarListeningIfNeeded()
        }
    }

    private func startCalendarListeningIfNeeded() {
        guard let group = selectedGroup, let uid = Auth.auth().currentUser?.uid else { return }
        calendarViewModel.startListening(groupId: group.id, groupName: group.name, currentUid: uid)
    }

    // ★ CalendarSwitcherRow.swiftの表示ラベルと同じ規則（コミュニティ／プライベート／カスタム名）に揃える。
    //   ★ 秘密の予定（isSecret）はcalendarIdがnilになりうる（EventViewModel.swift:842-843の
    //   コメント参照）。calendarId==nilだけで「コミュニティの予定」と判定すると、本人にしか
    //   見えない秘密イベントに誤って「コミュニティ」ラベルが付いてしまうため、isSecretを先に見る
    private func calendarLabel(for event: Event) -> String {
        if event.isSecret { return "秘密イベント" }
        let communityId = calendarViewModel.calendars.first(where: { $0.isCommunity })?.id
        guard let calendarId = event.calendarId, calendarId != communityId else {
            return "コミュニティ"
        }
        guard let cal = calendarViewModel.calendars.first(where: { $0.id == calendarId }) else {
            return "コミュニティ"
        }
        return cal.isCommunity ? "コミュニティ" : (cal.isPrivate ? "プライベート" : cal.name)
    }

    // MARK: - メインコンテンツ
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {

                // ★ ホーム画面にも常にOshiNiumのロゴ文字を出す。再読み込み中は
                //   同じ場所でその文字が左から描かれていくローディング表示に切り替わる
                OshiNiumRefreshBanner(accentColor: accentColor, isRefreshing: isRefreshing)

                groupHeader

                todayCard

                timelineSection
                    // ★ .tint(.clear)は更新スピナーを隠すためだけのものだが、環境値なので
                    //   放っておくとタイムライン内の投稿カードが出すconfirmationDialog/alertの
                    //   ボタン文字色まで透明になり、「保存する」等が見えなくなってしまう。
                    //   ここで本来のアクセントカラーに上書きし直して復元する
                    .tint(accentColor)
            }
            .padding(.bottom, 16 + customTabBarHeight)
        }
        .background(Color.appBackground.ignoresSafeArea())
        // ★ 標準のくるくるスピナーは目立たせず、代わりに上のOshiNiumRefreshBannerを主役にする
        .tint(.clear)
        .refreshable {
            await performRefresh()
        }
    }

    // ★ Firestoreのリスナーは常時最新なので、実際の再取得は不要。
    //   引っ張って離した瞬間から一定時間だけ演出を見せ、「更新した」という手応えを返す
    private func performRefresh() async {
        withAnimation(.easeInOut(duration: 0.2)) { isRefreshing = true }
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        withAnimation(.easeInOut(duration: 0.2)) { isRefreshing = false }
    }

    // MARK: - 画面上部の見出し（ユーザー情報の代わりに、今どのグループのホーム画面かを表示）
    @ViewBuilder
    private var groupHeader: some View {
        HStack(spacing: 14) {
            if let group = selectedGroup {
                GroupIcon(group: group, isSelected: false, size: 44)
            }

            Text(selectedGroup?.name ?? "OshiNium")
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            // ★ 通知（フォロー・予定・招待など）。以前はオシニウム（オリジナル）タブに
            //   あったが、より見つけやすいホーム画面の検索アイコンの隣に統合した
            NavigationLink {
                NotificationsTab()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color(.systemGray6)))

                    if notificationViewModel.unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .offset(x: 1, y: -1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(notificationViewModel.unreadCount > 0 ? "通知、未読あり" : "通知")

            // ★ グッズ・ペンライトのいいねランキング、投稿いいね数の上位者、
            //   コミュニティへの予定追加数（貢献度）をまとめて見られるランキング画面
            Button {
                showRanking = true
            } label: {
                Image(systemName: "crown")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.systemGray6)))
            }
            .accessibilityLabel("ランキング")

            // ★ 投稿の検索。虫眼鏡を押すとキャプションで投稿を検索できるシートを開く
            Button {
                showPostSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.systemGray6)))
            }
            .accessibilityLabel("投稿を検索")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .glossyHighlight(cornerRadius: 22)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showPostSearch) {
            PostSearchView(selectedGroup: selectedGroup)
        }
        .sheet(isPresented: $showRanking) {
            RankingView(group: selectedGroup)
        }
    }

    // MARK: - 「今日の予定」＋「直近1週間の予定」カード
    //   ★ 以前はカレンダータブで選択した日（selectedDate）の予定を表示していたため、
    //     カレンダーで別の日を見た直後にホームへ戻ると「今日の予定」のはずが
    //     その日の予定になってしまっていた。ホームでは常に本当の「今日」を基準にする。
    //     また、開閉トグル式だった一覧を廃止し、今日の予定と直近1週間の見通しを
    //     常に開いた状態のシンプルな1枚のカードにまとめる
    private var todayCard: some View {
        let today = Date()
        let todayEvents = eventsForDate(today)
        let weekEvents = upcomingWeekEvents(from: today)

        return VStack(alignment: .leading, spacing: 10) {

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    // ★ 以前は絵文字の✨だったが安っぽく見えるため、オシニウムタブの
                    //   タブバー（オリジナルタブの円形ボタン）と全く同じグラデーション・
                    //   宝石アイコンを小さく再利用し、色とモチーフをアプリ全体で統一する
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.oshiniumPrimary, Color(red: 0.78, green: 0.64, blue: 0.99)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 20, height: 20)
                            .shadow(color: Color.oshiniumPrimary.opacity(0.4), radius: 5, x: 0, y: 2)

                        BrilliantDiamondIcon(fill: AnyShapeStyle(Color.white), strokeColor: Color.oshiniumPrimary)
                            .frame(width: 10, height: 10)
                    }
                    .accessibilityHidden(true)

                    Text("今日の予定")
                        .font(.system(size: 15, weight: .semibold))
                    // ★ 予定が無い日は「予定がありません」を別行にせず見出しの同じ行に収め、
                    //   ホーム最初の1画面にタイムラインの投稿が1件ぴったり収まるよう縦の余白を削る
                    if todayEvents.isEmpty {
                        Text("・予定はありません")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(todayJP)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if !todayEvents.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(todayEvents.prefix(4)) { event in
                            NavigationLink(
                                destination: EventDetailView(event: event, isOwner: isOwner, eventViewModel: eventViewModel)
                            ) {
                                todayEventRow(event)
                            }
                            .buttonStyle(PressableRowStyle())
                        }
                        if todayEvents.count > 4 {
                            Text("ほか\(todayEvents.count - 4)件")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // ★ 以前はDivider()で区切っていたが、区切り線自体とその前後の余白が
            //   縦方向に意外とかさばるため、ホームの初期表示にタイムラインの投稿1件が
            //   ぴったり収まるようこの区切りを廃止し、代わりに少しの余白だけで分ける
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                        .accessibilityHidden(true)
                    Text("直近1週間の予定")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button {
                        navState.jumpToCalendar()
                    } label: {
                        HStack(spacing: 2) {
                            Text("カレンダーで見る")
                            Image(systemName: "chevron.right")
                                .accessibilityHidden(true)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentColor)
                    }
                }

                if weekEvents.isEmpty {
                    Text("直近1週間の予定はありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(weekEvents.prefix(5)) { event in
                            NavigationLink(
                                destination: EventDetailView(event: event, isOwner: isOwner, eventViewModel: eventViewModel)
                            ) {
                                weekEventRow(event)
                            }
                            .buttonStyle(PressableRowStyle())
                        }
                        if weekEvents.count > 5 {
                            Text("ほか\(weekEvents.count - 5)件")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    // ★ 今日の予定の行（時間・種類・タイトルだけのシンプルな1行）
    private func todayEventRow(_ event: Event) -> some View {
        let type = event.type ?? .other
        return HStack(spacing: 10) {
            Circle()
                .fill(type.iconColor)
                .frame(width: 7, height: 7)

            Text(timeText(event.date))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)

            Text(event.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            calendarBadge(calendarLabel(for: event))

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    // ★ 直近1週間の予定の行（日付・タイトルだけのさらに軽い1行）
    private func weekEventRow(_ event: Event) -> some View {
        let type = event.type ?? .other
        let date = event.startDate ?? event.date
        return HStack(spacing: 10) {
            Circle()
                .fill(type.iconColor)
                .frame(width: 6, height: 6)

            Text(weekDateText(date))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(accentColor)
                .frame(width: 54, alignment: .leading)

            Text(event.title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(1)

            calendarBadge(calendarLabel(for: event))

            Spacer(minLength: 0)
        }
    }

    // ★ どのカレンダーの予定かをホームでも一目で分かるようにする小さなラベル。
    //   「カレンダータブに出ていない」という誤解（実際はプライベート等、別カレンダーの予定）を防ぐ
    private func calendarBadge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(accentColor.opacity(0.12))
            )
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: - 推し活タイムライン（★選択中のグループの投稿だけを表示する）

    private var timelinePosts: [Post] {
        guard let selectedGroup else { return [] }
        return postViewModel.postsForGroups([selectedGroup.id])
    }

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)
                Text("推し活タイムライン")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.primary)

            if timelinePosts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 30))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("まだ投稿がありません")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("マイページから推しへの投稿をしてみましょう")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
            } else {
                // ★ Threadsのように、投稿ごとの白いカードではなく1枚の白いコンテナに
                //   まとめ、投稿同士は罫線だけで区切る（カードの影が積み重なる見た目をやめる）。
                //   投稿数が増えても画面外のカードまで一度に描画・画像読み込みしないよう、
                //   通常のVStackではなくLazyVStackにする
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timelinePosts.enumerated()), id: \.element.id) { index, post in
                        PostFeedCard(post: post)
                        if index != timelinePosts.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - グループのイベント一覧
    // ★ 2026/08/11修正：以前はgroupIdが一致するだけの全予定（自分がまだ承認していない
    //   他メンバーの投稿も含む）をホーム画面の「今日の予定」「今週の予定」に出してしまっていた
    //   （カレンダータブでは見えないのにホームには出てくる、という食い違いの原因だった）。
    //   EventViewModel.myVisibleEvents(groupId:)に承認制のフィルタを集約し、ここでは呼ぶだけにする
    var filteredEvents: [Event] {
        guard let group = selectedGroup else { return [] }
        return eventViewModel.myVisibleEvents(groupId: group.id)
    }

    // MARK: - 指定日のイベント
    private func eventsForDate(_ date: Date) -> [Event] {
        filteredEvents.filter { event in
            if let s = event.startDate, let e = event.endDate {
                if s > e {
                    print("⚠️ Warning: Invalid date range detected → startDate > endDate")
                    return false
                }
                return (s...e).contains(date)
            } else {
                return Calendar.current.isDate(event.date, inSameDayAs: date)
            }
        }
        .sorted { $0.date < $1.date }
    }

    // ★ 「今日」の翌日から7日以内に始まる/含まれる予定（今日ぶんは上のセクションで表示済みなので除く）
    private func upcomingWeekEvents(from today: Date) -> [Event] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: todayStart)
        else { return [] }

        return filteredEvents.filter { event in
            let eventStart: Date
            let eventEnd: Date
            if let s = event.startDate, let e = event.endDate, s <= e {
                eventStart = s
                eventEnd = e
            } else {
                eventStart = event.date
                eventEnd = event.date
            }
            return eventEnd >= tomorrowStart && eventStart < weekEnd
        }
        .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
    }

    private var todayJP: String {
        return CachedFormatters.date(format: "M/d（E）").string(from: Date())
    }

    private func timeText(_ date: Date) -> String {
        CachedFormatters.date(format: "HH:mm", locale: Locale.current).string(from: date)
    }

    private func weekDateText(_ date: Date) -> String {
        return CachedFormatters.date(format: "M/d（E）").string(from: date)
    }

}

// ★ 予定の行をタップした瞬間に軽く沈む/薄くなる、Appleのリストに近いタップ手応え。
//   .buttonStyle(.plain)のままだと押した瞬間の視覚フィードバックが一切無かった
private struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
