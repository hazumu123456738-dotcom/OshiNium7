//
//  UserSettings.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/26.
//

import Foundation

// ★ 投稿・コメントを誰に許可するか。「全員」「フォロワーのみ」「誰にも許可しない」の3段階
enum CommentPermission: String, Codable, CaseIterable {
    case everyone
    case followers
    case none

    var label: String {
        switch self {
        case .everyone: return "全員"
        case .followers: return "フォロワーのみ"
        case .none: return "受け付けない"
        }
    }
}

// ★ DM（メッセージリクエスト含む）を誰から受け取るか
enum DMPermission: String, Codable, CaseIterable {
    case everyone
    case none

    var label: String {
        switch self {
        case .everyone: return "全員から受け取る"
        case .none: return "受け取らない"
        }
    }
}

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

    // MARK: - プライバシー設定（設定画面「🔒 プライバシー」から変更）
    var commentPermission: CommentPermission = .everyone
    var dmPermission: DMPermission = .everyone

    // MARK: - 通知設定（設定画面「🔔 通知」から変更。ON/OFFの管理のみ）
    var liveNotifyEnabled: Bool = true
    var chatNotifyEnabled: Bool = true
    var followNotifyEnabled: Bool = true
    var postNotifyEnabled: Bool = true

    static let empty = UserSettings(
        displayName: "",
        bio: "",
        iconURL: "",
        birthday: "",
        snsLinks: [],
        defaultNotifyMinutes: nil,
        oshiFortunePoints: 0,
        isPrivateAccount: false,
        commentPermission: .everyone,
        dmPermission: .everyone,
        liveNotifyEnabled: true,
        chatNotifyEnabled: true,
        followNotifyEnabled: true,
        postNotifyEnabled: true
    )
}
