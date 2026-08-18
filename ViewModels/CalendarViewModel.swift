//
//  CalendarViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation
import Combine
import FirebaseFirestore

final class CalendarViewModel: ObservableObject {

    @Published var calendars: [OshiCalendar] = []
    // ★ Firestoreクエリのエラー（複合インデックス未作成等）を画面に出せるように公開する
    @Published var lastError: String?

    private let db = Firestore.firestore()
    private var communityListener: ListenerRegistration?
    private var personalListener: ListenerRegistration?

    private var communityCalendars: [OshiCalendar] = []
    private var personalCalendars: [OshiCalendar] = []

    deinit {
        communityListener?.remove()
        personalListener?.remove()
    }

    // MARK: - 購読（コミュニティ＋自分が招待されている個人カレンダー）

    func startListening(groupId: String, groupName: String, currentUid: String) {
        stopListening()

        communityListener = db.collection("calendars")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("isCommunity", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 CalendarViewModel コミュニティ購読エラー:", error)
                    DispatchQueue.main.async {
                        self.lastError = error.localizedDescription
                    }
                    return
                }

                let docs = snapshot?.documents ?? []
                self.communityCalendars = docs.compactMap { Self.decode($0) }
                self.mergeAndPublish()

                if self.communityCalendars.isEmpty {
                    self.createCommunityCalendarIfNeeded(groupId: groupId, groupName: groupName)
                }
            }

        // ★ プライベートカレンダーもコミュニティと同じく「常時存在」を保証する。
        //   グループ・ユーザーごとに1件だけの決め打ちIDにし、無ければ自動生成する
        createPrivateCalendarIfNeeded(groupId: groupId, uid: currentUid)

        // ★ firestore.rulesのcalendars.readは isCommunity==true か memberIds に
        //   自分がいるか、で条件分岐している。listクエリ側でisCommunityを絞り込んでいないと
        //   Firestoreがこのクエリ全体を「安全と証明できない」として権限エラーで拒否してしまう
        //   （groups.listで踏んだのと同種の問題）。isCommunity==falseを明示的に加える
        personalListener = db.collection("calendars")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("isCommunity", isEqualTo: false)
            .whereField("memberIds", arrayContains: currentUid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 CalendarViewModel 個人カレンダー購読エラー:", error)
                    DispatchQueue.main.async {
                        self.lastError = error.localizedDescription
                    }
                    return
                }

