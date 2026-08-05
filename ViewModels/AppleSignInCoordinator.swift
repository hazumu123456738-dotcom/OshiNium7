//
//  AppleSignInCoordinator.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import UIKit

// ★ Sign in with Appleの実処理。ASAuthorizationControllerのdelegate/presentation contextは
//   NSObjectでないと適合できないため、LoginView（struct）とは別にこのクラスへ切り出す。
//   Firebase側はリプレイ攻撃対策のためnonce（ランダム文字列とそのSHA256ハッシュ）を要求するので、
//   Appleへのリクエスト時にハッシュ済みnonceを渡し、Firebaseへの認証時には元の生nonceを渡す
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    enum SignInError: LocalizedError {
        case invalidCredential
        case missingNonce
        case missingIDToken

        var errorDescription: String? {
            switch self {
            case .invalidCredential: return "Appleからの認証情報を取得できませんでした"
            case .missingNonce: return "nonceの検証に失敗しました。もう一度お試しください"
            case .missingIDToken: return "Appleからのトークンを取得できませんでした"
            }
        }
    }

    private var currentNonce: String?
    private var completion: ((Result<User, Error>) -> Void)?

    func signIn(completion: @escaping (Result<User, Error>) -> Void) {
        self.completion = completion

        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(.failure(SignInError.invalidCredential))
            return
        }
        guard let nonce = currentNonce else {
            completion?(.failure(SignInError.missingNonce))
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            completion?(.failure(SignInError.missingIDToken))
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        Task {
            do {
                let authResult = try await Auth.auth().signIn(with: credential)
                await MainActor.run { self.completion?(.success(authResult.user)) }
            } catch {
                await MainActor.run { self.completion?(.failure(error)) }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // ★ ユーザーが自らキャンセルした場合はエラー表示せず、静かに終える
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }
        completion?(.failure(error))
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }

    // MARK: - nonce生成（Firebase公式ドキュメントのSign in with Apple実装と同じ方式）

    private static func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "nonceの生成に失敗しました: \(status)")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
