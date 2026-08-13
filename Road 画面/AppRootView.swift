//
//  AppRootView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/04.
//

import SwiftUI
import FirebaseAuth

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
            // ★ ここはSplashView/LoginView/OshiNiumTabView間の.transition(.opacity)中に
            //   一瞬だけ透けて見える土台。固定のColor.whiteだとダークモードでの遷移中に
            //   白フラッシュが起きるため、動的なappBackgroundにする
            //   (SplashView/LoginViewは意図的に常時ライトな独自背景を持っているため、
            //   通常表示時の見た目はこの変更では変わらない)
            Color.appBackground.ignoresSafeArea()

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
                notificationViewModel.startListeningAnnouncements()
                groupViewModel.startListening()
                savedPostViewModel.startListening(uid: uid)
                SubscriptionManager.shared.startListening(uid: uid)
                ThemeManager.shared.startListening(uid: uid)
            } else {
                followViewModel.stopListening()
                notificationViewModel.stopListening()
                notificationViewModel.stopListeningAnnouncements()
                groupViewModel.stopListening()
                savedPostViewModel.stopListening()
                SubscriptionManager.shared.stopListening()
                ThemeManager.shared.stopListening()
                // ★ ここが漏れていたため、ログアウト後もeventViewModel/postViewModelの
                //   リスナー(秘密の予定・投稿一覧)がstale認証のまま動き続けていた
                eventViewModel.stopListeners()
                postViewModel.stopListeners()
            }
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
            } else if let message = groupViewModel.loadErrorMessage, !showSplash {
                groupLoadErrorBanner(message)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: networkMonitor.isConnected)
        .animation(.easeInOut(duration: 0.25), value: groupViewModel.loadErrorMessage)
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

    // ★ グループ読み込みが権限エラー等で失敗した時に表示する。以前はこのエラーが
    //   ユーザーに一切伝わらず、ローディング画面のまま無言でフリーズしているように
    //   見えていた(GroupViewModel.startListening参照)
    private func groupLoadErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
            Button("再試行") {
                groupViewModel.startListening()
            }
            .font(.system(size: 12, weight: .bold))
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
                case .failure(let error):
                    // ★ グループチャットの参加上限など、理由が明確なエラーはそのまま伝える。
                    //   それ以外(ネットワークエラー等)は従来通りの汎用メッセージにする
                    if let groupError = error as? GroupCreationError,
                       case .privateChatJoinLimitReached = groupError {
                        joinResultMessage = groupError.errorDescription
                    } else {
                        joinResultMessage = "招待リンクからの参加に失敗しました。リンクをもう一度お確かめください。"
                    }
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

    // MARK: - スプラッシュ処理
    // ★ 以前は表示1.0秒+フェード0.4秒=計1.4秒と長めで、白背景のロゴ画面が
    //   もたついて見えるという指摘を受け、表示0.4秒+フェード0.25秒=計0.65秒に短縮した。
    //   その後さらに「まだ半分くらいの時間でいい」との指摘を受け表示0.2秒+フェード0.15秒=
    //   計0.35秒に、続けて「今の0.6倍くらいでいい」との指摘を受け表示0.12秒+フェード0.1秒=
    //   計0.22秒まで再短縮した
    private func runSplash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.1)) {
                showSplash = false
            }
            isFirstLaunch = false
        }
    }
}
