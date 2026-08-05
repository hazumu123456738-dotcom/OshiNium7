//
//  FCMTokenSync.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

// ★ FCMトークンをサインイン中のuidと紐付けてusers/{uid}/private/fcmへ保存する。
//   users/{uid}本体は他ユーザーからも読める設計（プロフィール表示用）のため、
//   誰にも見られるべきではないpush tokenは本人だけが読み書きできるサブコレクションに分けている。
//   「トークンが発行/更新されるタイミング」と「サインインが完了するタイミング」は
//   どちらが先に起きるか保証が無いため、AppDelegate（MessagingDelegate、トークン発行時）と
//   AuthViewModel（サインイン完了時）の両方から呼び出し、どちらが後に起きても
//   確実にuidとトークンが紐付いた状態でFirestoreに保存されるようにする
enum FCMTokenSync {
    static func save(_ token: String?) {
        guard let token, let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("private").document("fcm")
            .setData(["token": token, "updatedAt": Timestamp(date: Date())], merge: true) { error in
                if let error {
                    print("🔥 FCMTokenSync 保存エラー:", error.localizedDescription)
                }
            }
        // ★ 実際のプッシュ送信（PushNotificationService）は生のトークンではなく
        //   "user_{uid}"というトピック宛てに送る設計にしているため、トークンが確定した
        //   タイミングで必ず自分のトピックを購読しておく（Firebase Extension経由の送信に必須）
        subscribeToOwnTopic(uid: uid)
    }

    // ★ サインイン完了時など、「今このタイミングでの最新トークン」を改めて取りに行きたい場合に使う
    static func syncCurrentToken() {
        Messaging.messaging().token { token, error in
            if let error {
                print("🔥 FCMTokenSync token取得エラー:", error.localizedDescription)
                return
            }
            save(token)
        }
    }

    static func subscribeToOwnTopic(uid: String) {
        Messaging.messaging().subscribe(toTopic: "user_\(uid)") { error in
            if let error {
                print("🔥 FCMTokenSync トピック購読エラー:", error.localizedDescription)
            }
        }
    }

    // ★ 端末を共有している場合に、サインアウト後も前のアカウント宛ての通知が
    //   届き続けてしまう（プライバシー漏洩）のを防ぐため、ログアウト時に必ず呼ぶ
    static func unsubscribeFromOwnTopic(uid: String) {
        Messaging.messaging().unsubscribe(fromTopic: "user_\(uid)") { error in
            if let error {
                print("🔥 FCMTokenSync トピック購読解除エラー:", error.localizedDescription)
            }
        }
    }
}
