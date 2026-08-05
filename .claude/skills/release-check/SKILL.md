---
name: release-check
description: OshiNium7をリリース・提出前にレビューするときに使う。「リリース前チェックして」「バグがないか確認して」「ダークモード対応した？」「アクセシビリティ大丈夫？」のような、UI一貫性・ダークモード・アクセシビリティ・エラーハンドリング・ナビゲーション・レスポンシブ対応の横断確認とバグ出しに使用する。個別の1機能修正ではなく、アプリ全体の品質を横断的に洗い出すときに使う。
---

# Release Check — OshiNium7 リリース前品質レビュー

OshiNium7（SwiftUI + Firebase構成、独自タブバー／NavigationStack多用）をストアに出す前に、UI一貫性・ダークモード・アクセシビリティ・エラーハンドリング・ナビゲーション・レスポンシブ・バグの6軸で横断チェックし、具体的な修正案まで出す。

**このスキルは「見つけたら黙って直す」ではなく、必ず一覧レポートを先に出してから、ユーザーの指示に応じて修正に入る。** リリース前レビューは全体像の把握が目的であり、勝手に大量修正をコミットしない。

## 既知の前提（このプロジェクト特有の状態）

過去の調査で判明している、レビュー時に必ず踏まえるべき事実：

- **ダークモード：現状ほぼ未対応。** `Color(hex: "#FAFAFC")` のような固定Hexカラーが全体で使われており（`grep -rn 'Color(hex:' --include="*.swift" .` で件数確認可能）、`Color(.systemBackground)` 等の動的システムカラーや `.preferredColorScheme` の明示的な扱いがコードベースにほぼ存在しない。つまりダークモード端末で開くと背景は白いまま・文字色とのコントラストが破綻する可能性が高い。これは「バグが1つある」ではなく「全画面共通の設計課題」として扱う。
- **アクセシビリティ：`accessibilityLabel`/`accessibilityHint` 等の付与がほぼゼロ。** アイコンのみのボタン（SF Symbolsの×・戻る・シェアなど）にVoiceOverでの読み上げテキストが無い箇所が大半。
- **独自タブバー：** システム標準の`TabView(.tabItem)`を使わず自作タブバー＋`.safeAreaInset(edge:.bottom)`で実装している（`OshiNiumTabView.swift`）。各タブの中身は`customTabBarHeight`環境値を自分で足し込まないと、下端のボタンやコンテンツがタブバーの裏に隠れる。新しい画面を見るたびに、この環境値を正しく消費しているか確認する。
- **ビルド・実機確認の手順は確立済み：**
  ```bash
  xcodebuild -project OshiNium7.xcodeproj -scheme OshiNium7 \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath /tmp/oshinium_build_check build
  xcrun simctl install <device-udid> /tmp/oshinium_build_check/Build/Products/Debug-iphonesimulator/OshiNium7.app
  xcrun simctl launch <device-udid> com.hiraihazumu.OshiNium7
  xcrun simctl io <device-udid> screenshot <path>.png
  ```
  一時的な画面遷移確認が必要な場合は `// TEMP DEBUG` コメント付きで一時的に`@State`初期値やonAppearトリガーを差し替えてよいが、**確認後は必ず全て削除し、`grep -rn "TEMP DEBUG"`で空になることを確認してから最終ビルドし直す。**

## レビューの進め方（3フェーズ）

### フェーズ1：静的走査（コードを読むだけで拾えるもの）

各観点についてgrep/Readで機械的に洗い出す。

