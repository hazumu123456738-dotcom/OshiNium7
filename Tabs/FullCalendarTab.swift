//
//  FullCalendarTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/24.
//

import SwiftUI
import FirebaseAuth

struct FullCalendarTab: View {

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @StateObject private var calendarViewModel = CalendarViewModel()
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    // ★ イベント遷移用の NavigationPath をここで一元管理
    @State private var navigationPath = NavigationPath()

    @State private var currentIndex: Int = 12
    private let months: [Date] = generateMonths()

    @State private var selectedCalendar: OshiCalendar?
    @State private var showNewCalendar = false
    @State private var editingCalendar: OshiCalendar?

    // ★ 日付長押し→予定追加フロー（HomeViewと同じ構成）
    @State private var showAddOption = false
    @State private var showAIAdd = false
    @State private var showManualAdd = false
    @State private var tappedDateForAdd: Date? = nil

    // ★ カレンダー切り替え確認（HomeViewのグループ切り替え確認と同じ構成）
    @State private var pendingCalendar: OshiCalendar? = nil
    @State private var showCalendarSwitchAlert = false

    // ★ カレンダータブ右上の「…」から開く管理メニュー。今はカレンダー削除だけだが、
    //   今後カレンダーまわりの細かい機能を足していく集約先として用意する
    @State private var showCalendarManageMenu = false

