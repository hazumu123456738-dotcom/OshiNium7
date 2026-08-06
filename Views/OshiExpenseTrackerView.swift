//
//  OshiExpenseTrackerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import NukeUI

// ★ 「推し活の金額を計算」機能。チケット・グッズ・交通費・宿泊費などを記録して、
//   累計とグループ別・カテゴリ別の内訳を見られるようにする。本人以外には見せない記録なので
//   uidで絞り込んだ自分のデータだけを扱う。
//   ★ カレンダーで「何月何日に使ったか」を主役に据えたダッシュボードとして、
//     これ単体でも1本の家計簿アプリとして成立する完成度を目指して作り直した
struct OshiExpenseTrackerView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @StateObject private var expenseVM = OshiExpenseViewModel()
    @State private var showAddSheet = false
    // ★ この画面も自作の下タブバーの裏に隠れる領域があるため、環境値で受け取った
    //   タブバーの高さぶんを浮かせたボタンのpaddingに明示的に足す
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    // ★ カレンダーで見ている月・選択中の日（日を選ぶと記録一覧をその日だけに絞り込む）
    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?

    // ★ カレンダーに予定を出す対象グループ（金額の集計はグループを問わず全体で行うので、
    //   ここでの選択はカレンダーの予定表示だけに影響する）
    @State private var selectedCalendarGroup: IdolGroup?
    @State private var showGroupBreakdown = false

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2
    private var myUid: String? { Auth.auth().currentUser?.uid }

    // ★ 選択中の月（＋日が選ばれていればその日だけ）に絞った記録
    private var visibleExpenses: [OshiExpense] {
        let monthExpenses = expenseVM.expenses(inMonth: displayedMonth)
        guard let selectedDay else { return monthExpenses.sorted { $0.date > $1.date } }
        return monthExpenses
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
    }

    private var listTitle: String {
        if let selectedDay {
            return "\(dayLabel(selectedDay))の記録"
        }
        return "\(monthLabel(displayedMonth))の記録"
    }

    // ★ 選択中の日に、選択中グループの予定があれば、その一覧を返す
    private var selectedDayEvents: [Event] {
        guard let selectedDay, let groupId = selectedCalendarGroup?.id else { return [] }
        let events = eventViewModel.myEventsByDate[Calendar.current.startOfDay(for: selectedDay)] ?? []
        return events.filter { $0.groupId == groupId }
    }

    // ★ ミニカレンダーに印を付ける日付。選択中グループの予定がある日だけに絞る
    private var selectedGroupEventDates: Set<Date> {
        guard let groupId = selectedCalendarGroup?.id else { return [] }
        var dates: Set<Date> = []
        for (day, events) in eventViewModel.myEventsByDate {
            if events.contains(where: { $0.groupId == groupId }) {
                dates.insert(day)
            }
        }
        return dates
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    totalCard

                    calendarCard

                    if !expenseVM.totalsByCategory.isEmpty {
                        breakdownCard(title: "カテゴリ別", items: expenseVM.totalsByCategory.map { ($0.category, $0.amount) })
                    }

                    expenseList
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            .background(Color.appBackground.ignoresSafeArea())

            addButton
        }
        .navigationTitle("推し活の金額")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let myUid { expenseVM.startListening(uid: myUid) }
            if selectedCalendarGroup == nil { selectedCalendarGroup = groupViewModel.groups.first }
        }
        .onChange(of: groupViewModel.groups) { _, newGroups in
            if selectedCalendarGroup == nil { selectedCalendarGroup = newGroups.first }
        }
        .onDisappear { expenseVM.stopListening() }
        .sheet(isPresented: $showAddSheet) {
            AddOshiExpenseView(expenseVM: expenseVM, accentColor: accentColor, accentColor2: accentColor2)
        }
        .sheet(isPresented: $showGroupBreakdown) {
            groupBreakdownSheet
        }
    }

    // MARK: - 追加ボタン（画面右下に浮かせて、単体アプリのような主張のある導線にする）

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
        .accessibilityLabel("記録を追加")
        .padding(.trailing, 20)
        .padding(.bottom, 20 + customTabBarHeight)
    }

    // MARK: - 累計カード

    private var totalCard: some View {
        Button {
            showGroupBreakdown = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("累計金額（全グループ合算）")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    Text(yenText(expenseVM.totalAmount))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(expenseVM.expenses.count)件の記録・タップでグループ別の内訳")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }

                Divider().background(Color.white.opacity(0.3))

                HStack {
                    Text("今月の使用額")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(yenText(expenseVM.total(inMonth: Date())))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: accentColor.opacity(0.3), radius: 14, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 累計金額カードをタップした時の、グループ別内訳シート

    private var groupBreakdownSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("全体の累計金額")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(yenText(expenseVM.totalAmount))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    if !expenseVM.totalsByGroup.isEmpty {
                        breakdownCard(title: "推しグループ別", items: expenseVM.totalsByGroup.map { ($0.name, $0.amount) })
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("グループ別の内訳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { showGroupBreakdown = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - カレンダーカード（月送り・日タップで記録一覧を絞り込める）

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("いつ使ったか", systemImage: "calendar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(yenText(expenseVM.total(inMonth: displayedMonth)))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
            }

            if !groupViewModel.groups.isEmpty {
                calendarGroupChips
            }

            ExpenseMiniCalendar(
                displayedMonth: $displayedMonth,
                selectedDate: $selectedDay,
                markedDates: expenseVM.markedDates,
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
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ カレンダーに予定を出すグループの切り替えチップ（金額の集計には影響しない）
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

    // MARK: - 内訳カード（グループ別・カテゴリ別で共通利用）

    private func breakdownCard(title: String, items: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                ForEach(items, id: \.0) { name, amount in
                    VStack(spacing: 6) {
                        HStack {
                            Text(name)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer(minLength: 8)
                            Text(yenText(amount))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                        // ★ itemsは合計額の降順なので、先頭（最大値）を基準に横棒の長さを決める
                        breakdownBar(amount: amount, max: items.first?.1 ?? amount)
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

    private func breakdownBar(amount: Int, max: Int) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accentColor.opacity(0.15))
                .frame(width: geo.size.width, height: 6)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accentColor)
                        .frame(width: max > 0 ? geo.size.width * CGFloat(amount) / CGFloat(max) : 0, height: 6)
                }
        }
        .frame(height: 6)
    }

    // MARK: - 記録一覧（選択中の月・日に応じて絞り込む）

    private var expenseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(listTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            if visibleExpenses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "yensign.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text(selectedDay != nil ? "この日の記録はありません" : "この月の記録はありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleExpenses) { expense in
                        expenseRow(expense)
                    }
                }
            }
        }
    }

    private func expenseRow(_ expense: OshiExpense) -> some View {
        HStack(spacing: 12) {
            expenseThumbnail(expense)

            VStack(alignment: .leading, spacing: 3) {
                // ★ 「〇〇に◯円かかった」形式。交通費のように写真にしづらいものも
                //   画像なしでこの一文だけで内容が伝わるようにする
                Text("『\(expense.spentOnLabel)に\(yenText(expense.amount))かかった』")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(expense.groupName ?? expense.category)
                    Text("・")
                    Text(dayLabel(expense.date))
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .swipeActions {
            Button("削除", role: .destructive) {
                expenseVM.deleteExpense(expense)
            }
        }
    }

    @ViewBuilder
    private func expenseThumbnail(_ expense: OshiExpense) -> some View {
        if let urlString = expense.imageURL, let url = URL(string: urlString) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(.systemGray6)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                Circle().fill(accentColor.opacity(0.12))
                Image(systemName: OshiExpenseCategory(rawValue: expense.category)?.icon ?? "yensign.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
                    .accessibilityHidden(true)
            }
            .frame(width: 44, height: 44)
        }
    }

    private func yenText(_ amount: Int) -> String {
        "¥\(amount.formatted())"
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
}

// MARK: - 記録の追加フォーム
//   ★ 標準のFormではなく、このアプリの他の投稿・作成画面（PostComposerView等）と
//     同じ「白いカードを積んだカスタムレイアウト」に統一し、単体でも見劣りしない
//     仕上がりにする。日付は素のDatePickerではなく、ダッシュボードと同じ
//     ExpenseMiniCalendarをその場で開いて選ぶ、カレンダー中心の操作感にする

private struct AddOshiExpenseView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @ObservedObject var expenseVM: OshiExpenseViewModel
    let accentColor: Color
    let accentColor2: Color

    @Environment(\.dismiss) private var dismiss
    @State private var category: OshiExpenseCategory = .ticket
    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var calendarMonth = Date()
    @State private var selectedGroupId: String?
    @State private var showDatePicker = false

    // ★ 画像は任意。交通費のように形にできないものはレシートが無くても記録できるようにする
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isSaving = false

    private var canSave: Bool {
        guard let amount = Int(amountText) else { return false }
        return amount > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    amountCard
                    categoryCard
                    imageCard
                    dateCard
                    if !groupViewModel.groups.isEmpty {
                        groupCard
                    }
                    noteCard
                    saveButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .onChange(of: pickerItem) { _, newItem in
                loadPickedImage(newItem)
            }
        }
    }

    // MARK: - 画像（任意）

    private var imageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("写真（任意）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(selectedImage == nil ? "追加" : "変更", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }

            if isLoadingImage {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        self.selectedImage = nil
                        pickerItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.black.opacity(0.55), in: Circle())
                    }
                    .padding(8)
                    .accessibilityLabel("写真を削除")
                }
            } else {
                Text("交通費など、形にできないものは無しでもOKです")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingImage = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = uiImage
                    isLoadingImage = false
                }
            } else {
                await MainActor.run { isLoadingImage = false }
            }
        }
    }

    // MARK: - 金額

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("金額")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                Text("¥")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(accentColor)
                TextField("0", text: $amountText)
                    .font(.system(size: 30, weight: .bold))
                    .keyboardType(.numberPad)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - カテゴリ（アイコンチップ）

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("カテゴリ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(OshiExpenseCategory.allCases) { c in
                    categoryChip(c)
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

    private func categoryChip(_ c: OshiExpenseCategory) -> some View {
        let isSelected = category == c

        return Button {
            category = c
        } label: {
            VStack(spacing: 6) {
                Image(systemName: c.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityHidden(true)
                Text(c.rawValue)
                    .font(.system(size: 11, weight: .semibold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .foregroundColor(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color(.systemGray6))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日付（カレンダーで選ぶ）

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いつ使った？")
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

    // MARK: - メモ

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("メモ（任意）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("補足があれば", text: $note, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(1...4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 保存ボタン

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 6) {
                if isSaving {
                    ProgressView().tint(.white)
                }
                Text(isSaving ? "保存しています…" : "保存する")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .opacity(canSave && !isSaving ? 1 : 0.5)
        }
        .disabled(!canSave || isSaving)
        .padding(.top, 4)
    }

    private func save() {
        guard let uid = Auth.auth().currentUser?.uid, let amount = Int(amountText) else { return }
        let groupName = groupViewModel.groups.first(where: { $0.id == selectedGroupId })?.name
        isSaving = true

        Task {
            var imageURL: String?
            if let selectedImage {
                imageURL = try? await ImageStorageService.shared.uploadExpenseImage(selectedImage, uid: uid)
            }
            await MainActor.run {
                expenseVM.addExpense(
                    uid: uid,
                    groupId: selectedGroupId,
                    groupName: groupName,
                    category: category.rawValue,
                    amount: amount,
                    note: note.isEmpty ? nil : note,
                    imageURL: imageURL,
                    date: date
                )
                isSaving = false
                dismiss()
            }
        }
    }
}
