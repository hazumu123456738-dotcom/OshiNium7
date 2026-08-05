//
//  HashtagParserTests.swift
//  OshiNium7Tests
//

import XCTest
@testable import OshiNium7

final class HashtagParserTests: XCTestCase {

    func testExtractsSingleHashtag() {
        XCTAssertEqual(HashtagParser.extractHashtags(from: "今日は最高でした #ライブ"), ["#ライブ"])
    }

    func testExtractsMultipleHashtagsInOrder() {
        XCTAssertEqual(
            HashtagParser.extractHashtags(from: "#グッズ 買った #ペンライト も光った"),
            ["#グッズ", "#ペンライト"]
        )
    }

    func testExtractsNothingWhenNoHashtag() {
        XCTAssertEqual(HashtagParser.extractHashtags(from: "ハッシュタグが無い文章です"), [])
    }

    func testHashtagStopsAtWhitespace() {
        XCTAssertEqual(HashtagParser.extractHashtags(from: "#夏フェス 楽しかった"), ["#夏フェス"])
    }

    func testConsecutiveHashtagsAreSeparated() {
        // "#" 同士は区切りとして扱われ、1つの巨大なタグとして連結されない
        XCTAssertEqual(HashtagParser.extractHashtags(from: "#グッズ#ペンライト"), ["#グッズ", "#ペンライト"])
    }

    func testDuplicateHashtagsAreKept() {
        XCTAssertEqual(HashtagParser.extractHashtags(from: "#推し 最高 #推し"), ["#推し", "#推し"])
    }

    func testEmptyStringReturnsEmptyArray() {
        XCTAssertEqual(HashtagParser.extractHashtags(from: ""), [])
    }
}
