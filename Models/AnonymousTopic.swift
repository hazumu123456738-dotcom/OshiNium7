//
//  AnonymousTopic.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/03.
//

import Foundation

// ★ 匿名チャット内に、誰でも自由に立てられる「話題のトークルーム」。
//   1グループにつき無数のトークルームが存在でき、他のメンバーが立てたトークルームにも
//   自由に参加・閲覧できる。creatorUidはモデレーション（自分が立てたルームの削除）
//   のためだけに保持し、UI上には一切表示しない（メッセージ本文と同じ匿名方針）
struct AnonymousTopic: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var creatorUid: String
    var createdAt: Date
    var lastMessageAt: Date
    var messageCount: Int
}
