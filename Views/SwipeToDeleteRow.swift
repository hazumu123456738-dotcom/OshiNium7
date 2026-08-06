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
    @State private var hasCrossedThreshold = false

    private let buttonWidth: CGFloat = 76
    // ★ ボタン幅を超えて引っ張った/閉方向に押し込んだ分は、ネイティブアプリのように
    //   指の動きより遅れてついてくるゴム的な抵抗をかける（ハードクランプだと安っぽく見える）
    private let overDragResistance: CGFloat = 0.25

    private var rawOffset: CGFloat {
        settledOffset + dragTranslation
    }

    private var displayOffset: CGFloat {
        if rawOffset < -buttonWidth {
            return -buttonWidth + (rawOffset + buttonWidth) * overDragResistance
        } else if rawOffset > 0 {
            return rawOffset * overDragResistance
        }
        return rawOffset
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                deleteWithAnimation()
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
                .contentShape(Rectangle())
                .onTapGesture {
                    if settledOffset != 0 {
                        close()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation.width
                        }
                        .onChanged { value in
                            let crossed = settledOffset + value.translation.width < -buttonWidth / 2
                            if crossed != hasCrossedThreshold {
                                hasCrossedThreshold = crossed
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                        .onEnded { value in
                            // ★ 移動距離だけでなく指を離す瞬間の勢い(predictedEndTranslation)も見て、
                            //   短い距離でも素早くフリックしたら開く/閉じるようにする（ネイティブの挙動に合わせる）
                            let projected = settledOffset + value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                settledOffset = projected < -buttonWidth / 2 ? -buttonWidth : 0
                            }
                            hasCrossedThreshold = false
                        }
                )
        }
        .transition(.asymmetric(
            insertion: .opacity,
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }

    private func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            settledOffset = 0
        }
    }

    private func deleteWithAnimation() {
        withAnimation(.easeOut(duration: 0.25)) {
            onDelete()
        }
    }
}
