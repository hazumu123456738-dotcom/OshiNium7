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
    @State private var showUserSearch = false
    @State private var showRanking = false
    // ★ ヘッダーのグループ名下に表示する、そのコミュニティの参加人数。
    //   GroupViewModel.fetchMemberCountはFirestoreのcount()集計クエリを使う軽量版
    //   （全メンバードキュメントを読まずに件数だけ取得、選択中グループが変わるたびに
    //   1回だけ呼ぶ一時的な取得で、常時購読リスナーは追加しない）
    @State private var headerMemberCount: Int?
    // ★ 上に引っ張って再読み込みしている間だけ、OshiNiumの文字が左から描かれる
    //   独自ローディング表示を出す。投稿はFirestoreのリスナーで既に常に最新なので、
    //   ここでの「再読み込み」は改めて取得し直すというより「最新であることの確認演出」
    @State private var isRefreshing = false

    // ★ ホームの「今日の予定」「直近1週間の予定」は複数カレンダー（プライベート／コミュニティ／
    //   共有カレンダー）を横断表示するため、カレンダータブと違って「どのカレンダーの予定か」が
    //   一見して分からず「カレンダータブに出ていない」という誤解を招いていた。行にラベルを出すために
    //   FullCalendarTab.swiftと同じデータを参照する。以前はここで独自にCalendarViewModel()を
    //   保持しており、FullCalendarTab側のインスタンスと常時二重にFirestoreリスナーが
    //   稼働していたため、アプリ全体で1つだけの共有インスタンス(OshiNium7App)に統合した
    @EnvironmentObject var calendarViewModel: CalendarViewModel

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
            fetchHeaderMemberCount()
        }
        .onChange(of: groupViewModel.groups) { _, newGroups in
            selectedGroup = newGroups.first
        }
        .onChange(of: selectedGroup?.id) { _, _ in
            startCalendarListeningIfNeeded()
            fetchHeaderMemberCount()
        }
    }

    private func fetchHeaderMemberCount() {
        guard let groupId = selectedGroup?.id else {
            headerMemberCount = nil
            return
        }
        groupViewModel.fetchMemberCount(groupId: groupId) { count in
            headerMemberCount = count
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
    //   ★ 以前はcalendarViewModel.calendars（Firestoreリスナーの応答を待つ非同期データ）を
    //   参照して判定しており、アプリ起動直後などまだ読み込みが終わっていないタイミングでは
    //   「該当カレンダーが見つからない」→「コミュニティ」という誤ったフォールバックになっていた。
    //   実際にプライベートカレンダーの予定が一瞬「コミュニティ」表示になるバグとして報告された。
    //   calendarId自体の命名規則（"{groupId}_community" / "{groupId}_private_{uid}"）から
    //   コミュニティ／プライベートを判定すれば、calendarViewModelの読み込み状態に一切依存せず
    //   常に正しく分類できる（EventDetailView.ShareScope/AddEventView.nonSecretScopeと同じ手法）
    private func calendarLabel(for event: Event) -> String {
        if event.isSecret { return "秘密イベント" }
        guard let calendarId = event.calendarId, let groupId = event.groupId else {
            return "コミュニティ"
        }
        if calendarId == "\(groupId)_community" {
            return "コミュニティ"
        }
        if calendarId.hasPrefix("\(groupId)_private_") {
            return "プライベート"
        }
        // ★ 上記のどちらでもなければカスタム共有カレンダー。名前が引ければそれを使うが、
        //   calendarViewModelがまだ読み込み中で見つからない場合でも、
        //   誤解を招く「コミュニティ」には決してフォールバックしない
        if let cal = calendarViewModel.calendars.first(where: { $0.id == calendarId }) {
            return cal.name
        }
        return "共有カレンダー"
    }

    // MARK: - メインコンテンツ
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            // ★ 2026/08/21：グループカード・今日の予定カードの2段構成化やイベント件数の
            //   増加で縦幅が伸び、ホーム最初の1画面にタイムライン投稿のいいね等が
            //   収まりきらなくなった(ユーザー報告)。写真の表示サイズ(PostFeedCard側の
            //   固定260pt)はそのままに、ここと各カードの余白だけを詰めて空間を作る
            VStack(alignment: .leading, spacing: 8) {

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
        // ★ 2026/08/20修正：以前はグループ名とアイコン4つを同じ行に並べていたため、
        //   アイコンを1つ追加した(ユーザー検索)ことで横幅を圧迫し、「Heart2Heart」のような
        //   短い名前でも「Heart...」と省略される事態になっていた(ユーザー報告により発覚)。
        //   名前の行とアイコンの行を分け、グループ名は常にカードの全幅を使えるようにして、
        //   今後アイコンが増減しても名前が圧迫されない構成にする
        // ★ 2026/08/20再修正：ユーザーから提示されたデザイン案(2段構成・下段はラベル付き
        //   アイコンを区切り線で並べる)に合わせて作り直した。案の4つ目「招待」はこのアプリでは
        //   該当機能が無いため、実際の機能である「ユーザー検索」のまま踏襲する
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                if let group = selectedGroup {
                    GroupIcon(group: group, isSelected: false, size: 44)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(selectedGroup?.name ?? "OshiNium")
                            .font(.system(size: 20, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let group = selectedGroup {
                            Text(group.isPrivate ? "プライベート" : "コミュニティ")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accentColor.opacity(0.12)))
                        }
                    }

                    if let headerMemberCount {
                        Text("メンバー \(headerMemberCount)人")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                // ★ 通知（フォロー・予定・招待など）。以前はオシニウム（オリジナル）タブに
                //   あったが、より見つけやすいホーム画面の検索アイコンの隣に統合した
                headerIconColumn(
                    systemImage: "bell",
                    label: "通知",
                    showBadge: hasUnreadNotificationsForCurrentGroup
                ) {
                    NotificationsTab(currentGroup: selectedGroup)
                }

                headerDivider

                // ★ グッズ・ペンライトのいいねランキング、投稿いいね数の上位者、
                //   コミュニティへの予定追加数（貢献度）をまとめて見られるランキング画面
                headerIconButtonColumn(systemImage: "crown", label: "ランキング") {
                    showRanking = true
                }

                headerDivider

                // ★ 投稿の検索。キャプションで投稿を検索できるシートを開く
                headerIconButtonColumn(systemImage: "magnifyingglass", label: "検索") {
                    showPostSearch = true
                }

                headerDivider

                // ★ /ult監査(2026/08/18)で発見：他ユーザーを横断的に探す手段がグループ内の
                //   プロフィール経由しか無かった（成長ループの「他ユーザー発見」欠落）ため追加
                headerIconButtonColumn(systemImage: "person.crop.circle.fill", label: "ユーザー検索", overlaySystemImage: "magnifyingglass") {
                    showUserSearch = true
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .glossyHighlight(cornerRadius: 22)
        .padding(.horizontal, 16)
        // ★ mainContent側の.tint(.clear)（更新スピナーを隠すためのもの、下部の注記参照）は
        //   環境値としてsheetの中身にも伝わってしまい、閉じるボタン等の文字色まで透明にして
        //   しまう(実際に「投稿を検索」の閉じるボタンが空白になるバグとして報告された)。
        //   sheetごとに個別にtintを復元する
        .sheet(isPresented: $showPostSearch) {
            PostSearchView(selectedGroup: selectedGroup)
                .tint(accentColor)
        }
        .sheet(isPresented: $showUserSearch) {
            UserSearchView(group: selectedGroup)
                .tint(accentColor)
        }
        .sheet(isPresented: $showRanking) {
            RankingView(group: selectedGroup)
                .tint(accentColor)
        }
    }

    // MARK: - ヘッダー下段のラベル付きアイコン列（区切り線で仕切る、ユーザー提示のデザイン案に準拠）

    private var headerDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1, height: 30)
    }

    // ★ Buttonで即座にアクションを起こす系（ランキング・検索・ユーザー検索）
    private func headerIconButtonColumn(
        systemImage: String,
        label: String,
        overlaySystemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            headerIconColumnLabel(systemImage: systemImage, label: label, overlaySystemImage: overlaySystemImage, showBadge: false)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // ★ NavigationLinkで別画面へ遷移する系（通知。未読バッジも重ねる）
    private func headerIconColumn<Destination: View>(
        systemImage: String,
        label: String,
        showBadge: Bool,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            headerIconColumnLabel(systemImage: systemImage, label: label, overlaySystemImage: nil, showBadge: showBadge)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func headerIconColumnLabel(
        systemImage: String,
        label: String,
        overlaySystemImage: String?,
        showBadge: Bool
    ) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: overlaySystemImage != nil ? .center : .topTrailing) {
                Group {
                    if let overlaySystemImage {
                        ZStack {
                            Image(systemName: systemImage)
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: overlaySystemImage)
                                .font(.system(size: 9, weight: .bold))
                                .offset(x: 7, y: 7)
                        }
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(.systemGray6)))

                if showBadge {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 9, height: 9)
                        .offset(x: 1, y: -1)
                }
            }

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showBadge ? "\(label)、未読あり" : label)
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

        return VStack(alignment: .leading, spacing: 8) {

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
                            NavigationLink {
                                eventDestination(for: event)
                            } label: {
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
            VStack(alignment: .leading, spacing: 4) {
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
                            NavigationLink {
                                eventDestination(for: event)
                            } label: {
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    private func eventDestination(for event: Event) -> some View {
        EventDetailView(event: event, isOwner: isOwner, eventViewModel: eventViewModel)
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

    // ★ ベルのバッジも通知一覧（NotificationsTab）と同じ基準で判定する：groupIdを持つ
    //   通知（予定の追加・承認待ち・招待）は選択中のグループのものだけを対象にし、
    //   groupIdを持たない個人的な通知（フォロー・いいね等）は常に対象にする。
    //   以前はアプリ全体の未読数をそのまま見ていたため、他グループの未読で
    //   赤丸が点いているのに開くと（選択中グループには）何も新しくない、という
    //   食い違いが起きていた
    private var hasUnreadNotificationsForCurrentGroup: Bool {
        notificationViewModel.notifications.contains { notification in
            guard !notification.isRead else { return false }
            guard let groupId = notification.groupId else { return true }
            guard let selectedGroup else { return true }
            return groupId == selectedGroup.id
        }
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
                        // ★ Instagram/Threadsと同じく、10投稿に1件ほどの頻度で広告を挟む
                        if (index + 1).isMultiple(of: 10) {
                            Divider()
                            timelineAdCard
                        }
                        if index != timelinePosts.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // ★ タイムラインに挟む広告カード。他の投稿と見分けがつくよう「広告」ラベルを添える
    //   （App Store/景表法のガイドラインに沿い、広告であることを明示する）
    // ★ タイムラインカード内側の実際の余白(このView側16pt + 上位LazyVStack側14pt、
    //   両端合計60pt)を差し引いた実幅。固定320ptだとiPhone SE(375pt)で
    //   はみ出すため、AdBannerView側にこの実幅を渡してぴったり収める
    private var timelineAdWidth: CGFloat {
        max(UIScreen.main.bounds.width - 60, 0)
    }

    private var timelineAdCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("広告")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            AdBannerView(adUnitID: "ca-app-pub-8871310610756032/2089976241", width: timelineAdWidth)
                .frame(width: timelineAdWidth, height: AdBannerView.adaptiveHeight(forWidth: timelineAdWidth))
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("広告")
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
