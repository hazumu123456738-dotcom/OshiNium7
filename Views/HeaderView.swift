//
//  HeaderView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/05.
//

import SwiftUI

struct HeaderView: View {

    var userName: String
    var userId: String
    var onAddEvent: () -> Void

    var body: some View {

        ZStack {

            // MARK: - 中央タイトル（完全中央固定）
            Text("OshiNium")
                .font(.title3)
                .bold()
                .foregroundColor(.primary)

            HStack {

                // MARK: - 左：プロフィール画像のみ
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                Spacer()

                // MARK: - 右：＋ボタン
                Button(action: onAddEvent) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.pink.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.white)
    }
}
