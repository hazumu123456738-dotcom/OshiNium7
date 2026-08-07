//
//  MonthlyMVPBadgeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ 参加しているいずれかのグループで「今月一番いいねを集めたメンバー」になっていると
//   マイページのユーザー名の横に着けられる王冠バッジ。GoodsRankBadgeViewと同じ
//   「小さな円形グラデーション＋アイコン」の作りに揃え、他のバッジと並んでも違和感が無いようにする。
//   あくまで表示専用の実績バッジで、グループのオーナー権限そのものは変更しない
struct MonthlyMVPBadgeView: View {
    var size: CGFloat = 22

    private let colors: [Color] = [Color(red: 1.0, green: 0.84, blue: 0.35), Color(red: 0.90, green: 0.62, blue: 0.10)]

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.85), lineWidth: size * 0.05)
            )
            .frame(width: size, height: size)
            .shadow(color: colors.first?.opacity(0.5) ?? .clear, radius: size * 0.18, x: 0, y: size * 0.06)
            .accessibilityLabel("今月のいいねMVPバッジ")
    }
}
