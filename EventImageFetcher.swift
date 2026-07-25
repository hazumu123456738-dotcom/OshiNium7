//
//  EventImageFetcher.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/21.
//

import Foundation

enum EventImageFetcher {

    static func fetchImageURL(from urlString: String, completion: @escaping (URL?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        // 1回目：普通に取得
        fetchHTML(url: url) { html in
            if let html = html {
                if let found = extractImageURL(from: html, baseURL: url, originalURL: urlString) {
                    completion(found)
                    return
                }
            }

            // 2回目：JavaScript対策で ?amp=1 を付けて再取得（AMP版は画像が埋め込まれていることが多い）
            let ampURL = URL(string: urlString + (urlString.contains("?") ? "&amp=1" : "?amp=1"))
            if let ampURL = ampURL {
                fetchHTML(url: ampURL) { ampHTML in
                    if let ampHTML = ampHTML {
                        if let found = extractImageURL(from: ampHTML, baseURL: ampURL, originalURL: urlString) {
                            completion(found)
                            return
                        }
                    }
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - HTML取得（User-Agent付き）
    private static func fetchHTML(url: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard
                error == nil,
                let data = data,
                let html = String(data: data, encoding: .utf8)
            else {
                completion(nil)
                return
            }
            completion(html)
        }.resume()
    }

    // MARK: - 画像抽出ロジック（強化版）
    private static func extractImageURL(from html: String, baseURL: URL, originalURL: String) -> URL? {

        // ① og:image
        if let og = extractMetaContent(from: html, property: "og:image"),
           let url = URL(string: og, relativeTo: baseURL) {
            return url
        }

        // ② twitter:image
        if let tw = extractMetaContent(from: html, name: "twitter:image"),
           let url = URL(string: tw, relativeTo: baseURL) {
            return url
        }

        // ③ SNS fallback（twitter.com / x.com）
        if originalURL.contains("twitter.com") || originalURL.contains("x.com") {
            if let tw = extractMetaContent(from: html, name: "twitter:image"),
               let url = URL(string: tw) {
                return url
            }
        }

        // ④ ページ内最大画像（imgタグ）
        if let img = extractLargestImage(from: html, baseURL: baseURL) {
            return img
        }

        return nil
    }

    private static func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "<meta[^>]*property=[\"']\(property)[\"'][^>]*content=[\"']([^\"']+)[\"'][^>]*>"
        return firstMatch(in: html, pattern: pattern)
    }

    private static func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta[^>]*name=[\"']\(name)[\"'][^>]*content=[\"']([^\"']+)[\"'][^>]*>"
        return firstMatch(in: html, pattern: pattern)
    }

    private static func extractLargestImage(from html: String, baseURL: URL) -> URL? {
        let pattern = "<img[^>]*src=[\"']([^\"']+)[\"'][^>]*>"
        if let src = firstMatch(in: html, pattern: pattern) {
            return URL(string: src, relativeTo: baseURL)
        }
        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               match.numberOfRanges >= 2,
               let r = Range(match.range(at: 1), in: text) {
                return String(text[r])
            }
        } catch { return nil }
        return nil
    }
}
