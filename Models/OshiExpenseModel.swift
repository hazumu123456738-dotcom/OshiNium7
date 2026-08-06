//
//  OshiExpenseModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation

// ★ 推し活でいくら使ったかを記録する「推し活金額計算」機能用のモデル。
//   本人にしか見せない家計簿のようなものなので、uidで自分のものだけに絞り込んで使う
struct OshiExpense: Identifiable, Codable, Equatable {
    var id: String
    var uid: String
    var groupId: String?
    var groupName: String?
    var category: String   // "チケット" | "グッズ" | "交通費" | "宿泊費" | "その他"
    var amount: Int         // 円
    var note: String?
    var imageURL: String?   // ★ 任意。レシート・グッズの写真など（形にできない交通費等は無しでもよい）
    var date: Date
    var createdAt: Date

    // ★ 一覧表示「〇〇に◯円かかった」の〇〇部分。具体的なメモがあればそちらを優先する
    var spentOnLabel: String {
        if let note, !note.isEmpty { return note }
        return category
    }
}

enum OshiExpenseCategory: String, CaseIterable, Identifiable {
    case ticket = "チケット"
    case goods = "グッズ"
    case transport = "交通費"
    case lodging = "宿泊費"
    case other = "その他"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ticket: return "ticket.fill"
        case .goods: return "bag.fill"
        case .transport: return "tram.fill"
        case .lodging: return "bed.double.fill"
        case .other: return "yensign.circle.fill"
        }
    }
}
