//
//  CalendarRecreatePolicyTests.swift
//  OshiNium7Tests
//

import XCTest
@testable import OshiNium7

final class CalendarRecreatePolicyTests: XCTestCase {

    private let now = Date()

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
    }

    // MARK: - isRecreate

    func testNoDeleteHistoryIsNotRecreate() {
        XCTAssertFalse(CalendarRecreatePolicy.isRecreate(deleteTimestamps: []))
    }

    func testAnyDeleteHistoryIsRecreate() {
        XCTAssertTrue(CalendarRecreatePolicy.isRecreate(deleteTimestamps: [daysAgo(365)]))
    }

    // MARK: - recentRecreateCount

    func testRecentRecreateCountOnlyCountsWithinWindow() {
        let timestamps = [daysAgo(1), daysAgo(5), daysAgo(9), daysAgo(11), daysAgo(30)]
        let count = CalendarRecreatePolicy.recentRecreateCount(recreateTimestamps: timestamps, windowDays: 10, now: now)
        XCTAssertEqual(count, 3) // 1日前・5日前・9日前だけが10日以内
    }

    func testRecentRecreateCountWithNoHistoryIsZero() {
        XCTAssertEqual(CalendarRecreatePolicy.recentRecreateCount(recreateTimestamps: [], windowDays: 10, now: now), 0)
    }

    // MARK: - canCreate

    func testFirstEverCreationIsAlwaysAllowedRegardlessOfLimit() {
        // 削除履歴が無い(=純粋な新規作成)なら、limitが0でも許可される
        let canCreate = CalendarRecreatePolicy.canCreate(
            deleteTimestamps: [], recreateTimestamps: [], windowDays: 10, limit: 0, now: now
        )
        XCTAssertTrue(canCreate)
    }

    func testFreeUserCanRecreateOnceWithinWindow() {
        // 無課金(limit=1)：削除履歴はあるが、まだ一度も作り直していない → 許可
        let canCreate = CalendarRecreatePolicy.canCreate(
            deleteTimestamps: [daysAgo(1)], recreateTimestamps: [], windowDays: 10, limit: 1, now: now
        )
        XCTAssertTrue(canCreate)
    }

    func testFreeUserCannotRecreateTwiceWithinWindow() {
        // 無課金(limit=1)：既に1回作り直し済み → 2回目はブロック
        let canCreate = CalendarRecreatePolicy.canCreate(
            deleteTimestamps: [daysAgo(5)], recreateTimestamps: [daysAgo(3)], windowDays: 10, limit: 1, now: now
        )
        XCTAssertFalse(canCreate)
    }

    func testPremiumUserCanRecreateUpToFiveTimesWithinWindow() {
        // プレミアム(limit=5)：直近10日以内に4回作り直し済み → 5回目はまだ許可
        let recreates = [daysAgo(1), daysAgo(2), daysAgo(3), daysAgo(4)]
        let canCreate = CalendarRecreatePolicy.canCreate(
            deleteTimestamps: [daysAgo(9)], recreateTimestamps: recreates, windowDays: 10, limit: 5, now: now
        )
        XCTAssertTrue(canCreate)
    }

    func testPremiumUserBlockedAfterFiveRecreatesWithinWindow() {
        let recreates = [daysAgo(1), daysAgo(2), daysAgo(3), daysAgo(4), daysAgo(5)]
        let canCreate = CalendarRecreatePolicy.canCreate(
            deleteTimestamps: [daysAgo(9)], recreateTimestamps: recreates, windowDays: 10, limit: 5, now: now
        )
        XCTAssertFalse(canCreate)
    }

    // ★ ウィンドウ期間より前の古い"作り直し"は数えないので、たとえ過去に何度も
    //   作り直していても、直近windowDays日以内が空なら再び許可される
    func testOldRecreatesOutsideWindowDoNotCountTowardLimit() {
        let oldRecreates = [daysAgo(20), daysAgo(30), daysAgo(40)]
        let canCreate = CalendarRecreatePolicy.canCreate(
            deleteTimestamps: [daysAgo(50)], recreateTimestamps: oldRecreates, windowDays: 10, limit: 1, now: now
        )
        XCTAssertTrue(canCreate)
    }
}
