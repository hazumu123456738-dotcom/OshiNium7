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

    // 仮のおすすめグループ（後で Firestore に差し替え）
    let recommendedGroups: [IdolGroup] = [
        IdolGroup(id: "1", name: "NewJeans", imageData: nil),
        IdolGroup(id: "2", name: "IVE", imageData: nil),
        IdolGroup(id: "3", name: "LE SSERAFIM", imageData: nil)
    ]

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

                    // MARK: - おすすめのグループ
                    sectionTitle("おすすめのグループ")

                    VStack(spacing: 12) {
                        ForEach(recommendedGroups) { group in
                            RecommendedGroupRowView(group: group)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .navigationTitle("グループ")
        }
    }

    // MARK: - 検索バー
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("グループを検索", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - 新規グループ作成カード
    private var createGroupCard: some View {
        NavigationLink {
            NewGroupView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .foregroundColor(.black)
                        .font(.title3)
                }

                Text("新しいグループを作成")
                    .font(.headline)
                    .foregroundColor(.black)

                Spacer()
            }
            .padding()
            .background(Color.white)
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
