//
//  SharePostSheet.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI
import NukeUI
import FirebaseAuth

// ★ Instagramの「送信」のように、フォロー中の相手のアイコンをタップするだけで
//   その投稿をDMとして手軽にシェアできるようにする。従来のOSの共有シート（ShareLink）は
//   「その他の方法で共有」として残し、外部アプリへの共有もそのまま使えるようにする
struct SharePostSheet: View {
    let post: Post
    let shareText: String

    @EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @StateObject private var dmViewModel = DirectMessageViewModel()
    @State private var profiles: [String: ChatViewModel.RemoteUserProfile] = [:]
    @State private var sentUids: Set<String> = []

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    // ★ フォロー中の相手を「シェアしやすい相手」として一覧に出す
    private var targetUids: [String] {
        followViewModel.followingIds.subtracting([currentUid ?? ""]).sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if targetUids.isEmpty {
                    emptyState
                } else {
                    List(targetUids, id: \.self) { uid in
                        row(for: uid)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("シェア")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                ShareLink(item: shareText) {
                    Label("その他の方法でシェア", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            Capsule().fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                        )
                }
                .padding(16)
                .background(Color.appCardBackground.shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.4))
                .accessibilityHidden(true)
            Text("フォロー中のユーザーがいません")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("下の「その他の方法でシェア」から共有できます")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for uid: String) -> some View {
        HStack(spacing: 12) {
            avatarView(uid: uid)

            Text(profiles[uid]?.displayName ?? "…")
                .font(.system(size: 15, weight: .semibold))

            Spacer(minLength: 0)

            if sentUids.contains(uid) {
                Label("DMで送信済み", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            } else {
                Button {
                    send(to: uid)
                } label: {
                    Text("送信")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await loadProfileIfNeeded(uid)
        }
    }

    @ViewBuilder
    private func avatarView(uid: String) -> some View {
        if let iconURL = profiles[uid]?.iconURL, let url = URL(string: iconURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder(uid: uid)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            avatarPlaceholder(uid: uid)
        }
    }

    private func avatarPlaceholder(uid: String) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String((profiles[uid]?.displayName ?? "?").prefix(1)))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func loadProfileIfNeeded(_ uid: String) async {
        guard profiles[uid] == nil else { return }
        if let profile = await ChatViewModel.fetchUserProfile(uid: uid) {
            profiles[uid] = profile
        }
    }

    private func send(to uid: String) {
        guard let myUid = currentUid else { return }
        let threadId = DMThread.threadId(myUid, uid)
        let name = settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName
        dmViewModel.sendMessage(
            threadId: threadId,
            participants: [myUid, uid],
            text: shareText,
            senderUid: myUid,
            senderName: name,
            imageURL: post.mediaURL,
            mediaType: post.mediaType
        )
        AnalyticsManager.logSharePostSent(groupId: post.groupId)
        withAnimation(.easeInOut(duration: 0.15)) {
            _ = sentUids.insert(uid)
        }
    }
}
