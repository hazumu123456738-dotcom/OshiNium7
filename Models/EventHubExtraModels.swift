//
//  EventHubExtraModels.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation

// ★ イベント当日ハブの「チケット情報」「グッズ情報」「公式お知らせ」を、
//   event側の単一Stringフィールド（ticketPrice等）ではなく、複数件を追加できる
//   独立したコレクションとして持たせるためのモデル。VenueReportと同じ
//   「トップレベルコレクション＋eventIdで絞り込み」のパターンに揃える

struct EventTicketInfo: Identifiable, Codable, Equatable {
    var id: String
    var eventId: String
    var groupId: String
    var name: String
    var price: String
    var saleStart: String?
    var note: String?
    var url: String?
    var authorUid: String
    var createdAt: Date
}

struct EventGoodsItem: Identifiable, Codable, Equatable {
    var id: String
    var eventId: String
    var groupId: String
    var name: String
    var price: String?
    var note: String?
    var authorUid: String
    var createdAt: Date
}

struct EventAnnouncement: Identifiable, Codable, Equatable {
    var id: String
    var eventId: String
    var groupId: String
    var title: String
    var body: String?
    var url: String?
    var authorUid: String
    var createdAt: Date
}
