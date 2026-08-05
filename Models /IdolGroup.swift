//
//  IdolGroup.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import Foundation
import UIKit

// IdolGroup model (FirebaseFirestoreSwift を使わない版)
struct IdolGroup: Identifiable, Codable, Equatable {
    // Firestore のドキュメントID を文字列で保持（必須）
    var id: String
    var name: String
    var imageData: Data?
    var reading: String?
    var fandom: String?
    var concept: String?
    var history: String?
    var groupDescription: String?
    var createdAt: Date?
    // ★ グループ作成者のuid。role未設定の旧メンバーデータに対して「作成者=オーナー」を
    //   自己修復的に判定するためのフォールバックに使う
    var createdByUid: String?
    // ★ trueなら「招待制のグループチャット」。検索で見つかる公開カタログには出さず、
    //   招待リンク（招待コード）を知っている人だけが参加できる
    var isPrivate: Bool = false

    init(
        id: String = UUID().uuidString,
        name: String,
        imageData: Data? = nil,
        reading: String? = nil,
        fandom: String? = nil,
        concept: String? = nil,
        history: String? = nil,
        groupDescription: String? = nil,
        createdAt: Date? = nil,
        createdByUid: String? = nil,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.reading = reading
        self.fandom = fandom
        self.concept = concept
        self.history = history
        self.groupDescription = groupDescription
        self.createdAt = createdAt
        self.createdByUid = createdByUid
        self.isPrivate = isPrivate
    }

    static func == (lhs: IdolGroup, rhs: IdolGroup) -> Bool {
        return lhs.id == rhs.id
    }
}
