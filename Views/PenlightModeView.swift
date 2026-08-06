//
//  PenlightModeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI

// ★ オシニウムタブの「あったら便利な機能」その3：ライブ会場で使える応援ペンライトモード。
//   画面を選んだ色いっぱいに光らせるだけのシンプルな機能（バックエンド不要）。
//   表示中は画面の明るさを最大にし、閉じたら元の明るさに戻す
struct PenlightModeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedColor: Color = PenlightColor.presets[0].color
    @State private var isPulsing = false
    @State private var pulseEnabled = false
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness

    var body: some View {
        ZStack {
            selectedColor
                .opacity(pulseEnabled ? (isPulsing ? 1.0 : 0.55) : 1.0)
                .ignoresSafeArea()
                .animation(pulseEnabled ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isPulsing)

            VStack {
                topBar
                Spacer()
                controls
            }
        }
        .statusBarHidden()
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        .onDisappear {
            UIScreen.main.brightness = originalBrightness
        }
        .onChange(of: pulseEnabled) { _, enabled in
            isPulsing = enabled
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(contrastColor)
                    .padding(10)
                    .background(Circle().fill(contrastColor.opacity(0.15)))
            }

            Spacer()

            Button {
                pulseEnabled.toggle()
            } label: {
                Image(systemName: pulseEnabled ? "waveform" : "waveform.slash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(contrastColor)
                    .padding(10)
                    .background(Circle().fill(contrastColor.opacity(0.15)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var controls: some View {
        VStack(spacing: 18) {
            Text("色をタップして切り替え")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(contrastColor.opacity(0.85))

            HStack(spacing: 14) {
                ForEach(PenlightColor.presets) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColor = preset.color
                        }
                    } label: {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: preset.color == selectedColor ? 3 : 0)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
        .padding(.bottom, 40)
    }

    private var contrastColor: Color {
        selectedColor == .white || selectedColor == .yellow ? .black : .white
    }
}

struct PenlightColor: Identifiable {
    let id = UUID()
    let color: Color

    static let presets: [PenlightColor] = [
        PenlightColor(color: Color.oshiniumPrimary),
        PenlightColor(color: Color(red: 0.95, green: 0.45, blue: 0.55)),
        PenlightColor(color: Color(red: 0.35, green: 0.70, blue: 0.95)),
        PenlightColor(color: Color(red: 0.45, green: 0.85, blue: 0.55)),
        PenlightColor(color: Color(red: 0.98, green: 0.80, blue: 0.30)),
        PenlightColor(color: .white)
    ]
}
