//
//  FeatureGrid.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import SwiftUI

struct FeatureGrid: View {
    let features = [
        ("calendar", "みんなのカレンダー"),
        ("chart.bar", "ランキング"),
        ("flame", "トレンド"),
        ("bell", "通知管理"),
        ("ticket", "チケット管理"),
        ("bag", "グッズ管理"),
        ("yensign", "課金管理"),   // ← 修正ポイント
        ("book", "推し活日記")
    ]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: 20
        ) {
            ForEach(features, id: \.0) { icon, title in
                VStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(Color.pink.opacity(0.2))
                        .cornerRadius(12)

                    Text(title)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}
