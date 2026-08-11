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
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const { SignedDataVerifier, Environment, VerificationException } = require("@apple/app-store-server-library");

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

// ★ 匿名/公開チャット（コミュニティチャット）は「掲示板のスレッド」に近い設計で、
//   グループのメンバーなら誰でも自由にトークルームを立てられる（groups/{groupId}/anonymousTopics,
//   groups/{groupId}/openTopics）。作りっぱなしで誰も発言しなくなったルームが無限に
//   溜まり続けないよう、5日間メッセージが無かったルームは自動的に削除する。
//   ★ lastMessageAtはルーム作成時・メッセージ送信のたびにクライアント側で更新している
//   非正規化フィールド（ChatViewModel.createAnonymousTopic/createOpenTopic、および
//   メッセージ送信時の更新箇所を参照）。全グループ横断でチェックする必要があるため、
//   collectionGroupクエリを使う（firestore.indexes.jsonにCOLLECTION_GROUPスコープの
//   単一フィールド索引を追加済み。デプロイしないとこの関数はクエリ時にエラーになる）
exports.deleteStaleChatTopics = onSchedule(
  { schedule: "every 24 hours", timeZone: "Asia/Tokyo" },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 5 * 24 * 60 * 60 * 1000);

    for (const collectionGroupName of ["anonymousTopics", "openTopics"]) {
      const snapshot = await db
        .collectionGroup(collectionGroupName)
        .where("lastMessageAt", "<", cutoff)
        .get();

      console.log(`${collectionGroupName}: ${snapshot.size}件の未活動トークルームを削除します`);

      for (const doc of snapshot.docs) {
        // ★ messagesサブコレクションを含め、ドキュメントごと再帰的に削除する
        await db.recursiveDelete(doc.ref);
      }
    }
  }
);

// ============================================================================
// プレミアム課金の検証（App Store Server Library）
// ----------------------------------------------------------------------------
// ★ 背景：以前はクライアント（SubscriptionManager.swift）がStoreKitでの購入検証後、
//   自分のusers/{uid}.isPremiumSubscriberに直接trueを書き込んでいた。firestore.rulesは
//   本人のドキュメントへの書き込みを許可している以上、この値が「本物の購入」によるものかは
//   サーバー側で検証しない限り誰にも保証できず、理論上は課金なしでプレミアム機能を
//   無料で解除できてしまっていた。ここではApple公式の@apple/app-store-server-libraryで
//   StoreKitの署名付きトランザクション（JWS）を独立に検証し、Admin SDK（Firestoreルールを
//   経由しない特権アクセス）経由でのみisPremiumSubscriberを書き込む。
//
// ★ 追加の事前準備：
//   1) App Apple ID（本番判定の検証に必須）は設定済み（2026/08/11、6798340695）
//   2) App Store Connect →「アプリ情報」→「App Store Server通知」で、
//      本番URL・サンドボックスURLの両方に、下記でデプロイされるappStoreNotifications関数の
//      URL（firebase deploy後にコンソールに表示される、
//      https://asia-northeast1-oshinium-79256.cloudfunctions.net/appStoreNotifications 形式）
//      を設定する（バージョン2を選択すること）
//   3) functions/certs/AppleRootCA-G3.cer が存在すること（このセッションで
//      https://www.apple.com/certificateauthority/AppleRootCA-G3.cer から取得済み。
//      Appleが証明書を更新した場合はこのファイルを差し替える）
const APP_BUNDLE_ID = "com.hiraihazumu.OshiNium7";
const MONTHLY_PRODUCT_ID = "com.hiraihazumu.OshiNium7.premium.monthly";
// ★ App Store Connect「App情報」ページに表示されるApp Apple ID(2026/08/11設定)
const APP_APPLE_ID = 6798340695;

const appleRootCertificates = [
  fs.readFileSync(path.join(__dirname, "certs", "AppleRootCA-G3.cer"))
];

const verifierCache = {};
function getVerifier(environment) {
  if (!verifierCache[environment]) {
    verifierCache[environment] = new SignedDataVerifier(
      appleRootCertificates,
      true, // enableOnlineChecks（失効チェック・有効期限チェックをApple側にも問い合わせる）
      environment,
      APP_BUNDLE_ID,
      environment === Environment.PRODUCTION ? (APP_APPLE_ID || undefined) : undefined
    );
  }
  return verifierCache[environment];
}

// ★ ProductionのTransactionをSandboxの検証器に通す（あるいはその逆）と
//   VerificationStatus.INVALID_ENVIRONMENTで例外になる。審査時・TestFlight・実運用の
//   両方が同じエンドポイントに届くため、まずProductionとして検証し、環境不一致の
//   例外が出たらSandboxとして再試行する
async function verifyTransactionAnyEnvironment(signedTransactionInfo) {
  try {
    return await getVerifier(Environment.PRODUCTION).verifyAndDecodeTransaction(signedTransactionInfo);
  } catch (error) {
    if (error instanceof VerificationException) {
      return await getVerifier(Environment.SANDBOX).verifyAndDecodeTransaction(signedTransactionInfo);
    }
    throw error;
  }
}

async function verifyNotificationAnyEnvironment(signedPayload) {
  try {
    return await getVerifier(Environment.PRODUCTION).verifyAndDecodeNotification(signedPayload);
  } catch (error) {
    if (error instanceof VerificationException) {
      return await getVerifier(Environment.SANDBOX).verifyAndDecodeNotification(signedPayload);
    }
    throw error;
  }
}

