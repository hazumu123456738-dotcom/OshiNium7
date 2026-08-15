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

    // ★ detail: 「どんなことが起きたのか」をユーザー自身の言葉で書いてもらう自由記述欄。
    //   reasonだけだと運営が状況を判断しづらいため、ReportComposerSheetで必ず入力してもらう
    static func reportMessage(
        context: String,
        contextId: String,
        messageId: String?,
        messageText: String,
        reportedUid: String,
        reason: String,
        detail: String = ""
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
            "detail": detail,
            "createdAt": Timestamp(date: Date())
        ]

        db.collection("messageReports").addDocument(data: data) { error in
            if let error { print("🔥 reportMessage error:", error) }
        }
    }

    // ★ コミュニティカレンダーの予定を報告する（荒らし対策：虚偽の予定・スパム的な予定など）。
    //   reportMessageと同じmessageReportsコレクションを流用し、context: "event" で区別する
    static func reportEvent(groupId: String, eventId: String, eventTitle: String, creatorUid: String?, reason: String, detail: String = "") {
        reportMessage(
            context: "event",
            contextId: groupId,
            messageId: eventId,
            messageText: eventTitle,
            reportedUid: creatorUid ?? "",
            reason: reason,
            detail: detail
        )
    }

    // ★ 投稿タイムラインの投稿本体を報告する（同じmessageReportsコレクションを流用、context: "post"）
    static func reportPost(postId: String, groupId: String, caption: String, authorUid: String, reason: String, detail: String = "") {
        reportMessage(
            context: "post",
            contextId: groupId,
            messageId: postId,
            messageText: caption,
            reportedUid: authorUid,
            reason: reason,
            detail: detail
        )
    }

    // ★ 投稿へのコメントを報告する（同じmessageReportsコレクションを流用、context: "postComment"）
    static func reportPostComment(postId: String, commentId: String, commentText: String, authorUid: String, reason: String, detail: String = "") {
        reportMessage(
            context: "postComment",
            contextId: postId,
            messageId: commentId,
            messageText: commentText,
            reportedUid: authorUid,
            reason: reason,
            detail: detail
        )
    }

    // ★ 会場口コミ（VenueReportComposerView、匿名投稿）を報告する。画面には投稿者のuidを
    //   一切表示しないため、報告後もreportedUidは通報データ内にのみ保持される
    static func reportVenueReview(venueReportId: String, groupId: String, text: String, authorUid: String, reason: String, detail: String = "") {
        reportMessage(
            context: "venueReview",
            contextId: groupId,
            messageId: venueReportId,
            messageText: text,
            reportedUid: authorUid,
            reason: reason,
            detail: detail
        )
    }

    // ★ 特定のメッセージ・投稿ではなく、プロフィール画面から直接そのユーザー自体を報告する。
    //   グループのオーナーかどうかに関わらず、どのメンバーからでも使える（他の報告と同じ導線）
    static func reportUser(reportedUid: String, reportedName: String, reason: String, detail: String = "") {
        reportMessage(
            context: "userProfile",
            contextId: reportedUid,
            messageId: reportedUid,
            messageText: reportedName,
            reportedUid: reportedUid,
            reason: reason,
            detail: detail
        )
    }

    // MARK: - ブロック

    static func blockUser(_ blockedUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("blockedUsers").document(blockedUid)
            .setData(["blockedAt": Timestamp(date: Date())]) { error in
                if let error { print("🔥 blockUser error:", error) }
                // ★ 2026/08/14追加：X/Instagramと同じく、ブロックしたら双方向のフォロー関係・
                //   保留中のフォローリクエストも自動的に解除する（片方だけ消すと「相手はまだ
                //   自分をフォローしている」ような中途半端な状態が残ってしまうため）
                removeFollowRelationship(uid, blockedUid)
                completion?(error)
            }
    }

    // ★ ブロック時のフォロー関係クリーンアップ専用。follows/followRequestsとも
    //   ドキュメントIDが"{followerUid/fromUid}_{followingUid/toUid}"形式で統一されているため、
    //   両方向のIDを組み立てて削除するだけでよい（存在しない方は削除がno-opになるだけで安全）
    private static func removeFollowRelationship(_ uidA: String, _ uidB: String) {
        for collection in ["follows", "followRequests"] {
            db.collection(collection).document("\(uidA)_\(uidB)").delete { _ in }
            db.collection(collection).document("\(uidB)_\(uidA)").delete { _ in }
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

    // MARK: - ミュート
    //   ★ ブロックと違い、ミュートは相手に気づかれない・一方通行の「自分のタイムラインから
    //     見えなくするだけ」の機能。ブロックと同じデータ構造(users/{uid}/mutedUsers)にする

    static func muteUser(_ mutedUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("mutedUsers").document(mutedUid)
            .setData(["mutedAt": Timestamp(date: Date())]) { error in
                if let error { print("🔥 muteUser error:", error) }
                completion?(error)
            }
    }

    static func unmuteUser(_ mutedUid: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("mutedUsers").document(mutedUid)
            .delete { error in
                if let error { print("🔥 unmuteUser error:", error) }
                completion?(error)
            }
    }

    static func amIMuting(_ otherUid: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        db.collection("users").document(uid).collection("mutedUsers").document(otherUid)
            .getDocument { snapshot, _ in
                completion(snapshot?.exists == true)
            }
    }

    // ★ 自分がミュートしている相手のuid一覧。タイムライン表示側で、この一覧に含まれる
    //   投稿者の投稿を丸ごと除外する（ブロックのfetchBlockedUidsと同じ使い方）
    static func fetchMutedUids(completion: @escaping (Set<String>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        db.collection("users").document(uid).collection("mutedUsers").getDocuments { snapshot, error in
            if let error { print("🔥 fetchMutedUids error:", error) }
            let uids = Set((snapshot?.documents ?? []).map { $0.documentID })
            completion(uids)
        }
    }
}
