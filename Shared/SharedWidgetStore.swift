//
//  SharedWidgetStore.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation

// ★ ホーム画面ウィジェット（持ち物チェックリスト・推し活費用シミュレーター）とメインアプリの間で
//   データをやり取りするための共有領域。ウィジェットはFirestoreへ直接繋ぎに行かず、App Group経由で
//   この軽量なスナップショットだけを読む（オフラインでも高速に表示できるようにするため）。
//   このファイルはメインアプリ・ウィジェット拡張の両方のターゲットに含める。
//   ★ 以前はグループカレンダーのミニカレンダーウィジェットも持っていたが、
//   「一週間のカードも一ヶ月のカードもゴミだった」というフィードバックにより廃止した
enum SharedWidgetStore {

    // ★ Xcode側で両ターゲットに同じApp Groups capability（このID）を追加する必要がある
    static let appGroupId = "group.com.hiraihazumu.OshiNium7"

    // MARK: - 持ち物チェックリスト

    private static let packingKey = "widgetPackingSnapshot"

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

    // MARK: - 推し活費用シミュレーター
    //   ★ 以前はPackingと同じ「月間ドットカレンダー」を流用していたが、「累計金額のカードを
    //     そのまま表示してほしい」という要望を受け、カレンダー情報を一切持たない専用の
    //     軽量スナップショットに置き換えた（OshiExpenseTrackerView.totalCardと同じ数値を渡す）

    private static let expenseKey = "widgetExpenseSummary"

    static func saveExpenseSummary(_ summary: WidgetExpenseSummary) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(summary) else { return }
        defaults.set(data, forKey: expenseKey)
    }

    static func loadExpenseSummary() -> WidgetExpenseSummary? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        guard let data = defaults.data(forKey: expenseKey) else { return nil }
        return try? JSONDecoder().decode(WidgetExpenseSummary.self, from: data)
    }

    // MARK: - 着せ替えテーマ
    //   ★ ウィジェット拡張はThemeManager(Firestoreリスナーを持つメインアプリ専用のクラス)に
    //   依存できないため、選択中テーマの見た目に必要な色だけを軽量スナップショットとして
    //   App Group経由で共有する。ThemeManager.applyTheme(_:)が呼ばれるたびに書き込まれる

    private static let themeKey = "widgetThemeSnapshot"

    static func saveTheme(_ snapshot: WidgetThemeSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: themeKey)
    }

    static func loadTheme() -> WidgetThemeSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        guard let data = defaults.data(forKey: themeKey) else { return nil }
        return try? JSONDecoder().decode(WidgetThemeSnapshot.self, from: data)
    }
}

// ★ ウィジェットに必要な最小限の色情報だけを持つ。baseColorHex/accentColorHexは
//   CustomTheme.resolvedBaseColor/resolvedAccentColorをUIColor経由で16進数化したもの。
//   isDefaultがtrueの間はウィジェット側で一切色を上書きせず、既存の見た目のままにする
struct WidgetThemeSnapshot: Codable {
    let isDefault: Bool
    let baseColorHex: String
    let accentColorHex: String
}

// ★ 推し活費用ウィジェット専用。OshiExpenseTrackerViewの累計金額カードと同じ4つの数値だけを持つ
struct WidgetExpenseSummary: Codable {
    let totalAmount: Int      // 全グループ合算の累計金額
    let monthAmount: Int      // 今月の使用額
    let recordCount: Int      // 記録件数
    let updatedAt: Date
}

// ★ 持ち物チェックリスト・推し活の金額で共通利用する軽量なスナップショット。
//   「その日に記録があるか」だけを示す単色ドットでよいシンプルな用途のため、countだけ持つ
//   （持ち物ウィジェットは今週の帯カレンダーに、推し活費用ウィジェットは累計金額カードのみに使う）
struct WidgetDotCalendarDay: Codable, Hashable {
    let day: Int
    let count: Int
}

// ★ 「本日」に関する情報（todayDay/summaryText）はあえて持たない。以前はここに
//   「本日の持ち物は3点です」のような文字列を書き込み時点の日付でベイクしていたが、
//   アプリを開かない限りこのスナップショットは更新されないため、日をまたぐと
//   「昨日は3件あったのに今日は0件のはずなのに、まだ3件と表示され続ける」という
//   実害のあるバグになっていた（ユーザー報告で発覚）。日ごとの件数(days)という
//   生データだけを持たせ、「今日は何日か」「今日は何件か」はウィジェット側
//   （DotCalendarWidgets.swift）が描画のたびにDate()から都度計算する
struct WidgetDotCalendarSnapshot: Codable {
    let title: String
    let year: Int
    let month: Int
    let firstWeekday: Int
    let daysInMonth: Int
    let days: [WidgetDotCalendarDay]
    let updatedAt: Date
}
