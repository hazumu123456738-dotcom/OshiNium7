//
//  GroupCalendarView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/21.
//

import SwiftUI

struct GroupCalendarView: View {
    let group: IdolGroup
    @EnvironmentObject var eventViewModel: EventViewModel   // ← 修正ポイント

    // グループ専用イベントを返す
    var groupEvents: [Event] {
        eventViewModel.events.filter { $0.groupId == group.id }
    }

    var body: some View {
        VStack {
            Text("\(group.name) のカレンダー")
                .font(.title2)
                .padding()

            if groupEvents.isEmpty {
                Text("このグループの予定はありません")
                    .foregroundColor(.secondary)
            } else {
                List(groupEvents) { event in
                    VStack(alignment: .leading) {
                        Text(event.title).bold()
                        Text(event.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("\(group.name) カレンダー")
    }
}
