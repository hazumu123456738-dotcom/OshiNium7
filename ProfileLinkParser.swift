//
//  ProfileLinkParser.swift
//  OshiNium7
//

import Foundation

// ★ プロフィール共有リンクのuid抽出を1箇所に集約する。
//   新形式のUniversal Link(https://oshinium-79256.web.app/u/<uid>)と、
//   互換のため引き続き受け付ける旧カスタムスキーム(oshinium://profile?uid=<uid>)の
//   両方を、ShareProfileView(QRスキャン)とAppRootView(リンクタップ)の両方から同じロジックで扱う
enum ProfileLinkParser {
    static func uid(from value: String) -> String? {
        guard let url = URL(string: value) else { return nil }

        if url.scheme == "https" || url.scheme == "http" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let uIndex = pathComponents.firstIndex(of: "u"),
               pathComponents.indices.contains(uIndex + 1) {
                let uid = pathComponents[uIndex + 1]
                return uid.isEmpty ? nil : uid
            }
            return nil
        }

        if url.scheme == "oshinium", url.host == "profile",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let uid = components.queryItems?.first(where: { $0.name == "uid" })?.value,
           !uid.isEmpty {
            return uid
        }

        return nil
    }
}
