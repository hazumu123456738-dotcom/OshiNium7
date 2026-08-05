//
//  CommunityContributorBrooch.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI

// ★ 月末集計でアプリ全体の被いいね数が上位5%に入った「コミュニティ貢献者」だけが
//   マイページのユーザー名の横に着けられる、豪華なダイヤのブローチ。
//   色は月ごとに自動で変わり（ユーザー自身は選べない）、宝石の中にさりげなく月の数字を入れる。
//   宝石の形はオシニウムタブのロゴと同じBrilliantGemShapeを再利用し、世界観を統一する
struct CommunityContributorBrooch: View {
    var month: Int = Calendar.current.component(.month, from: Date())
    var size: CGFloat = 30

    private var palette: [Color] {
        Self.monthPalette[(month - 1 + 12) % 12]
    }

    var body: some View {
        ZStack {
            // ★ 豪華さを出すための豪奢な金属フレーム（銀〜白金のグラデーション＋外周の光彩）
            BroochFrameShape()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 1.0), Color(white: 0.68), Color(white: 0.95), Color(white: 0.55)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            BroochFrameShape()
                .stroke(Color.white.opacity(0.9), lineWidth: size * 0.02)

            // 宝石本体
            BrilliantGemShape()
                .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    BrilliantGemFacetLines()
                        .stroke(Color.white.opacity(0.55), lineWidth: size * 0.02)
                )
                .overlay(
                    BrilliantGemShape()
                        .stroke(Color.white.opacity(0.9), lineWidth: size * 0.025)
                )
                .padding(size * 0.17)

            // つや（ハイライト）
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(x: -size * 0.11, y: -size * 0.17)
                .blur(radius: 0.3)

            // ★ 何月の実績かをさりげなく示す小さな数字（宝石の下部に控えめに）
            Text("\(month)")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0.5)
                .offset(y: size * 0.22)
        }
        .frame(width: size, height: size)
        .shadow(color: (palette.first ?? .clear).opacity(0.55), radius: size * 0.16, x: 0, y: size * 0.06)
    }

    // ★ 1〜12月それぞれの2色グラデーション。自動で切り替わるだけで、ユーザーは変更できない
    static let monthPalette: [[Color]] = [
        [Color(red: 0.62, green: 0.83, blue: 0.97), Color(red: 0.25, green: 0.52, blue: 0.85)], // 1月 氷ブルー
        [Color(red: 0.97, green: 0.58, blue: 0.72), Color(red: 0.80, green: 0.28, blue: 0.50)], // 2月 ローズ
        [Color(red: 0.99, green: 0.75, blue: 0.82), Color(red: 0.92, green: 0.48, blue: 0.62)], // 3月 桜
        [Color(red: 0.62, green: 0.90, blue: 0.67), Color(red: 0.28, green: 0.68, blue: 0.44)], // 4月 フレッシュグリーン
        [Color(red: 0.35, green: 0.85, blue: 0.68), Color(red: 0.12, green: 0.60, blue: 0.50)], // 5月 エメラルド
        [Color(red: 0.46, green: 0.67, blue: 0.97), Color(red: 0.18, green: 0.40, blue: 0.82)], // 6月 サファイア
        [Color(red: 0.99, green: 0.84, blue: 0.42), Color(red: 0.93, green: 0.64, blue: 0.14)], // 7月 サンシャイン
        [Color(red: 0.72, green: 0.56, blue: 0.99), Color(red: 0.46, green: 0.30, blue: 0.87)], // 8月 アメジスト
        [Color(red: 0.78, green: 0.36, blue: 0.52), Color(red: 0.56, green: 0.15, blue: 0.32)], // 9月 バーガンディ
        [Color(red: 0.97, green: 0.62, blue: 0.30), Color(red: 0.87, green: 0.42, blue: 0.10)], // 10月 パンプキン
        [Color(red: 0.56, green: 0.42, blue: 0.87), Color(red: 0.35, green: 0.20, blue: 0.66)], // 11月 ディープパープル
        [Color(red: 0.92, green: 0.36, blue: 0.42), Color(red: 0.70, green: 0.14, blue: 0.24)]  // 12月 ルビー
    ]
}

// ★ シールド風の豪華な外枠の輪郭。BrilliantGemShapeより一回り大きい装飾的な多角形
private struct BroochFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        let points: [CGPoint] = [
            CGPoint(x: rect.minX + w * 0.22, y: rect.minY + h * 0.02),
            CGPoint(x: rect.minX + w * 0.78, y: rect.minY + h * 0.02),
            CGPoint(x: rect.maxX - w * 0.01, y: rect.minY + h * 0.30),
            CGPoint(x: rect.maxX - w * 0.05, y: rect.minY + h * 0.56),
            CGPoint(x: rect.minX + w * 0.50, y: rect.maxY),
            CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.56),
            CGPoint(x: rect.minX + w * 0.01, y: rect.minY + h * 0.30)
        ]

        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()

        return path
    }
}
