//
//  GroupViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// ★ グループ新規作成時に「同じグループがすでに存在するか」を表すエラー。
//   既存グループを呼び出し元に渡せるようにし、UI側で「参加する」導線を出せるようにする。
enum GroupCreationError: LocalizedError {
    case duplicate(existing: IdolGroup)
    case notSignedIn
    case notFound
    case groupLimitReached(limit: Int)
    case leaveCooldownActive(daysRemaining: Int)
    case privateChatCreateLimitReached(limit: Int)
    case privateChatJoinLimitReached(limit: Int)

    var errorDescription: String? {
        switch self {
        case .duplicate(let existing):
            return "「\(existing.name)」はすでに登録されています"
        case .notSignedIn:
            return "ログインが必要です"
        case .notFound:
            return "招待リンクのグループが見つかりませんでした"
        case .groupLimitReached(let limit):
            return "推しグループは\(limit)件まで登録できます。もっと登録するにはプレミアムにアップグレードしてください。"
        case .leaveCooldownActive(let daysRemaining):
            return "グループを退出した直後のため、新しい推しグループへの参加まであと\(daysRemaining)日お待ちください。プレミアムならすぐに参加できます。"
        case .privateChatCreateLimitReached(let limit):
            if limit == 0 {
                return "グループチャットの作成はプレミアム会員限定の機能です。プレミアムなら3件まで作成できます。"
            }
            return "作成できるグループチャットは\(limit)件までです。既存のグループチャットを退出してから作り直してください。"
        case .privateChatJoinLimitReached(let limit):
            if !SubscriptionManager.shared.isPremium {
                return "参加できるグループチャットは\(limit)件までです。プレミアムなら3件まで参加できます。"
            }
            return "参加できるグループチャットは\(limit)件までです。既存のグループチャットを退出してから参加してください。"
        }
    }
}

final class GroupViewModel: ObservableObject {

    @Published var groups: [IdolGroup] = []
    // ★ 起動直後、グループ選択画面を出すべきか(=本当に0件か)を判断するために、
    //   Firestoreからの初回応答が届いたかどうかを別途持つ。groups.isEmptyだけでは
    //   「まだ読み込み中で空」なのか「本当に0件」なのか区別できないため
    @Published var hasLoadedGroupsOnce = false
    // ★ このリスナーはアプリ起動直後のルート画面分岐(hasLoadedGroupsOnceで
    //   ローディング/グループ選択/タブ画面を切り替える)を左右する最重要リスナー。
    //   以前はエラー時にprintするだけでhasLoadedGroupsOnceをtrueにしていなかったため、
    //   権限エラー等が起きるとローディング画面のまま永久にフリーズしていた。
    //   エラー時もhasLoadedGroupsOnceはtrueにして先へ進めつつ、この文言でユーザーに
    //   状況を伝え、再試行できるようにする
    @Published var loadErrorMessage: String?

    // ★ 全ユーザー共通のグループカタログ（/groups）。検索・新規参加画面で使用。
    @Published var catalog: [IdolGroup] = []
    @Published var isLoadingCatalog = false

    // グループメンバー一覧（個人カレンダーの招待選択などに使用）
    @Published var members: [GroupMember] = []
    // ★ fetchMembers()のリスナーがエラーになった時に画面側で伝えられるようにする。
    //   以前はprintするだけで、権限エラー等が起きるとメンバー一覧が理由も分からず
    //   空のまま表示されていた
    @Published var membersLoadErrorMessage: String?

    // ★ fetchMembers(for:)と同時に、そのグループの本来の作成者uidを/groups/{id}から
    //   直接取得しておく。ユーザー個別のselectedGroupsミラーはcreatedByUidを持たない
    //   古いデータのことがあるため、権限の自己修復にはこちらを正とする
    @Published private(set) var currentGroupCreatorUid: String?

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    init() {}

    deinit {
        listener?.remove()
        membersListener?.remove()
    }

    // ★ 推しグループの上限(SubscriptionManager.groupLimit)は「招待制グループチャット」
    //   (isPrivate)を数に入れない。招待制グループチャットの作成・参加は別枠の
    //   固定上限(SubscriptionManager.shared.privateChatCreateLimit/JoinLimit)で管理する
    private var myUid: String? { Auth.auth().currentUser?.uid }

