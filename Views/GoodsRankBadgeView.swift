//
//  GoodsRankBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI

// ★ 「推し活ペンライト・グッズ」でいずれかのグループの被いいねランキング3位以内に
//   入ったユーザーだけが、マイページのユーザー名の横に着けられるペンライト型バッジ。
//   金・銀・銅で色が変わる（CommunityContributorBroochと並べても違和感の無い、
//   小さな円形グラデーション＋アイコンのシンプルな作り）
struct GoodsRankBadgeView: View {
    let tier: GoodsRankBadgeTier
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "flashlight.on.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.85), lineWidth: size * 0.05)
            )
            .frame(width: size, height: size)
            .shadow(color: (tier.colors.first ?? .clear).opacity(0.5), radius: size * 0.18, x: 0, y: size * 0.06)
            .accessibilityLabel("推し活グッズランキング\(tier.label)バッジ")
    }
}

enum GoodsRankBadgeTier {
    case gold, silver, bronze

    // ★ 数字が小さいほど上位（比較用）
    var rank: Int {
        switch self {
        case .gold: return 0
        case .silver: return 1
        case .bronze: return 2
        }
    }

    var label: String {
        switch self {
        case .gold: return "金"
        case .silver: return "銀"
        case .bronze: return "銅"
        }
    }

    var colors: [Color] {
        switch self {
        case .gold: return [Color(red: 1.0, green: 0.84, blue: 0.35), Color(red: 0.90, green: 0.62, blue: 0.10)]
        case .silver: return [Color(red: 0.90, green: 0.92, blue: 0.95), Color(red: 0.65, green: 0.68, blue: 0.72)]
        case .bronze: return [Color(red: 0.85, green: 0.58, blue: 0.35), Color(red: 0.65, green: 0.38, blue: 0.18)]
        }
    }
}
