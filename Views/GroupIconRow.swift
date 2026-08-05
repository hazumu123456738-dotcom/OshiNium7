//
//  GroupIconRow.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import SwiftUI

// ★ グループの丸アイコン。ホーム画面のアイコン一覧（GroupIconRow）は廃止し、
//   グループ切り替えはマイページタブの長押し（OshiNiumTabView）に一本化したが、
//   このGroupIcon自体はアプリ各所（タブバー長押しの切り替え・プロフィール・
//   イベント当日ハブなど）で共通利用しているため残す
struct GroupIcon: View {
    var group: IdolGroup
    var isSelected: Bool
    var size: CGFloat   // ← サイズを外から受け取る

    // ★ 画像がないグループでも同じサイズ・同じ演出になるよう、
    //   ベースの見た目（写真 or プレースホルダー）を必ず size×size で確保する
    @ViewBuilder
    private var base: some View {
        if let data = group.imageData,
           let uiImage = UIImage(data: data) {

            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)   // ← 余白を無視して最大化
                .frame(width: size, height: size)
                .clipShape(Circle())
                .contentShape(Circle())
                .clipped()

        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.oshiniumPrimary,
                            Color.oshiniumPrimary2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(String(group.name.prefix(1)))
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    // ★ ロゴ系画像（余白の多いバッジ等）でも他のグループと同じ存在感になるよう、
    //   すべてのアイコンの背後に統一サイズの白い台座（メダリオン）を敷いて高級感を揃える
    private let plateInset: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appCardBackground)
                .frame(width: size + plateInset, height: size + plateInset)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)

            base
                // ★ シャボン玉エフェクトは写真・プレースホルダー共通で適用（見た目を完全に統一）
                .overlay(
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.8)
                                ]),
                                center: .center
                            ),
                            lineWidth: isSelected ? 3 : 2
                        )
                        .opacity(0.9)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.55 : 0.35), lineWidth: 1.5)
                        .blur(radius: isSelected ? 2 : 1.5)
                        .offset(x: -2, y: -2)
                        .mask(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white, .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                )
                .shadow(color: Color.white.opacity(isSelected ? 1.0 : 0),
                        radius: isSelected ? 14 : 0)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.9 : 0),
                                lineWidth: isSelected ? 4 : 0)
                        .blur(radius: isSelected ? 3 : 0)
                )
                .frame(width: size, height: size)
        }
        .frame(width: size + plateInset, height: size + plateInset)
    }
}
