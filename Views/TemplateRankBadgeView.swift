//
//  TemplateRankBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ 「持ち物テンプレート」の投稿でいずれかのグループの被いいねランキング3位以内に
//   入ったユーザーだけが着けられる、本型のバッジ。GoodsRankBadgeViewと全く同じ作りで、
//   アイコンだけ持ち物テンプレートらしい本のマークに差し替える
struct TemplateRankBadgeView: View {
    let tier: GoodsRankBadgeTier
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "book.closed.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.85), lineWidth: size * 0.05)
            )
            .frame(width: size, height: size)
            .shadow(color: (tier.colors.first ?? .clear).opacity(0.5), radius: size * 0.18, x: 0, y: size * 0.06)
            .accessibilityLabel("持ち物テンプレートランキング\(tier.label)バッジ")
    }
}
