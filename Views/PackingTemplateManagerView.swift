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
    let onAddToDay: ([String], Date, [Date]) -> Void

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var navState: AppNavigationState

    @StateObject private var templateVM = PackingTemplateViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSheet = false
    @State private var selectedTemplate: PackingTemplate?
    @State private var editingTemplate: PackingTemplate?
    @State private var postingTemplate: PackingTemplate?
    @State private var showPostTemplate = false

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
            .navigationDestination(isPresented: $showPostTemplate) {
                if let postingTemplate {
                    PackingTemplatePostView(template: postingTemplate)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreatePackingTemplateView(templateVM: templateVM, accentColor: accentColor, accentColor2: accentColor2)
            }
            .sheet(item: $editingTemplate) { template in
                CreatePackingTemplateView(
                    templateVM: templateVM,
                    accentColor: accentColor,
                    accentColor2: accentColor2,
                    existingTemplate: template
                )
            }
            .sheet(item: $selectedTemplate) { template in
                PackingTemplateDetailSheet(
                    template: template,
                    initialDate: targetDate,
                    accentColor: accentColor,
                    accentColor2: accentColor2,
                    onAddToDay: { chosenDate, chosenRemindAts in
                        onAddToDay(template.items, chosenDate, chosenRemindAts)
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
        HStack(spacing: 12) {
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
                }
            }
            .buttonStyle(.plain)

            // ★ 以前はList専用の.swipeActionsを付けていたが、この画面はScrollView+VStackで
            //   Listではないため実際には一切反応していなかった（削除できない不具合）。
            //   確実に動く「…」メニューに置き換え、ついでに編集の入り口もここに追加する
            Menu {
                Button {
                    editingTemplate = template
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                Button {
                    postingTemplate = template
                    showPostTemplate = true
                } label: {
                    Label("投稿", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    templateVM.deleteTemplate(template) { error in
                        if error != nil { navState.showToast("削除できませんでした") }
                    }
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("テンプレートの操作")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
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
    let onAddToDay: (Date, [Date]) -> Void

    @EnvironmentObject var eventViewModel: EventViewModel
    @Environment(\.dismiss) private var dismiss

    // ★ 以前は呼び出し元（PackingChecklistViewでカレンダー選択中の日）に固定されていて
    //   日付を変えられなかった。ここに専用のカレンダーを持たせ、自由な日付を選べるようにする
    @State private var date: Date
    @State private var calendarMonth: Date
    @State private var showDatePicker = false
    // ★ AddPackingItemView/EditPackingItemViewと同じく、何個でも自由に追加・削除できる配列にする
    @State private var reminderTimes: [Date] = []

    init(template: PackingTemplate, initialDate: Date, accentColor: Color, accentColor2: Color, onAddToDay: @escaping (Date, [Date]) -> Void) {
        self.template = template
        self.initialDate = initialDate
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        self.onAddToDay = onAddToDay
        _date = State(initialValue: initialDate)
        _calendarMonth = State(initialValue: initialDate)
    }

    // ★ AddPackingItemViewと同じ「今日を選んでいる場合は現在時刻以降しか選べない」制限
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

    private func defaultReminderTime() -> Date {
        let proposed = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let range = reminderTimeRange
        if proposed < range.lowerBound { return range.lowerBound }
        if proposed > range.upperBound { return range.upperBound }
        return proposed
    }

    private var canAdd: Bool {
        !reminderTimes.contains { $0 < Date() }
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
                        onAddToDay(date, reminderTimes)
                    } label: {
                        Text("\(dayLabel(date))に追加する")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                            .opacity(canAdd ? 1 : 0.5)
                    }
                    .disabled(!canAdd)

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
            .onChange(of: date) { _, newDate in
                reminderTimes = reminderTimes.map { alignedReminderTime(day: newDate, time: $0) }
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

    // ★ このシートは「シートの上にさらに重ねるシート」として表示されるため、ここに
    //   もう一段NavigationStack+navigationTitleを重ねると、iOSのシート遷移中に
    //   2つのナビゲーションバーのタイトル文字が同じ位置に描画されて重なって見える
    //   既知の不具合があった。navigationTitleを使わず、自前のヘッダー行に置き換えて回避する
    private var datePickerSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Text("日付を選択")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("完了") { showDatePicker = false }
                    .font(.system(size: 15, weight: .semibold))
            }

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
                date = initialDate
                calendarMonth = initialDate
            } label: {
                Text("その日にする")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func dayLabel(_ date: Date) -> String {
        return CachedFormatters.date(format: "M月d日(E)").string(from: date)
    }
}

// MARK: - テンプレート作成フォーム

private struct CreatePackingTemplateView: View {
    @ObservedObject var templateVM: PackingTemplateViewModel
    @EnvironmentObject var navState: AppNavigationState
    let accentColor: Color
    let accentColor2: Color
    // ★ nilなら新規作成、値があれば編集モード（アイテムの追加・削除も含め、
    //   このフォームをそのまま再利用する）
    var existingTemplate: PackingTemplate? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var itemTexts: [String]
    @State private var showLimitReachedAlert = false
    @State private var showPremiumUpgrade = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    init(templateVM: PackingTemplateViewModel, accentColor: Color, accentColor2: Color, existingTemplate: PackingTemplate? = nil) {
        self.templateVM = templateVM
        self.accentColor = accentColor
        self.accentColor2 = accentColor2
        self.existingTemplate = existingTemplate
        _name = State(initialValue: existingTemplate?.name ?? "")
        _itemTexts = State(initialValue: existingTemplate?.items ?? [""])
    }

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
            .navigationTitle(existingTemplate == nil ? "テンプレートを作る" : "テンプレートを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("テンプレートの上限に達しました", isPresented: $showLimitReachedAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("アップグレード") { showPremiumUpgrade = true }
            } message: {
                Text("持ち物テンプレートは\(subscriptionManager.packingTemplateLimit)件まで保存できます。もっと保存するにはプレミアムにアップグレードしてください。")
            }
            .sheet(isPresented: $showPremiumUpgrade) {
                PremiumUpgradeView()
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
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existingTemplate {
                // ★ 既存テンプレートの編集は新規保存ではないため、上限チェックの対象外
                templateVM.updateTemplate(existingTemplate, name: trimmedName, items: trimmedItems) { error in
                    if error != nil {
                        navState.showToast("保存できませんでした")
                    } else {
                        dismiss()
                    }
                }
            } else {
                guard let uid = Auth.auth().currentUser?.uid else { return }
                // ★ ローカルキャッシュ(templates.count)の事前チェックはリスナーの反映遅れで
                //   すり抜けられる可能性があるため廃止。addTemplate自体が保存直前にFirestoreへ
                //   件数を問い合わせるサーバー基準のチェックを行い、上限超過ならエラーを返す
                templateVM.addTemplate(uid: uid, name: trimmedName, items: trimmedItems) { error in
                    if error != nil {
                        showLimitReachedAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
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
