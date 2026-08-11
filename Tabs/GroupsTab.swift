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
    @State private var showGroupLimitReached = false
    @State private var leaveCooldownDaysRemaining: Int?
    @State private var showPremiumUpgrade = false

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

    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

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
                                    groupViewModel.addGroup(group) { error in
                                        if let error, case GroupCreationError.groupLimitReached = error {
                                            showGroupLimitReached = true
                                        } else if let error, case GroupCreationError.leaveCooldownActive(let daysRemaining) = error {
                                            leaveCooldownDaysRemaining = daysRemaining
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("グループ")
            .navigationBarTitleDisplayMode(.inline)
            // ★ このタブはマイページから.sheetで開かれることが多く、スワイプでの
            //   ジェスチャー以外に閉じる手段が無いと「戻れない」と感じてしまうため、
            //   明示的な閉じるボタンを用意する
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.appCardBackground))
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("閉じる")
                }
            }
        }
        .onAppear {
            groupViewModel.loadCatalog()
        }
        .alert("推しグループの上限に達しました", isPresented: $showGroupLimitReached) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text("無課金では推しグループを2件まで登録できます。プレミアムにアップグレードすると5件まで登録できます。")
        }
        .alert("少し待ってください", isPresented: Binding(
            get: { leaveCooldownDaysRemaining != nil },
            set: { if !$0 { leaveCooldownDaysRemaining = nil } }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text(GroupCreationError.leaveCooldownActive(daysRemaining: leaveCooldownDaysRemaining ?? 0).errorDescription ?? "")
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    // MARK: - 検索バー
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor.opacity(0.7))
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accentColor.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
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
                        .fill(
                            LinearGradient(colors: [accentColor, accentColor2],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("新しいグループを作成")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Text("すでに登録されている場合はそのグループに参加します")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(0.12), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - セクションタイトル
    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(
                    LinearGradient(colors: [accentColor, accentColor2],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 3, height: 14)
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .padding(.horizontal, 16)
    }
}
