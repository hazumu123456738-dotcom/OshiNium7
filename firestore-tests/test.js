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

describe("dmThreads（DM一覧の削除。参加者本人のみ削除できる）", () => {
  async function seedThread(threadId, participants) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc(`dmThreads/${threadId}`).set({
        participants,
        lastMessage: "hello",
        lastMessageAt: new Date(),
        lastSenderUid: participants[0]
      });
    });
  }

  it("参加者本人はスレッドを削除できる", async () => {
    await seedThread("uid_me_uid_them", ["uid_me", "uid_them"]);
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(me.firestore().doc("dmThreads/uid_me_uid_them").delete());
  });

  it("参加者ではない第三者はスレッドを削除できない", async () => {
    await seedThread("uid_me_uid_them", ["uid_me", "uid_them"]);
    const stranger = testEnv.authenticatedContext("uid_stranger");
    await assertFails(stranger.firestore().doc("dmThreads/uid_me_uid_them").delete());
  });

  it("未サインインはスレッドを削除できない", async () => {
    await seedThread("uid_me_uid_them", ["uid_me", "uid_them"]);
    const anon = testEnv.unauthenticatedContext();
    await assertFails(anon.firestore().doc("dmThreads/uid_me_uid_them").delete());
  });
});

describe("pushTriggers（プッシュ通知の配信トリガー。送信者-受信者の実際の関係を種別ごとに検証する）", () => {
  function basePayload(overrides = {}) {
    return {
      senderUid: "uid_me",
      recipientUid: "uid_them",
      topic: "user_uid_them",
      notification: { title: "テスト", body: "本文" },
      data: { type: "follow" },
      ...overrides
    };
  }

  it("follow系（誰でも誰にでも送れる導線）はsenderUid・topicが正しければ作成できる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(me.firestore().collection("pushTriggers").add(basePayload()));
  });

  it("他人のsenderUidを名乗って作成することはできない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add(basePayload({ senderUid: "uid_someone_else" }))
    );
  });

  it("topicがrecipientUidと矛盾する場合は作成できない（生のデバイストークン等を直接指定させない）", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add(basePayload({ topic: "raw_device_token_abc123" }))
    );
  });

  it("タイトルが80文字を超えると作成できない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add(
        basePayload({ notification: { title: "あ".repeat(81), body: "本文" } })
      )
    );
  });

  it("本文が300文字を超えると作成できない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add(
        basePayload({ notification: { title: "テスト", body: "あ".repeat(301) } })
      )
    );
  });

  it("data.typeが無い（未知の種別）場合は作成できない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().collection("pushTriggers").add(basePayload({ data: {} }))
    );
  });

  describe("グループ系（groupChat/group_invite/event_*）：送信者が実際のメンバーであることを要求", () => {
    async function seedMembership(groupId, uid) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`groups/${groupId}/members/${uid}`).set({ uid, role: "member" });
      });
    }

    it("送信者が実際にそのグループのメンバーなら作成できる", async () => {
      await seedMembership("group1", "uid_me");
      const me = testEnv.authenticatedContext("uid_me");
      await assertSucceeds(
        me.firestore().collection("pushTriggers").add(
          basePayload({ data: { type: "groupChat", groupId: "group1" } })
        )
      );
    });

    it("送信者がそのグループのメンバーでなければ作成できない（改造クライアントによる無関係グループへのなりすまし通知を防ぐ）", async () => {
      const me = testEnv.authenticatedContext("uid_me");
      await assertFails(
        me.firestore().collection("pushTriggers").add(
          basePayload({ data: { type: "event_created", groupId: "group1" } })
        )
      );
    });
  });

  describe("dm：送信者と受信者の実際のDMスレッドが存在することを要求", () => {
    async function seedThread(uidA, uidB) {
      const threadId = [uidA, uidB].sort().join("_");
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`dmThreads/${threadId}`).set({
          participants: [uidA, uidB],
          lastMessage: "hi",
          lastMessageAt: new Date(),
          lastSenderUid: uidA
        });
      });
    }

    it("実際のDMスレッドが存在すれば作成できる", async () => {
      await seedThread("uid_me", "uid_them");
      const me = testEnv.authenticatedContext("uid_me");
      await assertSucceeds(
        me.firestore().collection("pushTriggers").add(
          basePayload({ data: { type: "dm", otherUid: "uid_them" } })
        )
      );
    });

    it("DMスレッドが存在しない相手には作成できない（面識のない相手への偽DM通知を防ぐ）", async () => {
      const me = testEnv.authenticatedContext("uid_me");
      await assertFails(
        me.firestore().collection("pushTriggers").add(
          basePayload({ data: { type: "dm", otherUid: "uid_them" } })
        )
      );
    });
  });

  describe("post_like/post_comment：参照postIdの投稿者が本当に受信者と一致することを要求", () => {
    async function seedPost(postId, authorUid) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`posts/${postId}`).set({ authorUid, text: "hello" });
      });
    }

    it("postIdの投稿者が受信者(recipientUid)と一致すれば作成できる", async () => {
      await seedPost("post1", "uid_them");
      const me = testEnv.authenticatedContext("uid_me");
      await assertSucceeds(
        me.firestore().collection("pushTriggers").add(
          basePayload({ data: { type: "post_like", postId: "post1" } })
        )
      );
    });

    it("postIdの投稿者が受信者と一致しなければ作成できない（無関係の第三者宛への偽いいね通知を防ぐ）", async () => {
      await seedPost("post1", "uid_someone_else");
      const me = testEnv.authenticatedContext("uid_me");
      await assertFails(
        me.firestore().collection("pushTriggers").add(
          basePayload({ data: { type: "post_comment", postId: "post1" } })
        )
      );
    });
  });
});

