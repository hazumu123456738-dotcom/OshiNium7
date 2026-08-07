//
//  SettingsSelectionViews.swift
//  OshiNium7
//

import SwiftUI

// ★ 設定画面の各項目は、必ず「タップ→専用の選択画面へ遷移→そこで選ぶ」という統一された
//   導線にする（設定一覧側の行の高さを、選択肢の数や長さに関わらず必ず揃えるため）。
//   3つとも同じ「単一選択・チェックマーク表示」の構造なので、それぞれ薄いラッパーにする

struct CommentPermissionSettingView: View {
    @ObservedObject var settingsVM: UserSettingsViewModel

    var body: some View {
        List {
            ForEach(CommentPermission.allCases, id: \.self) { permission in
                Button {
                    settingsVM.settings.commentPermission = permission
                    settingsVM.saveSettings()
                } label: {
                    HStack {
                        Text(permission.label)
                            .foregroundColor(.primary)
                        Spacer()
                        if settingsVM.settings.commentPermission == permission {
                            Image(systemName: "checkmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("コメント許可")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DMPermissionSettingView: View {
    @ObservedObject var settingsVM: UserSettingsViewModel

    var body: some View {
        List {
            ForEach(DMPermission.allCases, id: \.self) { permission in
                Button {
                    settingsVM.settings.dmPermission = permission
                    settingsVM.saveSettings()
                } label: {
                    HStack {
                        Text(permission.label)
                            .foregroundColor(.primary)
                        Spacer()
                        if settingsVM.settings.dmPermission == permission {
                            Image(systemName: "checkmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("メッセージ受信設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppThemeSettingView: View {
    @Binding var themeMode: AppThemeMode

    var body: some View {
        List {
            ForEach(AppThemeMode.allCases) { mode in
                Button {
                    themeMode = mode
                } label: {
                    HStack {
                        Text(mode.label)
                            .foregroundColor(.primary)
                        Spacer()
                        if themeMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("テーマ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
