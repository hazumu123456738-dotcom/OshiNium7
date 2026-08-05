//
//  AppTheme.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/02.
//

import SwiftUI
import UIKit

// ★ ダークモード対応の第一弾。これまで全画面で`Color(hex: "#FAFAFC")`（背景）や
//   `Color.white`（カード面）が固定値で使われており、ダークモード端末で開くと
//   背景・カードが白いまま残ってしまっていた。ここで動的に切り替わる2色（背景・カード面）
//   を定義し、既存の固定値をこの2色に置き換えることで、影響範囲が最も大きい
//   「背景が白いまま」「カードが浮いて見える」問題をまず解消する。
//   個々の画面の細かい配色（アクセントカラー・警告色等）は今回のスコープ外。
extension Color {
    // ★ 画面のベース背景。以前の`Color(hex: "#FAFAFC")`の置き換え先
    static let appBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.055, blue: 0.075, alpha: 1)
            : UIColor(red: 0.980, green: 0.980, blue: 0.988, alpha: 1)
    })

    // ★ カード・ピル・プレートなど「面」として浮かせる要素。以前の`Color.white`の置き換え先
    static let appCardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.133, alpha: 1)
            : UIColor.white
    })
}