// ★ 2026/08/11：users/{uid}に「isPremiumSubscriberを誰でもtrueに書き換えられる」という
//   重大な脆弱性があった（フィールド制限の無いallow write: if isSelf(uid);）。修正の再発防止として、
//   本人であってもこのフィールドを直接書き込めないことを固定化しておく
describe("users/{uid}（isPremiumSubscriberはクライアントから一切書き込めない）", () => {
  async function seedProfile(uid, extra = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc(`users/${uid}`).set({
        displayName: "テストユーザー",
        points: 100,
        ...extra
      });
    });
  }

  it("新規作成時にisPremiumSubscriberを含めることはできない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("users/uid_me").set({
        displayName: "新規ユーザー",
        isPremiumSubscriber: true
      })
    );
  });

  it("新規作成時に安全なプロフィール項目のみなら作成できる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me").set({
        displayName: "新規ユーザー",
        bio: "はじめまして"
      })
    );
  });

  it("本人でもisPremiumSubscriberだけを更新することはできない", async () => {
    await seedProfile("uid_me");
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("users/uid_me").set({ isPremiumSubscriber: true }, { merge: true })
    );
  });

  it("displayNameの更新にisPremiumSubscriberを紛れ込ませることもできない", async () => {
    await seedProfile("uid_me");
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("users/uid_me").set(
        { displayName: "改名後", isPremiumSubscriber: true },
        { merge: true }
      )
    );
  });

  it("安全なプロフィール項目（displayName等）だけの更新は引き続きできる", async () => {
    await seedProfile("uid_me");
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me").set({ displayName: "改名後" }, { merge: true })
    );
  });

  it("pointsは1回あたり500ptを超える増加はできない", async () => {
    await seedProfile("uid_me", { points: 100 });
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("users/uid_me").set({ points: 700 }, { merge: true })
    );
  });

  it("pointsの500pt以内の増加は許可される", async () => {
    await seedProfile("uid_me", { points: 100 });
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me").set({ points: 500 }, { merge: true })
    );
  });
});

