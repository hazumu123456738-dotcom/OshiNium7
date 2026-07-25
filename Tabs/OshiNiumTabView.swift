//
//  OshiNiumTabView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI

struct OshiNiumTabView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    // HomeView と同じ Binding（アプリ全体で共有される）
    @Binding var showAddEvent: Bool
    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    @State private var selectedTab: Tab = .home

    enum Tab {
        case home, calendar, ai, chat, mypage
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ホーム
            NavigationStack {
                HomeView(
                    selectedDate: $selectedDate,
                    selectedGroup: $selectedGroup,
                    showAddEvent: $showAddEvent
                )
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("ホーム")
            }
            .tag(Tab.home)

            // カレンダー（フル画面）
            NavigationStack {
                FullCalendarTab(
                    selectedGroup: $selectedGroup,
                    selectedDate: $selectedDate
                )
            }
            .tabItem {
                Image(systemName: "calendar")
                Text("カレンダー")
            }
            .tag(Tab.calendar)

            // AIタブ
            NavigationStack {
                AITab()
            }
            .tabItem {
                Image(systemName: "sparkles")
                Text("AI")
            }
            .tag(Tab.ai)

            // チャット
            NavigationStack {
                ChatTab()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("チャット")
            }
            .tag(Tab.chat)

            // マイページ
            NavigationStack {
                MyPageTab()
            }
            .tabItem {
                Image(systemName: "person.crop.circle.fill")
                Text("マイページ")
            }
            .tag(Tab.mypage)
        }
        .tint(.black)
    }
}
