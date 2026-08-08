//
//  GroupCountingTests.swift
//  OshiNium7Tests
//

import XCTest
@testable import OshiNium7

final class GroupCountingTests: XCTestCase {

    private func group(id: String, isPrivate: Bool, createdByUid: String?) -> IdolGroup {
        IdolGroup(id: id, name: "test-\(id)", createdByUid: createdByUid, isPrivate: isPrivate)
    }

    // MARK: - oshiGroupCount

    func testOshiGroupCountExcludesPrivateChats() {
        let groups = [
            group(id: "1", isPrivate: false, createdByUid: "me"),
            group(id: "2", isPrivate: false, createdByUid: "me"),
            group(id: "3", isPrivate: true, createdByUid: "me")
        ]
        XCTAssertEqual(GroupCounting.oshiGroupCount(in: groups), 2)
    }

    func testOshiGroupCountWithNoGroupsIsZero() {
        XCTAssertEqual(GroupCounting.oshiGroupCount(in: []), 0)
    }

    // MARK: - ownedPrivateChatCount

    func testOwnedPrivateChatCountOnlyCountsGroupsICreated() {
        let groups = [
            group(id: "1", isPrivate: true, createdByUid: "me"),
            group(id: "2", isPrivate: true, createdByUid: "someoneElse"),
            group(id: "3", isPrivate: false, createdByUid: "me") // 推しグループなのでカウント対象外
        ]
        XCTAssertEqual(GroupCounting.ownedPrivateChatCount(in: groups, myUid: "me"), 1)
    }

    func testOwnedPrivateChatCountWithNilUidIsZero() {
        let groups = [group(id: "1", isPrivate: true, createdByUid: "me")]
        XCTAssertEqual(GroupCounting.ownedPrivateChatCount(in: groups, myUid: nil), 0)
    }

    // MARK: - joinedPrivateChatCount

    func testJoinedPrivateChatCountOnlyCountsGroupsSomeoneElseCreated() {
        let groups = [
            group(id: "1", isPrivate: true, createdByUid: "me"),
            group(id: "2", isPrivate: true, createdByUid: "friendA"),
            group(id: "3", isPrivate: true, createdByUid: "friendB"),
            group(id: "4", isPrivate: false, createdByUid: "friendA") // 推しグループなのでカウント対象外
        ]
        XCTAssertEqual(GroupCounting.joinedPrivateChatCount(in: groups, myUid: "me"), 2)
    }

    func testJoinedPrivateChatCountWithNilUidIsZero() {
        let groups = [group(id: "1", isPrivate: true, createdByUid: "friendA")]
        XCTAssertEqual(GroupCounting.joinedPrivateChatCount(in: groups, myUid: nil), 0)
    }

    // ★ 作成した分と参加した分は排他的であるべき(同じグループが両方に二重カウントされない)
    func testOwnedAndJoinedCountsAreMutuallyExclusive() {
        let groups = [
            group(id: "1", isPrivate: true, createdByUid: "me"),
            group(id: "2", isPrivate: true, createdByUid: "friendA")
        ]
        let owned = GroupCounting.ownedPrivateChatCount(in: groups, myUid: "me")
        let joined = GroupCounting.joinedPrivateChatCount(in: groups, myUid: "me")
        XCTAssertEqual(owned, 1)
        XCTAssertEqual(joined, 1)
        XCTAssertEqual(owned + joined, groups.count)
    }
}
