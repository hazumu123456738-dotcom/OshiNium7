//
//  CalendarView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/30.
//

import SwiftUI

struct CalendarView: View {
    @Binding var selectedDate: Date
    let events: [Event]

    @ObservedObject var eventViewModel: EventViewModel
    var selectedGroup: IdolGroup?
    var isOwner: Bool = true

    @EnvironmentObject var settingsVM: UserSettingsViewModel   // ★ 追加

    @State private var showAddEvent = false

    var body: some View {
        VStack(spacing: 20) {

            // MARK: - カレンダー本体（ダブルタップ対応 & 月変更対応）
            FSCalendarView(
                selectedDate: $selectedDate,
                events: events,
                isOwner: isOwner,
                onDoubleTapDate: { date in
                    selectedDate = date
                    showAddEvent = true
                },
                onMonthChanged: { newMonth in
                    selectedDate = newMonth
                }
            )
            .frame(height: 350)
            .padding(.horizontal)

            // MARK: - 選択日のイベント一覧
            List {
                ForEach(eventsForSelectedDate) { event in
                    if event.isSecret && !isOwner {
                        EmptyView()
                    } else {
                        NavigationLink(
                            destination: EventDetailView(
                                event: event,
                                isOwner: isOwner,
                                eventViewModel: eventViewModel
                            )
                            .environmentObject(settingsVM)
                        ) {
                            eventRow(event)
                        }
                    }
                }
                .onDelete(perform: deleteEvent)
            }
        }
        .navigationBarTitle("")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - AddEventView（ダブルタップで開く）
        .sheet(isPresented: $showAddEvent) {
            if let group = selectedGroup {
                NavigationStack {
                    AddEventView(
                        selectedGroup: group,
                        defaultDate: selectedDate
                    )
                    .environmentObject(eventViewModel)
                    .environmentObject(settingsVM)
                }
            } else {
                Text("グループが選択されていません")
            }
        }
    }

    // MARK: - イベント行
    func eventRow(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.headline)
            Text(event.date.formatted())
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - 削除処理
    func deleteEvent(at offsets: IndexSet) {
        for index in offsets {
            let event = eventsForSelectedDate[index]
            eventViewModel.deleteEvent(event)
        }
    }

    // MARK: - 選択日のイベント
    var eventsForSelectedDate: [Event] {
        events.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }
}
