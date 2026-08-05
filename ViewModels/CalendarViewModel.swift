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

        personalListener = db.collection("calendars")
            .whereField("groupId", isEqualTo: groupId)
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

        // コミュニティカレンダーを先頭に、以降は作成日順
        let merged = Array(dict.values).sorted { lhs, rhs in
            if lhs.isCommunity != rhs.isCommunity { return lhs.isCommunity }
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

    // MARK: - 個人カレンダー作成

    func createPersonalCalendar(
        name: String,
        groupId: String,
        ownerId: String,
        memberIds: [String],
        colorHex: String?,
        completion: ((Result<OshiCalendar, Error>) -> Void)? = nil
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

        db.collection("calendars").document(id).setData(data) { error in
            if let error = error {
                completion?(.failure(error))
                return
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
            completion?(.success(calendar))
        }
    }

    // MARK: - 個人カレンダー編集

    func updateCalendarMembers(calendarId: String, memberIds: [String], completion: ((Error?) -> Void)? = nil) {
        db.collection("calendars").document(calendarId).updateData([
            "memberIds": memberIds
        ]) { error in
            completion?(error)
        }
    }

    func renameCalendar(calendarId: String, name: String, completion: ((Error?) -> Void)? = nil) {
        db.collection("calendars").document(calendarId).updateData([
            "name": name
        ]) { error in
            completion?(error)
        }
    }

    func deleteCalendar(_ calendar: OshiCalendar, completion: ((Error?) -> Void)? = nil) {
        guard !calendar.isCommunity else {
            completion?(NSError(
                domain: "Calendar",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "コミュニティカレンダーは削除できません"]
            ))
            return
        }

        db.collection("calendars").document(calendar.id).delete { error in
            completion?(error)
        }
    }
}
