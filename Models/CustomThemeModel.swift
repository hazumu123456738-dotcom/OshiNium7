//
//  CustomThemeModel.swift
//  OshiNium7
//

import SwiftUI

// ★ ポイントの交換景品第一弾「着せ替えカスタマイズ」のデータモデル。
//   将来的なテーマ追加・共有機能を見据え、各カテゴリはenum(プリセットの組み合わせ)にし、
//   ユーザーが作ったテーマも運営が用意する「限定テーマ」も同じCustomTheme構造体1つで
//   表現できるようにしている(isBuiltIn/pointCostで区別するだけ)
//   ★ 2026-08-08: 各カテゴリの選択肢を約3倍に拡張し、ベース/アクセントカラーは
//   プリセット以外に「カスタム」(16進数カラー+透明度)も選べるようにした
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

    // ★ baseColor/accentColorが.customの時だけ使う16進数カラーと、
    //   ベースカラー全体の透明度(参考デザインの「透明度」スライダーに対応)
    var baseColorCustomHex: String?
    var accentColorCustomHex: String?
    var colorOpacity: Double = 1.0

    // ★ isBuiltIn == trueは運営が用意した「限定テーマ」プリセット。pointCost > 0なら
    //   ポイント交換が必要(PointExchangeView参照)。isBuiltIn == falseはユーザーが
    //   カスタマイズ画面で自由に組み合わせて保存した、その人だけのテーマ
    var isBuiltIn: Bool = false
    var pointCost: Int = 0
    var createdAt: Date = Date()

    // ★ .customの時だけhexを見て解決する。それ以外は各enumのcolorをそのまま使う
    var resolvedBaseColor: Color {
        if baseColor == .custom, let hex = baseColorCustomHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return baseColor.color
    }

    var resolvedAccentColor: Color {
        if accentColor == .custom, let hex = accentColorCustomHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return accentColor.color
    }

    // ★ 「テーマが変更されているか」の判定はidではなく見た目に関わる項目の内容で行う。
    //   idは複製元(保存済みテーマや.default)から引き継がれたまま変わらないことが多く
    //   (例:カスタマイズ画面のdraftはThemeManager.activeThemeを複製して作るため、
    //   色を変えてもidは"default"のまま)、id比較では編集直後の状態を正しく検出できない
    var isVisuallyDefault: Bool {
        baseColor == CustomTheme.default.baseColor &&
        accentColor == CustomTheme.default.accentColor &&
        background == CustomTheme.default.background &&
        ribbon == CustomTheme.default.ribbon &&
        icon == CustomTheme.default.icon &&
        font == CustomTheme.default.font &&
        effect == CustomTheme.default.effect &&
        baseColorCustomHex == CustomTheme.default.baseColorCustomHex &&
        accentColorCustomHex == CustomTheme.default.accentColorCustomHex &&
        colorOpacity == CustomTheme.default.colorOpacity
    }

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

    // MARK: - 着せ替えアイコンの「おすすめセット」5種。すべてポイント限定(15pt均一)。
    //   ダイアの位置・形状は共通(トレードマーク)で、色・質感・背景・装飾だけを世界観ごとに作り込んだもの
    //   (2026-08-09: 単純な色相シフトの5色から、実際に描き起こした5世界観へ全面刷新)
    static let curatedPresets: [CustomTheme] = [
        CustomTheme(id: "preset_real_diamond", name: "リアルダイヤモンド", baseColor: .blue, accentColor: .white,
                    background: .gradient, ribbon: .none, icon: .diamond, font: .system, effect: .sparkles,
                    isBuiltIn: true, pointCost: 15),
        CustomTheme(id: "preset_noir_black", name: "漆黒ノワール", baseColor: .black, accentColor: .purple,
                    background: .galaxy, ribbon: .none, icon: .crown, font: .serif, effect: .stars,
                    isBuiltIn: true, pointCost: 15),
        CustomTheme(id: "preset_cute_pastel", name: "キュートパステル", baseColor: .pink, accentColor: .pink,
                    background: .hearts, ribbon: .none, icon: .heart, font: .rounded, effect: .hearts,
                    isBuiltIn: true, pointCost: 15),
        CustomTheme(id: "preset_jirai_ribbon", name: "地雷リボン", baseColor: .pink, accentColor: .black,
                    background: .plain, ribbon: .pinkRibbon, icon: .bow, font: .rounded, effect: .ribbonsFalling,
                    isBuiltIn: true, pointCost: 15),
        CustomTheme(id: "preset_lavender_chic", name: "ラベンダーシック", baseColor: .lavender, accentColor: .purple,
                    background: .gradient, ribbon: .none, icon: .sparkle, font: .serif, effect: .sparkles,
                    isBuiltIn: true, pointCost: 15)
    ]
}

