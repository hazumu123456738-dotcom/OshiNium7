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
            if let user {
                FCMTokenSync.syncCurrentToken()
                Self.ensureProfileDocumentExists(for: user)
            }
            // ★ クラッシュレポート上で「どのユーザーで起きたか」を追えるようにする
            CrashReportManager.setUserId(user?.uid)
        }
    }

    // ★ 以前はusers/{uid}が「設定画面を開いて保存した時」にしか作られなかったため、
    //   一度も設定を保存していない相手へのDM初回送信・投稿へのコメントが、
    //   firestore.rulesのget(users/{uid}).data...（recipientAcceptsDM/canCommentOn）で
    //   ドキュメント不在のまま評価され権限エラーになっていた。サインインのたびに、
    //   存在しなければ最小限のプロフィールを作成しておくことでこれを防ぐ。
    //   匿名ログイン（閲覧専用アカウント）は対象外にする
    private static func ensureProfileDocumentExists(for user: User) {
        guard !user.isAnonymous else { return }
        let ref = Firestore.firestore().collection("users").document(user.uid)
        ref.getDocument { snapshot, error in
            guard error == nil, snapshot?.exists != true else { return }
            ref.setData([
                "displayName": user.displayName ?? "",
                "iconURL": user.photoURL?.absoluteString ?? ""
            ]) { error in
                if let error { print("🔥 ensureProfileDocumentExists error:", error) }
            }
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
    //   ★ ここではusers/{uid}ドキュメントとFirebase Authのアカウント自体をベストエフォートで
    //   削除するのみ。posts/フォロー関係/グループ参加記録/Storage画像等の横断的な削除は、
    //   Firebase Auth側のアカウント削除を検知して発火するCloud Functions
    //   （functions/index.js の cleanupUserDataOnDelete、functionsV1.auth.user().onDelete）が
    //   Admin SDK経由（Firestoreルールを経由しない特権アクセス）で担う。クライアント側の権限では
    //   他コレクションを横断削除できないため、この責務分担は意図的なもの。
    //   ★ Firebaseの仕様上、直近のサインインから時間が経っていると
    //   currentUser.delete()が.requiresRecentLoginで失敗する。その場合は
    //   呼び出し側で「再ログインしてからもう一度お試しください」と案内する
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        FCMTokenSync.unsubscribeFromOwnTopic(uid: uid)

        // ★ 以前はFirestoreのプロフィール削除を先に行っていたため、その後のuser.delete()が
        //   .requiresRecentLogin（直近のサインインから時間が経っている場合にFirebaseが
        //   要求する再認証エラー）で失敗すると、プロフィールだけ消えてAuthアカウントは
        //   生き残ったまま＝ログイン状態は続くのにプロフィールが空、という復旧不能な
        //   中途半端な状態になっていた。認証アカウントの削除を先に行い、それが成功して
        //   初めてFirestore側の削除に進む順序に直す。
        //   ★ Firestore側の削除は、アカウント削除が終わった後の後片付け（ベストエフォート）
        //   として扱い、完了・失敗を待たずに呼び出し元へは成功を返す。user.delete()の直後は
        //   IDトークンの失効タイミングが保証されないため、この削除リクエスト自体が
        //   権限エラーになる可能性があるが、その場合でも「アカウント自体は削除済みで
        //   二度とログインできない」状態は達成できており、審査ガイドライン5.1.1(v)が
        //   求めるアカウント削除としては成立する（孤立したプロフィールドキュメントが
        //   残る可能性があるだけで、本人には実害が無い）
        user.delete { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            Firestore.firestore().collection("users").document(uid).delete { error in
                if let error { print("🔥 deleteAccount: プロフィール後片付け失敗（アカウント自体は削除済み）:", error) }
            }
            DispatchQueue.main.async {
                self?.user = nil
                completion(.success(()))
            }
        }
    }

    deinit {
        if let handle = listenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
