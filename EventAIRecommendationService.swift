//
//  EventAIRecommendationService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation

// ★ イベント当日ハブの「AIおすすめ」カード用。天気・会場・チケット・グッズ・お知らせなど、
//   画面の各カードに表示している実データだけをプロンプトに渡し、それをもとにした
//   混雑予測・おすすめの動き方・注意事項を生成する。SearchGroundingServiceと同じGemini構成だが、
//   googleSearchでの裏取りを必須にし、不確かな内容は断定しないよう指示することで、
//   カードに表示する情報の精度をできるだけ担保する
struct EventAITips: Codable, Equatable {
    var congestion: String
    var route: String
    var precautions: String
}

final class EventAIRecommendationService {

    static let shared = EventAIRecommendationService()
    private init() {}

    private let apiKey: String? = Secrets.geminiAPIKey
    private var currentTask: URLSessionDataTask?

    func generateTips(eventInfo: String, completion: @escaping (Result<EventAITips, Error>) -> Void) {
        guard let apiKey else {
            completion(.failure(NSError(
                domain: "EventAIRecommendation", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "APIキーが設定されていません"]
            )))
            return
        }

        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)"
        ) else {
            completion(.failure(NSError(
                domain: "EventAIRecommendation", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "リクエストURLの生成に失敗しました"]
            )))
            return
        }

        let prompt = """
        あなたは、ファンがイベント当日を安心して過ごせるように手助けする「当日ガイド」アシスタントです。
        以下は、このイベントについて実際にアプリ内で確認できている情報です。この情報と、必要であれば検索で
        確認できる公開情報だけを根拠にして、現実的でファンの役に立つアドバイスを作成してください。

        【最重要ルール】
        - 誇張や虚偽、根拠のない断定は書かないこと。
        - 確認できていないことを、確認できたかのように書かないこと。
        - 検索でも確認できない場合は、「一般的に」「同規模の会場では」など、推測であることが伝わる表現にすること。
        - 出力は日本語、各項目60字前後で簡潔にすること。絵文字は使わないこと。

        【アプリ内で確認できている情報】
        \(eventInfo)

        【出力形式】
        説明文やコードブロック記号を付けず、次のJSON形式のみを出力してください。
        {
          "congestion": "混雑予測",
          "route": "おすすめの動き方・ルート",
          "precautions": "当日の注意事項"
        }
        """

        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]]
            ],
            "tools": [
                ["googleSearch": [:]]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(NSError(
                domain: "EventAIRecommendation", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "リクエストの作成に失敗しました"]
            )))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        currentTask?.cancel()
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error as NSError?, error.code == NSURLErrorCancelled { return }

            if let error {
                completion(.failure(error))
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String
            else {
                completion(.failure(NSError(
                    domain: "EventAIRecommendation", code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "AIからの応答を取得できませんでした"]
                )))
                return
            }

            guard let objectText = Self.extractJSONObject(from: text),
                  let objectData = objectText.data(using: .utf8),
                  let tips = try? JSONDecoder().decode(EventAITips.self, from: objectData)
            else {
                completion(.failure(NSError(
                    domain: "EventAIRecommendation", code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "AIの応答を解析できませんでした"]
                )))
                return
            }

            completion(.success(tips))
        }

        currentTask = task
        task.resume()
    }

    private static func extractJSONObject(from text: String) -> String? {
        let t = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = t.firstIndex(of: "{") else { return nil }
        var depth = 0
        for i in t.indices[start...] {
            if t[i] == "{" { depth += 1 }
            if t[i] == "}" { depth -= 1 }
            if depth == 0 {
                return String(t[start...i])
            }
        }
        return nil
    }
}
