//
//  CustomThemeModel.swift
//  OshiNium7
//

import SwiftUI

// ★ ポイントの交換景品第一弾「着せ替えカスタマイズ」のデータモデル。
//   将来的なテーマ追加・共有機能を見据え、各カテゴリはenum(プリセットの組み合わせ)にし、
//   ユーザーが作ったテーマも運営が用意する「限定テーマ」も同じCustomTheme構造体1つで
//   表現できるようにしている(isBuiltIn/pointCostで区別するだけ)
struct CustomTheme: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var baseColor: ThemeColorOption
    var accentColor: ThemeColorOption
    var background: ThemeBackgroundStyle
    var ribbon: ThemeRibbonStyle
    var icon: ThemeIconAccent
    var font: ThemeFontStyle
    var effect: ThemeEffectStyle

    // ★ isBuiltIn == trueは運営が用意した「限定テーマ」プリセット。pointCost > 0なら
    //   ポイント交換が必要(PointExchangeView参照)。isBuiltIn == falseはユーザーが
    //   カスタマイズ画面で自由に組み合わせて保存した、その人だけのテーマ
    var isBuiltIn: Bool = false
    var pointCost: Int = 0
    var createdAt: Date = Date()

    static let `default` = CustomTheme(
        id: "default",
        name: "デフォルト",
        baseColor: .purple,
        accentColor: .purple,
        background: .plain,
        ribbon: .none,
        icon: .sparkle,
        font: .system,
        effect: .none
    )

    // MARK: - 「おすすめカラーセット」= 無料プリセット3種 + ポイント限定プリセット2種
    //   （参考デザインの「さくら/ラベンダー/ミントソーダ/ネオンピンク/ゴシックパープル」を、
    //   無料3種・ポイント限定2種に割り振ったもの）
    static let curatedPresets: [CustomTheme] = [
        CustomTheme(id: "preset_sakura", name: "さくら", baseColor: .pink, accentColor: .pink,
                    background: .sakura, ribbon: .pinkRibbon, icon: .heart, font: .rounded, effect: .sakuraPetals),
        CustomTheme(id: "preset_lavender", name: "ラベンダー", baseColor: .purple, accentColor: .purple,
                    background: .gradient, ribbon: .none, icon: .sparkle, font: .rounded, effect: .sparkles),
        CustomTheme(id: "preset_mintsoda", name: "ミントソーダ", baseColor: .mint, accentColor: .blue,
                    background: .stars, ribbon: .none, icon: .star, font: .system, effect: .none),
        CustomTheme(id: "preset_neonpink", name: "ネオンピンク", baseColor: .pink, accentColor: .purple,
                    background: .gradient, ribbon: .none, icon: .heart, font: .rounded, effect: .sparkles,
                    isBuiltIn: true, pointCost: 30),
        CustomTheme(id: "preset_gothicpurple", name: "ゴシックパープル", baseColor: .black, accentColor: .purple,
                    background: .stars, ribbon: .blackLace, icon: .crown, font: .serif, effect: .stars,
                    isBuiltIn: true, pointCost: 50)
    ]
}

// MARK: - ベースカラー／アクセントカラー

enum ThemeColorOption: String, Codable, CaseIterable, Identifiable {
    case pink, purple, blue, mint, black, white

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pink: return "ピンク"
        case .purple: return "パープル"
        case .blue: return "ブルー"
        case .mint: return "ミント"
        case .black: return "ブラック"
        case .white: return "ホワイト"
        }
    }

    var color: Color {
        switch self {
        case .pink: return Color(red: 0.95, green: 0.55, blue: 0.70)
        case .purple: return Color.oshiniumPrimary
        case .blue: return Color(red: 0.40, green: 0.60, blue: 0.95)
        case .mint: return Color(red: 0.45, green: 0.80, blue: 0.70)
        case .black: return Color(red: 0.18, green: 0.17, blue: 0.20)
        case .white: return Color(red: 0.98, green: 0.98, blue: 0.99)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .pink: return Color(red: 0.98, green: 0.75, blue: 0.82)
        case .purple: return Color.oshiniumPrimary2
        case .blue: return Color(red: 0.55, green: 0.78, blue: 0.98)
        case .mint: return Color(red: 0.65, green: 0.90, blue: 0.82)
        case .black: return Color(red: 0.35, green: 0.32, blue: 0.40)
        case .white: return Color(red: 0.90, green: 0.90, blue: 0.93)
        }
    }
}

// MARK: - 背景デザイン

enum ThemeBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case plain, gradient, sakura, stars

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: return "プレーン"
        case .gradient: return "グラデーション"
        case .sakura: return "桜・ピンク"
        case .stars: return "星空"
        }
    }

    var icon: String {
        switch self {
        case .plain: return "square"
        case .gradient: return "square.fill.on.square.fill"
        case .sakura: return "leaf.fill"
        case .stars: return "sparkles"
        }
    }
}

// MARK: - リボン・フレーム

enum ThemeRibbonStyle: String, Codable, CaseIterable, Identifiable {
    case none, pinkRibbon, goldRibbon, blackLace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "なし"
        case .pinkRibbon: return "リボン（ピンク）"
        case .goldRibbon: return "リボン（ゴールド）"
        case .blackLace: return "レース（ブラック）"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .pinkRibbon, .goldRibbon: return "bookmark.fill"
        case .blackLace: return "square.stack.3d.up.fill"
        }
    }
}

// MARK: - アイコンデザイン（バッジ・アクセントとして使うシンボル）

enum ThemeIconAccent: String, Codable, CaseIterable, Identifiable {
    case heart, star, diamond, crown, sparkle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heart: return "ハート"
        case .star: return "スター"
        case .diamond: return "ダイヤ"
        case .crown: return "クラウン"
        case .sparkle: return "スパークル"
        }
    }

    var systemImage: String {
        switch self {
        case .heart: return "heart.fill"
        case .star: return "star.fill"
        case .diamond: return "diamond.fill"
        case .crown: return "crown.fill"
        case .sparkle: return "sparkle"
        }
    }
}

// MARK: - フォント

enum ThemeFontStyle: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "標準"
        case .rounded: return "丸ゴシック"
        case .serif: return "明朝"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        }
    }
}

// MARK: - エフェクト（装飾カード上に舞うパーティクル）

enum ThemeEffectStyle: String, Codable, CaseIterable, Identifiable {
    case none, sakuraPetals, sparkles, stars

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "なし"
        case .sakuraPetals: return "さくら舞う"
        case .sparkles: return "きらきら"
        case .stars: return "星がまたたく"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .sakuraPetals: return "leaf.fill"
        case .sparkles: return "sparkles"
        case .stars: return "sparkle"
        }
    }
}
