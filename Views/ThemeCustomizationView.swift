//
//  ThemeCustomizationView.swift
//  OshiNium7
//

import SwiftUI
import UIKit

// ★ ポイント交換景品第一弾「着せ替えカスタマイズ」の本体画面。7カテゴリ(ベースカラー・
//   アクセントカラー・背景・リボン/フレーム・アイコン・フォント・エフェクト)を自由に
//   組み合わせ、上のプレビューにリアルタイム反映する。保存すると自分だけのテーマとして
//   users/{uid}/customThemesに追加され、あとで切り替えられる。
//   ★ カスタマイズツール自体はポイント交換景品(PointExchangeView参照)。ここに来られる時点で
//   ツールは解放済みという前提。CustomTheme.curatedPresetsのうちisBuiltIn==trueの
//   「限定テーマ」だけ、さらに追加でポイント交換が必要
//   ★ 2026-08-08: 各カテゴリの選択肢を約3倍に拡張し、カスタムカラー(16進数+透明度)・
//   「カスタマイズ中/プレビュー」切り替え・リセット・ヘルプを追加(参考デザインに準拠)
struct ThemeCustomizationView: View {
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CustomTheme
    @State private var selectedCategory: Category = .baseColor
    @State private var showSaveSheet = false
    @State private var themeName = ""
    @State private var showMyThemesSheet = false
    @State private var showHelp = false
    @State private var isPreviewMode = false
    @State private var unlockErrorMessage: String?
    @State private var unlockSuccessMessage: String?

    // ★ プレビューに埋め込む実物のカレンダータブ用。メイン画面の選択状態とは独立させ、
    //   ここでの操作(タップ等)は.allowsHitTesting(false)で無効化している
    @State private var previewSelectedGroup: IdolGroup?
    @State private var previewSelectedDate = Date()

    init() {
        _draft = State(initialValue: ThemeManager.shared.activeTheme)
    }

    enum Category: String, CaseIterable, Identifiable {
        case baseColor, accentColor, background, ribbon, icon, font, effect
        var id: String { rawValue }

        var label: String {
            switch self {
            case .baseColor: return "ベースカラー"
            case .accentColor: return "アクセント"
            case .background: return "背景"
            case .ribbon: return "リボン・フレーム"
            case .icon: return "アイコン"
            case .font: return "フォント"
            case .effect: return "エフェクト"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Picker("", selection: $isPreviewMode) {
                        Text("カスタマイズ中").tag(false)
                        Text("プレビュー").tag(true)
                    }
                    .pickerStyle(.segmented)

                    previewCard

                    if isPreviewMode {
                        Text("実際のプレビューです。カスタマイズに戻って続きを調整できます。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        categoryList

                        swatchPicker
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.appCardBackground)
                                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                            )

                        savedThemesButton
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("着せ替えカスタマイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigation) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("着せ替えカスタマイズについて")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存する") {
                        themeName = ""
                        showSaveSheet = true
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if previewSelectedGroup == nil {
                    previewSelectedGroup = groupViewModel.groups.first
                }
                themeManager.setPreviewOverride(draft)
            }
            .onChange(of: draft) { _, newValue in
                themeManager.setPreviewOverride(newValue)
            }
            .onDisappear {
                themeManager.setPreviewOverride(nil)
            }
            .sheet(isPresented: $showSaveSheet) { saveSheet }
            .sheet(isPresented: $showMyThemesSheet) { myThemesSheet }
            .alert("着せ替えカスタマイズとは", isPresented: $showHelp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("ベースカラー・アクセント・背景・リボン・アイコン・フォント・エフェクトを自由に組み合わせて、自分だけのテーマを作れます。変更はすぐにプレビューへ反映され、「保存する」で名前を付けて保存・後から切り替えできます。一部の限定テーマだけポイント交換が必要です。")
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
    }

    // MARK: - プレビュー
    //   ★ 以前は簡略化したモックカードだったが、「実際どうなるか分かりづらい」というフィードバックを
    //   受け、本物のカレンダータブ(FullCalendarTab)をそのまま縮小表示するライブプレビューに変更した。
    //   draftをThemeManager.previewOverrideへ流し込むことで、FullCalendarTabが実際に参照している
    //   Color.themedAccent/themedBaseや.oshiniumThemeDecoration()がそのままプレビュー用にも働く

    private var previewCard: some View {
        GeometryReader { geo in
            let naturalWidth: CGFloat = 393
            let naturalHeight: CGFloat = 760
            let scale = geo.size.width / naturalWidth

            FullCalendarTab(selectedGroup: $previewSelectedGroup, selectedDate: $previewSelectedDate)
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
                .frame(width: naturalWidth, height: naturalHeight)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: naturalHeight * scale, alignment: .topLeading)
                .allowsHitTesting(false)
        }
        .frame(height: isPreviewMode ? 600 : 340)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .animation(.easeInOut(duration: 0.2), value: isPreviewMode)
    }

    // MARK: - カスタマイズ項目一覧

    private var categoryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("カスタマイズ項目")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation { draft = themeManager.activeTheme }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("リセット")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)

