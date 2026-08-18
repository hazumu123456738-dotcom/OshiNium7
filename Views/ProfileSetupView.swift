//
//  ProfileSetupView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/16.
//

import SwiftUI

// ★ 初回ログイン直後、グループ選択より前に必ず通す画面。表示名と誕生日を入力させ、
//   13歳未満であればその場で利用を止める（権利・個人保護の観点での年齢確認、
//   これまでは技術的な制限が一切無く、利用規約上の自己申告のみだった）。
//   一度hasCompletedOnboardingがtrueになったユーザーはこの画面を二度と通らない
//   （AppRootView側の条件分岐を参照）
struct ProfileSetupView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @State private var displayName = ""
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var showUnderageBlock = false
    @State private var errorMessage: String?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }

    private var canSubmit: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        if showUnderageBlock {
            underageBlockView
        } else {
            setupForm
        }
    }

    // MARK: - プロフィール作成フォーム

    private var setupForm: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(accentColor)
                    Text("プロフィールを作成")
                        .font(.system(size: 20, weight: .bold))
                    Text("推し活を始める前に、ユーザーネームと誕生日を教えてください")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 10) {
                    Text("ユーザーネーム")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("例：ゆず", text: $displayName)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.appCardBackground)
                        )
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("誕生日")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    DatePicker(
                        "",
                        selection: $birthday,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.appCardBackground)
                    )
                }
                .padding(.horizontal, 20)

                Text("13歳未満の方はご利用いただけません。誕生日は後からマイページで変更できません。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    submit()
                } label: {
                    Text(isSaving ? "保存中…" : "はじめる")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .opacity(canSubmit ? 1 : 0.5)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func submit() {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil

        // ★ 13歳未満の場合、Firestoreへは何も書き込まずブロック画面へ切り替える
        //   （最小限の情報しか収集しない：入力された誕生日そのものも保存しない）
        guard age >= 13 else {
            isSaving = false
            showUnderageBlock = true
            return
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let birthdayString = CachedFormatters.date(format: "yyyy-MM-dd", locale: Locale.current).string(from: birthday)
        settingsVM.completeOnboarding(displayName: trimmed, birthday: birthdayString) { error in
            isSaving = false
            if error != nil {
                errorMessage = "保存できませんでした。時間をおいてもう一度お試しください。"
            }
        }
    }

    // MARK: - 13歳未満のブロック画面

    private var underageBlockView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("ご利用いただけません")
                .font(.system(size: 20, weight: .bold))
            Text("13歳未満の方は本アプリをご利用いただけません。")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                auth.logout()
            } label: {
                Text("ログアウトする")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(.systemGray2))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}
