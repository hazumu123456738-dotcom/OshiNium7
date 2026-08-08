//
//  PointExchangeView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI

// ★ 貯めたポイントの交換画面。以前は「推し活占いで貯めた大吉ポイント」専用の名称・仕組みだったが、
//   予定追加・コミュニティ貢献・投稿・イベント参加など行動全般に対する共通の報酬へ拡張していく
//   前提のため、「大吉ポイント」→「ポイント」に名称を統一した(2026-08-08)。
//   交換景品は「全タブの初期画面・アプリアイコンの着せ替えデザイン」を予定しているが、
//   デザイン自体はまだ用意できていないため、今回はポイント残高の確認と「近日追加予定」で
//   あることを伝える入口だけを用意する。デザインが揃い次第、ここに実際の着せ替え候補カード＋
//   交換ボタンを追加していく
struct PointExchangeView: View {
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    private let accentColor = Color(red: 0.95, green: 0.72, blue: 0.35)
    private let accentColor2 = Color(red: 0.95, green: 0.55, blue: 0.55)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                pointsCard
                comingSoonCard
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("ポイント交換")
        .navigationBarTitleDisplayMode(.inline)
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
            Text("推し活占いで大吉を引くと貯まります")
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

    private var comingSoonCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 34))
                .foregroundColor(accentColor.opacity(0.6))
                .accessibilityHidden(true)

            Text("アプリの着せ替え")
                .font(.system(size: 16, weight: .bold))

            Text("貯めたポイントで、全タブの初期画面やアプリアイコンのデザインを交換できるようになる予定です。デザインは近日追加されます。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("近日公開")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.gray.opacity(0.6)))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
}