            ForEach(Category.allCases) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = category }
                } label: {
                    HStack {
                        Text(category.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        currentValueLabel(for: category)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedCategory == category ? .oshiniumPrimary : .secondary.opacity(0.4))
                            .rotationEffect(.degrees(selectedCategory == category ? 90 : 0))
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if category != Category.allCases.last {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    @ViewBuilder
    private func currentValueLabel(for category: Category) -> some View {
        switch category {
        case .baseColor: Text(draft.baseColor.label).font(.system(size: 13))
        case .accentColor: Text(draft.accentColor.label).font(.system(size: 13))
        case .background: Text(draft.background.label).font(.system(size: 13))
        case .ribbon: Text(draft.ribbon.label).font(.system(size: 13))
        case .icon: Text(draft.icon.label).font(.system(size: 13))
        case .font: Text(draft.font.label).font(.system(size: 13))
        case .effect: Text(draft.effect.label).font(.system(size: 13))
        }
    }

    // MARK: - 選択中カテゴリのスウォッチピッカー

    @ViewBuilder
    private var swatchPicker: some View {
        switch selectedCategory {
        case .baseColor:
            VStack(alignment: .leading, spacing: 18) {
                colorSwatches(selected: draft.baseColor, customHex: $draft.baseColorCustomHex) { draft.baseColor = $0 }
                opacitySlider
            }
        case .accentColor:
            colorSwatches(selected: draft.accentColor, customHex: $draft.accentColorCustomHex) { draft.accentColor = $0 }
        case .background:
            optionSwatches(ThemeBackgroundStyle.allCases, selected: draft.background, icon: \.icon, label: \.label) { draft.background = $0 }
        case .ribbon:
            optionSwatches(ThemeRibbonStyle.allCases, selected: draft.ribbon, icon: \.icon, label: \.label) { draft.ribbon = $0 }
        case .icon:
            optionSwatches(ThemeIconAccent.allCases, selected: draft.icon, icon: \.systemImage, label: \.label) { draft.icon = $0 }
        case .font:
            fontSwatches
        case .effect:
            optionSwatches(ThemeEffectStyle.allCases, selected: draft.effect, icon: \.icon, label: \.label) { draft.effect = $0 }
        }
    }

    private var opacitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("透明度")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(draft.colorOpacity * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.oshiniumPrimary)
            }
            Slider(value: $draft.colorOpacity, in: 0.2...1.0)
                .tint(.oshiniumPrimary)
        }
    }

    private func colorSwatches(selected: ThemeColorOption, customHex: Binding<String?>, onSelect: @escaping (ThemeColorOption) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(ThemeColorOption.allCases) { option in
                        Button {
                            onSelect(option)
                            if option == .custom, customHex.wrappedValue == nil {
                                customHex.wrappedValue = "9B8CF2"
                            }
                        } label: {
                            VStack(spacing: 6) {
                                colorSwatchCircle(option: option, customHex: customHex.wrappedValue, isSelected: option == selected)
                                Text(option.label)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            if selected == .custom {
                ColorPicker(selection: Binding(
                    get: { Color(hex: customHex.wrappedValue ?? "9B8CF2") },
                    set: { customHex.wrappedValue = $0.toHexString() }
                ), supportsOpacity: false) {
                    Text("カラーを選択")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }

    private func colorSwatchCircle(option: ThemeColorOption, customHex: String?, isSelected: Bool) -> some View {
        Group {
            if option == .custom {
                Circle().fill(
                    AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center)
                )
            } else {
                Circle().fill(option.color)
            }
        }
        .frame(width: 44, height: 44)
        .overlay(
            Circle().strokeBorder(Color.oshiniumPrimary, lineWidth: isSelected ? 2.5 : 0)
                .padding(-3)
        )
        .overlay(
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(option == .white || option == .mint || option == .yellow ? .black.opacity(0.6) : .white)
                .opacity(isSelected ? 1 : 0)
        )
    }

    private func optionSwatches<T: Identifiable & Equatable>(
        _ options: [T], selected: T, icon: KeyPath<T, String>, label: KeyPath<T, String>, onSelect: @escaping (T) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(options) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(option[keyPath: label] == selected[keyPath: label] ? Color.oshiniumPrimary.opacity(0.18) : Color.appBackground)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle().strokeBorder(Color.oshiniumPrimary, lineWidth: option[keyPath: label] == selected[keyPath: label] ? 2 : 0.5)
                                    )
                                Image(systemName: option[keyPath: icon])
                                    .font(.system(size: 16))
                                    .foregroundColor(option[keyPath: label] == selected[keyPath: label] ? .oshiniumPrimary : .secondary)
                            }
                            Text(option[keyPath: label])
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 66)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var fontSwatches: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(ThemeFontStyle.allCases) { option in
                    Button {
                        draft.font = option
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(option == draft.font ? Color.oshiniumPrimary.opacity(0.18) : Color.appBackground)
                                    .frame(width: 48, height: 48)
                                    .overlay(Circle().strokeBorder(Color.oshiniumPrimary, lineWidth: option == draft.font ? 2 : 0.5))
                                Text("あぁ")
                                    .font(.system(size: 15, weight: option.weight, design: option.design))
                                    .foregroundColor(option == draft.font ? .oshiniumPrimary : .secondary)
                            }
                            Text(option.label)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 保存済みテーマ・限定テーマ

    private var savedThemesButton: some View {
        Button {
            showMyThemesSheet = true
        } label: {
            HStack {
                Image(systemName: "square.stack.fill")
                Text("保存したテーマ・限定テーマを見る")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.oshiniumPrimary)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.oshiniumPrimary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section("テーマ名") {
                    TextField("例：わたしのさくらテーマ", text: $themeName)
                }
            }
            .navigationTitle("テーマを保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showSaveSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
                        themeManager.saveTheme(name: trimmed.isEmpty ? "マイテーマ" : trimmed, draft: draft) { result in
                            if case .success(let saved) = result {
                                themeManager.applyTheme(saved)
                            }
                        }
                        showSaveSheet = false
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(180)])
    }

    private var myThemesSheet: some View {
        NavigationStack {
            List {
                Section("保存したテーマ") {
                    if themeManager.savedThemes.isEmpty {
                        Text("まだテーマを保存していません")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(themeManager.savedThemes) { theme in
                            themeRow(theme, isLocked: false)
                        }
                    }
                }
                Section("限定テーマ") {
                    ForEach(CustomTheme.curatedPresets) { theme in
                        themeRow(theme, isLocked: !themeManager.isUnlocked(theme))
                    }
                }
            }
            .navigationTitle("テーマ一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { showMyThemesSheet = false }
                }
            }
        }
    }

    private func themeRow(_ theme: CustomTheme, isLocked: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [theme.resolvedBaseColor, theme.resolvedAccentColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: theme.icon.systemImage).font(.system(size: 12)).foregroundColor(.white))

            Text(theme.name)
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if isLocked {
                Button {
                    unlock(theme)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text("\(theme.pointCost)pt")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.oshiniumPrimary))
                }
                .buttonStyle(.plain)
            } else if theme.id == themeManager.activeTheme.id {
                Text("適用中")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.oshiniumPrimary)
            } else {
                Button("適用") {
                    draft = theme
                    themeManager.applyTheme(theme)
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Color⇔16進数変換(カスタムカラー用)

extension Color {
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
