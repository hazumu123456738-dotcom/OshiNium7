//
//  SubscriptionManager.swift
//  OshiNium7
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import StoreKit

// ★ 無課金/プレミアムで機能ごとの上限が変わる。購読ステータス(isPremiumSubscriber)は
//   users/{uid}に直接持たせ、UserSettings/UserSettingsViewModelの通常の保存フロー
//   （saveSettings、フォーム全体を書き戻す形）とは意図的に分離する（oshiFortunePointsと
//   同じ理由：他のフォーム編集で誤って上書きされないように）。
//   ★ 既知の制約：App Store Connect側でこのサブスクリプション商品(productId参照)を
//   実際に作成しないと購入フローは動作しない。このセッションからはApp Store Connectの
//   操作ができないため、商品作成はユーザー自身に依頼する必要がある
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    private init() {}

    @Published private(set) var isPremium: Bool = false

    // ★ App Store Connectで実際に作成する際は、このIDと完全に一致させること
    static let monthlyProductId = "com.hiraihazumu.OshiNium7.premium.monthly"

    // ★ 実際の上限値は SubscriptionLimits(純粋関数・XCTestあり)に集約している。
    //   ここではisPremiumの現在値を渡すだけ
    static let calendarRecreateWindowDays = SubscriptionLimits.calendarRecreateWindowDays

    var groupLimit: Int { SubscriptionLimits.groupLimit(isPremium: isPremium) }
    var packingTemplateLimit: Int { SubscriptionLimits.packingTemplateLimit(isPremium: isPremium) }
    var calendarCreateLimit: Int { SubscriptionLimits.calendarCreateLimit(isPremium: isPremium) }
    var calendarRecreateLimit: Int { SubscriptionLimits.calendarRecreateLimit(isPremium: isPremium) }
    var privateChatCreateLimit: Int { SubscriptionLimits.privateChatCreateLimit(isPremium: isPremium) }
    var privateChatJoinLimit: Int { SubscriptionLimits.privateChatJoinLimit(isPremium: isPremium) }

    func refresh() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isPremium = false
            return
        }
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            let value = snapshot?.data()?["isPremiumSubscriber"] as? Bool ?? false
            DispatchQueue.main.async { self?.isPremium = value }
        }
    }

    private func setPremium(_ value: Bool, completion: @escaping (Error?) -> Void = { _ in }) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .setData(["isPremiumSubscriber": value], merge: true) { [weak self] error in
                if error == nil {
                    DispatchQueue.main.async { self?.isPremium = value }
                }
                completion(error)
            }
    }

    enum PurchaseOutcome {
        case success
        case cancelled
        case productNotConfigured
    }

    // ★ StoreKit 2での購入。productIdがApp Store Connectにまだ存在しない間は
    //   products(for:)が空配列を返すため、それを「未設定」として区別して呼び出し元に伝える
    func purchasePremium() async throws -> PurchaseOutcome {
        let products = try await Product.products(for: [Self.monthlyProductId])
        guard let product = products.first else {
            return .productNotConfigured
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                setPremium(true)
                await (transaction as StoreKit.Transaction).finish()
                return .success
            case .unverified:
                throw SubscriptionError.verificationFailed
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    // ★ 機種変更・再インストール後の「購入の復元」導線用
    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.monthlyProductId {
                setPremium(true)
                return true
            }
        }
        return false
    }
}

enum SubscriptionError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "購入情報の検証に失敗しました。時間をおいてもう一度お試しください。"
        }
    }
}
