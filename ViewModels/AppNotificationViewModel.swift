//
//  AppNotificationViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import Combine
import FirebaseFirestore

final class AppNotificationViewModel: ObservableObject {

    @Published private(set) var notifications: [AppNotification] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var collection: CollectionReference {
        db.collection("notifications")
    }

    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    // MARK: - 購読

    func startListening(uid: String) {
        listener?.remove()
        listener = collection
            .whereField("recipientUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 通知購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let loaded: [AppNotification] = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    guard let recipientUid = data["recipientUid"] as? String,
                          let type = data["type"] as? String,
                          let actorUid = data["actorUid"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                    else { return nil }

                    return AppNotification(
                        id: doc.documentID,
                        recipientUid: recipientUid,
                        type: type,
                        actorUid: actorUid,
                        actorName: data["actorName"] as? String ?? "名無しさん",
                        actorIconURL: data["actorIconURL"] as? String,
                        createdAt: createdAt,
                        isRead: data["isRead"] as? Bool ?? false,
                        groupId: data["groupId"] as? String,
                        groupName: data["groupName"] as? String,
                        eventId: data["eventId"] as? String,
                        eventTitle: data["eventTitle"] as? String
                    )
                }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.notifications = loaded.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        notifications = []
    }

    private func scheduleRetry(uid: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListening(uid: uid)
        }
    }

    // MARK: - 既読化

    func markAllRead() {
        for n in notifications where !n.isRead {
            collection.document(n.id).updateData(["isRead": true])
        }
    }

    // MARK: - フォロー通知の作成（FollowViewModel から呼ばれる）

    static func notifyFollow(recipientUid: String, actorUid: String, actorName: String, actorIconURL: String?) {
        guard recipientUid != actorUid else { return }
        var data: [String: Any] = [
            "recipientUid": recipientUid,
            "type": "follow",
            "actorUid": actorUid,
            "actorName": actorName,
            "createdAt": Timestamp(date: Date()),
            "isRead": false
        ]
        if let actorIconURL, !actorIconURL.isEmpty {
            data["actorIconURL"] = actorIconURL
        }
        Firestore.firestore().collection("notifications").document().setData(data) { error in
            if let error {
                print("🔥 notifyFollow error:", error)
            }
        }
        // ★ アプリ内通知（上のnotificationsドキュメント）は設定に関わらず必ず記録するが、
        //   実際に端末へ割り込むプッシュ送信だけは、相手のfollowNotifyEnabled設定を見て抑制する
        Firestore.firestore().collection("users").document(recipientUid).getDocument { snapshot, _ in
            let enabled = snapshot?.data()?["followNotifyEnabled"] as? Bool ?? true
            if enabled {
                PushNotificationService.send(toUid: recipientUid, title: actorName, body: "あなたをフォローしました")
            }
        }
    }

    // MARK: - フォローリクエスト通知（非公開アカウント向け。FollowViewModel から呼ばれる）

    static func notifyFollowRequest(recipientUid: String, actorUid: String, actorName: String, actorIconURL: String?) {
        guard recipientUid != actorUid else { return }
        var data: [String: Any] = [
            "recipientUid": recipientUid,
            "type": "follow_request",
            "actorUid": actorUid,
            "actorName": actorName,
            "createdAt": Timestamp(date: Date()),
            "isRead": false
        ]
        if let actorIconURL, !actorIconURL.isEmpty {
            data["actorIconURL"] = actorIconURL
        }
        Firestore.firestore().collection("notifications").document().setData(data) { error in
            if let error {
                print("🔥 notifyFollowRequest error:", error)
            }
        }
        PushNotificationService.send(toUid: recipientUid, title: actorName, body: "フォローリクエストが届きました")
    }

    // ★ 非公開アカウントの持ち主がリクエストを承認した時、リクエストを送った本人に届ける
    static func notifyFollowRequestAccepted(recipientUid: String, actorUid: String, actorName: String, actorIconURL: String?) {
        guard recipientUid != actorUid else { return }
        var data: [String: Any] = [
            "recipientUid": recipientUid,
            "type": "follow_request_accepted",
            "actorUid": actorUid,
            "actorName": actorName,
            "createdAt": Timestamp(date: Date()),
            "isRead": false
        ]
        if let actorIconURL, !actorIconURL.isEmpty {
            data["actorIconURL"] = actorIconURL
        }
        Firestore.firestore().collection("notifications").document().setData(data) { error in
            if let error {
                print("🔥 notifyFollowRequestAccepted error:", error)
            }
        }
        PushNotificationService.send(toUid: recipientUid, title: actorName, body: "フォローリクエストを承認しました")
    }

    // MARK: - グループチャットへの招待通知（NewPrivateGroupChatView から呼ばれる）
    //   ★ 招待制グループチャットは相互フォローの相手にしか送れない（アプリ側のガード）。
    //     通知をタップすると、まだメンバーでない相手はその場でグループに参加できる

