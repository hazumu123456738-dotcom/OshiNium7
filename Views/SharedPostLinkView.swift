//
//  SharedPostLinkView.swift
//  OshiNium7
//

import SwiftUI
import FirebaseFirestore

// ★ https://oshinium-79256.web.app/p/<postId> のUniversal Link・oshinium://post?id=<postId>の
//   カスタムスキームの両方から辿り着く、投稿単体の表示。DM経由でこのアプリのユーザーに送った場合は
//   SharedPostCardView（DirectMessageThreadView内）がタップだけで直接プロフィールへ飛ぶため
//   ここは経由しないが、外部（メモ・LINE等）に貼り付けたリンクを開いた場合はここが入口になる。
//   通常のタイムライン(PostFeedCard)と違い、投稿を1件だけ直接document(postId)で取得する必要があるため
//   専用の軽量な取得ロジックを持つ
struct SharedPostLinkView: View {
    let postId: String

    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var savedPostViewModel: SavedPostViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var post: Post?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let post {
                    ScrollView(showsIndicators: false) {
                        PostFeedCard(post: post)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
            }
        }
        .task {
            await loadPost()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "exclamationmark.bubble")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
                .accessibilityHidden(true)
            Text("この投稿は見つかりませんでした")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("削除されたか、閲覧できる権限がない可能性があります")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func loadPost() async {
        do {
            let snapshot = try await Firestore.firestore().collection("posts").document(postId).getDocument()
            if let data = snapshot.data(), let fetched = PostViewModel.decodePost(id: snapshot.documentID, data: data) {
                post = fetched
            }
        } catch {
            // ★ 取得失敗時はpostがnilのままなのでbody側のemptyStateがそのまま出る
        }
        isLoading = false
    }
}
