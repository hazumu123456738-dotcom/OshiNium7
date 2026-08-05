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
}
