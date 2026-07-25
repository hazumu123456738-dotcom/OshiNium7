//
//  HomeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import SwiftUI
import UIKit

struct HomeView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @Binding var selectedDate: Date
    @Binding var selectedGroup: IdolGroup?
    @Binding var showAddEvent: Bool

    @State private var showGroupManager = false
    @State private var isTodayExpanded = false
    @State private var isTodayFullyExpanded = false
    @State private var pendingGroup: IdolGroup? = nil
    @State private var showGroupSwitchAlert = false
    @State private var switchAnimation = false
    @State private var showSwitchBanner = false
    @State private var showAddOption = false
    @State private var showAIAdd = false
    @State private var showManualAdd = false
    @State private var tappedDateForAdd: Date? = nil

    var isOwner: Bool = true

    var body: some View {
        ZStack {
            mainContent
                .opacity(switchAnimation ? 0.3 : 1.0)

            if showSwitchBanner {
                switchBanner
            }
        }
        .alert(
            "「\(pendingGroup?.name ?? "")」のホーム画面に移動しますか？",
            isPresented: $showGroupSwitchAlert
        ) {
            Button("キャンセル", role: .cancel) {}
            Button("はい") {
                if let group = pendingGroup {
                    switchToGroup(group)
                }
            }
        }
        .presentationCornerRadius(20)
        .onAppear {
            if selectedGroup == nil {
                selectedGroup = groupViewModel.groups.first
            }
        }
        .onChange(of: groupViewModel.groups) { newGroups in
            selectedGroup = newGroups.first
        }
        .sheet(isPresented: $showAddOption) {
            AddMethodSelectView(
                onSelectAI: { showAIAdd = true },
                onSelectManual: { showManualAdd = true }
            )
        }
        .navigationDestination(isPresented: $showAIAdd) {
            if let group = selectedGroup {
                AIAddEventView(
                    selectedGroup: group,
                    defaultDate: tappedDateForAdd ?? selectedDate
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            } else {
                Text("グループが選択されていません")
            }
        }
        .navigationDestination(isPresented: $showManualAdd) {
            if let group = selectedGroup {
                AddEventView(
                    selectedGroup: group,
                    defaultDate: tappedDateForAdd ?? selectedDate
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            } else {
                Text("グループが選択されていません")
            }
        }
    }

    // MARK: - メインコンテンツ
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {

                HeaderView(
                    userName: "ユーザー名",
                    userId: "user_id",
                    onAddEvent: {
                        tappedDateForAdd = selectedDate
                        showAddOption = true
                    }
                )

                GroupIconRow(
                    groups: groupViewModel.groups,
                    selectedGroup: selectedGroup,
                    onAddGroup: { showGroupManager = true },
                    onRequestSwitchGroup: { group in
                        pendingGroup = group
                        showGroupSwitchAlert = true
                    },
                    onDeleteGroup: { group in deleteGroup(group) }
                )
                .padding(.vertical, 4)

                todayCard
                calendarSection

                if let group = selectedGroup,
                   let nextEvent = nextEventForSelectedGroup {
                    NextEventCardView(event: nextEvent, group: group)
                        .padding(.top, 6)
                }

                if let group = selectedGroup {
                    WeeklyScheduleView(
                        eventViewModel: eventViewModel,
                        selectedGroup: group
                    )
                    .frame(height: 110)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showGroupManager) {
            GroupsTab()
                .environmentObject(groupViewModel)
        }
    }

    // MARK: - TODAYカード
    private var todayCard: some View {
        let isToday = Calendar.current.isDateInToday(selectedDate)
        let events = eventsForSelectedDate
        let firstThree = Array(events.prefix(3))
        let remaining = Array(events.dropFirst(3))

        return VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isToday ? "✨ TODAY" : "\(selectedDateJP) の予定")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(
                        isToday
                        ? (events.isEmpty ? "今日は予定がありません" : "本日は \(events.count) 件の予定があります")
                        : (events.isEmpty ? "この日は予定がありません" : "この日は \(events.count) 件の予定があります")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text(isTodayExpanded ? "閉じる" : "予定を閲覧する")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Image(systemName: isTodayExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut) {
                    isTodayExpanded.toggle()
                    if !isTodayExpanded { isTodayFullyExpanded = false }
                }
            }

            if isTodayExpanded {
                Divider()

                ForEach(firstThree) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatEventTime(event.date))
                            .font(.caption)
                            .foregroundColor(.gray)

                        Divider()

                        NavigationLink(
                            destination: EventDetailView(
                                event: event,
                                isOwner: isOwner,
                                eventViewModel: eventViewModel
                            )
                        ) {
                            TodayEventRow(
                                event: event,
                                selectedDate: selectedDate,
                                isOwner: isOwner
                            )
                            .environmentObject(groupViewModel)
                        }
                    }
                }

                if events.count > 3 && !isTodayFullyExpanded {
                    Button {
                        withAnimation(.easeInOut) { isTodayFullyExpanded = true }
                    } label: {
                        Text("予定をすべて見る")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                    }
                }

                if isTodayFullyExpanded {
                    ForEach(remaining) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatEventTime(event.date))
                                .font(.caption)
                                .foregroundColor(.gray)

                            Divider()

                            NavigationLink(
                                destination: EventDetailView(
                                    event: event,
                                    isOwner: isOwner,
                                    eventViewModel: eventViewModel
                                )
                            ) {
                                TodayEventRow(
                                    event: event,
                                    selectedDate: selectedDate,
                                    isOwner: isOwner
                                )
                                .environmentObject(groupViewModel)
                            }
                        }
                    }

                    Divider()

                    Text("閉じる")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                        .onTapGesture {
                            withAnimation(.easeInOut) { isTodayFullyExpanded = false }
                        }
                }
            }

        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 1.0, green: 0.96, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - カレンダー（凡例修正済み）
    private var calendarSection: some View {
        VStack(spacing: 0) {

            HStack {
                Button(action: { moveMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }

                Spacer()

                Text(currentMonthJP)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { moveMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            FSCalendarView(
                selectedDate: $selectedDate,
                events: filteredEvents,
                isOwner: isOwner,
                onDoubleTapDate: { date in
                    tappedDateForAdd = date
                    showAddOption = true
                },
                onMonthChanged: { newMonth in
                    selectedDate = newMonth
                }
            )
            .id("calendar-\(selectedGroup?.id ?? "none")")
            .frame(height: 260)
            .padding(.horizontal, 12)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    legendDot(color: .systemRed, text: "ライブ・イベント")
                    legendDot(color: .systemBlue, text: "リリース")
                    legendDot(color: .systemGreen, text: "出演・放送・配信")
                }
                HStack(spacing: 12) {
                    legendDot(color: .systemOrange, text: "SNS")
                    legendDot(color: .systemPurple, text: "記念日")
                    legendDot(color: .systemGray, text: "その他")
                }
            }
            .font(.caption2)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 1.0, green: 0.96, blue: 0.99)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - 月移動
    private func moveMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    // MARK: - 月表示
    var currentMonthJP: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: selectedDate)
    }

    private func formatEventTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    func deleteGroup(_ group: IdolGroup) {
        groupViewModel.deleteGroup(group)
        if selectedGroup?.id == group.id {
            selectedGroup = groupViewModel.groups.first
        }
    }

    // MARK: - 次のイベント
    var nextEventForSelectedGroup: Event? {
        guard let group = selectedGroup else { return nil }
        let now = Date()

        let allEvents: [Event] = Array(eventViewModel.events)

        return allEvents
            .filter { event in
                guard event.groupId == group.id,
                      event.isSecret == false else { return false }

                let start = event.startDate ?? event.date
                return start >= now
            }
            .sorted { lhs, rhs in
                let l = lhs.startDate ?? lhs.date
                let r = rhs.startDate ?? rhs.date
                return l < r
            }
            .first
    }

    // MARK: - グループのイベント一覧
    var filteredEvents: [Event] {
        guard let group = selectedGroup else { return [] }
        return Array(eventViewModel.events).filter { $0.groupId == group.id }
    }

    // MARK: - 選択日のイベント
    var eventsForSelectedDate: [Event] {
        filteredEvents.filter { event in
            if let s = event.startDate, let e = event.endDate {
                if s > e {
                    print("⚠️ Warning: Invalid date range detected → startDate > endDate")
                    return false
                }
                return (s...e).contains(selectedDate)
            } else {
                return Calendar.current.isDate(event.date, inSameDayAs: selectedDate)
            }
        }
    }

    var selectedDateJP: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d（E）"
        return formatter.string(from: selectedDate)
    }

    @ViewBuilder
    func legendDot(color: UIColor, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(color))
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    // MARK: - グループ切り替え処理
    func switchToGroup(_ group: IdolGroup) {
        selectedGroup = group

        withAnimation(.easeInOut(duration: 0.25)) {
            switchAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.25)) {
                switchAnimation = false
            }
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showSwitchBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
                showSwitchBanner = false
            }
        }
    }

    private var switchBanner: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {

                if let data = selectedGroup?.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }

                Text("\(selectedGroup?.name ?? "") に切り替えました")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Color.gray.opacity(0.85)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
