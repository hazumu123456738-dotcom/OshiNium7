# Firestoreルールのセキュリティテスト

`../firestore.rules` を実際にFirebaseエミュレーター上で評価し、権限モデルが意図通りかを検証する。

## 実行方法

```bash
cd firestore-tests
npm install
cd ..
npx firebase-tools emulators:exec --only firestore --project oshinium-rules-test "cd firestore-tests && npm test"
```

## 必要環境

- Node.js（確認済み）
- Java Runtime（Firestoreエミュレーター自体がJava製のため必須）

2026-08-05に実際にエミュレーター上で実行し、9件全て成功することを確認済み
（`blockedUsers`は本人のみ読み書き可・`messageReports`は作成のみ可で閲覧不可・
`pushTriggers`はsenderUid本人かつtopicが`user_`形式のみ作成可、をそれぞれ確認）。
