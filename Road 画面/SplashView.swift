//
//  SplashView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/04.
//

import SwiftUI

struct SplashView: View {

    @State private var glow = false
    @State private var rotate = false
    @State private var fadeOut = false

    var body: some View {
        ZStack {

            // 背景画像
            Image("splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 🔥 ダイアモンド光アニメーション（中央）
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .opacity(glow ? 1 : 0.2)
                .animation(.easeInOut(duration: 1.6).repeatForever(), value: glow)

            // 🔥 下部のローディング（ダイアモンド形が回転）
            VStack {
                Spacer()

                DiamondShape()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.1)
                            ]),
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 45, height: 45)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotate)
                    .padding(.bottom, 8)

                LoadingDotsText()
                    .padding(.bottom, 60)
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .animation(.easeOut(duration: 0.8), value: fadeOut)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        glow = true
        rotate = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                fadeOut = true
            }
        }
    }
}

// 🔷「読み込み中」の文字。固定の「…」ではなく、3つの点が波のようにふわっと
//   大きさと透明度を交互に変える呼吸アニメーションにして、機械的な点滅ではなく
//   柔らかく次から次へ流れる印象にする
private struct LoadingDotsText: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            Text("読み込み中")
                .foregroundColor(.white.opacity(0.85))
                .font(.subheadline)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 5, height: 5)
                        .scaleEffect(animate ? 1 : 0.4)
                        .opacity(animate ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.7)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18),
                            value: animate
                        )
                }
            }
        }
        .onAppear { animate = true }
    }
}

// 🔷 ダイアモンド形
struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let top = CGPoint(x: rect.midX, y: rect.minY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.midY)

        path.move(to: top)
        path.addLine(to: right)
        path.addLine(to: bottom)
        path.addLine(to: left)
        path.closeSubpath()

        return path
    }
}
