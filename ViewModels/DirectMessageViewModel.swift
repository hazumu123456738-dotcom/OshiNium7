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

    func sendMessage(threadId: String, participants: [String], text: String, senderUid: String, senderName: String, imageURL: String? = nil, mediaType: String? = nil, batchId: String? = nil) {
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

        threadRef.collection("messages").document().setData(messageData) { error in
            if let error = error {
                print("🔥 DM送信エラー:", error)
            }
        }

        // ★ 一覧のプレビュー用。メディアのみの送信時はキャプションが空文字になるため、
        //   プレビューが空欄にならないようにする
        let previewText = trimmed.isEmpty && imageURL != nil ? (mediaType == "video" ? "（動画）" : "（画像）") : trimmed
        let threadData: [String: Any] = [
            "participants": participants,
            "lastMessage": previewText,
            "lastMessageAt": Timestamp(date: Date()),
            "lastSenderUid": senderUid
        ]
        threadRef.setData(threadData, merge: true)

        if let otherUid = participants.first(where: { $0 != senderUid }) {
            PushNotificationService.send(
                toUid: otherUid,
                title: senderName,
                body: previewText,
                routeData: ["type": "dm", "otherUid": senderUid]
            )
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
