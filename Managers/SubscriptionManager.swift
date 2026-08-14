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
//   users/{uid}に持たせているが、2026/08/11以降はクライアントから直接書き込めない
//   （firestore.rules参照）。StoreKitの署名付きトランザクション(JWS)をCloud Function
//   （verifyPremiumPurchase/appStoreNotifications、functions/index.js）へ送り、
//   Apple公式ライブラリでサーバー側からも独立に検証してもらった上で、Admin SDK経由
//   （ルールを経由しない特権アクセス）でのみ書き込んでもらう構成にした。
//   以前はクライアントが検証後に直接setDataしており、理論上は課金なしでも
//   isPremiumSubscriberをtrueに書き換えられてしまっていた（詳しくは各関数のコメント参照）。
//   ★ 既知の制約：App Store Connect側でこのサブスクリプション商品(productId参照)を
//   実際に作成しないと購入フローは動作しない。このセッションからはApp Store Connectの
//   操作ができないため、商品作成・App Store Server通知の設定はユーザー自身に依頼する必要がある
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private var transactionUpdatesTask: Task<Void, Never>?
    private var entitlementsRecheckTask: Task<Void, Never>?
    private var listener: ListenerRegistration?

    private init() {
        // ★ StoreKitの取引更新を購入操作の同期的な結果（purchasePremium()内のawait
        //   product.purchase()）だけでなく、常時ここでも監視する。ファミリー共有の
        //   Ask-to-Buy承認や、アプリ外・別デバイスで確定した更新取引が後から届いても、
        //   サーバー検証を経てisPremiumSubscriberへ反映されるようにする
        transactionUpdatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                if transaction.productID == Self.monthlyProductId {
                    // ★ jwsRepresentationはVerificationResult自体が持つプロパティであり、
                    //   中身を取り出した後のTransaction型には存在しない
                    await self?.verifyWithServer(result.jwsRepresentation)
                }
                await transaction.finish()
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
        entitlementsRecheckTask?.cancel()
        listener?.remove()
    }

    @Published private(set) var isPremium: Bool = false

    // ★ App Store Connectで実際に作成する際は、このIDと完全に一致させること
    static let monthlyProductId = "com.hiraihazumu.OshiNium7.premium.monthly"

    // ★ 実際の上限値は SubscriptionLimits(純粋関数・XCTestあり)に集約している。
    //   ここではisPremiumの現在値を渡すだけ
    static let calendarRecreateWindowDays = SubscriptionLimits.calendarRecreateWindowDays

    var groupLimit: Int {
        SubscriptionLimits.groupLimit(isPremium: isPremium, isAnonymous: Auth.auth().currentUser?.isAnonymous ?? false)
    }
    var packingTemplateLimit: Int { SubscriptionLimits.packingTemplateLimit(isPremium: isPremium) }
    var calendarCreateLimit: Int { SubscriptionLimits.calendarCreateLimit(isPremium: isPremium) }
    var calendarRecreateLimit: Int { SubscriptionLimits.calendarRecreateLimit(isPremium: isPremium) }
    var privateChatCreateLimit: Int { SubscriptionLimits.privateChatCreateLimit(isPremium: isPremium) }
    var privateChatJoinLimit: Int { SubscriptionLimits.privateChatJoinLimit(isPremium: isPremium) }

    // ★ isPremiumSubscriberの実体はCloud Function側だけが書き込む値なので、ここではその結果を
    //   リアルタイムで購読するだけにする（以前のrefresh()は一度きりのgetDocumentだった）。
    //   あわせて、アプリを開いていない間に起きた自動更新・失効・返金が未反映のままにならないよう、
    //   サインインのたびにTransaction.currentEntitlementsを静かに再検証する
    //   （AppStore.sync()と違い、サインインを促すUIは出ない）
    func startListening(uid: String) {
        listener?.remove()
        listener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                let value = snapshot?.data()?["isPremiumSubscriber"] as? Bool ?? false
                DispatchQueue.main.async { self?.isPremium = value }
            }

        entitlementsRecheckTask?.cancel()
        entitlementsRecheckTask = Task { [weak self] in
            for await result in StoreKit.Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.monthlyProductId else { continue }
                await self?.verifyWithServer(result.jwsRepresentation)
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        entitlementsRecheckTask?.cancel()
        entitlementsRecheckTask = nil
    }

    enum PurchaseOutcome {
        case success
        case cancelled
        case productNotConfigured
        // ★ ファミリー共有のAsk-to-Buy等で、購入者本人以外の承認待ちになっている状態。
        //   以前はcancelledと区別しておらず、承認待ちなのに「キャンセルされました」と
        //   表示してしまっていた。承認され次第Transaction.updatesが拾ってisPremiumが更新される
        case pending
    }

    // ★ StoreKit 2での購入。productIdがApp Store Connectにまだ存在しない間は
    //   products(for:)が空配列を返すため、それを「未設定」として区別して呼び出し元に伝える
    func purchasePremium() async throws -> PurchaseOutcome {
        let products = try await Product.products(for: [Self.monthlyProductId])
        guard let product = products.first else {
            return .productNotConfigured
        }

        // ★ appAccountTokenを添えて購入することで、Apple自身がプッシュしてくるApp Store
        //   Server通知（アプリを開いていない間の自動更新・失効・返金等）から「どのFirebase
        //   ユーザーの購入か」をCloud Functions側で逆引きできるようにする
        let token = currentOrNewAppAccountToken()
        let result = try await product.purchase(options: [.appAccountToken(token)])
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await verifyWithServer(verification.jwsRepresentation)
                await transaction.finish()
                return .success
            case .unverified:
                throw SubscriptionError.verificationFailed
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    // ★ 機種変更・再インストール後の「購入の復元」導線用
    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        var foundActive = false
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.monthlyProductId {
                await verifyWithServer(result.jwsRepresentation)
                foundActive = true
            }
        }
        return foundActive
    }

    // MARK: - appAccountTokenの管理
    // ★ UUIDを端末に1つだけ保持し、購入のたびに使い回す。生成のたびにFirestoreの
    //   対応表(storeKitAccountTokens/{token} -> uid)も最新化しておく
    //   （firestore.rules: 自分のuidを値にした作成のみ許可、読み取りはクライアントから不可）
    private static let appAccountTokenDefaultsKey = "subscriptionAppAccountToken"

    private func currentOrNewAppAccountToken() -> UUID {
        let token: UUID
        if let raw = UserDefaults.standard.string(forKey: Self.appAccountTokenDefaultsKey),
           let existing = UUID(uuidString: raw) {
            token = existing
        } else {
            token = UUID()
            UserDefaults.standard.set(token.uuidString, forKey: Self.appAccountTokenDefaultsKey)
        }
        registerAppAccountToken(token)
        return token
    }

    private func registerAppAccountToken(_ token: UUID) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("storeKitAccountTokens").document(token.uuidString.lowercased())
            .setData(["uid": uid], merge: true) { error in
                if let error { print("🔥 storeKitAccountTokens登録エラー:", error) }
            }
    }

    // MARK: - サーバー検証
    // ★ StoreKit側で「検証済み」となったトランザクションでも、それだけでは
    //   FirestoreのisPremiumSubscriberを直接書き換えない（firestore.rulesがクライアントからの
    //   直接書き込みを許可していないため、書いても無視される）。生のJWS
    //   （VerificationResult.jwsRepresentation。Transaction自体には無いプロパティなので
    //   呼び出し元でVerificationResultから取り出して渡す）をCloud Functionへ送り、
    //   Apple公式ライブラリでサーバー側からも独立に検証してもらってから、Admin SDK経由で書き込んでもらう
    private func verifyWithServer(_ transactionJWS: String) async {
        guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else { return }
        guard let url = URL(string: "https://asia-northeast1-oshinium-79256.cloudfunctions.net/verifyPremiumPurchase") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["transactionJWS": transactionJWS])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let verifiedIsPremium = json["isPremium"] as? Bool else {
                print("🔥 verifyPremiumPurchase: 予期しないレスポンス")
                return
            }
            // ★ Firestoreの購読(startListening)が直後に同じ値を拾うが、往復の間だけでも
            //   UIへ即時反映されるよう楽観的に更新しておく
            await MainActor.run { self.isPremium = verifiedIsPremium }
        } catch {
            print("🔥 verifyPremiumPurchase: 通信エラー:", error)
        }
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
