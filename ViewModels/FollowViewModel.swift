//
//  FollowViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ 非公開アカウントへのフォローリクエスト。ドキュメントIDはfollows同様
//   "{fromUid}_{toUid}"で一意に決まる
struct FollowRequest: Identifiable, Equatable {
    let id: String
    let fromUid: String
    let toUid: String
    let fromName: String
    let fromIconURL: String?
    let createdAt: Date
}

// ★ フォロー関係。ドキュメントIDは "{followerUid}_{followingUid}" で一意に決まるので、
//   二重フォローの心配がなく、フォロー解除も1件のdeleteで済む。
final class FollowViewModel: ObservableObject {

    // ★ 自分がフォローしているuidの集合
    @Published private(set) var followingIds: Set<String> = []
    // ★ 自分をフォローしているuidの集合
    @Published private(set) var followerIds: Set<String> = []
    // ★ 自分が送った、まだ承認されていないフォローリクエストの相手uid集合
    @Published private(set) var outgoingRequestIds: Set<String> = []
    // ★ 自分宛てに届いている、まだ判断していないフォローリクエスト一覧
    @Published private(set) var incomingRequests: [FollowRequest] = []

    private let db = Firestore.firestore()
    private var followingListener: ListenerRegistration?
    private var followerListener: ListenerRegistration?
    private var outgoingRequestListener: ListenerRegistration?
    private var incomingRequestListener: ListenerRegistration?
    private var myUid: String?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        followingListener?.remove()
        followerListener?.remove()
        outgoingRequestListener?.remove()
        incomingRequestListener?.remove()
    }

    private var followsCollection: CollectionReference {
        db.collection("follows")
    }

    private var requestsCollection: CollectionReference {
        db.collection("followRequests")
    }

    private func docId(follower: String, following: String) -> String {
        "\(follower)_\(following)"
    }

    private func decodeRequest(_ doc: QueryDocumentSnapshot) -> FollowRequest? {
        let data = doc.data()
        guard let fromUid = data["fromUid"] as? String,
              let toUid = data["toUid"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }
        return FollowRequest(
            id: doc.documentID,
            fromUid: fromUid,
            toUid: toUid,
            fromName: data["fromName"] as? String ?? "名無しさん",
            fromIconURL: data["fromIconURL"] as? String,
            createdAt: createdAt
        )
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

        outgoingRequestListener?.remove()
        outgoingRequestListener = requestsCollection
            .whereField("fromUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 followRequest(outgoing)購読エラー:", error)
                    return
                }
                let ids = Set((snapshot?.documents ?? []).compactMap { $0.data()["toUid"] as? String })
                DispatchQueue.main.async { self.outgoingRequestIds = ids }
            }

        incomingRequestListener?.remove()
        incomingRequestListener = requestsCollection
            .whereField("toUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 followRequest(incoming)購読エラー:", error)
                    return
                }
                let requests = (snapshot?.documents ?? []).compactMap { self.decodeRequest($0) }
                DispatchQueue.main.async { self.incomingRequests = requests.sorted { $0.createdAt > $1.createdAt } }
            }
    }

    func stopListening() {
        followingListener?.remove()
        followerListener?.remove()
        outgoingRequestListener?.remove()
        incomingRequestListener?.remove()
        followingListener = nil
        followerListener = nil
        outgoingRequestListener = nil
        incomingRequestListener = nil
        outgoingRequestIds = []
        incomingRequests = []
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
    func hasRequested(_ uid: String) -> Bool { outgoingRequestIds.contains(uid) }

    // MARK: - フォロー / フォロー解除

    func follow(myUid: String, targetUid: String, myName: String, myIconURL: String?) {
        guard myUid != targetUid else { return }
        let id = docId(follower: myUid, following: targetUid)
        let data: [String: Any] = [
            "followerUid": myUid,
            "followingUid": targetUid,
            "createdAt": Timestamp(date: Date())
        ]
        // ★ 2026/08/15修正：以前は書き込みの完了を待たずに通知を発火しており、
        //   Firestore書き込みが実際には失敗した場合でも「フォローされました」という
        //   通知が相手に届いてしまっていた。成功時のみ通知するよう完了クロージャ内に移動する
        followsCollection.document(id).setData(data) { error in
            if let error {
                print("🔥 follow error:", error)
                return
            }

            AppNotificationViewModel.notifyFollow(
                recipientUid: targetUid,
                actorUid: myUid,
                actorName: myName,
                actorIconURL: myIconURL
            )
        }
    }

    func unfollow(myUid: String, targetUid: String) {
        let id = docId(follower: myUid, following: targetUid)
        followsCollection.document(id).delete { error in
            if let error {
                print("🔥 unfollow error:", error)
            }
        }
    }

    // MARK: - 非公開アカウントへのフォローリクエスト

    // ★ 非公開アカウントの相手には即座にfollowsを作らず、フォローリクエストを送るだけにする。
    //   相手が承認して初めてfollows（実際のフォロー関係）が作られる
    func requestFollow(myUid: String, targetUid: String, myName: String, myIconURL: String?) {
        guard myUid != targetUid else { return }
        let id = docId(follower: myUid, following: targetUid)
        var data: [String: Any] = [
            "fromUid": myUid,
            "toUid": targetUid,
            "fromName": myName,
            "createdAt": Timestamp(date: Date())
        ]
        if let myIconURL, !myIconURL.isEmpty { data["fromIconURL"] = myIconURL }
        requestsCollection.document(id).setData(data) { error in
            if let error {
                print("🔥 requestFollow error:", error)
            }
        }

        AppNotificationViewModel.notifyFollowRequest(
            recipientUid: targetUid,
            actorUid: myUid,
            actorName: myName,
            actorIconURL: myIconURL
        )
    }

    // ★ 送った側からリクエストを取り消す（相手が判断する前に気が変わった場合）
    func cancelFollowRequest(myUid: String, targetUid: String) {
        let id = docId(follower: myUid, following: targetUid)
        requestsCollection.document(id).delete { error in
            if let error {
                print("🔥 cancelFollowRequest error:", error)
            }
        }
    }

    // ★ 承認：実際のfollowsドキュメントを作り、リクエストは削除する。
    //   myName/myIconURLは承認する本人（＝リクエスト受信者）自身のプロフィール。
    //   ★ この2つの書き込みは同じバッチにまとめて原子的に行う。別々のリクエストにすると、
    //   「followsの作成」を許可するルール側のexists()チェック（下のfirestore.rules参照）が、
    //   タイミング次第では削除済みのfollowRequestsを見て失敗する可能性があるため
    func acceptFollowRequest(_ request: FollowRequest, myName: String, myIconURL: String?) {
        let id = docId(follower: request.fromUid, following: request.toUid)
        let batch = db.batch()
        batch.setData([
            "followerUid": request.fromUid,
            "followingUid": request.toUid,
            "createdAt": Timestamp(date: Date())
        ], forDocument: followsCollection.document(id))
        batch.deleteDocument(requestsCollection.document(request.id))
        batch.commit { error in
            if let error {
                print("🔥 acceptFollowRequest error:", error)
            }
        }

        AppNotificationViewModel.notifyFollowRequestAccepted(
            recipientUid: request.fromUid,
            actorUid: request.toUid,
            actorName: myName,
            actorIconURL: myIconURL
        )
    }

    // ★ 拒否：リクエストを削除するだけ（Instagramと同様、拒否したことは相手に通知しない）
    func declineFollowRequest(_ request: FollowRequest) {
        requestsCollection.document(request.id).delete { error in
            if let error {
                print("🔥 declineFollowRequest error:", error)
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