// ★ 検証済みトランザクションから「今この瞬間、プレミアムとして有効か」を1箇所で判定する。
//   notificationTypeごとに個別分岐すると実装漏れ・解釈違いのリスクが高いため、
//   常に「有効期限が未来か」「返金・剥奪されていないか」という事実だけで判定する
//   （更新・失効・返金など、どんな通知が来てもこの2条件に必ず反映される）
function isTransactionActive(decodedTransaction) {
  if (decodedTransaction.productId !== MONTHLY_PRODUCT_ID) return null; // 対象商品ではない
  if (decodedTransaction.revocationDate) return false;
  if (!decodedTransaction.expiresDate) return false;
  return decodedTransaction.expiresDate > Date.now();
}

// ── verifyPremiumPurchase：クライアントが購入・復元の直後に自分で呼ぶ ──────
// ★ Firebase Authの検証済みIDトークンをAuthorizationヘッダーで受け取り、
//   Admin SDKでverifyIdToken()して初めてuidを信頼する（クライアントが
//   「自分は誰か」を自己申告する余地を無くす）。SwiftのFirebaseFunctions SDKを
//   新規に依存追加しなくて済むよう、あえてonCall(callable)ではなくonRequestにしている
exports.verifyPremiumPurchase = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const authHeader = req.get("Authorization") || "";
  const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length) : null;
  if (!idToken) {
    res.status(401).json({ error: "missing Authorization bearer token" });
    return;
  }

  let uid;
  try {
    const decodedIdToken = await admin.auth().verifyIdToken(idToken);
    uid = decodedIdToken.uid;
  } catch (error) {
    console.error("verifyPremiumPurchase: IDトークン検証エラー:", error);
    res.status(401).json({ error: "invalid ID token" });
    return;
  }

  const transactionJWS = req.body && req.body.transactionJWS;
  if (!transactionJWS || typeof transactionJWS !== "string") {
    res.status(400).json({ error: "transactionJWS is required" });
    return;
  }

  try {
    const decoded = await verifyTransactionAnyEnvironment(transactionJWS);
    const isActive = isTransactionActive(decoded);
    if (isActive === null) {
      res.status(400).json({ error: "unexpected productId" });
      return;
    }

    await admin.firestore().collection("users").doc(uid).set(
      { isPremiumSubscriber: isActive },
      { merge: true }
    );

    // ★ appAccountTokenが含まれていれば、後からのAppStore Server通知（appStoreNotifications）が
    //   このuidへ書き戻せるよう、対応表を最新化しておく
    if (decoded.appAccountToken) {
      await admin.firestore().collection("storeKitAccountTokens").doc(decoded.appAccountToken).set(
        { uid, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    }

    res.status(200).json({ isPremium: isActive });
  } catch (error) {
    console.error("verifyPremiumPurchase: 検証エラー:", error);
    res.status(400).json({ error: "verification failed" });
  }
});

// ── appStoreNotifications：Apple自身がサーバー間で呼ぶWebhook ───────────
// ★ アプリを開いていない間に起きた自動更新・失効・返金・剥奪を反映するための入り口。
//   Appleからの呼び出しにFirebase Authは付かないため、代わりにJWS自体の署名検証
//   （Appleの秘密鍵で署名されている＝Apple自身が発行したものだと保証される）を信頼の根拠にする。
//   appAccountToken（購入時にSubscriptionManager.swiftが設定）を手がかりに
//   storeKitAccountTokensコレクションからuidを逆引きする
exports.appStoreNotifications = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const signedPayload = req.body && req.body.signedPayload;
  if (!signedPayload || typeof signedPayload !== "string") {
    // ★ Appleからの本来のリクエストではありえない形。200を返して再送を止める
    res.status(200).send("ignored: no signedPayload");
    return;
  }

  try {
    const notification = await verifyNotificationAnyEnvironment(signedPayload);
    const signedTransactionInfo = notification.data && notification.data.signedTransactionInfo;
    if (!signedTransactionInfo) {
      // ★ REFUND_DECLINED等、トランザクション情報を伴わない通知種別もある。
      //   処理対象外として黙って200を返す
      res.status(200).send("ignored: no transaction info");
      return;
    }

    const decodedTransaction = await verifyTransactionAnyEnvironment(signedTransactionInfo);
    const isActive = isTransactionActive(decodedTransaction);
    if (isActive === null || !decodedTransaction.appAccountToken) {
      res.status(200).send("ignored: not our product or no appAccountToken");
      return;
    }

    const tokenDoc = await admin.firestore()
      .collection("storeKitAccountTokens").doc(decodedTransaction.appAccountToken).get();
    const uid = tokenDoc.data() && tokenDoc.data().uid;
    if (!uid) {
      console.warn("appStoreNotifications: appAccountTokenに対応するuidが見つからない", decodedTransaction.appAccountToken);
      res.status(200).send("ignored: unknown appAccountToken");
      return;
    }

    await admin.firestore().collection("users").doc(uid).set(
      { isPremiumSubscriber: isActive },
      { merge: true }
    );

    res.status(200).send("ok");
  } catch (error) {
    console.error("appStoreNotifications: 検証エラー:", error);
    // ★ 検証に失敗しても200を返し、Appleの無限リトライを避ける
    //   （不正なペイロードは検証失敗＝Firestoreに一切書き込まれないため安全側に倒れている）
    res.status(200).send("verification failed, ignored");
  }
});
