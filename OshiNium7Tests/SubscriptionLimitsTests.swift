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

    // ★ 2026/08/19追加：マスDM対策の新規スレッド上限。無料は1日20件、
    //   プレミアムは無制限(.max)であることを明示的にテストしておく
    func testDMNewThreadDailyLimit() {
        XCTAssertEqual(SubscriptionLimits.dmNewThreadDailyLimit(isPremium: false), 20)
        XCTAssertEqual(SubscriptionLimits.dmNewThreadDailyLimit(isPremium: true), .max)
    }

    // ★ 2026/08/20追加：投稿1件あたりの画像・動画の枚数上限。運営コスト検討により、
    //   無料は5枚・プレミアムは従来通り10枚
    func testPostMediaLimit() {
        XCTAssertEqual(SubscriptionLimits.postMediaLimit(isPremium: false), 5)
        XCTAssertEqual(SubscriptionLimits.postMediaLimit(isPremium: true), 10)
    }

    // ★ 2026/08/20追加：動画投稿自体をプレミアム限定機能にした
    func testCanPostVideoIsPremiumOnly() {
        XCTAssertFalse(SubscriptionLimits.canPostVideo(isPremium: false))
        XCTAssertTrue(SubscriptionLimits.canPostVideo(isPremium: true))
    }
}
