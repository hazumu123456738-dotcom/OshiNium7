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
const { defineSecret } = require("firebase-functions/params");
const nodemailer = require("nodemailer");
// ★ Authユーザーの削除トリガー（onDelete）は、2026年8月時点でv2 SDKにまだ存在せず、
//   v1名前空間（firebase-functions/v1）でのみ提供されている。v1とv2は同じfunctions/index.js内に
//   共存できる（実際に別々のexportsとしてデプロイされる）
const functionsV1 = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const { getAuth } = require("firebase-admin/auth");
const fs = require("fs");
const path = require("path");
const { SignedDataVerifier, Environment, VerificationException } = require("@apple/app-store-server-library");

admin.initializeApp();

// ★ 2026/08/15発見・修正：firebase-adminを^12.6.0→^14.2.0へ上げた際(コミットc333cf29)、
//   v14で名前空間互換API(admin.firestore()/admin.messaging()/admin.storage()/admin.auth()、
//   および admin.firestore.Timestamp/FieldValue)がadminオブジェクトから完全に削除されて
//   いたことに気づかず、この既存コードは全箇所そのまま残っていた。結果、デプロイ自体は
//   成功する（importが無効になるだけで例外は起きない）ため気づかれにくいが、実際に
//   呼ばれるとTypeError: admin.firestore is not a functionで全て失敗していた
//   （sendPushOnTrigger＝チャット/DMのプッシュ通知本体、cleanupUserDataOnDelete、
//   deleteStaleChatTopics、verifyPremiumPurchase/appStoreNotificationsの課金検証、
//   今回追加のnotifyOnNewReportも含め、admin.XXX()を呼ぶ全関数が対象）。
//   v14のモジュラーAPI（getFirestore()等）に統一して修正した

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
    await getMessaging().send({
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

// ============================================================================
// 通報(messageReports)の即時通知
// ----------------------------------------------------------------------------
// ★ release-analyzer 2026-08-15分析で発見：「自動停止ではなく必ず人間が確認してから
//   restrictedUsersに手動で追加する」という方針(荒らし対策)は、messageReportsが
//   allow read:falseかつ管理画面も無いため、開発者が能動的にFirebaseコンソールを
//   開かない限り通報の存在自体に気づけないという穴があった。作成をトリガーに、
//   既存のpushTriggers→sendPushOnTriggerの仕組みに乗せたアプリ内プッシュ通知と、
//   Gmail経由のメール通知を両方同時に送る
const gmailAppPassword = defineSecret("GMAIL_APP_PASSWORD");

const REPORT_NOTIFY_UID = "KOLyKPVg8SdNtXkXXRc96E00P8i1";
const REPORT_NOTIFY_EMAIL = "hazumu123456738@gmail.com";

exports.notifyOnNewReport = onDocumentCreated(
  { document: "messageReports/{docId}", secrets: [gmailAppPassword] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const report = snap.data();
    const title = "新しい通報があります";
    const bodyPreview = `[${report.context || "不明"}] ${report.reason || ""}`.slice(0, 80);

    // ① アプリ内プッシュ通知
    await getFirestore().collection("pushTriggers").add({
      topic: `user_${REPORT_NOTIFY_UID}`,
      notification: { title, body: bodyPreview },
      data: { type: "moderationReport" }
    });

    // ② メール通知（送信元・宛先ともpingjingdan@gmail.com）
    try {
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: REPORT_NOTIFY_EMAIL,
          pass: gmailAppPassword.value()
        }
      });

      const createdAt = report.createdAt && typeof report.createdAt.toDate === "function"
        ? report.createdAt.toDate().toISOString()
        : "(不明)";

      await transporter.sendMail({
        from: `OshiNium 通報アラート <${REPORT_NOTIFY_EMAIL}>`,
        to: REPORT_NOTIFY_EMAIL,
        subject: `【OshiNium】新しい通報: ${report.context || "不明"}`,
        text: [
          `種別: ${report.context || "(不明)"}`,
          `対象ID(contextId): ${report.contextId || "(不明)"}`,
          `対象メッセージ/投稿ID: ${report.messageId || "(不明)"}`,
          `通報者uid: ${report.reporterUid || "(不明)"}`,
          `被通報者uid: ${report.reportedUid || "(不明)"}`,
          `理由: ${report.reason || "(不明)"}`,
          `詳細: ${report.detail || "(なし)"}`,
          `本文/タイトル: ${report.messageText || "(なし)"}`,
          `日時: ${createdAt}`
        ].join("\n")
      });
    } catch (error) {
      console.error("通報メール送信エラー:", error);
    }
  }
);

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
    const db = getFirestore();
    const cutoff = Timestamp.fromMillis(Date.now() - 5 * 24 * 60 * 60 * 1000);

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
// アカウント削除時のサーバー側クリーンアップ
// ----------------------------------------------------------------------------
// ★ 背景：AuthViewModel.deleteAccount()はFirebase Authのアカウント本体と
//   users/{uid}ドキュメントしか消していなかった（クライアントのFirestoreルール上、
//   本人が書き込めるのは自分のドキュメントに限られ、投稿・グループ参加記録・
//   フォロー関係などを本人の権限だけで横断的に消すことはできないため）。
//   Admin SDKはルールを経由しない特権アクセスのため、Authユーザーが実際に削除された
//   直後にこの関数が発火し、本人だけが所有していて他ユーザーに実害の無いデータを
//   横断的に削除する。
//
// ★ スコープを意図的に絞っている（=あえて消さないもの）：
//   - コミュニティ予定（events）: 作成者がこのユーザーでも、既に他メンバーが
//     承認・カレンダー登録済みの可能性があり、削除すると本人以外の実害になるため残す
//     （creatorUidが孤立した参照になるだけで、実害・個人情報漏洩は無い）
//   - グループ本体（groups）: 唯一のオーナーだった場合の引き継ぎ方針は別途の
//     プロダクト判断が必要なため、メンバーシップ（members/{uid}）の削除に留める
//   - dmThreads / groups/{id}/messages: 会話相手が実在する共有データのため、
//     相手側の会話履歴を消してしまうことになる（利用規約第4条の前提とも矛盾する）
//   - messageReports: 通報・被通報の記録はモデレーション上の安全記録として、
//     アカウント削除後も保持する（悪用ユーザーがアカウント削除で通報履歴を
//     消せてしまうことを防ぐ）
//   - storeKitAccountTokens: 課金の不正利用防止のためのトークン記録であり、
//     プロフィール等の個人情報は含まない
async function deleteCollectionByField(db, collectionName, field, uid) {
  const snapshot = await db.collection(collectionName).where(field, "==", uid).get();
  if (snapshot.empty) return 0;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snapshot.size;
}

