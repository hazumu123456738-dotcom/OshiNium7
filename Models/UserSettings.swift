//
//  UserSettings.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/26.
//

import Foundation

struct UserSettings: Codable {
    var displayName: String
    var bio: String
    var iconURL: String
    var birthday: String
    var snsLinks: [String]

    // 🔔 デフォルト通知時間（nil = 通知しない）
    var defaultNotifyMinutes: Int? = nil

    // ★ 推し活占いで大吉を引くと貯まるポイント。将来的にカレンダー・ホーム画面の
    //   デコレーション機能などと交換できるようにする構想の第一歩
    var oshiFortunePoints: Int = 0

    // ★ 非公開アカウント（鍵垢）。trueの場合、自分をフォローしていない相手には
    //   投稿を見せない（firestore.rulesのposts/{postId}側で実際に強制する）
    var isPrivateAccount: Bool = false

    static let empty = UserSettings(
        displayName: "",
        bio: "",
        iconURL: "",
        birthday: "",
        snsLinks: [],
        defaultNotifyMinutes: nil,
        oshiFortunePoints: 0,
        isPrivateAccount: false
    )
}
