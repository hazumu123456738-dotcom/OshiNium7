//
//  AICalendarAutoFillView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI

// ★ コミュニティカレンダーが空のグループ向けの「AIに丸ごと検索してもらう」導線。
//   既存のAI予定追加（AIAddEventView）はユーザー自身が検索クエリを考えて入力する必要があるが、
//   新規グループ・新規ユーザーにその手間を求めるのは離脱要因になる。ここでは検索クエリを
//   このアプリ側で自動生成し、SearchGroundingService（既存のGemini+Google検索連携）へ
//   そのまま投げるだけで、AIAddEventResultListView（既存のレビュー・追加UI）に渡す。
//   ★ 「AIが見つけた候補を人間が選んで追加する」という既存の安全設計（AIの誤情報が
//   コミュニティ全員が見る予定表に無審査で入らない）はそのまま維持する
struct AICalendarAutoFillView: View {

    let group: IdolGroup

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var results: [AIEventResult] = []
    @State private var errorMessage: String?
    @State private var didSearch = false

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)

    // ★ ユーザーに何も入力させず、このグループ名だけから直近半年分の予定を
    //   広く検索させるための固定クエリ
    private var autoQuery: String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(year)年の直近半年のライブ・イベント・テレビ出演・ファンミーティング・リリース予定を全て教えてください"
    }

    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if let errorMessage {
                errorState(errorMessage)
            } else {
                AIAddEventResultListView(
                    eventViewModel: eventViewModel,
                    results: results,
                    selectedGroup: group,
                    defaultDate: Date()
                )
            }
        }
        .navigationTitle("AIで予定を検索")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didSearch else { return }
            didSearch = true
            runSearch()
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(accentColor)
            Text("「\(group.name)」の公式スケジュールを検索しています…")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange.opacity(0.7))
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                isLoading = true
                errorMessage = nil
                runSearch()
            } label: {
                Text("もう一度検索する")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(accentColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func runSearch(attempt: Int = 1, maxAttempts: Int = 6) {
        SearchGroundingService.shared.searchEvents(
            query: autoQuery,
            groupName: group.name,
            groupId: group.id
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let jsonString):
                    if jsonString == "[]", attempt < maxAttempts {
                        let delay = Double.random(in: 0.2...0.5)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            runSearch(attempt: attempt + 1, maxAttempts: maxAttempts)
                        }
                        return
                    }

                    guard let list = AIEventResult.list(from: jsonString) else {
                        isLoading = false
                        errorMessage = "AIの返答を解析できませんでした。もう一度お試しください。"
                        return
                    }

                    results = list.filter { $0.groupId == group.id }
                    isLoading = false

                case .failure:
                    if attempt < maxAttempts {
                        let delay = Double.random(in: 0.2...0.5)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            runSearch(attempt: attempt + 1, maxAttempts: maxAttempts)
                        }
                        return
                    }
                    isLoading = false
                    errorMessage = "AI検索でエラーが発生しました。しばらくしてから再試行してください。"
                }
            }
        }
    }
}
