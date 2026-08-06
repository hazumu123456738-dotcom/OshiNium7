---
name: firebase-guardian
description: OshiNiumのBackend(Firebase)専任チェック。firestore.rules・storage.rules・firestore.indexes.jsonを変更するとき、または新しいFirestoreのlist/queryクエリを追加・変更するときに必ず使う。特に「rule-provability問題」(クエリにルールが参照するフィールドの等価フィルタが無いと、クエリ全体が権限エラーになる罠)の再発防止が目的。「Firestoreルールを変更して」「新しいコレクションを追加して」「権限エラーが出る」のような場面で使う。
---

# firebase-guardian — OshiNium Backend(Firebase)専任チェック

このスキルは、`firestore.rules` / `storage.rules` / `firestore.indexes.json` / Firestoreクエリ(list系)に触れる変更のたびに呼ぶ。目的はただ1つ：**「rule-provability問題」を二度と本番で踏まないこと。**

## rule-provability問題とは(このプロジェクトで過去最低3回発生した既知の罠)

Firestoreのセキュリティルールで、あるフィールドの値によって読み取り可否を分岐させている(例: `allow read: if resource.data.isCommunity == false || ...`)にもかかわらず、クライアント側の**list/queryクエリがそのフィールドに対する等価フィルタ(`.whereField(fieldName, isEqualTo:)`)を含んでいない**場合、Firestoreはルールを「証明できない」と判断し、個々のドキュメントの中身に関わらず**クエリ全体を権限エラーで拒否する**。個別の`get()`は問題なく成功するため発見が遅れやすく、実際に過去以下の2件が長期間気づかれなかった:

- `groups`コレクションの新規作成時重複チェッククエリ: `isPrivate`フィルタ欠落 → 新規グループ作成が権限エラー。
- `calendars`コレクションの個人カレンダーリスナー: `isCommunity`フィルタ欠落 → **個人/共有カレンダーが実装当初からずっと読み込めていなかった**重大な隠れバグ。

## チェックリスト(ルール変更・クエリ変更のたびに必ず実施)

1. **変更したルールが参照する全フィールドを洗い出す。** `resource.data.xxx`や`request.resource.data.xxx`の`xxx`を全てリストアップする。
2. **対応するクライアント側のFirestore list/queryクエリを特定し(`grep -rn "\.whereField\|\.getDocuments\|addSnapshotListener" --include="*.swift"`など)、洗い出した各フィールドに対する等価フィルタが実際に付いているか1つずつ確認する。** 欠けていれば追加する。三項演算子・`||`を含むルールは特に要注意(片方の分岐でしか使わないフィルタを見落としやすい)。
3. **`get()`ベースの単体ドキュメント読み取りとlist/queryを混同しない。** `get()`は個別ドキュメントの中身だけで判定できるため問題になりにくいが、`allow list`/コレクションクエリはこの限りではない。
4. 新しいコレクション・サブコレクションを追加する場合は、default-denyで終わっているか(`match /{document=**} { allow read, write: if false; }`のような閉じたルールがあるか)を確認する。

## 変更後の検証(必須)

- `firestore-tests/`にNode.js製のFirestoreエミュレータルールテスト一式がある(`package.json`/`test.js`)。ルールを変更したら、可能な範囲でここにテストケースを追加・実行し、意図通りに許可/拒否されるか確認する。既存テストが通ることも確認する。
- Storageルール(`storage.rules`)を変更した場合、アップロードパス(`profileImages/` `postMedia/` `diaryMedia/` `events/` `chatMedia/`)の書き込み者制限が`ImageStorageService.swift`の実際のアップロード先パスと一致しているか照合する。

## デプロイ依頼(このセッションからは直接デプロイできない)

ルール変更が完了したら、必ず以下を行う:

1. `firestore.rules`または`storage.rules`の**全文**(差分ではなく)をコードブロックでユーザーに提示する。
2. Firebaseコンソールの該当「ルール」タブに貼り付けてデプロイしてもらうよう依頼する。
3. 「貼り付け後、1行目に`rules_version = '2';`が残っているか確認してください」と必ず一言添える。
4. デプロイされるまでは、そのルールに依存する新機能が権限エラーになるのは想定通りであり、バグではないことを明記する。

## インデックス

新しいクエリで複合条件(等価フィルタ+範囲/ソート等)を使う場合、`firestore.indexes.json`への追加が必要かどうかを確認する。実際に不足していれば、ビルド・実行時のFirestoreエラーメッセージにインデックス作成用のコンソールURLが含まれるので、それを手がかりにする。
