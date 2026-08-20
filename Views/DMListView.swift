//
//  DMListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import FirebaseAuth
import NukeUI

// ★ DM一覧画面。相互フォローのユーザーとしかDMを開始できないようにする
//   （本音を言いやすくするための投稿・口コミの匿名機能とは違い、DMは知り合い同士の
//     やり取りなので、お互いフォローし合っている関係に限定する）
//   ※ クライアント側でのガードに加えて、Firestoreセキュリティルール側でも
//     「参加者2人が相互フォローしていない限りdmThreadsへの書き込みを拒否する」設定を
//     別途行うことを推奨（このプロジェクトはCloud Functions/ルールのデプロイ環境が
//     このセッションから直接操作できないため、アプリ側の制御のみ実装している）
struct DMListView: View {

    // ★ 通常のDM一覧（相互フォロー）と、メッセージリクエスト一覧（相互フォローでない相手との
    //   スレッド）は、チャットタブ側で別々のタブ（グループ／DM／DMリクエスト）として分離されている。
    //   このビュー自身はどちらの一覧を出すかをmodeで受け取るだけにする
    enum Mode {
        case normal
        case requests
    }

    var mode: Mode = .normal

    @EnvironmentObject var followViewModel: FollowViewModel
    @StateObject private var threadListVM = DMThreadListViewModel()

    @State private var mutualProfiles: [(uid: String, name: String, iconURL: String?)] = []
    @State private var threadProfiles: [String: (name: String, iconURL: String?)] = [:]
    // ★ 2026/08/20（oshiスキル監査で発見）：自分がブロックしている相手のスレッドが
    //   一覧に残ったまま（最新メッセージのプレビュー付きで）表示されていた。
    //   FollowListView/PostCommentsSheet等、他の一覧画面と同じ「表示だけの絞り込み」
    //   （[[feedback_block_scope_display_only]]）をここにも揃える
    @State private var blockedUids: Set<String> = []

    private let accentColor = Color.oshiniumPrimary
    private var myUid: String? { Auth.auth().currentUser?.uid }
    private var mutualUids: Set<String> {
        followViewModel.followingIds.intersection(followViewModel.followerIds).subtracting(blockedUids)
    }

    // ★ 相互フォローでない相手とのスレッドは「メッセージリクエスト」タブに分離する
    //   （コミュニティのグループチャットから相互ではない相手にメッセージを送った場合など）
    private var normalThreads: [DMThread] {
        threadListVM.threads.filter { thread in
            guard let myUid, let other = thread.otherUid(myUid: myUid), !blockedUids.contains(other) else { return false }
            return followViewModel.isMutual(other)
        }
    }
    private var requestThreads: [DMThread] {
        threadListVM.threads.filter { thread in
            guard let myUid, let other = thread.otherUid(myUid: myUid), !blockedUids.contains(other) else { return false }
            return !followViewModel.isMutual(other)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if mode == .normal {
                    if !mutualProfiles.isEmpty {
                        newMessageSection
                    }
                    threadsSection
                } else {
                    requestsOnlySection
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .refreshable {
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        .onAppear {
            if let myUid { threadListVM.startListening(uid: myUid) }
            ModerationService.fetchBlockedUids { blockedUids = $0 }
        }
        .onDisappear {
            threadListVM.stopListening()
        }
        .task(id: mutualUids) {
            await loadMutualProfiles()
        }
        .task(id: threadListVM.threads.map(\.id)) {
            await loadThreadProfiles()
        }
    }

    // MARK: - 新しいメッセージ（相互フォローのユーザーのみ）

    private var newMessageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("新しいメッセージ（相互フォロー）")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(mutualProfiles, id: \.uid) { profile in
                        NavigationLink {
                            DirectMessageThreadView(otherUid: profile.uid, otherName: profile.name, otherIconURL: profile.iconURL)
                        } label: {
                            VStack(spacing: 6) {
                                avatarView(name: profile.name, iconURL: profile.iconURL, size: 56)
                                Text(profile.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .frame(width: 60)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - メッセージリクエスト一覧（相互フォローでない相手とのDM。別タブとして独立表示）

    @ViewBuilder
    private var requestsOnlySection: some View {
        if requestThreads.isEmpty {
            requestsEmptyState
        } else {
            VStack(spacing: 10) {
                ForEach(requestThreads) { thread in
                    threadRow(thread, isRequest: true)
                }
            }
        }
    }

    private var requestsEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.4))
            Text("メッセージリクエストはありません")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - スレッド一覧（相互フォロー）

    @ViewBuilder
    private var threadsSection: some View {
        if normalThreads.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(normalThreads) { thread in
                    threadRow(thread)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "message")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.4))
            Text(mutualProfiles.isEmpty ? "相互フォローのユーザーとDMができます\nまずはフォローし合ってみましょう" : "まだDMはありません")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func threadRow(_ thread: DMThread, isRequest: Bool = false) -> some View {
        guard let myUid, let otherUid = thread.otherUid(myUid: myUid) else {
            return AnyView(EmptyView())
        }
        let profile = threadProfiles[otherUid]
        let name = profile?.name ?? "名無しさん"

        return AnyView(
            threadRowContent(thread, otherUid: otherUid, name: name, profile: profile, isRequest: isRequest)
                .contextMenu {
                    Button(role: .destructive) {
                        threadListVM.deleteThread(thread)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
        )
    }

    private func threadRowContent(
        _ thread: DMThread,
        otherUid: String,
        name: String,
        profile: (name: String, iconURL: String?)?,
        isRequest: Bool
    ) -> some View {
        Group {
            NavigationLink {
                DirectMessageThreadView(otherUid: otherUid, otherName: name, otherIconURL: profile?.iconURL)
            } label: {
                HStack(spacing: 12) {
                    avatarView(name: name, iconURL: profile?.iconURL, size: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            if isRequest {
                                Text("リクエスト")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                            }
                        }
                        Text(thread.lastMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text(relativeTime(thread.lastMessageAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func avatarView(name: String, iconURL: String?, size: CGFloat) -> some View {
        if let iconURL, let url = URL(string: iconURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    avatarPlaceholder(name: name, size: size)
                }
            }
        } else {
            avatarPlaceholder(name: name, size: size)
        }
    }

    private func avatarPlaceholder(name: String, size: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [accentColor, Color.oshiniumPrimary2],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - 読み込み

    private func loadMutualProfiles() async {
        var loaded: [(uid: String, name: String, iconURL: String?)] = []
        for uid in mutualUids {
            let profile = await ChatViewModel.fetchUserProfile(uid: uid)
            loaded.append((uid, profile?.displayName ?? "名無しさん", profile?.iconURL))
        }
        await MainActor.run { self.mutualProfiles = loaded }
    }

    private func loadThreadProfiles() async {
        guard let myUid else { return }
        var updated = threadProfiles
        for thread in threadListVM.threads {
            guard let otherUid = thread.otherUid(myUid: myUid), updated[otherUid] == nil else { continue }
            if let profile = await ChatViewModel.fetchUserProfile(uid: otherUid) {
                updated[otherUid] = (profile.displayName, profile.iconURL)
            }
        }
        await MainActor.run { self.threadProfiles = updated }
    }
}
