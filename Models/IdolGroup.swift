//
//  IdolGroup.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import Foundation
import UIKit

// ★ 「会場口コミ」で同じカテゴリの他グループの口コミも見られるようにするための分類。
//   新規グループ作成時に必須で選ばせる（既存グループはnilのままになりうるため、
//   詳細編集画面でも後から設定できるようにする）
enum GroupCategory: String, CaseIterable, Identifiable, Codable {
    case kpop = "K-POP"
    case maleIdol = "男性アイドル"
    case femaleIdol = "女性アイドル"
    case vtuber = "VTuber"
    case voiceActor = "声優"
    case anime = "アニメ・キャラクター"
    // ★ 個人で活動する配信者・実況者・元プロゲーマー等（アイドルグループ等の既存カテゴリに
    //   当てはまらない個人勢）。AIによる自動情報収集で、同名の別人と混同されやすいため新設した
    case streamer = "配信者・個人勢"
    case other = "その他"

    var id: String { rawValue }
}

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
    // ★ 「会場口コミ」の同カテゴリ横断表示に使う。この機能の追加より前に作られた
    //   グループはnilのままのことがあるため、扱う側はnilを「未設定」として許容すること
    var category: GroupCategory? = nil

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
        isPrivate: Bool = false,
        category: GroupCategory? = nil
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
        self.category = category
    }

    static func == (lhs: IdolGroup, rhs: IdolGroup) -> Bool {
        return lhs.id == rhs.id
    }
}
