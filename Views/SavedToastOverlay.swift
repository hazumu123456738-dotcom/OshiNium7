//
//  SavedToastOverlay.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import SwiftUI

// ★ 予定を追加・保存・削除した直後に一瞬だけ表示する完了お知らせのオーバーレイ。
//   AppNavigationState.showToast(_:) 経由で、アプリのどこからでも同じ見た目で呼べる
struct SavedToastOverlay: View {
    var message: String = "保存しました"

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.40, green: 0.78, blue: 0.55),
                                Color(red: 0.55, green: 0.85, blue: 0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color(red: 0.40, green: 0.78, blue: 0.55).opacity(0.35), radius: 12, x: 0, y: 6)

                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
    }
}
