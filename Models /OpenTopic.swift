//
//  OpenTopic.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import Foundation

// ★ コミュニティチャットの「公開版」。匿名チャットと同じく、メンバーなら誰でも自由に
//   話題（トークルーム）を立てられ、他のメンバーが立てたトークルームにも自由に参加・閲覧できる。
//   匿名版との違いは、発言者の名前・アイコンをそのまま表示すること
//   （＝同じ推しを応援する仲間として、実アカウントで繋がりたい人向けの入口）
struct OpenTopic: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var creatorUid: String
    var createdAt: Date
    var lastMessageAt: Date
    var messageCount: Int
}
