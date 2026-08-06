//
//  PackingChecklistModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import Foundation

// ★ ライブ・イベント当日の持ち物を記録する機能用のモデル。推し活の金額計算と同様、
//   本人にしか見せないメモなので、uidで自分のものだけに絞り込んで使う
struct PackingChecklistItem: Identifiable, Codable, Equatable {
    var id: String
    var uid: String
    var groupId: String?
    var groupName: String?
    var title: String
    var isChecked: Bool
    var date: Date
    var createdAt: Date
    // ★ 設定されていればこの日時にローカル通知でリマインドする（nil = 通知しない）
    var remindAt: Date?
}
