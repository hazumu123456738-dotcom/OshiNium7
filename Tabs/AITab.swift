//
//  AITab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/24.
//

import SwiftUI

struct AITab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {

                // 工事中イラスト
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 200, height: 200)

                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("AI 機能を準備中…")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("ここには今後、AIを使った便利機能が追加されます。")
                        .font(.body)
                        .multilineTextAlignment(.center)

                    Text("・AI予定追加\n・AI検索\n・AIチャット\nなどをまとめて使えるようにします。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AI")
                        .font(.headline)
                        .bold()
                }
            }
        }
    }
}
