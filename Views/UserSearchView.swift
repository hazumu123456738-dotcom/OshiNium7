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
//   「他ユーザー発見」ステップが構造的に欠落していた）。ユーザーネームの前方一致で
//   usersコレクションを検索できるようにする（単一フィールドのrange検索のため、
//   Firestoreの自動生成インデックスのみで動作し、追加のインデックス設定は不要）
struct UserSearchResult: Identifiable {
    let uid: String
    let displayName: String
    let bio: String
    let iconURL: String
    var id: String { uid }
}

enum UserSearchService {
    static func search(query: String, excludingUid: String?, completion: @escaping ([UserSearchResult]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion([])
            return
        }
        Firestore.firestore().collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: trimmed)
            .whereField("displayName", isLessThan: trimmed + "\u{f8ff}")
            .limit(to: 30)
            .getDocuments { snapshot, error in
                if let error {
                    print("🔥 UserSearchService search error:", error)
                    CrashReportManager.recordNonFatal(error)
                    completion([])
                    return
                }
                let results = (snapshot?.documents ?? []).compactMap { doc -> UserSearchResult? in
                    guard doc.documentID != excludingUid else { return nil }
                    let data = doc.data()
                    guard let displayName = data["displayName"] as? String, !displayName.isEmpty else { return nil }
                    return UserSearchResult(
                        uid: doc.documentID,
                        displayName: displayName,
                        bio: data["bio"] as? String ?? "",
                        iconURL: data["iconURL"] as? String ?? ""
                    )
                }
                completion(results)
            }
    }
}

struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var isSearching = false
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
            .navigationTitle("ユーザーを検索")
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
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            emptyState(icon: "person.text.rectangle", text: "ユーザーネームでオシニウムの他のユーザーを探せます")
        } else if isSearching {
            Spacer()
            ProgressView()
            Spacer()
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

            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                if !result.bio.isEmpty {
                    Text(result.bio)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

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

            TextField("ユーザーネームで検索", text: $query)
                .focused($isFocused)
                .submitLabel(.search)
                .onChange(of: query) { _, newValue in
                    scheduleSearch(for: newValue)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
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
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            UserSearchService.search(query: trimmed, excludingUid: currentUid) { found in
                Task { @MainActor in
                    guard !Task.isCancelled else { return }
                    results = found
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
