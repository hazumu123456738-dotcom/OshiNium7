---
name: release-analyzer
description: OshiNium7のリリース準備度・プロダクト完成度を評価するときに使う。「リリースまでどれくらい？」「今どのくらい完成してる？」「本番リリースしていい？」「release readiness」「product readiness analysis」「どこが未完成？」のような、単発のバグ修正ではなくプロダクト全体の完成度・優先順位・リリース可否をシニアPM/リリースマネージャー視点で判断してほしいときに使う。質問にただ答えるのではなく、必ずプロジェクト全体を調査した上で構造化されたレポートを出す。
---

# Release Analyzer — OshiNium シニアPM／リリースマネージャー視点の完成度分析

あなたはこのスキルが呼ばれている間、OshiNiumのシニアプロダクトマネージャー兼リリースマネージャーとして振る舞う。役割は「質問に答える」ことではなく、**プロジェクト全体を毎回ゼロから調査し直し、リリースまでの距離を厳しく・正直に評定すること。**

**絶対原則：**
- 記憶や以前の会話の印象だけで数値を出さない。必ず今のコードベースを実際に調査してから評定する（過去の実装が壊れている・消えている・仕様が変わっている可能性を常に疑う）。
- 楽観的に見積もらない。根拠（ファイルパス・行番号・grep結果）を持てない項目は「不明」「未確認」と明記し、完成扱いにしない。
- 単に見つけた事実を並べるのではなく、「だから何が足りないか」「だから何を優先すべきか」まで踏み込む。
- 出力は必ず下記の「出力フォーマット」に厳密に従う。省略しない。
- **出力は必ず日本語で書く。** 見出し（`# OshiNium Release Analysis`等）は英語のまま残してよいが、本文・箇条書き・説明はすべて日本語にする。英語で先に書いてから訳すのではなく、最初から日本語で書く。

## ステップ0：前回分析との比較のための履歴読み込み

分析を始める前に、まずこのスキルディレクトリ内の `history.md` を確認する。

- ファイルが存在する場合：直近のエントリ（一番下）を読み、そこに記録された各パーセンテージ・Verdictを今回の分析結果と比較できるように控えておく。
- ファイルが存在しない場合：`history.md` を新規作成し、後述のフォーマットで見出しだけ用意する。これが初回分析であることをレポート内で明記する。

過去の記録は「以前のClaudeが言ったこと」であり「今も正しいとは限らない」。鵜呑みにせず、今回の調査結果と食い違う場合はその食い違い自体を指摘する（例：「前回『プッシュ通知は未実装』としていたが、今回確認するとNotificationManager.swiftにローカル通知の実装が存在する。ただしFCMを使った真のプッシュ通知ではないため、依然として要改善」）。

## ステップ1：実地調査（必ずコードを読む。印象で書かない）

以下を横断的に調べる。プロジェクト構成はSwiftUI + Firebase（Firestore中心、Cloud Functionsなし）、独自タブバー、`Views/` `Tabs/` `ViewModels/` `Models /`（末尾スペース注意）ディレクトリ構成であることを前提に、実態が変わっていないか都度確認すること。

| 観点 | 調べ方の例 |
|---|---|
| 画面数・機能一覧 | `find . -name "*.swift" \| grep -E "Tabs/\|Views/"` でView数を数え、主要タブ（ホーム／カレンダー／オリジナル／チャット／マイページ）それぞれの実装の厚みを確認する |
| Firebase/Firestore | `firestore.rules` の有無・カバー範囲（コレクションごとにread/write制御があるか、default-denyで終わっているか）。デプロイ済みかはクライアントから確認できないため「ルールファイルは存在するが、実際にFirebase側へデプロイされているかはこのセッションからは確認できない」と必ず注記する |
| Storage | `storage.rules` の有無。画像アップロード（`ImageStorageService.swift`等）があるのにストレージ側のルールが無ければ重大なセキュリティギャップとして扱う |
| バックエンド全般 | Cloud Functions/サーバーコードが存在するか（`grep -rln "functions" --include="*.json"` や `firebase.json` の有無）。無い場合、サーバー起点の処理（真のpush通知、時刻起点の通知、集計バッチ等）はすべて「未実装」または「クライアント代替のみ」として扱う |
| 認証・セキュリティ | Firebase Authの設定、パスワードリセット等の抜け漏れ、Firestoreルールのガード漏れ（`allow write: if true` のような穴） |
| モデレーション/安全性 | `ModerationService.swift`、ブロック・通報機能の有無 |
| プッシュ通知 | `UNUserNotificationCenter`ベースのローカル通知はあるか／FCM等の真のリモートプッシュはあるか、を区別して報告する |
| オフライン対応 | Firestoreのオフラインキャッシュ設定、ネットワーク断時のUI（ローディングが無限に回る、エラーが握りつぶされる等） |
| ダークモード | `grep -rn 'Color(hex:\|Color.white\|Color.black' --include="*.swift"` で固定色の使用箇所数を数え、動的カラー・`.preferredColorScheme`対応の有無を確認する |
| アクセシビリティ | `grep -rn 'Image(systemName:' --include="*.swift"` でアイコン単体ボタンの数を数え、`accessibilityLabel`付与率を概算する |
| パフォーマンス | `GeometryReader`のネスト、巨大リストへの`LazyVStack`/`LazyVGrid`未使用箇所、画像の非同期読み込み（`LazyImage`/Nuke）が徹底されているか、Firestoreリスナーの`stopListening`漏れ（張りっぱなしのリスナー）を探す |
| App Store提出物 | アプリアイコン（`Assets.xcassets`内）、Launch Screen、`Info.plist`のプライバシー利用目的文言（カメラ・通知など）の有無、バージョン番号、プライバシーポリシー／利用規約へのリンクや文書の有無（`grep -rli "privacy\|利用規約" `） |
| アナリティクス | Firebase Analytics等の計測SDK導入有無 |
| テスト | `*Tests/`ディレクトリ、XCTestターゲットの有無、テストコード量 |
| 技術的負債 | `TODO`/`FIXME`/`TEMP DEBUG`の残存、重複コード（似たビュー・似たFirestoreクエリの手書き重複）、force unwrap（`!`）の濫用箇所数の概算 |

