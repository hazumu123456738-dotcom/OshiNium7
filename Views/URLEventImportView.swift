//
//  URLEventImportView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ 「AIで追加する」(Web全体を検索する既存フロー、現在は精度の都合で開発中)とは別の入り口。
//   こちらはユーザーが選んだ1本のURL(公式ツイート・イベントページ等)の中身だけを
//   AIに読み取らせてイベント情報を抽出する。情報源は常にユーザー自身が指定したものなので、
//   検索して探すAIより結果を信頼しやすい。抽出結果は既存のAIAddEventResultView（確認画面）で
//   必ずユーザーが内容を確認してから保存する
struct URLEventImportView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.customTabBarHeight) private var customTabBarHeight
    @EnvironmentObject var eventViewModel: EventViewModel

    let selectedGroup: IdolGroup?
    let defaultDate: Date

    @State private var urlText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var extractedResult: AIEventResult?
    @State private var navigateToResult = false
    @FocusState private var isFieldFocused: Bool

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.80, green: 0.86, blue: 1.0),
                    Color(red: 0.93, green: 0.90, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            Color(red: 0.98, green: 0.98, blue: 0.99)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                    }

                    Spacer()

                    Text("URLから追加")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("URLを読み込んで予定を作成")
                                .font(.system(size: 24, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text("公式ツイートやイベントページのURLを貼り付けると、\nAIが日時・会場を読み取ってフォームに入力します")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(colors: [accentColor.opacity(0.25), accentColor2.opacity(0.25)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 120, height: 120)

                            Image(systemName: "link.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 66, height: 66)
                                .foregroundColor(accentColor)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("会場・公演情報が書かれたURL")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)

                            TextField("https://...", text: $urlText)
                                .font(.system(size: 15))
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isFieldFocused)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.appCardBackground)
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(isFieldFocused ? accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
                                )

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 24)

                        Button {
                            runExtraction()
                        } label: {
                            ZStack {
                                LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                                    .frame(height: 56)
                                    .cornerRadius(28)
                                    .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 6)

                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.white)
                                    }
                                    Text(isLoading ? "読み取っています…" : "URLを読み込む")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .opacity(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                        .padding(.bottom, 12 + customTabBarHeight)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToResult) {
            if let extractedResult {
                AIAddEventResultView(
                    result: extractedResult,
                    selectedGroup: selectedGroup,
                    defaultDate: defaultDate,
                    imageURL: nil,
                    eventVM: eventViewModel
                )
            }
        }
    }

    private func runExtraction() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await URLEventExtractionService.extractEvent(
                    from: urlText,
                    groupName: selectedGroup?.name ?? "",
                    groupId: selectedGroup?.id ?? ""
                )
                await MainActor.run {
                    isLoading = false
                    extractedResult = result
                    navigateToResult = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = (error as? URLEventExtractionService.ExtractionError)?.errorDescription
                        ?? "読み込みに失敗しました。もう一度お試しください"
                }
            }
        }
    }
}
