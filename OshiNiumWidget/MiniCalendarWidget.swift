//
//  MiniCalendarWidget.swift
//  OshiNiumWidget
//
//  Created by hirai hazumu on 2026/07/30.
//

import WidgetKit
import SwiftUI

// MARK: - タイムラインエントリー

struct CalendarEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetCalendarSnapshot?
}

// MARK: - タイムラインプロバイダー
//   ★ ウィジェットはFirestoreに直接繋がない。メインアプリがApp Group経由で
//     書き出しておいたスナップショット（SharedWidgetStore）を読むだけにして、
//     オフラインでも一瞬で表示できるようにする

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), snapshot: SharedWidgetStore.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(CalendarEntry(date: Date(), snapshot: SharedWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let entry = CalendarEntry(date: Date(), snapshot: SharedWidgetStore.load())
        // ★ アプリ側からの更新（WidgetCenter.reloadAllTimelines）を主な更新経路にしつつ、
        //   アプリを開かない日が続いても日付表示だけはズレないよう1時間おきに再評価する
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - 見た目

struct MiniCalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: CalendarProvider.Entry

    // ★ ウィジェットはOshiNium7本体と別ターゲット（AppTheme.swiftを含まない）のため、
    //   Color.oshiniumPrimaryを参照できずリテラルのまま持つ
    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                header(snapshot)
                // ★ 正方形(.systemSmall)には月間グリッドは詰め込みすぎて読めなくなるため、
                //   「今日を含む週」だけの帯カレンダーに絞る。長方形(.systemMedium)は
                //   これまで通り月間グリッド（実機で良好と確認済みのため変更しない）
                if family == .systemSmall {
                    weekStrip(snapshot)
                } else {
                    grid(snapshot)
                }
            }
            .padding(14)
        } else {
            emptyState
        }
    }

    // ★ 「今日を含む週(日〜土)」の7マスだけを1行で見せる。月境界は空欄扱いの軽い簡略化
    private func weekStrip(_ snapshot: WidgetCalendarSnapshot) -> some View {
        let dayLookup = Dictionary(uniqueKeysWithValues: snapshot.days.map { ($0.day, $0.types) })
        let todayDay = snapshot.todayDay ?? 1
        let leading = snapshot.firstWeekday - 1
        let todayCol = (leading + todayDay - 1) % 7
        let weekStartDay = todayDay - todayCol

        return HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { col in
                let day = weekStartDay + col
                if day >= 1 && day <= snapshot.daysInMonth {
                    dayCell(day: day, types: dayLookup[day] ?? [], isToday: day == snapshot.todayDay)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func header(_ snapshot: WidgetCalendarSnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor)
            Text(snapshot.groupName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(snapshot.year)年\(snapshot.month)月")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    // ★ 週の頭（日）を先頭にした7列グリッド。先頭の空きマスは前月分の余白として空欄にする
    private func grid(_ snapshot: WidgetCalendarSnapshot) -> some View {
        let leading = snapshot.firstWeekday - 1
        let totalCells = leading + snapshot.daysInMonth
        let rows = Int(ceil(Double(totalCells) / 7.0))
        let dayLookup = Dictionary(uniqueKeysWithValues: snapshot.days.map { ($0.day, $0.types) })

        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let day = cellIndex - leading + 1
                        if day >= 1 && day <= snapshot.daysInMonth {
                            dayCell(day: day, types: dayLookup[day] ?? [], isToday: day == snapshot.todayDay)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(day: Int, types: [String], isToday: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 9.5, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 16, height: 16)
                .background(
                    Circle().fill(isToday ? accentColor : Color.clear)
                )

            HStack(spacing: 1.5) {
                ForEach(Array(types.prefix(3)), id: \.self) { raw in
                    Circle()
                        .fill(color(for: raw))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func color(for rawType: String) -> Color {
        (EventType(rawValue: rawType) ?? .other).iconColor
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 22))
                .foregroundColor(.secondary.opacity(0.5))
            Text("OshiNiumを開いて連携してください")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}

// MARK: - ウィジェット定義

struct MiniCalendarWidget: Widget {
    let kind: String = "MiniCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            MiniCalendarWidgetView(entry: entry)
                .containerBackground(Color(red: 0.98, green: 0.98, blue: 0.99), for: .widget)
        }
        .configurationDisplayName("OshiNium ミニカレンダー")
        .description("選択中グループの予定をホーム画面でひと目で確認できます。正方形は今週、長方形は今月分を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
