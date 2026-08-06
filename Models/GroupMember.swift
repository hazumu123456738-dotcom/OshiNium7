//
//  GroupMember.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

// ★ グループ内の権限。旧データ（role未設定の既存メンバー）は"member"として扱う
enum GroupRole: String, Codable {
    case owner, admin, member

    // ★ メンバーの追加・削除・昇格降格ができるか
    var canManageMembers: Bool { self == .owner || self == .admin }
    // ★ グループ自体を削除できるか（オーナーのみ）
    var canDeleteGroup: Bool { self == .owner }
    // ★ 他人の投稿・メッセージを削除できるか（オーナー・管理者）
    var canModerateContent: Bool { self == .owner || self == .admin }

    var displayLabel: String {
        switch self {
        case .owner: return "オーナー"
        case .admin: return "管理者"
        case .member: return "メンバー"
        }
    }
}

struct GroupMember: Identifiable, Codable, Equatable {
    var id: String { uid }
    var uid: String
    var displayName: String
    var iconURL: String?
    var joinedAt: Date?
    // ★ nil = Firestore側にまだroleが保存されていない（旧データ）。表示・判定には
    //   effectiveRoleを使う。ここをnilのまま保持しておくことで、GroupViewModel.myRole(in:)側で
    //   「role未設定なら作成者かどうかで自己修復する」判定ができる
    var role: GroupRole?

    var effectiveRole: GroupRole { role ?? .member }
}
