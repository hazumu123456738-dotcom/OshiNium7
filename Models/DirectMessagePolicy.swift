//
//  DirectMessagePolicy.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import Foundation

// ★ DirectMessageThreadViewが画面表示のために持っていた「1通制限」「既読」の判定ロジックを、
//   Firebase/View状態から切り離した純粋な関数として切り出したもの。
//   ViewModel/Viewはこれを薄く呼び出すだけにすることで、ユニットテストで挙動を固定できる
enum DirectMessagePolicy {

    // ★ 相互フォローでない相手への「メッセージリクエスト」は、リクエストする側が
    //   最初の1通を送った後、相手から返信があるまで次を送れないようにする
    //   （Instagram等と同じ、一方的な連投を防ぐための制限。相手が一度でも返信すれば
    //   実質的に「リクエストを承諾した」とみなし、以降は双方とも自由に送れる）
    static func isRequestLimited(
        messages: [Message],
        currentUid: String,
        otherUid: String,
        isMutual: Bool
    ) -> Bool {
        guard !isMutual else { return false }
        let otherHasSentAnyMessage = messages.contains { $0.senderUid == otherUid }
        guard !otherHasSentAnyMessage else { return false }
        let myMessageCount = messages.filter { $0.senderUid == currentUid }.count
        return myMessageCount >= 1
    }

    // ★ Instagram DM風の「既読」表示。自分が送った直近のメッセージにだけ、
    //   相手の最終既読時刻がそのメッセージの送信時刻以降であれば表示する
    static func isLastMineSeen(
        message: Message,
        lastMessageId: String?,
        currentUid: String,
        otherReadAt: Date?
    ) -> Bool {
        guard message.senderUid == currentUid,
              message.id == lastMessageId,
              let otherReadAt else { return false }
        return otherReadAt >= message.createdAt
    }
}
