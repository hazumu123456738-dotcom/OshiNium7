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

    // ★ 「GON」のように同じ名前で活動する人物・グループが複数存在するケースで、AIが
    //   別人の情報を混ぜて返してしまう問題への対策。グループ作成時に必須選択している
    //   category（例：VTuber／配信者・個人勢）と、任意の補足ヒントをプロンプトに含め、
    //   「その活動ジャンルに一致する人物・グループの情報だけ」に絞り込ませる
    private static func disambiguationBlock(category: GroupCategory?, activityHint: String?) -> String {
        var lines: [String] = []
        if let category {
            lines.append("このグループ・人物の活動ジャンル: \(category.rawValue)")
        }
        if let activityHint, !activityHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("補足の手がかり: \(activityHint)")
        }
        guard !lines.isEmpty else { return "" }
        return """

        \(lines.joined(separator: "\n"))

        【重要】同じ名前で活動する別人・別グループが存在する可能性があります。
        必ず上記の活動ジャンル・手がかりに一致する人物・グループの情報だけを使ってください。
        一致するか確信が持てない場合、その項目は書かず空文字にしてください。
        異なる人物・グループの情報を混ぜて書かないこと。
        """
    }

    // ★ 個別項目のAI再調査（「修正」用）。全項目を調べ直すsearchGroupInfoと違い、
    //   ユーザーが手動で直した他の項目を巻き込まずに、指定した1項目だけをAIに調べ直させる。
    func refineField(groupName: String, category: GroupCategory? = nil, fieldLabel: String, currentValue: String) async -> String? {
        guard let apiKey else {
            print("⚠️ GroupInfoSearchService: APIキーが設定されていません")
            return nil
        }

        guard let url = URL(string:
            // ★ 2026/08/16修正：flash-liteは実在しない架空のグループ名でも、検索結果の裏付けなしに
            //   詳細な経歴・実在の他アーティストとの関係まで自信満々に創作してしまう事例が
            //   実際に確認された（例：架空グループに実在のBTS/TWICEのボイストレーナーが
            //   関わったという虚偽の経歴を生成）。より精度の高いモデルに切り替える
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=\(apiKey)"
        ) else { return nil }

        let prompt = """
        あなたは推し活コミュニティアプリのアシスタントです。
        「\(groupName)」というアイドルグループ・アーティスト・Vtuberなどについて、
        検索結果をもとに次の1項目だけを確認し、正しい内容を日本語で返してください。
        \(Self.disambiguationBlock(category: category, activityHint: nil))

        項目名: \(fieldLabel)
        現在入力されている内容: "\(currentValue.isEmpty ? "（空欄）" : currentValue)"

        【ルール】
        - 検索結果で裏付けが取れた最新・正確な内容のみを返す
        - 現在の内容がすでに正しければそのまま返してよい。間違っていれば訂正する
        - 裏付けが取れない場合は絶対に憶測で書かず、空文字だけを返す
        - 検索してもこのグループ・人物が実在すると確認できない場合は、経歴やメンバー構成などを
          それらしく創作せず、必ず空文字を返す
        - 実在の他のアーティスト・人物・グループ（例：既存の有名アイドルグループ）との関わりは、
          検索結果で明確に裏付けられた場合以外は絶対に書かない。実在の第三者を無関係に
          結びつけて経歴を作らないこと
        - 出力は項目の中身のテキストのみ。前置き・説明・記号・引用符・改行は一切つけない
        """

        guard let text = await requestGemini(url: url, prompt: prompt) else { return nil }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"「」"))
        return cleaned.isEmpty ? nil : cleaned
    }

    func searchGroupInfo(groupName: String, category: GroupCategory? = nil, activityHint: String? = nil) async -> GroupInfoResult? {
        guard let apiKey else {
            print("⚠️ GroupInfoSearchService: APIキーが設定されていません")
            return nil
        }

        guard let url = URL(string:
            // ★ 2026/08/16修正：flash-liteは実在しない架空のグループ名でも、検索結果の裏付けなしに
            //   詳細な経歴・実在の他アーティストとの関係まで自信満々に創作してしまう事例が
            //   実際に確認された（例：架空グループに実在のBTS/TWICEのボイストレーナーが
            //   関わったという虚偽の経歴を生成）。より精度の高いモデルに切り替える
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=\(apiKey)"
        ) else { return nil }

        let prompt = """
        あなたは推し活コミュニティアプリのアシスタントです。
        「\(groupName)」というアイドルグループ・アーティスト・Vtuberなどについて、
        検索結果をもとに以下の情報を日本語で簡潔にまとめてください。
        \(Self.disambiguationBlock(category: category, activityHint: activityHint))

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
        - 検索してもこのグループ・人物が実在すると確認できない場合、デビュー日・メンバー名・
          プロデュース関係者などを一切創作せず、reading以外の全項目を空文字にする
        - 実在の他のアーティスト・人物・グループ（例：既存の有名アイドルグループやその関係者）との
          関わりは、検索結果で明確に裏付けられた場合以外は絶対に書かない。実在の第三者を
          無関係に結びつけて経歴を作らないこと（虚偽の関係を実在人物に結びつけるのは重大な誤りです）
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
