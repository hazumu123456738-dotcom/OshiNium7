//
//  ThemedScreenDecoration.swift
//  OshiNium7
//

import SwiftUI

// ★ 着せ替えテーマを実際の画面へ反映する共通レイヤー。ホーム/カレンダー/オシニウム/
//   チャット/マイページの5タブそれぞれのルートに`.oshiniumThemeDecoration()`を
//   1行足すだけで、選択中テーマの「背景の淡いテーマカラー」「上部のアクセントライン+
//   リボンバッジ」「エフェクトの控えめな常時パーティクル」を重ねられるようにする。
//   ★ CustomTheme.defaultのままなら何も描画しない(既存の「高級感×白×純正アップル」の
//   デザインを一切変えない)。ユーザーが実際にテーマを選んで初めて見た目が変わる
//   ★ 5タブは常時マウントされたままopacityで切り替える構造(OshiNiumTabView)のため、
//   パーティクルは常時アニメーションさせず固定配置にして、見えていないタブでの
//   余計な描画コストを避ける
//   ★ 2026-08-09: 現在どの画面からも呼び出していない(タブ画面への反映は一旦保留し、
//   まずはアプリアイコンの着せ替えだけをリリースする方針になったため)。実装自体は
//   ここに残しているので、再開する際は各タブのbody末尾に`.oshiniumThemeDecoration()`を
//   1行足すだけでよい
struct ThemedScreenDecoration: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        let theme = themeManager.activeTheme
        let isCustomized = !theme.isVisuallyDefault

        content
            .background(alignment: .top) {
                if isCustomized {
                    themeBackgroundLayer(theme)
                }
            }
            .overlay {
                if isCustomized, theme.effect != .none {
                    ThemeAmbientParticles(effect: theme.effect, tint: theme.resolvedAccentColor)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if isCustomized, theme.ribbon != .none {
                    ThemeTopAccentBar(style: theme.ribbon, color: theme.resolvedAccentColor)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private func themeBackgroundLayer(_ theme: CustomTheme) -> some View {
        let base = theme.resolvedBaseColor
        let secondary = theme.baseColor == .custom ? base.opacity(0.6) : theme.baseColor.secondaryColor
        let strength = theme.colorOpacity * 0.16 // 実画面では控えめに(カード面とのコントラストを保つ)

        Group {
            switch theme.background {
            case .plain:
                base.opacity(strength)
            case .gradient, .confetti, .waves, .sparkleDust:
                LinearGradient(colors: [base.opacity(strength), secondary.opacity(strength * 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .sakura, .floralLace, .clouds, .snow:
                LinearGradient(colors: [base.opacity(strength), Color.clear], startPoint: .top, endPoint: .bottom)
            case .stars, .galaxy:
                LinearGradient(colors: [base.opacity(strength * 1.3), Color.clear], startPoint: .top, endPoint: .bottom)
            case .hearts:
                RadialGradient(colors: [base.opacity(strength), Color.clear], center: .top, startRadius: 10, endRadius: 420)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    func oshiniumThemeDecoration() -> some View {
        modifier(ThemedScreenDecoration())
    }
}

// MARK: - 画面上部のアクセントライン
//   ★ 当初はリボンアイコンのバッジも中央に重ねていたが、画面ごとにヘッダーの構成が違うため
//   「OshiNium」ロゴや「DMリクエスト」タブなど既存の文字・ボタンと衝突する画面があった。
//   衝突リスクの無い、画面最上端の細いアクセントラインだけに絞る
private struct ThemeTopAccentBar: View {
    let style: ThemeRibbonStyle
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [color.opacity(0), color.opacity(0.7), color.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 3)
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - 常時表示の控えめなアンビエントパーティクル(固定配置・非アニメーション)

private struct ThemeAmbientParticles: View {
    let effect: ThemeEffectStyle
    let tint: Color

    // ★ .random()を使うと再描画のたびに位置が変わってちらつくため、固定の相対座標を使う
    private static let positions: [(CGFloat, CGFloat, CGFloat)] = [
        (0.08, 0.06, 12), (0.85, 0.10, 9), (0.20, 0.30, 8),
        (0.92, 0.42, 11), (0.06, 0.55, 9), (0.80, 0.68, 13),
        (0.15, 0.82, 8), (0.90, 0.90, 10)
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(Self.positions.enumerated()), id: \.offset) { _, point in
                Image(systemName: effect.particleSystemImage)
                    .font(.system(size: point.2))
                    .foregroundColor(tint.opacity(0.18))
                    .position(x: point.0 * geo.size.width, y: point.1 * geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}
