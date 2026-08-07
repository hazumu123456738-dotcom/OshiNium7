//
//  GoodsRankBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI

// ★ 「推し活ペンライト・グッズ」の今月の被いいねランキングで1位・2位に入った
//   ユーザーだけが、マイページのユーザー名の横に着けられるペンライト型バッジ。
//   金・銀の2色のみ（銅は無し）。CommunityContributorBroochと同じく金属質な光沢と
//   月の数字を入れ、世界観を揃える
struct GoodsRankBadgeView: View {
    let tier: GoodsRankBadgeTier
    var month: Int = Calendar.current.component(.month, from: Date())
    var size: CGFloat = 22

    var body: some View {
        MetallicBadgeBase(tier: tier, month: month, size: size, systemImage: "flashlight.on.fill")
            .accessibilityLabel("推し活グッズランキング\(month)月\(tier.label)バッジ")
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

// ★ GoodsRankBadgeView/TemplateRankBadgeView共通の金属質バッジ土台。
//   単純な円グラデーションではなく、斜めのハイライト帯（つや）と月の数字タグを重ね、
//   「メタリックな質感」と「何月の実績か」の両方を一目で伝える
struct MetallicBadgeBase: View {
    let tier: GoodsRankBadgeTier
    var month: Int
    var size: CGFloat = 22
    var systemImage: String

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing))

            // ★ 光沢帯（つや）。斜めに白いグラデーションの帯を重ねて金属らしい反射感を出す
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.75), Color.white.opacity(0.0)],
                        startPoint: .topLeading, endPoint: .center
                    )
                )
                .blendMode(.plusLighter)

            Circle()
                .trim(from: 0.0, to: 0.5)
                .stroke(Color.white.opacity(0.55), lineWidth: size * 0.04)
                .rotationEffect(.degrees(-45))

            Image(systemName: systemImage)
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 0.5)

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: size * 0.05)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            // ★ 何月の実績かを示す小さな金属タグ。バッジ本体の右下に控えめに添える
            Text("\(month)")
                .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(width: size * 0.5, height: size * 0.5)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.55)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: size * 0.02))
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
                .offset(x: size * 0.12, y: size * 0.12)
        }
        .shadow(color: (tier.colors.first ?? .clear).opacity(0.55), radius: size * 0.2, x: 0, y: size * 0.07)
    }
}