async function deleteCollectionGroupByField(db, collectionGroupName, field, uid) {
  const snapshot = await db.collectionGroup(collectionGroupName).where(field, "==", uid).get();
  if (snapshot.empty) return 0;

  for (const doc of snapshot.docs) {
    // ★ 他人の投稿へのコメントの場合、Post側のcommentCount（非正規化フィールド）も
    //   一緒に減らす。親投稿自体が同じ削除処理で既に消えている場合はupdateが失敗するが、
    //   件数不整合よりドキュメント消失の方が優先度が低い問題なのでcatchして無視してよい
    if (collectionGroupName === "comments") {
      const postRef = doc.ref.parent.parent;
      if (postRef) {
        await postRef.update({ commentCount: FieldValue.increment(-1) }).catch(() => {});
      }
    }
    await doc.ref.delete();
  }
  return snapshot.size;
}

exports.cleanupUserDataOnDelete = functionsV1
  .region("asia-northeast1")
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const db = getFirestore();
    const bucket = getStorage().bucket("oshinium-79256.firebasestorage.app");

    console.log(`cleanupUserDataOnDelete: uid=${uid} の関連データ削除を開始`);

    // users/{uid}とその全サブコレクション（selectedGroups/blockedUsers/mutedUsers/
    // private/calendarActivityLog/fortuneLog/approvalLog/customThemes）をまとめて削除
    await db.recursiveDelete(db.collection("users").doc(uid));

    // 自分の投稿（コメントサブコレクション込み）
    const ownPosts = await db.collection("posts").where("authorUid", "==", uid).get();
    for (const doc of ownPosts.docs) {
      await db.recursiveDelete(doc.ref);
    }
    console.log(`  posts: ${ownPosts.size}件削除`);

    // 他人の投稿に残したコメント（collectionGroupクエリ、親のcommentCountも補正）
    const deletedComments = await deleteCollectionGroupByField(db, "comments", "authorUid", uid);
    console.log(`  comments(他人の投稿分): ${deletedComments}件削除`);

    // グループメンバーシップ（全グループ横断、collectionGroupクエリ）
    const deletedMemberships = await deleteCollectionGroupByField(db, "members", "uid", uid);
    console.log(`  group memberships: ${deletedMemberships}件削除`);

    // フォロー関係（自分発・自分宛の両方向）
    const followsAsFollower = await deleteCollectionByField(db, "follows", "followerUid", uid);
    const followsAsFollowing = await deleteCollectionByField(db, "follows", "followingUid", uid);
    console.log(`  follows: ${followsAsFollower + followsAsFollowing}件削除`);

    // フォローリクエスト（自分発・自分宛の両方向）
    const requestsFrom = await deleteCollectionByField(db, "followRequests", "fromUid", uid);
    const requestsTo = await deleteCollectionByField(db, "followRequests", "toUid", uid);
    console.log(`  followRequests: ${requestsFrom + requestsTo}件削除`);

    // 通知（自分宛・自分が発生させた両方）
    const notificationsReceived = await deleteCollectionByField(db, "notifications", "recipientUid", uid);
    const notificationsSent = await deleteCollectionByField(db, "notifications", "actorUid", uid);
    console.log(`  notifications: ${notificationsReceived + notificationsSent}件削除`);

    // 本人だけが所有する推し活記録・記録系コレクション
    for (const [collectionName, field] of [
      ["memoryDiaries", "uid"],
      ["oshiExpenses", "uid"],
      ["venueReports", "uid"],
      ["packingChecklistItems", "uid"],
      ["packingTemplates", "uid"],
      ["savedPosts", "uid"],
      ["eventTickets", "authorUid"],
      ["eventGoods", "authorUid"],
      ["eventAnnouncements", "authorUid"],
      ["privateEvents", "creatorUid"]
    ]) {
      const count = await deleteCollectionByField(db, collectionName, field, uid);
      console.log(`  ${collectionName}: ${count}件削除`);
    }

    // プライベートカレンダー（本人しか見られない、他人と共有していないもののみ）
    const privateCalendars = await db
      .collection("calendars")
      .where("ownerId", "==", uid)
      .where("isPrivate", "==", true)
      .get();
    if (!privateCalendars.empty) {
      const batch = db.batch();
      privateCalendars.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
    console.log(`  private calendars: ${privateCalendars.size}件削除`);

    // Storage上の本人所有フォルダ（プロフィール画像・投稿/日記/費用/口コミの画像）
    for (const prefix of [
      `profileImages/${uid}/`,
      `postMedia/${uid}/`,
      `diaryMedia/${uid}/`,
      `expenseMedia/${uid}/`,
      `venueReportMedia/${uid}/`
    ]) {
      await bucket.deleteFiles({ prefix }).catch((error) => {
        console.error(`  Storage削除失敗 (${prefix}):`, error.message);
      });
    }

    console.log(`cleanupUserDataOnDelete: uid=${uid} の関連データ削除完了`);
  });

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
    const decodedIdToken = await getAuth().verifyIdToken(idToken);
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

    await getFirestore().collection("users").doc(uid).set(
      { isPremiumSubscriber: isActive },
      { merge: true }
    );

    // ★ appAccountTokenが含まれていれば、後からのAppStore Server通知（appStoreNotifications）が
    //   このuidへ書き戻せるよう、対応表を最新化しておく
    if (decoded.appAccountToken) {
      await getFirestore().collection("storeKitAccountTokens").doc(decoded.appAccountToken).set(
        { uid, updatedAt: FieldValue.serverTimestamp() },
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

    const tokenDoc = await getFirestore()
      .collection("storeKitAccountTokens").doc(decodedTransaction.appAccountToken).get();
    const uid = tokenDoc.data() && tokenDoc.data().uid;
    if (!uid) {
      console.warn("appStoreNotifications: appAccountTokenに対応するuidが見つからない", decodedTransaction.appAccountToken);
      res.status(200).send("ignored: unknown appAccountToken");
      return;
    }

    await getFirestore().collection("users").doc(uid).set(
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
