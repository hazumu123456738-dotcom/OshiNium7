//
//  OshiNium7App.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/20.
//

import SwiftUI
import FirebaseCore

@main
struct OshiNium7App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject var auth = AuthViewModel()
    @StateObject var eventViewModel = EventViewModel()
    @StateObject var groupViewModel = GroupViewModel()
    @StateObject var settingsVM = UserSettingsViewModel()
    @StateObject var postViewModel = PostViewModel()
    @StateObject var followViewModel = FollowViewModel()
    @StateObject var notificationViewModel = AppNotificationViewModel()
    @StateObject var navState = AppNavigationState()

    // ★ AppRootView に渡すための状態（既存）
    @State private var showAddEvent = false
    @State private var selectedGroup: IdolGroup? = nil
    @State private var selectedDate = Date()

    var body: some Scene {
        WindowGroup {
            AppRootView(
                showAddEvent: $showAddEvent,
                selectedGroup: $selectedGroup,
                selectedDate: $selectedDate
            )
            .environmentObject(auth)
            .environmentObject(eventViewModel)
            .environmentObject(groupViewModel)
            .environmentObject(settingsVM)
            .environmentObject(postViewModel)
            .environmentObject(followViewModel)
            .environmentObject(notificationViewModel)
            .environmentObject(navState)
        }
    }
}
