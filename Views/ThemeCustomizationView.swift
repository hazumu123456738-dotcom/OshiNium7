//
//  ThemeCustomizationView.swift
//  OshiNium7
//

import SwiftUI

// ★ ポイント交換景品第一弾「着せ替えカスタマイズ」の本体画面。7カテゴリ(ベースカラー・
//   アクセントカラー・背景・リボン/フレーム・アイコン・フォント・エフェクト)を自由に
//   組み合わせ、上のプレビューにリアルタイム反映する。保存すると自分だけのテーマとして
//   users/{uid}/customThemesに追加され、あとで切り替えられる。
//   ★ カスタマイズツール自体は誰でも無料で使える。ポイントが必要なのは
//   CustomTheme.curatedPresetsのうちisBuiltIn==trueの「限定テーマ」を解放する時だけ
struct ThemeCustomizationView: View {
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var draft: CustomTheme
    @State private var selectedCategory: Category = .baseColor
    @State private var showSaveSheet = false
    @State private var themeName = ""
    @State private var showMyThemesSheet = false
    @State private var unlockErrorMessage: String?
    @State private var unlockSuccessMessage: String?

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
                    previewCard

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
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("着せ替えカスタマイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存する") {
                        themeName = ""
                        showSaveSheet = true
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showSaveSheet) { saveSheet }
            .sheet(isPresented: $showMyThemesSheet) { myThemesSheet }
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

    private var previewCard: some View {
        ZStack {
            themedBackground(draft)

            ThemeEffectParticles(effect: draft.effect, tint: draft.accentColor.color)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: draft.icon.systemImage)
                        .foregroundColor(draft.accentColor.color)
                    Text("Heart2Heart")
                        .font(.system(size: 17, weight: .bold, design: draft.font.design))
                        .foregroundColor(draft.baseColor == .black ? .white : .primary)
                    Spacer()
                }
                Text("2026年8月")
                    .font(.system(size: 22, weight: .heavy, design: draft.font.design))
                    .foregroundColor(draft.baseColor == .black ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Capsule()
                    .fill(draft.accentColor.color.opacity(0.85))
                    .frame(height: 22)
                    .overlay(
                        Text("コミュニティカレンダー")
                            .font(.system(size: 10, weight: .bold, design: draft.font.design))
                            .foregroundColor(.white)
                    )
            }
            .padding(16)

            if draft.ribbon != .none {
                RibbonBanner(style: draft.ribbon, color: draft.accentColor.color)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private func themedBackground(_ theme: CustomTheme) -> some View {
        switch theme.background {
        case .plain:
            theme.baseColor.color.opacity(0.16)
        case .gradient:
            LinearGradient(colors: [theme.baseColor.color.opacity(0.35), theme.baseColor.secondaryColor.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sakura:
            LinearGradient(colors: [theme.baseColor.color.opacity(0.25), Color.white.opacity(0.4)], startPoint: .top, endPoint: .bottom)
        case .stars:
            LinearGradient(colors: [Color(red: 0.08, green: 0.06, blue: 0.16), theme.baseColor.color.opacity(0.35)], startPoint: .top, endPoint: .bottom)
        }
        Color.white.opacity(0.001) // タップ領域確保のダミー(重ねる背景がZStack内で潰れないように)
    }

    // MARK: - カスタマイズ項目一覧

    private var categoryList: some View {
        VStack(spacing: 0) {
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
            colorSwatches(selected: draft.baseColor) { draft.baseColor = $0 }
        case .accentColor:
            colorSwatches(selected: draft.accentColor) { draft.accentColor = $0 }
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

    private func colorSwatches(selected: ThemeColorOption, onSelect: @escaping (ThemeColorOption) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(ThemeColorOption.allCases) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(option.color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().strokeBorder(Color.oshiniumPrimary, lineWidth: option == selected ? 2.5 : 0)
                                        .padding(-3)
                                )
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(option == .white || option == .mint ? .black.opacity(0.6) : .white)
                                        .opacity(option == selected ? 1 : 0)
                                )
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
                                    .font(.system(size: 15, design: option.design))
                                    .foregroundColor(option == draft.font ? .oshiniumPrimary : .secondary)
                            }
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
                .fill(LinearGradient(colors: [theme.baseColor.color, theme.accentColor.color], startPoint: .topLeading, endPoint: .bottomTrailing))
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

// MARK: - リボン・フレームの簡易デコレーション

private struct RibbonBanner: View {
    let style: ThemeRibbonStyle
    let color: Color

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    )
                    .rotationEffect(.degrees(180))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                Spacer()
            }
            Spacer()
        }
        .padding(.top, -6)
    }
}

// MARK: - エフェクトのパーティクル(さくら舞う・きらきら・星がまたたく)

private struct ThemeEffectParticles: View {
    let effect: ThemeEffectStyle
    let tint: Color

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let delay: Double
        let size: CGFloat
    }

    @State private var particles: [Particle] = (0..<14).map { _ in
        Particle(x: .random(in: 0...1), delay: .random(in: 0...3), size: .random(in: 4...9))
    }

    var body: some View {
        if effect == .none {
            EmptyView()
        } else {
            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ForEach(particles) { particle in
                        let progress = ((t + particle.delay).truncatingRemainder(dividingBy: 4)) / 4
                        particleIcon
                            .font(.system(size: particle.size))
                            .foregroundColor(tint.opacity(0.8))
                            .position(
                                x: particle.x * geo.size.width + sin(t + particle.delay) * 8,
                                y: progress * geo.size.height
                            )
                            .opacity(effect == .sakuraPetals ? 1 : (0.4 + 0.6 * sin(t * 2 + particle.delay)))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var particleIcon: some View {
        switch effect {
        case .sakuraPetals: Image(systemName: "leaf.fill")
        case .sparkles: Image(systemName: "sparkle")
        case .stars: Image(systemName: "star.fill")
        case .none: EmptyView()
        }
    }
}
