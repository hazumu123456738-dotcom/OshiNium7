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
    var type: String   // "follow" / "event_created" / "event_deleted"
    var actorUid: String
    var actorName: String
    var actorIconURL: String?
    var createdAt: Date
    var isRead: Bool

    // ★ "event_created" / "event_deleted" 用（予定通知）。グループのコミュニティカレンダーに
    //   予定が追加/削除された時に使う。どのグループ・どの予定かをこの通知だけで表示できるように持たせる
    var groupId: String?
    var groupName: String?
    var eventId: String?
    var eventTitle: String?
}
