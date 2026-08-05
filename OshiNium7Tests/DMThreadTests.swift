//
//  DMThreadTests.swift
//  OshiNium7Tests
//

import XCTest
@testable import OshiNium7

final class DMThreadTests: XCTestCase {

    func testThreadIdIsOrderIndependent() {
        let idAB = DMThread.threadId("uidA", "uidB")
        let idBA = DMThread.threadId("uidB", "uidA")
        XCTAssertEqual(idAB, idBA, "同じ2人の間なら、渡す順番が逆でも同じスレッドIDになるべき")
    }

    func testThreadIdFormat() {
        XCTAssertEqual(DMThread.threadId("bbb", "aaa"), "aaa_bbb")
    }

    func testThreadIdIsDeterministicAcrossCalls() {
        let first = DMThread.threadId("user1", "user2")
        let second = DMThread.threadId("user1", "user2")
        XCTAssertEqual(first, second)
    }

    func testOtherUidReturnsTheRemainingParticipant() {
        let thread = DMThread(
            id: DMThread.threadId("me", "them"),
            participants: ["me", "them"],
            lastMessage: "hello",
            lastMessageAt: Date(),
            lastSenderUid: "me"
        )
        XCTAssertEqual(thread.otherUid(myUid: "me"), "them")
        XCTAssertEqual(thread.otherUid(myUid: "them"), "me")
    }

    // ★ otherUid(myUid:)は「自分以外の参加者」を返すだけで、myUidが実際に
    //   参加者に含まれているかは検証しない（呼び出し側は必ず自分が参加者である
    //   スレッドに対してのみ呼ぶ、という前提の軽量な実装）。
    //   そのため、参加者に無いuidを渡すと「自分以外」の条件に一致した最初の参加者を返す
    func testOtherUidWithUnrelatedUidReturnsFirstNonMatchingParticipant() {
        let thread = DMThread(
            id: DMThread.threadId("me", "them"),
            participants: ["me", "them"],
            lastMessage: "hello",
            lastMessageAt: Date(),
            lastSenderUid: "me"
        )
        XCTAssertEqual(thread.otherUid(myUid: "someoneElse"), "me")
    }

    func testOtherUidReturnsNilWhenNoParticipants() {
        let thread = DMThread(
            id: "empty",
            participants: [],
            lastMessage: "",
            lastMessageAt: Date(),
            lastSenderUid: nil
        )
        XCTAssertNil(thread.otherUid(myUid: "me"))
    }
}
