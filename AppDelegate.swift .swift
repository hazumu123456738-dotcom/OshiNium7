//
//  AppDelegate.swift .swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/18.
//

import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

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

        // 通知許可
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            } else {
                print("通知許可: \(granted)")
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
}
