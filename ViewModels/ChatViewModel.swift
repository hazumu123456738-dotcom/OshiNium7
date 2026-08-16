//
//  ChatViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation
import Combine
import FirebaseFirestore

final class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoaded = false

    // ★ 匿名チャット（コミュニティチャット匿名版）用。通常のmessages購読とは
    //   完全に独立したFirestoreサブコレクション（groups/{groupId}/anonymousTopics/{topicId}/messages）を使う。
    //   誰でも自分で話題（トークルーム）を立てられ、他の人が立てた話題にも自由に参加・閲覧できる
    @Published var anonymousMessages: [Message] = []
    @Published var isAnonymousLoaded = false

    @Published var anonymousTopics: [AnonymousTopic] = []
    @Published var isAnonymousTopicsLoaded = false

    // ★ 公開版（コミュニティチャット公開版）用。匿名版と同じ「誰でも話題を立てられる」構造だが、
    //   完全に別のFirestoreサブコレクション（groups/{groupId}/openTopics/{topicId}/messages）を使い、
    //   発言者の名前・アイコンはそのまま表示する（推し活の友達を見つけるための場）
    @Published var openMessages: [Message] = []
    @Published var isOpenLoaded = false

    @Published var openTopics: [OpenTopic] = []
    @Published var isOpenTopicsLoaded = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var anonymousListener: ListenerRegistration?
    private var anonymousTopicsListener: ListenerRegistration?
    private var openListener: ListenerRegistration?
    private var openTopicsListener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private var anonymousTopicsRetryDelay: TimeInterval = 1
    private var anonymousMessagesRetryDelay: TimeInterval = 1
    private var openTopicsRetryDelay: TimeInterval = 1
    private var openMessagesRetryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
        anonymousListener?.remove()
        anonymousTopicsListener?.remove()
        openListener?.remove()
        openTopicsListener?.remove()
    }

    // MARK: - 購読

    func observeMessages(groupId: String) {
        listener?.remove()
        listener = db.collection("groups").document(groupId).collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 ChatViewModel 購読エラー:", error)
                    self.scheduleRetry(groupId: groupId)
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
                        isSystem: data["isSystem"] as? Bool ?? false,
                        likedBy: data["likedBy"] as? [String] ?? [],
                        systemCategory: data["systemCategory"] as? String
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

    private func scheduleRetry(groupId: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeMessages(groupId: groupId) }
        }
    }

    // MARK: - 既読管理（チャット一覧の未読バッジ用）
    //   ★ groups/{groupId}/members/{uid}.lastReadAtに「最後にこの画面を開いた時刻」を記録する。
    //     既存のmembersドキュメント更新ルール（本人はrole以外を自由に更新可）でそのまま書き込めるため、
    //     ルールの追加変更は不要
    func markGroupChatRead(groupId: String, uid: String) {
        db.collection("groups").document(groupId).collection("members").document(uid)
            .setData(["lastReadAt": Timestamp(date: Date())], merge: true)
    }

    static func fetchMyLastReadAt(groupId: String, uid: String) async -> Date? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("groups").document(groupId).collection("members").document(uid)
                .getDocument()
            return (snapshot.data()?["lastReadAt"] as? Timestamp)?.dateValue()
        } catch {
            return nil
        }
    }

    // MARK: - 送信

    // ★ completionは呼び出し元がエラー時にトースト等でユーザーへ知らせるためのもの。
    //   以前はここでprintするだけで、通報を受けて制限されたユーザーなどは送信ボタンを
    //   押しても何も起きず、失敗したことにすら気づけなかった
    func sendMessage(groupId: String, groupName: String, text: String, senderUid: String, senderName: String, imageURL: String? = nil, mediaType: String? = nil, batchId: String? = nil, completion: ((Error?) -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // ★ 画像・動画だけを送る（キャプション無し）ケースも許可するため、
        //   本文が空でもメディアURLがあれば送信可とする
        guard !trimmed.isEmpty || imageURL != nil else { return }

        var data: [String: Any] = [
            "senderUid": senderUid,
            "senderName": senderName,
            "text": trimmed,
            "createdAt": Timestamp(date: Date())
        ]
        if let imageURL { data["imageURL"] = imageURL }
        if let mediaType { data["mediaType"] = mediaType }
        if let batchId { data["batchId"] = batchId }

        db.collection("groups").document(groupId).collection("messages").document().setData(data) { error in
            if let error = error {
                print("🔥 ChatViewModel 送信エラー:", error)
            }
            completion?(error)
        }

        // ★ 送信者以外の全メンバーへプッシュ通知。メディアのみの送信時はキャプションが
        //   空文字になるため、通知本文が空欄にならないようフォールバックする
        let pushBody = trimmed.isEmpty && imageURL != nil ? (mediaType == "video" ? "（動画）" : "（画像）") : trimmed
        db.collection("groups").document(groupId).collection("members").getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            for doc in docs where doc.documentID != senderUid {
                PushNotificationService.send(
                    toUid: doc.documentID,
                    title: "\(groupName) / \(senderName)",
                    body: pushBody,
                    routeData: ["type": "groupChat", "groupId": groupId]
                )
            }
        }
    }

    // MARK: - システムメッセージ送信（予定の追加・削除などをグループチャットにお知らせ）
    //   ★ ユーザー入力ではなくアプリ側から自動投稿するため、インスタンス不要のstaticにして
    //     AppNotificationViewModel.notifyFollow などと同じ形にする（EventViewModelから直接呼べる）

    static func postSystemMessage(groupId: String, text: String, category: String? = nil) {
        var data: [String: Any] = [
            "senderUid": "system",
            "senderName": "お知らせ",
            "text": text,
            "createdAt": Timestamp(date: Date()),
            "isSystem": true
        ]
        if let category { data["systemCategory"] = category }

        Firestore.firestore().collection("groups").document(groupId).collection("messages").document().setData(data) { error in
            if let error = error {
                print("🔥 postSystemMessage error:", error)
            }
        }
    }

    // MARK: - 削除（自分の発言のみ）

    func deleteMessage(groupId: String, message: Message) {
        guard let id = message.id else { return }
        db.collection("groups").document(groupId).collection("messages").document(id).delete { error in
            if let error = error {
                print("🔥 ChatViewModel 削除エラー:", error)
            }
        }
    }

    // MARK: - リアクション（ダブルタップでハート）

    func toggleLike(groupId: String, message: Message, uid: String) {
        guard let id = message.id else { return }
        let ref = db.collection("groups").document(groupId).collection("messages").document(id)
        if message.likedBy.contains(uid) {
            ref.updateData(["likedBy": FieldValue.arrayRemove([uid])])
        } else {
            ref.updateData(["likedBy": FieldValue.arrayUnion([uid])])
        }
    }

    // MARK: - 匿名チャット：トークルーム（話題）一覧
    //   ★ 誰でも自由に話題を立てられ、他の人が立てた話題にも自由に参加・閲覧できる。
    //     直近にやり取りがあったトークルームが上に来るよう lastMessageAt の降順で並べる

    func observeAnonymousTopics(groupId: String) {
        anonymousTopicsListener?.remove()
        anonymousTopicsListener = db.collection("groups").document(groupId).collection("anonymousTopics")
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 ChatViewModel 匿名トークルーム購読エラー:", error)
                    self.scheduleAnonymousTopicsRetry(groupId: groupId)
                    return
                }

                let docs = snapshot?.documents ?? []
                let loaded: [AnonymousTopic] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let creatorUid = data["creatorUid"] as? String else { return nil }

                    return AnonymousTopic(
                        id: doc.documentID,
                        title: title,
                        creatorUid: creatorUid,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date(),
                        messageCount: data["messageCount"] as? Int ?? 0
                    )
                }

                self.anonymousTopicsRetryDelay = 1

                DispatchQueue.main.async {
                    self.anonymousTopics = loaded
                    self.isAnonymousTopicsLoaded = true
                }
            }
    }

    func stopObservingAnonymousTopics() {
        anonymousTopicsListener?.remove()
        anonymousTopicsListener = nil
        isAnonymousTopicsLoaded = false
        anonymousTopics = []
    }

    // ★ observeMessagesのscheduleRetryと同じ考え方。ルール未デプロイ等で一時的に
    //   権限エラーになっても、指数バックオフで自動的に再購読し続ける
    private func scheduleAnonymousTopicsRetry(groupId: String) {
        anonymousTopicsListener?.remove()
        let delay = anonymousTopicsRetryDelay
        anonymousTopicsRetryDelay = min(anonymousTopicsRetryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeAnonymousTopics(groupId: groupId) }
        }
    }

    // ★ 立てた本人はcreatorUidとしてサーバーに残るが、UI上で名乗ることは無い
    //   （後から自分のトークルームだけ削除できるようにするための情報）
    func createAnonymousTopic(groupId: String, title: String, creatorUid: String, completion: ((AnonymousTopic?) -> Void)? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?(nil)
            return
        }

        let now = Date()
        let data: [String: Any] = [
            "title": trimmed,
            "creatorUid": creatorUid,
            "createdAt": Timestamp(date: now),
            "lastMessageAt": Timestamp(date: now),
            "messageCount": 0
        ]

        let ref = db.collection("groups").document(groupId).collection("anonymousTopics").document()
        ref.setData(data) { error in
            if let error = error {
                print("🔥 ChatViewModel 匿名トークルーム作成エラー:", error)
                completion?(nil)
                return
            }
            completion?(AnonymousTopic(id: ref.documentID, title: trimmed, creatorUid: creatorUid, createdAt: now, lastMessageAt: now, messageCount: 0))
        }
    }

    // ★ トークルームの削除（立てた本人 or グループ管理者）。中の発言も一括で消す
    func deleteAnonymousTopic(groupId: String, topic: AnonymousTopic) {
        let topicRef = db.collection("groups").document(groupId).collection("anonymousTopics").document(topic.id)
        topicRef.collection("messages").getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            let batch = self.db.batch()
            for doc in snapshot?.documents ?? [] {
                batch.deleteDocument(doc.reference)
            }
            batch.deleteDocument(topicRef)
            batch.commit { error in
                if let error = error {
                    print("🔥 ChatViewModel 匿名トークルーム削除エラー:", error)
                }
            }
        }
    }

    static func fetchLatestAnonymousTopic(groupId: String) async -> AnonymousTopic? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("groups").document(groupId).collection("anonymousTopics")
                .order(by: "lastMessageAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else { return nil }
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let creatorUid = data["creatorUid"] as? String else { return nil }

            return AnonymousTopic(
                id: doc.documentID,
                title: title,
                creatorUid: creatorUid,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date(),
                messageCount: data["messageCount"] as? Int ?? 0
            )
        } catch {
            print("🔥 ChatViewModel fetchLatestAnonymousTopic error:", error)
            return nil
        }
    }

    // MARK: - 匿名チャット：個々のトークルーム内の発言
    //   ★ 送信者の実名・アイコンは一切保持しない。senderUidだけはモデレーション
    //     （通報・管理者による削除）のためにドキュメントへ残すが、UI側では絶対に使わない。
    //     senderNameは常に「匿名」で固定して書き込む（後から本名で検索されるのを防ぐため）

    private func anonymousMessagesRef(groupId: String, topicId: String) -> CollectionReference {
        db.collection("groups").document(groupId).collection("anonymousTopics").document(topicId).collection("messages")
    }

    func observeAnonymousMessages(groupId: String, topicId: String) {
        anonymousListener?.remove()
        anonymousListener = anonymousMessagesRef(groupId: groupId, topicId: topicId)
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 ChatViewModel 匿名チャット購読エラー:", error)
                    self.scheduleAnonymousMessagesRetry(groupId: groupId, topicId: topicId)
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
                        senderName: "匿名",
                        text: text,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                self.anonymousMessagesRetryDelay = 1

                DispatchQueue.main.async {
                    self.anonymousMessages = loaded
                    self.isAnonymousLoaded = true
                }
            }
    }

    func stopObservingAnonymous() {
        anonymousListener?.remove()
        anonymousListener = nil
        isAnonymousLoaded = false
        anonymousMessages = []
    }

    private func scheduleAnonymousMessagesRetry(groupId: String, topicId: String) {
        anonymousListener?.remove()
        let delay = anonymousMessagesRetryDelay
        anonymousMessagesRetryDelay = min(anonymousMessagesRetryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeAnonymousMessages(groupId: groupId, topicId: topicId) }
        }
    }

    func sendAnonymousMessage(groupId: String, topicId: String, text: String, senderUid: String, originalText: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let messageRef = anonymousMessagesRef(groupId: groupId, topicId: topicId).document()
        let data: [String: Any] = [
            "senderUid": senderUid,
            "senderName": "匿名",
            "text": trimmed,
            "createdAt": Timestamp(date: Date())
        ]

        messageRef.setData(data) { error in
            if let error = error {
                print("🔥 ChatViewModel 匿名チャット送信エラー:", error)
            }
        }

        // ★ 伏せ字化された場合のみ、元の発言をモデレーション専用コレクションへ別途保存する
        if let originalText, originalText != trimmed {
            ModerationService.logFlaggedContent(
                context: "anonymousMessage",
                contextId: groupId,
                messageId: messageRef.documentID,
                originalText: originalText,
                senderUid: senderUid
            )
        }

        // ★ トークルーム一覧の並び順（直近やり取りが上）とメッセージ数表示のために、
        //   親のトークルームドキュメントも合わせて更新する
        let topicRef = db.collection("groups").document(groupId).collection("anonymousTopics").document(topicId)
        topicRef.updateData([
            "lastMessageAt": Timestamp(date: Date()),
            "messageCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("🔥 ChatViewModel 匿名トークルーム更新エラー:", error)
            }
        }
    }

    func deleteAnonymousMessage(groupId: String, topicId: String, message: Message) {
        guard let id = message.id else { return }
        anonymousMessagesRef(groupId: groupId, topicId: topicId).document(id).delete { error in
            if let error = error {
                print("🔥 ChatViewModel 匿名チャット削除エラー:", error)
            }
        }
    }

    // MARK: - 公開チャット：トークルーム（話題）一覧
    //   ★ 匿名版と同じ「誰でも自由に話題を立てられる」構造。直近にやり取りがあった
    //     トークルームが上に来るよう lastMessageAt の降順で並べる

    func observeOpenTopics(groupId: String) {
        openTopicsListener?.remove()
        openTopicsListener = db.collection("groups").document(groupId).collection("openTopics")
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 ChatViewModel 公開トークルーム購読エラー:", error)
                    self.scheduleOpenTopicsRetry(groupId: groupId)
                    return
                }

                let docs = snapshot?.documents ?? []
                let loaded: [OpenTopic] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let creatorUid = data["creatorUid"] as? String else { return nil }

                    return OpenTopic(
                        id: doc.documentID,
                        title: title,
                        creatorUid: creatorUid,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date(),
                        messageCount: data["messageCount"] as? Int ?? 0
                    )
                }

                self.openTopicsRetryDelay = 1

                DispatchQueue.main.async {
                    self.openTopics = loaded
                    self.isOpenTopicsLoaded = true
                }
            }
    }

    func stopObservingOpenTopics() {
        openTopicsListener?.remove()
        openTopicsListener = nil
        isOpenTopicsLoaded = false
        openTopics = []
    }

    private func scheduleOpenTopicsRetry(groupId: String) {
        openTopicsListener?.remove()
        let delay = openTopicsRetryDelay
        openTopicsRetryDelay = min(openTopicsRetryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeOpenTopics(groupId: groupId) }
        }
    }

    func createOpenTopic(groupId: String, title: String, creatorUid: String, completion: ((OpenTopic?) -> Void)? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?(nil)
            return
        }

        let now = Date()
        let data: [String: Any] = [
            "title": trimmed,
            "creatorUid": creatorUid,
            "createdAt": Timestamp(date: now),
            "lastMessageAt": Timestamp(date: now),
            "messageCount": 0
        ]

        let ref = db.collection("groups").document(groupId).collection("openTopics").document()
        ref.setData(data) { error in
            if let error = error {
                print("🔥 ChatViewModel 公開トークルーム作成エラー:", error)
                completion?(nil)
                return
            }
            completion?(OpenTopic(id: ref.documentID, title: trimmed, creatorUid: creatorUid, createdAt: now, lastMessageAt: now, messageCount: 0))
        }
    }

    // ★ 立てた本人、またはグループのオーナー・管理者が削除できる
    func deleteOpenTopic(groupId: String, topic: OpenTopic) {
        let topicRef = db.collection("groups").document(groupId).collection("openTopics").document(topic.id)
        topicRef.collection("messages").getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            let batch = self.db.batch()
            for doc in snapshot?.documents ?? [] {
                batch.deleteDocument(doc.reference)
            }
            batch.deleteDocument(topicRef)
            batch.commit { error in
                if let error = error {
                    print("🔥 ChatViewModel 公開トークルーム削除エラー:", error)
                }
            }
        }
    }

    static func fetchLatestOpenTopic(groupId: String) async -> OpenTopic? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("groups").document(groupId).collection("openTopics")
                .order(by: "lastMessageAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else { return nil }
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let creatorUid = data["creatorUid"] as? String else { return nil }

            return OpenTopic(
                id: doc.documentID,
                title: title,
                creatorUid: creatorUid,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date(),
                messageCount: data["messageCount"] as? Int ?? 0
            )
        } catch {
            print("🔥 ChatViewModel fetchLatestOpenTopic error:", error)
            return nil
        }
    }

    // MARK: - 公開チャット：個々のトークルーム内の発言
    //   ★ 匿名版と違い、発言者の名前をそのまま書き込む。アイコンはUI側でusers/{uid}を
    //     直接見て常に最新のものを表示する（ChatRoomViewと同じ方針）

    private func openMessagesRef(groupId: String, topicId: String) -> CollectionReference {
        db.collection("groups").document(groupId).collection("openTopics").document(topicId).collection("messages")
    }

    func observeOpenMessages(groupId: String, topicId: String) {
        openListener?.remove()
        openListener = openMessagesRef(groupId: groupId, topicId: topicId)
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 ChatViewModel 公開チャット購読エラー:", error)
                    self.scheduleOpenMessagesRetry(groupId: groupId, topicId: topicId)
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
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }

                self.openMessagesRetryDelay = 1

                DispatchQueue.main.async {
                    self.openMessages = loaded
                    self.isOpenLoaded = true
                }
            }
    }

    func stopObservingOpen() {
        openListener?.remove()
        openListener = nil
        isOpenLoaded = false
        openMessages = []
    }

    private func scheduleOpenMessagesRetry(groupId: String, topicId: String) {
        openListener?.remove()
        let delay = openMessagesRetryDelay
        openMessagesRetryDelay = min(openMessagesRetryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeOpenMessages(groupId: groupId, topicId: topicId) }
        }
    }

    func sendOpenMessage(groupId: String, topicId: String, text: String, senderUid: String, senderName: String, originalText: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let messageRef = openMessagesRef(groupId: groupId, topicId: topicId).document()
        let data: [String: Any] = [
            "senderUid": senderUid,
            "senderName": senderName,
            "text": trimmed,
            "createdAt": Timestamp(date: Date())
        ]

        messageRef.setData(data) { error in
            if let error = error {
                print("🔥 ChatViewModel 公開チャット送信エラー:", error)
            }
        }

        // ★ 伏せ字化された場合のみ、元の発言をモデレーション専用コレクションへ別途保存する
        if let originalText, originalText != trimmed {
            ModerationService.logFlaggedContent(
                context: "openMessage",
                contextId: groupId,
                messageId: messageRef.documentID,
                originalText: originalText,
                senderUid: senderUid
            )
        }

        let topicRef = db.collection("groups").document(groupId).collection("openTopics").document(topicId)
        topicRef.updateData([
            "lastMessageAt": Timestamp(date: Date()),
            "messageCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("🔥 ChatViewModel 公開トークルーム更新エラー:", error)
            }
        }
    }

    func deleteOpenMessage(groupId: String, topicId: String, message: Message) {
        guard let id = message.id else { return }
        openMessagesRef(groupId: groupId, topicId: topicId).document(id).delete { error in
            if let error = error {
                print("🔥 ChatViewModel 公開チャット削除エラー:", error)
            }
        }
    }

    // MARK: - 一覧画面用：最新メッセージ1件だけ単発取得（プレビュー表示用）

    static func fetchLastMessage(groupId: String) async -> Message? {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("groups").document(groupId).collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else { return nil }
            let data = doc.data()
            guard let senderUid = data["senderUid"] as? String,
                  let text = data["text"] as? String else { return nil }

            return Message(
                id: doc.documentID,
                senderUid: senderUid,
                senderName: data["senderName"] as? String ?? "名無しさん",
                text: text,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        } catch {
            print("🔥 ChatViewModel fetchLastMessage error:", error)
            return nil
        }
    }

    // MARK: - 一覧画面用：最新メッセージ・既読時刻をリアルタイム購読（未読ドット用）
    //   ★ 以前は単発取得（fetchLastMessage/fetchMyLastReadAt）のみだったため、チャット一覧
    //     画面自体は独自タブバーの構成上ずっとマウントされたまま裏に隠れるだけなのに、
    //     再取得のきっかけ（グループの切り替え・pull to refresh）が起きない限り、
    //     チャットルームを開いて既読にしても一覧の未読ドットが消えない・新着が来ても
    //     気付けない、という不具合になっていた。live listenerに切り替えることで、
    //     このタブが裏に隠れている間も含めて常に最新の状態を反映できるようにする

    static func observeLastMessage(groupId: String, onChange: @escaping (Message?) -> Void) -> ListenerRegistration {
        Firestore.firestore()
            .collection("groups").document(groupId).collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                guard let doc = snapshot?.documents.first else {
                    onChange(nil)
                    return
                }
                let data = doc.data()
                guard let senderUid = data["senderUid"] as? String,
                      let text = data["text"] as? String else {
                    onChange(nil)
                    return
                }
                onChange(Message(
                    id: doc.documentID,
                    senderUid: senderUid,
                    senderName: data["senderName"] as? String ?? "名無しさん",
                    text: text,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                ))
            }
    }

    static func observeMyLastReadAt(groupId: String, uid: String, onChange: @escaping (Date?) -> Void) -> ListenerRegistration {
        Firestore.firestore()
            .collection("groups").document(groupId).collection("members").document(uid)
            .addSnapshotListener { snapshot, error in
                onChange((snapshot?.data()?["lastReadAt"] as? Timestamp)?.dateValue())
            }
    }

    // MARK: - 一覧画面用：メンバーの現在の表示名だけ単発取得（プレビューを固定名から解放するため）

    static func fetchMemberName(groupId: String, uid: String) async -> String? {
        do {
            let doc = try await Firestore.firestore()
                .collection("groups").document(groupId).collection("members").document(uid)
                .getDocument()
            return doc.data()?["displayName"] as? String
        } catch {
            return nil
        }
    }

    // MARK: - 送信者アイコン・名前用：users/{uid} を直接参照（大元のソース）
    //   ★ groups/{id}/members は「参加した瞬間」のスナップショットのミラーなので、
    //     機能追加前から参加している古いメンバーはここに登録されていないことがある。
    //     プロフィール本体（users/{uid}）を直接見れば、ミラーの同期漏れに関わらず必ず最新が取れる。
    struct RemoteUserProfile {
        let displayName: String
        let iconURL: String?
    }

    // ★ 2026/08/16修正：一時的な通信エラーで1回失敗すると、呼び出し元(PostFeedCard等の
    //   .task)は二度と呼び直さないため、投稿者名・アイコンが「名無しさん」「?」のまま
    //   カード表示中ずっと戻らなくなっていた。エラー時のみ短い間隔で最大2回まで再試行する
    //   （NearbyPlacesService.withRetryと同じ考え方）
    static func fetchUserProfile(uid: String, attempt: Int = 1, maxAttempts: Int = 3) async -> RemoteUserProfile? {
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard let data = doc.data() else { return nil }
            let name = data["displayName"] as? String
            let icon = data["iconURL"] as? String
            return RemoteUserProfile(
                displayName: name.nonEmptyOrNil ?? "名無しさん",
                iconURL: (icon?.isEmpty == false) ? icon : nil
            )
        } catch {
            print("🔥 ChatViewModel fetchUserProfile error (\(attempt)/\(maxAttempts)):", error)
            guard attempt < maxAttempts else { return nil }
            try? await Task.sleep(nanoseconds: 400_000_000)
            return await fetchUserProfile(uid: uid, attempt: attempt + 1, maxAttempts: maxAttempts)
        }
    }
}
