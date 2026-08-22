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
    // ★ 2026/08/21発見：ログイン直後、Firestoreリスナーが最初のスナップショットを
    //   受け取るまでのごく数秒間、postsが空配列のままになる。この間、HomeView側は
    //   「まだ投稿がありません」という“本当に0件”の空状態と見分けが付かず表示していたため、
    //   ユーザーから「ログインしたら投稿が全部消えた」という報告につながった
    //   （実際にはデータは消えておらず、単なる初回読み込み中の一瞬をそう見せていただけ）。
    //   GroupViewModel.hasLoadedGroupsOnceと同じパターンで「読み込み未完了」と
    //   「読み込み済みで実際に0件」を区別できるようにする
    @Published private(set) var hasLoadedPostsOnce = false
    private var hasLoadedPublicFeedOnce = false
    private var hasLoadedOwnPostsOnce = false

    private let db = Firestore.firestore()
    // ★ 「公開アカウントの投稿」と「自分の投稿（非公開でも常に見える）」を別々のクエリに
    //   分けて購読する。1本の絞り込み無しクエリのままだと、投稿者の非公開設定を
    //   ルール側でget()参照する必要があり、Firestoreのlistクエリの安全性の静的証明ができず
    //   購読そのものが丸ごと権限エラーになってしまうため（詳細はPostModel.authorIsPrivateのコメント）
    private var publicFeedListener: ListenerRegistration?
    private var ownPostsListener: ListenerRegistration?
    // ★ 2026/08/16（/moneyスキル監査）：以前はここに上限が無く、アプリを開くたびに
    //   「公開設定の投稿を全件」リアルタイム購読していた。これはユーザー数×投稿総数に
    //   比例して読み取りコストが増える設計で、投稿総数自体もユーザー数の増加とともに
    //   増えるため、実質ユーザー数の2乗でコストが増加する（数百人規模でも月額が
    //   跳ね上がる試算になった）。RankingView/UserProfileView（他グループを跨いだ
    //   「いいねした投稿」統計）等、postsをグループ横断で参照する既存機能を壊さない
    //   範囲で、まずは直近N件に上限を設けてコストの青天井化を防ぐ。将来的に投稿数が
    //   この上限に実際に近づいてきたら、グループ単位の絞り込みクエリへ分割する
    private let publicFeedLimit = 1000
    private let ownPostsLimit = 500
    private var publicFeedPosts: [Post] = []
    private var ownPosts: [Post] = []
    // ★ 投稿一覧が更新されたら、画面に表示される前に画像をキャッシュへ先読みしておく
    //   （インスタのタイムラインのように、開いた瞬間に画像がすでに出ている状態にするため）
    private let imagePrefetcher = ImagePrefetcher()

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    // ★ ミュートした相手の投稿はタイムラインから丸ごと除外する（相手には気づかれない）。
    //   ブロックと違いFirestoreルール側での制御は不要（自分だけの表示上の絞り込みのため）
    private var mutedUids: Set<String> = [] {
        didSet { mergeAndPublish() }
    }

    // ★ 2026/08/14追加：ブロックした相手の投稿もタイムライン・つぶやきから丸ごと除外する。
    //   ミュートと同じ「自分だけの表示上の絞り込み」だが、ブロックは「その人のコンテンツを
    //   一切見たくない」という強い意思表示のため、ミュートとは別に明示的に持たせる
    private var blockedUids: Set<String> = [] {
        didSet { mergeAndPublish() }
    }

    func refreshMutedUids() {
        ModerationService.fetchMutedUids { [weak self] uids in
            DispatchQueue.main.async {
                self?.mutedUids = uids
            }
        }
    }

    func refreshBlockedUids() {
        ModerationService.fetchBlockedUids { [weak self] uids in
            DispatchQueue.main.async {
                self?.blockedUids = uids
            }
        }
    }

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
        refreshMutedUids()
        refreshBlockedUids()

        // ★ startListeners()はログイン・ログアウトのたびに呼ばれ得るため、
        //   毎回リセットしないと前回セッションの「読み込み済み」状態を引きずってしまう
        hasLoadedPostsOnce = false
        hasLoadedPublicFeedOnce = false
        hasLoadedOwnPostsOnce = false

        publicFeedListener = postsCollection
            .whereField("authorIsPrivate", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .limit(to: publicFeedLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("🔥 投稿購読エラー（公開フィード）:", error)
                    self.scheduleRetry()
                    return
                }
                self.publicFeedPosts = snapshot?.documents.compactMap { self.decodePost(doc: $0) } ?? []
                self.retryDelay = 1
                self.hasLoadedPublicFeedOnce = true
                self.markLoadedIfReady()
                self.mergeAndPublish()
            }

        guard let uid = Auth.auth().currentUser?.uid else {
            // ★ 自分の投稿クエリを組み立てられない(ログイン前等)場合、公開フィード側の
            //   初回読み込みだけを待てば良い状態にしておく。そうしないと存在しない
            //   ownPostsListenerの完了を永遠に待ち続け、hasLoadedPostsOnceが
            //   trueにならないまま「読み込み中」表示が固まってしまう
            markLoadedIfReady()
            return
        }
        ownPostsListener = postsCollection
            .whereField("authorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: ownPostsLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("🔥 投稿購読エラー（自分の投稿）:", error)
                    return
                }
                self.ownPosts = snapshot?.documents.compactMap { self.decodePost(doc: $0) } ?? []
                self.hasLoadedOwnPostsOnce = true
                self.markLoadedIfReady()
                self.mergeAndPublish()
            }
    }

    // ★ 公開フィード・自分の投稿の両方の初回スナップショットが揃って初めて
    //   「読み込み完了」とみなす(片方だけだと、まだ来ていない方のデータが
    //   反映される前にfalseの空表示が一瞬出てしまう)
    private func markLoadedIfReady() {
        if ownPostsListener == nil && Auth.auth().currentUser == nil {
            hasLoadedPostsOnce = hasLoadedPublicFeedOnce
        } else {
            hasLoadedPostsOnce = hasLoadedPublicFeedOnce && hasLoadedOwnPostsOnce
        }
    }

    // ★ 自分が非公開アカウントの場合、自分の投稿は公開フィード側のクエリには載らないため
    //   自分の投稿クエリの結果とマージする（両方に載るケースはidで重複排除する）
    private func mergeAndPublish() {
        var merged: [String: Post] = [:]
        for post in publicFeedPosts { merged[post.id] = post }
        for post in ownPosts { merged[post.id] = post }
        let newPosts = merged.values
            .filter { !mutedUids.contains($0.authorUid) && !blockedUids.contains($0.authorUid) }
            .sorted { $0.createdAt > $1.createdAt }

        // ★ データ通信節約モード（設定画面「🎨 アプリ」）がONの間は、まだ画面に出ていない
        //   画像まで先読みするのをやめ、実際にスクロールで表示されたタイミングでだけ読み込む
        //   ★ 2026/08/17（/moneyスキル監査）：以前はnewPosts全件（上限追加後でも最大1000件超）分の
        //   画像URLを、Firestoreの差分更新のたび（いいね1件の変動等でも）に毎回まるごと
        //   先読みし直していた。実際に画面に表示されるのは選択中グループの直近数十件程度なので、
        //   直近の投稿だけに絞る（それ以外の画像はNukeの通常のスクロール時読み込みに任せる。
        //   先読みは体感速度のための最適化であり、これを絞っても表示自体は変わらない）
        if !UserDefaults.standard.bool(forKey: "dataSaverModeEnabled") {
            let imageURLs = newPosts
                .prefix(40)
                .filter { $0.mediaType == "image" }
                .compactMap { $0.mediaURL }
                .compactMap { URL(string: $0) }
            imagePrefetcher.startPrefetching(with: imageURLs)
        }

        DispatchQueue.main.async {
            self.posts = newPosts
        }
    }

    func stopListeners() {
        publicFeedListener?.remove()
        publicFeedListener = nil
        ownPostsListener?.remove()
        ownPostsListener = nil
        hasLoadedPostsOnce = false
        hasLoadedPublicFeedOnce = false
        hasLoadedOwnPostsOnce = false
    }

    private func scheduleRetry() {
        publicFeedListener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.startListeners() }
        }
    }

    // MARK: - デコード

    private func decodePost(doc: QueryDocumentSnapshot) -> Post? {
        Self.decodePost(id: doc.documentID, data: doc.data())
    }

    // ★ 共有リンク(SharedPostLinkView)からdocument(postId)を単発取得する場合にも
    //   同じデコードロジックを使い回せるよう、インスタンスに依存しない形で切り出す
    static func decodePost(id: String, data: [String: Any]) -> Post? {
        guard let authorUid = data["authorUid"] as? String,
              let groupId = data["groupId"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return Post(
            id: id,
            authorUid: authorUid,
            authorIsPrivate: data["authorIsPrivate"] as? Bool ?? false,
            groupId: groupId,
            groupName: data["groupName"] as? String ?? "",
            mediaURL: data["mediaURL"] as? String,
            mediaType: data["mediaType"] as? String,
            mediaItems: (data["mediaItems"] as? [[String: Any]])?.compactMap { item in
                guard let url = item["url"] as? String, let type = item["type"] as? String else { return nil }
                return PostMediaItem(url: url, type: type)
            },
            caption: data["caption"] as? String,
            packingTemplateName: data["packingTemplateName"] as? String,
            packingTemplateItems: data["packingTemplateItems"] as? [String],
            goodsKind: data["goodsKind"] as? String,
            goodsTitle: data["goodsTitle"] as? String,
            expenseAmount: data["expenseAmount"] as? Int,
            expenseCategory: data["expenseCategory"] as? String,
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
        mediaItems: [PostMediaItem]? = nil,
        caption: String?,
        authorUid: String,
        packingTemplateName: String? = nil,
        packingTemplateItems: [String]? = nil,
        goodsKind: String? = nil,
        goodsTitle: String? = nil,
        expenseAmount: Int? = nil,
        expenseCategory: String? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        // ★ 2026/08/18追加（ユーザー報告：予定保存フリーズと同根）：以前はgetDocument→
        //   addDocumentの2段階どちらにも応答確認の上限が無く、通信が不安定だと
        //   「投稿しています…」のまま無期限に固まって見えていた。全体を1つの
        //   タイムアウト付き処理としてまとめる
        Task {
            let error = await NetworkMonitor.awaitWithTimeout { done in
                self.performCreatePost(
                    groupId: groupId, groupName: groupName, mediaURL: mediaURL, mediaType: mediaType,
                    mediaItems: mediaItems, caption: caption, authorUid: authorUid,
                    packingTemplateName: packingTemplateName, packingTemplateItems: packingTemplateItems,
                    goodsKind: goodsKind, goodsTitle: goodsTitle,
                    expenseAmount: expenseAmount, expenseCategory: expenseCategory,
                    completion: done
                )
            }
            await MainActor.run { completion?(error) }
        }
    }

    private func performCreatePost(
        groupId: String,
        groupName: String,
        mediaURL: String?,
        mediaType: String?,
        mediaItems: [PostMediaItem]?,
        caption: String?,
        authorUid: String,
        packingTemplateName: String?,
        packingTemplateItems: [String]?,
        goodsKind: String?,
        goodsTitle: String?,
        expenseAmount: Int?,
        expenseCategory: String?,
        completion: @escaping (Error?) -> Void
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
            if let mediaItems, mediaItems.count > 1 {
                data["mediaItems"] = mediaItems.map { ["url": $0.url, "type": $0.type] }
            }
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
            if let expenseAmount, let expenseCategory, !expenseCategory.isEmpty {
                data["expenseAmount"] = expenseAmount
                data["expenseCategory"] = expenseCategory
            }

            self.postsCollection.addDocument(data: data) { error in
                if let error = error {
                    print("🔥 createPost error:", error)
                    CrashReportManager.recordNonFatal(error)
                }
                completion(error)
            }
        }
    }

    // MARK: - 削除（自分の投稿のみ）

    func deletePost(_ post: Post, completion: ((Error?) -> Void)? = nil) {
        // ★ 2026/08/21修正：Firestoreの.delete(completion:)はサーバー確認後に呼ばれ、
        //   スナップショットリスナー経由の画面更新もそれを待って発生するため、
        //   タップしてから画面に反映されるまでにワンテンポ体感の遅延があった。
        //   postsから即座に取り除く（楽観的更新）ことで、タップと同時に画面から消えるようにする。
        //   万が一失敗した場合は元の状態に戻す
        let previousPosts = posts
        posts.removeAll { $0.id == post.id }
        postsCollection.document(post.id).delete { [weak self] error in
            if let error = error {
                print("🔥 deletePost error:", error)
                CrashReportManager.recordNonFatal(error)
                self?.posts = previousPosts
            }
            completion?(error)
        }
    }

    // MARK: - キャプション編集（自分の投稿のみ。画像・動画は変更不可）

    func updateCaption(_ post: Post, newCaption: String, completion: ((Error?) -> Void)? = nil) {
        let trimmed = newCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        // ★ 2026/08/21修正：deletePostと同じ理由。サーバー確認を待たず、
        //   postsの該当投稿のcaptionを即座に書き換える（楽観的更新）。
        //   タイムライン・マイページどちらも同じpostsを参照しているため、
        //   これだけで画面上の表示が保存操作と同時に切り替わる。失敗時は元に戻す
        let previousPosts = posts
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].caption = trimmed
        }
        postsCollection.document(post.id).updateData(["caption": trimmed]) { [weak self] error in
            if let error = error {
                print("🔥 updateCaption error:", error)
                CrashReportManager.recordNonFatal(error)
                self?.posts = previousPosts
            }
            completion?(error)
        }
    }

    // MARK: - いいね切り替え

    // ★ actorName/actorIconURLは「いいねした本人」の表示名・アイコン。呼び出し側（View）が
    //   すでにUserSettingsViewModelで持っている自分の情報をそのまま渡す（FollowViewModel.follow等と同じ形）
    func toggleLike(post: Post, uid: String, actorName: String = "", actorIconURL: String? = nil) {
        let ref = postsCollection.document(post.id)
        if post.likedBy.contains(uid) {
            ref.updateData(["likedBy": FieldValue.arrayRemove([uid])])
        } else {
            ref.updateData(["likedBy": FieldValue.arrayUnion([uid])])
            AppNotificationViewModel.notifyPostLike(
                recipientUid: post.authorUid, actorUid: uid, actorName: actorName, actorIconURL: actorIconURL, postId: post.id
            )
        }
    }

    // ★ 持ち物テンプレートの「お礼いいね」用。既にいいね済みなら何もしない
    //   （toggleLikeと違い、外すことはしない一方向の操作）
    func likeIfNotAlready(post: Post, uid: String, actorName: String = "", actorIconURL: String? = nil) {
        guard !post.likedBy.contains(uid) else { return }
        postsCollection.document(post.id).updateData(["likedBy": FieldValue.arrayUnion([uid])])
        AppNotificationViewModel.notifyPostLike(
            recipientUid: post.authorUid, actorUid: uid, actorName: actorName, actorIconURL: actorIconURL, postId: post.id
        )
    }

    // MARK: - フィルタ

    func postsForGroups(_ groupIds: Set<String>) -> [Post] {
        posts.filter { groupIds.contains($0.groupId) }
    }

    func posts(authorUid: String) -> [Post] {
        posts.filter { $0.authorUid == authorUid }
    }

    // ★ 2026/08/17追加：他人のプロフィール(UserProfileView)専用。posts(authorUid:)は
    //   publicFeedListenerの「全体で最新1000件」の中からしか絞り込めないため、投稿数が
    //   多いグループに押し出されて対象外になった相手の古い投稿がプロフィールから消えて
    //   見えてしまう問題があった（自分の投稿はownPostsListenerで別途500件確保しているため
    //   この問題が起きない、という非対称が存在した）。他人のプロフィールを開いたその場で
    //   その人の投稿だけを都度取得することで解消する。都度1回きりの取得（購読しっぱなしに
    //   しない）なので、コストはプロフィールを開いた回数×その人の投稿数だけで済み、
    //   ユーザー数の2乗で増えるような形にはならない
    static func fetchPosts(authorUid: String, limit: Int = 500) async -> [Post] {
        guard let snapshot = try? await Firestore.firestore().collection("posts")
            .whereField("authorUid", isEqualTo: authorUid)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        else { return [] }
        return snapshot.documents.compactMap { decodePost(id: $0.documentID, data: $0.data()) }
    }

    // ★ マイページの「いいね」統計タップ用。自分がいいねした投稿一覧（新しい順）
    func likedPosts(uid: String) -> [Post] {
        posts.filter { $0.likedBy.contains(uid) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // ★ ユーザー(uid)がこれまでに受け取った、全投稿合計のいいね数
    func totalLikesReceived(uid: String) -> Int {
        posts.filter { $0.authorUid == uid }.reduce(0) { $0 + $1.likedBy.count }
    }

    // MARK: - グループ内「今月のいいねMVP」（表示専用バッジ。ダイアモンドバッジの実体）
    //   ★ 以前はアプリ全体での被いいね数上位5%を「コミュニティ貢献者」として扱っていたが、
    //     「そのグループで最も投稿していいねをもらっているユーザーにダイアモンドバッジを」
    //     という要望に合わせ、グループ単位・月単位の「今月のいいねMVP」をそのままダイアモンド
    //     バッジ(CommunityContributorBrooch)の判定に使う形へ統一した
    //   ★ 「オーナー権限を、月間で一番いいねを集めたメンバーにする」という要望を受けて検討したが、
    //     実際にFirestore上のroleを書き換える形にすると、クライアント側の集計をそのまま信頼する
    //     必要があり、自己申告で「自分が今月一番いいねを集めた」と偽装してオーナー権限を奪えて
    //     しまう（安全にやるには月次集計をCloud Functionsのようなサーバー側処理で行う必要がある）。
    //     そのため実際の権限（role）は変更せず、「このグループの今月のMVPは誰か」を示す
    //     表示専用のバッジとして提供する

    // ★ 指定グループ・今月分の投稿だけを対象に、被いいね数の多い順にユーザーを並べる
    func monthlyLikeRanking(groupId: String) -> [(uid: String, total: Int)] {
        let calendar = Calendar.current
        let now = Date()
        var totals: [String: Int] = [:]
        for post in posts where post.groupId == groupId && calendar.isDate(post.createdAt, equalTo: now, toGranularity: .month) {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        return totals.sorted { $0.value > $1.value }.map { (uid: $0.key, total: $0.value) }
    }

    // ★ 今月、そのグループで一番いいねを集めたメンバーのuid（1件も無ければnil）
    func monthlyTopLikedUid(groupId: String) -> String? {
        monthlyLikeRanking(groupId: groupId).first(where: { $0.total > 0 })?.uid
    }

    // ★ マイページ表示用：自分が参加しているいずれかのグループで、今月のMVP(一番いいねを
    //   集めたメンバー)になっているか。bestGoodsBadgeと同じ「どこか1つのグループで達成していればOK」
    //   という考え方に揃える
    func isMonthlyMVP(uid: String) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let groupIds = Set(posts.compactMap { post -> String? in
            calendar.isDate(post.createdAt, equalTo: now, toGranularity: .month) ? post.groupId : nil
        })
        return groupIds.contains { monthlyTopLikedUid(groupId: $0) == uid }
    }

    // MARK: - 「推し活ペンライト・グッズ」ランキング・バッジ
    //   ★ 専用の投稿・コレクションは持たず、goodsKindが付いた通常の投稿をそのまま対象にする

    func goodsPosts(groupId: String) -> [Post] {
        posts.filter { $0.groupId == groupId && $0.goodsKind != nil }
    }

    // ★ 指定グループ内で、goods投稿の被いいね合計の多い順にユーザーを並べる（ショーケース・
    //   全期間ランキング用。GoodsPenlightHubViewの表示はこちらを使い続ける）
    func goodsRanking(groupId: String) -> [(uid: String, total: Int)] {
        var totals: [String: Int] = [:]
        for post in goodsPosts(groupId: groupId) {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        return totals.sorted { $0.value > $1.value }.map { (uid: $0.key, total: $0.value) }
    }

    // ★ マイページのバッジ判定専用。「今月」分のgoods投稿だけに絞ったランキング
    func monthlyGoodsRanking(groupId: String) -> [(uid: String, total: Int)] {
        let calendar = Calendar.current
        let now = Date()
        var totals: [String: Int] = [:]
        for post in goodsPosts(groupId: groupId) where calendar.isDate(post.createdAt, equalTo: now, toGranularity: .month) {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        return totals.sorted { $0.value > $1.value }.map { (uid: $0.key, total: $0.value) }
    }

    // ★ どのグループでもよいので、そのuidが到達した最高順位のメダル種別を返す。
    //   今月のランキングのみを対象にし、金・銀の2段階だけを渡す（銅は無し）
    func bestGoodsBadge(uid: String) -> GoodsRankBadgeTier? {
        let groupIds = Set(posts.compactMap { $0.goodsKind != nil ? $0.groupId : nil })
        var best: GoodsRankBadgeTier?
        for groupId in groupIds {
            let ranked = monthlyGoodsRanking(groupId: groupId)
            guard let index = ranked.firstIndex(where: { $0.uid == uid }), ranked[index].total > 0, index < 2 else { continue }
            let tier: GoodsRankBadgeTier = index == 0 ? .gold : .silver
            if tier.rank < (best?.rank ?? Int.max) {
                best = tier
            }
        }
        return best
    }

    // MARK: - 「持ち物テンプレート」投稿ランキング・バッジ
    //   ★ goodsRanking/bestGoodsBadgeと全く同じ考え方。goodsKindの代わりに
    //     packingTemplateNameが付いた投稿（テンプレートをそのまま投稿として共有したもの）を対象にする

    func templatePosts(groupId: String) -> [Post] {
        posts.filter { $0.groupId == groupId && $0.packingTemplateName != nil }
    }

    // ★ 指定グループ内で、テンプレート投稿の被いいね合計の多い順にユーザーを並べる（全期間）
    func templateRanking(groupId: String) -> [(uid: String, total: Int)] {
        var totals: [String: Int] = [:]
        for post in templatePosts(groupId: groupId) {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        return totals.sorted { $0.value > $1.value }.map { (uid: $0.key, total: $0.value) }
    }

    // ★ マイページのバッジ判定専用。「今月」分のテンプレート投稿だけに絞ったランキング
    func monthlyTemplateRanking(groupId: String) -> [(uid: String, total: Int)] {
        let calendar = Calendar.current
        let now = Date()
        var totals: [String: Int] = [:]
        for post in templatePosts(groupId: groupId) where calendar.isDate(post.createdAt, equalTo: now, toGranularity: .month) {
            totals[post.authorUid, default: 0] += post.likedBy.count
        }
        return totals.sorted { $0.value > $1.value }.map { (uid: $0.key, total: $0.value) }
    }

    // ★ どのグループでもよいので、そのuidが到達した最高順位のメダル種別を返す。
    //   今月のランキングのみを対象にし、金・銀の2段階だけを渡す（銅は無し）
    func bestTemplateBadge(uid: String) -> GoodsRankBadgeTier? {
        let groupIds = Set(posts.compactMap { $0.packingTemplateName != nil ? $0.groupId : nil })
        var best: GoodsRankBadgeTier?
        for groupId in groupIds {
            let ranked = monthlyTemplateRanking(groupId: groupId)
            guard let index = ranked.firstIndex(where: { $0.uid == uid }), ranked[index].total > 0, index < 2 else { continue }
            let tier: GoodsRankBadgeTier = index == 0 ? .gold : .silver
            if tier.rank < (best?.rank ?? Int.max) {
                best = tier
            }
        }
        return best
    }
}
