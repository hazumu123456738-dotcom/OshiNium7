//
//  TemplateRankBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ 「持ち物テンプレート」投稿の今月の被いいねランキングで1位・2位に入った
//   ユーザーだけが着けられる、本型のバッジ。GoodsRankBadgeViewと同じMetallicBadgeBaseを
//   使い、アイコンだけ本のマークに差し替える
struct TemplateRankBadgeView: View {
    let tier: GoodsRankBadgeTier
    var month: Int = Calendar.current.component(.month, from: Date())
    var size: CGFloat = 22

    var body: some View {
        MetallicBadgeBase(tier: tier, month: month, size: size, systemImage: "book.closed.fill")
            .accessibilityLabel("持ち物テンプレートランキング\(month)月\(tier.label)バッジ")
    }
}
