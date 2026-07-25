//
//  MonthlyCalendarView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/25.
//

import SwiftUI

struct MonthlyCalendarView: View {

    let month: Date
    let eventsByDate: [Date: [Event]]

    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    // ★ FullCalendarTab から渡される「イベント選択時の処理」
    let onSelectEvent: (Event) -> Void

    @State private var selectedDateForSheet: Date? = nil
    @State private var showDayEvents = false

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {

        GeometryReader { geo in
            VStack(spacing: 0) {

                Spacer(minLength: 0)

                weekdayHeader()

                calendarGrid(height: geo.size.height)
            }
            .sheet(isPresented: $showDayEvents) {

                // ★ Optional を unwrap して渡す
                if let date = selectedDateForSheet,
                   let group = selectedGroup {

                    DayEventListView(
                        date: date,
                        selectedGroup: group
                    ) { event in
                        // ★ イベント選択時の処理は「親に任せる」
                        showDayEvents = false
                        onSelectEvent(event)
                    }
                    .environmentObject(eventViewModel)
                    .environmentObject(settingsVM)

                } else {
                    Text("グループが選択されていません")
                }
            }
        }
    }

    // MARK: - 曜日ヘッダー
    private func weekdayHeader() -> some View {
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

        return HStack(spacing: 0) {
            ForEach(0..<7) { index in

                let color: Color = {
                    if index == 0 { return Color.red.opacity(0.75) }
                    if index == 6 { return Color.blue.opacity(0.75) }
                    return Color.black.opacity(0.55)
                }()

                Text(weekdays[index])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    // MARK: - カレンダー本体（5×7固定）
    private func calendarGrid(height: CGFloat) -> some View {

        let days = generateFiveRowDays(for: month)
        let cellHeight: CGFloat = 115

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 0
        ) {
            ForEach(days, id: \.self) { date in
                dateCell(date, cellHeight: cellHeight)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.06), lineWidth: 0.5)
                    )
            }
        }
        .frame(height: cellHeight * 5)
        .padding(.horizontal, 4)
    }

    // MARK: - 指定日のイベント（選択中グループでフィルタ）
    private func filteredEvents(for date: Date) -> [Event] {
        let key = calendar.startOfDay(for: date)
        guard let events = eventsByDate[key] else { return [] }

        guard let group = selectedGroup else { return events }

        return events.filter { event in
            event.groupId == group.id
        }
    }

    // MARK: - 色ルール
    private func color(for type: EventType) -> Color {
        switch type {
        case .live, .event: return .red
        case .tv: return .green
        case .release: return .blue
        case .sns: return .orange
        case .anniversary: return .purple
        case .other: return .gray
        }
    }

    // MARK: - 半角/全角考慮したタイトル制限（半角=0.6文字）
    private func truncatedTitle(_ title: String, limit: Double = 6.0) -> String {
        var count: Double = 0
        var result = ""

        for char in title {
            if char.isASCII {
                count += 0.6
            } else {
                count += 1.0
            }

            if count > limit { break }
            result.append(char)
        }

        return result
    }

    // MARK: - 半角英字は tracking を広げる
    private func adjustedTitle(_ title: String) -> Text {
        let isAscii = title.unicodeScalars.allSatisfy { $0.isASCII }

        if isAscii {
            return Text(title).tracking(0.8)
        } else {
            return Text(title)
        }
    }

    // MARK: - 日付セル
    private func dateCell(_ date: Date?, cellHeight: CGFloat) -> some View {
        guard let date else {
            return AnyView(
                Rectangle()
                    .fill(Color.white)
                    .frame(height: cellHeight)
            )
        }

        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isInCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let weekday = calendar.component(.weekday, from: date)
        let isHoliday = isJapaneseHoliday(date)

        let textColor: Color = {
            if !isInCurrentMonth { return Color.gray.opacity(0.25) }
            if weekday == 7 { return Color.blue.opacity(0.75) }
            if isHoliday || weekday == 1 { return Color.red.opacity(0.75) }
            return Color.black.opacity(0.55)
        }()

        let isSelected = selectedDateForSheet.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let events = filteredEvents(for: date)

        let rangeEvents = events.filter { e in
            if let s = e.startDate, let end = e.endDate { return s <= date && date <= end }
            return false
        }

        let singleEvents = events.filter { e in
            e.startDate == nil &&
            e.endDate == nil &&
            calendar.isDate(e.date, inSameDayAs: date) &&
            !e.isSecret
        }

        let secretEvents = events.filter { e in
            e.isSecret && (
                (e.startDate != nil && e.endDate != nil && e.startDate! <= date && date <= e.endDate!) ||
                calendar.isDate(e.date, inSameDayAs: date)
            )
        }

        let allDisplayEvents = rangeEvents + singleEvents
        let eventsToShow = Array(allDisplayEvents.prefix(4))
        let hasMore = allDisplayEvents.count > 4

        return AnyView(
            ZStack {

                if isSelected && !isToday {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                }

                VStack(spacing: 2) {

                    // 日付
                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 32, height: 32)
                        }

                        Text("\(day)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isToday ? .white : textColor)
                    }
                    .frame(maxWidth: .infinity)

                    // イベント帯
                    if !eventsToShow.isEmpty {
                        VStack(spacing: 2) {
                            ForEach(eventsToShow.indices, id: \.self) { idx in
                                let event = eventsToShow[idx]
                                let isRange = (event.startDate != nil && event.endDate != nil)
                                let isOverflowBand = (idx == 3 && hasMore)

                                Rectangle()
                                    .fill(color(for: event.type ?? .other).opacity(isOverflowBand ? 0.45 : 1.0))
                                    .frame(height: 14)
                                    .cornerRadius(4)
                                    .overlay(
                                        HStack(spacing: 0) {

                                            if !isRange {
                                                adjustedTitle(truncatedTitle(event.title))
                                                    .font(.system(size: 9.5, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .padding(.leading, 3)
                                                Spacer(minLength: 2)
                                            } else {
                                                Spacer(minLength: 6)
                                                adjustedTitle(truncatedTitle(event.title))
                                                    .font(.system(size: 9.5, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Spacer(minLength: 6)
                                            }

                                            if isOverflowBand {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 9.5, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.9))
                                                    .padding(.trailing, 3)
                                            }
                                        }
                                    )
                            }
                        }
                    }

                    // 秘密イベント
                    if !secretEvents.isEmpty {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                            .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
            .frame(height: cellHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelected {
                    showDayEvents = true
                } else {
                    selectedDateForSheet = date
                    selectedDate = date
                }
            }
            .onLongPressGesture {
                selectedDateForSheet = date
                selectedDate = date
                showDayEvents = true
            }
        )
    }

    // MARK: - 5×7 用の日付生成
    private func generateFiveRowDays(for date: Date) -> [Date?] {

        var days: [Date] = []

        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: date) {
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevLast = prevRange.count

            for i in stride(from: firstWeekday - 2, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: prevLast - i - 1, to: prevMonth.startOfMonth) {
                    days.append(d)
                }
            }
        }

        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(d)
            }
        }

        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) {
            var nextDay = 0
            while days.count < 35 {
                if let d = calendar.date(byAdding: .day, value: nextDay, to: nextMonth.startOfMonth) {
                    days.append(d)
                }
                nextDay += 1
            }
        }

        return days
    }

    // MARK: - 祝日判定
    private func isJapaneseHoliday(_ date: Date) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        if cal.isDateInWeekend(date) { return true }

        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy-MM-dd"

        let key = f.string(from: date)
        let holidayList: Set<String> = [
            "2026-01-01","2026-01-12","2026-02-11","2026-02-23",
            "2026-03-20","2026-04-29","2026-05-03","2026-05-04",
            "2026-05-05","2026-07-20","2026-08-11","2026-09-21",
            "2026-09-22","2026-09-23","2026-10-12","2026-11-03",
            "2026-11-23"
        ]
        return holidayList.contains(key)
    }
}

private extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }
}
