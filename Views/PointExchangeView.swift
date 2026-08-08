//
//  PointExchangeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI

// ★ 貯めたポイントの交換画面。以前は「推し活占いで貯めた大吉ポイント」専用の名称・仕組みだったが、
//   予定追加・コミュニティ貢献・投稿・イベント参加など行動全般に対する共通の報酬へ拡張していく
//   前提のため、「大吉ポイント」→「ポイント」に名称を統一した(2026-08-08)。
//   交換景品第一弾は「着せ替えカスタマイズ」(ThemeCustomizationView)。カスタマイズツール自体は
//   誰でも無料で使える入口として案内し、ポイントが必要なのは限定テーマ(CustomTheme.curatedPresetsの
//   isBuiltIn==true)の解放だけ、という構成をこの画面でそのまま表現する
struct PointExchangeView: View {
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var showThemeCustomization = false
    @State private var unlockErrorMessage: String?
    @State private var unlockSuccessMessage: String?

    private let accentColor = Color(red: 0.95, green: 0.72, blue: 0.35)
    private let accentColor2 = Color(red: 0.95, green: 0.55, blue: 0.55)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                pointsCard
                themeEntryCard
                limitedThemesSection
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("ポイント交換")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showThemeCustomization) {
            ThemeCustomizationView()
                .environmentObject(settingsVM)
        }
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

    private var pointsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "seal.fill")
                .font(.system(size: 26))
                .foregroundColor(.white)
                .accessibilityHidden(true)
            Text("\(settingsVM.settings.points) pt")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)
            Text("推し活占いや予定の追加など、アプリ内の活動で貯まります")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accentColor.opacity(0.35), radius: 16, x: 0, y: 8)
        )
        .accessibilityElement(children: .combine)
    }

    private var themeEntryCard: some View {
        Button {
            showThemeCustomization = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [themeManager.activeTheme.baseColor.color, themeManager.activeTheme.accentColor.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: themeManager.activeTheme.icon.systemImage)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("着せ替えカスタマイズ")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text("誰でも無料で使えます。今の適用中：\(themeManager.activeTheme.name)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private var limitedThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ポイント限定テーマ")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(CustomTheme.curatedPresets.filter { $0.isBuiltIn }) { theme in
                    limitedThemeRow(theme)
                }
            }
        }
    }

    private func limitedThemeRow(_ theme: CustomTheme) -> some View {
        let isUnlocked = themeManager.isUnlocked(theme)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [theme.baseColor.color, theme.accentColor.color], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Image(systemName: theme.icon.systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(theme.name)
                    .font(.system(size: 15, weight: .bold))
                Text(isUnlocked ? "交換済み・カスタマイズ画面から選べます" : "\(theme.pointCost)ptと交換")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.oshiniumPrimary)
            } else {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
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
