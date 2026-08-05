//
//  PostCommentViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ 投稿へのコメント。posts/{postId}/commentsのサブコレクションに持つ
//   （ChatViewModelのgroups/{id}/messagesと同じ考え方）。
//   件数はPost側にcommentCountとして非正規化しており、追加・削除のたびに
//   バッチ書き込みでコメント本体とカウントを同時に更新する（Cloud Functions不要）
final class PostCommentViewModel: ObservableObject {

    @Published var comments: [PostComment] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    // MARK: - 購読

    func observeComments(postId: String) {
        listener?.remove()
        listener = db.collection("posts").document(postId).collection("comments")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("🔥 コメント購読エラー:", error)
                    self.scheduleRetry(postId: postId)
                    return
                }

                let loaded: [PostComment] = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    guard let authorUid = data["authorUid"] as? String,
                          let text = data["text"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    else { return nil }

                    return PostComment(
                        id: doc.documentID,
                        authorUid: authorUid,
                        authorName: data["authorName"] as? String ?? "名無しさん",
                        text: text,
                        createdAt: createdAt
                    )
                }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.comments = loaded
                }
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
        comments = []
    }

    private func scheduleRetry(postId: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.observeComments(postId: postId)
        }
    }

    // MARK: - 追加・削除（コメント本体とPost側のcommentCountを1回のバッチで同時更新）

    func addComment(postId: String, authorUid: String, authorName: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let commentRef = db.collection("posts").document(postId).collection("comments").document()
        let postRef = db.collection("posts").document(postId)

        let batch = db.batch()
        batch.setData([
            "authorUid": authorUid,
            "authorName": authorName,
            "text": trimmed,
            "createdAt": Timestamp(date: Date())
        ], forDocument: commentRef)
        batch.updateData(["commentCount": FieldValue.increment(Int64(1))], forDocument: postRef)

        batch.commit { error in
            if let error {
                print("🔥 addComment error:", error)
            }
        }
    }

    func deleteComment(postId: String, comment: PostComment) {
        let commentRef = db.collection("posts").document(postId).collection("comments").document(comment.id)
        let postRef = db.collection("posts").document(postId)

        let batch = db.batch()
        batch.deleteDocument(commentRef)
        batch.updateData(["commentCount": FieldValue.increment(Int64(-1))], forDocument: postRef)

        batch.commit { error in
            if let error {
                print("🔥 deleteComment error:", error)
            }
        }
    }
}
