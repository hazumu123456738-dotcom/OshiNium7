//
//  SubscriptionLimitsTests.swift
//  OshiNium7Tests
//

import XCTest
@testable import OshiNium7

final class SubscriptionLimitsTests: XCTestCase {

    func testGroupLimit() {
        XCTAssertEqual(SubscriptionLimits.groupLimit(isPremium: false), 2)
        XCTAssertEqual(SubscriptionLimits.groupLimit(isPremium: true), 5)
    }

    func testPackingTemplateLimit() {
        XCTAssertEqual(SubscriptionLimits.packingTemplateLimit(isPremium: false), 3)
        XCTAssertEqual(SubscriptionLimits.packingTemplateLimit(isPremium: true), 10)
    }

    func testCalendarCreateLimit() {
        XCTAssertEqual(SubscriptionLimits.calendarCreateLimit(isPremium: false), 1)
        XCTAssertEqual(SubscriptionLimits.calendarCreateLimit(isPremium: true), 5)
    }

    func testCalendarRecreateLimit() {
        XCTAssertEqual(SubscriptionLimits.calendarRecreateLimit(isPremium: false), 1)
        XCTAssertEqual(SubscriptionLimits.calendarRecreateLimit(isPremium: true), 5)
    }

    // ★ グループチャットの「作成」は無課金では0件(=プレミアム限定機能)である点が
    //   他の上限と違う特殊なケースなので、明示的にテストしておく
    func testPrivateChatCreateLimitIsPremiumOnly() {
        XCTAssertEqual(SubscriptionLimits.privateChatCreateLimit(isPremium: false), 0)
        XCTAssertEqual(SubscriptionLimits.privateChatCreateLimit(isPremium: true), 3)
    }

    func testPrivateChatJoinLimit() {
        XCTAssertEqual(SubscriptionLimits.privateChatJoinLimit(isPremium: false), 1)
        XCTAssertEqual(SubscriptionLimits.privateChatJoinLimit(isPremium: true), 3)
    }

    func testCalendarRecreateWindowDaysIsTenDays() {
        XCTAssertEqual(SubscriptionLimits.calendarRecreateWindowDays, 10)
    }
}
