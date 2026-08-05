//
//  StringOptionalExtensions.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import Foundation

// ★ 「値はあるが空文字列」を「値が無い」と同じに扱いたい場面（キャプション・会場名・メモ等の
//   フォールバック表示）で、`x?.isEmpty == false ? x! : fallback` という強制アンラップ付きの
//   三項演算子が複数箇所にコピーされていたのをここに集約する。安全性は変えず、書き方だけ整理する
extension Optional where Wrapped == String {
    var nonEmptyOrNil: String? {
        (self?.isEmpty == false) ? self : nil
    }
}
