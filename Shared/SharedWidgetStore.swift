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
