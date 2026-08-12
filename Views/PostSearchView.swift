//
//  PostSearchView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/31.
//

import SwiftUI

// ★ ホーム画面右上の虫眼鏡から開く投稿検索。選択中グループの投稿を対象に、
//   キャプションの文字列でクライアント側フィルタする（投稿は既にリスナーで
//   全件ロード済みのため、Firestore側の全文検索は不要）
struct PostSearchView: View {

    let selectedGroup: IdolGroup?
    // ★ 投稿中の「#〇〇」タップから開いた場合、そのタグを検索欄に入れた状態で開く
    var initialQuery: String = ""

    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    private let accentColor = Color.oshiniumPrimary

    private var groupPosts: [Post] {
        guard let selectedGroup else { return [] }
        return postViewModel.postsForGroups([selectedGroup.id])
    }

    // ★ 「#グッズ」「#ペンライト」「持ち物テンプレート」は、投稿本文の文字列ではなく
    //   ツールと連動した構造化フィールド（goodsKind・packingTemplateItems）で絞り込む
    //   仮想タグ。キャプションに実際にその文字列を書いていなくても、そのツールから
    //   投稿されたものは確実にヒットするようにする
    private var results: [Post] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed == "#グッズ" || trimmed == "#ペンライト" {
            let kind = String(trimmed.dropFirst())
            return groupPosts.filter { $0.goodsKind == kind }
        }
        if trimmed == "持ち物テンプレート" {
            return groupPosts.filter { $0.packingTemplateItems?.isEmpty == false }
        }

        return groupPosts.filter {
            ($0.caption ?? "").localizedCaseInsensitiveContains(trimmed) ||
            ($0.goodsTitle ?? "").localizedCaseInsensitiveContains(trimmed) ||
            ($0.packingTemplateName ?? "").localizedCaseInsensitiveContains(trimmed)
        }
    }

    // ★ そのグループに実際にそのツール由来の投稿がある時だけ候補として出す
    private var toolLinkedSuggestions: [(label: String, icon: String)] {
        var items: [(String, String)] = []
        if groupPosts.contains(where: { $0.goodsKind == "ペンライト" }) {
            items.append(("#ペンライト", "flashlight.on.fill"))
        }
        if groupPosts.contains(where: { $0.goodsKind == "グッズ" }) {
            items.append(("#グッズ", "gift.fill"))
        }
        if groupPosts.contains(where: { $0.packingTemplateItems?.isEmpty == false }) {
            items.append(("持ち物テンプレート", "checklist"))
        }
        return items
    }

    // ★ このグループの投稿から使われているハッシュタグを頻度順に拾い、
    //   検索欄が空のときに「よく使われるタグ」として一覧できるようにする
    private var popularHashtags: [String] {
        var counts: [String: Int] = [:]
        for post in groupPosts {
            guard let caption = post.caption else { continue }
            for tag in HashtagParser.extractHashtags(from: caption) {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.map(\.key)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if popularHashtags.isEmpty && toolLinkedSuggestions.isEmpty {
                        emptyState(
                            icon: "magnifyingglass",
                            text: selectedGroup.map { "\($0.name)の投稿をキャプションで検索できます" }
                                ?? "グループが選択されていません"
                        )
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                if !toolLinkedSuggestions.isEmpty {
                                    toolLinkedSuggestionsSection
                                }
                                if !popularHashtags.isEmpty {
                                    popularHashtagsSection
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } else if results.isEmpty {
                    emptyState(icon: "text.magnifyingglass", text: "「\(query)」に一致する投稿が見つかりませんでした")
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(results) { post in
                                PostFeedCard(post: post)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("投稿を検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            if !initialQuery.isEmpty {
                query = initialQuery
            }
            isFocused = true
        }
    }

    // MARK: - よく使われるハッシュタグ（検索欄が空のときに、タップで検索できる候補として出す）

    private var popularHashtagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("よく使われるハッシュタグ")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(popularHashtags, id: \.self) { tag in
                    Button {
                        query = tag
                    } label: {
                        Text(tag)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(accentColor.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - ツールと連動した候補（#グッズ・#ペンライト・持ち物テンプレート）
    //   ★ そのグループに実際に該当する投稿がある時だけ、キャプションの文字列に頼らず
    //     構造化フィールドで確実にヒットする候補として出す

    private var toolLinkedSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ツールの投稿から探す")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            HStack(spacing: 8) {
                ForEach(toolLinkedSuggestions, id: \.label) { suggestion in
                    Button {
                        query = suggestion.label
                    } label: {
                        Label(suggestion.label, systemImage: suggestion.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.60, green: 0.45, blue: 0.90), Color(red: 0.85, green: 0.50, blue: 0.85)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 検索バー

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("キャプションで検索", text: $query)
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
