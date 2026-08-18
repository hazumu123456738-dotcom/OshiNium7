//
//  SearchGroundingService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import Foundation

final class SearchGroundingService {

    static let shared = SearchGroundingService()
    private init() {}

    private let apiKey: String? = Secrets.geminiAPIKey

    // ★ 直前のリクエストを保持してキャンセルできるようにする
    private var currentTask: URLSessionDataTask?

    // ★ 2026/08/17（/moneyスキル監査）追加：呼び出し側(AIAddEventView/AICalendarAutoFillView)が
    //   同じグループ・同じクエリでボタンを連打したり、画面を行き来して再度同じ検索を
    //   実行した場合に、内容が変わらないのに毎回Gemini APIを課金呼び出ししていた。
    //   見つかった結果（空配列"[]"は除く。空配列は「本当に無かった」のか「モデルが今回
    //   たまたま見つけられなかった」のか区別が付かずキャッシュすると誤って固定してしまうため）
    //   だけを短時間キャッシュし、同一条件の再検索をAPIを叩かずに即返す
    private struct CacheEntry {
        let result: String
        let timestamp: Date
    }
    private var resultCache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 300

    private static func cacheKey(query: String, groupName: String, groupId: String) -> String {
        "\(groupId)|\(groupName)|\(query.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    func searchEvents(
        query: String,
        groupName: String,
        groupId: String,
        retry: Int = 2,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // ★ /ult監査で発見：ユーザー入力(query)がそのままプロンプトへ無制限に埋め込まれており、
        //   長大な入力によるプロンプトインジェクション・トークン浪費への防御が無かった。
        //   出力はJSON整形+groupId一致フィルタで後段検証されるため実害は限定的だが、
        //   念のため長さの上限だけ設ける
        let query = String(query.prefix(200))

        let key = Self.cacheKey(query: query, groupName: groupName, groupId: groupId)
        if let cached = resultCache[key], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            completion(.success(cached.result))
            return
        }

        guard let apiKey else {
            completion(.failure(NSError(
                domain: "SearchGrounding",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "APIキーが設定されていません"]
            )))
            return
        }

        // ★ 検索結果の解釈＋厳密なJSON整形を1回の呼び出しで両方求めるタスクのため、
        //   flash-liteでは精度が不安定だった。flashに上げて様子を見る
        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=\(apiKey)"
        ) else {
            completion(.failure(NSError(
                domain: "SearchGrounding",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "リクエストURLの生成に失敗しました"]
            )))
            return
        }

        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)

        // ★ 「絶対に [] だけで終わらせない」プロンプト
        let prompt = """
        あなたは「\(groupName)」のイベント情報のみを抽出するアシスタントです。

        ユーザー入力: \(query)
        今日の日付: \(todayString)

        【最重要ルール（誤爆防止）】
        1. 「\(groupName)」に関連するイベント・出演情報のみ返す。
        2. 関係ないイベント（TGCなど）は絶対に返さない。
        3. groupId は必ず指定された「\(groupId)」をそのまま返す。
        4. 関係ないイベントに groupId を付与して返してはいけない。

        【国別ルール（世界対応）】
        5. 日本でのイベントが検索結果に存在しない場合、
           世界中のどの国のイベントでも返してよい。
        6. 韓国、アメリカ、ヨーロッパなど、国は問わない。
        7. ただし必ず「\(groupName)」本人が出演するイベントに限る。

        【検索結果の扱い】
        8. Grounding（googleSearch）に「\(groupName)」が含まれない場合でも、
           世界の公式情報があれば返してよい。
        9. 関係ないイベント（TGCなど）は無視する。

        【日付ルール】
        - 未来の日付のみ返す。
        - 過去の日付は返さない。
        - 日付が不明な場合は "" を返す。

        【URLルール】
        - URL は Grounding で取得できた安全なもののみ。
        - 推測でURLを作らない。
        - リダイレクトURL（vertexaisearch.cloud.google.com/...）は返さない。
        - 危険なURLは返さない。
        - 不明なら "" を返す。

        【出力形式】
        JSON 配列のみ返す：

        {
          "groupId": "\(groupId)",
          "title": "イベント名",
          "date": "YYYY-MM-DD（未来のみ）",
          "type": "",
          "subType": "",
          "place": "",
          "source": "",
          "url": ""
        }

        【禁止事項】
        - 上記以外のキーを含めない。
        - JSON 以外のテキストを出力しない。
        - 関係ないイベントを返すくらいなら必ず [] を返す。

        """

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "tools": [
                [
                    "googleSearch": [:]
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(NSError(
                domain: "SearchGrounding", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "リクエストの作成に失敗しました"]
            )))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        // ★ ここで前回のリクエストをキャンセル
        currentTask?.cancel()
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in

            // キャンセルされたタスクなら何もしない
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            if let error = error {
                if retry > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.searchEvents(
                            query: query,
                            groupName: groupName,
                            groupId: groupId,
                            retry: retry - 1,
                            completion: completion
                        )
                    }
                    return
                }
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(NSError(
                    domain: "SearchGrounding",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "データなし"]
                )))
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.success("[]"))
                return
            }

            // ★ 以前はraw.contains("\"error\"")という文字列ベースの判定で、検索結果の
            //   スニペット等に「エラー」の英語表記がたまたま含まれるだけの正常な応答まで
            //   誤ってAPIエラー扱いにしていた。トップレベルの"error"キーの有無で判定する
            if json["error"] != nil {
                completion(.failure(NSError(
                    domain: "SearchGrounding",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Gemini API エラー応答"]
                )))
                return
            }

            guard
                let candidates = json["candidates"] as? [[String: Any]],
                let content = candidates.first?["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let text = parts.first?["text"] as? String
            else {
                completion(.success("[]"))
                return
            }

            let cleaned = Self.extractJSONArray(from: text)

            // ★ 空配列"[]"はキャッシュしない（呼び出し側のリトライが「今回は本当に無かった」
            //   のか判断し直すための再検索であり、キャッシュすると常に同じ空結果を
            //   返すだけになってリトライの意味が無くなる）
            if cleaned != "[]" {
                self?.resultCache[key] = CacheEntry(result: cleaned, timestamp: Date())
            }
            completion(.success(cleaned))

        }

        // ★ 今回のタスクを保持してから実行
        currentTask = task
        task.resume()
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
