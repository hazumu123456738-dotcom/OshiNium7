//
//  WeeklyScheduleView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/18.
//

import SwiftUI

struct WeeklyScheduleView: View {
    @ObservedObject var eventViewModel: EventViewModel
    var selectedGroup: IdolGroup

    @State private var weekOffset: Int = 0
    @State private var weekDates: [Date] = []

    @State private var selectedEvent: Event? = nil

    private var currentWeekStart: Date {
        Calendar.current.date(
            byAdding: .weekOfYear,
            value: weekOffset,
            to: Date().startOfWeek
        ) ?? Date().startOfWeek
    }

    private var currentWeekEnd: Date {
        Calendar.current.date(
            byAdding: .day,
            value: 6,
            to: currentWeekStart
        ) ?? currentWeekStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // MARK: - ヘッダー（タイトル＋週送り）
            HStack {
                Text("今週の予定")
                    .font(.headline)

                Spacer()

                Button {
                    weekOffset -= 1
                    generateWeekDates()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                }

                Text(weekRangeText)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(minWidth: 80)

                Button {
                    weekOffset += 1
                    generateWeekDates()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 4)

            // MARK: - 7日分を横並び
            HStack(spacing: 6) {
                ForEach(weekDates, id: \.self) { date in
                    dayColumn(date: date)
                }
            }
            .frame(maxHeight: 100)
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 1.0, green: 0.96, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06),
                radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .onAppear {
            generateWeekDates()
        }
        .sheet(item: $selectedEvent) { event in
            NavigationStack {
                EventDetailView(
                    event: event,
                    isOwner: true,
                    eventViewModel: eventViewModel
                )
            }
        }
    }

    // MARK: - 1日のカラム
    @ViewBuilder
    func dayColumn(date: Date) -> some View {
        let events = eventsFor(date: date)
        let isTodayDate = isToday(date)

        VStack(spacing: 4) {

            // 上部：日付エリア
            VStack(spacing: 1) {
                Text(date.weekdayShortJP)
                    .font(.caption2)
                    .foregroundColor(weekdayColor(for: date))

                Text(date.dayString)
                    .font(.footnote)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(
                isTodayDate
                ? Color(red: 1.0, green: 0.96, blue: 0.97)
                : Color(.systemGray6)
            )
            .cornerRadius(6)

            // 下部：イベントドット（タップで詳細へ）
            HStack(spacing: 3) {
                ForEach(events.prefix(3)) { event in
                    let type = event.type ?? .other   // ← Optional 安全化

                    Circle()
                        .fill(Color(type.color))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            selectedEvent = event
                        }
                }
            }
            .frame(height: 10)

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            isTodayDate
            ? Color(red: 1.0, green: 0.96, blue: 0.97)
            : Color(.systemGray5)
        )
        .cornerRadius(10)
        .shadow(
            color: isTodayDate ? Color.pink.opacity(0.3) : .clear,
            radius: isTodayDate ? 6 : 0,
            x: 0,
            y: 2
        )
    }

    // MARK: - その日のイベント
    func eventsFor(date: Date) -> [Event] {
        eventViewModel.events.filter {
            $0.groupId == selectedGroup.id &&
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    // MARK: - 今日判定
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - 今週の日付生成
    func generateWeekDates() {
        let start = currentWeekStart
        weekDates = (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: start)
        }
    }

    // MARK: - 週範囲テキスト
    var weekRangeText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        return "\(f.string(from: currentWeekStart))〜\(f.string(from: currentWeekEnd))"
    }

    // MARK: - 曜日カラー
    func weekdayColor(for date: Date) -> Color {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return Color(red: 1.0, green: 0.35, blue: 0.37)   // 日
        case 7: return Color(red: 0.23, green: 0.51, blue: 0.96)  // 土
        default: return .gray
        }
    }
}

// MARK: - Date 拡張
extension Date {
    var startOfWeek: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return cal.date(from: comps) ?? self
    }

    var weekdayShortJP: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }

    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }
}

