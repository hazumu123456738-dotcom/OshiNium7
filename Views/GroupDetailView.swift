//
//  GroupDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/19.
//

import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel

    @State private var localGroup: IdolGroup
    @State private var isSearchingAI = false
    @State private var aiSearchFailed = false
    @State private var showEdit = false

    init(group: IdolGroup) {
        _localGroup = State(initialValue: group)
    }

    private let accentColor = Color.oshiniumPrimary

    // 詳細が1つでもあるかどうか
    private var hasDetail: Bool {
        localGroup.concept != nil ||
        localGroup.history != nil ||
        localGroup.groupDescription != nil
    }

    // ★ 自分が参加しているグループだけ、AI自動入力（＝自分の手元データの更新）を許可する
    private var isOwnGroup: Bool {
        groupViewModel.groups.contains(where: { $0.id == localGroup.id })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                heroCard

                if hasDetail {
                    infoCard {
                        HStack(spacing: 28) {
                            labeledValue(label: "読み方", value: localGroup.reading)
                            labeledValue(label: "ファンダム名", value: localGroup.fandom)
                            Spacer()
                        }
                    }

                    infoCard {
                        sectionBlock(icon: "sparkles", title: "コンセプト", text: localGroup.concept)
                    }

                    infoCard {
                        sectionBlock(icon: "clock.arrow.circlepath", title: "歴史", text: localGroup.history)
                    }

                    infoCard {
                        sectionBlock(icon: "text.alignleft", title: "説明", text: localGroup.groupDescription)
                    }
                } else {
                    emptyDetailCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(localGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnGroup {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        GroupMemberManagementView(group: localGroup)
                    } label: {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(accentColor)
                    }
                    .accessibilityLabel("メンバー管理")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(accentColor)
                    }
                    .accessibilityLabel("グループ情報を編集")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                GroupDetailEditView(group: localGroup)
            }
        }
        // ★ グループ作成直後はAIによる自動調査がバックグラウンドで走っている最中のことがあるため、
        //   Firestoreの最新データ（groupViewModel.groups）が更新されたら手動操作なしで画面に反映する。
        //   IdolGroup.== はidだけを見る実装なので、onChangeではなく毎回発火するonReceiveを使う。
        .onReceive(groupViewModel.$groups) { updated in
            if let latest = updated.first(where: { $0.id == localGroup.id }) {
                localGroup = latest
            }
        }
    }

    // MARK: - 詳細未設定時のカード（AI自動入力）
    private var emptyDetailCard: some View {
        infoCard {
            VStack(spacing: 12) {
                Text("このグループはまだ詳細カードが設定されていません。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isOwnGroup {
                    Button {
                        runAISearch()
                    } label: {
                        HStack(spacing: 6) {
                            if isSearchingAI {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isSearchingAI ? "AIが調べています…" : "AIで自動入力")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [accentColor, Color.oshiniumPrimary2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .disabled(isSearchingAI)

                    if aiSearchFailed {
                        Text("情報が見つかりませんでした。もう一度試すか、右上の編集ボタンから手入力してください。")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }

                    Button {
                        showEdit = true
                    } label: {
                        Text("自分で入力する")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
    }

    private func runAISearch() {
        guard !isSearchingAI else { return }
        isSearchingAI = true
        aiSearchFailed = false

        Task {
            let result = await GroupInfoSearchService.shared.searchGroupInfo(groupName: localGroup.name)

            await MainActor.run {
                isSearchingAI = false

                guard let result,
                      (result.reading ?? result.fandom ?? result.concept ?? result.history ?? result.groupDescription) != nil
                else {
                    aiSearchFailed = true
                    return
                }

                localGroup.reading = result.reading
                localGroup.fandom = result.fandom
                localGroup.concept = result.concept
                localGroup.history = result.history
                localGroup.groupDescription = result.groupDescription

                groupViewModel.updateGroup(localGroup)
            }
        }
    }

    // MARK: - Heroカード
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = localGroup.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackHero
            }

            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                startPoint: .bottom,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 6) {
                if let fandom = localGroup.fandom, !fandom.isEmpty {
                    Text(fandom)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.25))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                Text(localGroup.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(20)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private var fallbackHero: some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.85), Color.oshiniumPrimary2.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(localGroup.name.prefix(1)))
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: - 共通カード
    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

            content()
                .padding(16)
        }
    }

    // ★ AIが確証を持てず空にした項目や未入力の項目は、適当な作り話で埋めず「特になし」と
    //   はっきり表示する。ユーザーが後から編集ボタンで正しい情報に書き換えられるようにするため。
    private func labeledValue(label: String, value: String?) -> some View {
        let resolved = value.nonEmptyOrNil
        return VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(resolved ?? "特になし")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(resolved == nil ? .secondary.opacity(0.7) : .primary)
        }
    }

    private func sectionBlock(icon: String, title: String, text: String?) -> some View {
        let resolved = text.nonEmptyOrNil
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(resolved ?? "特になし")
                .font(.system(size: 14))
                .foregroundColor(resolved == nil ? .secondary.opacity(0.7) : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