    var body: some View {

        NavigationStack(path: $navigationPath) {

            ZStack(alignment: .bottomTrailing) {

            VStack(spacing: 0) {

                header

                CalendarSwitcherRow(
                    calendars: calendarViewModel.calendars,
                    selectedCalendar: selectedCalendar,
                    onSelect: { calendar in
                        guard calendar.id != selectedCalendar?.id else { return }
                        pendingCalendar = calendar
                        showCalendarSwitchAlert = true
                    },
                    onAdd: {
                        showNewCalendar = true
                    },
                    onRequestEdit: { calendar in
                        editingCalendar = calendar
                    }
                )
                .padding(.bottom, 4)

                TabView(selection: $currentIndex) {
                    ForEach(0..<months.count, id: \.self) { index in
                        MonthlyCalendarView(
                            month: months[index],
                            eventsByDate: eventViewModel.eventsByDate,
                            selectedCalendar: selectedCalendar,
                            communityCalendarId: calendarViewModel.calendars.first(where: { $0.isCommunity })?.id,
                            selectedGroup: $selectedGroup,
                            selectedDate: $selectedDate,
                            // ★ ここで「イベントが選ばれたときの遷移」を親に渡す
                            onSelectEvent: { event in
                                // 常に「イベント詳細だけ」を乗せるようにする
                                navigationPath = NavigationPath()
                                navigationPath.append(event)
                            },
                            onRequestAddEvent: { date in
                                tappedDateForAdd = date
                                showAddOption = true
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // ★ TabViewに明示的にmaxHeightを与えて残りの領域ぴったりに収める。
                //   これが無いと、自作の下タブバー分だけ減った本当の表示可能領域より
                //   VStack全体が大きく育ってしまい、＋ボタンや最終週がタブバーの裏に
                //   隠れて見切れてしまっていた
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            .background(Color.appBackground)
            // ★ EventDetailView への遷移はここで一元管理
            .navigationDestination(for: Event.self) { event in
                EventDetailView(
                    event: event,
                    isOwner: true,
                    eventViewModel: eventViewModel
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
            addEventButton

            }
        }
        .sheet(isPresented: $showAddOption) {
            AddMethodSelectView(
                onSelectAI: { showAIAdd = true },
                onSelectManual: { showManualAdd = true }
            )
        }
        .alert(
            "「\(pendingCalendar?.isCommunity == true ? "コミュニティカレンダー" : pendingCalendar?.name ?? "")」に切り替えますか？",
            isPresented: $showCalendarSwitchAlert
        ) {
            Button("キャンセル", role: .cancel) {}
            Button("はい") {
                if let calendar = pendingCalendar {
                    selectedCalendar = calendar
                }
            }
        }
        .onAppear {
            startCalendarListeningIfNeeded()
        }
        .onChange(of: selectedGroup) { _ in
            startCalendarListeningIfNeeded()
        }
        .onChange(of: calendarViewModel.calendars) { calendars in
            // 選択中カレンダーが無くなった/未選択ならコミュニティカレンダーを既定選択にする
            if selectedCalendar == nil || !calendars.contains(where: { $0.id == selectedCalendar?.id }) {
                selectedCalendar = calendars.first(where: { $0.isCommunity })
            }
        }
        .sheet(isPresented: $showNewCalendar) {
            if let group = selectedGroup, let uid = Auth.auth().currentUser?.uid {
                NewCalendarView(
                    groupId: group.id,
                    ownerId: uid,
                    calendarViewModel: calendarViewModel,
                    onCreated: { calendar in
                        selectedCalendar = calendar
                    }
                )
            }
        }
        .sheet(item: $editingCalendar) { calendar in
            CalendarEditView(
                calendar: calendar,
                calendarViewModel: calendarViewModel,
                onDeleted: {
                    if selectedCalendar?.id == calendar.id {
                        selectedCalendar = calendarViewModel.calendars.first(where: { $0.isCommunity })
                    }
                },
                onUpdated: { updated in
                    if selectedCalendar?.id == updated.id {
                        selectedCalendar = updated
                    }
                }
            )
        }
        .sheet(isPresented: $showCalendarManageMenu) {
            CalendarManageMenuView(
                calendarViewModel: calendarViewModel,
                onDeleted: { deleted in
                    if selectedCalendar?.id == deleted.id {
                        selectedCalendar = calendarViewModel.calendars.first(where: { $0.isCommunity })
                    }
                }
            )
        }
    }

    private func startCalendarListeningIfNeeded() {
        guard let group = selectedGroup, let uid = Auth.auth().currentUser?.uid else {
            calendarViewModel.stopListening()
            return
        }
        calendarViewModel.startListening(groupId: group.id, groupName: group.name, currentUid: uid)
    }

    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.85, blue: 0.45),
            Color(red: 0.80, green: 0.62, blue: 0.18)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {

            VStack(alignment: .leading, spacing: 6) {

                // ★ 今どのグループのカレンダーを見ているのか一目でわかるように見出しを出す
                //   ★ カレンダー本体の表示領域をなるべく広く取れるよう、見出し・アイコンは
                //     控えめなサイズにする
                if let selectedGroup {
                    HStack(spacing: 5) {
                        GroupIcon(group: selectedGroup, isSelected: false, size: 14)
                        Text(selectedGroup.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.70, green: 0.55, blue: 0.98))
                    }
                }

                Text(monthTitle(months[currentIndex]))
                    .font(.system(size: 18, weight: .semibold))

                if selectedCalendar?.isCommunity ?? true {
                    // ★ コミュニティカレンダーはひと目でわかる豪華なゴールドバッジ
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .accessibilityHidden(true)
                        Text("コミュニティカレンダー（グループ全員で共有）")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(goldGradient))
                    .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.4), radius: 6, y: 2)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(selectedCalendar!.name)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ★ カレンダーまわりの細かい機能（今はカレンダー削除のみ）をまとめる集約先。
            //   今後増える管理系の機能はここから辿れるようにしていく
            // ★ 「上に上げて」の指示で、テキスト列の1行目（グループ名）よりさらに上、
            //   ヘッダーの一番上の縁に揃うようにする
            Button {
                showCalendarManageMenu = true
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.top, -4)
            .accessibilityLabel("カレンダーの管理メニュー")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: - 予定追加ボタン（カレンダー右下）
    private var addEventButton: some View {
        Button {
            tappedDateForAdd = selectedDate
            showAddOption = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .accessibilityLabel("予定を追加")
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.70, green: 0.55, blue: 0.98),
                            Color(red: 0.90, green: 0.60, blue: 0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color(red: 0.70, green: 0.55, blue: 0.98).opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        // ★ このNavigationStackは自作の下タブバー分の安全域を引き継がないため、
        //   環境値で受け取ったタブバーの高さを明示的に足して、タブバーの裏に
        //   隠れないようにする
        .padding(.bottom, 24 + customTabBarHeight)
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
