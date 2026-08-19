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

    // ★ 匿名ログインは無課金より厳しく1グループまで。プレミアムでも匿名なら1のまま
    //   （匿名のままプレミアム購入はできない想定だが、念のため優先されることを明示しておく）
    func testGroupLimitAnonymous() {
        XCTAssertEqual(SubscriptionLimits.groupLimit(isPremium: false, isAnonymous: true), 1)
        XCTAssertEqual(SubscriptionLimits.groupLimit(isPremium: true, isAnonymous: true), 1)
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

    // ★ 2026/08/19追加：マスDM対策の新規スレッド上限。無料は1日20件、
    //   プレミアムは無制限(.max)であることを明示的にテストしておく
    func testDMNewThreadDailyLimit() {
        XCTAssertEqual(SubscriptionLimits.dmNewThreadDailyLimit(isPremium: false), 20)
        XCTAssertEqual(SubscriptionLimits.dmNewThreadDailyLimit(isPremium: true), .max)
    }
}