// MARK: - ベースカラー／アクセントカラー(6種 → 18種 + カスタム)

enum ThemeColorOption: String, Codable, CaseIterable, Identifiable {
    case pink, purple, blue, mint, black, white
    case red, orange, yellow, green, teal, indigo, brown, gray, gold, silver, coral, lavender
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pink: return "ピンク"
        case .purple: return "パープル"
        case .blue: return "ブルー"
        case .mint: return "ミント"
        case .black: return "ブラック"
        case .white: return "ホワイト"
        case .red: return "レッド"
        case .orange: return "オレンジ"
        case .yellow: return "イエロー"
        case .green: return "グリーン"
        case .teal: return "ティール"
        case .indigo: return "インディゴ"
        case .brown: return "ブラウン"
        case .gray: return "グレー"
        case .gold: return "ゴールド"
        case .silver: return "シルバー"
        case .coral: return "コーラル"
        case .lavender: return "ラベンダー"
        case .custom: return "カスタム"
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
        case .red: return Color(red: 0.90, green: 0.30, blue: 0.32)
        case .orange: return Color(red: 0.95, green: 0.60, blue: 0.25)
        case .yellow: return Color(red: 0.95, green: 0.80, blue: 0.30)
        case .green: return Color(red: 0.40, green: 0.75, blue: 0.45)
        case .teal: return Color(red: 0.30, green: 0.70, blue: 0.70)
        case .indigo: return Color(red: 0.38, green: 0.38, blue: 0.78)
        case .brown: return Color(red: 0.55, green: 0.40, blue: 0.30)
        case .gray: return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .gold: return Color(red: 0.85, green: 0.70, blue: 0.35)
        case .silver: return Color(red: 0.75, green: 0.76, blue: 0.80)
        case .coral: return Color(red: 0.95, green: 0.50, blue: 0.45)
        case .lavender: return Color(red: 0.75, green: 0.68, blue: 0.92)
        case .custom: return Color(red: 0.60, green: 0.60, blue: 0.62)
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
        case .red: return Color(red: 0.98, green: 0.55, blue: 0.55)
        case .orange: return Color(red: 0.98, green: 0.78, blue: 0.50)
        case .yellow: return Color(red: 0.98, green: 0.90, blue: 0.60)
        case .green: return Color(red: 0.62, green: 0.88, blue: 0.65)
        case .teal: return Color(red: 0.55, green: 0.88, blue: 0.88)
        case .indigo: return Color(red: 0.62, green: 0.62, blue: 0.92)
        case .brown: return Color(red: 0.75, green: 0.62, blue: 0.50)
        case .gray: return Color(red: 0.78, green: 0.78, blue: 0.80)
        case .gold: return Color(red: 0.95, green: 0.85, blue: 0.60)
        case .silver: return Color(red: 0.90, green: 0.91, blue: 0.93)
        case .coral: return Color(red: 0.98, green: 0.72, blue: 0.68)
        case .lavender: return Color(red: 0.88, green: 0.84, blue: 0.96)
        case .custom: return Color(red: 0.78, green: 0.78, blue: 0.80)
        }
    }
}

