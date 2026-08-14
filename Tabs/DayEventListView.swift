//
//  DayEventListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/25.
//

import SwiftUI
import NukeUI
import FirebaseAuth

struct DayEventListView: View {

    let date: Date
    let selectedGroup: IdolGroup
    var selectedCalendar: OshiCalendar? = nil
    var communityCalendarId: String? = nil
    let onSelect: (Event) -> Void   // ★ ここが追加

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var navState: AppNavigationState
    @EnvironmentObject var groupViewModel: GroupViewModel

    private var myUid: String? { Auth.auth().currentUser?.uid }

    // ★ 荒らし対策：予定を編集・削除できるのは「追加した本人」だけ（グループ内の権限差は廃止済み）。
    //   firestore.rules側の制限と同じ考え方をUI側でも反映し、権限が無いボタンはそもそも出さない
    private func canModify(_ event: Event) -> Bool {
        guard let myUid else { return false }
        return event.creatorUid == myUid
    }

    @Environment(\.dismiss) private var dismiss

    @State private var imageURLs: [String: URL] = [:]

    @State private var showAddMethodSelect = false
    @State private var showManualAdd = false
    @State private var showAIAdd = false
    @State private var showURLAdd = false
    @State private var copyingEvent: Event?
    @State private var eventPendingDelete: Event?

    // ★ .fullScreenCoverには標準シートのような下スワイプでの閉じ操作が無いため、
    //   自前でドラッグを検知して同じ挙動を再現する
    @GestureState private var dragOffset: CGFloat = 0

    // MARK: - 選択日のイベント（選択グループ・カレンダーでフィルタ）
    //   個人カレンダー選択時も、予定を組む上で重要なコミュニティカレンダーの予定は併せて表示する
    //   ★ 2026/08/11修正：コミュニティカレンダーの承認制（MonthlyCalendarView.isApprovedForMe
    //   参照）をここでは見ておらず、月表示のカレンダーには出ない未承認の予定が、日付をタップした
    //   先のこの一覧にだけ表示されてしまっていた（selectedCalendarが未選択の場合は
    //   コミュニティ判定すら素通りしていた、より広いすり抜けだった）
    private var eventsForDay: [Event] {
        let key = Calendar.current.startOfDay(for: date)
        let allEvents = eventViewModel.eventsByDate[key] ?? []
        return allEvents.filter { event in
            guard event.groupId == selectedGroup.id else { return false }
            // ★ 以前はselectedCalendarがnilの間、コミュニティ以外（プライベート・共有カレンダー）の
            //   予定を無条件に素通しさせていた。カレンダー読み込み中などselectedCalendarが
            //   未確定の間に、本来見えるべきでないプライベートの予定が一瞬でも見えてしまう/
            //   削除済みの予定が再表示される不具合があったため、MonthlyCalendarView.filteredEvents
            //   と同じ「コミュニティかつ承認済み」だけを安全側のデフォルトにする
            guard let oshiCalendar = selectedCalendar else {
                return isCommunityEvent(event) && isApprovedForMe(event)
            }

            if oshiCalendar.isCommunity {
                return isCommunityEvent(event) && isApprovedForMe(event)
            } else {
                return event.calendarId == oshiCalendar.id || (isCommunityEvent(event) && isApprovedForMe(event))
            }
        }
    }

    private func isCommunityEvent(_ event: Event) -> Bool {
        event.calendarId == nil || event.calendarId == communityCalendarId
    }

    private func isApprovedForMe(_ event: Event) -> Bool {
        guard let myUid else { return false }
        return event.approvedBy.contains(myUid)
    }

    // MARK: - 色ルール
    private func color(for type: EventType?) -> Color {
        switch type ?? .other {
        case .live, .event: return .red
        case .tv: return .green
        case .release: return .blue
        case .sns: return .orange
        case .anniversary: return .purple
        case .other: return .gray
        }
    }

