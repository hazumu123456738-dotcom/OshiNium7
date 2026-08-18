//
//  AnalyticsManager.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/27.
//

import Foundation
import FirebaseAnalytics

// ★ Firebase Analyticsへの薄いラッパー。呼び出し側がFirebaseAnalyticsを直接importせずに
//   すむようにする（他のManagerと同じく、Firebase SDKへの依存をここに閉じ込める）。
//   起動・セッション・画面遷移の基本的な計測はSDKが自動で行うため、ここでは
//   「推し活のOS」としての核となる行動（投稿・予定登録・シェア・AI利用）だけを
//   意図的に絞って計測する
enum AnalyticsManager {

    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    static func logPostCreated(groupId: String, hasMedia: Bool, goodsKind: String?) {
        var params: [String: Any] = ["group_id": groupId, "has_media": hasMedia]
        if let goodsKind { params["goods_kind"] = goodsKind }
        logEvent("post_created", parameters: params)
    }

    static func logEventCreated(groupId: String, method: String) {
        // method: "manual" または "ai"
        logEvent("event_created", parameters: ["group_id": groupId, "method": method])
    }

    static func logSharePostSent(groupId: String) {
        logEvent("share_post_sent", parameters: ["group_id": groupId])
    }

    static func logAIRecommendationGenerated(feature: String) {
        logEvent("ai_recommendation_generated", parameters: ["feature": feature])
    }

    // ★ 2026/08/18（/ultスキル監査）追加：以前は投稿・予定作成・シェア・AI利用しか
    //   計測しておらず、「新規登録→推し登録→グループ参加→投稿→他ユーザー発見→DM→再訪問」
    //   という成長ループの前半（登録・グループ参加・フォロー・DM）が全く追えなかった。
    //   Firebase標準のイベント名(AnalyticsEventSignUp/AnalyticsEventLogin)を使うことで、
    //   Firebaseコンソールの標準レポート（コンバージョン等）とも噛み合うようにする
    static func logSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [AnalyticsParameterMethod: method])
    }

    static func logLogin(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [AnalyticsParameterMethod: method])
    }

    static func logGroupJoined(groupId: String) {
        logEvent("group_joined", parameters: ["group_id": groupId])
    }

    static func logGroupCreated(groupId: String) {
        logEvent("group_created", parameters: ["group_id": groupId])
    }

    static func logUserFollowed(targetUid: String) {
        logEvent("user_followed", parameters: ["target_uid": targetUid])
    }

    static func logDMSent(threadId: String) {
        logEvent("dm_sent", parameters: ["thread_id": threadId])
    }

    // ★ 2026/08/18追加：プレミアム画面の表示→購入の転換率を追えるようにする
    //   （以前はどちらも計測しておらず、サブスク訴求がどれだけ効いているか分からなかった）
    static func logPremiumUpgradeViewShown() {
        logEvent("premium_upgrade_view_shown")
    }

    static func logSubscriptionPurchased() {
        logEvent("subscription_purchased", parameters: ["product": "premium_monthly"])
    }

    // ★ /ult監査で発見：購入計測(subscription_purchased)はあったが、失効・解約・返金で
    //   isPremiumSubscriberがfalseへ戻る瞬間を計測していなかったため、チャーン率が
    //   全く追えなかった。SubscriptionManager.startListeningのFirestore購読内で
    //   true→falseへの変化を検知した時に呼ぶ
    static func logSubscriptionChurned() {
        logEvent("subscription_churned", parameters: ["product": "premium_monthly"])
    }
}
