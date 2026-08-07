//
//  PackingTemplateManagerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI
import FirebaseAuth

// ★ 持ち物チェックリストの「マイテンプレート」管理画面。日付に紐付けない
//   「よく持っていくものセット」を保存しておき、①選択中の日にまとめて追加する、
//   ②そのまま投稿として共有する、の2つの使い方ができる
struct PackingTemplateManagerView: View {

    // ★ 「この日に追加」シートを開いたときの初期選択日（詳細シート側で自由に変更できる）
    let targetDate: Date
    // ★ 追加が終わったら呼ばれる（PackingChecklistView側でchecklistVM.addItemを実行してもらう）。
    //   ユーザーが詳細シート内で選び直した日付・通知リマインド時刻をそのまま渡す
    let onAddToDay: ([String], Date, Date?) -> Void

    @EnvironmentObject var eventViewModel: EventViewModel

    @StateObject private var templateVM = PackingTemplateViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSheet = false
    @State private var selectedTemplate: PackingTemplate?

    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)
    private let accentColor2 = Color(red: 0.55, green: 0.82, blue: 0.60)
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
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("マイテンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("テンプレートを作る")
                }
            }
            .onAppear {
                if let myUid { templateVM.startListening(uid: myUid) }
            }
            .onDisappear { templateVM.stopListening() }
            .sheet(isPresented: $showCreateSheet) {
                CreatePackingTemplateView(templateVM: templateVM, accentColor: accentColor, accentColor2: accentColor2)
            }
            .sheet(item: $selectedTemplate) { template in
                PackingTemplateDetailSheet(
                    template: template,
                    initialDate: targetDate,
                    accentColor: accentColor,
                    accentColor2: accentColor2,
                    onAddToDay: { chosenDate, chosenRemindAt in
                        onAddToDay(template.items, chosenDate, chosenRemindAt)
                        selectedTemplate = nil
                        dismiss()
                    }
                )
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
            Text("まだテンプレートがありません")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("よく持っていくものセットを保存しておくと、次の予定にまとめて追加したり、投稿として共有できます")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func templateRow(_ template: PackingTemplate) -> some View {
        Button {
            selectedTemplate = template
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
                    .foregroundColor(.secondary.opacity(0.5))
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
        .swipeActions {
            Button("削除", role: .destructive) {
                templateVM.deleteTemplate(template)
            }
        }
    }
}

// MARK: - テンプレート詳細（この日に追加する／投稿する）

private struct PackingTemplateDetailSheet: View {
    let template: PackingTemplate
    let initialDate: Date
    let accentColor: Color
    let accentColor2: Color
    // ★ ユーザーがこのシート内で選び直した日付・通知リマインド時刻を、追加確定時にそのまま呼び出し元へ渡す。
    //   以前はテンプレートから追加した持ち物には通知を仕込む手段が無く、AddPackingItemViewの
    //   単発追加でしか通知が来なかった。同じ仕組みをここにも持たせる
    let onAddToDay: (Date, Date?) -> Void

    @EnvironmentObject var eventViewModel: EventViewModel
    @Environment(\.dismiss) private var dismiss

    // ★ 以前は呼び出し元（PackingChecklistViewでカレンダー選択中の日）に固定されていて
    //   日付を変えられなかった。ここに専用のカレンダーを持たせ、自由な日付を選べるようにする
    @State private var date: Date
    @State private var calendarMonth: Date
    @State private var showDatePicker = false
    @State private var reminderEnabled = false
    @State private var reminderTime: Date

    init(template: PackingTemplate, initialDate: Date, accentColor: Color, accentColor2: Color, onAddToDay: @escaping (Date, Date?) -> Void) {
        self.template = template
        self.initialDate = initialDate
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        self.onAddToDay = onAddToDay
        _date = State(initialValue: initialDate)
        _calendarMonth = State(initialValue: initialDate)
        _reminderTime = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(template.items, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(accentColor.opacity(0.6))
                                    .accessibilityHidden(true)
                                Text(item)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    dateCard
                    reminderCard

                    Button {
                        onAddToDay(date, resolvedRemindAt)
                    } label: {
                        Text("\(dayLabel(date))に追加する")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }

                    NavigationLink {
                        PackingTemplatePostView(template: template)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityHidden(true)
                            Text("投稿する")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().stroke(accentColor, lineWidth: 1.3))
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - 日付（カレンダーで選ぶ。AddPackingItemViewのdateCardと同じ構成）

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

                    Text(dayLabel(date))
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

    // MARK: - 通知リマインド（AddPackingItemView.reminderCardと同じ構成）

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

                Text("\(dayLabel(date))の指定時刻に「\(template.items.joined(separator: "・"))」を忘れずにとお知らせします")
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

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f.string(from: date)
    }
}

// MARK: - テンプレート作成フォーム

private struct CreatePackingTemplateView: View {
    @ObservedObject var templateVM: PackingTemplateViewModel
    let accentColor: Color
    let accentColor2: Color

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var itemTexts: [String] = [""]

    private var trimmedItems: [String] {
        itemTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !trimmedItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameCard
                    itemsCard
                    saveButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("テンプレートを作る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テンプレート名")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("例：遠征セット", text: $name)
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("持ち物")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(itemTexts.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("例：ペンライト", text: $itemTexts[index])
                            .font(.system(size: 14))

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

    private var saveButton: some View {
        Button {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            templateVM.addTemplate(uid: uid, name: name.trimmingCharacters(in: .whitespacesAndNewlines), items: trimmedItems)
            dismiss()
        } label: {
            Text("保存する")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .opacity(canSave ? 1 : 0.5)
        }
        .disabled(!canSave)
    }
}