| 観点 | 探し方の例 | 見るポイント |
|---|---|---|
| UI一貫性 | 各`Views/`・`Tabs/`のカード・ボタン・角丸半径・shadowの値を横断比較 | `cornerRadius`が16/18/20/24などバラバラに混在していないか、ボタンの高さ・フォントウェイトが画面ごとに揺れていないか、アクセントカラー（紫系`Color(red:0.70,green:0.55,blue:0.98)`など）が画面によって微妙に違う値になっていないか |
| ダークモード | `grep -rn 'Color(hex:\|Color.white\|Color.black' --include="*.swift"` | 固定色が背景・カードに直接使われている箇所。動的対応が必要なら`Color(.systemBackground)`系への置き換え、または最低限`.preferredColorScheme(.light)`で意図的に固定するかの方針をユーザーに確認する |
| アクセシビリティ | `grep -rn 'Image(systemName:' --include="*.swift"` でアイコンのみのButtonを洗い出す | ラベルの無いアイコンボタン、`minimumScaleFactor`のない長文テキスト、コントラストの弱い`.opacity(0.x)`のテキスト |
| エラーハンドリング | `grep -rn 'catch\|completion(.failure\|errorMessage' --include="*.swift"` | Firestoreリスナーのエラー時に画面上に何も出ない（printログのみで握りつぶし）箇所、ネットワーク断・空データ時のempty state有無 |
| ナビゲーション | 各`NavigationStack`の`navigationDestination`定義を確認 | 戻れない画面（`.navigationBarBackButtonHidden(true)`だが独自の閉じるボタンが無い）、`.fullScreenCover`からの脱出経路、独自タブバーとNavigationStackの奥深くにいる状態でタブを切り替えたときの挙動 |
| レスポンシブ | `GeometryReader`使用箇所（`MonthlyCalendarView.swift`等）を確認 | 小さい端末（iPhone SE相当・幅375pt）や大きい端末（Pro Max・幅430pt）でレイアウトが破綻しないか、`.frame(width:)`の固定値がSEで画面外に出ないか |
| バグ全般 | 直近の変更差分・TODO/FIXMEコメント | `grep -rn 'TODO\|FIXME\|TEMP DEBUG' --include="*.swift" .` が残っていないか |

### フェーズ2：実機（シミュレーター）確認

静的走査だけでは分からない見た目・挙動を確認する。

1. 上記のビルド手順でシミュレーターにインストール。
2. 主要タブ（ホーム／カレンダー／オリジナル／チャット／マイページ）をそれぞれスクリーンショットで確認。
3. **ダークモード確認：** `xcrun simctl ui <device-udid> appearance dark` でダークモードに切り替えてから同じ画面を撮り直し、白背景に白文字のような破綻がないか見る。確認後は `appearance light` で戻す。
4. **Dynamic Type確認：** 可能なら`xcrun simctl status_bar`や設定変更で文字サイズを最大にし、主要画面でテキストが切れる・ボタンが潰れる箇所を探す。
5. 深い階層のナビゲーション（例：カレンダー→予定詳細→編集）を辿り、タブバーの裏にボタンが隠れていないか、独自タブバーの`customTabBarHeight`を消費しているかを確認する。

### フェーズ3：レポート出力

**必ずコードを直接いじる前に、以下の形式でレポートを提示する。**

```
## リリース前チェックレポート

### サマリー
- 検出した問題: X件（重大 X / 中 X / 軽微 X）
- 対応推奨の優先順位: ...

### 1. UI一貫性
- [重大/中/軽微] 問題の説明（該当ファイル:行）
  → 提案する修正

### 2. ダークモード
...

### 3. アクセシビリティ
...

### 4. エラーハンドリング
...

### 5. ナビゲーション
...

### 6. レスポンシブ
...

### 見つかったバグ
- 再現手順 → 原因の当たり → 修正案
```

重大度の目安：
- **重大**：クラッシュ・データ消失・操作不能・完全に読めない/見えないUI
- **中**：見た目が崩れる・タブバーで隠れる・エラー時に何も表示されない
- **軽微**：微妙な色/余白のズレ、アクセシビリティラベル欠如など機能自体は動く問題

レポート提示後、ユーザーが「直して」と言った項目から着手する。修正時は既存のビルド→実機確認→`TEMP DEBUG`削除→最終ビルドのサイクルを必ず踏む。
