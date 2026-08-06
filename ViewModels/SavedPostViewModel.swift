//
//  SavedPostViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ 投稿の「保存（ブックマーク）」。ドキュメントIDは"{uid}_{postId}"で一意に決まるので、
//   二重保存の心配がなく、保存解除も1件のdeleteで済む（FollowViewModelと同じ構成）
final class SavedPostViewModel: ObservableObject {

    @Published private(set) var savedPostIds: Set<String> = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var myUid: String?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var savedCollection: CollectionReference {
        db.collection("savedPosts")
    }

    private func docId(uid: String, postId: String) -> String {
        "\(uid)_\(postId)"
    }

    func startListening(uid: String) {
        guard myUid != uid else { return }
        myUid = uid
        listener?.remove()

        listener = savedCollection
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 savedPosts購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }
                let ids = Set((snapshot?.documents ?? []).compactMap { $0.data()["postId"] as? String })
                self.retryDelay = 1
                DispatchQueue.main.async { self.savedPostIds = ids }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        myUid = nil
    }

    private func scheduleRetry(uid: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.myUid = nil
            self?.startListening(uid: uid)
        }
    }

    func isSaved(_ postId: String) -> Bool {
        savedPostIds.contains(postId)
    }

    // MARK: - 保存・解除

    func toggleSave(post: Post, uid: String) {
        let id = docId(uid: uid, postId: post.id)
        if savedPostIds.contains(post.id) {
            savedCollection.document(id).delete()
        } else {
            savedCollection.document(id).setData([
                "uid": uid,
                "postId": post.id,
                "groupId": post.groupId,
                "createdAt": Timestamp(date: Date())
            ])
        }
    }
}
