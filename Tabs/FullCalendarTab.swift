//
//  FullCalendarTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/24.
//

import SwiftUI
import FirebaseAuth

// ★ 日付長押し→思い出日記フロー。date+isPresentedの2状態を分けて持つと
//   同じ画面に多数積んでいる.sheet群の中で反映タイミングがずれて空の
//   シートが出ることがあったため、単一のIdentifiableな値にまとめている
//   （invitingCalendar/editingCalendarと同じ.sheet(item:)パターン）
private struct DiaryComposerRequest: Identifiable {
    let id = UUID()
    let date: Date
}

struct FullCalendarTab: View {

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var diaryViewModel = MemoryDiaryViewModel()
    // ★ Color.themedAccentはThemeManager.shared.activeTheme(着せ替え画面のプレビュー中は
    //   ドラフトの一時的な上書き値)を直接参照する。この@ObservedObjectが無いと、
    //   テーマが変わってもSwiftUIがこの画面の再描画タイミングを知る手段が無く、
    //   色が古いまま固まってしまう
    @ObservedObject private var themeManager = ThemeManager.shared

    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    // ★ イベント遷移用の NavigationPath をここで一元管理
    @State private var navigationPath = NavigationPath()

    @State private var currentIndex: Int = 12
    private let months: [Date] = generateMonths()

    @State private var selectedCalendar: OshiCalendar?
    @State private var showNewCalendar = false
    @State private var editingCalendar: OshiCalendar?
    @State private var invitingCalendar: OshiCalendar?

    // ★ 日付長押し→予定追加フロー（HomeViewと同じ構成）
    @State private var showAddOption = false
    @State private var showAIAdd = false
    @State private var showURLAdd = false
    @State private var showManualAdd = false
    @State private var tappedDateForAdd: Date? = nil

    // ★ 日付長押し→思い出日記フロー
    @State private var diaryComposerRequest: DiaryComposerRequest? = nil

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
                    },
                    onRequestInvite: { calendar in
                        invitingCalendar = calendar
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
                            },
                            onRequestDiary: { date in
                                diaryComposerRequest = DiaryComposerRequest(date: date)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // ★ TabViewに明示的にmaxHeightを与えて残りの領域ぴったりに収める。
                //   これが無いと、自作の下タブバー分だけ減った本当の表示可能領域より
                //   VStack全体が大きく育ってしまい、最終週がタブバーの裏に隠れて
                //   見切れてしまっていた。以前はここに「＋ボタン専用の余白」も
                //   確保していたが、それが今度は「カレンダーの下に不自然な空白がある」
                //   という見た目の問題になっていた。＋ボタンをヘッダーのアイコンに
                //   移したことでこの余白が不要になり、カレンダーが全高をそのまま使える
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            .oshiniumThemeDecoration()
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
            .navigationDestination(isPresented: $showURLAdd) {
                URLEventImportView(
                    selectedGroup: selectedGroup,
                    defaultDate: tappedDateForAdd ?? selectedDate
                )
                .environmentObject(eventViewModel)
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
        }
        .sheet(isPresented: $showAddOption) {
            AddMethodSelectView(
                onSelectAI: { showAIAdd = true },
                onSelectURL: { showURLAdd = true },
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
            if let uid = Auth.auth().currentUser?.uid {
                diaryViewModel.startListening(uid: uid)
            }
        }
        .onChange(of: selectedGroup) { _, _ in
            startCalendarListeningIfNeeded()
        }
        .onChange(of: calendarViewModel.calendars) { _, calendars in
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
        .sheet(item: $invitingCalendar) { calendar in
            CalendarInviteView(calendar: calendar, calendarViewModel: calendarViewModel)
        }
        .sheet(item: $diaryComposerRequest) { request in
            if let group = selectedGroup {
                MemoryDiaryComposerView(date: request.date, group: group, diaryViewModel: diaryViewModel)
            }
        }
        .sheet(isPresented: $showCalendarManageMenu) {
            CalendarManageMenuView(
                calendarViewModel: calendarViewModel,
                eventViewModel: eventViewModel,
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
                            .foregroundColor(Color.themedAccent)
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
                        Text(selectedCalendar?.name ?? "")
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
            // ★ 以前は右下に浮かせた円形の＋ボタンだったが、6週分ある月の最終週と
            //   重なってしまう問題があった。ヘッダーのアイコンに統合することで、
            //   カレンダー本体はスペースを一切犠牲にせず全高を使えるようにする
            HStack(spacing: 14) {
                Button {
                    tappedDateForAdd = selectedDate
                    showAddOption = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.themedAccent)
                }
                .accessibilityLabel("予定を追加")

                Button {
                    showCalendarManageMenu = true
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .accessibilityLabel("カレンダーの管理メニュー")
            }
            .padding(.top, -4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
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
