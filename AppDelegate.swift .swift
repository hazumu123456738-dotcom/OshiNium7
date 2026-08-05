//
//  AppDelegate.swift .swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/18.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

// ★ プッシュ通知（FCM）基盤。APNs⇔FCMのトークン紐付け、Firestoreへのトークン保存、
//   フォアグラウンド中の通知表示を担う。「実際に送信する」サーバー側（Cloud Functions等）は
//   この開発環境からは構築・デプロイできないため未着手だが、クライアント側は
//   Cloud Functionsが用意され次第すぐ送信対象にできる状態まで整えてある
class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        // 🔥 初回起動だけ強制ログアウト
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if isFirstLaunch {
            do {
                try Auth.auth().signOut()
                print("DEBUG: 初回起動 → 強制ログアウト")
            } catch {
                print("DEBUG: 強制ログアウト失敗:", error.localizedDescription)
            }

            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // 通知許可
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            } else {
                print("通知許可: \(granted)")
            }
            // ★ APNsトークンの取得（＝FCMトークンの発行）には、リモート通知への
            //   登録要求が必須。許可が拒否された場合でも呼び出し自体は安全（何も起きないだけ）
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        return true
    }

    // Google ログインのコールバック
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - APNs ⇔ FCM トークン紐付け

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔥 リモート通知の登録に失敗:", error.localizedDescription)
    }

    // MARK: - MessagingDelegate（FCMトークンの発行・更新のたびに呼ばれる）

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        FCMTokenSync.save(fcmToken)
    }

    // MARK: - フォアグラウンド中に通知を受け取ったときも、バックグラウンド時と同様に表示する

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
