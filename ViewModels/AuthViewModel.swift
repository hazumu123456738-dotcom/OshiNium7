//
//  AuthViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/24.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
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

    // ★ App Store審査ガイドライン5.1.1(v)：アカウント作成に対応しているアプリは、
    //   アプリ内からアカウント削除を行える手段を用意しなければならない。
    //   ★ 既知の制約：ここではusers/{uid}ドキュメントとFirebase Authのアカウント自体を
    //   削除するのみで、posts/groups/messagesなど本人が作成した他コレクションの
    //   データは削除しない（本来はCloud Functionsでのカスケード削除が望ましいが、
    //   このセッションからはCloud Functionsのデプロイができないため次回以降の課題とする）。
    //   ★ Firebaseの仕様上、直近のサインインから時間が経っていると
    //   currentUser.delete()が.requiresRecentLoginで失敗する。その場合は
    //   呼び出し側で「再ログインしてからもう一度お試しください」と案内する
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        FCMTokenSync.unsubscribeFromOwnTopic(uid: uid)

        Firestore.firestore().collection("users").document(uid).delete { [weak self] error in
            if let error {
                completion(.failure(error))
                return
            }
            user.delete { error in
                DispatchQueue.main.async {
                    if let error {
                        completion(.failure(error))
                    } else {
                        self?.user = nil
                        completion(.success(()))
                    }
                }
            }
        }
    }

    deinit {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
