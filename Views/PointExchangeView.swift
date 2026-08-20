//
//  PointExchangeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI
import UIKit

// ★ 貯めたポイントの交換画面。以前は「推し活占いで貯めた大吉ポイント」専用の名称・仕組みだったが、
//   予定追加・コミュニティ貢献・投稿・イベント参加など行動全般に対する共通の報酬へ拡張していく
//   前提のため、「大吉ポイント」→「ポイント」に名称を統一した(2026-08-08)。
//   ★ 2026-08-09: 交換景品を「自由に組み合わせて作るカスタマイズツール」から「こちらが用意した
//   完成済みのアイコンデザインから選ぶ」方式に変更。ダイア型のアプリアイコンだけを着せ替えられる
//   (ダイアの位置・形状は固定、色だけがテーマごとに変わる)。カスタマイズ編集画面
//   (ThemeCustomizationView)自体は削除せず残してあるが、この画面からは導線を外して一旦保留にした。
//   タブ画面・ウィジェットへのテーマ反映も同じ理由で保留(ThemedScreenDecoration/
//   SharedWidgetStoreのテーマ関連コードは残してあるので、再開時はThemeManager.applyTheme(_:)から
//   呼び出しを復活させ、各タブへ.oshiniumThemeDecoration()を戻すだけでよい)
struct PointExchangeView: View {
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var unlockErrorMessage: String?
    @State private var unlockSuccessMessage: String?

    // ★ この画面は独自タブバー(OshiNiumTabView)配下のNavigationStackからNavigationLinkで
    //   到達するため、下端のカスタムタブバーの高さ分を自分でパディングとして足さないと、
    //   一覧の最後の項目がタブバーの裏に隠れて全部見えなくなる(EventHubPickerViewと同じ理由)
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private let accentColor = Color(red: 0.95, green: 0.72, blue: 0.35)
    private let accentColor2 = Color(red: 0.95, green: 0.55, blue: 0.55)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                pointsCard
                iconGallerySection
            }
            .padding(20)
            .padding(.bottom, customTabBarHeight)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("ポイント交換")
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

    // MARK: - アプリアイコンの着せ替え

    private var iconGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アプリアイコンの着せ替え")
                .font(.system(size: 16, weight: .bold))
            Text("ダイアの色をテーマごとに変更できます。気に入ったデザインを選んでください。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                defaultIconRow
                ForEach(CustomTheme.curatedPresets) { theme in
                    iconRow(theme)
                }
            }
            .padding(.top, 4)
        }
    }

    private var isDefaultIconActive: Bool {
        UIApplication.shared.alternateIconName == nil
    }

    private var defaultIconRow: some View {
        HStack(spacing: 14) {
            iconThumbnail(assetName: nil)

            VStack(alignment: .leading, spacing: 3) {
                Text("スタンダード")
                    .font(.system(size: 15, weight: .bold))
                Text("最初から入っている標準のアイコン")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isDefaultIconActive {
                Text("適用中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.oshiniumPrimary)
            } else {
                Button("適用") {
                    themeManager.applyTheme(.default) { error in
                        if let error { unlockErrorMessage = error.localizedDescription }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    private func iconRow(_ theme: CustomTheme) -> some View {
        let isUnlocked = themeManager.isUnlocked(theme)
        let isActive = !isDefaultIconActive && themeManager.activeTheme.id == theme.id

        return HStack(spacing: 14) {
            iconThumbnail(assetName: ThemeManager.iconName(for: theme.id))

            VStack(alignment: .leading, spacing: 3) {
                Text(theme.name)
                    .font(.system(size: 15, weight: .bold))
                Text(isUnlocked ? "タップして適用" : "\(theme.pointCost)ptと交換")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isActive {
                Text("適用中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.oshiniumPrimary)
            } else if isUnlocked {
                Button("適用") {
                    themeManager.applyTheme(theme) { error in
                        if let error { unlockErrorMessage = error.localizedDescription }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
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
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // ★ 抽象的な色見本ではなく、実際に切り替わるアイコン画像そのものをサムネイルに使うことで、
    //   「どんな見た目になるか」が一目でわかるようにする(AppIcon-*@2x/3x.pngはOshiNium7/
    //   AlternateIconsに実体があり、アプリ本体と同じ.app直下にコピーされる)
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
