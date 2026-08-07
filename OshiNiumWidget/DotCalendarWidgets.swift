//
//  DotCalendarWidgets.swift
//  OshiNiumWidget
//
//  Created by hirai hazumu on 2026/08/07.
//

import WidgetKit
import SwiftUI

// ★ 持ち物チェックリストのホーム画面ウィジェット。App Group経由でスナップショットを
//   読むだけの軽量な作り。タップすると.widgetURLでアプリ内の該当ツールへ直接遷移する
//   （推し活費用シミュレーターのウィジェットは、累計金額カードをそのまま見せる専用の
//   見た目に分けたため、このファイル末尾のExpenseTotalCardWidgetViewを参照）

// MARK: - 見た目（持ち物チェックリスト）
//   ★ 元は月間グリッドを.systemMediumだけに詰め込んでいたが、「視覚的に情報がわかることが
//     大切」というフィードバックを受けて刷新。正方形(.systemSmall)は数字テキストの要約だけに
//     絞って伝えたい情報を確実に入り切らせ、長方形(.systemMedium)は要約テキスト＋
//     「今週」だけの帯カレンダー(月間グリッドではない)を組み合わせて、どちらのサイズでも
//     情報が欠けたり詰まりすぎたりしないようにした

struct DotCalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetDotCalendarSnapshot?
    let accentColor: Color
    let icon: String
    let emptyMessage: String

    var body: some View {
        if let snapshot {
            switch family {
            case .systemSmall:
                summaryOnly(snapshot)
            default:
                summaryWithWeek(snapshot)
            }
        } else {
            emptyState
        }
    }

    // MARK: 正方形 — 要約テキストだけを大きく見せる
    private func summaryOnly(_ snapshot: WidgetDotCalendarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(accentColor)
            Spacer(minLength: 0)
            Text(snapshot.summaryText)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            Text("\(snapshot.year)年\(snapshot.month)月")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: 長方形 — 要約テキスト＋今週だけの帯カレンダー
    private func summaryWithWeek(_ snapshot: WidgetDotCalendarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(snapshot)
            Text(snapshot.summaryText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            weekStrip(snapshot)
        }
        .padding(14)
    }

    private func header(_ snapshot: WidgetDotCalendarSnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor)
            Text(snapshot.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(accentColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(snapshot.year)年\(snapshot.month)月")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    // ★ 月間グリッドではなく「今日を含む週(日〜土)」の7マスだけを1行で見せる。
    //   月境界(1日より前・月末より後)は空欄扱いにする軽い簡略化
    private func weekStrip(_ snapshot: WidgetDotCalendarSnapshot) -> some View {
        let dayLookup = Dictionary(uniqueKeysWithValues: snapshot.days.map { ($0.day, $0.count) })
        let todayDay = snapshot.todayDay ?? 1
        let leading = snapshot.firstWeekday - 1
        let todayCol = (leading + todayDay - 1) % 7
        let weekStartDay = todayDay - todayCol

        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { col in
                let day = weekStartDay + col
                if day >= 1 && day <= snapshot.daysInMonth {
                    weekCell(day: day, count: dayLookup[day] ?? 0, isToday: day == snapshot.todayDay)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func weekCell(day: Int, count: Int, isToday: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(isToday ? accentColor : Color.clear))

            Circle()
                .fill(count > 0 ? accentColor : Color.clear)
                .frame(width: 4, height: 4)
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 推し活費用シミュレーター
//   ★ 「累計金額のカードをそのまま長方形で表示してほしい」という要望を受け、
//     カレンダー要素を一切持たず、OshiExpenseTrackerView.totalCardと同じ構成
//     （累計金額・記録件数・今月の使用額）をそのまま再現する専用の見た目にした

struct ExpenseCalendarEntry: TimelineEntry {
    let date: Date
    let summary: WidgetExpenseSummary?
}

struct ExpenseCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpenseCalendarEntry {
        ExpenseCalendarEntry(date: Date(), summary: SharedWidgetStore.loadExpenseSummary())
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseCalendarEntry) -> Void) {
        completion(ExpenseCalendarEntry(date: Date(), summary: SharedWidgetStore.loadExpenseSummary()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseCalendarEntry>) -> Void) {
        let entry = ExpenseCalendarEntry(date: Date(), summary: SharedWidgetStore.loadExpenseSummary())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// ★ OshiExpenseTrackerView.totalCardと同じ紫グラデーション・文言・レイアウトをそのまま再現
struct ExpenseTotalCardWidgetView: View {
    let summary: WidgetExpenseSummary?

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)
    private let accentColor2 = Color(red: 0.90, green: 0.60, blue: 0.95)

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("累計金額（全グループ合算）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    Text(yenText(summary.totalAmount))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(summary.recordCount)件の記録・タップで開く")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }

                Divider().background(Color.white.opacity(0.3))

                HStack {
                    Text("今月の使用額")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(yenText(summary.monthAmount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(18)
            .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            VStack(spacing: 6) {
                Image(systemName: "yensign.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("OshiNiumで推し活費用シミュレーターを開いて連携してください")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
        }
    }

    private func yenText(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "¥" + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }
}

struct ExpenseCalendarWidget: Widget {
    let kind: String = "ExpenseCalendarWidget"
    // ★ ウィジェットタップで推し活費用シミュレーターを直接開く（oshinium://expense）
    private let deepLinkURL = URL(string: "oshinium://expense")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpenseCalendarProvider()) { entry in
            ExpenseTotalCardWidgetView(summary: entry.summary)
                .containerBackground(Color(red: 0.98, green: 0.98, blue: 0.99), for: .widget)
                .widgetURL(deepLinkURL)
        }
        .configurationDisplayName("推し活費用シミュレーター")
        .description("累計金額のカードをそのままホーム画面で確認できます。タップでアプリの推し活費用シミュレーターを開きます。")
        .supportedFamilies([.systemMedium])
    }
}