                let docs = snapshot?.documents ?? []
                self.personalCalendars = docs.compactMap { Self.decode($0) }.filter { !$0.isCommunity }
                self.mergeAndPublish()
            }
    }

    func stopListening() {
        communityListener?.remove()
        personalListener?.remove()
        communityListener = nil
        personalListener = nil
    }

    private func mergeAndPublish() {
        var dict: [String: OshiCalendar] = [:]
        for calendar in communityCalendars + personalCalendars {
            dict[calendar.id] = calendar
        }

        // コミュニティカレンダーを先頭に、次にプライベートカレンダー、以降は作成日順
        let merged = Array(dict.values).sorted { lhs, rhs in
            if lhs.isCommunity != rhs.isCommunity { return lhs.isCommunity }
            if lhs.isPrivate != rhs.isPrivate { return lhs.isPrivate }
            return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        }

        DispatchQueue.main.async {
            self.calendars = merged
        }
    }

    private static func decode(_ doc: QueryDocumentSnapshot) -> OshiCalendar? {
        let data = doc.data()
        guard let groupId = data["groupId"] as? String,
              let name = data["name"] as? String else { return nil }

        return OshiCalendar(
            id: doc.documentID,
            groupId: groupId,
            name: name,
            isCommunity: data["isCommunity"] as? Bool ?? false,
            isPrivate: data["isPrivate"] as? Bool ?? false,
            ownerId: data["ownerId"] as? String,
            memberIds: data["memberIds"] as? [String] ?? [],
            colorHex: data["colorHex"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    // MARK: - コミュニティカレンダー自動作成（グループにまだ無ければ1件だけ作る）

    private func createCommunityCalendarIfNeeded(groupId: String, groupName: String) {
        let ref = db.collection("calendars").document("\(groupId)_community")

        ref.getDocument { [weak self] snapshot, _ in
            guard self != nil else { return }
            if snapshot?.exists == true { return }

            let data: [String: Any] = [
                "groupId": groupId,
                "name": "\(groupName) コミュニティカレンダー",
                "isCommunity": true,
                "memberIds": [],
                "createdAt": Timestamp(date: Date())
            ]

            ref.setData(data) { error in
                if let error = error {
                    print("🔥 createCommunityCalendarIfNeeded error:", error)
                }
            }
        }
    }

    // MARK: - プライベートカレンダー自動作成（グループ×自分ごとに1件だけ、無ければ作る）
    //   ★ コミュニティと違い誰も招待できない自分だけのカレンダー。memberIdsは常に自分1人だけ

    private func createPrivateCalendarIfNeeded(groupId: String, uid: String) {
        let ref = db.collection("calendars").document("\(groupId)_private_\(uid)")

        ref.getDocument { [weak self] snapshot, _ in
            guard self != nil else { return }
            if snapshot?.exists == true { return }

            let data: [String: Any] = [
                "groupId": groupId,
                "name": "プライベート",
                "isCommunity": false,
                "isPrivate": true,
                "ownerId": uid,
                "memberIds": [uid],
                "createdAt": Timestamp(date: Date())
            ]

            ref.setData(data) { error in
                if let error = error {
                    print("🔥 createPrivateCalendarIfNeeded error:", error)
                }
            }
        }
    }

    // MARK: - 個人カレンダー作成
    //   ★ 自動作成されるコミュニティ・プライベートカレンダー(常時1件ずつ)は上限に含めない。
    //   ここでいう「作成数」は、自分がownerIdになっている追加カレンダー(isCommunity/isPrivateどちらもfalse)の数

    func myPersonalCalendarCount(ownerId: String) -> Int {
        calendars.filter { !$0.isCommunity && !$0.isPrivate && $0.ownerId == ownerId }.count
    }

    func createPersonalCalendar(
        name: String,
        groupId: String,
        ownerId: String,
        memberIds: [String],
        colorHex: String?,
        completion: ((Result<OshiCalendar, Error>) -> Void)? = nil
    ) {
        let limit = SubscriptionManager.shared.calendarCreateLimit
        if myPersonalCalendarCount(ownerId: ownerId) >= limit {
            completion?(.failure(CalendarError.createLimitReached(limit: limit)))
            return
        }

        // ★ 「作り直し」(このグループで過去に個人カレンダーを削除したことがあるかどうか)の
        //   判定は必ず作成の前に行う。削除履歴が無ければ純粋な新規作成として素通りする
        checkRecreateLimit(groupId: groupId, uid: ownerId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion?(.failure(error))
            case .success(let isRecreate):
                self.performCreatePersonalCalendar(
                    name: name, groupId: groupId, ownerId: ownerId,
                    memberIds: memberIds, colorHex: colorHex, isRecreate: isRecreate,
                    completion: completion
                )
            }
        }
    }

    private func performCreatePersonalCalendar(
        name: String,
        groupId: String,
        ownerId: String,
        memberIds: [String],
        colorHex: String?,
        isRecreate: Bool,
        completion: ((Result<OshiCalendar, Error>) -> Void)?
    ) {
        let id = UUID().uuidString
        var allMembers = Set(memberIds)
        allMembers.insert(ownerId)

        var data: [String: Any] = [
            "groupId": groupId,
            "name": name,
            "isCommunity": false,
            "ownerId": ownerId,
            "memberIds": Array(allMembers),
            "createdAt": Timestamp(date: Date())
        ]
        if let colorHex { data["colorHex"] = colorHex }

        // ★ 2026/08/18追加（ユーザー報告：予定保存フリーズと同根）：以前は応答確認に
        //   上限が無く、通信が不安定だと「保存中」のまま無期限に固まって見えていた
        Task { [weak self] in
            let error = await NetworkMonitor.awaitWithTimeout { done in
                self?.db.collection("calendars").document(id).setData(data) { error in done(error) }
            }

            guard let self else { return }

            if let error = error {
                await MainActor.run { completion?(.failure(error)) }
                return
            }

            // ★ 削除履歴があった(=今回は「作り直し」だった)場合だけ、レート制限用の
            //   ログに記録する。純粋な新規作成はカウントしない
            if isRecreate {
                self.logCalendarActivity(uid: ownerId, groupId: groupId, action: "recreate")
            }

            let calendar = OshiCalendar(
                id: id,
                groupId: groupId,
                name: name,
                isCommunity: false,
                ownerId: ownerId,
                memberIds: Array(allMembers),
                colorHex: colorHex,
                createdAt: Date()
            )
            await MainActor.run { completion?(.success(calendar)) }
        }
    }

    // MARK: - 「作り直し」レート制限（削除→再作成のサイクルを10日間で数回までに制限）
    //   ★ users/{uid}/calendarActivityLogに"delete"(削除の度に記録)・"recreate"
    //   (削除履歴がある状態での再作成の度に記録)の2種類のログを残す。"delete"は
    //   「このグループで過去に削除したことがあるか」の判定にだけ使い(無期限に有効)、
    //   実際のレート制限のカウントは10日以内の"recreate"ログの件数で行う

    private func calendarActivityCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("calendarActivityLog")
    }

    private func logCalendarActivity(uid: String, groupId: String, action: String) {
        calendarActivityCollection(uid: uid).addDocument(data: [
            "groupId": groupId,
            "action": action,
            "at": Timestamp(date: Date())
        ]) { error in
            if let error { print("🔥 calendarActivityLog write error:", error) }
        }
    }

    // ★ Result<Bool, Error>のBool = 「今回の作成は作り直しだったか」。
    //   実際の判定ロジック(削除履歴の有無・直近件数の集計)はCalendarRecreatePolicy
    //   (純粋関数・XCTestあり)に委譲し、ここではFirestoreからのデータ取得だけを行う
    private func checkRecreateLimit(groupId: String, uid: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        calendarActivityCollection(uid: uid)
            .whereField("groupId", isEqualTo: groupId)
            .whereField("action", isEqualTo: "delete")
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    completion(.failure(error))
                    return
                }
                let deleteTimestamps = Self.timestamps(from: snapshot)
                guard CalendarRecreatePolicy.isRecreate(deleteTimestamps: deleteTimestamps) else {
                    completion(.success(false))
                    return
                }

                self.calendarActivityCollection(uid: uid)
                    .whereField("groupId", isEqualTo: groupId)
                    .whereField("action", isEqualTo: "recreate")
                    .getDocuments { snapshot, error in
                        if let error {
                            completion(.failure(error))
                            return
                        }
                        let recreateTimestamps = Self.timestamps(from: snapshot)
                        let windowDays = SubscriptionManager.calendarRecreateWindowDays
                        let limit = SubscriptionManager.shared.calendarRecreateLimit

                        let canCreate = CalendarRecreatePolicy.canCreate(
                            deleteTimestamps: deleteTimestamps,
                            recreateTimestamps: recreateTimestamps,
                            windowDays: windowDays,
                            limit: limit
                        )
                        if canCreate {
                            completion(.success(true))
                        } else {
                            completion(.failure(CalendarError.recreateLimitReached(limit: limit, windowDays: windowDays)))
                        }
                    }
            }
    }

    private static func timestamps(from snapshot: QuerySnapshot?) -> [Date] {
        (snapshot?.documents ?? []).compactMap { ($0.data()["at"] as? Timestamp)?.dateValue() }
    }

    // MARK: - 個人カレンダー編集

    // ★ 2026/08/18追加（ユーザー報告：予定保存フリーズと同根）：以前は応答確認に
    //   上限が無く、通信が不安定だと「保存中」のまま無期限に固まって見えていた
    func updateCalendarMembers(calendarId: String, memberIds: [String], completion: ((Error?) -> Void)? = nil) {
        Task {
            let error = await NetworkMonitor.awaitWithTimeout { done in
                self.db.collection("calendars").document(calendarId).updateData([
                    "memberIds": memberIds
                ]) { error in done(error) }
            }
            await MainActor.run { completion?(error) }
        }
    }

    func renameCalendar(calendarId: String, name: String, completion: ((Error?) -> Void)? = nil) {
        Task {
            let error = await NetworkMonitor.awaitWithTimeout { done in
                self.db.collection("calendars").document(calendarId).updateData([
                    "name": name
                ]) { error in done(error) }
            }
            await MainActor.run { completion?(error) }
        }
    }

    func deleteCalendar(_ calendar: OshiCalendar, completion: ((Error?) -> Void)? = nil) {
        guard !calendar.isCommunity && !calendar.isPrivate else {
            completion?(NSError(
                domain: "Calendar",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "このカレンダーは削除できません"]
            ))
            return
        }

        // ★ /ult監査で発見：他のCalendarViewModel関数(updateCalendarMembers/renameCalendar)は
        //   保存フリーズ修正時にタイムアウト付きへ揃えたが、ここだけ素のdelete completionを
        //   待ち続ける形が残っており、通信不安定時にボタンを押しても無反応に見えていた
        Task {
            let error = await NetworkMonitor.awaitWithTimeout { done in
                self.db.collection("calendars").document(calendar.id).delete { [weak self] error in
                    if error == nil, let ownerId = calendar.ownerId {
                        // ★ 「作り直し」レート制限の判定材料として、削除履歴を残す
                        //   (このログ自体はカウント対象ではなく、"recreate"ログの起点として使う)
                        self?.logCalendarActivity(uid: ownerId, groupId: calendar.groupId, action: "delete")
                    }
                    done(error)
                }
            }
            await MainActor.run { completion?(error) }
        }
    }
}

enum CalendarError: LocalizedError {
    case createLimitReached(limit: Int)
    case recreateLimitReached(limit: Int, windowDays: Int)

    var errorDescription: String? {
        switch self {
        case .createLimitReached(let limit):
            return "作成できるカレンダーは\(limit)件までです。より作成するにはプレミアムにアップグレードしてください。"
        case .recreateLimitReached(let limit, let windowDays):
            return "カレンダーの作り直しは\(windowDays)日間に\(limit)回までです。もっと作り直すにはプレミアムにアップグレードしてください。"
        }
    }
}
