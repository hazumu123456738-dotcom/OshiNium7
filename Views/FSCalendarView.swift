//
//  FSCalendarView.swift .swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import SwiftUI
import FSCalendar
import UIKit

// MARK: - 日本の祝日判定
extension Date {
    var isJapaneseHoliday: Bool {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: self)

        let formatter = CachedFormatters.date(format: "yyyy/MM/dd")

        let holidays = [
            "\(year)/01/01",
            "\(year)/02/11",
            "\(year)/02/23",
            "\(year)/04/29",
            "\(year)/05/03",
            "\(year)/05/04",
            "\(year)/05/05",
            "\(year)/11/03",
            "\(year)/11/23"
        ]

        let holidayDates = holidays.compactMap { formatter.date(from: $0) }
        return holidayDates.contains { calendar.isDate($0, inSameDayAs: self) }
    }
}

struct FSCalendarView: UIViewRepresentable {

    @Binding var selectedDate: Date
    var events: [Event]
    var isOwner: Bool
    var onDoubleTapDate: (Date) -> Void
    var onMonthChanged: (Date) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> FSCalendar {
        let calendar = FSCalendar()
        calendar.delegate = context.coordinator
        calendar.dataSource = context.coordinator

        calendar.placeholderType = .none
        calendar.headerHeight = 0
        calendar.appearance.headerMinimumDissolvedAlpha = 0
        calendar.locale = Locale(identifier: "ja_JP")

        calendar.appearance.weekdayFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        calendar.appearance.weekdayTextColor = UIColor.label

        // 曜日色（赤・青）
        DispatchQueue.main.async {
            let labels = calendar.calendarWeekdayView.weekdayLabels
            if labels.count == 7 {
                labels[0].textColor = .systemRed
                labels[6].textColor = .systemBlue
            }
        }

        // 今日の色
        calendar.appearance.todayColor = UIColor.systemPink.withAlphaComponent(0.35)
        calendar.appearance.titleTodayColor = .white
        calendar.appearance.todaySelectionColor = .systemPink
        calendar.appearance.selectionColor = UIColor.systemPink.withAlphaComponent(0.25)
        calendar.appearance.titleDefaultColor = UIColor.label

        // ドット位置
        calendar.appearance.eventSelectionColor = .clear
        calendar.appearance.eventOffset = CGPoint(x: 0, y: 10)

        // ダブルタップ
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        calendar.addGestureRecognizer(doubleTap)

        return calendar
    }

    func updateUIView(_ uiView: FSCalendar, context: Context) {
        context.coordinator.events = events
        context.coordinator.isOwner = isOwner

        DispatchQueue.main.async {
            uiView.reloadData()
            uiView.select(self.selectedDate)
            uiView.setCurrentPage(self.selectedDate, animated: false)
        }
    }

    class Coordinator: NSObject, FSCalendarDelegate, FSCalendarDataSource, FSCalendarDelegateAppearance {

        var parent: FSCalendarView
        var events: [Event] = []
        var isOwner: Bool = true

        init(_ parent: FSCalendarView) {
            self.parent = parent
        }

        // MARK: - 色ルール（完全統一版）
        func color(for type: EventType) -> UIColor {
            switch type {

            case .live, .event:
                return .systemRed          // ライブ・イベント → 赤

            case .tv:
                return .systemGreen        // 出演系 → 緑

            case .release:
                return .systemBlue         // ★ リリース → 青（修正済み）

            case .sns:
                return .systemOrange       // SNS → オレンジ

            case .anniversary:
                return .systemPurple       // 記念日 → 紫

            case .other:
                return .systemGray         // その他 → 灰
            }
        }

        // MARK: - 範囲判定
        private func isDate(_ date: Date, inRangeOf event: Event) -> Bool {
            let cal = Calendar.current

            if let s = event.startDate, let e = event.endDate {

                if s > e {
                    print("⚠️ FSCalendar: Invalid range detected → \(s) > \(e)")
                    return false
                }

                return (s...e).contains(date)
            }

            return cal.isDate(event.date, inSameDayAs: date)
        }

        // MARK: - ドット数
        func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
            let eventsForDay = events.filter {
                isDate(date, inRangeOf: $0) && !$0.isSecret
            }
            return min(eventsForDay.count, 3)
        }

        // MARK: - ドット色
        func calendar(_ calendar: FSCalendar,
                      appearance: FSCalendarAppearance,
                      eventDefaultColorsFor date: Date) -> [UIColor]? {

            let eventsForDay = events.filter {
                isDate(date, inRangeOf: $0) && !$0.isSecret
            }
            if eventsForDay.isEmpty { return nil }

            return eventsForDay.prefix(3).map { color(for: $0.type ?? .other) }
        }

        // MARK: - ドット位置
        func calendar(_ calendar: FSCalendar,
                      appearance: FSCalendarAppearance,
                      eventOffsetFor date: Date) -> CGPoint {
            CGPoint(x: 0, y: 10)
        }

        // MARK: - アイコン（秘密イベント専用 🗝️）
        func calendar(_ calendar: FSCalendar, imageFor date: Date) -> UIImage? {

            let secretEvents = events.filter {
                $0.isSecret && isDate(date, inRangeOf: $0)
            }

            if isOwner, !secretEvents.isEmpty {
                return UIImage(systemName: "lock.fill")?
                    .withTintColor(.purple, renderingMode: .alwaysOriginal)
            }

            return nil
        }

        // MARK: - 日付選択
        func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
            parent.selectedDate = date
        }

        func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
            parent.onMonthChanged(calendar.currentPage)
        }

        // MARK: - ダブルタップ
        @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
            guard let calendar = sender.view as? FSCalendar else { return }

            let point = sender.location(in: calendar.collectionView)

            if let indexPath = calendar.collectionView.indexPathForItem(at: point),
               let cell = calendar.collectionView.cellForItem(at: indexPath) as? FSCalendarCell,
               let date = calendar.date(for: cell) {

                parent.selectedDate = date
                parent.onDoubleTapDate(date)
            }
        }

        // MARK: - 祝日・週末色
        func calendar(_ calendar: FSCalendar,
                      appearance: FSCalendarAppearance,
                      titleDefaultColorFor date: Date) -> UIColor? {

            if date.isJapaneseHoliday { return .systemRed }

            let weekday = Calendar.current.component(.weekday, from: date)
            if weekday == 1 { return .systemRed }
            if weekday == 7 { return .systemBlue }

            return .label
        }
    }
}
