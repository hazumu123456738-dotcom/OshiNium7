//
//  ContentLinkParser.swift
//  OshiNium7
//

import Foundation

// ★ 投稿・予定の共有リンクのID抽出を1箇所に集約する。ProfileLinkParserと同じ考え方で、
//   新形式のUniversal Link(https://oshinium-79256.web.app/p/<postId> や /e/<eventId>)と、
//   互換のためのカスタムスキーム(oshinium://post?id=<postId> / oshinium://event?id=<eventId>)の
//   両方を同じロジックで扱う
enum ContentLinkParser {
    static func postId(from value: String) -> String? {
        extractId(from: value, pathKey: "p", customSchemeHost: "post")
    }

    static func eventId(from value: String) -> String? {
        extractId(from: value, pathKey: "e", customSchemeHost: "event")
    }

    private static func extractId(from value: String, pathKey: String, customSchemeHost: String) -> String? {
        guard let url = URL(string: value) else { return nil }

        if url.scheme == "https" || url.scheme == "http" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let keyIndex = pathComponents.firstIndex(of: pathKey),
               pathComponents.indices.contains(keyIndex + 1) {
                let id = pathComponents[keyIndex + 1]
                return id.isEmpty ? nil : id
            }
            return nil
        }

        if url.scheme == "oshinium", url.host == customSchemeHost,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
           !id.isEmpty {
            return id
        }

        return nil
    }
}
