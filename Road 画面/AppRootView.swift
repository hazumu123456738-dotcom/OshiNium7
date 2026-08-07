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
    @EnvironmentObject var savedPostViewModel: SavedPostViewModel
    @EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var notificationViewModel: AppNotificationViewModel
    @EnvironmentObject var navState: AppNavigationState
    @EnvironmentObject var networkMonitor: NetworkMonitor

    @Binding var showAddEvent: Bool
    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    @State private var showSplash = true

    // ★ 招待リンク（oshinium://join?group=<id>）から参加した結果を伝えるアラート
    @State private var joinResultMessage: String?
    @State private var showJoinResultAlert = false

    // ★ プロフィール共有リンク（oshinium://profile?uid=<uid>）から開いたプロフィール
    @State private var deepLinkProfileUid: String?

    // ★ ホーム画面ウィジェット（持ち物チェックリスト・推し活費用シミュレーター）タップからの
    //   ディープリンク（oshinium://packing・oshinium://expense）。タブ切り替えを介さず、
    //   アプリ内でツールを開いた時と同じ画面をそのままfullScreenCoverで開く
    @State private var showPackingDeepLink = false
    @State private var showExpenseDeepLink = false

    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Group {
                if showSplash {
                    SplashView()
                        .transition(.opacity)

                } else {

                    if auth.user == nil {
                        LoginView()

                    } else if !groupViewModel.hasLoadedGroupsOnce {
                        // ★ 起動直後、Firestoreから「本当にグループ0件か」の応答が
                        //   届くまでのごく一瞬だけ表示する（グループ選択画面が一瞬
                        //   チラつくのを防ぐ）
                        groupsLoadingPlaceholder

                    } else if groupViewModel.groups.isEmpty {
                        // ★ グループ選択画面は「まだ一つも推しグループを選んだことが
                        //   ない」初回ログインの人だけに出す。既に選択済みのグループが
                        //   Firestore上にあれば、別デバイスからのログインでも自動でスキップする
                        GroupSelectView {}

                    } else {
                        OshiNiumTabView(
                            showAddEvent: $showAddEvent,
                            selectedGroup: $selectedGroup,
                            selectedDate: $selectedDate
                        )
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
        // ★ フォロー関係・アプリ内通知・参加グループはuidに紐づくため、
        //   ログイン状態が確定してから開始する。グループを最初にここで読み始めることで、
        //   グループ選択画面を出すべきか（＝本当に0件か）を起動直後に判定できる
        .onReceive(auth.$user) { user in
            if let uid = user?.uid {
                followViewModel.startListening(uid: uid)
                notificationViewModel.startListening(uid: uid)
                groupViewModel.startListening()
                savedPostViewModel.startListening(uid: uid)
            } else {
                followViewModel.stopListening()
                notificationViewModel.stopListening()
                groupViewModel.stopListening()
                savedPostViewModel.stopListening()
            }
        }
        // ★ ホーム画面ウィジェット（ミニカレンダー）用に、選択中グループの今月の予定を
        //   App Group経由で書き出す。予定データかグループが変わるたびに更新し、
        //   ウィジェット側にも再読み込みを促す
        .onChange(of: eventViewModel.eventsByDate) { _, _ in
            updateWidgetSnapshot()
        }
        .onChange(of: selectedGroup?.id) { _, _ in
            updateWidgetSnapshot()
        }
        // ★ oshinium:// のディープリンク（グループ招待・プロフィール共有）の入り口
        .onOpenURL { url in
            handleDeepLink(url)
        }
        // ★ https://oshinium-79256.web.app/u/<uid> のUniversal Linkの入り口。
        //   Associated Domainsが有効な端末でアプリがインストール済みなら、
        //   Safariを経由せずこちらが直接呼ばれる（未インストール端末ではpublic/u/index.htmlが開く）
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleProfileLink(url: url)
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
        // ★ 持ち物チェックリストウィジェットのタップから、アプリ内で開いた時と同じ画面を開く。
        //   通常はNavigationLinkで他画面から遷移するため戻るボタンが自動で付くが、
        //   ここではNavigationStackの一番上（＝戻り先が無い）として直接開くため、
        //   明示的な閉じるボタンが無いと二度とこの画面から出られなくなっていた
        //   （fullScreenCoverはsheetと違いスワイプで閉じることもできない）。それを解消する
        .fullScreenCover(isPresented: $showPackingDeepLink) {
            NavigationStack {
                PackingChecklistView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showPackingDeepLink = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .accessibilityLabel("閉じる")
                        }
                    }
            }
            .environmentObject(eventViewModel)
            .environmentObject(groupViewModel)
        }
        // ★ 推し活費用シミュレーターウィジェットのタップから、同じく該当画面を直接開く（理由は上と同じ）
        .fullScreenCover(isPresented: $showExpenseDeepLink) {
            NavigationStack {
                OshiExpenseTrackerView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showExpenseDeepLink = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .accessibilityLabel("閉じる")
                        }
                    }
            }
            .environmentObject(eventViewModel)
            .environmentObject(groupViewModel)
        }
        // ★ オフライン時に「読み込み中のまま無言で止まっている」ように見えるのを防ぐため、
        //   ネットワークが無い間は上部に明示的なバナーを出す。キャッシュ済みのデータは
        //   Firestoreの永続キャッシュによりオフラインでも表示され続けるので、
        //   これは「新しい情報が取得できていない」ことを伝えるためのもの
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected && !showSplash {
                offlineBanner
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: networkMonitor.isConnected)
    }

    // ★ Firestoreからグループ0件かどうかの初回応答が届くまでの、ごく短い間だけ映るプレースホルダー
    private var groupsLoadingPlaceholder: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ProgressView()
                .tint(Color.oshiniumPrimary)
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
            Text("オフラインです。最新の情報を取得できません")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    // MARK: - ディープリンクのハンドリング
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "oshinium",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        switch url.host {
        case "join":
            handleInviteLink(components: components)
        case "profile":
            handleProfileLink(url: url)
        case "packing":
            showPackingDeepLink = true
        case "expense":
            showExpenseDeepLink = true
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
                    selectedGroup = group
                    joinResultMessage = "「\(group.name)」に参加しました！専用のグループチャットとカレンダーが自動的に用意されます。"
                case .failure:
                    joinResultMessage = "招待リンクからの参加に失敗しました。リンクをもう一度お確かめください。"
                }
                showJoinResultAlert = true
            }
        }
    }

    // ★ 新形式のUniversal Link(https://oshinium-79256.web.app/u/<uid>)・
    //   旧カスタムスキーム(oshinium://profile?uid=<uid>)のどちらから来ても同じ扱いにする
    private func handleProfileLink(url: URL) {
        guard let uid = ProfileLinkParser.uid(from: url.absoluteString) else { return }
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
    // ★ 1秒表示したら、インスタのように透けてホーム画面（またはログイン画面）に遷移する
    private func runSplash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
            isFirstLaunch = false
        }
    }
}