// MARK: - 背景デザイン(4種 → 12種)

enum ThemeBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case plain, gradient, sakura, stars
    case hearts, clouds, confetti, floralLace, galaxy, waves, snow, sparkleDust

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: return "プレーン"
        case .gradient: return "グラデーション"
        case .sakura: return "桜・ピンク"
        case .stars: return "星空"
        case .hearts: return "ハート柄"
        case .clouds: return "もこもこ雲"
        case .confetti: return "紙吹雪"
        case .floralLace: return "花柄レース"
        case .galaxy: return "銀河"
        case .waves: return "波紋"
        case .snow: return "雪景色"
        case .sparkleDust: return "きらめき"
        }
    }

    var icon: String {
        switch self {
        case .plain: return "square"
        case .gradient: return "square.fill.on.square.fill"
        case .sakura: return "leaf.fill"
        case .stars: return "sparkles"
        case .hearts: return "heart.fill"
        case .clouds: return "cloud.fill"
        case .confetti: return "party.popper.fill"
        case .floralLace: return "camera.macro"
        case .galaxy: return "moon.stars.fill"
        case .waves: return "water.waves"
        case .snow: return "snowflake"
        case .sparkleDust: return "wand.and.stars"
        }
    }
}

// MARK: - リボン・フレーム(4種 → 12種)

enum ThemeRibbonStyle: String, Codable, CaseIterable, Identifiable {
    case none, pinkRibbon, goldRibbon, blackLace
    case silverChain, pearlString, floralCrown, starGarland, laceFrame, jewelBorder, ropeKnot, rainbowRibbon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "なし"
        case .pinkRibbon: return "リボン（ピンク）"
        case .goldRibbon: return "リボン（ゴールド）"
        case .blackLace: return "レース（ブラック）"
        case .silverChain: return "チェーン（シルバー）"
        case .pearlString: return "パールストリング"
        case .floralCrown: return "フラワークラウン"
        case .starGarland: return "スターガーランド"
        case .laceFrame: return "レースフレーム"
        case .jewelBorder: return "ジュエルボーダー"
        case .ropeKnot: return "ロープノット"
        case .rainbowRibbon: return "レインボーリボン"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .pinkRibbon, .goldRibbon, .rainbowRibbon: return "bookmark.fill"
        case .blackLace, .laceFrame: return "square.stack.3d.up.fill"
        case .silverChain, .ropeKnot: return "link"
        case .pearlString, .jewelBorder: return "circle.grid.3x3.fill"
        case .floralCrown: return "camera.macro"
        case .starGarland: return "sparkles"
        }
    }
}

// MARK: - アイコンデザイン（バッジ・アクセントとして使うシンボル、5種 → 15種）

enum ThemeIconAccent: String, Codable, CaseIterable, Identifiable {
    case heart, star, diamond, crown, sparkle
    case moon, sun, flower, ribbon, butterfly, cloud, bow, gem, paw, music

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heart: return "ハート"
        case .star: return "スター"
        case .diamond: return "ダイヤ"
        case .crown: return "クラウン"
        case .sparkle: return "スパークル"
        case .moon: return "ムーン"
        case .sun: return "サン"
        case .flower: return "フラワー"
        case .ribbon: return "リボン"
        case .butterfly: return "バタフライ"
        case .cloud: return "クラウド"
        case .bow: return "ボウ"
        case .gem: return "ジェム"
        case .paw: return "肉球"
        case .music: return "ミュージック"
        }
    }

    var systemImage: String {
        switch self {
        case .heart: return "heart.fill"
        case .star: return "star.fill"
        case .diamond: return "diamond.fill"
        case .crown: return "crown.fill"
        case .sparkle: return "sparkle"
        case .moon: return "moon.stars.fill"
        case .sun: return "sun.max.fill"
        case .flower: return "camera.macro"
        case .ribbon: return "bookmark.fill"
        case .butterfly: return "ladybug.fill"
        case .cloud: return "cloud.fill"
        case .bow: return "gift.fill"
        case .gem: return "hexagon.fill"
        case .paw: return "pawprint.fill"
        case .music: return "music.note"
        }
    }
}

