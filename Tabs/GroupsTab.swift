//
//  GroupsTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI

struct GroupsTab: View {

    @EnvironmentObject var groupViewModel: GroupViewModel

    @State private var searchText = ""

    // ★ 全ユーザー共通カタログ（/groups）から、自分がまだ参加していないグループを抽出する
    //   ★ 招待制のグループチャット（isPrivate）は検索・参加導線には出さない。招待リンクを
    //     知っている人だけが参加できる仕組みにするため
    private var browsableCatalog: [IdolGroup] {
        let joinedIds = Set(groupViewModel.groups.map { $0.id })
        let notJoined = groupViewModel.catalog.filter { !joinedIds.contains($0.id) && !$0.isPrivate }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notJoined }

        return notJoined.filter { group in
            group.name.localizedCaseInsensitiveContains(trimmed)
                || (group.reading?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (group.fandom?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - 検索バー
                    searchBar

                    // MARK: - 新規グループ作成カード
                    createGroupCard

                    // MARK: - 参加中のグループ
                    if !groupViewModel.groups.isEmpty {
                        sectionTitle("参加中のグループ")

                        VStack(spacing: 12) {
                            ForEach(groupViewModel.groups) { group in
                                GroupRowView(group: group)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // MARK: - みんなの推しグループ（共通カタログ）
                    sectionTitle(searchText.isEmpty ? "みんなの推しグループ" : "検索結果")

                    if groupViewModel.isLoadingCatalog && groupViewModel.catalog.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else if browsableCatalog.isEmpty {
                        Text(
                            searchText.isEmpty
                                ? "他のグループはまだ登録されていません"
                                : "「\(searchText)」に一致するグループが見つかりませんでした"
                        )
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(browsableCatalog) { group in
                                RecommendedGroupRowView(group: group) {
                                    groupViewModel.addGroup(group)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .navigationTitle("グループ")
        }
        .onAppear {
            groupViewModel.loadCatalog()
        }
    }

    // MARK: - 検索バー
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .accessibilityHidden(true)

            TextField("グループを検索", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .accessibilityLabel("検索文字をクリア")
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 新規グループ作成カード
    private var createGroupCard: some View {
        NavigationLink {
            NewGroupView { _ in
                groupViewModel.loadCatalog()
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                        .font(.title3)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("新しいグループを作成")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("すでに登録されている場合はそのグループに参加します")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.appCardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - セクションタイトル
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 16)
    }
}
