//
//  GroupHomeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/21.
//

import SwiftUI

struct GroupHomeView: View {
    let group: IdolGroup
    @EnvironmentObject var eventViewModel: EventViewModel   // ← 修正済み

    var groupEvents: [Event] {
        eventViewModel.events.filter { $0.groupId == group.id }
    }

    var todayEvents: [Event] {
        groupEvents.filter {
            Calendar.current.isDate($0.date, inSameDayAs: Date())
        }
    }

    var upcomingEvents: [Event] {
        groupEvents
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - グループ情報
                HStack(spacing: 16) {
                    if let data = group.imageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.name)
                            .font(.title2)
                            .bold()

                        if let desc = group.groupDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                // MARK: - 今日の予定
                if !todayEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日の予定").font(.headline)
                        ForEach(todayEvents) { event in
                            EventRow(event: event)
                        }
                    }
                    .padding(.horizontal)
                }

                // MARK: - 今後の予定
                VStack(alignment: .leading, spacing: 10) {
                    Text("今後の予定").font(.headline)

                    if upcomingEvents.isEmpty {
                        Text("今後の予定はありません")
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    } else {
                        ForEach(upcomingEvents) { event in
                            EventRow(event: event)
                        }
                    }
                }
                .padding(.horizontal)

                // MARK: - カレンダーへ
                NavigationLink(
                    destination: GroupCalendarView(group: group)
                        .environmentObject(eventViewModel)   // ← 修正済み
                ) {
                    HStack {
                        Text("このグループのカレンダーを見る")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - EventRow（必ず同じファイル内に置く）
struct EventRow: View {
    let event: Event

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body)

                Text(event.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
