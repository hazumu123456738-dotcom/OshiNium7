//
//  BlockedAndMutedUsersView.swift
//  OshiNium7
//

import SwiftUI
import NukeUI

// ★ 設定画面の「ブロックしたユーザー」「ミュートしたユーザー」から開く一覧。
//   どちらもuidの集合を取得して解除できるだけの、ほぼ同じ構造の画面なので
//   共通の中身(ModerationUserListContent)を1つ作り、文言と処理だけ差し替える

struct BlockedUsersListView: View {
    @EnvironmentObject var postViewModel: PostViewModel
    @State private var uids: Set<String> = []

    var body: some View {
        ModerationUserListContent(
            uids: uids,
            emptyMessage: "ブロックしたユーザーはいません",
            actionLabel: "解除する",
            action: { uid, completion in
                ModerationService.unblockUser(uid) { _ in
                    completion()
                    postViewModel.refreshBlockedUids()
                }
            }
        )
        .navigationTitle("ブロックしたユーザー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    private func reload() {
        ModerationService.fetchBlockedUids { uids = $0 }
    }
}

struct MutedUsersListView: View {
    @EnvironmentObject var postViewModel: PostViewModel
    @State private var uids: Set<String> = []

    var body: some View {
        ModerationUserListContent(
            uids: uids,
            emptyMessage: "ミュートしたユーザーはいません",
            actionLabel: "解除する",
            action: { uid, completion in
                ModerationService.unmuteUser(uid) { _ in
                    completion()
                    postViewModel.refreshMutedUids()
                }
            }
        )
        .navigationTitle("ミュートしたユーザー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
    }

    private func reload() {
        ModerationService.fetchMutedUids { uids = $0 }
    }
}

// MARK: - 共通の中身

private struct ModerationUserListContent: View {
    let uids: Set<String>
    let emptyMessage: String
    let actionLabel: String
    let action: (String, @escaping () -> Void) -> Void

    @State private var profiles: [String: ChatViewModel.RemoteUserProfile] = [:]
    @State private var removedUids: Set<String> = []
    @State private var toastMessage: String?

    private var sortedUids: [String] {
        Array(uids.subtracting(removedUids)).sorted()
    }

    var body: some View {
        Group {
            if sortedUids.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                        .accessibilityHidden(true)
                    Text(emptyMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)
            } else {
                List(sortedUids, id: \.self) { uid in
                    HStack(spacing: 12) {
                        if let iconURL = profiles[uid]?.iconURL, let url = URL(string: iconURL) {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Circle().fill(Color(.systemGray4))
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        } else {
                            Circle().fill(Color(.systemGray4)).frame(width: 36, height: 36)
                        }

                        Text(profiles[uid]?.displayName ?? "読み込み中…")
                            .font(.system(size: 14, weight: .semibold))

                        Spacer(minLength: 0)

                        Button(actionLabel) {
                            action(uid) {
                                removedUids.insert(uid)
                                withAnimation { toastMessage = "解除しました" }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                                    withAnimation { toastMessage = nil }
                                }
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                    }
                    .task {
                        guard profiles[uid] == nil else { return }
                        if let profile = await ChatViewModel.fetchUserProfile(uid: uid) {
                            profiles[uid] = profile
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let toastMessage {
                SimpleToast(text: toastMessage)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
