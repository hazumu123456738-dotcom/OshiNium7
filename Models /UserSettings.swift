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

    static let empty = UserSettings(
        displayName: "",
        bio: "",
        iconURL: "",
        birthday: "",
        snsLinks: [],
        defaultNotifyMinutes: nil
    )
}
