//
//  AppTheme.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/02.
//

import SwiftUI
import UIKit

// ★ ダークモード対応の第一弾。これまで全画面で`Color(hex: "#FAFAFC")`（背景）や
//   `Color.white`（カード面）が固定値で使われており、ダークモード端末で開くと
//   背景・カードが白いまま残ってしまっていた。ここで動的に切り替わる2色（背景・カード面）
//   を定義し、既存の固定値をこの2色に置き換えることで、影響範囲が最も大きい
//   「背景が白いまま」「カードが浮いて見える」問題をまず解消する。
//   個々の画面の細かい配色（アクセントカラー・警告色等）は今回のスコープ外。
extension Color {
    // ★ 画面のベース背景。以前の`Color(hex: "#FAFAFC")`の置き換え先。
    //   デザインコンセプト「高級感×白×純正アップル×少しの立体感」に合わせ、
    //   完全な無彩色ではなくごく薄く紫みを効かせ、ブランドカラーとの一体感を出す
    static let appBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.058, green: 0.056, blue: 0.082, alpha: 1)
            : UIColor(red: 0.978, green: 0.975, blue: 0.992, alpha: 1)
    })

    // ★ カード・ピル・プレートなど「面」として浮かせる要素。以前の`Color.white`の置き換え先。
    //   純白ではなく、ごくわずかに紫を帯びた白にすることで光沢感のある質感を狙う
    static let appCardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.112, green: 0.110, blue: 0.138, alpha: 1)
            : UIColor(red: 0.997, green: 0.995, blue: 1.0, alpha: 1)
    })

    // ★ OshiNiumのブランドカラー（紫〜ピンクのグラデーション）。以前は画面ごとに
    //   `private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)` のように
    //   同じ値がファイル数十箇所に個別コピーされており、色味を1箇所で調整できなかった。
    //   ここに1つだけ定義し、各画面はこれを指す形にする
    static let oshiniumPrimary = Color(red: 0.70, green: 0.55, blue: 0.98)
    static let oshiniumPrimary2 = Color(red: 0.90, green: 0.60, blue: 0.95)

    // ★ 着せ替えカスタマイズ用。ThemeManager.shared.activeTheme(プレビュー中はドラフトの
    //   一時的な上書き値)を見て、デフォルトテーマの間は今まで通りoshiniumPrimary系を返し、
    //   テーマ変更中はそのテーマのベース/アクセントカラーを返す。カレンダータブなど
    //   「テーマに連動してほしい」特定の要素だけをoshiniumPrimaryからこちらへ置き換えていく
    static var themedAccent: Color {
        let theme = ThemeManager.shared.activeTheme
        return theme.isVisuallyDefault ? oshiniumPrimary : theme.resolvedAccentColor
    }

    static var themedBase: Color {
        let theme = ThemeManager.shared.activeTheme
        return theme.isVisuallyDefault ? oshiniumPrimary2 : theme.resolvedBaseColor
    }
}

// MARK: - 角丸半径の標準値

// ★ release-check(2026/08/20)で発見：cornerRadiusが12〜24の間で画面ごとにバラバラに
//   使われており、統一された値の指針が無かった。GlossyHighlightのデフォルト値(20)が
//   実質的に「カード」の標準として既に定着していたため、ここで明文化する。
//   既存の18/16/14系の値を一括で20へ寄せる変更は見た目の回帰確認が難しく
//   スコープ外とし、まずは最頻値(20、105箇所)をこの定数に置き換えて一本化した上で、
//   今後の新規実装がここを参照する土台とする
enum CornerRadius {
    /// カード・投稿・シート等、主要な「面」のコンテナに使う標準値
    static let card: CGFloat = 20
    /// アイコンボタン・チップ・サムネイル等、小さめの要素に使う標準値
    static let compact: CGFloat = 14
}

// MARK: - グロッシーハイライト（デザインコンセプト「少しの立体感」用の共通パーツ）

// ★ カードの左上から差し込む光のような、ごく薄い斜めのハイライトを重ねる。
//   紫の光沢感を演出するための共通モディファイア。主要なカードにだけ使い、
//   使いすぎると煩雑になるため控えめな不透明度にとどめる
struct GlossyHighlight: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.card

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.oshiniumPrimary.opacity(0.14),
                            Color.white.opacity(0.0),
                            Color.oshiniumPrimary2.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
    }
}

extension View {
    func glossyHighlight(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        modifier(GlossyHighlight(cornerRadius: cornerRadius))
    }
}
