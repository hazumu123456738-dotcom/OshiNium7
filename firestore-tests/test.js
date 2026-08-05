// firestore.rulesの権限モデルを、実際のルールファイルに対してFirebaseエミュレーターで検証する。
// 実行方法（プロジェクトルートから）:
//   cd firestore-tests && npm install
//   firebase emulators:exec --only firestore "npm test"
//
// XCTest（OshiNium7Tests）はSwift側のロジックを見るだけで、実際のFirestoreルール文字列が
// 意図通りかまでは検証できない。ここではその隙間を埋め、「一見緩そうに見えるが実は正しい」
// messageReports・pushTriggers・blockedUsersの権限境界を固定化する

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} = require("@firebase/rules-unit-testing");

let testEnv;

before(async function () {
  this.timeout(30000);
  testEnv = await initializeTestEnvironment({
    projectId: "oshinium-rules-test",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8")
    }
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

describe("blockedUsers（自分だけが読み書きできる）", () => {
  it("本人は自分のblockedUsersを書き込める", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me/blockedUsers/uid_them").set({ blockedAt: new Date() })
    );
  });

  it("他人のblockedUsersには書き込めない", async () => {
    const other = testEnv.authenticatedContext("uid_other");
    await assertFails(
      other.firestore().doc("users/uid_me/blockedUsers/uid_them").set({ blockedAt: new Date() })
    );
  });

  it("未サインインは書き込めない", async () => {
    const anon = testEnv.unauthenticatedContext();
    await assertFails(
      anon.firestore().doc("users/uid_me/blockedUsers/uid_them").set({ blockedAt: new Date() })
    );
  });
});

describe("messageReports（通報。作成のみ許可、閲覧・更新・削除はクライアントから一切不可）", () => {
  it("reporterUidが自分のuidと一致していれば作成できる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().collection("messageReports").add({
        reporterUid: "uid_me",
        reportedUid: "uid_them",
        context: "post",
        contextId: "group1",
        messageId: "post1",
        messageText: "spam",
        reason: "スパム・宣伝",
        createdAt: new Date()
      })
    );
  });

  it("reporterUidを他人になりすまして作成することはできない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("messageReports").add({
        reporterUid: "uid_someone_else",
        reportedUid: "uid_them",
        context: "post",
        contextId: "group1",
        messageId: "post1",
        messageText: "spam",
        reason: "スパム・宣伝",
        createdAt: new Date()
      })
    );
  });

  it("作成した本人でも読み返すことはできない（閲覧は常に不可）", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    // セキュリティルールを一時的にバイパスして直接データを仕込む
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection("messageReports").doc("report1").set({
        reporterUid: "uid_me",
        reportedUid: "uid_them",
        context: "post",
        contextId: "group1",
        messageId: "post1",
        messageText: "spam",
        reason: "スパム・宣伝",
        createdAt: new Date()
      });
    });
    await assertFails(me.firestore().collection("messageReports").doc("report1").get());
  });
});

describe("pushTriggers（プッシュ通知の配信トリガー）", () => {
  it("senderUidが自分で、topicがuser_{uid}形式なら作成できる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().collection("pushTriggers").add({
        senderUid: "uid_me",
        topic: "user_uid_them",
        notification: { title: "テスト", body: "本文" }
      })
    );
  });

  it("他人のsenderUidを名乗って作成することはできない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add({
        senderUid: "uid_someone_else",
        topic: "user_uid_them",
        notification: { title: "テスト", body: "本文" }
      })
    );
  });

  it("topicが'user_'形式でなければ作成できない（生のデバイストークン等を直接指定させない）", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add({
        senderUid: "uid_me",
        topic: "raw_device_token_abc123",
        notification: { title: "テスト", body: "本文" }
      })
    );
  });
});