describe("fortuneLog（推し活占いのポイント付与済みログ。作成のみ・削除不可）", () => {
  it("本人は今日ぶんを新規作成できる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me/fortuneLog/2026-08-11").set({ points: 3 })
    );
  });

  it("他人のfortuneLogには書き込めない", async () => {
    const other = testEnv.authenticatedContext("uid_other");
    await assertFails(
      other.firestore().doc("users/uid_me/fortuneLog/2026-08-11").set({ points: 3 })
    );
  });

  it("本人であっても、一度作成した記録を削除して1日分の制限をすり抜けることはできない", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/uid_me/fortuneLog/2026-08-11").set({ points: 3 });
    });
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(me.firestore().doc("users/uid_me/fortuneLog/2026-08-11").delete());
  });

  it("本人であっても、一度作成した記録を上書き更新することはできない", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/uid_me/fortuneLog/2026-08-11").set({ points: 3 });
    });
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("users/uid_me/fortuneLog/2026-08-11").set({ points: 999 }, { merge: true })
    );
  });
});

describe("customThemes（着せ替え。本人だけが読み書きできる）", () => {
  it("本人は自分のcustomThemesを書き込める", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me/customThemes/theme1").set({ name: "自作テーマ" })
    );
  });

  it("他人のcustomThemesには書き込めない", async () => {
    const other = testEnv.authenticatedContext("uid_other");
    await assertFails(
      other.firestore().doc("users/uid_me/customThemes/theme1").set({ name: "自作テーマ" })
    );
  });

  it("他人のcustomThemesは読み取ることもできない", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/uid_me/customThemes/theme1").set({ name: "自作テーマ" });
    });
    const other = testEnv.authenticatedContext("uid_other");
    await assertFails(other.firestore().doc("users/uid_me/customThemes/theme1").get());
  });
});

describe("storeKitAccountTokens（appAccountToken → uid の対応表。クライアントからは読み取り不可）", () => {
  it("自分のuidを値にした新規登録はできる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("storeKitAccountTokens/token-abc").set({ uid: "uid_me" })
    );
  });

  it("他人のuidを値にした登録はできない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("storeKitAccountTokens/token-abc").set({ uid: "uid_other" })
    );
  });

  it("本人であっても読み取ることはできない（Cloud Functionsだけが読む）", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("storeKitAccountTokens/token-abc").set({ uid: "uid_me" });
    });
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(me.firestore().doc("storeKitAccountTokens/token-abc").get());
  });

  it("他人が登録した自分名義のトークンを、別人が横取り更新することはできない", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("storeKitAccountTokens/token-abc").set({ uid: "uid_me" });
    });
    const stranger = testEnv.authenticatedContext("uid_stranger");
    await assertFails(
      stranger.firestore().doc("storeKitAccountTokens/token-abc").set({ uid: "uid_stranger" }, { merge: true })
    );
  });
});

describe("followRequests（非公開アカウントへのフォローリクエスト）", () => {
  it("fromUidが自分自身なら作成できる", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("followRequests/uid_me_uid_them").set({
        fromUid: "uid_me",
        toUid: "uid_them",
        createdAt: new Date()
      })
    );
  });

  it("他人になりすましてfromUidを名乗ることはできない", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("followRequests/uid_someone_uid_them").set({
        fromUid: "uid_someone_else",
        toUid: "uid_them",
        createdAt: new Date()
      })
    );
  });

  it("送った本人・受け取った本人以外は読み取れない", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("followRequests/uid_me_uid_them").set({
        fromUid: "uid_me", toUid: "uid_them", createdAt: new Date()
      });
    });
    const stranger = testEnv.authenticatedContext("uid_stranger");
    await assertFails(stranger.firestore().doc("followRequests/uid_me_uid_them").get());
  });

  it("受け取った本人（toUid）は承認/拒否のためリクエストを削除できる", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("followRequests/uid_me_uid_them").set({
        fromUid: "uid_me", toUid: "uid_them", createdAt: new Date()
      });
    });
    const them = testEnv.authenticatedContext("uid_them");
    await assertSucceeds(them.firestore().doc("followRequests/uid_me_uid_them").delete());
  });
});

