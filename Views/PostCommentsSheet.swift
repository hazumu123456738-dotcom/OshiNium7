//
//  PostCommentsSheet.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import SwiftUI
import FirebaseAuth
import NukeUI

struct PostCommentsSheet: View {
    let post: Post

    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @StateObject private var commentVM = PostCommentViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var profileCache: [String: ChatViewModel.RemoteUserProfile] = [:]
    @State private var reportTarget: PostComment?

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)
    private var currentUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                commentList
                inputBar
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("コメント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            commentVM.observeComments(postId: post.id)
        }
        .onDisappear {
            commentVM.stopObserving()
        }
        .confirmationDialog(
            "このコメントを報告しますか？",
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(["スパム・宣伝", "嫌がらせ・誹謗中傷", "不適切な内容", "その他"], id: \.self) { reason in
                Button(reason) {
                    if let comment = reportTarget {
                        ModerationService.reportPostComment(
                            postId: post.id,
                            commentId: comment.id,
                            commentText: comment.text,
                            authorUid: comment.authorUid,
                            reason: reason
                        )
                    }
                    reportTarget = nil
                }
            }
            Button("キャンセル", role: .cancel) { reportTarget = nil }
        }
    }

    // MARK: - コメント一覧

    @ViewBuilder
    private var commentList: some View {
        if commentVM.comments.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 34))
                    .foregroundColor(.gray.opacity(0.4))
                Text("まだコメントがありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(commentVM.comments) { comment in
                        commentRow(comment)
                    }
                }
                .padding(16)
            }
        }
    }

    private func commentRow(_ comment: PostComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(for: comment)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(liveAuthorName(for: comment))
                        .font(.system(size: 13, weight: .semibold))
                    Text(relativeTime(comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .task {
            await loadProfileIfNeeded(for: comment.authorUid)
        }
        .contextMenu {
            if comment.authorUid == currentUid {
                Button(role: .destructive) {
                    commentVM.deleteComment(postId: post.id, comment: comment)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } else {
                Button {
                    reportTarget = comment
                } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    // ★ タップでそのコメント投稿者のプロフィールに遷移できるようにする
    private func avatar(for comment: PostComment) -> some View {
        NavigationLink {
            UserProfileView(
                uid: comment.authorUid,
                fallbackName: liveAuthorName(for: comment),
                fallbackIconURL: profileCache[comment.authorUid]?.iconURL
            )
        } label: {
            avatarImage(for: comment)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(liveAuthorName(for: comment))さんのプロフィール")
    }

    @ViewBuilder
    private func avatarImage(for comment: PostComment) -> some View {
        if let iconURL = profileCache[comment.authorUid]?.iconURL, let url = URL(string: iconURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder(for: comment)
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
        } else {
            avatarPlaceholder(for: comment)
        }
    }

    private func avatarPlaceholder(for comment: PostComment) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 30, height: 30)
            .overlay(
                Text(String(liveAuthorName(for: comment).prefix(1)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func liveAuthorName(for comment: PostComment) -> String {
        profileCache[comment.authorUid]?.displayName ?? comment.authorName
    }

    private func loadProfileIfNeeded(for uid: String) async {
        guard profileCache[uid] == nil else { return }
        if let profile = await ChatViewModel.fetchUserProfile(uid: uid) {
            profileCache[uid] = profile
        }
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("コメントを入力", text: $inputText, axis: .vertical)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...4)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray.opacity(0.4)
                        : accentColor
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.appCardBackground
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3)
        )
    }

    private func send() {
        guard let uid = currentUid else { return }
        let name = settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName
        commentVM.addComment(postId: post.id, authorUid: uid, authorName: name, text: inputText)
        inputText = ""
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
