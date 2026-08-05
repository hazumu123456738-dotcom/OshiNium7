//
//  AIAddEventView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/12.
//

import SwiftUI

struct AIAddEventView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.customTabBarHeight) private var customTabBarHeight
    @EnvironmentObject var eventViewModel: EventViewModel

    let selectedGroup: IdolGroup?
    let defaultDate: Date

    @State private var inputText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var aiResults: [AIEventResult] = []
    @State private var navigateToList = false

    @FocusState private var isTextFocused: Bool

    private let maxCharacters = 100

    // ▼ 検索ヒント（今月・来月・今年を自動計算）
    private var searchHints: [String] {
        let calendar = Calendar.current
        let now = Date()

        let currentMonth = calendar.component(.month, from: now)
        let nextMonth = (currentMonth % 12) + 1
        let year = calendar.component(.year, from: now)

        func monthName(_ month: Int) -> String {
            "\(month)月"
        }

        let currentMonthName = monthName(currentMonth)
        let nextMonthName = monthName(nextMonth)

        return [
            "\(currentMonthName)のライブ予定",
            "\(nextMonthName)のライブ予定",
            "\(year)年の日本公演一覧",
            "\(currentMonthName)のイベント情報",
            "\(nextMonthName)のイベント情報",
            "今週のテレビ出演予定",
            "来週のテレビ出演予定",
            "\(currentMonthName)のファンミーティング情報",
            "\(nextMonthName)のファンミーティング情報",
            "\(currentMonthName)のリリース情報",
            "サイン会（日本）",
            "ショーケース（日本）",
            "フェス出演予定",
            "海外公演（アジア）"
        ]
    }

    var body: some View {
        ZStack {
            // 背景（上部グラデーション＋全体薄グレー）
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

                // MARK: - ナビゲーションバー
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                            )
                    }

                    Spacer()

                    Text("AI予定追加")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // MARK: - ヒーローエリア
                        VStack(spacing: 8) {
                            Text("AIが予定を検索します")
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text("知りたい情報を入力してください")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                        // MARK: - AIイラスト
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.78, green: 0.86, blue: 1.0),
                                            Color(red: 0.83, green: 0.76, blue: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

                            Image(systemName: "magnifyingglass.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color(red: 0.95, green: 0.96, blue: 1.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.top, 4)

                        // MARK: - 入力カード
                        VStack(alignment: .leading, spacing: 12) {
                            Text("知りたい予定を入力")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.appCardBackground)
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

                                VStack(alignment: .leading, spacing: 8) {
                                    TextEditor(text: $inputText)
                                        .focused($isTextFocused)
                                        .frame(minHeight: 120, maxHeight: 160)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    isTextFocused
                                                    ? LinearGradient(
                                                        colors: [
                                                            Color(red: 0.70, green: 0.80, blue: 1.0),
                                                            Color(red: 0.80, green: 0.70, blue: 1.0)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                    : LinearGradient(
                                                        colors: [Color(.systemGray4)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    ),
                                                    lineWidth: isTextFocused ? 1.5 : 1
                                                )
                                        )
                                        .onChange(of: inputText) { newValue in
                                            if newValue.count > maxCharacters {
                                                inputText = String(newValue.prefix(maxCharacters))
                                            }
                                        }
                                        .overlay(
                                            Group {
                                                if inputText.isEmpty {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("今後のライブ予定")
                                                        Text("ファンミーティング情報")
                                                        Text("テレビ出演予定")
                                                        Text("リリース情報")
                                                        Text("サイン会情報")
                                                    }
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Color.gray.opacity(0.6))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 12)
                                                }
                                            },
                                            alignment: .topLeading
                                        )

                                    HStack {
                                        Spacer()
                                        Text("\(inputText.count) / \(maxCharacters)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 4)
                                }
                                .padding(12)
                            }

                            Text("※現在ホーム画面で選択しているグループの情報のみ検索できます。\n※他グループの情報は検索対象になりません。")
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray.opacity(0.8))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)

                        // MARK: - 検索ヒントエリア（タップ無効化）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("検索のポイント（例）")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)

                            FlexibleChipsView(
                                items: searchHints,
                                onTap: { _ in
                                    // 完全無効化
                                }
                            )
                        }
                        .padding(.horizontal, 24)

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                                .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }

                // MARK: - AI解析ボタン（画面下部固定）
                VStack {
                    Button {
                        runAI()
                    } label: {
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.48, blue: 1.0),
                                    Color(red: 0.66, green: 0.33, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 60)
                            .cornerRadius(30)
                            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("✨")
                                }

                                Text(isLoading ? "解析中です…" : "AIに検索してもらう")
                                    .foregroundColor(.white)
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        // ★ このNavigationStackは自作の下タブバー分の安全域を引き継がないため、
                        //   環境値で受け取ったタブバーの高さを明示的に足して、タブバーの裏に
                        //   隠れないようにする
                        .padding(.bottom, 12 + customTabBarHeight)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                }
                .background(
                    Color(red: 0.98, green: 0.98, blue: 0.99)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToList) {
            AIAddEventResultListView(
                eventViewModel: eventViewModel,
                results: aiResults,
                selectedGroup: selectedGroup,
                defaultDate: defaultDate
            )
        }
    }

    // MARK: - AI解析処理
    private func runAI() {
        if isLoading { return }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let group = selectedGroup else {
            self.errorMessage = "グループ情報が取得できませんでした"
            return
        }

        errorMessage = nil
        isLoading = true

        runAIInternal(
            query: trimmed,
            group: group,
            attempt: 1,
            maxAttempts: 8
        )
    }

    // MARK: - 503対応：超高速リトライ内部処理
    private func runAIInternal(
        query: String,
        group: IdolGroup,
        attempt: Int,
        maxAttempts: Int
    ) {
        let groupId = group.id

        SearchGroundingService.shared.searchEvents(
            query: query,
            groupName: group.name,
            groupId: groupId
        ) { result in
            DispatchQueue.main.async {

                switch result {

                case .success(let jsonString):

                    if jsonString == "[]" {

                        if attempt < maxAttempts {

                            if attempt <= 3 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.runAIInternal(
                                        query: query,
                                        group: group,
                                        attempt: attempt + 1,
                                        maxAttempts: maxAttempts
                                    )
                                }
                                return
                            }

                            let delay = Double.random(in: 0.1...0.3)
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.runAIInternal(
                                    query: query,
                                    group: group,
                                    attempt: attempt + 1,
                                    maxAttempts: maxAttempts
                                )
                            }
                            return
                        }

                        self.isLoading = false
                        self.errorMessage = "AIが混雑しています。しばらくしてから再試行してください"
                        return
                    }

                    guard let list = AIEventResult.list(from: jsonString) else {
                        self.isLoading = false
                        self.errorMessage = "AIの返したJSONを解析できませんでした"
                        return
                    }

                    let filtered = list.filter { $0.groupId == groupId }

                    if filtered.isEmpty {
                        self.isLoading = false
                        self.errorMessage = "該当するイベントは見つかりませんでした"
                        return
                    }

                    self.aiResults = filtered
                    self.isLoading = false
                    self.navigateToList = true

                case .failure:

                    if attempt < maxAttempts {

                        let delay = Double.random(in: 0.1...0.3)
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.runAIInternal(
                                query: query,
                                group: group,
                                attempt: attempt + 1,
                                maxAttempts: maxAttempts
                            )
                        }
                        return
                    }

                    self.isLoading = false
                    self.errorMessage = "AI解析エラーが発生しました"
                }
            }
        }
    }

    // MARK: - チップレイアウト用ビュー
    struct FlexibleChipsView: View {
        let items: [String]
        let onTap: (String) -> Void

        var body: some View {
            let columns = [
                GridItem(.adaptive(minimum: 140), spacing: 8)
            ]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { text in
                    Button {
                        onTap(text)
                    } label: {
                        Text(text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.20, green: 0.30, blue: 0.60))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.90, green: 0.94, blue: 1.0),
                                                Color(red: 0.93, green: 0.90, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
