//
//  ModerationService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// ★ 通報・ブロックまわりの共通処理。グループチャット・DMの両方から呼ばれる。
//   ブロック関係は「自分がブロックしたユーザー一覧」を各ユーザー自身のサブコレクションに
//   持つシンプルな片方向データ構造にし、判定側で両方向（自分→相手／相手→自分）を確認する
enum ModerationService {
    private static var db: Firestore { Firestore.firestore() }

    // MARK: - 通報

    static func reportMessage(
        context: String,
        contextId: String,
        messageId: String?,
        messageText: String,
        reportedUid: String,
        reason: String
    ) {
        guard let uid = Auth.auth().currentUser?.uid, let messageId else { return }

        let data: [String: Any] = [
            "reporterUid": uid,
            "reportedUid": reportedUid,
            "context": context,
            "contextId": contextId,
            "messageId": messageId,
            "messageText": messageText,
            "reason": reason,
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("messageReports").addDocument(data: data) { error in
            if let error { print("🔥 reportMessage error:", error) }
        }
    }

    // ★ コミュニティカレンダーの予定を報告する（荒らし対策：虚偽の予定・スパム的な予定など）。
    //   reportMessageと同じmessageReportsコレクションを流用し、context: "event" で区別する
    static func reportEvent(groupId: String, eventId: String, eventTitle: String, creatorUid: String?, reason: String) {
        reportMessage(
            context: "event",
            contextId: groupId,
            messageId: eventId,
            messageText: eventTitle,
            reportedUid: creatorUid ?? "",
            reason: reason
        )
    }

    // MARK: - ブロック

    static func blockUser(_ blockedUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("blockedUsers").document(blockedUid)
            .setData(["blockedAt": Timestamp(date: Date())]) { error in
                if let error { print("🔥 blockUser error:", error) }
                completion?(error)
            }
    }

    static func unblockUser(_ blockedUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("blockedUsers").document(blockedUid)
            .delete { error in
                if let error { print("🔥 unblockUser error:", error) }
                completion?(error)
            }
    }

    // ★ 自分が相手をブロックしているか
    static func amIBlocking(_ otherUid: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        db.collection("users").document(uid).collection("blockedUsers").document(otherUid)
            .getDocument { snapshot, _ in
                completion(snapshot?.exists == true)
            }
    }

    // ★ 相手が自分をブロックしているか
    static func isBlockedByMe(otherUid: String, meUid: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(otherUid).collection("blockedUsers").document(meUid)
            .getDocument { snapshot, _ in
                completion(snapshot?.exists == true)
            }
    }

    // ★ どちらかの方向でブロックされていればtrue（DM送信可否の判定に使う）
    static func isBlockedEitherWay(myUid: String, otherUid: String, completion: @escaping (Bool) -> Void) {
        amIBlocking(otherUid) { iBlockThem in
            if iBlockThem {
                completion(true)
                return
            }
            isBlockedByMe(otherUid: otherUid, meUid: myUid) { theyBlockMe in
                completion(theyBlockMe)
            }
        }
    }

    // ★ 自分がブロックしている相手のuid一覧。公開トークルームのように複数人がいる場では
    //   「送信を止める」という単純なDM的な仕組みが作れないため、代わりに一覧をまとめて取得し、
    //   ブロックした相手の発言を表示側で丸ごと非表示にする、という方式にする
    static func fetchBlockedUids(completion: @escaping (Set<String>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        db.collection("users").document(uid).collection("blockedUsers").getDocuments { snapshot, error in
            if let error { print("🔥 fetchBlockedUids error:", error) }
            let uids = Set((snapshot?.documents ?? []).map { $0.documentID })
            completion(uids)
        }
    }
}
