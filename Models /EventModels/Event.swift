//
//  Event.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import Foundation
import FirebaseFirestore

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var date: Date
    var memo: String?
    var groupId: String?
    var type: String?   // ← Firestore に合わせて追加

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.memo = try container.decodeIfPresent(String.self, forKey: .memo)
        self.groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)

        // Timestamp or Date の両方に対応
        if let timestamp = try? container.decode(Timestamp.self, forKey: .date) {
            self.date = timestamp.dateValue()
        } else {
            self.date = try container.decode(Date.self, forKey: .date)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encode(date, forKey: .date)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case memo
        case groupId
        case type
    }
}
