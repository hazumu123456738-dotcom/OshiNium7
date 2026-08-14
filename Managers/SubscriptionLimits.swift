//
//  SubscriptionLimits.swift
//  OshiNium7
//

import Foundation

// ★ 無課金/プレミアムの機能別上限の「数字そのもの」だけを持つ、Firestore/StoreKitに
//   一切依存しない純粋な計算ロジック。SubscriptionManager(シングルトン、Firestore購読を持つ)
//   から数字部分だけを切り出すことで、DirectMessagePolicy等と同じくXCTestで直接検証できるようにする。
//   ここを直接書き換えれば、SubscriptionManager側は何もいじらずに上限値だけ調整できる
enum SubscriptionLimits {
    static let calendarRecreateWindowDays = 10

    // ★ 匿名ログインは「1グループだけ」に制限する（ユーザー登録すれば無課金でも2つまで）。
    //   匿名かどうかはisPremiumと独立した軸なので、既定値falseの追加引数にして
    //   他の呼び出し元（無課金/プレミアムしか気にしない箇所）に影響を与えないようにする
    static func groupLimit(isPremium: Bool, isAnonymous: Bool = false) -> Int {
        if isAnonymous { return 1 }
        return isPremium ? 5 : 2
    }

    static func packingTemplateLimit(isPremium: Bool) -> Int {
        isPremium ? 10 : 3
    }

    static func calendarCreateLimit(isPremium: Bool) -> Int {
        isPremium ? 5 : 1
    }

    static func calendarRecreateLimit(isPremium: Bool) -> Int {
        isPremium ? 5 : 1
    }

    // ★ 招待制グループチャットの「作成」だけは無課金0件(=プレミアム限定機能)
    static func privateChatCreateLimit(isPremium: Bool) -> Int {
        isPremium ? 3 : 0
    }

    static func privateChatJoinLimit(isPremium: Bool) -> Int {
        isPremium ? 3 : 1
    }
}