    // ★ 実際のカウントロジックはGroupCounting(純粋関数・XCTestあり)に集約している
    private var oshiGroupCount: Int {
        GroupCounting.oshiGroupCount(in: groups)
    }

    // ★ 無料会員が「退出→即別の推しグループに参加」を繰り返すことで、同時登録数の上限(2件)を
    //   実質無視して生涯では無制限にグループを渡り歩けてしまう抜け道への対策。
    //   1回目の退出は無罰（すぐ別のグループに参加できる）だが、2回目以降の退出後は
    //   一定期間、新しい推しグループへの参加をブロックする。プレミアム会員は上限自体が
    //   緩く、この抜け道で得られる実質的な利得が無いため対象外
    private static let leaveCooldownDays = 7

    private func leaveCooldownDaysRemaining(uid: String) async -> Int? {
        guard !SubscriptionManager.shared.isPremium else { return nil }
        guard let snapshot = try? await db.collection("users").document(uid).getDocument(),
              let data = snapshot.data(),
              let leaveCount = data["groupLeaveCount"] as? Int, leaveCount >= 2,
              let lastLeaveTimestamp = data["lastGroupLeaveAt"] as? Timestamp,
              let cooldownEnd = Calendar.current.date(byAdding: .day, value: Self.leaveCooldownDays, to: lastLeaveTimestamp.dateValue())
        else { return nil }

        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: cooldownEnd).day ?? 0
        return remaining > 0 ? remaining : nil
    }

    private var myOwnedPrivateChatCount: Int {
        GroupCounting.ownedPrivateChatCount(in: groups, myUid: myUid)
    }

    private var myJoinedPrivateChatCount: Int {
        GroupCounting.joinedPrivateChatCount(in: groups, myUid: myUid)
    }

    // MARK: - 名前正規化（重複防止の核）
    func normalizeName(_ name: String) -> String {
        var text = name.lowercased()

        // 全角 → 半角
        text = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text

        // カタカナ → ひらがな
        text = text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text

        // 記号・スペース削除
        text = text.replacingOccurrences(
            of: "[^a-zA-Z0-9ぁ-ん一-龥]",
            with: "",
            options: .regularExpression
        )

        return text
    }

    // MARK: - Firestoreドキュメント → IdolGroup デコード（各所で共通化）
    private func decodeIdolGroup(id: String, data: [String: Any]) -> IdolGroup {
        let name = data["name"] as? String ?? "Unknown"

        var imageData: Data? = nil
        if let raw = data["imageData"] as? Data {
            imageData = raw
        } else if let base64 = data["imageData"] as? String {
            imageData = Data(base64Encoded: base64)
        }

        var createdAtDate: Date? = nil
        if let ts = data["createdAt"] as? Timestamp {
            createdAtDate = ts.dateValue()
        }

        return IdolGroup(
            id: id,
            name: name,
            imageData: (imageData?.isEmpty == true) ? nil : imageData,
            reading: data["reading"] as? String,
            fandom: data["fandom"] as? String,
            concept: data["concept"] as? String,
            history: data["history"] as? String,
            groupDescription: data["groupDescription"] as? String,
            createdAt: createdAtDate,
            createdByUid: data["createdByUid"] as? String,
            isPrivate: data["isPrivate"] as? Bool ?? false,
            category: (data["category"] as? String).flatMap(GroupCategory.init(rawValue:))
        )
    }

    // MARK: - グループ新規作成（全ユーザー共通カタログ /groups）
    //   同名グループ（正規化して比較）がすでに存在する場合は作成せず、
    //   既存グループを持たせたエラーを投げる。呼び出し元はそれを使って
    //   「参加する」導線を出す（＝「アプリ全体の決まり事」としての重複禁止）。
    func createGroup(name: String, imageData: Data?, category: GroupCategory) async throws -> IdolGroup {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupCreationError.notSignedIn
        }

        // ★ グループ本体（公開カタログ）を作ってしまってから上限で弾かれると、
        //   誰も参加していない孤児グループが残ってしまう。必ず先にチェックする
        let limit = SubscriptionManager.shared.groupLimit
        if oshiGroupCount >= limit {
            throw GroupCreationError.groupLimitReached(limit: limit)
        }
        if let daysRemaining = await leaveCooldownDaysRemaining(uid: uid) {
            throw GroupCreationError.leaveCooldownActive(daysRemaining: daysRemaining)
        }

        let normalized = normalizeName(name)

        // ★ firestore.rulesのgroups.listはisPrivate==falseの絞り込みが無いと
        //   クエリ全体を拒否するため、必ずisPrivateも組み合わせてクエリする
        let snapshot = try await db.collection("groups")
            .whereField("normalizedName", isEqualTo: normalized)
            .whereField("isPrivate", isEqualTo: false)
            .getDocuments()

        if let existingDoc = snapshot.documents.first {
            let existing = decodeIdolGroup(id: existingDoc.documentID, data: existingDoc.data())
            throw GroupCreationError.duplicate(existing: existing)
        }

        let id = UUID().uuidString
        let createdAt = Date()

        let data: [String: Any] = [
            "id": id,
            "name": name,
            "normalizedName": normalized,
            "imageData": imageData ?? Data(),
            "createdAt": Timestamp(date: createdAt),
            "createdByUid": uid,
            // ★ isPrivateを必ず明示的に書き込む。loadCatalog()のクエリがisPrivate==falseで
            //   絞り込むため、フィールド自体が無いドキュメントはlistクエリの対象から漏れてしまう
            "isPrivate": false,
            "category": category.rawValue
        ]

        try await db.collection("groups").document(id).setData(data)

        let newGroup = IdolGroup(
            id: id,
            name: name,
            imageData: imageData,
            reading: nil,
            fandom: nil,
            concept: nil,
            history: nil,
            groupDescription: nil,
            createdAt: createdAt,
            createdByUid: uid,
            category: category
        )

        // 作成者自身も自動的に参加済みにし、オーナー権限を与える
        addGroup(newGroup, role: .owner)

        return newGroup
    }

    // MARK: - 招待制グループチャットの作成
    //   ★ 通常のグループ（推し活の対象そのもの）とは違い、「友だち同士のグループチャット」用。
    //     公開カタログには載せず、同名重複チェックも行わない（Discordの招待リンクと同じ考え方で、
    //     招待リンク＝招待コードを知っている人だけが参加できる）。
    //     チャット画面・コミュニティカレンダーの自動作成の仕組みは通常のグループとまるごと共用する。
    func createPrivateGroup(name: String, imageData: Data?) async throws -> IdolGroup {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw GroupCreationError.notSignedIn
        }

        // ★ 無課金/プレミアムで差を付けない固定上限（荒らし・スパム防止目的）。
        //   推しグループの上限とは完全に別枠でチェックする
        let createLimit = SubscriptionManager.shared.privateChatCreateLimit
        if myOwnedPrivateChatCount >= createLimit {
            throw GroupCreationError.privateChatCreateLimitReached(limit: createLimit)
        }

        let id = UUID().uuidString
        let createdAt = Date()

        let data: [String: Any] = [
            "id": id,
            "name": name,
            "imageData": imageData ?? Data(),
            "createdAt": Timestamp(date: createdAt),
            "createdByUid": uid,
            "isPrivate": true
        ]

        try await db.collection("groups").document(id).setData(data)

        let newGroup = IdolGroup(
            id: id,
            name: name,
            imageData: imageData,
            createdAt: createdAt,
            createdByUid: uid,
            isPrivate: true
        )

        // 作成者自身も自動的に参加済みにし、オーナー権限を与える
        addGroup(newGroup, role: .owner)

        return newGroup
    }

    // MARK: - 招待リンク（oshinium://join?group=<id>）経由での参加
    //   ★ 招待制グループは公開カタログに出ないため、招待リンクに含まれるIDから
    //     直接/groups/{id}を取得して参加する。作成者以外は"member"として参加する
    func joinGroup(byId groupId: String, completion: @escaping (Result<IdolGroup, Error>) -> Void) {
        guard Auth.auth().currentUser?.uid != nil else {
            completion(.failure(GroupCreationError.notSignedIn))
            return
        }

        db.collection("groups").document(groupId).getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(), snapshot?.exists == true else {
                completion(.failure(GroupCreationError.notFound))
                return
            }

            let group = self.decodeIdolGroup(id: groupId, data: data)

            // ★ 招待制グループチャット(isPrivate)への新規参加(=自分が作成者ではない)だけ、
            //   別枠の固定上限をチェックする。既にメンバーの場合(再アクセス)や、自分の
            //   グループへの再参加は対象外
            if group.isPrivate,
               group.createdByUid != Auth.auth().currentUser?.uid,
               !self.groups.contains(where: { $0.id == group.id }) {
                let joinLimit = SubscriptionManager.shared.privateChatJoinLimit
                if self.myJoinedPrivateChatCount >= joinLimit {
                    completion(.failure(GroupCreationError.privateChatJoinLimitReached(limit: joinLimit)))
                    return
                }
            }

            self.addGroup(group, role: .member) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(group))
                }
            }
        }
    }

    // MARK: - グループカタログの取得（検索・新規参加画面用）
    func loadCatalog(completion: (() -> Void)? = nil) {
        isLoadingCatalog = true

        // ★ 招待制グループ（isPrivate）はカタログに絶対に出さない。firestore.rulesの
        //   list権限もisPrivate==falseを要求しているため、このwhereFieldを外すと
        //   クエリ自体がまるごと権限エラーになる（部分的に返る、ということはない）
        db.collection("groups")
            .whereField("isPrivate", isEqualTo: false)
            .order(by: "name")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("DEBUG loadCatalog error:", error)
                    DispatchQueue.main.async {
                        self.isLoadingCatalog = false
                        completion?()
                    }
                    return
                }

                let docs = snapshot?.documents ?? []
                let loaded = docs.map { self.decodeIdolGroup(id: $0.documentID, data: $0.data()) }

                DispatchQueue.main.async {
                    self.catalog = loaded
                    self.isLoadingCatalog = false
                    completion?()
                }
            }
    }

    // MARK: - 自分がすでに参加しているグループを、共通カタログにも反映する
    //   （このカタログ機構ができる前に作成されたグループ／過去データの自己修復。
    //     これにより「以前作ったグループが選択画面に出てこない」問題を解消する）
    private func backfillCatalogIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        for group in groups {
            let ref = db.collection("groups").document(group.id)
            ref.getDocument { snapshot, _ in
                guard snapshot?.exists != true else { return }

                var data: [String: Any] = [
                    "id": group.id,
                    "name": group.name,
                    "normalizedName": self.normalizeName(group.name),
                    "createdAt": Timestamp(date: group.createdAt ?? Date()),
                    "createdByUid": uid,
                    // ★ createGroup()と同じ理由でisPrivateを必ず明示する
                    "isPrivate": group.isPrivate
                ]
                if let reading = group.reading { data["reading"] = reading }
                if let fandom = group.fandom { data["fandom"] = fandom }
                if let concept = group.concept { data["concept"] = concept }
                if let history = group.history { data["history"] = history }
                if let groupDescription = group.groupDescription { data["groupDescription"] = groupDescription }
                if let imageData = group.imageData { data["imageData"] = imageData }

                ref.setData(data, merge: true) { error in
                    if let error = error {
                        print("DEBUG backfillCatalogIfNeeded error:", error)
                    }
                }
            }
        }
    }

    // MARK: - Firestore リアルタイム取得（ユーザーの selectedGroups）
    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("DEBUG GroupViewModel: uid nil")
            return
        }

        listener?.remove()

        listener = db.collection("users")
            .document(uid)
            .collection("selectedGroups")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in

                guard let self = self else { return }

                if let error = error {
                    print("DEBUG GroupViewModel listener error:", error)
                    DispatchQueue.main.async {
                        self.hasLoadedGroupsOnce = true
                        self.loadErrorMessage = "グループの読み込みに失敗しました。通信状態を確認してもう一度お試しください。"
                    }
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.groups = []
                        self.hasLoadedGroupsOnce = true
                        self.loadErrorMessage = nil
                    }
                    return
                }

                let loaded = docs.map { self.decodeIdolGroup(id: $0.documentID, data: $0.data()) }

                DispatchQueue.main.async {
                    self.groups = loaded
                    self.hasLoadedGroupsOnce = true
                    self.loadErrorMessage = nil
                    print("DEBUG Firestore groups updated:", self.groups.map { $0.name })
                    self.backfillCatalogIfNeeded()
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        groups = []
        hasLoadedGroupsOnce = false
        loadErrorMessage = nil
    }

    // MARK: - Firestore 単発取得
    func fetchGroupsOnce(completion: (([IdolGroup]) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?([])
            return
        }

        db.collection("users")
            .document(uid)
            .collection("selectedGroups")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in

                if let error = error {
                    print("DEBUG fetchGroupsOnce error:", error)
                    completion?([])
                    return
                }

                guard let docs = snapshot?.documents else {
                    completion?([])
                    return
                }

                let loaded = docs.map { self.decodeIdolGroup(id: $0.documentID, data: $0.data()) }
                completion?(loaded)
            }
    }

    // MARK: - Firestore 追加（ユーザーの selectedGroups に追加）
    //   ★ roleは新規参加時のみ使う「初期値の希望」。既にメンバーとして存在する場合は
    //     mirrorMembership側で既存のroleを上書きしないようガードする
    func addGroup(_ group: IdolGroup, role: GroupRole = .member, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // ★ 新規に1件追加する場合だけ上限・クールダウンをチェックする（既存グループの情報更新
        //   目的の再書き込みは対象外）。招待制グループチャット(isPrivate)はこの上限には含めない
        //   （createPrivateGroup/joinGroup(byId:)側で別枠の上限を先にチェック済みのため）
        let isNewJoin = !group.isPrivate && !groups.contains(where: { $0.id == group.id })

        func writeGroup() {
            let docRef = db.collection("users")
                .document(uid)
                .collection("selectedGroups")
                .document(group.id)

            var data: [String: Any] = [
                "name": group.name,
                "reading": group.reading as Any,
                "fandom": group.fandom as Any,
                "concept": group.concept as Any,
                "history": group.history as Any,
                "groupDescription": group.groupDescription as Any,
                "createdAt": Timestamp(date: group.createdAt ?? Date()),
                "createdByUid": group.createdByUid as Any,
                "isPrivate": group.isPrivate,
                "category": group.category?.rawValue as Any
            ]

            if let imageData = group.imageData {
                data["imageData"] = imageData
            }

            docRef.setData(data) { [weak self] error in
                if let error = error {
                    print("DEBUG addGroup error:", error)
                    completion?(error)
                } else {
                    print("DEBUG addGroup success:", group.name)
                    self?.mirrorMembership(groupId: group.id, uid: uid, defaultRole: role)
                    completion?(nil)
                }
            }
        }

        guard isNewJoin else {
            writeGroup()
            return
        }

        let limit = SubscriptionManager.shared.groupLimit
        if oshiGroupCount >= limit {
            completion?(GroupCreationError.groupLimitReached(limit: limit))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            if let daysRemaining = await self.leaveCooldownDaysRemaining(uid: uid) {
                await MainActor.run {
                    completion?(GroupCreationError.leaveCooldownActive(daysRemaining: daysRemaining))
                }
                return
            }
            await MainActor.run {
                writeGroup()
            }
        }
    }

    // MARK: - グループメンバー一覧のミラー（招待選択用）
    //   ★ 既にrole付きのメンバードキュメントが存在する場合はroleフィールドを一切送らない。
    //     setData(merge:true)であっても、キーを含めてしまうとその値で上書きされてしまうため、
    //     「初回参加時だけroleを設定する」ことを保証するには事前読み取りが必要
    private func mirrorMembership(groupId: String, uid: String, defaultRole: GroupRole = .member) {
        let memberRef = db.collection("groups").document(groupId).collection("members").document(uid)

        memberRef.getDocument { existingSnapshot, _ in
            let alreadyHasRole = existingSnapshot?.data()?["role"] != nil
            // ★ コミュニティチャットへの「参加しました」お知らせは、本当に初めて参加した
            //   瞬間だけ出したい。alreadyHasRoleは「role未設定の古いデータ」でも偽になりうるため
            //   それとは別に、ドキュメント自体が存在しなかったか（＝本当に初参加か）で判定する
            let isNewJoin = existingSnapshot?.exists != true

            self.db.collection("users").document(uid).getDocument { snapshot, _ in
                let data = snapshot?.data()
                let displayName = data?["displayName"] as? String ?? "名無しさん"
                let iconURL = data?["iconURL"] as? String

                var memberData: [String: Any] = [
                    "uid": uid,
                    "displayName": displayName,
                    "joinedAt": Timestamp(date: Date())
                ]
                if let iconURL { memberData["iconURL"] = iconURL }
                if !alreadyHasRole { memberData["role"] = defaultRole.rawValue }

                memberRef.setData(memberData, merge: true) { error in
                    if let error = error {
                        print("DEBUG mirrorMembership error:", error)
                    } else if isNewJoin {
                        ChatViewModel.postSystemMessage(
                            groupId: groupId,
                            text: "🎉 \(displayName)さんがコミュニティに参加しました"
                        )
                    }
                }
            }
        }
    }

    private func removeMembership(groupId: String, uid: String) {
        db.collection("groups").document(groupId).collection("members").document(uid).delete { error in
            if let error = error {
                print("DEBUG removeMembership error:", error)
            }
        }
    }

    // ★ 退出クールダウン([[leaveCooldownDaysRemaining]])のための記録。groupLeaveCountが
    //   2以上になった時点から、lastGroupLeaveAtを起点にクールダウンが発生する（=1回目の
    //   退出は無罰）
    private func recordGroupLeave(uid: String) {
        db.collection("users").document(uid).setData([
            "groupLeaveCount": FieldValue.increment(Int64(1)),
            "lastGroupLeaveAt": Timestamp(date: Date())
        ], merge: true) { error in
            if let error = error {
                print("DEBUG recordGroupLeave error:", error)
            }
        }
    }

    // MARK: - 参加人数だけを軽量に取得（グループ選択画面のカード表示用）
    //   ★ 一覧購読(fetchMembers)は選択中の1グループにしか使わないが、こちらはカタログの
    //     カードを開くたびに何件も呼ばれうるため、全ドキュメントを読まずに件数だけ取れる
    //     Firestoreのcount()集計クエリを使う（読み取り件数・帯域を抑える）
    func fetchMemberCount(groupId: String, completion: @escaping (Int) -> Void) {
        db.collection("groups").document(groupId).collection("members")
            .count
            .getAggregation(source: .server) { snapshot, error in
                if let error {
                    print("DEBUG fetchMemberCount error:", error)
                    completion(0)
                    return
                }
                completion(snapshot?.count.intValue ?? 0)
            }
    }

    // MARK: - グループメンバー一覧の購読

    func fetchMembers(for groupId: String) {
        membersListener?.remove()
        currentGroupCreatorUid = nil

        db.collection("groups").document(groupId).getDocument { [weak self] snapshot, _ in
            DispatchQueue.main.async {
                self?.currentGroupCreatorUid = snapshot?.data()?["createdByUid"] as? String
                self?.healOwnerRoleIfNeeded(groupId: groupId)
            }
        }

        membersListener = db.collection("groups").document(groupId).collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("DEBUG fetchMembers error:", error)
                    DispatchQueue.main.async {
                        self.membersLoadErrorMessage = "メンバー一覧の読み込みに失敗しました。通信状態を確認してもう一度お試しください。"
                    }
                    return
                }

                let docs = snapshot?.documents ?? []
                let loaded: [GroupMember] = docs.compactMap { doc in
                    let data = doc.data()
                    guard let uid = data["uid"] as? String else { return nil }
                    let role = (data["role"] as? String).flatMap(GroupRole.init(rawValue:))
                    return GroupMember(
                        uid: uid,
                        displayName: data["displayName"] as? String ?? "名無しさん",
                        iconURL: data["iconURL"] as? String,
                        joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue(),
                        role: role
                    )
                }

                DispatchQueue.main.async {
                    self.members = loaded
                    self.membersLoadErrorMessage = nil
                    self.healOwnerRoleIfNeeded(groupId: groupId)
                }
            }
    }

    // ★ 自己修復：作成者本人のmemberドキュメントにまだroleが無ければ、
    //   ここで"owner"として書き戻す。currentGroupCreatorUid・membersの両方が
    //   揃うたびに呼ばれる（どちらが先に届いても最終的に必ず走る）
    private func healOwnerRoleIfNeeded(groupId: String) {
        guard let creatorUid = currentGroupCreatorUid else { return }
        guard let creatorMember = members.first(where: { $0.uid == creatorUid }) else { return }
        guard creatorMember.role == nil else { return }
        updateMemberRole(groupId: groupId, uid: creatorUid, role: .owner)
    }

    func stopFetchingMembers() {
        membersListener?.remove()
        membersListener = nil
        currentGroupCreatorUid = nil
        membersLoadErrorMessage = nil
    }

    // MARK: - 権限まわり（fetchMembers()で読み込んだ members を前提に使う）

    // ★ 現在ログイン中のユーザーの、このグループでの権限。
    //   memberドキュメントにroleが無い旧データでも、グループの作成者本人であれば
    //   オーナーとして扱う（自己修復）。判定結果は次回のmirrorMembership呼び出し時に
    //   自然とFirestoreへも書き戻される。作成者uidはfetchMembers(for:)が取得する
    //   currentGroupCreatorUidを正とする（渡されたIdolGroup.createdByUidは
    //   selectedGroupsミラーの古いデータで欠けていることがあるため頼らない）
    func myRole(in group: IdolGroup) -> GroupRole {
        guard let uid = Auth.auth().currentUser?.uid else { return .member }
        let isCreator = (currentGroupCreatorUid ?? group.createdByUid) == uid

        if let member = members.first(where: { $0.uid == uid }) {
            if let role = member.role { return role }
            return isCreator ? .owner : .member
        }
        return isCreator ? .owner : .member
    }

    // ★ 権限変更（オーナーのみが実行できる想定。呼び出し側でmyRole(in:)==.ownerを確認すること）
    func updateMemberRole(groupId: String, uid: String, role: GroupRole, completion: ((Error?) -> Void)? = nil) {
        db.collection("groups").document(groupId).collection("members").document(uid)
            .setData(["role": role.rawValue], merge: true) { error in
                if let error { print("DEBUG updateMemberRole error:", error) }
                completion?(error)
            }
    }

    // ★ メンバーの強制退出（オーナー・管理者のみが実行できる想定）。
    //   membersミラーの削除に加えて、本人のselectedGroups側も削除して
    //   「そのユーザーの一覧からもグループが消える」ところまで行う
    func removeMember(groupId: String, uid: String, completion: ((Error?) -> Void)? = nil) {
        let group = db.collection("groups").document(groupId)
        group.collection("members").document(uid).delete { [weak self] error in
            if let error {
                print("DEBUG removeMember error:", error)
                completion?(error)
                return
            }
            self?.db.collection("users").document(uid).collection("selectedGroups").document(groupId).delete { error in
                if let error { print("DEBUG removeMember selectedGroups cleanup error:", error) }
                completion?(nil)
            }
            self?.db.collection("users").document(uid).getDocument { snapshot, _ in
                let displayName = snapshot?.data()?["displayName"] as? String ?? "名無しさん"
                ChatViewModel.postSystemMessage(
                    groupId: groupId,
                    text: "👋 \(displayName)さんが退会しました"
                )
            }
        }
    }

    // MARK: - グループの完全削除（オーナーのみ）
    //   ★ /groups/{id} 本体とmembersサブコレクションを削除する。他メンバー全員の
    //     selectedGroups側までは踏み込まない（他ユーザーの領域への書き込みが広範になりすぎるため）。
    //     そのため他メンバーの一覧には削除後も一覧上残ることがある点は既知の制約として
    //     割り切っている（グループ自体は存在しなくなるため、開いても空状態になる）
    func deleteGroupCompletely(_ group: IdolGroup, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard myRole(in: group) == .owner else {
            completion?(NSError(domain: "OshiNium", code: 403, userInfo: [NSLocalizedDescriptionKey: "オーナーのみが削除できます"]))
            return
        }

        let groupRef = db.collection("groups").document(group.id)
        groupRef.collection("members").getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            let members = snapshot?.documents ?? []
            // ★ 他のメンバーが1人でも参加している場合、オーナーであっても削除させない
            //   （他メンバーのチャット履歴・思い出を本人の知らないところで一方的に消してしまうため）
            if members.contains(where: { $0.documentID != uid }) {
                completion?(NSError(domain: "OshiNium", code: 409, userInfo: [NSLocalizedDescriptionKey: "他のメンバーが参加しているグループは削除できません。先に全員を退出させてから削除してください。"]))
                return
            }
            let batch = self.db.batch()
            for doc in members {
                batch.deleteDocument(doc.reference)
            }
            batch.deleteDocument(groupRef)
            batch.commit { error in
                if let error {
                    print("DEBUG deleteGroupCompletely error:", error)
                    completion?(error)
                    return
                }
                // 自分自身のselectedGroupsからも消す（退出と同じ後始末）
                self.db.collection("users").document(uid).collection("selectedGroups").document(group.id).delete { _ in
                    completion?(nil)
                }
            }
        }
    }

    // MARK: - プロフィール変更を参加中の全グループの members ミラーに同期
    //   （プロフィール保存時に呼ぶ。これをしないと名前・アイコンがグループ参加時点の
    //     ものに固定されたままになり、チャット等の表示が更新されない）
    func syncMemberProfile(displayName: String, iconURL: String?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        var memberData: [String: Any] = ["displayName": displayName]
        if let iconURL, !iconURL.isEmpty {
            memberData["iconURL"] = iconURL
        }

        for group in groups {
            db.collection("groups").document(group.id).collection("members").document(uid)
                .setData(memberData, merge: true) { error in
                    if let error = error {
                        print("🔥 syncMemberProfile error (\(group.id)):", error)
                    }
                }
        }
    }

    // MARK: - Firestore 更新
    func updateGroup(_ group: IdolGroup, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let docRef = db.collection("users")
            .document(uid)
            .collection("selectedGroups")
            .document(group.id)

        var data: [String: Any] = [
            "name": group.name,
            "reading": group.reading as Any,
            "fandom": group.fandom as Any,
            "concept": group.concept as Any,
            "history": group.history as Any,
            "groupDescription": group.groupDescription as Any,
            "category": group.category?.rawValue as Any
        ]

        if let created = group.createdAt {
            data["createdAt"] = Timestamp(date: created)
        }

        if let imageData = group.imageData {
            data["imageData"] = imageData
        }

        // ★ updateData だと対象ドキュメントが未作成の場合に失敗する（addGroup の書き込みと
        //   競合するAI自動入力タイマーなどでレースになりうる）。setData(merge:) なら
        //   ドキュメントの有無に関わらず安全に書き込める。
        docRef.setData(data, merge: true) { error in
            if let error = error {
                print("DEBUG updateGroup error:", error)
                completion?(error)
            } else {
                print("DEBUG updateGroup success:", group.name)
                completion?(nil)
            }
        }

        // ★ カテゴリは「会場口コミ」で他ユーザーのグループとも横断照合するため、
        //   個人ミラー(selectedGroups)だけでなく全ユーザー共通カタログ(/groups)にも反映する
        if let category = group.category {
            db.collection("groups").document(group.id)
                .setData(["category": category.rawValue], merge: true)
        }
    }

    // MARK: - Firestore 削除（退出）
    func deleteGroup(_ group: IdolGroup, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .collection("selectedGroups")
            .document(group.id)
            .delete { [weak self] error in
                if let error = error {
                    print("DEBUG deleteGroup error:", error)
                    completion?(error)
                } else {
                    print("DEBUG deleteGroup success:", group.name)
                    self?.removeMembership(groupId: group.id, uid: uid)
                    self?.db.collection("users").document(uid).getDocument { snapshot, _ in
                        let displayName = snapshot?.data()?["displayName"] as? String ?? "名無しさん"
                        ChatViewModel.postSystemMessage(
                            groupId: group.id,
                            text: "👋 \(displayName)さんが退会しました"
                        )
                    }
                    // ★ 招待制グループチャット(isPrivate)は別枠の上限のため、
                    //   退出クールダウンの対象（推しグループの退出）にはカウントしない
                    if !group.isPrivate {
                        self?.recordGroupLeave(uid: uid)
                    }
                    completion?(nil)
                }
            }
    }

    // MARK: - Firestore 全ユーザーから所属人数を数える
    func fetchMemberCount(for groupId: String, completion: @escaping (Int) -> Void) {

        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("DEBUG fetchMemberCount error:", error)
                completion(0)
                return
            }

            guard let users = snapshot?.documents else {
                completion(0)
                return
            }

            var count = 0
            let dispatch = DispatchGroup()

            for user in users {
                dispatch.enter()

                self.db.collection("users")
                    .document(user.documentID)
                    .collection("selectedGroups")
                    .document(groupId)
                    .getDocument { doc, _ in
                        if doc?.exists == true {
                            count += 1
                        }
                        dispatch.leave()
                    }
            }

            dispatch.notify(queue: .main) {
                completion(count)
            }
        }
    }
}
