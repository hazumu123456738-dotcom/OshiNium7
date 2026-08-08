//
//  EventHubPickerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI

// ★ オリジナルタブの入り口を「イベントダッシュボード」として設計する。
//   本日のライブ・今日やること・今後のイベント・チケット状況・推し活費用シミュレーターを
//   一画面にまとめ、イベント詳細に入る前に必要な情報を一目で確認できるようにする。
//   本日のライブ・今後のイベントは予定追加機能で登録された実データ（EventViewModel）から組み立てる。
struct EventHubPickerView: View {
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @Binding var selectedEvent: Event?

    // ★ ホーム画面で選択中のグループ。このタブもホームと連動して、
    //   そのグループのイベントだけを表示する（他グループのイベントは出さない）
    let currentGroup: IdolGroup?
    var onOpenCalendar: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var showSearchSheet = false
    @StateObject private var venueReportVM = VenueReportViewModel()
    @State private var venueReviewSearchText = ""
    @State private var showOtherOshiReviews = false
    @ObservedObject private var themeManager = ThemeManager.shared

    // ★ 自作の下タブバー分の余白を、画面下端に浮かせた要素だけでなく
    //   ScrollView自体の最後のコンテンツ（ツールのグリッド）にも足す必要がある。
    //   これが無いと、下までスクロールした時にツールの最後の行がタブバーの裏に隠れて見えない
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    // MARK: - データ

    // ★ 以前はstartOfDay(今日の0時)より後かどうかで判定していたため、「今日の0時開演」のように
    //   開演時刻がすでに過ぎたイベントでも、日付が今日である限りいつまでも「今後のイベント」に
    //   残り続けてしまっていた。開演時刻(範囲イベントならendDate、無ければdate)そのものが
    //   現在時刻を過ぎたかどうかで判定するように修正する
    private var upcomingEvents: [Event] {
        let now = Date()
        return eventViewModel.events
            .filter { ($0.endDate ?? $0.startDate ?? $0.date) >= now }
            .filter { $0.groupId == currentGroup?.id }
            .sorted { $0.date < $1.date }
    }

    private var todayEvent: Event? {
        upcomingEvents.first { Calendar.current.isDateInToday($0.date) }
    }