    // ★ 「Aug 24, 2026」のような英語表記になっていたため、数字だけで判断できる
    //   日本語表記（8/24(月)）に統一する。曜日は漢字1文字だけをかっこで囲う
    private func japaneseDateLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "M/d(E)").string(from: date)
    }

    private func typeName(for type: EventType?) -> String {
        switch type ?? .other {
        case .live: return "ライブ"
        case .event: return "イベント"
        case .tv: return "出演・放送"
        case .release: return "リリース"
        case .sns: return "SNS"
        case .anniversary: return "記念日"
        case .other: return "その他"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - イベントなし
                if eventsForDay.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.7))
                            .accessibilityHidden(true)

                        Text("この日の予定はありません。")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 60)

                // MARK: - イベントあり
                } else {
                    ForEach(eventsForDay) { event in
                        eventRow(for: event)
                            .task {
                                await loadImageIfNeeded(for: event)
                            }
                    }

                    Spacer(minLength: 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .offset(y: dragOffset)
        .animation(.interactiveSpring(), value: dragOffset)
        // ★ .simultaneousGesture にすることで、リスト内のスクロール自体は妨げず、
        //   下方向に大きくドラッグして離したときだけ閉じる（一番上までスクロールした
        //   状態からさらに下に引っ張るのと同じ操作感）
        .simultaneousGesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    guard value.translation.height > 0 else { return }
                    state = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    }
                }
        )
        .navigationTitle(japaneseDateLabel(date))
        .navigationBarTitleDisplayMode(.inline)
        // ★ canModify(_:)がグループの権限（オーナー/管理者判定）を正しく解決できるよう、
        //   このグループのメンバー情報を読み込んでおく
        .onAppear {
            groupViewModel.fetchMembers(for: selectedGroup.id)
        }

        // ★ ここから下の遷移は「追加用の sheet」だけ残す

        .toolbar {
            // ★ .fullScreenCoverに変更したことで、シート特有の下スワイプでの閉じ操作が
            //   無くなったため、明示的な閉じるボタンを用意する
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("閉じる")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddMethodSelect = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .foregroundColor(.oshiniumPrimary)
                }
                .accessibilityLabel("予定を追加")
            }
        }

        .sheet(isPresented: $showAddMethodSelect) {
            AddMethodSelectView(
                onSelectAI: {
                    showAddMethodSelect = false
                    showAIAdd = true
                },
                onSelectURL: {
                    showAddMethodSelect = false
                    showURLAdd = true
                },
                onSelectManual: {
                    showAddMethodSelect = false
                    showManualAdd = true
                }
            )
        }

        .sheet(isPresented: $showManualAdd) {
            NavigationStack {
                // ★ 以前はselectedCalendar?.idをそのまま渡していたため、コミュニティカレンダー
                //   選択中（selectedCalendarはコミュニティのOshiCalendarそのもの、idはnilではない）
                //   でもcalendarIdがnilにならず、AddEventView側の「コミュニティに保存されます」の
                //   確認ダイアログが出ない等の不整合があった。AI追加・URL追加と同じ判定に揃える
                AddEventView(
                    selectedGroup: selectedGroup,
                    defaultDate: date,
                    calendarId: (selectedCalendar?.isCommunity ?? true) ? nil : selectedCalendar?.id
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            }
        }

        .sheet(isPresented: $showAIAdd) {
            NavigationStack {
                AIAddEventView(
                    selectedGroup: selectedGroup,
                    defaultDate: date,
                    calendarId: (selectedCalendar?.isCommunity ?? true) ? nil : selectedCalendar?.id
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            }
        }

        .sheet(isPresented: $showURLAdd) {
            NavigationStack {
                URLEventImportView(
                    selectedGroup: selectedGroup,
                    defaultDate: date,
                    calendarId: (selectedCalendar?.isCommunity ?? true) ? nil : selectedCalendar?.id
                )
                .environmentObject(eventViewModel)
            }
        }

        .sheet(item: $copyingEvent) { event in
            CopyEventView(event: event, eventViewModel: eventViewModel)
        }
        .alert(
            "「\(eventPendingDelete?.title ?? "この予定")」を削除しますか？",
            isPresented: Binding(
                get: { eventPendingDelete != nil },
                set: { if !$0 { eventPendingDelete = nil } }
            )
        ) {
            Button("キャンセル", role: .cancel) { eventPendingDelete = nil }
            Button("削除する", role: .destructive) {
                if let event = eventPendingDelete {
                    eventViewModel.deleteEvent(event)
                    navState.showToast("予定を削除しました")
                }
                eventPendingDelete = nil
            }
        } message: {
            if let event = eventPendingDelete, isCommunityEvent(event) {
                Text("あなたのカレンダーからのみ削除されます。他のメンバーのカレンダーには残ります。")
            } else {
                Text("この操作は取り消せません。")
            }
        }
    }

    // MARK: - シェア用テキスト
    private func shareText(for event: Event) -> String {
        var lines: [String] = ["【\(event.title.isEmpty ? "予定" : event.title)】"]
        lines.append(japaneseDateLabel(event.date))
        if let place = event.place, !place.isEmpty {
            lines.append("場所: \(place)")
        }
        if let url = event.url, !url.isEmpty {
            lines.append(url)
        } else if let officialURL = event.officialURL, !officialURL.isEmpty {
            lines.append(officialURL)
        }
        lines.append("via OshiNium")
        return lines.joined(separator: "\n")
    }

    // MARK: - カードUI
    private func eventRow(for event: Event) -> some View {
        VStack(spacing: 0) {

            HStack(spacing: 14) {

                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemGray6))

                    if let id = event.id,
                       let url = imageURLs[id] {

                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 150)
                                    .clipped()
                            } else {
                                placeholder(for: event)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    } else {
                        placeholder(for: event)
                    }
                }
                .frame(width: 110, height: 150)

                VStack(alignment: .leading, spacing: 8) {

                    Text(typeName(for: event.type))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color(for: event.type)))

                    Text(eventViewModel.group(for: event.groupId ?? "")?.name ?? "イベント")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer().frame(height: 6)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        Text(japaneseDateLabel(event.date))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    if let place = event.place {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            Text(place)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect(event)
            }
            // ★ onTapGestureだけだとVoiceOverからは個々のText断片がバラバラに
            //   読み上げられ、タップ可能なカードだと伝わらない。1つの要素にまとめ、
            //   ボタンとして認識させる
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)

            Divider()
                .padding(.horizontal, 14)

            // MARK: - コピー・シェア・削除（カード内アクション）
            HStack(spacing: 20) {
                Button {
                    copyingEvent = event
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color(for: event.type))
                }
                .buttonStyle(.plain)

                ShareLink(item: shareText(for: event)) {
                    Label("シェア", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                // ★ 荒らし対策：削除できるのは追加した本人か、グループの管理者・オーナーだけ
                if canModify(event) {
                    Button {
                        eventPendingDelete = event
                    } label: {
                        Label("削除", systemImage: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    // ★ グループの登録画像（IdolGroup.imageData）をイベント画像未設定時のフォールバックに使う。
    //   selectedGroupはこの画面のイベント全てに共通の所属グループなので、直接参照できる
    private var groupFallbackImage: UIImage? {
        guard let data = selectedGroup.imageData, !data.isEmpty else { return nil }
        return UIImage(data: data)
    }

    @ViewBuilder
    private func placeholder(for event: Event) -> some View {
        if let groupImage = groupFallbackImage {
            Image(uiImage: groupImage)
                .resizable()
                .scaledToFill()
                .frame(width: 110, height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            ZStack {
                LinearGradient(
                    colors: [color(for: event.type).opacity(0.7),
                             color(for: event.type).opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .accessibilityHidden(true)

                    Text(typeName(for: event.type))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
            .frame(width: 110, height: 150)
        }
    }

    private func loadImageIfNeeded(for event: Event) async {

        guard let id = event.id else { return }
        if imageURLs[id] != nil { return }

        if let urls = event.imageURLs,
           let first = urls.first,
           let directURL = URL(string: first) {

            DispatchQueue.main.async {
                imageURLs[id] = directURL
            }
            return
        }

        // ★ AIが検索時点で見つけている thumbnailURL があれば、わざわざ公式サイトを
        //   スクレイピングして画像URLを探しに行く（EventImageFetcher）必要はない。
        //   これが読み込みが遅くなる主な原因だった。
        if let thumb = event.thumbnailURL, let thumbURL = URL(string: thumb) {
            DispatchQueue.main.async {
                imageURLs[id] = thumbURL
            }
            return
        }

        guard let urlString = event.officialURL else { return }

        EventImageFetcher.fetchImageURL(from: urlString) { url in
            guard let url else { return }
            DispatchQueue.main.async {
                imageURLs[id] = url
            }
        }
    }
}
