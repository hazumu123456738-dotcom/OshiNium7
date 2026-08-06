//
//  PostViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import Nuke

final class PostViewModel: ObservableObject {

    @Published private(set) var posts: [Post] = []

    private let db = Firestore.firestore()
    // ★ 「公開アカウントの投稿」と「自分の投稿（非公開でも常に見える）」を別々のクエリに
    //   分けて購読する。1本の絞り込み無しクエリのままだと、投稿者の非公開設定を
    //   ルール側でget()参照する必要があり、Firestoreのlistクエリの安全性の静的証明ができず
    //   購読そのものが丸ごと権限エラーになってしまうため（詳細はPostModel.authorIsPrivateのコメント）
    private var publicFeedListener: ListenerRegistration?
    private var ownPostsListener: ListenerRegistration?
    private var publicFeedPosts: [Post] = []
    private var ownPosts: [Post] = []
    // ★ 投稿一覧が更新されたら、画面に表示される前に画像をキャッシュへ先読みしておく
    //   （インスタのタイムラインのように、開いた瞬間に画像がすでに出ている状態にするため）
    private let imagePrefetcher = ImagePrefetcher()

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        publicFeedListener?.remove()
        ownPostsListener?.remove()
    }

    private var postsCollection: CollectionReference {
        db.collection("posts")
    }

    // MARK: - Firestore リアルタイム購読

    func startListeners() {
        publicFeedListener?.remove()
        ownPostsListener?.remove()

        publicFeedListener = postsCollection
            .whereField("authorIsPrivate", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("🔥 投稿購読エラー（公開フィード）:", error)
                    self.scheduleRetry()
                    return
                }
                self.publicFeedPosts = snapshot?.documents.compactMap { self.decodePost(doc: $0) } ?? []
                self.retryDelay = 1
                self.mergeAndPublish()
            }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        ownPostsListener = postsCollection
            .whereField("authorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("🔥 投稿購読エラー（自分の投稿）:", error)
                    return
                }
                self.ownPosts = snapshot?.documents.compactMap { self.decodePost(doc: $0) } ?? []
                self.mergeAndPublish()
            }
    }

    // ★ 自分が非公開アカウントの場合、自分の投稿は公開フィード側のクエリには載らないため
    //   自分の投稿クエリの結果とマージする（両方に載るケースはidで重複排除する）
    private func mergeAndPublish() {
        var merged: [String: Post] = [:]
        for post in publicFeedPosts { merged[post.id] = post }
        for post in ownPosts { merged[post.id] = post }
        let newPosts = merged.values.sorted { $0.createdAt > $1.createdAt }

        let imageURLs = newPosts
            .filter { $0.mediaType == "image" }
            .compactMap { $0.mediaURL }
            .compactMap { URL(string: $0) }
        imagePrefetcher.startPrefetching(with: imageURLs)

        DispatchQueue.main.async {
            self.posts = newPosts
        }
    }

    func stopListeners() {
        publicFeedListener?.remove()
        publicFeedListener = nil
        ownPostsListener?.remove()
        ownPostsListener = nil
    }

    private func scheduleRetry() {
        publicFeedListener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListeners()
        }
    }

    // MARK: - デコード

    private func decodePost(doc: QueryDocumentSnapshot) -> Post? {
        let data = doc.data()

        guard let authorUid = data["authorUid"] as? String,
              let groupId = data["groupId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return Post(
            id: doc.documentID,
            authorUid: authorUid,
            authorIsPrivate: data["authorIsPrivate"] as? Bool ?? false,
            groupId: groupId,
            groupName: data["groupName"] as? String ?? "",
            mediaURL: data["mediaURL"] as? String,
            mediaType: data["mediaType"] as? String,
            caption: data["caption"] as? String,
            packingTemplateName: data["packingTemplateName"] as? String,
            packingTemplateItems: data["packingTemplateItems"] as? [String],
            goodsKind: data["goodsKind"] as? String,
            goodsTitle: data["goodsTitle"] as? String,
            createdAt: createdAt,
            likedBy: data["likedBy"] as? [String] ?? [],
            commentCount: data["commentCount"] as? Int ?? 0
        )
    }

    // MARK: - 投稿作成

    // ★ Threadsのようにテキストのみの投稿もできるよう、mediaURL/mediaTypeは任意にしている
    func createPost(
        groupId: String,
        groupName: String,
        mediaURL: String?,
        mediaType: String?,
        caption: String?,
        authorUid: String,
        packingTemplateName: String? = nil,
        packingTemplateItems: [String]? = nil,
        goodsKind: String? = nil,
        goodsTitle: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        // ★ 投稿時点の非公開設定をそのまま投稿ドキュメントへ焼き込む（後から鍵垢に切り替えても
        //   既存の投稿の公開範囲は変わらない、Threads/Instagram等と同じ仕様）
        db.collection("users").document(authorUid).getDocument { [weak self] userSnapshot, _ in
            guard let self else { return }
            let isPrivate = userSnapshot?.data()?["isPrivateAccount"] as? Bool ?? false

            var data: [String: Any] = [
                "authorUid": authorUid,
                "authorIsPrivate": isPrivate,
                "groupId": groupId,
                "groupName": groupName,
                "createdAt": Timestamp(date: Date()),
                "likedBy": [String](),
                "commentCount": 0
            ]
            if let mediaURL { data["mediaURL"] = mediaURL }
            if let mediaType { data["mediaType"] = mediaType }
            if let caption, !caption.isEmpty {
                data["caption"] = caption
            }
            if let packingTemplateName, let packingTemplateItems, !packingTemplateItems.isEmpty {
                data["packingTemplateName"] = packingTemplateName
                data["packingTemplateItems"] = packingTemplateItems
            }
            if let goodsKind, let goodsTitle, !goodsTitle.isEmpty {
                data["goodsKind"] = goodsKind
                data["goodsTitle"] = goodsTitle
            }

            self.postsCollection.addDocument(data: data) { error in
                if let error = error {
                    print("🔥 createPost error:", error)
                }
                completion?(error)
            }
        }
    }

    // MARK: - 削除（自分の投稿のみ）

    func deletePost(_ post: Post) {
        postsCollection.document(post.id).delete { error in
            if let error = error {
                print("🔥 deletePost error:", error)
            }
        }
    }

    // MARK: - キャプション編集（自分の投稿のみ。画像・動画は変更不可）

    func updateCaption(_ post: Post, newCaption: String) {
        let trimmed = newCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        postsCollection.document(post.id).updateData(["caption": trimmed]) { error in
            if let error = error {
                print("🔥 updateCaption error:", error)
            }
        }
    }

    // MARK: - いいね切り替え

    func toggleLike(post: Post, uid: String) {
        let ref = postsCollection.document(post.id)
        if post.likedBy.contains(uid) {
            ref.updateData(["likedBy": FieldValue.arrayRemove([uid])])
        } else {
            ref.updateData(["likedBy": FieldValue.arrayUnion([uid])])
        }
    }

    // ★ 持ち物テンプレートの「お礼いいね」用。既にいいね済みなら何もしない
    //   （toggleLikeと違い、外すことはしない一方向の操作）
    func likeIfNotAlready(post: Post, uid: String) {
        guard !post.likedBy.contains(uid) else { return }
        postsCollection.document(post.id).updateData(["likedBy": FieldValue.arrayUnion([uid])])
    }

    // MARK: - フィルタ

    func postsForGroups(_ groupIds: Set<String>) -> [Post] {
        posts.filter { groupIds.contains($0.groupId) }
    }

    func posts(authorUid: String) -> [Post] {
        posts.filter { $0.authorUid == authorUid }
    }

    // ★ マイページの「いいね」統計タップ用。自分がいいねした投稿一覧（新しい順）
    func likedPosts(uid: String) -> [Post] {
        posts.filter { $0.likedBy.contains(uid) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - コミュニティ貢献者バッジ（アプリ全体での被いいね数 上位5%）
    //   ★ 本来は月末にサーバー側で集計してその月の結果を確定させるべきだが、このプロジェクトは
    //     Cloud Functionsのデプロイ環境をこのセッションから直接操作できないため、
    //     クライアント側で現在購読中の全投稿（postsはグループを問わずアプリ全体を購読している）
    //     から都度リアルタイムに集計する。人数が少ないうちは実質「即時集計」になる

    // ★ ユーザー(uid)がこれまでに受け取った、全投稿合計のいいね数
    func totalLikesReceived(uid: String) -> Int {
        posts.filter { $0.authorUid == uid }.reduce(0) { $0 + $1.likedBy.count }
    }

    // ★ 投稿を持つ全ユーザーを被いいね数の多い順に並べたとき、そのuidが上位5%以内に入るか。
    //   被いいねが1件も無いユーザーは対象外にする
    func isTopContributor(uid: String, topPercent: Double = 0.05) -> Bool {
        var totals: [String: Int] = [:]
        for post in posts {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        guard let myTotal = totals[uid], myTotal > 0 else { return false }

        let sorted = totals.values.sorted(by: >)
        let cutoffCount = max(1, Int((Double(sorted.count) * topPercent).rounded(.up)))
        let threshold = sorted[cutoffCount - 1]
        return myTotal >= threshold
    }

    // MARK: - 「推し活ペンライト・グッズ」ランキング・バッジ
    //   ★ 専用の投稿・コレクションは持たず、goodsKindが付いた通常の投稿をそのまま対象にする

    func goodsPosts(groupId: String) -> [Post] {
        posts.filter { $0.groupId == groupId && $0.goodsKind != nil }
    }

    // ★ 指定グループ内で、goods投稿の被いいね合計の多い順にユーザーを並べる
    func goodsRanking(groupId: String) -> [(uid: String, total: Int)] {
        var totals: [String: Int] = [:]
        for post in goodsPosts(groupId: groupId) {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        return totals.sorted { $0.value > $1.value }.map { (uid: $0.key, total: $0.value) }
    }

    // ★ どのグループでもよいので、そのuidが到達した最高順位のメダル種別を返す
    func bestGoodsBadge(uid: String) -> GoodsRankBadgeTier? {
        let groupIds = Set(posts.compactMap { $0.goodsKind != nil ? $0.groupId : nil })
        var best: GoodsRankBadgeTier?
        for groupId in groupIds {
            let ranked = goodsRanking(groupId: groupId)
            guard let index = ranked.firstIndex(where: { $0.uid == uid }), ranked[index].total > 0 else { continue }
            let tier: GoodsRankBadgeTier?
            switch index {
            case 0: tier = .gold
            case 1: tier = .silver
            case 2: tier = .bronze
            default: tier = nil
            }
            if let tier, tier.rank < (best?.rank ?? Int.max) {
                best = tier
            }
        }
        return best
    }
}
