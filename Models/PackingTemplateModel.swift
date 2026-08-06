//
//  PackingTemplateModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import Foundation

// ★ 持ち物チェックリストの「よく持っていくものセット」を、日付に紐付けず
//   自分専用のテンプレートとして保存しておく機能用のモデル。
//   投稿として共有した持ち物リスト（Post.packingTemplateItems）を他ユーザーが
//   自分のテンプレートとして保存するときも、同じ形でこのコレクションに書き込まれる
struct PackingTemplate: Identifiable, Codable, Equatable {
    var id: String
    var uid: String
    var name: String
    var items: [String]
    var createdAt: Date
}
