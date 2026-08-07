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
    @StateObject var savedPostViewModel = SavedPostViewModel()
    @StateObject var followViewModel = FollowViewModel()
    @StateObject var notificationViewModel = AppNotificationViewModel()
    // ★ AppDelegate（UIKit）がプッシュ通知タップ時にAppNavigationState.sharedへ直接書き込むため、
    //   ここでも同じシングルトンインスタンスを使う（別インスタンスだとAppDelegate側の変更が
    //   SwiftUI側のEnvironmentObjectに反映されない）
    @StateObject var navState = AppNavigationState.shared
    @StateObject var networkMonitor = NetworkMonitor()

    // ★ AppRootView に渡すための状態（既存）
    @State private var showAddEvent = false
    @State private var selectedGroup: IdolGroup? = nil
    @State private var selectedDate = Date()

    // ★ 設定画面「🎨 アプリ」のテーマ切り替え。デバイス単位の見た目設定
    @AppStorage(AppThemeMode.storageKey) private var themeModeRaw = AppThemeMode.system.rawValue
    private var themeMode: AppThemeMode { AppThemeMode(rawValue: themeModeRaw) ?? .system }

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
            .environmentObject(savedPostViewModel)
            .environmentObject(followViewModel)
            .environmentObject(notificationViewModel)
            .environmentObject(navState)
            .environmentObject(networkMonitor)
            .preferredColorScheme(themeMode.colorScheme)
        }
    }
}
