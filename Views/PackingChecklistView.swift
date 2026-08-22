//
//  PackingChecklistView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import FirebaseAuth

// ★ オシニウムタブの「あったら便利な機能」その1：ライブ・イベント当日の持ち物チェックリスト。
//   推し活の金額計算（OshiExpenseTrackerView）と同じ構成にする：Firestoreにuidで絞り込んで
//   保存し、本人にしか見えない記録として扱う。カレンダーで「いつの持ち物か」を選んで
//   日ごと・グループごとに追加できるようにする
struct PackingChecklistView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var navState: AppNavigationState
    @StateObject private var checklistVM = PackingChecklistViewModel()
    @State private var showAddSheet = false
    @State private var showTemplateManager = false
    @State private var editingItem: PackingChecklistItem?

    @State private var displayedMonth = Date()
    // ★ 開いた直後は「その月全部の持ち物」ではなく「今日の持ち物」だけを表示したいので、
    //   未選択(nil)ではなく今日の日付を初期値にする。カレンダーで別の日をタップすれば、
    //   これまで通りその日の持ち物に絞り込まれる
    @State private var selectedDay: Date? = Date()

    // ★ 2026/08/21追加：予定が多いグループが混ざると見分けづらいというユーザー指摘を受け、
    //   OshiExpenseTrackerViewと同じくカレンダーに出す「予定」だけグループごとに切り替えられる
    //   ようにする。持ち物そのもの(markedDates)はグループを問わず登録した全件のドットを
    //   常に表示したままにする(こちらはグループを絞る対象ではない)
    @State private var selectedCalendarGroup: IdolGroup?

    // ★ Firestoreの削除はネットワーク経由で反映が非同期のため、スワイプ削除の見た目は
    //   ローカルで即座に隠して滑らかにアニメーションさせる（実際の削除リクエストは裏で並行して送る）
    @State private var pendingDeleteIDs: Set<String> = []

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)
    private let accentColor2 = Color(red: 0.55, green: 0.82, blue: 0.60)
    private var myUid: String? { Auth.auth().currentUser?.uid }

    private var visibleItems: [PackingChecklistItem] {
        let monthItems = checklistVM.items(inMonth: displayedMonth).filter { !pendingDeleteIDs.contains($0.id) }
        guard let selectedDay else { return monthItems.sorted { $0.date > $1.date } }
        return monthItems
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
    }

    private var listTitle: String {
        if let selectedDay {
            return "\(dayLabel(selectedDay))の持ち物"
        }
        return "\(monthLabel(displayedMonth))の持ち物"
    }

    private var checkedCount: Int { visibleItems.filter(\.isChecked).count }

    // ★ 選択中グループのコミュニティカレンダーID。承認済みかどうかの判定に必要
    private func communityCalendarId(for groupId: String) -> String? {
        calendarViewModel.calendars.first(where: { $0.isCommunity && $0.groupId == groupId })?.id
    }

    // ★ 選択中の日に、選択中グループの予定があれば、その一覧を返す
    //   ★ 2026/08/21修正：groupIdだけの絞り込みだと、コミュニティカレンダーの未承認予定
    //   (他メンバーが追加したがまだ自分が承認していない予定)まで混ざって出てしまっていた。
    //   Event.visibleEventsForGroupで、カレンダータブ本体と同じ承認状態のチェックを揃える
    private var selectedDayEvents: [Event] {
        guard let selectedDay, let groupId = selectedCalendarGroup?.id else { return [] }
        let events = eventViewModel.myEventsByDate[Calendar.current.startOfDay(for: selectedDay)] ?? []
        return Event.visibleEventsForGroup(
            from: events, groupId: groupId,
            communityCalendarId: communityCalendarId(for: groupId), myUid: myUid
        )
    }

    // ★ ミニカレンダーに予定の印(✦)を付ける日付。選択中グループの、実際にカレンダータブに
    //   表示される予定(未承認のコミュニティ予定は除く)がある日だけに絞る。
    //   持ち物のドット(checklistVM.markedDates)はここでは絞らず、常に全グループぶん表示する
    private var selectedGroupEventDates: Set<Date> {
        guard let groupId = selectedCalendarGroup?.id else { return [] }
        let communityId = communityCalendarId(for: groupId)
        var dates: Set<Date> = []
        for (day, events) in eventViewModel.myEventsByDate {
            if !Event.visibleEventsForGroup(from: events, groupId: groupId, communityCalendarId: communityId, myUid: myUid).isEmpty {
                dates.insert(day)
            }
        }
        return dates
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ★ 以前は ScrollView + VStack + 独自ドラッグジェスチャー(SwipeToDeleteRow)で
            //   スワイプ削除を再現していたが、縦スクロールのScrollViewと横方向ドラッグの
            //   ジェスチャーが競合し、スワイプがほとんど反応しなくなっていた。
            //   Listのネイティブ.swipeActionsに切り替えることで、Appleの標準実装に委ね
            //   確実に動くようにする
            List {
                Section {
                    calendarCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    if visibleItems.isEmpty {
                        emptyItemsState
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        if checkedCount == visibleItems.count {
                            allCheckedBanner
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        ForEach(visibleItems) { item in
                            itemRowContent(item)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            _ = pendingDeleteIDs.insert(item.id)
                                        }
                                        // ★ 2026/08/15修正：削除失敗時、以前はpendingDeleteIDsに
                                        //   入れっぱなしでアイテムが一覧から消えたままになっていた
                                        checklistVM.deleteItem(item) { error in
                                            if error != nil {
                                                pendingDeleteIDs.remove(item.id)
                                                navState.showToast("削除できませんでした")
                                            }
                                        }
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    itemListHeader
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                Color.clear.frame(height: 90)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())

            addButton
        }
        .navigationTitle("持ち物チェックリスト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTemplateManager = true
                } label: {
                    Image(systemName: "square.stack.3d.up")
                }
                .accessibilityLabel("マイテンプレート")
            }
        }
        .onAppear {
            if let myUid { checklistVM.startListening(uid: myUid) }
            if selectedCalendarGroup == nil { selectedCalendarGroup = groupViewModel.groups.first }
        }
        .onChange(of: groupViewModel.groups) { _, newGroups in
            if selectedCalendarGroup == nil { selectedCalendarGroup = newGroups.first }
        }
        .onDisappear { checklistVM.stopListening() }
        .sheet(isPresented: $showAddSheet) {
            AddPackingItemView(checklistVM: checklistVM, defaultDate: selectedDay ?? Date(), accentColor: accentColor, accentColor2: accentColor2)
        }
        .sheet(isPresented: $showTemplateManager) {
            PackingTemplateManagerView(targetDate: selectedDay ?? Date()) { items, chosenDate, chosenRemindAts in
                guard let myUid else { return }
                checklistVM.addItems(uid: myUid, groupId: nil, groupName: nil, titles: items, date: chosenDate, remindAts: chosenRemindAts) { error in
                    if error != nil { navState.showToast("追加できませんでした") }
                }
            }
            .environmentObject(eventViewModel)
        }
        .sheet(item: $editingItem) { item in
            EditPackingItemView(checklistVM: checklistVM, item: item, accentColor: accentColor, accentColor2: accentColor2)
                .environmentObject(eventViewModel)
        }
    }

    // MARK: - 追加ボタン（自作の下タブバーの裏に隠れないよう高さを足す）

    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel("持ち物を追加")
        .padding(.trailing, 20)
        .padding(.bottom, 20 + customTabBarHeight)
    }

    // MARK: - カレンダーカード（月送り・日タップで絞り込める）

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("いつの持ち物か", systemImage: "calendar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(checklistVM.items(inMonth: displayedMonth).count)件")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
            }

            SharedScopeBadge(scope: .private, tint: accentColor)

            if !groupViewModel.groups.isEmpty {
                calendarGroupChips
            }

            ExpenseMiniCalendar(
                displayedMonth: $displayedMonth,
                selectedDate: $selectedDay,
                markedDates: checklistVM.markedDates,
                eventDates: selectedGroupEventDates,
                accentColor: accentColor
            )

            if !selectedDayEvents.isEmpty {
                CalendarEventDetailRow(events: selectedDayEvents)
            }

            if selectedDay != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDay = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .accessibilityHidden(true)
                        Text("日付の絞り込みを解除")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ カレンダーに予定を出すグループの切り替えチップ（持ち物のドット表示には影響しない）
    private var calendarGroupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groupViewModel.groups) { g in
                    let isSelected = selectedCalendarGroup?.id == g.id
                    Button {
                        selectedCalendarGroup = g
                    } label: {
                        Text(g.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule().fill(
                                            LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                                        )
                                    } else {
                                        Capsule().fill(Color(.systemGray6))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 一覧（選択中の月・日に応じて絞り込む）

    private var itemListHeader: some View {
        HStack {
            Text(listTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
            if !visibleItems.isEmpty {
                Spacer()
                Text("\(checkedCount)/\(visibleItems.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .textCase(nil)
    }

    // ★ その日(または月)の持ち物が全部チェック済みの時だけ出す、完了バナー。
    //   PackingChecklistViewModel側の通知(sendPackingAllCheckedNotification)と対になる、
    //   アプリを開いている間の視覚的なフィードバック
    private var allCheckedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("準備完了です")
                    .font(.system(size: 14, weight: .bold))
                Text("持ち物が全部そろいました")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accentColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var emptyItemsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
                .accessibilityHidden(true)
            Text(selectedDay != nil ? "この日の持ち物はまだありません" : "この月の持ち物はまだありません")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func itemRowContent(_ item: PackingChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button {
                checklistVM.toggleChecked(item) { error in
                    if error != nil { navState.showToast("更新できませんでした") }
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundColor(item.isChecked ? accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title)
            .accessibilityValue(item.isChecked ? "チェック済み" : "未チェック")
            .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked)

                HStack(spacing: 6) {
                    Text(dayLabel(item.date))
                    if let groupName = item.groupName, !groupName.isEmpty {
                        Text("・\(groupName)")
                    }
                    if let firstRemindAt = item.remindAts.min() {
                        let extra = item.remindAts.count - 1
                        Label(extra > 0 ? "\(reminderTimeLabel(firstRemindAt))・他\(extra)件" : reminderTimeLabel(firstRemindAt), systemImage: "bell.fill")
                            .foregroundColor(accentColor)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            // ★ タイトル・日付・通知リマインドを後から変更できるように
            Button {
                editingItem = item
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 19))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("「\(item.title)」を編集")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    private func dayLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "M/d(E)").string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "M月").string(from: date)
    }

    private func reminderTimeLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "HH:mm").string(from: date)
    }
}

// MARK: - 持ち物追加フォーム（推し活の金額の追加フォームと同じ「白カードを積んだ」構成）

private struct AddPackingItemView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var navState: AppNavigationState
    @ObservedObject var checklistVM: PackingChecklistViewModel
    let defaultDate: Date
    let accentColor: Color
    let accentColor2: Color

    @Environment(\.dismiss) private var dismiss
    // ★ テンプレート作成画面と同じく、複数の持ち物を1回でまとめて追加できるように
    //   単一のtitleではなく可変長の配列にする
    @State private var itemTexts: [String] = [""]
    @State private var date: Date
    @State private var calendarMonth: Date
    @State private var selectedGroupId: String?
    @State private var showDatePicker = false
    // ★ 以前は「通知するか(Bool)」＋「時刻(Date)」の単一プロパティだったため
    //   リマインドが1個しか設定できなかった。何個でも自由に追加・削除できるよう配列にする
    @State private var reminderTimes: [Date] = []
    @State private var showTemplatePicker = false
    // ★ 2026/08/21追加：日付選択シートのカレンダーに出す予定をグループごとに切り替えるための状態。
    //   保存する持ち物自体のタグ(selectedGroupId、上の「推しグループ（任意）」)とは別物で、
    //   あくまでカレンダー上でどのグループの予定を見るかだけを切り替える
    @State private var calendarGroup: IdolGroup?

    init(checklistVM: PackingChecklistViewModel, defaultDate: Date, accentColor: Color, accentColor2: Color) {
        self.checklistVM = checklistVM
        self.defaultDate = defaultDate
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        _date = State(initialValue: defaultDate)
        _calendarMonth = State(initialValue: defaultDate)
    }

    private var myUid: String? { Auth.auth().currentUser?.uid }

    private var trimmedItems: [String] {
        itemTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    // ★ 過去の時刻でリマインドが設定されてしまうと、UNCalendarNotificationTrigger
    //   (repeats: false)は二度と発火しない。「持ち物ツールの通知だけ来ない」不具合の
    //   主因だったため、保存自体をブロックする最後の砦としてここでも確認する
    //   （日時ピッカー側の`in:`制限が主な防止策、これは念のための二重チェック）
    private var canSave: Bool {
        guard !trimmedItems.isEmpty else { return false }
        if reminderTimes.contains(where: { $0 < Date() }) { return false }
        return true
    }

    // ★ 今日を選んでいる場合は「現在時刻以降」しか選べないようにする
    private var reminderTimeRange: ClosedRange<Date> {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
            return Date()...endOfDay
        } else {
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? date
            return startOfDay...endOfDay
        }
    }

    // ★ reminderTimeは時刻(時・分)だけを気にした値だが、内部的にはDateなので
    //   年月日が「持ち物の日付」からズレたままだと、上のreminderTimeRangeとの
    //   比較(同じ日かどうか)がおかしくなる。dateが変わるたびに年月日を合わせ直す
    private func alignedReminderTime(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? time
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    itemsCard
                    dateCard
                    reminderCard
                    if !groupViewModel.groups.isEmpty {
                        groupCard
                    }
                    saveButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("持ち物を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onChange(of: date) { _, newDate in
                reminderTimes = reminderTimes.map { alignedReminderTime(day: newDate, time: $0) }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplateUsePickerSheet(targetDate: date) { items in
                    applyTemplateItems(items)
                }
                .environmentObject(eventViewModel)
            }
        }
    }

    // MARK: - 持ち物名（テンプレート作成画面と同じく、+ボタンで何個でも行を増やせる）

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("持ち物")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(itemTexts.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("例：ペンライト、うちわ", text: $itemTexts[index])
                            .font(.system(size: 15, weight: .semibold))

                        if itemTexts.count > 1 {
                            Button {
                                itemTexts.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .accessibilityLabel("この持ち物を削除")
                        }
                    }
                }
            }

            Button {
                itemTexts.append("")
            } label: {
                Label("持ち物を追加", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            // ★ 自分のテンプレートから持ち物をまとめて呼び出せる導線。
            //   テンプレートが無い人には作成できることを案内する
            Button {
                showTemplatePicker = true
            } label: {
                Label("テンプレートを使用", systemImage: "square.stack.3d.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ テンプレートから選んだ持ち物を、既存の入力欄に追記する（空の1行だけの状態なら置き換える）
    private func applyTemplateItems(_ items: [String]) {
        let existingNonEmpty = itemTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        itemTexts = existingNonEmpty.isEmpty ? items : existingNonEmpty + items
        if itemTexts.isEmpty { itemTexts = [""] }
    }

    // MARK: - 日付（カレンダーで選ぶ）

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いつの持ち物？")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Button {
                calendarMonth = date
                showDatePicker = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(accentColor.opacity(0.12))
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentColor)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 36, height: 36)

                    Text(dateDisplayText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 通知リマインド（当日の指定した時刻に「持ち物を確認して」と知らせる。何個でも追加できる）

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("通知でリマインドする", systemImage: "bell.fill")
                .font(.system(size: 14, weight: .semibold))

            ForEach(reminderTimes.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        DatePicker(
                            "通知する時刻",
                            selection: Binding(
                                get: { reminderTimes[index] },
                                set: { reminderTimes[index] = alignedReminderTime(day: date, time: $0) }
                            ),
                            in: reminderTimeRange,
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .font(.system(size: 14, weight: .semibold))
                        .datePickerStyle(.compact)

                        Spacer(minLength: 0)

                        Button {
                            reminderTimes.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .accessibilityLabel("このリマインドを削除")
                    }

                    if reminderTimes[index] < Date() {
                        Text("この時刻はすでに過ぎています。現在時刻より後の時刻を選んでください")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }

            Button {
                reminderTimes.append(defaultReminderTime())
            } label: {
                Label("リマインドを追加", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            if !reminderTimes.isEmpty {
                Text("\(dayLabel(date))の指定時刻に「\(trimmedItems.isEmpty ? "持ち物" : trimmedItems.joined(separator: "・"))」を忘れずにとお知らせします")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ リマインドを追加した瞬間のデフォルト時刻（当日の朝9時。範囲外なら選べる最も近い時刻に丸める）
    private func defaultReminderTime() -> Date {
        let proposed = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let range = reminderTimeRange
        if proposed < range.lowerBound { return range.lowerBound }
        if proposed > range.upperBound { return range.upperBound }
        return proposed
    }

    private func dayLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "M月d日").string(from: date)
    }

    private var dateDisplayText: String {
        return CachedFormatters.date(format: "yyyy年M月d日（E）").string(from: date)
    }

    private func communityCalendarId(for groupId: String) -> String? {
        calendarViewModel.calendars.first(where: { $0.isCommunity && $0.groupId == groupId })?.id
    }

    // ★ 日付選択カレンダーに予定の印(✦)を出す日付。選択中グループの、実際にカレンダータブに
    //   表示される予定(未承認のコミュニティ予定は除く)がある日だけに絞る
    //   ★ 2026/08/21修正：groupIdだけの絞り込みだと未承認のコミュニティ予定まで混ざっていた
    private var calendarGroupEventDates: Set<Date> {
        guard let groupId = calendarGroup?.id else { return [] }
        let communityId = communityCalendarId(for: groupId)
        var dates: Set<Date> = []
        for (day, events) in eventViewModel.myEventsByDate {
            if !Event.visibleEventsForGroup(from: events, groupId: groupId, communityCalendarId: communityId, myUid: myUid).isEmpty {
                dates.insert(day)
            }
        }
        return dates
    }

    private var calendarGroupEventsOnSelectedDate: [Event] {
        guard let groupId = calendarGroup?.id else { return [] }
        let events = eventViewModel.myEventsByDate[Calendar.current.startOfDay(for: date)] ?? []
        return Event.visibleEventsForGroup(
            from: events, groupId: groupId,
            communityCalendarId: communityCalendarId(for: groupId), myUid: myUid
        )
    }

    // ★ このシートは「シートの上にさらに重ねるシート」として表示されるため、ここに
    //   もう一段NavigationStack+navigationTitleを重ねると、iOSのシート遷移中に
    //   2つのナビゲーションバーのタイトル文字が同じ位置に描画されて重なって見える
    //   既知の不具合があった。navigationTitleを使わず、自前のヘッダー行に置き換えて回避する
    //   ★ 2026/08/21修正：.presentationDetents([.medium])に固定していたため、グループチップを
    //   追加した分もあわせてカレンダー下部が画面に入り切らなくなっていた(ユーザー報告)。
    //   .largeも選べるようにし、開いた瞬間から余裕を持って全体が収まるようにする
    private var datePickerSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("日付を選択")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("完了") { showDatePicker = false }
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ★ グループチップ追加で縦幅が伸びたため、.mediumだけでは
            //   ヘッダーごと上下中央揃えで見切れてしまっていた(ユーザー報告)。
            //   ScrollViewで包んで、どんな画面サイズでも中身が絶対に見切れないようにする
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        if !groupViewModel.groups.isEmpty {
                            datePickerGroupChips
                        }

                        ExpenseMiniCalendar(
                            displayedMonth: $calendarMonth,
                            selectedDate: Binding(
                                get: { date },
                                set: { newValue in
                                    if let newValue { date = newValue }
                                }
                            ),
                            eventDates: calendarGroupEventDates,
                            accentColor: accentColor
                        )

                        if !calendarGroupEventsOnSelectedDate.isEmpty {
                            CalendarEventDetailRow(events: calendarGroupEventsOnSelectedDate)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    Button {
                        date = defaultDate
                        calendarMonth = defaultDate
                    } label: {
                        Text("その日にする")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            if calendarGroup == nil { calendarGroup = groupViewModel.groups.first }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var datePickerGroupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groupViewModel.groups) { g in
                    let isSelected = calendarGroup?.id == g.id
                    Button {
                        calendarGroup = g
                    } label: {
                        Text(g.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule().fill(
                                            LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                                        )
                                    } else {
                                        Capsule().fill(Color(.systemGray6))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - グループ（チップ）

    private var groupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("推しグループ（任意）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    groupChip(name: "指定しない", isSelected: selectedGroupId == nil) {
                        selectedGroupId = nil
                    }
                    ForEach(groupViewModel.groups) { g in
                        groupChip(name: g.name, isSelected: selectedGroupId == g.id) {
                            selectedGroupId = g.id
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func groupChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(
                                LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                            )
                        } else {
                            Capsule().fill(Color(.systemGray6))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 保存ボタン

    private var saveButton: some View {
        Button {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            let groupName = groupViewModel.groups.first(where: { $0.id == selectedGroupId })?.name
            checklistVM.addItems(uid: uid, groupId: selectedGroupId, groupName: groupName, titles: trimmedItems, date: date, remindAts: reminderTimes) { error in
                if error != nil { navState.showToast("追加できませんでした") }
            }
            dismiss()
        } label: {
            Text("保存する")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .opacity(canSave ? 1 : 0.5)
        }
        .disabled(!canSave)
        .padding(.top, 4)
    }
}

// MARK: - 持ち物を追加画面の「テンプレートを使用」から開く、テンプレート選択シート

// ★ 「持ち物を追加」フォームの中から自分のテンプレートを呼び出すための軽量な選択画面。
//   選ぶとその場でitemTexts（フォームの入力欄）に反映されるだけで、まだFirestoreへは保存しない
//   （最終的な保存は「持ち物を追加」フォーム自身の保存ボタンで行う）。
//   テンプレートが1件も無い場合／さらにテンプレートを作りたい場合は、
//   持ち物ツール右上の「マイテンプレート」ボタンと同じPackingTemplateManagerViewへ遷移する
private struct TemplateUsePickerSheet: View {
    let targetDate: Date
    let onSelect: ([String]) -> Void

    @EnvironmentObject var eventViewModel: EventViewModel
    @StateObject private var templateVM = PackingTemplateViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showTemplateManager = false

    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)
    private var myUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if templateVM.templates.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(templateVM.templates) { template in
                                templateRow(template)
                            }
                            createRow
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("テンプレートを使用")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                if let myUid { templateVM.startListening(uid: myUid) }
            }
            .onDisappear { templateVM.stopListening() }
            .sheet(isPresented: $showTemplateManager) {
                PackingTemplateManagerView(targetDate: targetDate) { items, _, _ in
                    onSelect(items)
                    dismiss()
                }
                .environmentObject(eventViewModel)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
                .accessibilityHidden(true)
            Text("テンプレートがまだ存在しません")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text("よく持っていくものセットをテンプレートとして作成できます")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Button {
                showTemplateManager = true
            } label: {
                Label("テンプレートを作成する", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(accentColor))
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func templateRow(_ template: PackingTemplate) -> some View {
        Button {
            onSelect(template.items)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accentColor.opacity(0.12))
                    Image(systemName: "checklist")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                        .accessibilityHidden(true)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(template.items.joined(separator: "・"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var createRow: some View {
        Button {
            showTemplateManager = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.secondary.opacity(0.12))
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(width: 40, height: 40)

                Text("テンプレートを作成する")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer(minLength: 8)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 持ち物の編集（既存アイテムのタイトル・日付・通知リマインドを変更する）

// ★ AddPackingItemViewは複数アイテムを一括追加する専用の作りなので、既存1件だけを
//   編集するのには合わない。単一アイテム用に絞った、より軽量な編集フォーム
private struct EditPackingItemView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var navState: AppNavigationState
    @ObservedObject var checklistVM: PackingChecklistViewModel
    let item: PackingChecklistItem
    let accentColor: Color
    let accentColor2: Color

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var calendarMonth: Date
    @State private var showDatePicker = false
    // ★ AddPackingItemViewと同じく、何個でも自由に追加・削除できる配列にする
    @State private var reminderTimes: [Date]
    // ★ AddPackingItemViewと同じく、日付選択カレンダーに出す予定をグループごとに切り替える用
    @State private var calendarGroup: IdolGroup?

    init(checklistVM: PackingChecklistViewModel, item: PackingChecklistItem, accentColor: Color, accentColor2: Color) {
        self.checklistVM = checklistVM
        self.item = item
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        _title = State(initialValue: item.title)
        _date = State(initialValue: item.date)
        _calendarMonth = State(initialValue: item.date)
        _reminderTimes = State(initialValue: item.remindAts)
    }

    private var myUid: String? { Auth.auth().currentUser?.uid }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ★ AddPackingItemViewと同じ「過去の時刻は選ばせない」ガード
    private var canSave: Bool {
        guard !trimmedTitle.isEmpty else { return false }
        if reminderTimes.contains(where: { $0 < Date() }) { return false }
        return true
    }

    private var reminderTimeRange: ClosedRange<Date> {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
            return Date()...endOfDay
        } else {
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? date
            return startOfDay...endOfDay
        }
    }

    private func alignedReminderTime(day: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? time
    }

    // ★ リマインドを追加した瞬間のデフォルト時刻（当日の朝9時。範囲外なら選べる最も近い時刻に丸める）
    private func defaultReminderTime() -> Date {
        let proposed = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let range = reminderTimeRange
        if proposed < range.lowerBound { return range.lowerBound }
        if proposed > range.upperBound { return range.upperBound }
        return proposed
    }

    private var dateDisplayText: String {
        return CachedFormatters.date(format: "yyyy年M月d日（E）").string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "M月d日").string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleCard
                    dateCard
                    reminderCard
                    saveButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("持ち物を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onChange(of: date) { _, newDate in
                reminderTimes = reminderTimes.map { alignedReminderTime(day: newDate, time: $0) }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
        }
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("持ち物")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("例：ペンライト、うちわ", text: $title)
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いつの持ち物？")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Button {
                calendarMonth = date
                showDatePicker = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(accentColor.opacity(0.12))
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(accentColor)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 36, height: 36)

                    Text(dateDisplayText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("通知でリマインドする", systemImage: "bell.fill")
                .font(.system(size: 14, weight: .semibold))

            ForEach(reminderTimes.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        DatePicker(
                            "通知する時刻",
                            selection: Binding(
                                get: { reminderTimes[index] },
                                set: { reminderTimes[index] = alignedReminderTime(day: date, time: $0) }
                            ),
                            in: reminderTimeRange,
                            displayedComponents: [.hourAndMinute]
                        )
                        .labelsHidden()
                        .font(.system(size: 14, weight: .semibold))
                        .datePickerStyle(.compact)

                        Spacer(minLength: 0)

                        Button {
                            reminderTimes.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .accessibilityLabel("このリマインドを削除")
                    }

                    if reminderTimes[index] < Date() {
                        Text("この時刻はすでに過ぎています。現在時刻より後の時刻を選んでください")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }

            Button {
                reminderTimes.append(defaultReminderTime())
            } label: {
                Label("リマインドを追加", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            if !reminderTimes.isEmpty {
                Text("\(dayLabel(date))の指定時刻に「\(trimmedTitle.isEmpty ? "持ち物" : trimmedTitle)」を忘れずにとお知らせします")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func communityCalendarId(for groupId: String) -> String? {
        calendarViewModel.calendars.first(where: { $0.isCommunity && $0.groupId == groupId })?.id
    }

    // ★ 日付選択カレンダーに予定の印(✦)を出す日付。選択中グループの、実際にカレンダータブに
    //   表示される予定(未承認のコミュニティ予定は除く)がある日だけに絞る
    //   ★ 2026/08/21修正：groupIdだけの絞り込みだと未承認のコミュニティ予定まで混ざっていた
    private var calendarGroupEventDates: Set<Date> {
        guard let groupId = calendarGroup?.id else { return [] }
        let communityId = communityCalendarId(for: groupId)
        var dates: Set<Date> = []
        for (day, events) in eventViewModel.myEventsByDate {
            if !Event.visibleEventsForGroup(from: events, groupId: groupId, communityCalendarId: communityId, myUid: myUid).isEmpty {
                dates.insert(day)
            }
        }
        return dates
    }

    private var calendarGroupEventsOnSelectedDate: [Event] {
        guard let groupId = calendarGroup?.id else { return [] }
        let events = eventViewModel.myEventsByDate[Calendar.current.startOfDay(for: date)] ?? []
        return Event.visibleEventsForGroup(
            from: events, groupId: groupId,
            communityCalendarId: communityCalendarId(for: groupId), myUid: myUid
        )
    }

    // ★ このシートは「シートの上にさらに重ねるシート」として表示されるため、ここに
    //   もう一段NavigationStack+navigationTitleを重ねると、iOSのシート遷移中に
    //   2つのナビゲーションバーのタイトル文字が同じ位置に描画されて重なって見える
    //   既知の不具合があった。navigationTitleを使わず、自前のヘッダー行に置き換えて回避する
    //   ★ 2026/08/21修正：AddPackingItemViewと同じくグループチップを追加し、
    //   .presentationDetents([.medium])のままだと画面に入り切らなくなるため.largeも選べるようにする
    private var datePickerSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("日付を選択")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("完了") { showDatePicker = false }
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ★ AddPackingItemViewと同じく、グループチップ追加で縦幅が伸びたため
            //   ScrollViewで包んで中身が絶対に見切れないようにする
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        if !groupViewModel.groups.isEmpty {
                            datePickerGroupChips
                        }

                        ExpenseMiniCalendar(
                            displayedMonth: $calendarMonth,
                            selectedDate: Binding(
                                get: { date },
                                set: { newValue in
                                    if let newValue { date = newValue }
                                }
                            ),
                            eventDates: calendarGroupEventDates,
                            accentColor: accentColor
                        )

                        if !calendarGroupEventsOnSelectedDate.isEmpty {
                            CalendarEventDetailRow(events: calendarGroupEventsOnSelectedDate)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    Button {
                        date = item.date
                        calendarMonth = item.date
                    } label: {
                        Text("その日にする")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            if calendarGroup == nil { calendarGroup = groupViewModel.groups.first }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var datePickerGroupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groupViewModel.groups) { g in
                    let isSelected = calendarGroup?.id == g.id
                    Button {
                        calendarGroup = g
                    } label: {
                        Text(g.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule().fill(
                                            LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                                        )
                                    } else {
                                        Capsule().fill(Color(.systemGray6))
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            checklistVM.updateItem(item, title: trimmedTitle, date: date, remindAts: reminderTimes) { error in
                if error != nil { navState.showToast("更新できませんでした") }
            }
            dismiss()
        } label: {
            Text("保存する")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .opacity(canSave ? 1 : 0.5)
        }
        .disabled(!canSave)
        .padding(.top, 4)
    }
}
