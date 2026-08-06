//
//  MemoryDiaryModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import Foundation

// ★ カレンダーの日付長押しから書く「思い出日記」。文章＋画像（任意・複数枚）を綴れる、
//   本人だけが読み書きできる個人的な記録（oshiExpenses/packingChecklistItemsと同じ構成）
struct MemoryDiaryEntry: Identifiable, Codable, Equatable {
    var id: String
    var uid: String
    var groupId: String
    var date: Date
    var text: String
    var imageURLs: [String]
    var createdAt: Date
}
