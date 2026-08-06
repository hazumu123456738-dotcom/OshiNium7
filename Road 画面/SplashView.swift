//
//  SplashView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/04.
//

import SwiftUI

// ★ シンプルにロゴと「OshiNium」の文字を1秒ほど見せてから、インスタのように
//   透けてホーム画面（またはログイン画面）に遷移する。フェード自体はAppRootView側で
//   このViewの表示/非表示を切り替える際に行うため、ここでは静的に表示するだけでよい
struct SplashView: View {
    private let logoSize: CGFloat = 220

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("splash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)

                Text("OshiNium")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color.oshiniumPrimary)
            }
        }
    }
}
