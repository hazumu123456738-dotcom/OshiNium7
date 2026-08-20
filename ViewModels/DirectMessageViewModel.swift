//
//  DirectMessageViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ 個人間のDM（相互フォローのユーザー同士のみ開始できる。ChatViewModelのDM版）
final class DirectMessageViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoaded = false
    // ★ Instagram DM風の「既読」表示用。相手が最後にこのスレッドを開いた時刻
    @Published var otherReadAt: Date?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var readListener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60
    // ★ 2026/08/20（/moneyスキル監査）：ChatViewModelの各種チャットと同じく、
    //   以前はDMも全メッセージ履歴を毎回読み直していた。直近N件だけ購読するよう変更
    private let recentMessageLimit = 300

    deinit {
        listener?.remove()
        readListener?.remove()
    }

    // MARK: - 新規スレッド作成数の1日あたり上限(マスDM/迷惑行為対策)

    // ★ /ult監査(2026/08/18)で発見：無料/プレミアム問わず、新規DMスレッドを大量に立てる
    //   「マスDM」行為への総量制限が無かった。2026/08/19、CEOの指示により無料ユーザーは
    //   1日20件・プレミアム会員は無制限という設計に変更(SubscriptionLimits.dmNewThreadDailyLimit
    //   参照。既存の機能別上限[グループ/テンプレート/カレンダー等]と同じ、無料/プレミアムで
    //   段階を変える方式に揃えた)。既存スレッドへの返信・同一相手への再送信はカウント対象外
    //   (DirectMessageThreadView.sendがmessages.isEmptyの時=新規スレッドの時だけこのチェックを呼ぶ)
    //
    // ★ グループ/カレンダーの上限と同じくクライアント側のみでの判定(firestore.rulesまでは
    //   踏み込まない)。改造クライアントによる回避は理論上可能だが、既存の同種の上限も
    //   同じ設計で運用されており、悪用時の実害はマスDMの被害者側がdmPermission='none'/
    //   'followers'やブロックで自衛できる範囲に留まる
    func isNewThreadLimitReached(currentUid: String, limit: Int, completion: @escaping (Bool) -> Void) {
        guard limit != .max else {
            completion(false)
            return
        }
        let since = Timestamp(date: Date().addingTimeInterval(-86400))
        db.collection("users").document(currentUid).collection("dmThreadCreationLog")
            .whereField("createdAt", isGreaterThan: since)
            .getDocuments { snapshot, _ in
                let count = snapshot?.documents.count ?? 0
                completion(count >= limit)
            }
    }

    func logNewThreadCreation(currentUid: String) {
        db.collection("users").document(currentUid).collection("dmThreadCreationLog")
            .addDocument(data: ["createdAt": Timestamp(date: Date())])
    }

    // MARK: - 既読管理

    func markThreadRead(threadId: String, uid: String) {
        db.collection("dmThreads").document(threadId).collection("reads").document(uid)
            .setData(["lastReadAt": Timestamp(date: Date())], merge: true)
    }

    func observeOtherRead(threadId: String, otherUid: String) {
        readListener?.remove()
        readListener = db.collection("dmThreads").document(threadId).collection("reads").document(otherUid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let date = (snapshot?.data()?["lastReadAt"] as? Timestamp)?.dateValue()
                DispatchQueue.main.async {
                    self.otherReadAt = date
                }
            }
    }

    func stopObservingRead() {
        readListener?.remove()
        readListener = nil
        otherReadAt = nil
    }

    func observeMessages(threadId: String) {
        listener?.remove()
        listener = db.collection("dmThreads").document(threadId).collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: recentMessageLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 DM購読エラー:", error)
                    self.scheduleRetry(threadId: threadId)
                    return
                }

                // ★ 直近N件を新しい順に取得しているため、表示用に古い→新しい順へ戻す
                let docs = (snapshot?.documents ?? []).reversed()
                let loaded: [Message] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let senderUid = data["senderUid"] as? String,
                          let text = data["text"] as? String else { return nil }

                    return Message(
                        id: doc.documentID,
                        senderUid: senderUid,
                        senderName: data["senderName"] as? String ?? "名無しさん",
                        text: text,
                        imageURL: data["imageURL"] as? String,
                        mediaType: data["mediaType"] as? String,
                        batchId: data["batchId"] as? String,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        likedBy: data["likedBy"] as? [String] ?? []
                    )
                }

                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.messages = loaded
                    self.isLoaded = true
                }
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
        isLoaded = false
        messages = []
    }

    private func scheduleRetry(threadId: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeMessages(threadId: threadId) }
        }
    }

    // MARK: - 送信（スレッドのプレビュー情報も同時に更新する）

    // ★ completionは呼び出し元がエラー時にトースト等でユーザーへ知らせるためのもの。
    //   以前はここでprintするだけで、通報を受けて制限されたユーザーなどは送信ボタンを
    //   押しても何も起きず、失敗したことにすら気づけなかった
    // ★ 2026/08/18追加：匿名/公開トークルーム・会場口コミには既にあるNGワード自動伏せ字が
    //   DMだけ未適用だった。DMは自由な会話の主導線であり、暴力的表現・自殺/自傷助長表現・
    //   露骨な性的表現・誹謗中傷から相手を守る仕組みがここだけ無いのは一貫性を欠くと判断し、
    //   同じ検知・伏せ字化・モデレーション記録の仕組みをそのまま適用する。ただし1対1の
    //   私的な会話という性質を踏まえ、他画面にある「投稿前ガイドライン」の初回確認アラートや
    //   違反カウントによる警告表示までは持ち込まず、検知・保護の実処理のみを揃える
    func sendMessage(threadId: String, participants: [String], text: String, senderUid: String, senderName: String, imageURL: String? = nil, mediaType: String? = nil, batchId: String? = nil, sharedPostId: String? = nil, sharedPostAuthorUid: String? = nil, sharedPostAuthorName: String? = nil, sharedPostGroupName: String? = nil, completion: ((Error?) -> Void)? = nil) {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // ★ 画像・動画だけを送る（キャプション無し）ケースも許可するため、本文が空でもメディアURLがあれば送信可
        guard !original.isEmpty || imageURL != nil else { return }
        let trimmed = original.isEmpty ? original : NGWordFilter.maskedText(original)

        let threadRef = db.collection("dmThreads").document(threadId)
        let messageRef = threadRef.collection("messages").document()

        var messageData: [String: Any] = [
            "senderUid": senderUid,
            "senderName": senderName,
            "text": trimmed,
            "createdAt": Timestamp(date: Date())
        ]
        if let imageURL { messageData["imageURL"] = imageURL }
        if let mediaType { messageData["mediaType"] = mediaType }
        if let batchId { messageData["batchId"] = batchId }
        if let sharedPostId { messageData["sharedPostId"] = sharedPostId }
        if let sharedPostAuthorUid { messageData["sharedPostAuthorUid"] = sharedPostAuthorUid }
        if let sharedPostAuthorName { messageData["sharedPostAuthorName"] = sharedPostAuthorName }
        if let sharedPostGroupName { messageData["sharedPostGroupName"] = sharedPostGroupName }

        // ★ 一覧のプレビュー用。メディアのみの送信時はキャプションが空文字になるため、
        //   プレビューが空欄にならないようにする
        let previewText = trimmed.isEmpty && imageURL != nil ? (mediaType == "video" ? "（動画）" : "（画像）") : trimmed
        let threadData: [String: Any] = [
            "participants": participants,
            "lastMessage": previewText,
            "lastMessageAt": Timestamp(date: Date()),
            "lastSenderUid": senderUid
        ]

        // ★ 新規スレッドの最初のメッセージでは、messagesサブコレクションへの書き込みルールが
        //   get(dmThreads/{threadId}).data.participantsを参照するため、スレッド本体の
        //   ドキュメントが先にコミット済みでなければならない。以前はスレッド作成とメッセージ送信を
        //   並行して（どちらが先に完了するか保証の無い形で）投げていたため、初回メッセージが
        //   権限エラーで失敗しうる不具合があった。スレッド側の書き込みが確実に完了してから
        //   メッセージを送るよう、順番に実行する
        threadRef.setData(threadData, merge: true) { error in
            if let error {
                print("🔥 DMスレッド更新エラー:", error)
                CrashReportManager.recordNonFatal(error)
                completion?(error)
                return
            }
            messageRef.setData(messageData) { error in
                if let error {
                    print("🔥 DM送信エラー:", error)
                    CrashReportManager.recordNonFatal(error)
                } else {
                    AnalyticsManager.logDMSent(threadId: threadId)
                }
                completion?(error)
            }

            // ★ 伏せ字化された場合のみ、元の発言をモデレーション専用コレクションへ
            //   別途保存する（他画面のlogFlaggedContent呼び出しと同じ仕組み）
            if trimmed != original {
                ModerationService.logFlaggedContent(
                    context: "dm",
                    contextId: threadId,
                    messageId: messageRef.documentID,
                    originalText: original,
                    senderUid: senderUid
                )
            }

            if let otherUid = participants.first(where: { $0 != senderUid }) {
                PushNotificationService.send(
                    toUid: otherUid,
                    title: senderName,
                    body: previewText,
                    routeData: ["type": "dm", "otherUid": senderUid]
                )
            }
        }
    }

    // MARK: - 削除（自分の発言のみ）

    func deleteMessage(threadId: String, message: Message) {
        guard let id = message.id else { return }
        db.collection("dmThreads").document(threadId).collection("messages").document(id).delete { error in
            if let error = error {
                print("🔥 DM削除エラー:", error)
                CrashReportManager.recordNonFatal(error)
            }
        }
    }

    // MARK: - リアクション（ダブルタップでハート）

    func toggleLike(threadId: String, message: Message, uid: String) {
        guard let id = message.id else { return }
        let ref = db.collection("dmThreads").document(threadId).collection("messages").document(id)
        if message.likedBy.contains(uid) {
            ref.updateData(["likedBy": FieldValue.arrayRemove([uid])])
        } else {
            ref.updateData(["likedBy": FieldValue.arrayUnion([uid])])
        }
    }
}
