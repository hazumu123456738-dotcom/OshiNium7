//
//  CalendarEventDetailRow.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI

// ★ 推し活の金額計算・持ち物チェックリストのミニカレンダーで、メインのカレンダータブに
//   予定が入っている日（スパークル付きの日）を選んだときに出す詳細行。
//   左側に「この日の予定」であることを示すアイコン、右側にその予定のタイトル・場所を出す
struct CalendarEventDetailRow: View {
    let events: [Event]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(events, id: \.id) { event in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.15))
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .frame(width: 30, height: 30)

                    Text("この日の予定")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                        if let place = event.place, !place.isEmpty {
                            Text(place)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }
}
