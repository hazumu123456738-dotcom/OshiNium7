//
//  AppRootView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/04.
//

import SwiftUI
import FirebaseAuth
import WidgetKit

struct AppRootView: View {

    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var notificationViewModel: AppNotificationViewModel
    @EnvironmentObject var navState: AppNavigationState

    @Binding var showAddEvent: Bool
    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    @State private var showSplash = true

    // ★ 招待リンク（oshinium://join?group=<id>）から参加した結果を伝えるアラート
    @State private var joinResultMessage: String?
    @State private var showJoinResultAlert = false

    // ★ プロフィール共有リンク（oshinium://profile?uid=<uid>）から開いたプロフィール
    @State private var deepLinkProfileUid: String?

    @AppStorage("hasSelectedGroup") private var hasSelectedGroup = false
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if showSplash {
                    SplashView()

                } else {

                    if auth.user == nil {
                        LoginView()

                    } else if !hasSelectedGroup {
                        GroupSelectView {
                            hasSelectedGroup = true
                        }
                        .onAppear {
                            groupViewModel.startListening()
                        }

                    } else {
                        OshiNiumTabView(
                            showAddEvent: $showAddEvent,
                            selectedGroup: $selectedGroup,
                            selectedDate: $selectedDate
                        )
                        .onAppear {
                            groupViewModel.startListening()
                        }
                    }
                }
            }
        }

        // MARK: - AddEventView（全画面表示）
        .fullScreenCover(isPresented: $showAddEvent) {
            if let group = selectedGroup {
                NavigationStack {
                    AddEventView(
                        selectedGroup: group,
                        defaultDate: selectedDate
                    )
                    .environmentObject(eventViewModel)
                    .environmentObject(settingsVM)
                    .environmentObject(navState)
                }
            } else {
                Text("グループが選択されていません")
            }
        }
        .onAppear {
            runSplash()
            eventViewModel.startListeners()
            postViewModel.startListeners()
        }
        // ★ EventViewModel.groups は自分では取得しておらず常に空だったため、
        //   group(for:) が全滅していた（イベントに紐づくグループアイコン等が出せない）。
        //   GroupViewModel の最新値をそのまま鏡写しして修正する。
        .onReceive(groupViewModel.$groups) { groups in
            eventViewModel.groups = groups
        }
        // ★ フォロー関係・アプリ内通知はuidに紐づくため、ログイン状態が確定してから開始する
        .onReceive(auth.$user) { user in
            if let uid = user?.uid {
                followViewModel.startListening(uid: uid)
                notificationViewModel.startListening(uid: uid)
            } else {
                followViewModel.stopListening()
                notificationViewModel.stopListening()
            }
        }
        // ★ ホーム画面ウィジェット（ミニカレンダー）用に、選択中グループの今月の予定を
        //   App Group経由で書き出す。予定データかグループが変わるたびに更新し、
        //   ウィジェット側にも再読み込みを促す
        .onChange(of: eventViewModel.eventsByDate) { _ in
            updateWidgetSnapshot()
        }
        .onChange(of: selectedGroup?.id) { _ in
            updateWidgetSnapshot()
        }
        // ★ oshinium:// のディープリンク（グループ招待・プロフィール共有）の入り口
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .alert("グループチャットへの招待", isPresented: $showJoinResultAlert) {
            Button("OK") {}
        } message: {
            Text(joinResultMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { deepLinkProfileUid != nil },
            set: { if !$0 { deepLinkProfileUid = nil } }
        )) {
            if let uid = deepLinkProfileUid {
                NavigationStack {
                    UserProfileView(uid: uid)
                }
            }
        }
    }

    // MARK: - ディープリンクのハンドリング
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "oshinium",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        switch url.host {
        case "join":
            handleInviteLink(components: components)
        case "profile":
            handleProfileLink(components: components)
        default:
            break
        }
    }

    private func handleInviteLink(components: URLComponents) {
        guard let groupId = components.queryItems?.first(where: { $0.name == "group" })?.value,
              !groupId.isEmpty else { return }

        guard auth.user != nil else {
            joinResultMessage = "招待リンクから参加するには、まずログインしてください。"
            showJoinResultAlert = true
            return
        }

        groupViewModel.joinGroup(byId: groupId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let group):
                    hasSelectedGroup = true
                    selectedGroup = group
                    joinResultMessage = "「\(group.name)」に参加しました！専用のグループチャットとカレンダーが自動的に用意されます。"
                case .failure:
                    joinResultMessage = "招待リンクからの参加に失敗しました。リンクをもう一度お確かめください。"
                }
                showJoinResultAlert = true
            }
        }
    }

    private func handleProfileLink(components: URLComponents) {
        guard let uid = components.queryItems?.first(where: { $0.name == "uid" })?.value,
              !uid.isEmpty else { return }
        deepLinkProfileUid = uid
    }

    // MARK: - ウィジェット用スナップショットの書き出し
    private func updateWidgetSnapshot() {
        guard let group = selectedGroup else { return }
        let cal = Calendar.current
        let now = Date()
        let year = cal.component(.year, from: now)
        let month = cal.component(.month, from: now)

        guard let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let daysInMonth = range.count
        let todayDay = cal.isDate(now, equalTo: firstOfMonth, toGranularity: .month)
            ? cal.component(.day, from: now)
            : nil

        var dayTypes: [Int: Set<String>] = [:]
        for event in eventViewModel.events where event.groupId == group.id && !event.isSecret {
            let d = event.startDate ?? event.date
            guard cal.isDate(d, equalTo: firstOfMonth, toGranularity: .month) else { continue }
            let day = cal.component(.day, from: d)
            dayTypes[day, default: []].insert((event.type ?? .other).rawValue)
        }

        let days = dayTypes.map { WidgetCalendarDay(day: $0.key, types: Array($0.value)) }

        let snapshot = WidgetCalendarSnapshot(
            groupName: group.name,
            year: year,
            month: month,
            firstWeekday: firstWeekday,
            daysInMonth: daysInMonth,
            days: days,
            todayDay: todayDay,
            updatedAt: now
        )

        SharedWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - スプラッシュ処理
    private func runSplash() {
        if isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSplash = false
                isFirstLaunch = false
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSplash = false
        }
    }
}
