//
//  GoodsPostDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import SwiftUI
import NukeUI
import FirebaseAuth

// ★ ショーケースのカードをタップした時の、1件のペンライト・グッズ投稿の詳細表示。
//   通常の投稿と完全に同じPostのため、いいね・削除も既存のPostViewModelをそのまま使う
struct GoodsPostDetailView: View {
    let post: Post

    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var isLiked: Bool {
        guard let currentUid else { return false }
        return post.likedBy.contains(currentUid)
    }
    private var isMine: Bool { currentUid == post.authorUid }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                LazyImage(url: URL(string: post.mediaURL ?? "")) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.goodsTitle ?? "")
                            .font(.system(size: 17, weight: .bold))
                        Text("\(post.groupName)・\(post.goodsKind ?? "")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if let caption = post.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }

                likeButton
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(post.goodsTitle ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isMine {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("この投稿を削除")
                }
            }
        }
        .confirmationDialog(
            "この投稿を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                postViewModel.deletePost(post)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private var likeButton: some View {
        Button {
            guard let currentUid else { return }
            postViewModel.toggleLike(post: post, uid: currentUid)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? Color(red: 0.95, green: 0.35, blue: 0.55) : .secondary)
                Text("\(post.likedBy.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "いいね済み" : "いいね")
        .accessibilityValue("\(post.likedBy.count)件")
    }
}
