//
//  MyPageTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI
struct MyPageTab: View {
    var body: some View {
        VStack {
            Text("マイページ")
                .font(.largeTitle.bold())
                .padding(.top, 20)

            Text("プロフィールや参加グループ数などを表示予定")
                .foregroundColor(.secondary)
                .padding(.top, 8)

            Spacer()
        }
    }
}
