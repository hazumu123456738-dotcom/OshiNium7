//
//  URLEventExtractionService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import Foundation
import UIKit

// ★ 「AIがWeb全体を検索して予定を探す」(SearchGroundingService)とは違い、
//   ユーザー自身が指定した1本のURL(公式ツイート・イベントページ等)の中身だけを読み取って
//   イベント情報を抽出する。情報源をユーザーが自分で選んでいるため、AIは「探して当てる」のではなく
//   「書いてあることを読み取るだけ」になり、googleSearchツールを使う既存のAI予定検索より
//   安価かつ結果の裏取りがしやすい(ユーザー自身がそのURLを既に信頼して選んでいるため)。
enum URLEventExtractionService {

    enum ExtractionError: LocalizedError {
        case invalidURL
        case fetchFailed
        case emptyContent
        case apiKeyMissing
        case responseParseFailed
        case notRelatedToGroup(groupName: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URLの形式が正しくありません"
            case .fetchFailed: return "ページを読み込めませんでした。URLを確認してください"
            case .emptyContent: return "ページから文章を取得できませんでした"
            case .apiKeyMissing: return "APIキーが設定されていません"
            case .responseParseFailed: return "AIの応答を解析できませんでした"
            case .notRelatedToGroup(let groupName):
                return "このURLには「\(groupName)」に関連する情報が見つかりませんでした。グループに関係するURLを指定してください。"
            }
        }
    }

    // ★ トークン数（≒費用）を抑えるため、抽出したテキストはこの文字数までに切り詰める
    private static let maxContentLength = 6000
    private static let apiKey: String? = Secrets.geminiAPIKey

    static func extractEvent(from urlString: String, groupName: String, groupId: String) async throws -> AIEventResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, scheme.hasPrefix("http") else {
            throw ExtractionError.invalidURL
        }

        let pageText = try await fetchReadableText(from: url)
        guard !pageText.isEmpty else { throw ExtractionError.emptyContent }

        // ★ グループとは無関係なURLでもイベントを作れてしまう問題への対策。
        //   ページ本文にグループ名が一切含まれていない場合は、AIに投げる前の時点で弾く
        //   （余計なAPI呼び出しも節約できる）。全角半角・ひらがなカタカナのゆらぎは
        //   GroupViewModel.normalizeNameと同じ考え方で吸収する
        guard pageSeemsRelated(pageText: pageText, groupName: groupName) else {
            throw ExtractionError.notRelatedToGroup(groupName: groupName)
        }

        guard let apiKey else { throw ExtractionError.apiKeyMissing }
        guard let requestURL = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)"
        ) else { throw ExtractionError.apiKeyMissing }

        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        // ★ SearchGroundingServiceと同じJSON形式で出力させ、既存のAIEventResult.list(from:)を
        //   そのまま再利用できるようにする（検索なし・抽出のみなのでgoogleSearchツールは使わない）
        let prompt = """
        あなたは、与えられた文章から「\(groupName)」に関するイベント情報を1件だけ抽出するアシスタントです。

        今日の日付: \(todayString)
        グループID: \(groupId)

        【最重要ルール】
        - 以下の文章に実際に書かれている内容だけを使うこと。書かれていない情報を推測で埋めないこと。
        - 日付が具体的に書かれていない場合は date を "" にすること。
        - タイトルが分からない場合でも、文章の主題から自然なタイトルを付けてよい。
        - 出力は必ず1件のみ。複数のイベントが書かれていても、最も主要なものだけを返す。
        - 文章の内容が「\(groupName)」とは無関係だと判断した場合は、絶対に別のイベントを
          代わりに作らないこと。その場合は必ず空の配列 [] だけを返すこと。

        【文章】
        \(pageText)

        【出力形式】
        説明文やコードブロック記号を付けず、次のJSON配列(要素は1件のみ)の形式だけを出力してください。
        [
          {
            "groupId": "\(groupId)",
            "title": "イベント名",
            "date": "YYYY-MM-DD（不明なら空文字）",
            "type": "",
            "subType": "",
            "place": "",
            "source": "",
            "url": "\(trimmed)"
          }
        ]
        """

        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw ExtractionError.responseParseFailed
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else {
            throw ExtractionError.responseParseFailed
        }

        let cleaned = extractJSONArray(from: text)
        guard var result = AIEventResult.from(jsonString: cleaned) else {
            // ★ AI自身が「無関係」と判断してあえて空配列を返した場合と、
            //   単純な応答解析の失敗を区別し、前者はより分かりやすいメッセージにする
            if cleaned.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
                throw ExtractionError.notRelatedToGroup(groupName: groupName)
            }
            throw ExtractionError.responseParseFailed
        }

        // ★ officialURLはAIの応答任せにせず、ユーザーが指定した元のURLを必ずそのまま使う
        result.officialURL = trimmed
        return result
    }

    // MARK: - グループ関連性チェック

    private static func pageSeemsRelated(pageText: String, groupName: String) -> Bool {
        let normalizedGroup = normalize(groupName)
        guard !normalizedGroup.isEmpty else { return true }
        return normalize(pageText).contains(normalizedGroup)
    }

    // ★ GroupViewModel.normalizeNameと同じ考え方（全角→半角、カタカナ→ひらがな、記号除去）で
    //   表記ゆれを吸収する
    private static func normalize(_ text: String) -> String {
        var t = text.lowercased()
        t = t.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? t
        t = t.applyingTransform(.hiraganaToKatakana, reverse: true) ?? t
        t = t.replacingOccurrences(of: "[^a-zA-Z0-9ぁ-ん一-龥]", with: "", options: .regularExpression)
        return t
    }

    // MARK: - ページ取得＋HTML→プレーンテキスト変換

    private static func fetchReadableText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ExtractionError.fetchFailed
        }

        guard let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) else {
            throw ExtractionError.fetchFailed
        }

        let text = attributed.string
            .replacingOccurrences(of: #"\n{2,}"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(text.prefix(maxContentLength))
    }

    private static func extractJSONArray(from text: String) -> String {
        let t = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = t.firstIndex(of: "[") {
            var depth = 0
            for i in t.indices[start...] {
                if t[i] == "[" { depth += 1 }
                if t[i] == "]" { depth -= 1 }
                if depth == 0 {
                    return String(t[start...i])
                }
            }
        }
        return "[]"
    }
}
