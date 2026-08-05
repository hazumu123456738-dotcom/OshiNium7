//
//  OpenTopicSearchView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI

// ★ 公開トークルーム一覧右上の虫眼鏡から開く検索。トークルームは既に一覧画面の
//   リスナーで全件ロード済みのため、Firestore側の全文検索は不要でクライアント側フィルタで足りる
struct OpenTopicSearchView: View {

    let group: IdolGroup
    @ObservedObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    private let accentColor = Color(red: 1.0, green: 0.45, blue: 0.42)
    private let accentColor2 = Color(red: 1.0, green: 0.70, blue: 0.30)

    private var results: [OpenTopic] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return chatViewModel.openTopics.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptyState(icon: "magnifyingglass", text: "話題のタイトルで、今あるトークルームを検索できます")
                } else if results.isEmpty {
                    emptyState(icon: "text.magnifyingglass", text: "「\(query)」に一致するトークルームが見つかりませんでした")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(results) { topic in
                                NavigationLink {
                                    OpenChatRoomView(group: group, topic: topic)
                                } label: {
                                    resultRow(topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("トークルームを検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear { isFocused = true }
    }

    // MARK: - 検索バー

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            TextField("知りたいことを入力", text: $query)
                .focused($isFocused)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .accessibilityLabel("検索文字をクリア")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .padding(16)
    }

    // MARK: - 検索結果の行

    private func resultRow(_ topic: OpenTopic) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("\(topic.messageCount)件の発言")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - 空状態

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.4))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
