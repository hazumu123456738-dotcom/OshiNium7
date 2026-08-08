//
//  GroupCounting.swift
//  OshiNium7
//

import Foundation

// ★ GroupViewModel.groups([IdolGroup])から「推しグループ何件・招待制グループチャットを
//   何件作った/参加しているか」を数える部分だけを、Firestoreに一切依存しない純粋関数として
//   切り出したもの。DirectMessagePolicyと同じ狙いで、XCTestで直接検証できるようにする
enum GroupCounting {
    // ★ 推しグループの上限に数えるのは招待制グループチャット(isPrivate)を除いたもの
    static func oshiGroupCount(in groups: [IdolGroup]) -> Int {
        groups.filter { !$0.isPrivate }.count
    }

    // ★ 自分がオーナーとして作成した招待制グループチャットの数
    static func ownedPrivateChatCount(in groups: [IdolGroup], myUid: String?) -> Int {
        guard let myUid else { return 0 }
        return groups.filter { $0.isPrivate && $0.createdByUid == myUid }.count
    }

    // ★ 他人が作成した招待制グループチャットに、招待され参加している数
    static func joinedPrivateChatCount(in groups: [IdolGroup], myUid: String?) -> Int {
        guard let myUid else { return 0 }
        return groups.filter { $0.isPrivate && $0.createdByUid != myUid }.count
    }
}
