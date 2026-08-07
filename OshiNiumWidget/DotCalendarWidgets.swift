//
//  DotCalendarWidgets.swift
//  OshiNiumWidget
//
//  Created by hirai hazumu on 2026/08/07.
//

import WidgetKit
import SwiftUI

// ★ 持ち物チェックリスト・推し活費用シミュレーターのホーム画面ウィジェット。
//   MiniCalendarWidget（予定の色分けカレンダー）と同じ「App Group経由でスナップショットを
//   読むだけ」の考え方を、より軽量な単色ドットカレンダー(WidgetDotCalendarSnapshot)向けに
//   共通化したもの。タップすると.widgetURLでアプリ内の該当ツールへ直接遷移する

// MARK: - 見た目（両ウィジェット共通）

struct DotCalendarWidgetView: View {
    let snapshot: WidgetDotCalendarSnapshot?
    let accentColor: Color
    let icon: String
    let emptyMessage: String

    var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 6) {
                header(snapshot)
                grid(snapshot)
            }
            .padding(14)
        } else {
            emptyState
        }
    }

    private func header(_ snapshot: WidgetDotCalendarSnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor)
            Text(snapshot.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(snapshot.year)年\(snapshot.month)月")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    private func grid(_ snapshot: WidgetDotCalendarSnapshot) -> some View {
        let leading = snapshot.firstWeekday - 1
        let totalCells = leading + snapshot.daysInMonth
        let rows = Int(ceil(Double(totalCells) / 7.0))
        let dayLookup = Dictionary(uniqueKeysWithValues: snapshot.days.map { ($0.day, $0.count) })

        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let day = cellIndex - leading + 1
                        if day >= 1 && day <= snapshot.daysInMonth {
                            dayCell(day: day, count: dayLookup[day] ?? 0, isToday: day == snapshot.todayDay)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(day: Int, count: Int, isToday: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 9.5, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 16, height: 16)
                .background(
                    Circle().fill(isToday ? accentColor : Color.clear)
                )

            Circle()
                .fill(count > 0 ? accentColor : Color.clear)
                .frame(width: 3.5, height: 3.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.secondary.opacity(0.5))
            Text(emptyMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}

// MARK: - 持ち物チェックリスト

struct PackingCalendarEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDotCalendarSnapshot?
}

struct PackingCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> PackingCalendarEntry {
        PackingCalendarEntry(date: Date(), snapshot: SharedWidgetStore.loadPacking())
    }

    func getSnapshot(in context: Context, completion: @escaping (PackingCalendarEntry) -> Void) {
        completion(PackingCalendarEntry(date: Date(), snapshot: SharedWidgetStore.loadPacking()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PackingCalendarEntry>) -> Void) {
        let entry = PackingCalendarEntry(date: Date(), snapshot: SharedWidgetStore.loadPacking())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct PackingCalendarWidget: Widget {
    let kind: String = "PackingCalendarWidget"
    // ★ ウィジェットタップで持ち物チェックリストを直接開く（AppRootView.handleDeepLinkのoshinium://packing）
    private let deepLinkURL = URL(string: "oshinium://packing")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PackingCalendarProvider()) { entry in
            DotCalendarWidgetView(
                snapshot: entry.snapshot,
                accentColor: Color(red: 0.40, green: 0.72, blue: 0.55),
                icon: "checklist",
                emptyMessage: "OshiNiumで持ち物チェックリストを開いて連携してください"
            )
            .containerBackground(Color(red: 0.98, green: 0.98, blue: 0.99), for: .widget)
            .widgetURL(deepLinkURL)
        }
        .configurationDisplayName("持ち物チェックリスト")
        .description("今月、持ち物の記録がある日をホーム画面でひと目で確認できます。タップでアプリの持ち物チェックリストを開きます。")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 推し活費用シミュレーター

struct ExpenseCalendarEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDotCalendarSnapshot?
}

struct ExpenseCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpenseCalendarEntry {
        ExpenseCalendarEntry(date: Date(), snapshot: SharedWidgetStore.loadExpense())
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseCalendarEntry) -> Void) {
        completion(ExpenseCalendarEntry(date: Date(), snapshot: SharedWidgetStore.loadExpense()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseCalendarEntry>) -> Void) {
        let entry = ExpenseCalendarEntry(date: Date(), snapshot: SharedWidgetStore.loadExpense())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct ExpenseCalendarWidget: Widget {
    let kind: String = "ExpenseCalendarWidget"
    // ★ ウィジェットタップで推し活費用シミュレーターを直接開く（oshinium://expense）
    private let deepLinkURL = URL(string: "oshinium://expense")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpenseCalendarProvider()) { entry in
            DotCalendarWidgetView(
                snapshot: entry.snapshot,
                accentColor: Color(red: 0.70, green: 0.55, blue: 0.98),
                icon: "yensign.circle.fill",
                emptyMessage: "OshiNiumで推し活費用シミュレーターを開いて連携してください"
            )
            .containerBackground(Color(red: 0.98, green: 0.98, blue: 0.99), for: .widget)
            .widgetURL(deepLinkURL)
        }
        .configurationDisplayName("推し活費用シミュレーター")
        .description("今月、費用の記録がある日をホーム画面でひと目で確認できます。タップでアプリの推し活費用シミュレーターを開きます。")
        .supportedFamilies([.systemMedium])
    }
}
