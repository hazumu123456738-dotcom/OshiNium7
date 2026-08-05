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

このセッションの実行環境にはJavaが入っておらず（`/usr/bin/java`はスタブのみ、Homebrewも無し）、
実際にエミュレーターを起動してテストを走らせるところまでは確認できていない。
`node --check test.js` で構文エラーが無いことのみ確認済み。

Javaを用意できる環境（開発者のMac等）で上記コマンドを実行すれば、そのまま動くはず。