// MARK: - フォント(3種 → 9種)
//   ★ SwiftUIのFont.Designはdefault/serif/rounded/monospacedの4種類しか無く、
//   このプロジェクトに独自の書体ファイルは同梱されていないため、design×weight×字間の
//   組み合わせで見た目に違いが出る9パターンを作る(実在しない書体を偽装するものではない)

enum ThemeFontStyle: String, Codable, CaseIterable, Identifiable {
    case system, rounded, serif, monospaced
    case systemBold, roundedBold, serifLight, roundedWide, serifBold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "標準"
        case .rounded: return "丸ゴシック"
        case .serif: return "明朝"
        case .monospaced: return "モノスペース"
        case .systemBold: return "標準・太字"
        case .roundedBold: return "丸ゴシック・太字"
        case .serifLight: return "明朝・ライト"
        case .roundedWide: return "丸ゴシック・広め"
        case .serifBold: return "明朝・太字"
        }
    }

    var design: Font.Design {
        switch self {
        case .system, .systemBold: return .default
        case .rounded, .roundedBold, .roundedWide: return .rounded
        case .serif, .serifLight, .serifBold: return .serif
        case .monospaced: return .monospaced
        }
    }

    var weight: Font.Weight {
        switch self {
        case .system, .rounded, .serif, .monospaced: return .regular
        case .systemBold, .roundedBold, .serifBold: return .bold
        case .serifLight: return .light
        case .roundedWide: return .semibold
        }
    }

    var tracking: CGFloat {
        switch self {
        case .roundedWide: return 1.2
        default: return 0
        }
    }
}

// MARK: - エフェクト（装飾カード上に舞うパーティクル、4種 → 12種）

enum ThemeEffectStyle: String, Codable, CaseIterable, Identifiable {
    case none, sakuraPetals, sparkles, stars
    case hearts, confetti, bubbles, snow, fireflies, butterflies, ribbonsFalling, glitterRain

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "なし"
        case .sakuraPetals: return "さくら舞う"
        case .sparkles: return "きらきら"
        case .stars: return "星がまたたく"
        case .hearts: return "ハート降る"
        case .confetti: return "紙吹雪"
        case .bubbles: return "シャボン玉"
        case .snow: return "雪が舞う"
        case .fireflies: return "ほたる"
        case .butterflies: return "蝶が舞う"
        case .ribbonsFalling: return "リボン降る"
        case .glitterRain: return "グリッター"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .sakuraPetals: return "leaf.fill"
        case .sparkles: return "sparkles"
        case .stars: return "sparkle"
        case .hearts: return "heart.fill"
        case .confetti: return "party.popper.fill"
        case .bubbles: return "circle.circle.fill"
        case .snow: return "snowflake"
        case .fireflies: return "light.max"
        case .butterflies: return "ladybug.fill"
        case .ribbonsFalling: return "bookmark.fill"
        case .glitterRain: return "wand.and.stars"
        }
    }

    var particleSystemImage: String {
        switch self {
        case .none: return ""
        case .sakuraPetals: return "leaf.fill"
        case .sparkles: return "sparkle"
        case .stars: return "star.fill"
        case .hearts: return "heart.fill"
        case .confetti: return "square.fill"
        case .bubbles: return "circle"
        case .snow: return "snowflake"
        case .fireflies: return "circle.fill"
        case .butterflies: return "ladybug.fill"
        case .ribbonsFalling: return "minus.circle.fill"
        case .glitterRain: return "sparkle"
        }
    }
}
