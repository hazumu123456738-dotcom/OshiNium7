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
    case followers
    case none

    var label: String {
        switch self {
        case .everyone: return "全員から受け取る"
        case .followers: return "フォロワーのみ"
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

    // ★ アプリ内共通の報酬ポイント。当初は推し活占いで大吉を引くと貯まる用途だけだったが、
    //   今後は予定追加・コミュニティ貢献・投稿・イベント参加など行動全般に対する報酬へ
    //   拡張していく前提のため、獲得手段を限定しない汎用の名前にしている。
    //   将来的にはカレンダー・ホーム画面のデコレーション機能などと交換できるようにする構想
    var points: Int = 0

    // ★ 2026/08/16追加：初回起動時のプロフィール作成・年齢確認（ProfileSetupView）を
    //   完了したかどうか。誕生日フィールドの有無で判定すると、将来「誕生日は空のままでよい」
    //   という仕様変更が入った時に判定基準が壊れるため、専用のフラグとして独立させている
    var hasCompletedOnboarding: Bool = false

    // ★ 2026/08/18追加：Gemini API利用規約の年齢要件（18歳未満に利用される可能性が高い
    //   アプリでの使用を禁止）に対応するため、AI機能(予定検索・グループ情報検索・当日ガイド等)
    //   の利用可否をここで判定する。誕生日は既にProfileSetupViewで13歳以上確認済みの上で
    //   取得済みのため、新たに情報を集めずに算出できる
    var isAdult: Bool {
        guard let date = CachedFormatters.date(format: "yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX")).date(from: birthday) else {
            return false
        }
        let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return age >= 18
    }

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
        points: 0,
        hasCompletedOnboarding: false,
        isPrivateAccount: false,
        commentPermission: .everyone,
        dmPermission: .everyone,
        liveNotifyEnabled: true,
        chatNotifyEnabled: true,
        followNotifyEnabled: true,
        postNotifyEnabled: true
    )
}