    static func notifyGroupInvite(recipientUid: String, groupId: String, groupName: String, actorUid: String, actorName: String, actorIconURL: String?) {
        guard recipientUid != actorUid else { return }
        var data: [String: Any] = [
            "recipientUid": recipientUid,
            "type": "group_invite",
            "actorUid": actorUid,
            "actorName": actorName,
            "createdAt": Timestamp(date: Date()),
            "isRead": false,
            "groupId": groupId,
            "groupName": groupName
        ]
        if let actorIconURL, !actorIconURL.isEmpty {
            data["actorIconURL"] = actorIconURL
        }
        Firestore.firestore().collection("notifications").document().setData(data) { error in
            if let error {
                print("🔥 notifyGroupInvite error:", error)
            }
        }
        PushNotificationService.send(toUid: recipientUid, title: actorName, body: "「\(groupName)」に招待しました")
    }

    // MARK: - 予定の追加・削除通知（EventViewModel から呼ばれる）
    //   ★ グループチャットと同じ相手＝ groups/{groupId}/members 全員（自分以外）に、
    //     コミュニティカレンダーに予定が追加/削除されたことを一件ずつ届ける

    private static func fetchMemberUids(groupId: String, completion: @escaping ([String]) -> Void) {
        Firestore.firestore().collection("groups").document(groupId).collection("members")
            .getDocuments { snapshot, error in
                if let error {
                    print("🔥 fetchMemberUids error:", error)
                    completion([])
                    return
                }
                completion(snapshot?.documents.map { $0.documentID } ?? [])
            }
    }

    static func notifyEventCreated(
        groupId: String,
        groupName: String,
        eventId: String?,
        eventTitle: String,
        actorUid: String,
        actorName: String,
        actorIconURL: String?
    ) {
        fetchMemberUids(groupId: groupId) { uids in
            for uid in uids where uid != actorUid {
                var data: [String: Any] = [
                    "recipientUid": uid,
                    "type": "event_created",
                    "actorUid": actorUid,
                    "actorName": actorName,
                    "createdAt": Timestamp(date: Date()),
                    "isRead": false,
                    "groupId": groupId,
                    "groupName": groupName,
                    "eventTitle": eventTitle
                ]
                if let actorIconURL, !actorIconURL.isEmpty { data["actorIconURL"] = actorIconURL }
                if let eventId { data["eventId"] = eventId }

                Firestore.firestore().collection("notifications").document().setData(data) { error in
                    if let error {
                        print("🔥 notifyEventCreated error:", error)
                    }
                }
                PushNotificationService.send(toUid: uid, title: groupName, body: "新しい予定「\(eventTitle)」が追加されました")
            }
        }
    }

    // ★ コミュニティカレンダーの承認制：予定を追加した本人以外の全メンバーに「承認しますか？」を届ける。
    //   タップした先（NotificationsTab.destination）で承認/保留を選べる
    static func notifyEventApprovalRequest(
        groupId: String,
        groupName: String,
        eventId: String?,
        eventTitle: String,
        actorUid: String,
        actorName: String,
        actorIconURL: String?
    ) {
        fetchMemberUids(groupId: groupId) { uids in
            for uid in uids where uid != actorUid {
                var data: [String: Any] = [
                    "recipientUid": uid,
                    "type": "event_approval_request",
                    "actorUid": actorUid,
                    "actorName": actorName,
                    "createdAt": Timestamp(date: Date()),
                    "isRead": false,
                    "groupId": groupId,
                    "groupName": groupName,
                    "eventTitle": eventTitle
                ]
                if let actorIconURL, !actorIconURL.isEmpty { data["actorIconURL"] = actorIconURL }
                if let eventId { data["eventId"] = eventId }

                Firestore.firestore().collection("notifications").document().setData(data) { error in
                    if let error {
                        print("🔥 notifyEventApprovalRequest error:", error)
                    }
                }
                PushNotificationService.send(toUid: uid, title: groupName, body: "\(actorName)さんが追加した「\(eventTitle)」の予定が承認待ちです")
            }
        }
    }

    static func notifyEventDeleted(
        groupId: String,
        groupName: String,
        eventTitle: String,
        actorUid: String,
        actorName: String,
        actorIconURL: String?
    ) {
        fetchMemberUids(groupId: groupId) { uids in
            for uid in uids where uid != actorUid {
                var data: [String: Any] = [
                    "recipientUid": uid,
                    "type": "event_deleted",
                    "actorUid": actorUid,
                    "actorName": actorName,
                    "createdAt": Timestamp(date: Date()),
                    "isRead": false,
                    "groupId": groupId,
                    "groupName": groupName,
                    "eventTitle": eventTitle
                ]
                if let actorIconURL, !actorIconURL.isEmpty { data["actorIconURL"] = actorIconURL }

                Firestore.firestore().collection("notifications").document().setData(data) { error in
                    if let error {
                        print("🔥 notifyEventDeleted error:", error)
                    }
                }
                PushNotificationService.send(toUid: uid, title: groupName, body: "予定「\(eventTitle)」が削除されました")
            }
        }
    }
}
