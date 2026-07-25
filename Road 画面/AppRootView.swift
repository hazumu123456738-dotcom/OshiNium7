//
//  AppRootView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/04.
//

import SwiftUI
import FirebaseAuth

struct AppRootView: View {

    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @Binding var showAddEvent: Bool
    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    @State private var showSplash = true

    @AppStorage("hasSelectedGroup") private var hasSelectedGroup = false
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                if showSplash {
                    SplashView()

                } else {

                    if auth.user == nil {
                        LoginView()

                    } else if !hasSelectedGroup {
                        GroupSelectView {
                            hasSelectedGroup = true
                        }
                        .onAppear {
                            groupViewModel.startListening()
                        }

                    } else {
                        OshiNiumTabView(
                            showAddEvent: $showAddEvent,
                            selectedGroup: $selectedGroup,
                            selectedDate: $selectedDate
                        )
                        .onAppear {
                            groupViewModel.startListening()
                        }
                    }
                }
            }
        }

        // MARK: - AddEventView（全画面表示）
        .fullScreenCover(isPresented: $showAddEvent) {
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

        .onAppear {
            runSplash()
            eventViewModel.startListeners()
        }
    }

    // MARK: - スプラッシュ処理
    private func runSplash() {
        if isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSplash = false
                isFirstLaunch = false
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSplash = false
        }
    }
}
