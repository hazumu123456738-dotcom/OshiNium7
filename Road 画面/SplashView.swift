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

                Text("読み込み中…")
                    .foregroundColor(.white.opacity(0.85))
                    .font(.subheadline)
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
