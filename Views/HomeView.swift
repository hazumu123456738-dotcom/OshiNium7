//
//  HomeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import SwiftUI
import UIKit

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
    // ★ 上に引っ張って再読み込みしている間だけ、OshiNiumの文字が左から描かれる
    //   独自ローディング表示を出す。投稿はFirestoreのリスナーで既に常に最新なので、
    //   ここでの「再読み込み」は改めて取得し直すというより「最新であることの確認演出」
    @State private var isRefreshing = false

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    var isOwner: Bool = true

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        mainContent
        .onAppear {
            if selectedGroup == nil {
                selectedGroup = groupViewModel.groups.first
            }
        }
        .onChange(of: groupViewModel.groups) { _, newGroups in
            selectedGroup = newGroups.first
        }
    }

    // MARK: - メインコンテンツ
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                // ★ ホーム画面にも常にOshiNiumのロゴ文字を出す。再読み込み中は
                //   同じ場所でその文字が左から描かれていくローディング表示に切り替わる
                OshiNiumRefreshBanner(accentColor: accentColor, isRefreshing: isRefreshing)

                groupHeader

                todayCard

                timelineSection
                    .padding(.top, 4)
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .sheet(isPresented: $showPostSearch) {
            PostSearchView(selectedGroup: selectedGroup)
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

        return VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("✨ 今日の予定")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(todayJP)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                if todayEvents.isEmpty {
                    Text("今日は予定がありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 8) {
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

            Divider()

            VStack(alignment: .leading, spacing: 10) {
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
                    VStack(spacing: 6) {
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
        .padding(16)
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

            Spacer(minLength: 0)
        }
    }

    // MARK: - 推し活タイムライン（★選択中のグループの投稿だけを表示する）

    private var timelinePosts: [Post] {
        guard let selectedGroup else { return [] }
        return postViewModel.postsForGroups([selectedGroup.id])
    }

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    var filteredEvents: [Event] {
        guard let group = selectedGroup else { return [] }
        return Array(eventViewModel.events).filter { $0.groupId == group.id }
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d（E）"
        return formatter.string(from: Date())
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weekDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d（E）"
        return formatter.string(from: date)
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
