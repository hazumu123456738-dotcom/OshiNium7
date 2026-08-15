//
//  AppIconSettingView.swift
//  OshiNium7
//

import SwiftUI
import UIKit

// ★ マイページの設定画面(MyPageManageMenuView)「アプリ」セクションから開く、
//   アプリアイコンの切り替え専用画面。ポイント交換で入手済みのアイコンはいつでも
//   無料で切り替えられる(themeManager.applyTheme(_:)がsetAlternateIconNameを呼ぶ)。
//   未入手のアイコンもここに一覧表示し、そのままポイント交換できるようにする
struct AppIconSettingView: View {
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var unlockErrorMessage: String?
    @State private var unlockSuccessMessage: String?

    private var isDefaultIconActive: Bool {
        UIApplication.shared.alternateIconName == nil
    }

    var body: some View {
        List {
            Section {
                defaultIconRow
                ForEach(CustomTheme.curatedPresets) { theme in
                    iconRow(theme)
                }
            } footer: {
                Text("ポイント交換で入手されたアイコンは、こちらからいつでも無料で切り替えていただけます。")
            }
        }
        .navigationTitle("アプリアイコン")
        .navigationBarTitleDisplayMode(.inline)
        .alert("交換できませんでした", isPresented: Binding(
            get: { unlockErrorMessage != nil },
            set: { if !$0 { unlockErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { unlockErrorMessage = nil }
        } message: {
            Text(unlockErrorMessage ?? "")
        }
        .alert("交換しました", isPresented: Binding(
            get: { unlockSuccessMessage != nil },
            set: { if !$0 { unlockSuccessMessage = nil } }
        )) {
            Button("OK", role: .cancel) { unlockSuccessMessage = nil }
        } message: {
            Text(unlockSuccessMessage ?? "")
        }
    }

    private var defaultIconRow: some View {
        HStack(spacing: 14) {
            iconThumbnail(assetName: nil)

            VStack(alignment: .leading, spacing: 3) {
                Text("スタンダード")
                    .font(.system(size: 15, weight: .semibold))
                Text("最初から入っている標準のアイコン")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDefaultIconActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.oshiniumPrimary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDefaultIconActive else { return }
            themeManager.applyTheme(.default) { error in
                if let error { unlockErrorMessage = error.localizedDescription }
            }
        }
    }

    private func iconRow(_ theme: CustomTheme) -> some View {
        let isUnlocked = themeManager.isUnlocked(theme)
        let isActive = !isDefaultIconActive && themeManager.activeTheme.id == theme.id

        return HStack(spacing: 14) {
            iconThumbnail(assetName: ThemeManager.iconName(for: theme.id))

            VStack(alignment: .leading, spacing: 3) {
                Text(theme.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(isUnlocked ? "タップして適用" : "\(theme.pointCost)ptと交換")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.oshiniumPrimary)
            } else if !isUnlocked {
                Button {
                    unlock(theme)
                } label: {
                    Text("\(theme.pointCost)ptで交換")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.oshiniumPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isUnlocked, !isActive else { return }
            themeManager.applyTheme(theme) { error in
                if let error { unlockErrorMessage = error.localizedDescription }
            }
        }
    }

    private func iconThumbnail(assetName: String?) -> some View {
        Group {
            if let assetName, let uiImage = UIImage(named: assetName) {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                Image("AppIconThumbnail")
                    .resizable()
            }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func unlock(_ theme: CustomTheme) {
        themeManager.unlock(theme, settingsVM: settingsVM) { result in
            switch result {
            case .success(let remaining):
                unlockSuccessMessage = "「\(theme.name)」と交換しました。現在のポイントは\(remaining)ptです。"
            case .failure(let error):
                unlockErrorMessage = error.localizedDescription
            }
        }
    }
}
