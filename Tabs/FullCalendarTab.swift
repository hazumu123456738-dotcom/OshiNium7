//
//  FullCalendarTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/24.
//

import SwiftUI

struct FullCalendarTab: View {

    @EnvironmentObject var eventViewModel: EventViewModel

    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    // ★ イベント遷移用の NavigationPath をここで一元管理
    @State private var navigationPath = NavigationPath()

    @State private var currentIndex: Int = 12
    private let months: [Date] = generateMonths()

    var body: some View {

        NavigationStack(path: $navigationPath) {

            VStack(spacing: 0) {

                header

                TabView(selection: $currentIndex) {
                    ForEach(0..<months.count, id: \.self) { index in
                        MonthlyCalendarView(
                            month: months[index],
                            eventsByDate: eventViewModel.eventsByDate,
                            selectedGroup: $selectedGroup,
                            selectedDate: $selectedDate,
                            // ★ ここで「イベントが選ばれたときの遷移」を親に渡す
                            onSelectEvent: { event in
                                // 常に「イベント詳細だけ」を乗せるようにする
                                navigationPath = NavigationPath()
                                navigationPath.append(event)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.white)
            // ★ EventDetailView への遷移はここで一元管理
            .navigationDestination(for: Event.self) { event in
                EventDetailView(
                    event: event,
                    isOwner: true,
                    eventViewModel: eventViewModel
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {

            Text(monthTitle(months[currentIndex]))
                .font(.system(size: 22, weight: .semibold))

            Text("ここに推しグループ情報やフィルターを後で載せる")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: date)
    }
}

func generateMonths() -> [Date] {
    let calendar = Calendar.current
    let now = Date()
    var months: [Date] = []

    for i in -12...12 {
        if let month = calendar.date(byAdding: .month, value: i, to: now) {
            months.append(month)
        }
    }
    return months
}
