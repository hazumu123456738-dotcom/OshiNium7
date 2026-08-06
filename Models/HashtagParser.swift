//
//  HashtagParser.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import Foundation

// ★ 投稿キャプション中の「#〇〇」ハッシュタグ抽出ロジック。
//   以前はPostFeedCard（ハイライト表示）とPostSearchView（よく使われるタグ集計）に
//   同じ正規表現がそれぞれ別々に書かれていたため、1箇所にまとめて共有する
enum HashtagParser {
    static let pattern = "#[^\\s#]+"

    static func matches(in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
    }

    // ★ 文中に登場する「#〇〇」を出現順のまま抽出する（重複も含む）
    static func extractHashtags(from text: String) -> [String] {
        let ns = text as NSString
        return matches(in: text).map { ns.substring(with: $0.range) }
    }
}
