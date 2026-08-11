//
//  PushNotificationService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import FirebaseAuth
import FirebaseFirestore

// ★ このコレクション（pushTriggers）にドキュメントを書き込むと、Cloud Functions
//   （functions/index.js の sendPushOnTrigger）がそれを検知し、実際にFCM経由で
//   プッシュ通知を送信する。クライアントはトリガードキュメントを書き込むだけで、
//   実際の配信はサーバー側（Cloud Functions）に委ねる構成。
//   Cloud Functionsのデプロイ手順はfunctions/index.js冒頭のコメントを参照
//   （このセッションからはNode.js/firebase CLIが無くデプロイできないため、
//   ユーザー自身のマシンでのデプロイが必要）。
//
//   ★ クライアントは他ユーザーの生のデバイストークンを一切扱わない。代わりに
//   "user_{uid}"というFCMトピック宛てに送る（各端末はサインイン中、FCMTokenSyncで
//   自分のトピックを自動購読している）。これにより、他人のプッシュトークンを
//   Firestoreルール上で読めるようにする必要が無く、安全性をシンプルに保てる。
//
//   ★ firestore.rulesのpushTriggersは、senderUidが本人か・topicのフォーマットに加え、
//   routeDataの"type"ごとに送信者-受信者の実際の関係を検証する（グループ系は実在の
//   メンバーか、dmは実際のDMスレッドがあるか、post_like/post_commentは参照postIdの
//   投稿者が受信者と一致するかを確認）。そのためrouteDataの"type"は省略不可――
//   省略すると、改造クライアント対策と同じ理由でルールに拒否され、通知が届かない
//   （setDataのcompletionでエラーとしてprintされるだけなので気づきにくい。新しい
//   通知種別を追加する際は必ずfirestore.rulesのpushTriggerRelationshipOk()側にも対応を足すこと）
enum PushNotificationService {
    private static let triggerCollection = "pushTriggers"

    // ★ routeData: 通知タップ時の遷移先を伝えるペイロード兼、firestore.rules側の関係性検証キー
    //   （例: ["type": "groupChat", "groupId": groupId] / ["type": "dm", "otherUid": senderUid]）。
    //   Cloud Functions側でFCMのdataフィールドとしてそのまま転送し、AppDelegateのdidReceive
    //   responseで読み取る（"type"はルール側の検証にも使われるため必須）
    static func send(toUid uid: String, title: String, body: String, routeData: [String: String]) {
        guard let senderUid = Auth.auth().currentUser?.uid, senderUid != uid else { return }
        let data: [String: Any] = [
            "senderUid": senderUid,
            "recipientUid": uid,
            "topic": "user_\(uid)",
            "notification": [
                "title": title,
                "body": body
            ],
            "createdAt": Timestamp(date: Date()),
            "data": routeData
        ]
        Firestore.firestore().collection(triggerCollection).document().setData(data) { error in
            if let error {
                print("🔥 PushNotificationService send error:", error.localizedDescription)
            }
        }
    }
}
