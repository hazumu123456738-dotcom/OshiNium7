//
//  DMThreadModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation

// ★ DM（個人間チャット）のスレッド一覧表示用。
//   ドキュメントIDは参加者2人のuidをソートして "_" で結合したもの（"{uidA}_{uidB}"）にすることで、
//   同じ2人の間のスレッドが常に1つに定まるようにしている
struct DMThread: Identifiable, Codable, Equatable {
    var id: String
    var participants: [String]
    var lastMessage: String
    var lastMessageAt: Date
    var lastSenderUid: String?

    // ★ 相手のuid（2人しかいない前提。自分のuidを渡して残った方を返す）
    func otherUid(myUid: String) -> String? {
        participants.first { $0 != myUid }
    }

    static func threadId(_ uidA: String, _ uidB: String) -> String {
        [uidA, uidB].sorted().joined(separator: "_")
    }
}
