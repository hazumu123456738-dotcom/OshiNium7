# OshiNium7 開発規約(CTO運用)

## プロジェクト概要

- SwiftUI + Firebase(Firestore中心、Cloud Functionsは`functions/`にプッシュ通知トリガーのみ)。
- ビジョン: **"OshiNium is the operating system for fan activities."**（推し活のOS）。すべての判断はこのビジョンを強めるかどうかで評価する。
- Bundle ID: `com.hiraihazumu.OshiNium7`。Firebaseプロジェクト: `oshinium-79256`。
- Xcodeターゲット3つ: `OshiNium7`(本体) / `OshiNiumWidgetExtension`(ウィジェット) / `OshiNium7Tests`(XCTest)。
- 独自タブバー実装（`TabView(.tabItem)`ではなく`Tabs/OshiNiumTabView.swift`の自作+`.safeAreaInset(edge:.bottom)`）。5タブ: ホーム/カレンダー/オシニウム(看板タブ)/チャット/マイページ。

## ディレクトリと既知の罠

`OshiNium7/`直下だけがXcodeのfile-system-synchronizedグループで、`Views/` `Models/` `Tabs/` `Managers/` `ViewModels/`は**非同期グループ**。新規Swiftファイルを追加したら`xcodeproj` Rubyジェムで`project.pbxproj`に手動登録する必要がある。手順・注意点(フルパスを渡すと`Views/Views/...`の二重パスでビルド破壊する罠など)は**`project-setup` Skill**に集約してあるので、新規ファイル追加を伴う作業では必ずこれを参照する。

## Git運用ルール

- `main`は常にビルド可能な状態を維持する。
- 「機能追加」「Firestoreルール変更」「複数ファイルにまたがる変更」は必ず`feature/<説明>`ブランチを切る。タイポ等の軽微修正はmain直接コミットでよい。
- マージ前に該当QA Skill(`release-check`または`verify`)を最低1回通す。
- Worktreeは常用しない。大きな機能実装の途中で別の緊急対応が必要になった場合のみ追加し、`.pbxproj`に触れるタスクを複数のWorktreeで同時に走らせない(競合防止)。
- push/GitHub(`origin` = `hazumu123456738-dotcom/OshiNium7`)は区切りのバックアップとして使う。

## Skill選択ルーティング表

| こういう要求のとき | 呼ぶSkill |
|---|---|
| 高レベルな機能追加要求全般の起点、プロジェクト全体の継続改善 | `oshi` |
| 画面の新規実装・変更の最後の仕上げ | `design-review` |
| 新機能・UXフローのアイデア出し(企画のみ、実装はしない) | `oshinium-ai` |
| Firestore/Storageルール・インデックス・Cloud Functions変更 | `firebase-guardian` |
| 新規Swiftファイル追加・プロジェクト構成に関わる作業 | `project-setup` |
| リリース前の横断チェック(UI一貫性/ダークモード/アクセシビリティ等) | `release-check` |
| 実機シミュレーターでの動作確認 | `verify` |
| 完成度・リリース可否の評定 | `release-analyzer` |

判断に迷う場合、1人がすべて決めるのではなく該当Skillの専門知識を通してから判断する。

## 禁止事項・確認必須事項

- 検証用の`// TEMP DEBUG`コードは確認後に必ず削除し、`grep -rn "TEMP DEBUG"`が空であることを確認してからコミットする(コミット時はHookでも機械的にブロックされる)。
- ファイルの**削除**は必ずユーザーに確認を取ってから実行する。編集・新規作成は指示に沿う内容であれば自律的に進めてよい。
- `firestore.rules`/`storage.rules`は、このセッションから直接Firebaseへデプロイできない。変更したら全文をユーザーに提示し、Firebaseコンソールへの手動貼り付けを依頼する(1行目`rules_version = '2';`が残っているか確認するよう毎回念押しする)。
- 一区切り作業が終わったら、次の優先順位を提示し、実行前に必ず確認を取る。

## 検証の基本形

```bash
xcodebuild -project OshiNium7.xcodeproj -scheme OshiNium7 \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/oshinium_build_check build

DEVICE=<シミュレーターUDID>
APP_PATH=/tmp/oshinium_build_check/Build/Products/Debug-iphonesimulator/OshiNium7.app
xcrun simctl install $DEVICE "$APP_PATH"
xcrun simctl launch $DEVICE com.hiraihazumu.OshiNium7
xcrun simctl io $DEVICE screenshot <path>.png
```

タップ操作の自動化(osascript等)はホストの許可プロンプトでハングするため使わない。特定画面への到達は`// TEMP DEBUG`を使う。詳細な罠・落とし穴(ログの拾い方、テストデータの罠など)は`verify` Skillを参照。
