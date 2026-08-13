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

    deinit {
        listener?.remove()
        readListener?.remove()
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
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 DM購読エラー:", error)
                    self.scheduleRetry(threadId: threadId)
                    return
                }

                let docs = snapshot?.documents ?? []
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
            self?.observeMessages(threadId: threadId)
        }
    }

    // MARK: - 送信（スレッドのプレビュー情報も同時に更新する）

    // ★ completionは呼び出し元がエラー時にトースト等でユーザーへ知らせるためのもの。
    //   以前はここでprintするだけで、通報を受けて制限されたユーザーなどは送信ボタンを
    //   押しても何も起きず、失敗したことにすら気づけなかった
    func sendMessage(threadId: String, participants: [String], text: String, senderUid: String, senderName: String, imageURL: String? = nil, mediaType: String? = nil, batchId: String? = nil, sharedPostId: String? = nil, sharedPostAuthorUid: String? = nil, sharedPostAuthorName: String? = nil, sharedPostGroupName: String? = nil, completion: ((Error?) -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // ★ 画像・動画だけを送る（キャプション無し）ケースも許可するため、本文が空でもメディアURLがあれば送信可
        guard !trimmed.isEmpty || imageURL != nil else { return }

        let threadRef = db.collection("dmThreads").document(threadId)

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
                completion?(error)
                return
            }
            threadRef.collection("messages").document().setData(messageData) { error in
                if let error {
                    print("🔥 DM送信エラー:", error)
                }
                completion?(error)
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
