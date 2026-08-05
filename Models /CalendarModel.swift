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
    var ownerId: String?
    var memberIds: [String]
    var colorHex: String?
    var createdAt: Date?

    static func == (lhs: OshiCalendar, rhs: OshiCalendar) -> Bool {
        return lhs.id == rhs.id
    }
}