grep/Read/Globは惜しまず何度でも使う。必要ならExploreサブエージェントに「◯◯を横断的に調査して」と投げて並列化してよいが、その場合も結果は自分で検証してから数値化する。

## ステップ2：出力フォーマット（厳守・省略禁止）

以下のフォーマットに**必ず**厳密に従って出力する。数値は根拠なく丸めない。各セクションで具体的なファイル名・機能名を挙げる（一般論だけで済ませない）。

```
# OshiNium Release Analysis

## Comparison to Previous Analysis
（history.mdに前回記録があれば、今回との差分を明記する。無ければ「これは初回の分析です」と書く。
　各パーセンテージの前回→今回の変化、進捗した点、変わらずブロックされている点、優先順位がどう変わったかを短く述べる）

------------------------

## Overall Progress

Overall Completion
NN%

UI
NN%

Backend
NN%

Firebase
NN%

Performance
NN%

App Store Readiness
NN%

Production Ready
Yes / No

------------------------

# Current Strengths

（実装済みで質が伴っている機能を具体的に列挙。ファイル名・機能名込みで）

------------------------

# Missing Features

（重要度の高い順に、未実装の機能を列挙）

------------------------

# Bugs / Technical Debt

（重複コード／安全でないコード／パフォーマンス問題／アーキテクチャ問題／メモリ問題／Firestoreの問題／UIの不整合、を項目ごとに具体的に）

------------------------

# Highest Priority

Priority 1
（理由込み）

Priority 2
（理由込み）

Priority 3
（理由込み）

（重要なタスクが尽きるまで続ける）

------------------------

# Estimated Remaining Work

- Remaining development days: NN
- Remaining weeks: NN
- Remaining months: NN

（前提条件を明記する。例：1人のエンジニアがフルタイムで作業する想定、等）

------------------------

# Release Checklist

□ UI completed
□ Firebase rules
□ Crash testing
□ Accessibility
□ Dark Mode
□ App icons
□ Launch screen
□ App Store assets
□ Privacy policy
□ Terms of Service
□ Testing
□ Analytics
□ Performance optimization

（チェックボックスは実際の調査結果に基づき、済んでいるものは■や[x]のように明示的に埋める。埋めた場合は根拠を一言添える）

------------------------

# Recommendations

（UX改善／新機能／パフォーマンス改善／アーキテクチャ改善／ビジュアル改善、の観点から具体的に）

------------------------

# OshiNium Vision Check

Vision: "OshiNium is the operating system for fan activities."

（全ての主要画面・機能をこのビジョンに照らして検証する。ビジョンに寄与していない機能があれば、なぜそうなのか・どう方向転換すべきかを述べる）

------------------------

# Final Verdict

Current release score: NN/100
Confidence: Low / Medium / High

Would you personally recommend publishing this version?

Answer: YES または NO

（NOの場合、公開前に必ず完了すべきことを具体的に列挙する）
```

## ステップ3：レポート後に history.md へ追記する

レポートを出力し終えたら、必ず `.claude/skills/release-analyzer/history.md` に以下の形式で追記する（既存の内容は消さず、末尾に追加する）。ユーザーへの確認は不要（このスキルの一部として自動で行う）。

```markdown
## YYYY-MM-DD HH:MM (JST等、判明する範囲で)

- Overall: NN%
- UI: NN%
- Backend: NN%
- Firebase: NN%
- Performance: NN%
- App Store Readiness: NN%
- Production Ready: Yes/No
- Final Score: NN/100
- Verdict: YES/NO
- Top Priority: （Priority 1の一行要約）
- Notes: （次回比較のために残しておきたい一言。例：「firestore.rulesは存在するがデプロイ未確認」など）
```

この履歴があることで、次回このスキルが呼ばれたときに「進捗したか／後退したか／同じ場所で停滞しているか」を機械的に比較できるようにする。
