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
    @StateObject private var checklistVM = PackingChecklistViewModel()
    @State private var showAddSheet = false
    @State private var showTemplateManager = false

    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)
    private let accentColor2 = Color(red: 0.55, green: 0.82, blue: 0.60)
    private var myUid: String? { Auth.auth().currentUser?.uid }

    private var visibleItems: [PackingChecklistItem] {
        let monthItems = checklistVM.items(inMonth: displayedMonth)
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

    // ★ 選択中の日にメインのカレンダータブの予定（登録している全グループぶん）があれば、その一覧を返す
    private var selectedDayEvents: [Event] {
        guard let selectedDay else { return [] }
        return eventViewModel.myEventsByDate[Calendar.current.startOfDay(for: selectedDay)] ?? []
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    calendarCard
                    itemList
                }
                .padding(16)
                .padding(.bottom, 90)
            }
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
        }
        .onDisappear { checklistVM.stopListening() }
        .sheet(isPresented: $showAddSheet) {
            AddPackingItemView(checklistVM: checklistVM, defaultDate: selectedDay ?? Date(), accentColor: accentColor, accentColor2: accentColor2)
        }
        .sheet(isPresented: $showTemplateManager) {
            PackingTemplateManagerView(targetDate: selectedDay ?? Date()) { items in
                guard let myUid else { return }
                for item in items {
                    checklistVM.addItem(uid: myUid, groupId: nil, groupName: nil, title: item, date: selectedDay ?? Date(), remindAt: nil)
                }
            }
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

            ExpenseMiniCalendar(
                displayedMonth: $displayedMonth,
                selectedDate: $selectedDay,
                markedDates: checklistVM.markedDates,
                eventDates: Set(eventViewModel.myEventsByDate.keys),
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
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 一覧（選択中の月・日に応じて絞り込む）

    private var itemList: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if visibleItems.isEmpty {
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
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleItems) { item in
                        itemRow(item)
                    }
                }
            }
        }
    }

    private func itemRow(_ item: PackingChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button {
                checklistVM.toggleChecked(item)
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
                    if let remindAt = item.remindAt {
                        Label(reminderTimeLabel(remindAt), systemImage: "bell.fill")
                            .foregroundColor(accentColor)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .swipeActions {
            Button("削除", role: .destructive) {
                checklistVM.deleteItem(item)
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f.string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月"
        return f.string(from: date)
    }

    private func reminderTimeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - 持ち物追加フォーム（推し活の金額の追加フォームと同じ「白カードを積んだ」構成）

private struct AddPackingItemView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
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
    @State private var reminderEnabled = false
    @State private var reminderTime: Date

    init(checklistVM: PackingChecklistViewModel, defaultDate: Date, accentColor: Color, accentColor2: Color) {
        self.checklistVM = checklistVM
        self.defaultDate = defaultDate
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        _date = State(initialValue: defaultDate)
        _calendarMonth = State(initialValue: defaultDate)
        // ★ 通知のデフォルトは当日の朝9時。持ち物確認を出発前に済ませてもらう想定
        _reminderTime = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate) ?? defaultDate)
    }

    private var trimmedItems: [String] {
        itemTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !trimmedItems.isEmpty
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
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 通知リマインド（当日の指定した時刻に「持ち物を確認して」と知らせる）

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $reminderEnabled.animation(.easeInOut(duration: 0.15))) {
                Label("通知でリマインドする", systemImage: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .tint(accentColor)

            if reminderEnabled {
                DatePicker(
                    "通知する時刻",
                    selection: $reminderTime,
                    displayedComponents: [.hourAndMinute]
                )
                .font(.system(size: 14, weight: .semibold))
                .datePickerStyle(.compact)

                Text("\(dayLabel(date))の指定時刻に「\(trimmedItems.isEmpty ? "持ち物" : trimmedItems.joined(separator: "・"))」を忘れずにとお知らせします")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    // ★ 「持ち物の日付（年月日）」＋「リマインド時刻（時分）」を合成した実際の通知日時
    private var resolvedRemindAt: Date? {
        guard reminderEnabled else { return nil }
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminderTime)
        var merged = DateComponents()
        merged.year = dayComponents.year
        merged.month = dayComponents.month
        merged.day = dayComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged)
    }

    private var dateDisplayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日（E）"
        return f.string(from: date)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 14) {
                    ExpenseMiniCalendar(
                        displayedMonth: $calendarMonth,
                        selectedDate: Binding(
                            get: { date },
                            set: { newValue in
                                if let newValue { date = newValue }
                            }
                        ),
                        eventDates: Set(eventViewModel.myEventsByDate.keys),
                        accentColor: accentColor
                    )

                    let eventsOnDate = eventViewModel.myEventsByDate[Calendar.current.startOfDay(for: date)] ?? []
                    if !eventsOnDate.isEmpty {
                        CalendarEventDetailRow(events: eventsOnDate)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )

                Button {
                    date = Date()
                    calendarMonth = Date()
                } label: {
                    Text("今日にする")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { showDatePicker = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
            for item in trimmedItems {
                checklistVM.addItem(uid: uid, groupId: selectedGroupId, groupName: groupName, title: item, date: date, remindAt: resolvedRemindAt)
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
