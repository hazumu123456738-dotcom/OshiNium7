//
//  UserSearchView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/19.
//

import SwiftUI
import NukeUI
import FirebaseFirestore
import FirebaseAuth

// ★ /ult監査(2026/08/18)で発見：オシニウムには他ユーザーを横断的に見つける手段が無く、
//   フォロー・DMへの導線がグループ内のプロフィール経由に限られていた（成長ループの
//   「他ユーザー発見」ステップが構造的に欠落していた）。
//   ★ 2026/08/19修正：当初はusersコレクション全体を横断検索していたが、
//   「グループに参加できるのは同じ推しを選んだメンバーのみ」という前提を崩し、
//   見ず知らずの他グループのユーザーまで発見・接触できてしまう設計だったため、
//   検索対象を「現在選択中のグループのメンバー」に限定するよう変更した
//   （groups/{groupId}/membersサブコレクションを検索。displayNameは
//   GroupViewModel.mirrorMembership/syncMemberProfileで非正規化済みのフィールドで、
//   単一フィールドのrange検索のためFirestoreの自動生成インデックスのみで動作する）
struct UserSearchResult: Identifiable {
    let uid: String
    let displayName: String
    let iconURL: String
    var id: String { uid }
}

enum UserSearchService {
    // ★ release-check(2026/08/20)で発見：以前はエラー時もcompletion([])だけを返していたため、
    //   呼び出し側では「本当に該当0件」と「通信/権限エラーで検索自体が失敗した」を区別できず、
    //   どちらも同じ「見つかりませんでした」表示になっていた。errorも呼び出し元へ渡すよう変更する
    static func search(query: String, groupId: String, excludingUid: String?, completion: @escaping ([UserSearchResult], Error?) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion([], nil)
            return
        }
        Firestore.firestore().collection("groups").document(groupId).collection("members")
            .whereField("displayName", isGreaterThanOrEqualTo: trimmed)
            .whereField("displayName", isLessThan: trimmed + "\u{f8ff}")
            .limit(to: 30)
            .getDocuments { snapshot, error in
                if let error {
                    print("🔥 UserSearchService search error:", error)
                    CrashReportManager.recordNonFatal(error)
                    completion([], error)
                    return
                }
                let results = (snapshot?.documents ?? []).compactMap { doc -> UserSearchResult? in
                    guard doc.documentID != excludingUid else { return nil }
                    let data = doc.data()
                    guard let displayName = data["displayName"] as? String, !displayName.isEmpty else { return nil }
                    return UserSearchResult(
                        uid: doc.documentID,
                        displayName: displayName,
                        iconURL: data["iconURL"] as? String ?? ""
                    )
                }
                completion(results, nil)
            }
    }
}

struct UserSearchView: View {
    let group: IdolGroup?

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var blockedUids: Set<String> = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private let accentColor = Color.oshiniumPrimary
    private var currentUid: String? { Auth.auth().currentUser?.uid }

    // ★ 自分がブロックしている相手は、検索結果からも見えないようにする
    //   （FollowListView.loadと同じ「表示だけの絞り込み」方針、[[feedback_block_scope_display_only]]）
    private var visibleResults: [UserSearchResult] {
        results.filter { !blockedUids.contains($0.uid) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(group.map { "\($0.name)のメンバーを検索" } ?? "ユーザーを検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            isFocused = true
            ModerationService.fetchBlockedUids { blockedUids = $0 }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    @ViewBuilder
    private var content: some View {
        if group == nil {
            emptyState(icon: "exclamationmark.triangle", text: "グループが選択されていません")
        } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emptyState(icon: "person.text.rectangle", text: "ユーザーネームで「\(group?.name ?? "")」のメンバーを探せます")
        } else if isSearching {
            Spacer()
            ProgressView()
            Spacer()
        } else if let errorMessage {
            emptyState(icon: "exclamationmark.triangle", text: errorMessage)
        } else if visibleResults.isEmpty {
            emptyState(icon: "person.crop.circle.badge.questionmark", text: "「\(query)」に一致するユーザーが見つかりませんでした")
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleResults) { result in
                        NavigationLink {
                            UserProfileView(uid: result.uid, fallbackName: result.displayName, fallbackIconURL: result.iconURL)
                        } label: {
                            userRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    private func userRow(_ result: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            if let url = URL(string: result.iconURL), !result.iconURL.isEmpty {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } else {
                        placeholderIcon(result.displayName)
                    }
                }
            } else {
                placeholderIcon(result.displayName)
            }

            Text(result.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func placeholderIcon(_ name: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [accentColor, Color.oshiniumPrimary2],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 46, height: 46)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - 検索バー

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(group.map { "\($0.name)のメンバーを検索" } ?? "ユーザーネームで検索", text: $query)
                .focused($isFocused)
                .submitLabel(.search)
                .onChange(of: query) { _, newValue in
                    scheduleSearch(for: newValue)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    errorMessage = nil
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

    // ★ Firestoreへのクエリを伴うため、投稿検索（クライアント側フィルタのみ）と違い
    //   1文字ごとに即座に検索すると通信量・読み取り課金が無駄に増える。300msのデバウンスを挟む
    private func scheduleSearch(for value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let groupId = group?.id else {
            results = []
            isSearching = false
            errorMessage = nil
            return
        }
        isSearching = true
        errorMessage = nil
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            UserSearchService.search(query: trimmed, groupId: groupId, excludingUid: currentUid) { found, error in
                Task { @MainActor in
                    guard !Task.isCancelled else { return }
                    results = found
                    // ★ 「該当0件」と「検索自体が失敗」を区別して表示する(release-check 2026/08/20)
                    errorMessage = error != nil ? "検索に失敗しました。通信環境をご確認のうえ、もう一度お試しください" : nil
                    isSearching = false
                }
            }
        }
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
