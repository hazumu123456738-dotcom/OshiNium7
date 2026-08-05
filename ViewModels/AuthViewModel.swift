//
//  AuthViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/24.
//

import Foundation
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    @Published var user: User? = nil

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {

        // 🔥 起動直後は必ず user = nil（初回ログイン画面を確実に出す）
        self.user = nil

        // 🔥 FirebaseAuth の復元が終わったら user が更新される
        listenerHandle = Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                self.user = user
            }
            // ★ トークン発行(AppDelegate)とサインインのどちらが先に起きても
            //   確実にusers/{uid}.fcmTokenへ紐付けるため、サインイン確定時にも同期する
            if user != nil {
                FCMTokenSync.syncCurrentToken()
            }
            // ★ クラッシュレポート上で「どのユーザーで起きたか」を追えるようにする
            CrashReportManager.setUserId(user?.uid)
        }
    }

    var isLoggedIn: Bool {
        return user != nil
    }

    func logout() {
        // ★ 端末共有時に前のアカウント宛てのプッシュ通知が届き続けないよう、
        //   サインアウト前に自分のトピック購読を解除しておく
        if let uid = user?.uid {
            FCMTokenSync.unsubscribeFromOwnTopic(uid: uid)
        }
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            print("ログアウト失敗:", error.localizedDescription)
        }
    }

    deinit {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
