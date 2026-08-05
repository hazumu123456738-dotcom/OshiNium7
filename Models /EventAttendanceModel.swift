//
//  EventAttendanceModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import Foundation

// ★ 「参戦記録」機能用。過去の予定1つにつき「参戦しましたか？」の回答を1件持つ。
//   本人にしか見せない記録なので、uidで自分のものだけに絞り込んで使う。
//   ドキュメントIDは "{uid}_{eventId}" にして、同じ予定への回答を上書き保存できるようにする
struct EventAttendanceRecord: Identifiable, Codable, Equatable {
    var id: String
    var uid: String
    var eventId: String
    var attended: Bool
    var answeredAt: Date
}