    private var searchResults: [Event]? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return upcomingEvents.filter { event in
            event.title.localizedCaseInsensitiveContains(trimmed)
                || (event.place?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (eventViewModel.group(for: event.groupId)?.name.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                topBar

                // ★ どのグループの画面かを示すアイコン・グループ名のすぐ下に
                //   今後のイベントを表示する（間の余白を詰める）
                VStack(alignment: .leading, spacing: 12) {
                    headline
                    upcomingSection
                }

                // ★ 本日のライブが無い日はこのタブに何も表示しない（セクションごと省略する）
                todaySection

                toolsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40 + customTabBarHeight)
        }
        .background(Color.appBackground.ignoresSafeArea())
        // ★ イベント・チケット等もリスナーで既に最新のため、標準スピナーで
        //   「更新した」手応えだけ返す（独自アニメーションはホーム画面だけ）
        .refreshable {
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        .sheet(isPresented: $showSearchSheet) {
            searchSheet
        }
        .onAppear {
            venueReportVM.startListeningAllReviews()
        }
        // ★ このタブはカスタムタブバーの下で常時マウントされたままになる構成のため、
        //   ここではonDisappearでのstopListeningを行わない。venueReviewsDetailや
        //   会場詳細ページへNavigationLinkでプッシュ遷移すると親のonDisappearが
        //   発火してしまい、遷移先が参照しているリスナーごと止まってしまう
        //   （EventHubDetailViewのようにsheetでのみ使う場合と違い、push遷移では成立しない）ため
    }

    // MARK: - トップバー

    // ★ 以前は左（ベル1個）と右（¥＋人アイコンの2個）の見た目の幅が違っていたため、
    //   中央のロゴがSpacerの釣り合いだけでは真ん中に来ず、少し左に寄って見えていた。
    //   ZStackで中央ロゴを独立させ、左右のアイコン幅に関係なく常に画面中央に固定する
    private var topBar: some View {
        ZStack {
            VStack(spacing: 2) {
                BrilliantDiamondIcon(
                    fill: AnyShapeStyle(
                        LinearGradient(colors: [accentColor, accentColor2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    ),
                    strokeColor: .white,
                    showFacets: true
                )
                .frame(width: 28, height: 28)

                OshiNiumWordmark(fontSize: 14, weight: .bold, color: accentColor)
            }

            HStack {
                // ★ 通知ベルはホームタブの検索アイコンの隣に統合したため、ここには置かない
                Button {
                    showSearchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("検索")

                Spacer()

                HStack(spacing: 14) {
                    NavigationLink {
                        OshiExpenseTrackerView()
                    } label: {
                        Image(systemName: "yensign.circle")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("推し活の金額")

                    Image(systemName: "person.circle")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(.primary)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - 検索シート

    private var searchSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                searchBar

                if let results = searchResults {
                    searchResultsSection(results)
                } else {
                    Text("イベント名・会場・アーティスト名で検索できます")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 24)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        showSearchSheet = false
                        searchText = ""
                    }
                }
            }
        }
    }

    // MARK: - 見出し（ホームと同じグループに連動していることがわかるように）

    @ViewBuilder
    private var headline: some View {
        if let currentGroup {
            HStack(spacing: 6) {
                GroupIcon(group: currentGroup, isSelected: false, size: 22)
                Text(currentGroup.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
    }

    // MARK: - 検索バー

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            TextField("イベント・会場・アーティストを検索", text: $searchText)
                .font(.system(size: 14))
                .autocapitalization(.none)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .accessibilityLabel("検索文字をクリア")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - 検索結果

    private func searchResultsSection(_ results: [Event]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("検索結果", trailing: nil, action: nil)

            if results.isEmpty {
                Text("「\(searchText)」に一致する予定が見つかりませんでした")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 12) {
                    ForEach(results) { event in
                        searchResultRow(event)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .onTapGesture {
                                selectedEvent = event
                                showSearchSheet = false
                                searchText = ""
                            }
                    }
                }
            }
        }
    }

    private func searchResultRow(_ event: Event) -> some View {
        let group = eventViewModel.group(for: event.groupId)

        return HStack(spacing: 12) {
            EventThumbnailImage(event: event, group: group, width: 52, height: 52, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                if let place = event.place, !place.isEmpty {
                    Text(place)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - 本日のライブ（無い日はセクションごと非表示にする）

    @ViewBuilder
    private var todaySection: some View {
        if let event = todayEvent {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("本日のライブ", trailing: "すべて見る") {
                    selectedEvent = event
                }
                todayCard(event)
            }
        }
    }

    private func todayCard(_ event: Event) -> some View {
        let group = eventViewModel.group(for: event.groupId)

        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                EventThumbnailImage(event: event, group: group, width: 100, height: 100, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("本日開催")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor))

                    Text(event.title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(2)

                    if let place = event.place, !place.isEmpty {
                        Label(place, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Label(timeLabel(event.date), systemImage: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                VStack(spacing: 3) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange.opacity(0.7))
                        .accessibilityHidden(true)
                    Text("準備中")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Button {
                selectedEvent = event
            } label: {
                Text("本日のライブを見る")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accentColor.opacity(0.1))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
        )
        .glossyHighlight(cornerRadius: 22)
    }

    // MARK: - 今後のイベント

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("今後のイベント", trailing: onOpenCalendar != nil ? "カレンダーで見る" : nil) {
                onOpenCalendar?()
            }

            if upcomingEvents.isEmpty {
                Text(currentGroup.map { "\($0.name)の予定はまだ登録されていません" } ?? "グループが選択されていません")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(upcomingEvents) { event in
                            upcomingCard(event)
                                .onTapGesture { selectedEvent = event }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func upcomingCard(_ event: Event) -> some View {
        let group = eventViewModel.group(for: event.groupId)
        let typeColor = (event.type ?? .other).iconColor

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                EventThumbnailImage(event: event, group: group, width: 140, height: 100, cornerRadius: 16)

                Text((event.type ?? .other).displayName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(typeColor))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel(event.date))
                    .font(.system(size: 11, weight: .semibold))
                Text(timeLabel(event.date))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            if let place = event.place, !place.isEmpty {
                Label(place, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 140, alignment: .leading)
    }

    // MARK: - 会場口コミ（グループ内で書かれた口コミを会場横断で検索・閲覧）

    // ★ イベント詳細画面（EventHubDetailView）の「会場口コミを書く」から投稿された
    //   口コミを、会場（place）単位でここに集約する。書き込みはイベント詳細側の
    //   専用フォームからのみ行い、ここは会場を検索して読むだけの入り口にする。
    //   初期状態は自分が登録している推しグループの口コミのみ、トグルONで同じカテゴリの
    //   他グループの口コミも表示する（groupCategoryはsubmit時にスナップショットされたもの）
    private var myGroupIds: Set<String> {
        Set(groupViewModel.groups.map(\.id))
    }

    private var myCategories: Set<GroupCategory> {
        Set(groupViewModel.groups.compactMap(\.category))
    }

    private func visibleReviews(includeOtherOshi: Bool) -> [VenueReport] {
        venueReportVM.allReviews.filter { report in
            if myGroupIds.contains(report.groupId) { return true }
            guard includeOtherOshi,
                  let categoryRaw = report.groupCategory,
                  let category = GroupCategory(rawValue: categoryRaw)
            else { return false }
            return myCategories.contains(category)
        }
    }

    private struct VenueSummary: Identifiable {
        let place: String
        var id: String { place }
        let reviewCount: Int
        let latestReview: VenueReport?
    }

    private func venueSummaries(includeOtherOshi: Bool) -> [VenueSummary] {
        let grouped = Dictionary(grouping: visibleReviews(includeOtherOshi: includeOtherOshi)) {
            ($0.place ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.key.isEmpty }

        return grouped.map { place, reports in
            VenueSummary(
                place: place,
                reviewCount: reports.count,
                latestReview: reports.max { $0.createdAt < $1.createdAt }
            )
        }
        .sorted { $0.reviewCount > $1.reviewCount }
    }

    private var filteredVenueSummaries: [VenueSummary] {
        let all = venueSummaries(includeOtherOshi: showOtherOshiReviews)
        let trimmed = venueReviewSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.place.localizedCaseInsensitiveContains(trimmed) }
    }

    private var venueReviewsDetail: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                venueReviewSearchField
                otherOshiToggleCard

                if filteredVenueSummaries.isEmpty {
                    emptyStateCard(
                        icon: venueReviewSearchText.isEmpty ? "text.bubble" : "magnifyingglass",
                        text: venueReviewSearchText.isEmpty
                            ? "会場の口コミはまだ投稿されていません"
                            : "「\(venueReviewSearchText)」に一致する会場が見つかりませんでした"
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredVenueSummaries) { venue in
                            NavigationLink {
                                VenueDetailView(
                                    place: venue.place,
                                    venueReportVM: venueReportVM,
                                    myGroupIds: myGroupIds,
                                    myCategories: myCategories,
                                    initialShowOtherOshi: showOtherOshiReviews,
                                    writeGroup: currentGroup
                                )
                            } label: {
                                venueSummaryRow(venue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("会場口コミ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var venueReviewSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            TextField("会場名で検索（例：東京ドーム）", text: $venueReviewSearchText)
                .font(.system(size: 14))
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    private var otherOshiToggleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $showOtherOshiReviews) {
                Text("他の推しの口コミを見る")
                    .font(.system(size: 13, weight: .semibold))
            }
            .tint(accentColor)

            if !myCategories.isEmpty {
                let categoryLabel = myCategories.map(\.rawValue).sorted().joined(separator: "・")
                Text("同じカテゴリ（\(categoryLabel)）の口コミも表示します")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // ★ 会場カード：会場名・件数・最新の口コミ1件のプレビューだけを見せ、
    //   詳細（住所・地図・全件）は会場詳細ページ（VenueDetailView）に譲る
    private func venueSummaryRow(_ venue: VenueSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accentColor.opacity(0.12))
                Image(systemName: "building.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(accentColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(venue.place)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let latest = venue.latestReview {
                    Text(latest.text)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text("\(venue.reviewCount)件")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - ツール（チケット状況・費用シミュレーター・あったら便利な機能をボタン式で並べる）
    //   ★ それぞれ専用のイラスト風アイコンを載せたボタンにし、規則正しい3列グリッドで揃える

    private struct ToolItem {
        let icon: String
        let label: String
        let colors: [Color]
        let badge: String?
    }

    private var toolItems: [ToolItem] {
        [
            ToolItem(
                icon: "text.bubble.fill",
                label: "会場口コミ",
                colors: [Color(red: 0.35, green: 0.62, blue: 0.95), Color(red: 0.45, green: 0.80, blue: 0.90)],
                badge: venueSummaries(includeOtherOshi: false).isEmpty ? nil : "\(venueSummaries(includeOtherOshi: false).count)"
            ),
            ToolItem(
                icon: "yensign.circle.fill",
                label: "推し活費用\nシミュレーター",
                colors: [accentColor, accentColor2],
                badge: nil
            ),
            ToolItem(
                icon: "checklist",
                label: "持ち物\nチェックリスト",
                colors: [Color(red: 0.40, green: 0.72, blue: 0.55), Color(red: 0.55, green: 0.82, blue: 0.60)],
                badge: nil
            ),
            ToolItem(
                icon: "sparkles",
                label: "今日の\n推し活占い",
                colors: [Color(red: 0.95, green: 0.72, blue: 0.35), Color(red: 0.95, green: 0.55, blue: 0.55)],
                badge: nil
            ),
            ToolItem(
                icon: "flashlight.on.fill",
                label: "ペンライト\n・グッズ",
                colors: [Color(red: 0.60, green: 0.45, blue: 0.90), Color(red: 0.85, green: 0.50, blue: 0.85)],
                badge: nil
            ),
            ToolItem(
                icon: "book.closed.fill",
                label: "思い出日記",
                colors: [Color(red: 0.25, green: 0.65, blue: 0.72), Color(red: 0.35, green: 0.80, blue: 0.78)],
                badge: nil
            ),
            ToolItem(
                icon: "paintpalette.fill",
                label: "着せ替え\nカスタマイズ",
                colors: [themeManager.activeTheme.baseColor.color, themeManager.activeTheme.accentColor.color],
                badge: nil
            )
        ]
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ツール", trailing: nil, action: nil)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                NavigationLink { venueReviewsDetail } label: { toolButton(toolItems[0]) }
                    .buttonStyle(.plain)

                NavigationLink { OshiExpenseTrackerView() } label: { toolButton(toolItems[1]) }
                    .buttonStyle(.plain)

                NavigationLink { PackingChecklistView() } label: { toolButton(toolItems[2]) }
                    .buttonStyle(.plain)

                NavigationLink { OshiFortuneView(group: currentGroup) } label: { toolButton(toolItems[3]) }
                    .buttonStyle(.plain)

                NavigationLink { GoodsPenlightHubView(group: currentGroup) } label: { toolButton(toolItems[4]) }
                    .buttonStyle(.plain)

                NavigationLink { MemoryDiaryListView(group: currentGroup) } label: { toolButton(toolItems[5]) }
                    .buttonStyle(.plain)

                // ★ ポイント交換景品として解放した人だけに表示する「着せ替え」タイル。
                //   末尾に追加するため、既存の6件(2行×3列)の次の行の先頭に表示される
                if themeManager.isToolUnlocked {
                    NavigationLink { ThemeCustomizationView() } label: { toolButton(toolItems[6]) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func toolButton(_ item: ToolItem) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Image(systemName: item.icon)
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)
                    )
                    .shadow(color: item.colors[0].opacity(0.35), radius: 8, x: 0, y: 4)

                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .frame(minWidth: 16)
                        .background(Circle().fill(Color.red))
                        .offset(x: 6, y: -6)
                }
            }

            Text(item.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 空状態カード（共通）

    private func emptyStateCard(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary.opacity(0.6))
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 共通パーツ

    private func sectionHeader(_ title: String, trailing: String?, action: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Spacer()
            if let trailing {
                Button { action?() } label: {
                    HStack(spacing: 2) {
                        Text(trailing)
                        Image(systemName: "chevron.right")
                            .accessibilityHidden(true)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                }
            }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm開演"
        return f.string(from: date)
    }
}
