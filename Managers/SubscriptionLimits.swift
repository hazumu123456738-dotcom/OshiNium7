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

    // ★ 無料ユーザーの新規DMスレッド作成数(マスDM対策、/ult監査2026/08/18で追加)。
    //   2026/08/19、CEOの指示によりプレミアム会員は無制限に変更(.maxを返す)。
    //   既存スレッドへの返信・同じ相手への再送信はこの上限の対象外(DirectMessageThreadView.send
    //   がmessages.isEmptyの時=新規スレッドの時だけこの値を使ってチェックする)
    static func dmNewThreadDailyLimit(isPremium: Bool) -> Int {
        isPremium ? .max : 20
    }

    // ★ 2026/08/20、CEOの指示により運営コスト検討の一環で追加。タイムライン投稿は
    //   グループの全メンバーが繰り返し閲覧する共有データのため、DM等の1対1メディアより
    //   Storage容量・転送コストへの影響が大きい。1投稿あたりの画像・動画の枚数上限を
    //   無課金は半分(5枚)に絞り、プレミアムは従来通り10枚のままにする
    static func postMediaLimit(isPremium: Bool) -> Int {
        isPremium ? 10 : 5
    }

    // ★ 動画は画像と違い、圧縮後も1本あたり数MB〜数十MBになりうる上、タイムラインで
    //   自動的にサムネイル生成・複数人が繰り返し視聴するため、画像投稿より運営コストへの
    //   影響が大きい。CEOの指示により動画投稿自体をプレミアム会員限定の機能にする
    //   (既存の会場口コミ・持ち物テンプレ等は新規メディアアップロードを伴わないため対象外。
    //   DM・思い出日記の動画は1対1/本人のみの閲覧で影響が小さいため、今回は対象外のまま)
    static func canPostVideo(isPremium: Bool) -> Bool {
        isPremium
    }
}
