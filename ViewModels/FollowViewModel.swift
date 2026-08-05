//
//  FollowViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ フォロー関係。ドキュメントIDは "{followerUid}_{followingUid}" で一意に決まるので、
//   二重フォローの心配がなく、フォロー解除も1件のdeleteで済む。
final class FollowViewModel: ObservableObject {

    // ★ 自分がフォローしているuidの集合
    @Published private(set) var followingIds: Set<String> = []
    // ★ 自分をフォローしているuidの集合
    @Published private(set) var followerIds: Set<String> = []

    private let db = Firestore.firestore()
    private var followingListener: ListenerRegistration?
    private var followerListener: ListenerRegistration?
    private var myUid: String?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        followingListener?.remove()
        followerListener?.remove()
    }

    private var followsCollection: CollectionReference {
        db.collection("follows")
    }

    private func docId(follower: String, following: String) -> String {
        "\(follower)_\(following)"
    }

    // MARK: - 自分のフォロー関係の購読

    func startListening(uid: String) {
        guard myUid != uid else { return }
        myUid = uid
        followingListener?.remove()
        followerListener?.remove()

        followingListener = followsCollection
            .whereField("followerUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 follow(following)購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }
                let ids = Set((snapshot?.documents ?? []).compactMap { $0.data()["followingUid"] as? String })
                DispatchQueue.main.async { self.followingIds = ids }
            }

        followerListener = followsCollection
            .whereField("followingUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 follow(follower)購読エラー:", error)
                    return
                }
                let ids = Set((snapshot?.documents ?? []).compactMap { $0.data()["followerUid"] as? String })
                DispatchQueue.main.async { self.followerIds = ids }
            }
    }

    func stopListening() {
        followingListener?.remove()
        followerListener?.remove()
        followingListener = nil
        followerListener = nil
        myUid = nil
        followingIds = []
        followerIds = []
    }

    private func scheduleRetry(uid: String) {
        followingListener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        myUid = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListening(uid: uid)
        }
    }

    // MARK: - 判定ヘルパー

    func isFollowing(_ uid: String) -> Bool { followingIds.contains(uid) }
    func isFollower(_ uid: String) -> Bool { followerIds.contains(uid) }
    func isMutual(_ uid: String) -> Bool { isFollowing(uid) && isFollower(uid) }

    // MARK: - フォロー / フォロー解除

    func follow(myUid: String, targetUid: String, myName: String, myIconURL: String?) {
        guard myUid != targetUid else { return }
        let id = docId(follower: myUid, following: targetUid)
        let data: [String: Any] = [
            "followerUid": myUid,
            "followingUid": targetUid,
            "createdAt": Timestamp(date: Date())
        ]
        followsCollection.document(id).setData(data) { error in
            if let error {
                print("🔥 follow error:", error)
            }
        }

        AppNotificationViewModel.notifyFollow(
            recipientUid: targetUid,
            actorUid: myUid,
            actorName: myName,
            actorIconURL: myIconURL
        )
    }

    func unfollow(myUid: String, targetUid: String) {
        let id = docId(follower: myUid, following: targetUid)
        followsCollection.document(id).delete { error in
            if let error {
                print("🔥 unfollow error:", error)
            }
        }
    }

    // MARK: - 他ユーザーのフォロー数・一覧（プロフィール閲覧用の単発取得）

    static func fetchCounts(for uid: String) async -> (followers: Int, following: Int) {
        let db = Firestore.firestore()
        async let followersSnap = try? db.collection("follows").whereField("followingUid", isEqualTo: uid).getDocuments()
        async let followingSnap = try? db.collection("follows").whereField("followerUid", isEqualTo: uid).getDocuments()
        let (f, g) = await (followersSnap, followingSnap)
        return (f?.documents.count ?? 0, g?.documents.count ?? 0)
    }

    // ★ kind: "followers"（このuidをフォローしている人） / "following"（このuidがフォローしている人）
    //   等号1つだけのクエリにして複合インデックスが不要なようにし、並び替えはクライアント側で行う
    static func fetchUids(for uid: String, kind: String) async -> [String] {
        let db = Firestore.firestore()
        let field = kind == "followers" ? "followingUid" : "followerUid"
        let targetField = kind == "followers" ? "followerUid" : "followingUid"
        guard let snapshot = try? await db.collection("follows")
            .whereField(field, isEqualTo: uid)
            .getDocuments()
        else { return [] }
        let sorted = snapshot.documents.sorted {
            let a = ($0.data()["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
            let b = ($1.data()["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
            return a > b
        }
        return sorted.compactMap { $0.data()[targetField] as? String }
    }
}
