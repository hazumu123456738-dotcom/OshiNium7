---
name: verify
description: OshiNium7でコード変更を実機（シミュレーター）で動かして検証するときに使う。ビルド・インストール・起動・特定画面への到達・スクリーンショット・ログ確認の一連の手順（このリポジトリで実際に機能した手順）をまとめたもの。
---

# OshiNium7 — 検証（verify）の手引き

CTO運用モデル移行(CLAUDE.md参照)以降、`main`は常にビルド可能な状態を維持し、機能追加は`feature/<説明>`ブランチで進める運用になっている。`git status`/`git diff`は現在の作業スコープ把握に使ってよい。ただし移行前の古いコミットについては粒度が粗い場合があるので、過去のコミット内容を根拠に判断する際は実際のコードを読んで裏取りする。

## ビルド・インストール・起動（この3行が基本形）

```bash
xcodebuild -project OshiNium7.xcodeproj -scheme OshiNium7 \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/oshinium_build_check build

DEVICE=678A4DE8-3268-4906-87FF-823F456C7AED   # iPhone 17 シミュレーター
APP_PATH=/tmp/oshinium_build_check/Build/Products/Debug-iphonesimulator/OshiNium7.app
xcrun simctl terminate $DEVICE com.hiraihazumu.OshiNium7   # 失敗してもOK（起動してなければ何もしない）
xcrun simctl install $DEVICE "$APP_PATH"
xcrun simctl launch $DEVICE com.hiraihazumu.OshiNium7
xcrun simctl io $DEVICE screenshot <path>.png
```

新規Swiftファイルを追加した場合は、先にXcodeプロジェクトへの手動登録が必要（`Views/`・`Models/`はfile-system-synchronizedグループではない）。手順は`project-setup` Skillに集約してあるので参照する。

## 特定の画面・状態まで到達する（タップ自動化は使えない）

Accessibility経由のosascript等によるタップ自動化はホストの許可プロンプトでハングするため**使わない**。代わりに`// TEMP DEBUG`コメント付きで、狙った画面まで自動的に到達するコードを一時的に仕込む：

- 起動直後に特定タブを開きたい：`OshiNiumTabView.swift`の`@State private var selectedTab: Tab = .home`を一時的に`.chat`等に変更（`Tab`enumは小文字`mypage`であることに注意、`.myPage`はコンパイルエラー）
- 特定の画面・シートまで自動遷移したい：対象Viewの`onAppear`に`DispatchQueue.main.asyncAfter(deadline: .now() + N) { ... }`で状態を書き換える（`showXxxSheet = true`、`fullScreenCover(isPresented:)`のトリガーなど）
- フォーム入力→送信までまとめて検証したい：`TextField`の`@State`変数に直接文字列を代入してから、送信関数を直接呼ぶ（例：`inputText = "..."; send()`）

**確認後は必ず全て削除し、`grep -rn "TEMP DEBUG" --include="*.swift" .`が空になることを確認してから最終ビルドし直す。** これを飛ばして「検証用に一時的に変えたコード」がそのまま残った状態を完了報告にしない。

**★ 最重要：`xcodebuild`が成功しただけで「完了」にしない。** ソースコードのTEMP DEBUGを消してビルドが通っても、**シミュレーターに入っているのはまだ古い(TEMP DEBUGが仕込まれたままの)ビルド**であることを忘れがちな落とし穴がある。実際に過去、この手順を飛ばしたために「マイページを開くと投稿一覧へ自動遷移する」という検証用の一時コードがシミュレーターに残ったまま放置され、ユーザーがそれを本物のバグとして報告する事態が起きた（[[feedback_verify_must_reinstall]]）。TEMP DEBUG削除後は必ず：
1. `xcrun simctl terminate` → `install` → `launch` で実際に再インストールする
2. スクリーンショットで、TEMP DEBUGを仕込む前の本来の挙動に戻っていることを目で確認する

この2つを済ませるまで、作業を「完了」と報告しない。

## ログの確認（重要な落とし穴）

**Swiftの`print()`はこの環境では拾えない。** `xcrun simctl spawn <device> log stream`はFirebase SDK等が`os_log`で出すログ（`[FirebaseFirestore]`等）は問題なく拾えるが、アプリコード内の素の`print()`はos_logを経由しないため出てこない。`xcrun simctl launch --stdout=<path> --stderr=<path>`でのリダイレクトも、このサンドボックス環境では毎回ファイルが作成されず機能しなかった（原因未特定、要再挑戦の価値はあるが期待しない）。

権限エラーやFirestoreの成功/失敗を切り分けたいときは、`print()`診断コードを仕込むのではなく、以下のどちらかを使う：

1. **Firebase自身のログ**：`xcrun simctl spawn $DEVICE log stream --level debug --predicate 'process == "OshiNium7"' > out.txt &` をバックグラウンドで起動しておき、後で`grep -i "Missing or insufficient permissions\|FirebaseFirestore"`する。書き込み先パス・クエリ内容までログに出るので、想定したパスと一致しているかの確認に使える。
2. **画面に直接出す**：一時的に`List(...)`等でデータを画面に表示して、その状態をスクリーンショットで見る（例：`groupViewModel.groups`の中身をタイトルとIDだけ並べて表示し、期待した実データが存在するか確認した）。ログよりも確実で、`print()`が拾えないこの環境では基本これを使う。

## テストデータの罠

このシミュレーターのFirestoreには、シード/デモ用途らしき`Heart2Heart-id`・`ATEEZ-id`・`xikers-id`のようなカスタム文字列IDのグループがあり、**これらは`members`サブコレクションが空**（誰のmemberドキュメントも存在しない）。UI上は`myGroupRole`のフォールバックで「オーナー」と表示されるため一見メンバーに見えるが、実際にはグループスコープの読み書きが軒並み権限エラーになる。**グループ絡みの機能を検証するときは、アプリの「新規グループチャットを作る」フローで実際に作られた、UUID形式のIDを持つグループ（例：後から自分で作った「担当仲間」等）を使うこと。** 症状：`groups/{id}/messages`のような既存の動いているはずの機能まで権限エラーになったら、まずこのメンバー欠落を疑う（`GroupMemberManagementView(group:)`を一時的に開いてメンバー数を見れば一発で分かる）。

## Firebaseルールのデプロイ

このセッションからは`firestore.rules`/`storage.rules`を直接デプロイできない（`firebase` CLI・認証情報なし）。更新したら全文をコードブロックでユーザーに提示し、Firebaseコンソールの「ルール」タブに貼り付けて公開してもらう。デプロイ前は新しいルールに依存する機能が権限エラーになるのは想定通りであり、バグではない。貼り付け後は1行目`rules_version = '2';`が残っているか確認するよう毎回念押しする。
