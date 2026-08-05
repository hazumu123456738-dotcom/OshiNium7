//
//  ExpenseMiniCalendar.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI

// ★ 「推し活の金額」機能専用の、月送りできるミニカレンダー。
//   記録がある日には小さなドットを表示し、日付をタップして選択できる。
//   ダッシュボードでの「その日の記録だけ見る」フィルタと、記録追加時の
//   「いつ使ったか」の日付選択の両方で共通利用する（見た目・操作感を統一するため）
struct ExpenseMiniCalendar: View {

    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?

    // ★ 記録がある日（startOfDayに正規化済み）の集合。ドット表示にのみ使う
    var markedDates: Set<Date> = []
    // ★ メインのカレンダータブに予定が入っている日（startOfDayに正規化済み）の集合。
    //   記録の有無を示すドットとは別に、日付の右上にスパークルで別枠として示す
    var eventDates: Set<Date> = []
    var accentColor: Color

    // ★ 未来の日付は選べないようにする場合はtrueにする（記録追加時のみ使用）
    var disablesFutureDates: Bool = false

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(spacing: 14) {
            monthHeader
            weekdayHeader
            dayGrid
        }
    }

    // MARK: - 月送りヘッダー

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accentColor.opacity(0.1)))
            }

            Spacer()

            Text(monthTitle)
                .font(.system(size: 15, weight: .bold))

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accentColor.opacity(0.1)))
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(weekdayColor(index))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 日付グリッド

    private var dayGrid: some View {
        let days = daysInGrid()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isInMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        let isMarked = markedDates.contains(calendar.startOfDay(for: day))
        let hasEvent = eventDates.contains(calendar.startOfDay(for: day))
        let isDisabled = disablesFutureDates && day > calendar.startOfDay(for: Date()).addingTimeInterval(86399)

        return Button {
            guard isInMonth, !isDisabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedDate = nil
                } else {
                    selectedDate = day
                }
            }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                        .foregroundColor(textColor(isInMonth: isInMonth, isSelected: isSelected, isToday: isToday, isDisabled: isDisabled))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(isSelected ? AnyShapeStyle(accentColor) : AnyShapeStyle(isToday ? accentColor.opacity(0.12) : Color.clear))
                        )

                    if hasEvent && isInMonth {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(isSelected ? .white : .orange)
                            .offset(x: 2, y: -2)
                    }
                }

                Circle()
                    .fill(isMarked && !isSelected ? accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .disabled(!isInMonth || isDisabled)
        .frame(maxWidth: .infinity)
    }

    private func textColor(isInMonth: Bool, isSelected: Bool, isToday: Bool, isDisabled: Bool) -> Color {
        if isSelected { return .white }
        if !isInMonth || isDisabled { return .gray.opacity(0.3) }
        if isToday { return accentColor }
        return .primary
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return .red.opacity(0.7) }
        if index == 6 { return .blue.opacity(0.7) }
        return .secondary
    }

    // MARK: - 日付計算

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = newMonth
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: displayedMonth)
    }

    // ★ 前後月の日付で7の倍数まで埋めた、表示用の日付配列（月により5〜6行）
    private func daysInGrid() -> [Date] {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return [] }

        var days: [Date] = []
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingCount = firstWeekday - 1

        if leadingCount > 0, let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth) {
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevFirst = calendar.date(from: calendar.dateComponents([.year, .month], from: prevMonth))!
            let prevLast = prevRange.count
            for i in stride(from: leadingCount - 1, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: prevLast - i - 1, to: prevFirst) {
                    days.append(d)
                }
            }
        }

        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(d)
            }
        }

        let remainder = days.count % 7
        if remainder != 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) {
            let trailingCount = 7 - remainder
            for i in 0..<trailingCount {
                if let d = calendar.date(byAdding: .day, value: i, to: nextMonth) {
                    days.append(d)
                }
            }
        }

        return days
    }
}
