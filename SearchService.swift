//
//  SearchService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import Foundation

final class SearchService {

    static let shared = SearchService()

    private init() {}

    // あなたの検索エンジンID（cx）
    private let cx = "e2a18386cc6a04ac1"

    // Google Custom Search APIキー
    private let apiKey = Secrets.googleSearchAPIKey

    /// Google検索 → スニペット抽出
    func search(query: String, completion: @escaping (Result<[String], Error>) -> Void) {

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        let urlString =
            "https://www.googleapis.com/customsearch/v1?q=\(encoded)&key=\(apiKey)&cx=\(cx)"

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "SearchService", code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "URL生成エラー"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in

            if let error = error {
                print("DEBUG Search error:", error)
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "SearchService", code: -2,
                                            userInfo: [NSLocalizedDescriptionKey: "データなし"])))
                return
            }

            // 生レスポンスをログ出力
            if let raw = String(data: data, encoding: .utf8) {
                print("DEBUG Search raw response:", raw)
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                // エラー返却チェック
                if let errorInfo = json?["error"] as? [String: Any] {
                    let message = errorInfo["message"] as? String ?? "不明なエラー"
                    print("DEBUG Search API error:", message)
                    completion(.failure(NSError(domain: "SearchService", code: -3,
                                                userInfo: [NSLocalizedDescriptionKey: message])))
                    return
                }

                // items → スニペット抽出
                let items = json?["items"] as? [[String: Any]] ?? []
                let snippets = items.compactMap { $0["snippet"] as? String }

                print("DEBUG Search snippets:", snippets)

                completion(.success(snippets))

            } catch {
                print("DEBUG JSON decode error:", error)
                completion(.failure(error))
            }

        }.resume()
    }
}
