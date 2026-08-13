//
//  GoodsRankBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI

// ★ 「推し活ペンライト・グッズ」の今月の被いいねランキングで1位・2位に入った
//   ユーザーだけが、マイページのユーザー名の横に着けられるバッジ。金・銀の2色のみ（銅は無し）。
//   ★ 以前は円形のメタリックメダル（MetallicBadgeBase、ペンライトのアイコン付き）だったが、
//   ランキング画面（RankingView）の「もらえるバッジ」説明カードは同じ実績をダイヤモンド型の
//   アイコン（BrilliantDiamondIcon、オシニウムタブと同じ意匠）で見せており、実際に着けられる
//   バッジと説明の見た目が食い違っていた。実際のバッジ側をランキング画面の意匠に揃える
struct GoodsRankBadgeView: View {
    let tier: GoodsRankBadgeTier
    var month: Int = Calendar.current.component(.month, from: Date())
    var size: CGFloat = 26

    var body: some View {
        DiamondRankBadge(tier: tier, month: month, size: size)
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

// ★ GoodsRankBadgeView/TemplateRankBadgeView共通の土台。RankingView.simpleDiamondIconと
//   同じBrilliantDiamondIcon(ダイヤモンド型の輪郭+ファセット線)にtier別のグラデーションと
//   光沢のハイライトを重ね、右下に「何月の実績か」の小さな数字タグを添える
struct DiamondRankBadge: View {
    let tier: GoodsRankBadgeTier
    var month: Int
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            BrilliantDiamondIcon(
                fill: AnyShapeStyle(
                    LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                ),
                strokeColor: .white
            )

            // 光沢（左上のハイライト）を重ね、より立体的に見せる
            BrilliantGemShape()
                .fill(
                    LinearGradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0)], startPoint: .topLeading, endPoint: .center)
                )
                .blendMode(.plusLighter)
        }
        .frame(width: size, height: size)
        .shadow(color: (tier.colors.first ?? .clear).opacity(0.5), radius: size * 0.18, x: 0, y: size * 0.07)
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
    }
}
