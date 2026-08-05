//
//  OshiNiumRefreshBanner.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI

// ★ ホーム画面上部に常時表示する「OshiNium」の見出し。普段は完全に描画された状態で
//   静止しているが、上に引っ張って（下にスワイプして）再読み込みしている間だけ、
//   標準のくるくるスピナーの代わりに文字が左から右へ繰り返し描かれていくアニメーションになる。
//   常時表示することで「ホーム画面にOshiNiumの文字が無い」状態を解消しつつ、
//   同じ場所がそのままローディング表示としても機能する
struct OshiNiumRefreshBanner: View {
    var accentColor: Color
    var isRefreshing: Bool

    @State private var revealProgress: CGFloat = 1

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            OshiNiumWordmark(fontSize: 19, weight: .bold, color: accentColor)
                .mask(
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle().frame(width: geo.size.width * revealProgress)
                            Spacer(minLength: 0)
                        }
                    }
                )

            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .onChange(of: isRefreshing) { refreshing in
            if refreshing {
                // ★ 1回の再読み込みにつき、文字が描かれるのは1回だけにする
                //   （以前はrepeatForeverで再読み込み中ずっとループし続けていた）
                revealProgress = 0
                withAnimation(.linear(duration: 0.9)) {
                    revealProgress = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.25)) {
                    revealProgress = 1
                }
            }
        }
    }
}
