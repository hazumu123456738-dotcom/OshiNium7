//
//  AIEventResult.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import Foundation
import UIKit

// MARK: - AIEventResult（完全版）
struct AIEventResult: Codable, Identifiable {

    let id = UUID()

    var groupId: String?

    var title: String
    var dateString: String
    var location: String?

    var openTime: String?
    var startTime: String?
    var endTime: String?

    var access: String?
    var organizer: String?
    var contact: String?

    var officialURL: String?
    var thumbnailURL: String?

    // ★ tags は nil にしない（inferType が確実に読めるようにする）
    var tags: [String]

    var ticketPrice: String?
    var ticketStartDate: String?

    enum CodingKeys: String, CodingKey {
        case groupId
        case title
        case dateString = "date"
        case location = "place"

        case openTime
        case startTime
        case endTime

        case access
        case organizer
        case contact

        case officialURL = "url"
        case thumbnailURL

        case tags = "type"
        case ticketPrice
        case ticketStartDate
    }
}

// MARK: - RawEvent（Grounding の生データ）
extension AIEventResult {

    struct RawEvent: Codable {
        let groupId: String?
        let title: String?
        let date: String?
        let type: String?
        let subType: String?
        let place: String?
        let source: String?
        let url: String?
    }

    // MARK: - JSON → [AIEventResult]
    static func list(from jsonString: String) -> [AIEventResult]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
            let decoder = JSONDecoder()
            let rawList = try decoder.decode([RawEvent].self, from: data)

            var mapped = rawList.map { raw -> AIEventResult in

                // ★ type + subType → tags（nil を絶対に作らない）
                var tagList: [String] = []

                if let t = raw.type?.lowercased(), !t.isEmpty {
                    tagList.append(t)
                }
                if let s = raw.subType?.lowercased(), !s.isEmpty {
                    tagList.append(s)
                }

                // ★ tags が空でも [] にする（nil にしない）
                let safeTags = tagList

                return AIEventResult(
                    groupId: raw.groupId,
                    title: raw.title ?? "",
                    dateString: raw.date ?? "",
                    location: raw.place,

                    openTime: nil,
                    startTime: nil,
                    endTime: nil,

                    access: nil,
                    organizer: nil,
                    contact: nil,

                    officialURL: raw.url,
                    thumbnailURL: nil,

                    tags: safeTags,   // ← ★ ここが最重要

                    ticketPrice: nil,
                    ticketStartDate: nil
                )
            }

            // MARK: - URL 正規化 & 実在チェック & TLSチェック（元コード完全維持）
            mapped = mapped.map { item in
                var newItem = item

                if let urlStr = item.officialURL {

                    let cleaned = urlStr
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: " ", with: "")

                    guard let url = URL(string: cleaned) else {
                        newItem.officialURL = ""
                        return newItem
                    }

                    guard UIApplication.shared.canOpenURL(url) else {
                        newItem.officialURL = ""
                        return newItem
                    }

                    let semaphore = DispatchSemaphore(value: 0)
                    var isSafe = false

                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5

                    URLSession.shared.dataTask(with: request) { _, response, error in
                        if let err = error as NSError? {
                            if err.code == NSURLErrorSecureConnectionFailed {
                                isSafe = false
                                semaphore.signal()
                                return
                            }
                        }

                        if let http = response as? HTTPURLResponse,
                           (200...399).contains(http.statusCode) {
                            isSafe = true
                        }

                        semaphore.signal()
                    }.resume()

                    semaphore.wait()

                    newItem.officialURL = isSafe ? cleaned : ""
                }

                return newItem
            }

            return mapped

        } catch {
            print("DEBUG decode error:", error)
            return nil
        }
    }

    static func from(jsonString: String) -> AIEventResult? {
        return list(from: jsonString)?.first
    }
}

// MARK: - 日付正規化（元コード完全維持）
extension AIEventResult {

    func parsedDates(defaultYear: Int) -> [Date] {

        var raw = dateString

        raw = raw.replacingOccurrences(
            of: #"\(.+?\)"#,
            with: "",
            options: .regularExpression
        )

        raw = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw

        raw = raw
            .replacingOccurrences(of: ".", with: "/")
            .replacingOccurrences(of: "-", with: "/")
            .replacingOccurrences(of: " ", with: "")

        if raw.contains("〜") {
            let parts = raw.split(separator: "〜").map { String($0) }
            if parts.count == 2 {
                return expandRange(start: parts[0], end: parts[1], year: defaultYear)
            }
        }

        if let d = parseSingleDate(raw, year: defaultYear) {
            return [d]
        }

        return []
    }

    private func parseSingleDate(_ str: String, year: Int) -> Date? {
        var s = str

        if s.filter({ $0 == "/" }).count == 1 {
            s = "\(year)/" + s
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"

        return formatter.date(from: s)
    }

    private func expandRange(start: String, end: String, year: Int) -> [Date] {
        guard let startDate = parseSingleDate(start, year: year),
              let endDate = parseSingleDate(end, year: year) else {
            return []
        }

        var dates: [Date] = []
        var current = startDate
        let cal = Calendar.current

        // ★ startとendはAIが生成した文字列から解析した値のため、万一日付が
        //   逆転・大きくズレて解釈された場合に無限に近いループでメモリを食い潰さないよう、
        //   現実的なイベント期間の上限（1年）でガードする
        while current <= endDate && dates.count < 366 {
            dates.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }
}
