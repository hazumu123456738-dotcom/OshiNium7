//
//  AppNotificationModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation

// ★ アプリ内通知（フォローされた時など）。
//   このプロジェクトにはCloud Functions/FCMのようなサーバー側のpush基盤がまだ無いため、
//   端末が閉じている間の本物のプッシュ通知はできない。ここではアプリを開いている間に
//   リアルタイムで届く「アプリ内通知」として実装する
struct AppNotification: Identifiable, Codable, Equatable {
    var id: String
    var recipientUid: String
    // "follow" / "follow_request" / "follow_request_accepted" / "group_invite" /
    // "event_created" / "event_approval_request" / "post_like" / "post_comment"
    var type: String
    var actorUid: String
    var actorName: String
    var actorIconURL: String?
    var createdAt: Date
    var isRead: Bool

    // ★ "event_created" 用（予定通知）。グループのコミュニティカレンダーに
    //   予定が追加された時に使う。どのグループ・どの予定かをこの通知だけで表示できるように持たせる
    var groupId: String?
    var groupName: String?
    var eventId: String?
    var eventTitle: String?

    // ★ "post_like" / "post_comment" 用（2026/08/11追加）。どの投稿への反応かをこの通知だけで
    //   表示・遷移できるように持たせる
    var postId: String?
}

// ★ 運営（開発者）からの全体お知らせ（2026/08/13追加）。新機能・予定追加方法の変更など、
//   個々のユーザー宛てではなく全員に一律で届けたい内容を発信するための、AppNotificationとは
//   別枠の掲示板。recipientUidを持たず、1件書けば全ユーザーに同じものが見える設計。
//   投稿はこのアプリ内には管理画面が無いため、Firebaseコンソールからannouncementsコレクションに
//   直接ドキュメントを作成する運用にする（restrictedUsersと同じ「コンソールから手動」パターン）
struct Announcement: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var body: String
    var createdAt: Date
    // ★ 未指定ならNotificationsTab側でmegaphone.fillにフォールバックする
    var iconName: String?
}
