//
//  GroupInfoSearchService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

struct GroupInfoResult {
    var reading: String?
    var fandom: String?
    var concept: String?
    var history: String?
    var groupDescription: String?
}

// ★ 推し活の自動化の一環：新規グループ作成時に、AI(Gemini + Google検索)が
//   グループの基本情報を自動で調べて詳細カードを埋める。SearchGroundingService.swift と
//   同じ Gemini エンドポイント・APIキー・JSON抽出方式を踏襲している。
final class GroupInfoSearchService {

    static let shared = GroupInfoSearchService()
    private init() {}

    private let apiKey: String? = Secrets.geminiAPIKey

    // ★ 個別項目のAI再調査（「修正」用）。全項目を調べ直すsearchGroupInfoと違い、
    //   ユーザーが手動で直した他の項目を巻き込まずに、指定した1項目だけをAIに調べ直させる。
    func refineField(groupName: String, fieldLabel: String, currentValue: String) async -> String? {
        guard let apiKey else {
            print("⚠️ GroupInfoSearchService: APIキーが設定されていません")
            return nil
        }

        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)"
        ) else { return nil }

        let prompt = """
        あなたは推し活コミュニティアプリのアシスタントです。
        「\(groupName)」というアイドルグループ・アーティスト・Vtuberなどについて、
        検索結果をもとに次の1項目だけを確認し、正しい内容を日本語で返してください。

        項目名: \(fieldLabel)
        現在入力されている内容: "\(currentValue.isEmpty ? "（空欄）" : currentValue)"

        【ルール】
        - 検索結果で裏付けが取れた最新・正確な内容のみを返す
        - 現在の内容がすでに正しければそのまま返してよい。間違っていれば訂正する
        - 裏付けが取れない場合は絶対に憶測で書かず、空文字だけを返す
        - 出力は項目の中身のテキストのみ。前置き・説明・記号・引用符・改行は一切つけない
        """

        guard let text = await requestGemini(url: url, prompt: prompt) else { return nil }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"「」"))
        return cleaned.isEmpty ? nil : cleaned
    }

    func searchGroupInfo(groupName: String) async -> GroupInfoResult? {
        guard let apiKey else {
            print("⚠️ GroupInfoSearchService: APIキーが設定されていません")
            return nil
        }

        guard let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=\(apiKey)"
        ) else { return nil }

        let prompt = """
        あなたは推し活コミュニティアプリのアシスタントです。
        「\(groupName)」というアイドルグループ・アーティスト・Vtuberなどについて、
        検索結果をもとに以下の情報を日本語で簡潔にまとめてください。

        【出力形式】
        JSONオブジェクトのみを返してください。他の説明文やコードブロック記法は一切含めないでください。
        {
          "reading": "読み方（カタカナ。不明なら空文字）",
          "fandom": "ファンダム名・ファンの呼称（不明なら空文字）",
          "concept": "コンセプトや世界観（2〜3文。不明なら空文字）",
          "history": "デビュー年や結成の経緯など簡単な歴史（2〜3文。不明なら空文字）",
          "groupDescription": "グループの簡単な紹介文（2〜3文。不明なら空文字）"
        }

        【ルール】
        - 検索結果で裏付けが取れた情報のみを書く。裏付けが取れない項目は必ず空文字("")にする
        - 存在するかどうか確信が持てない場合は、絶対に創作・憶測で埋めない。空文字の方が間違った情報より良い
        - 特に fandom（ファンダム名）は、公式または広く知られた固有の呼称が見つからない限り空文字にする。それらしい名前を推測で作らない
        - JSON以外のテキストは絶対に出力しない
        """

        guard let text = await requestGemini(url: url, prompt: prompt) else { return nil }

        let cleaned = Self.extractJSONObject(from: text)
        guard let objData = cleaned.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: objData) as? [String: Any] else {
            print("⚠️ GroupInfoSearchService: JSON抽出に失敗 raw text:", text)
            return nil
        }

        // ★ モデルが「不明なら空文字」の指示を守らず null や数値等を返すことがあるため、
        //   辞書全体を [String: String] に一括キャストせず、キーごとに安全に文字列化する。
        //   （一括キャストだと1フィールドでも型違反があるだけで全項目が消えてしまっていた）
        func nonEmpty(_ key: String) -> String? {
            guard let s = raw[key] as? String, !s.isEmpty else { return nil }
            return s
        }

        return GroupInfoResult(
            reading: nonEmpty("reading"),
            fandom: nonEmpty("fandom"),
            concept: nonEmpty("concept"),
            history: nonEmpty("history"),
            groupDescription: nonEmpty("groupDescription")
        )
    }

    // MARK: - Gemini呼び出し共通処理

    private func requestGemini(url: URL, prompt: String) async -> String? {
        let body: [String: Any] = [
            "contents": [
                ["role": "user", "parts": [["text": prompt]]]
            ],
            "tools": [
                ["googleSearch": [:]]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = json["candidates"] as? [[String: Any]],
                let content = candidates.first?["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let text = parts.first?["text"] as? String
            else {
                print("⚠️ GroupInfoSearchService: 応答の解析に失敗")
                return nil
            }

            return text
        } catch {
            print("🔥 GroupInfoSearchService error:", error)
            return nil
        }
    }

    private static func extractJSONObject(from text: String) -> String {
        let t = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = t.firstIndex(of: "{") {
            var depth = 0
            for i in t.indices[start...] {
                if t[i] == "{" { depth += 1 }
                if t[i] == "}" { depth -= 1 }
                if depth == 0 {
                    return String(t[start...i])
                }
            }
        }
        return "{}"
    }
}
