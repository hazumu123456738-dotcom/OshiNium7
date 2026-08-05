//
//  DirectMessagePolicyTests.swift
//  OshiNium7Tests
//

import XCTest
@testable import OshiNium7

final class DirectMessagePolicyTests: XCTestCase {

    private func message(id: String, senderUid: String, secondsAgo: TimeInterval = 0) -> Message {
        Message(
            id: id,
            senderUid: senderUid,
            senderName: "test",
            text: "hello",
            createdAt: Date().addingTimeInterval(-secondsAgo)
        )
    }

    // MARK: - isRequestLimited

    func testMutualFollowIsNeverLimited() {
        let messages = [message(id: "1", senderUid: "me"), message(id: "2", senderUid: "me")]
        XCTAssertFalse(
            DirectMessagePolicy.isRequestLimited(messages: messages, currentUid: "me", otherUid: "them", isMutual: true)
        )
    }

    func testNotMutualWithNoMessagesYetIsNotLimited() {
        XCTAssertFalse(
            DirectMessagePolicy.isRequestLimited(messages: [], currentUid: "me", otherUid: "them", isMutual: false)
        )
    }

    func testNotMutualAfterOneMessageSentIsLimited() {
        let messages = [message(id: "1", senderUid: "me")]
        XCTAssertTrue(
            DirectMessagePolicy.isRequestLimited(messages: messages, currentUid: "me", otherUid: "them", isMutual: false)
        )
    }

    func testNotMutualButOtherHasRepliedIsNotLimited() {
        let messages = [
            message(id: "1", senderUid: "me", secondsAgo: 60),
            message(id: "2", senderUid: "them", secondsAgo: 30)
        ]
        XCTAssertFalse(
            DirectMessagePolicy.isRequestLimited(messages: messages, currentUid: "me", otherUid: "them", isMutual: false)
        )
    }

    // MARK: - isLastMineSeen

    func testLastMineSeenWhenOtherReadAfterSend() {
        let msg = message(id: "last", senderUid: "me", secondsAgo: 60)
        let readAt = Date() // 今読んだ = 送信より後
        XCTAssertTrue(
            DirectMessagePolicy.isLastMineSeen(message: msg, lastMessageId: "last", currentUid: "me", otherReadAt: readAt)
        )
    }

    func testNotSeenWhenOtherReadBeforeSend() {
        let msg = message(id: "last", senderUid: "me", secondsAgo: 0)
        let readAt = Date().addingTimeInterval(-60) // 送信より前に読んだ扱い
        XCTAssertFalse(
            DirectMessagePolicy.isLastMineSeen(message: msg, lastMessageId: "last", currentUid: "me", otherReadAt: readAt)
        )
    }

    func testNotSeenWhenMessageIsNotTheLastOne() {
        let msg = message(id: "notLast", senderUid: "me", secondsAgo: 60)
        XCTAssertFalse(
            DirectMessagePolicy.isLastMineSeen(message: msg, lastMessageId: "last", currentUid: "me", otherReadAt: Date())
        )
    }

    func testNotSeenWhenMessageIsNotMine() {
        let msg = message(id: "last", senderUid: "them", secondsAgo: 60)
        XCTAssertFalse(
            DirectMessagePolicy.isLastMineSeen(message: msg, lastMessageId: "last", currentUid: "me", otherReadAt: Date())
        )
    }

    func testNotSeenWhenOtherReadAtIsNil() {
        let msg = message(id: "last", senderUid: "me", secondsAgo: 60)
        XCTAssertFalse(
            DirectMessagePolicy.isLastMineSeen(message: msg, lastMessageId: "last", currentUid: "me", otherReadAt: nil)
        )
    }
}
