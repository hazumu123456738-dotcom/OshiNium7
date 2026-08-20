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
    @EnvironmentObject var navState: AppNavigationState
    // ★ HomeViewと同じ共有インスタンス(OshiNium7App)を使う。以前はここで独自にCalendarViewModel()を
    //   保持しており、HomeView側のインスタンスと常時二重にFirestoreリスナーが稼働していた
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @StateObject private var diaryViewModel = MemoryDiaryViewModel()

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
    // ★ カレンダーを切り替えたことが一目でわかるよう、切り替え先の名前を添えたトーストを出す
    @State private var switchedCalendarToast: String? = nil

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
                        defaultDate: tappedDateForAdd ?? selectedDate,
                        calendarId: (selectedCalendar?.isCommunity ?? true) ? nil : selectedCalendar?.id
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
                    defaultDate: tappedDateForAdd ?? selectedDate,
                    calendarId: (selectedCalendar?.isCommunity ?? true) ? nil : selectedCalendar?.id
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            }
            .navigationDestination(isPresented: $showManualAdd) {
                if let group = selectedGroup {
                    AddEventView(
                        selectedGroup: group,
                        defaultDate: tappedDateForAdd ?? selectedDate,
                        // ★ 今このタブで見ているカレンダーへそのまま保存する
                        //   （コミュニティカレンダーを見ている時はnilのままでよい）
                        calendarId: (selectedCalendar?.isCommunity ?? true) ? nil : selectedCalendar?.id
                    )
                    .environmentObject(eventViewModel)
                    .environmentObject(settingsVM)
                } else {
                    Text("グループが選択されていません")
                }
            }
            }
            .overlay(alignment: .top) {
                if let switchedCalendarToast {
                    Text(switchedCalendarToast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.82)))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                    let name = calendar.isCommunity ? "コミュニティカレンダー" : calendar.name
                    withAnimation(.easeInOut(duration: 0.2)) {
                        switchedCalendarToast = "「\(name)」に切り替えました"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            switchedCalendarToast = nil
                        }
                    }
                }
            }
        }
        .onAppear {
            startCalendarListeningIfNeeded()
            if let uid = Auth.auth().currentUser?.uid {
                diaryViewModel.startListening(uid: uid)
            }
            // ★ calendarViewModelはHomeViewと共有しているインスタンスのため、このタブが
            //   初めて表示される時点で既にcalendarViewModel.calendarsが読み込み済み（空でない）
            //   ことがある。selectedCalendarの初期化を.onChange(of: calendarViewModel.calendars)
            //   だけに任せていると、「読み込み完了→この画面が現れる」の順で起きた場合に
            //   onChangeが変化を検知できず（既に確定した値のまま変化しない）、selectedCalendarが
            //   nilのまま固定されてしまっていた。filteredEvents/eventsForDayはselectedCalendarが
            //   nilの間、カレンダー種別・承認状態を問わず予定を素通しする安全側に倒していない
            //   フォールバックになっており、これがプライベートの予定がコミュニティ表示に
            //   紛れ込む・削除済みの予定が消えない不具合の直接の原因だった。
            //   onAppear時点でも同じ初期化を試みることで、どちらの順序でも必ず解決する
            resolveSelectedCalendarIfNeeded(calendarViewModel.calendars)
        }
        .onChange(of: selectedGroup) { _, _ in
            startCalendarListeningIfNeeded()
        }
        .onChange(of: calendarViewModel.calendars) { _, calendars in
            resolveSelectedCalendarIfNeeded(calendars)
        }
        .onChange(of: selectedCalendar) { _, newValue in
            navState.lastSelectedCalendarId = newValue?.id
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
                groupId: selectedGroup?.id,
                groupName: selectedGroup?.name,
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

    // ★ 選択中カレンダーが無くなった/未選択の場合、まずnavState.lastSelectedCalendarId
    //   （予定の追加・削除でこのタブが作り直される直前まで見ていたカレンダー）への復帰を
    //   試み、それも見つからなければコミュニティカレンダーを既定選択にする。
    //   onAppearとonChange(of: calendarViewModel.calendars)の両方から呼ぶことで、
    //   「カレンダー読み込み→このタブが現れる」「このタブが現れる→カレンダー読み込み」
    //   どちらの順序で起きてもselectedCalendarが必ず初期化されるようにする
    private func resolveSelectedCalendarIfNeeded(_ calendars: [OshiCalendar]) {
        guard selectedCalendar == nil || !calendars.contains(where: { $0.id == selectedCalendar?.id }) else { return }
        if let lastId = navState.lastSelectedCalendarId,
           let restored = calendars.first(where: { $0.id == lastId }) {
            selectedCalendar = restored
        } else {
            selectedCalendar = calendars.first(where: { $0.isCommunity })
        }
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
                            .foregroundColor(Color.oshiniumPrimary)
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
                        .foregroundColor(Color.oshiniumPrimary)
                }
                .accessibilityLabel("予定を追加")

                Button {
                    showCalendarManageMenu = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray.opacity(0.6))
                        if pendingApprovalCount > 0 {
                            Circle()
                                .fill(Color.oshiniumPrimary)
                                .frame(width: 9, height: 9)
                                .offset(x: 3, y: -2)
                        }
                    }
                }
                .accessibilityLabel(pendingApprovalCount > 0 ? "カレンダーの管理メニュー、承認待ちの予定が\(pendingApprovalCount)件あります" : "カレンダーの管理メニュー")
            }
            .padding(.top, -4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // ★ 2026/08/15修正：総件数ではなく「未確認件数」を出す(EventViewModel.unseenPendingApprovalCount参照)
    private var pendingApprovalCount: Int {
        guard let groupId = selectedGroup?.id else { return 0 }
        return eventViewModel.unseenPendingApprovalCount(groupId: groupId)
    }

    private func monthTitle(_ date: Date) -> String {
        return CachedFormatters.date(format: "yyyy年 M月").string(from: date)
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
