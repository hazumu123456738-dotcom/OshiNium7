//
//  CachedFormatters.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/12.
//

import Foundation

// ★ DateFormatter/NumberFormatterの生成はロケールデータの読み込みを伴い、見た目以上に重い処理。
//   SwiftUIのView computed property（例：dateDisplayText）の中でDateFormatter()のように
//   毎回ローカルインスタンス化すると、そのカードを含む画面のbodyが再評価されるたび
//   （＝同じ画面内の他のTextFieldへの入力や、他のボタンのタップのたびに）フォーマッタを
//   毎回作り直すことになり、タイプ時のもたつきとして体感できるレベルの負荷になる
//   （実際にユーザーから推し活費用シミュレーターの金額入力画面で報告された）。
//   フォーマット文字列・ロケール・スタイルごとにインスタンスをキャッシュして使い回す。
//   ★ Viewのbody（メインスレッドで評価される）からの利用のみを想定している。
//   ViewModel/Service側のバックグラウンドスレッドから使う場合は、Formatterクラスの
//   スレッド安全性がAppleにより保証されていないため、このキャッシュは使わないこと
enum CachedFormatters {
    private static var dateFormatters: [String: DateFormatter] = [:]

    static func date(format: String, locale: Locale = Locale(identifier: "ja_JP")) -> DateFormatter {
        let key = "\(locale.identifier)|\(format)"
        if let cached = dateFormatters[key] { return cached }
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = format
        dateFormatters[key] = f
        return f
    }

    private static var numberFormatters: [String: NumberFormatter] = [:]

    static func number(style: NumberFormatter.Style) -> NumberFormatter {
        let key = "\(style.rawValue)"
        if let cached = numberFormatters[key] { return cached }
        let f = NumberFormatter()
        f.numberStyle = style
        numberFormatters[key] = f
        return f
    }
}
