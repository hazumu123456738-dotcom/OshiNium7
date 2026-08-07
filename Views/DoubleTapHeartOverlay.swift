//
//  DoubleTapHeartOverlay.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI
import Combine

// ★ 投稿画像のダブルタップいいねで表示するハート演出。PostFeedCard・GoodsPostDetailView
//   両方の投稿画像で共通利用する（以前は白いハートが単純に拡大縮小するだけだった）。
//   赤系グラデーション＋グロー＋回転による「揺れ」＋外側に広がって消えるネオン風リングで、
//   近未来的な質感を出す
struct DoubleTapHeartOverlay: View {
    var isActive: Bool
    var scale: CGFloat
    var rotation: Double

    private let heartRed = Color(red: 0.98, green: 0.14, blue: 0.32)
    private let heartRedLight = Color(red: 1.0, green: 0.42, blue: 0.48)

    var body: some View {
        ZStack {
            // ★ 近未来感を出すためのネオン風パルスリング。ハートの発火に合わせて
            //   外側へ広がりながら消える（レーダー/スキャンのような演出）
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(heartRed.opacity(isActive ? 0 : 0.7), lineWidth: 2.5)
                    .frame(width: 56, height: 56)
                    .scaleEffect(isActive ? 1 : (1.8 + CGFloat(i) * 0.5))
                    .animation(
                        .easeOut(duration: 0.7).delay(Double(i) * 0.08),
                        value: isActive
                    )
            }

            Image(systemName: "heart.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [heartRedLight, heartRed], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: heartRed.opacity(0.85), radius: 22)
                .shadow(color: .white.opacity(0.5), radius: 3)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
        }
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// ★ 発火のたびにpop→シェイク(左右に揺れる)→落ち着く、を行う駆動ロジック。
//   PostFeedCard・GoodsPostDetailViewの両方から同じ呼び出しで使えるようにする
@MainActor
final class DoubleTapHeartDriver: ObservableObject {
    @Published var isActive = false
    @Published var scale: CGFloat = 0.4
    @Published var rotation: Double = 0

    func trigger() {
        isActive = true
        scale = 0.4
        rotation = 0

        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
            scale = 1.15
        }

        // ★ 角度を細かく切り替えて「揺れ」を作る（repeatCountのautoreverses任せだと
        //   往復の中間表情が制御しにくいため、明示的なステップ列にする）
        let shakeSteps: [(delay: Double, angle: Double)] = [
            (0.08, 14), (0.16, -12), (0.24, 8), (0.32, -5), (0.40, 2), (0.46, 0)
        ]
        for step in shakeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) { [weak self] in
                withAnimation(.easeInOut(duration: 0.08)) {
                    self?.rotation = step.angle
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                self?.scale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            withAnimation(.easeOut(duration: 0.25)) {
                self?.isActive = false
            }
        }
    }
}