// ★ events.approvedBy/dismissedByの複雑な組み合わせルール（2026/08/11追加）を固定化する。
//   このルールは「自分のuidを1件だけ足す／外す」という差分の形を厳密にチェックしており、
//   実装ミスが起きやすい箇所
describe("events（承認待ち一覧の「削除」／カレンダー本体からの「削除」）", () => {
  async function seedEvent(eventId, extra = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`groups/group1/members/uid_me`).set({ role: "member" });
      await db.doc(`groups/group1/members/uid_them`).set({ role: "member" });
      await db.doc(`events/${eventId}`).set({
        title: "テストイベント",
        date: new Date(),
        isSecret: false,
        groupId: "group1",
        creatorUid: "uid_them",
        approvedBy: ["uid_them"],
        ...extra
      });
    });
  }

  it("dismissedByに自分のuidを足すだけの更新はできる（承認待ち一覧の「削除」）", async () => {
    await seedEvent("event1");
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("events/event1").set({ dismissedBy: ["uid_me"] }, { merge: true })
    );
  });

  it("dismissedByに他人のuidを紛れ込ませることはできない", async () => {
    await seedEvent("event1");
    const me = testEnv.authenticatedContext("uid_me");
    await assertFails(
      me.firestore().doc("events/event1").set({ dismissedBy: ["uid_them"] }, { merge: true })
    );
  });

  it("approvedByから自分のuidを外しdismissedByに足す更新はできる（カレンダー本体からの「削除」）", async () => {
    await seedEvent("event2", { approvedBy: ["uid_them", "uid_me"] });
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("events/event2").set(
        { approvedBy: ["uid_them"], dismissedBy: ["uid_me"] },
        { merge: true }
      )
    );
  });

  it("approvedByから他人のuidを外すことはできない（自分のuidしか外せない）", async () => {
    await seedEvent("event3", { approvedBy: ["uid_them", "uid_me"] });
    const me = testEnv.authenticatedContext("uid_me");
    // uid_meが自分は残したまま、uid_themだけをapprovedByから外そうとする不正な更新
    await assertFails(
      me.firestore().doc("events/event3").set(
        { approvedBy: ["uid_me"], dismissedBy: ["uid_me"] },
        { merge: true }
      )
    );
  });
});

describe("approvalLog（承認待ち一覧の「承認済み」を10日間積み重ね表示するための記録）", () => {
  it("本人は自分のapprovalLogに書き込める", async () => {
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(
      me.firestore().doc("users/uid_me/approvalLog/event1").set({
        approvedAt: new Date(),
        groupId: "group1"
      })
    );
  });

  it("本人は自分のapprovalLogを読める", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/uid_me/approvalLog/event1").set({
        approvedAt: new Date(),
        groupId: "group1"
      });
    });
    const me = testEnv.authenticatedContext("uid_me");
    await assertSucceeds(me.firestore().doc("users/uid_me/approvalLog/event1").get());
  });

  it("他人のapprovalLogには書き込めない", async () => {
    const other = testEnv.authenticatedContext("uid_other");
    await assertFails(
      other.firestore().doc("users/uid_me/approvalLog/event1").set({
        approvedAt: new Date(),
        groupId: "group1"
      })
    );
  });

  it("他人のapprovalLogは読めない", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc("users/uid_me/approvalLog/event1").set({
        approvedAt: new Date(),
        groupId: "group1"
      });
    });
    const other = testEnv.authenticatedContext("uid_other");
    await assertFails(other.firestore().doc("users/uid_me/approvalLog/event1").get());
  });
});
