//
//  TemplateRankBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ 「持ち物テンプレート」投稿の今月の被いいねランキングで1位・2位に入った
//   ユーザーだけが着けられるバッジ。GoodsRankBadgeViewと同じDiamondRankBadge
//   （ランキング画面と同じダイヤモンド意匠）を使う
struct TemplateRankBadgeView: View {
    let tier: GoodsRankBadgeTier
    var month: Int = Calendar.current.component(.month, from: Date())
    var size: CGFloat = 26

    var body: some View {
        DiamondRankBadge(tier: tier, month: month, size: size)
            .accessibilityLabel("持ち物テンプレートランキング\(month)月\(tier.label)バッジ")
    }
}
