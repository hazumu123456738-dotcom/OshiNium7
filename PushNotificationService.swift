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
//   ★ 既知の制約：このコレクションへのcreateは「サインインしていること」以外を
//   強制していない（firestore.rulesのpushTriggers参照）。改造クライアントが
//   任意のuid宛てに偽の通知タイトル・本文を送りつけるスパムは技術的には可能——
//   これは既存のDM1通制限と同じく「サーバーが無い以上、完全ななりすまし防止には
//   本物のバックエンドが必要」というこのアプリ全体の設計上のトレードオフを踏襲している。
enum PushNotificationService {
    private static let triggerCollection = "pushTriggers"

    // ★ routeData: 通知タップ時の遷移先を伝えるためのペイロード（例: ["type": "groupChat",
    //   "groupId": groupId] / ["type": "dm", "otherUid": senderUid]）。Cloud Functions側で
    //   FCMのdataフィールドとしてそのまま転送し、AppDelegateのdidReceive responseで読み取る
    static func send(toUid uid: String, title: String, body: String, routeData: [String: String] = [:]) {
        guard let senderUid = Auth.auth().currentUser?.uid, senderUid != uid else { return }
        var data: [String: Any] = [
            "senderUid": senderUid,
            "topic": "user_\(uid)",
            "notification": [
                "title": title,
                "body": body
            ],
            "createdAt": Timestamp(date: Date())
        ]
        if !routeData.isEmpty { data["data"] = routeData }
        Firestore.firestore().collection(triggerCollection).document().setData(data) { error in
            if let error {
                print("🔥 PushNotificationService send error:", error.localizedDescription)
            }
        }
    }
}
