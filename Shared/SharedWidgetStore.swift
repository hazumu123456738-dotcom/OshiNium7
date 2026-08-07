//
//  SharedWidgetStore.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation

// ★ ホーム画面ウィジェット（ミニカレンダー）とメインアプリの間でデータをやり取りするための
//   共有領域。ウィジェットはFirestoreへ直接繋ぎに行かず、App Group経由でこの軽量な
//   スナップショットだけを読む（オフラインでも高速に表示できるようにするため）。
//   このファイルはメインアプリ・ウィジェット拡張の両方のターゲットに含める。
enum SharedWidgetStore {

    // ★ Xcode側で両ターゲットに同じApp Groups capability（このID）を追加する必要がある
    static let appGroupId = "group.com.hiraihazumu.OshiNium7"

    private static let key = "widgetCalendarSnapshot"

    static func save(_ snapshot: WidgetCalendarSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetCalendarSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetCalendarSnapshot.self, from: data)
    }

    // MARK: - 持ち物チェックリスト・推し活の金額（同じ「月間ドットカレンダー」の考え方を流用）

    private static let packingKey = "widgetPackingSnapshot"
    private static let expenseKey = "widgetExpenseSnapshot"

    static func savePacking(_ snapshot: WidgetDotCalendarSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: packingKey)
    }

    static func loadPacking() -> WidgetDotCalendarSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        guard let data = defaults.data(forKey: packingKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDotCalendarSnapshot.self, from: data)
    }

    static func saveExpense(_ snapshot: WidgetDotCalendarSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: expenseKey)
    }

    static func loadExpense() -> WidgetDotCalendarSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        guard let data = defaults.data(forKey: expenseKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDotCalendarSnapshot.self, from: data)
    }
}

// ★ 持ち物チェックリスト・推し活の金額で共通利用する軽量なカレンダースナップショット。
//   WidgetCalendarSnapshot（予定の色分けドット）と違い、こちらは「その日に記録があるか」
//   だけを示す単色ドットでよいシンプルな用途のため、typesの代わりにcountだけ持つ
struct WidgetDotCalendarDay: Codable, Hashable {
    let day: Int
    let count: Int
}

struct WidgetDotCalendarSnapshot: Codable {
    let title: String
    let year: Int
    let month: Int
    let firstWeekday: Int
    let daysInMonth: Int
    let days: [WidgetDotCalendarDay]
    let todayDay: Int?
    let updatedAt: Date
    // ★ 「本日の持ち物は3点です」「今月の推し活費用は¥12,000です」のような、そのまま画面に
    //   出せる日本語の要約テキスト。円換算・「点」なのか「件」なのかの判断はアプリ側の
    //   ドメイン知識（PackingChecklistItem/OshiExpense）に依存するため、ウィジェット側では
    //   一切計算せずアプリ側で作った文字列をそのまま表示するだけにする
    let summaryText: String
}

// ★ 1日分の「その日に予定があるか・何色で示すか」だけを持つ軽量な構造体
struct WidgetCalendarDay: Codable, Hashable {
    let day: Int
    // 予定の種類（EventType.rawValue）の集合。複数種類あればその分だけ色ドットを出す
    let types: [String]
}

// ★ ウィジェットに渡す「今月のミニカレンダー」のスナップショット
struct WidgetCalendarSnapshot: Codable {
    let groupName: String
    let year: Int
    let month: Int
    // その月の1日の曜日（1=日曜〜7=土曜。Calendar.componentと同じ体系）
    let firstWeekday: Int
    let daysInMonth: Int
    let days: [WidgetCalendarDay]
    let todayDay: Int?
    let updatedAt: Date
}
