//
//  SwipeToDeleteRow.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI

// ★ List（.swipeActions）を使っていない画面向けの、Instagram DM風の左スワイプ削除。
//   持ち物チェックリスト・DM一覧のように「ScrollView + VStack + ForEach」で組まれた
//   一覧（カレンダーカード等、行以外の要素とも同じスクロール領域を共有している画面）では
//   Listに組み替えられない/組み替えたくないため、行1つぶんに直接ドラッグジェスチャーを付けて
//   同じ見た目・操作感を再現する
struct SwipeToDeleteRow<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    // ★ 開いた状態（ゴミ箱が見えている状態）で確定している位置。ドラッグ中はこれに
    //   dragTranslationを足した値をそのまま表示に使う
    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let buttonWidth: CGFloat = 76

    private var displayOffset: CGFloat {
        max(-buttonWidth, min(0, settledOffset + dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.18)) {
                    onDelete()
                }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
            }
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("削除")

            content()
                .offset(x: displayOffset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let projected = settledOffset + value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                settledOffset = projected < -buttonWidth / 2 ? -buttonWidth : 0
                            }
                        }
                )
        }
    }
}
