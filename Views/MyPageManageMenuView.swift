//
//  MyPageManageMenuView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI

// ★ マイページ右上の「…」から開く管理メニュー。カレンダータブの管理メニューと同じ考え方で、
//   今はログアウトだけだが、今後マイページまわりの設定機能が増えたらここに行を足していく
struct MyPageManageMenuView: View {

    var onLogout: () -> Void

    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $settingsVM.settings.isPrivateAccount) {
                        Label("非公開アカウント", systemImage: "lock.fill")
                    }
                    .onChange(of: settingsVM.settings.isPrivateAccount) { _, _ in
                        settingsVM.saveSettings()
                    }
                } footer: {
                    Text("オンにすると、あなたをフォローしていない人には投稿が表示されなくなります。")
                }

                Section("法的情報") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Label("利用規約", systemImage: "doc.text")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("ログアウトしてよろしいですか？", isPresented: $showLogoutConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    dismiss()
                    onLogout()
                }
            }
        }
    }
}
