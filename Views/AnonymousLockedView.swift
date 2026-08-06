//
//  AnonymousLockedView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import SwiftUI

// ★ 匿名ログイン（閲覧専用）では使えない機能（ホーム・チャット・マイページ）の
//   代わりに表示するロック画面。タブ自体は消さず、開くとここに案内する
struct AnonymousLockedView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 54))
                .foregroundColor(Color.oshiniumPrimary.opacity(0.5))

            VStack(spacing: 6) {
                Text("ユーザー登録することで見れます")
                    .font(.system(size: 16, weight: .bold))

                Text("匿名ログイン中は閲覧専用のため、この機能は使えません。\nユーザー登録すると、投稿やチャット、マイページが使えるようになります。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Button {
                auth.logout()
            } label: {
                Text("ログイン / 新規登録する")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.oshiniumPrimary, Color.oshiniumPrimary2],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 32)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
