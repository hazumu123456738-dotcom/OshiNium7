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
        }
    }

    var isLoggedIn: Bool {
        return user != nil
    }

    func logout() {
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
