//
//  AddMethodSelectView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import SwiftUI

struct AddMethodSelectView: View {

    var onSelectAI: () -> Void
    var onSelectURL: () -> Void
    var onSelectManual: () -> Void

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(accentColor)

                Text("予定の追加方法を選択")
                    .font(.system(size: 18, weight: .bold))

                Text("どちらの方法で予定を登録しますか？")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 28)

            VStack(spacing: 14) {
                // ★ AIによる自動入力は現在まだ精度が低いため、選べないようにして
                //   「開発中」であることを明示する（手動追加のみ案内する）
                methodCard(
                    icon: "sparkles",
                    title: "AIで追加する",
                    subtitle: "アーティスト名や公演名を伝えるだけでAIが調べて自動入力します",
                    iconBackground: AnyShapeStyle(Color(.systemGray4)),
                    iconColor: .secondary,
                    badge: "開発中",
                    isEnabled: false,
                    action: onSelectAI
                )

                // ★ URLから取得した画像（og:image）の一部で、詳細画面のヒーロー画像が
                //   画面幅を超えてはみ出す不具合が未解決のため、原因が分かるまでAI追加と
                //   同じ「開発中」扱いで選べないようにしておく（アプリの他画面と同じ、
                //   実害のある不具合は直せるまで機能自体を止めるという方針）
                methodCard(
                    icon: "link",
                    title: "URLから追加する",
                    subtitle: "公式ツイートやイベントページのURLを貼るとAIが読み取って自動入力します",
                    iconBackground: AnyShapeStyle(Color(.systemGray4)),
                    iconColor: .secondary,
                    badge: "開発中",
                    isEnabled: false,
                    action: onSelectURL
                )

                methodCard(
                    icon: "pencil",
                    title: "手動で追加する",
                    subtitle: "日時や会場などを自分で入力して登録します",
                    iconBackground: AnyShapeStyle(Color(.systemGray5)),
                    iconColor: .secondary,
                    action: onSelectManual
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 12)
        }
        .background(backgroundView)
        .presentationDetents([.height(480)])
        .presentationCornerRadius(36)
    }

    private func methodCard(
        icon: String,
        title: String,
        subtitle: String,
        iconBackground: AnyShapeStyle,
        iconColor: Color = .white,
        badge: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isEnabled ? .primary : .secondary)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.gray.opacity(0.6)))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
            .opacity(isEnabled ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // MARK: - 背景（AddEventView等と同じ高級感のあるグロー背景）
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 36)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.94, blue: 1.0),
                        Color(red: 0.99, green: 0.99, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .blur(radius: 40)
                        .offset(x: -120, y: -140)

                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .blur(radius: 60)
                        .offset(x: 140, y: 60)
                }
            )
            .ignoresSafeArea()
    }
}
