//
//  GroupMember.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

// ★ 2026/08/13：グループ内の権限差（オーナー・管理者）という概念そのものを廃止した。
//   メンバーは全員対等で、誰かが他メンバーを昇格・降格・強制退出させたり、
//   他人の投稿・メッセージを代わりに削除したりする権限は持たない
//   （自分自身の投稿・メッセージの削除はこれまで通り本人にだけ許可される）
struct GroupMember: Identifiable, Codable, Equatable {
    var id: String { uid }
    var uid: String
    var displayName: String
    var iconURL: String?
    var joinedAt: Date?
}
