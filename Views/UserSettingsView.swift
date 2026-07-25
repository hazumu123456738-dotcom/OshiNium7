//
//  UserSettingsView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/26.
//

import SwiftUI

struct UserSettingsView: View {
    @StateObject var viewModel = UserSettingsViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            // MARK: - プロフィール
            Section(header: Text("プロフィール")) {
                TextField("名前", text: $viewModel.settings.displayName)
                TextField("自己紹介", text: $viewModel.settings.bio)
                TextField("アイコン画像URL", text: $viewModel.settings.iconURL)

                // 誕生日：ダイアル式＋日本語ロケール
                DatePicker(
                    "誕生日",
                    selection: Binding(
                        get: { dateFromString(viewModel.settings.birthday) },
                        set: { viewModel.settings.birthday = stringFromDate($0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "ja_JP"))
            }

            // MARK: - SNSリンク
            Section(header: Text("SNSリンク")) {
                ForEach(0..<viewModel.settings.snsLinks.count, id: \.self) { index in
                    TextField("リンク", text: $viewModel.settings.snsLinks[index])
                }

                Button("リンクを追加") {
                    viewModel.settings.snsLinks.append("")
                }
            }

            // MARK: - 保存ボタン
            Button("保存") {
                viewModel.saveSettings()
                dismiss()   // 保存後にホームへ戻る
            }
            .foregroundColor(.blue)
        }
        .navigationTitle("ユーザー設定")
        .onAppear {
            viewModel.loadSettings()
        }
    }

    // MARK: - 文字列 ⇄ 日付 変換
    func dateFromString(_ str: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str) ?? Date()
    }

    func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
