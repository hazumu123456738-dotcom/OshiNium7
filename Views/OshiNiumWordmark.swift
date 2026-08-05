//
//  OshiNiumWordmark.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI

// ★ アプリ全体で使う「OshiNium」ロゴ文字。iの点（ドット）部分だけを、
//   ブランドシンボルであるダイアモンドの小さな図形に置き換える。
//   実装は「点なしのi（Unicode U+0131）」を使い、その真上に自前で小さな
//   ダイアモンド図形を重ねることで、フォント側の点を完全に置き換える
struct OshiNiumWordmark: View {
    var fontSize: CGFloat = 14
    var weight: Font.Weight = .bold
    var color: Color = .primary
    var diamondColor: Color? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text("Osh")
            dotlessI
            Text("N")
            dotlessI
            Text("um")
        }
        .font(.system(size: fontSize, weight: weight))
        .foregroundColor(color)
    }

    private var dotlessI: some View {
        // ★ U+0131（LATIN SMALL LETTER DOTLESS I）は点の無い"ı"。
        //   その上に、点があった位置目掛けて小さなダイアモンドを重ねる
        Text("\u{0131}")
            .overlay(alignment: .top) {
                OshiNiumDiamondDot()
                    .fill(diamondColor ?? color)
                    .frame(width: fontSize * 0.22, height: fontSize * 0.22)
                    .offset(y: fontSize * 0.06)
            }
    }
}

// ★ ロゴのダイアモンドアイコンと同じ「ひし形」。点として使うので装飾（ファセット線等）は付けない
struct OshiNiumDiamondDot: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
