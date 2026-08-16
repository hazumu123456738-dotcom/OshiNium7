//
//  AppRootView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/04.
//

import SwiftUI
import FirebaseAuth
import AppTrackingTransparency

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

    // ★ 投稿・予定の共有リンク（https://oshinium-79256.web.app/p or /e、oshinium://post・oshinium://event）
    //   から開いた投稿・予定。ProfileLinkParserと同じ仕組みで、Universal Link・カスタムスキームの
    //   両方から同じ状態に集約する
    @State private var deepLinkPostId: String?
    @State private var deepLinkEventId: String?

    // ★ ホーム画面ウィジェット（持ち物チェックリスト・推し活費用シミュレーター）タップからの
    //   ディープリンク（oshinium://packing・oshinium://expense）。タブ切り替えを介さず、
    //   アプリ内でツールを開いた時と同じ画面をそのままfullScreenCoverで開く
    @State private var showPackingDeepLink = false
    @State private var showExpenseDeepLink = false

    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    // ★ AdMobのパーソナライズ広告用。ATTのシステムダイアログは一度回答すると
    //   二度と出せないため、このセッション内で二重に要求しないようフラグで一度きりにする
    @State private var hasRequestedTracking = false
    @State private var hasRequestedConsent = false

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

                    } else if !settingsVM.hasLoadedOnboardingStatus {
                        // ★ 起動直後、Firestoreから本人のプロフィール（hasCompletedOnboarding）の
                        //   応答が届くまでのごく一瞬だけ表示する（下のProfileSetupViewが一瞬
                        //   チラつくのを防ぐ。groupsLoadingPlaceholderと同じ考え方）
                        groupsLoadingPlaceholder

                    } else if !settingsVM.settings.hasCompletedOnboarding {
                        // ★ 2026/08/16追加：グループ選択より前に必ず一度通す、初回プロフィール
                        //   作成・年齢確認の画面。詳細はProfileSetupView.swift参照
                        ProfileSetupView()

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
                        .onAppear {
                            requestConsentIfNeeded()
                            requestTrackingIfNeeded()
                            // ★ 推し活占いの動画広告は、実際にタップされるより前から
                            //   先読みを始めておかないと間に合わない（占い画面に着いてから
                            //   ロードを始めると、タップ時点でまだ読み込み中になりやすい）
                            _ = InterstitialAdManager.shared
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
        // ★ 2026/08/16追加：予定リマインド通知のタップ(AppNavigationState.openEvent)を、
        //   既存のUniversal Link用deepLinkEventId(SharedEventLinkView)にそのまま乗せる
        .onReceive(navState.$pendingEventDeepLink) { eventId in
            guard let eventId else { return }
            deepLinkEventId = eventId
            navState.pendingEventDeepLink = nil
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
                // ★ 2026/08/16追加：ProfileSetupView（初回プロフィール作成・年齢確認）の
                //   出し分けに、この読み込み結果（hasCompletedOnboarding）を使う
                settingsVM.loadSettings()
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
                // ★ ログアウト→別アカウントでの再ログイン時に、前のアカウントの
                //   settingsが一瞬でも残らないようリセットする
                settingsVM.settings = UserSettings.empty
                settingsVM.hasLoadedOnboardingStatus = false
            }
        }
        // ★ oshinium:// のディープリンク（グループ招待・プロフィール共有）の入り口
        .onOpenURL { url in
            handleDeepLink(url)
        }
        // ★ https://oshinium-79256.web.app/u/<uid>・/p/<postId>・/e/<eventId> のUniversal Linkの入り口。
        //   Associated Domainsが有効な端末でアプリがインストール済みなら、
        //   Safariを経由せずこちらが直接呼ばれる（未インストール端末ではpublic/配下のindex.htmlが開く）
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleUniversalLink(url: url)
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
        .sheet(isPresented: Binding(
            get: { deepLinkPostId != nil },
            set: { if !$0 { deepLinkPostId = nil } }
        )) {
            if let postId = deepLinkPostId {
                SharedPostLinkView(postId: postId)
            }
        }
        .sheet(isPresented: Binding(
            get: { deepLinkEventId != nil },
            set: { if !$0 { deepLinkEventId = nil } }
        )) {
            if let eventId = deepLinkEventId {
                SharedEventLinkView(eventId: eventId)
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
        case "post":
            handlePostLink(url: url)
        case "event":
            handleEventLink(url: url)
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

    private func handlePostLink(url: URL) {
        guard let postId = ContentLinkParser.postId(from: url.absoluteString) else { return }
        deepLinkPostId = postId
    }

    private func handleEventLink(url: URL) {
        guard let eventId = ContentLinkParser.eventId(from: url.absoluteString) else { return }
        deepLinkEventId = eventId
    }

    // ★ Universal Link(https://oshinium-79256.web.app/...)の入り口はホスト名の出し分けが無く、
    //   /u/・/p/・/eのどのパスかで初めて種類がわかるため、oshinium://の時と違い1つの関数に集約する
    private func handleUniversalLink(url: URL) {
        if let uid = ProfileLinkParser.uid(from: url.absoluteString) {
            deepLinkProfileUid = uid
        } else if let postId = ContentLinkParser.postId(from: url.absoluteString) {
            deepLinkPostId = postId
        } else if let eventId = ContentLinkParser.eventId(from: url.absoluteString) {
            deepLinkEventId = eventId
        }
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

    // MARK: - UMP（AdMobをEEA/UK圏へ配信する場合に必須の同意取得フロー）
    // ★ UMPConsentInformation自身が端末の地域を判定するため、対象地域以外の
    //   ユーザーには何も表示されない。ATTと同じくメイン画面が落ち着いてから呼ぶ
    private func requestConsentIfNeeded() {
        guard !hasRequestedConsent else { return }
        hasRequestedConsent = true

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        ConsentManager.requestConsentAndStartAdsIfNeeded(from: rootVC)
    }

    // MARK: - App Tracking Transparency（AdMobのパーソナライズ広告用）
    // ★ ログイン直後・スプラッシュ直後だとシステムダイアログが画面遷移のアニメーションと
    //   競合して見づらいため、メイン画面（OshiNiumTabView）が実際に表示され落ち着いてから
    //   少し間を置いて出す。.notDeterminedの時だけ要求し、既に許可/拒否済みなら何もしない
    //   （requestTrackingAuthorization自体は再度呼んでも安全だが、無駄な呼び出しを避ける）
    private func requestTrackingIfNeeded() {
        guard !hasRequestedTracking else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            hasRequestedTracking = true
            return
        }
        hasRequestedTracking = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
