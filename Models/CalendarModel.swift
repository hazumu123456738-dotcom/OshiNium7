//
//  CalendarModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

struct OshiCalendar: Identifiable, Codable, Equatable {
    var id: String
    var groupId: String
    var name: String
    var isCommunity: Bool
    // ★ コミュニティと同じく常時1件だけ自動用意される、自分だけの非公開カレンダー。
    //   誰も招待できず、削除もできない（CalendarViewModel参照）
    var isPrivate: Bool = false
    var ownerId: String?
    var memberIds: [String]
    var colorHex: String?
    var createdAt: Date?

    static func == (lhs: OshiCalendar, rhs: OshiCalendar) -> Bool {
        return lhs.id == rhs.id
    }
}
