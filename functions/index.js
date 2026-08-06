// index.js
//
// OshiNium Cloud Functions
// ----------------------------------------------------------------------------
// ★ クライアント（PushNotificationService.swift）は"pushTriggers"コレクションに
//   ドキュメントを書き込むだけで、実際のFCM送信はこの関数が担う。
//   クライアントは他ユーザーの生のデバイストークンを一切扱わず、必ず"user_{uid}"という
//   トピック宛てに送る設計（各端末はサインイン中、FCMTokenSync.swiftで自分のトピックを
//   自動購読している）。
//
// ★ デプロイ方法（このリポジトリのルートディレクトリで）:
//   1) このマシンにNode.js（LTS版。https://nodejs.org からインストーラーで入れられる。
//      Homebrewは不要）をインストールする
//   2) npm install -g firebase-tools
//   3) firebase login
//   4) cd functions && npm install && cd ..
//   5) firebase deploy --only functions
//
// ★ 前提：Firebaseプロジェクトが Blaze（従量課金）プランになっていること
//   （Cloud Functionsのデプロイ自体にBlazeプランが必須）。この規模のアプリなら
//   実際の請求はほぼ発生しない（無料枠の範囲内）。

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// ★ リージョンはFirestoreデータベースの所在地に合わせるのが望ましい。
//   Firebaseコンソールの「Firestore Database」→「データベースの詳細」で
//   実際のロケーションを確認し、違っていればここを書き換えること
//   （例："asia-northeast1" = 東京、"us-central1" = 米国中部）
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

exports.sendPushOnTrigger = onDocumentCreated("pushTriggers/{docId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  const topic = data.topic;
  const notification = data.notification;
  // ★ 通知タップ時にクライアント（AppDelegate.swift）が該当のグループチャット/DMへ
  //   遷移できるよう、送信元がセットしたルーティング情報をFCMのdataフィールドとしてそのまま転送する。
  //   FCMのdataは値がすべて文字列である必要があるため、文字列のキー・値だけを拾う
  const routeData = {};
  if (data.data && typeof data.data === "object") {
    for (const [key, value] of Object.entries(data.data)) {
      if (typeof value === "string") {
        routeData[key] = value;
      }
    }
  }

  if (!topic || !notification || !notification.title || !notification.body) {
    console.error("pushTriggers ドキュメントに必須フィールドが無い", event.params.docId);
    await snap.ref.delete();
    return;
  }

  try {
    await admin.messaging().send({
      topic,
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: routeData
    });
  } catch (error) {
    console.error("FCM送信エラー:", error);
  }

  // ★ 送信済みのトリガードキュメントを溜め続けないよう削除する。
  //   クライアント側のFirestoreルールでは削除できないが、Admin SDKはルールを経由しないため可能
  await snap.ref.delete();
});
