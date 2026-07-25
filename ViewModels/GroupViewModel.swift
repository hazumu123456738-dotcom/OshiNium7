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

final class GroupViewModel: ObservableObject {

    @Published var groups: [IdolGroup] = []

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {}

    deinit {
        listener?.remove()
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

    // MARK: - Firestore グループ作成（全ユーザー共通 /groups）
    func createGroup(name: String, imageData: Data?) async throws -> IdolGroup {

        let normalized = normalizeName(name)

        // 既存チェック
        let snapshot = try await db.collection("groups")
            .whereField("normalizedName", isEqualTo: normalized)
            .getDocuments()

        if !snapshot.isEmpty {
            throw NSError(domain: "Group", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "このグループはすでに存在します"
            ])
        }

        let id = UUID().uuidString
        let createdAt = Date()

        let data: [String: Any] = [
            "id": id,
            "name": name,
            "normalizedName": normalized,
            "imageData": imageData ?? Data(),
            "createdAt": Timestamp(date: createdAt)
        ]

        try await db.collection("groups").document(id).setData(data)

        // IdolGroup を返す
        return IdolGroup(
            id: id,
            name: name,
            imageData: imageData,
            reading: nil,
            fandom: nil,
            concept: nil,
            history: nil,
            groupDescription: nil,
            createdAt: createdAt
        )
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
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { self.groups = [] }
                    return
                }

                var loaded: [IdolGroup] = []

                for doc in docs {
                    let data = doc.data()
                    let id = doc.documentID
                    let name = data["name"] as? String ?? "Unknown"

                    var imageData: Data? = nil
                    if let raw = data["imageData"] as? Data {
                        imageData = raw
                    } else if let base64 = data["imageData"] as? String {
                        imageData = Data(base64Encoded: base64)
                    }

                    let reading = data["reading"] as? String
                    let fandom = data["fandom"] as? String
                    let concept = data["concept"] as? String
                    let history = data["history"] as? String
                    let groupDescription = data["groupDescription"] as? String

                    var createdAtDate: Date? = nil
                    if let ts = data["createdAt"] as? Timestamp {
                        createdAtDate = ts.dateValue()
                    }

                    let group = IdolGroup(
                        id: id,
                        name: name,
                        imageData: imageData,
                        reading: reading,
                        fandom: fandom,
                        concept: concept,
                        history: history,
                        groupDescription: groupDescription,
                        createdAt: createdAtDate
                    )

                    loaded.append(group)
                }

                DispatchQueue.main.async {
                    self.groups = loaded
                    print("DEBUG Firestore groups updated:", self.groups.map { $0.name })
                }
            }
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

                var loaded: [IdolGroup] = []

                for doc in docs {
                    let data = doc.data()
                    let id = doc.documentID
                    let name = data["name"] as? String ?? "Unknown"

                    var imageData: Data? = nil
                    if let raw = data["imageData"] as? Data {
                        imageData = raw
                    } else if let base64 = data["imageData"] as? String {
                        imageData = Data(base64Encoded: base64)
                    }

                    let reading = data["reading"] as? String
                    let fandom = data["fandom"] as? String
                    let concept = data["concept"] as? String
                    let history = data["history"] as? String
                    let groupDescription = data["groupDescription"] as? String

                    var createdAtDate: Date? = nil
                    if let ts = data["createdAt"] as? Timestamp {
                        createdAtDate = ts.dateValue()
                    }

                    let group = IdolGroup(
                        id: id,
                        name: name,
                        imageData: imageData,
                        reading: reading,
                        fandom: fandom,
                        concept: concept,
                        history: history,
                        groupDescription: groupDescription,
                        createdAt: createdAtDate
                    )

                    loaded.append(group)
                }

                completion?(loaded)
            }
    }

    // MARK: - Firestore 追加（ユーザーの selectedGroups に追加）
    func addGroup(_ group: IdolGroup, completion: ((Error?) -> Void)? = nil) {
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
            "createdAt": Timestamp(date: group.createdAt ?? Date())
        ]

        if let imageData = group.imageData {
            data["imageData"] = imageData
        }

        docRef.setData(data) { error in
            if let error = error {
                print("DEBUG addGroup error:", error)
                completion?(error)
            } else {
                print("DEBUG addGroup success:", group.name)
                completion?(nil)
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
            "groupDescription": group.groupDescription as Any
        ]

        if let created = group.createdAt {
            data["createdAt"] = Timestamp(date: created)
        }

        if let imageData = group.imageData {
            data["imageData"] = imageData
        }

        docRef.updateData(data) { error in
            if let error = error {
                print("DEBUG updateGroup error:", error)
                completion?(error)
            } else {
                print("DEBUG updateGroup success:", group.name)
                completion?(nil)
            }
        }
    }

    // MARK: - Firestore 削除（退出）
    func deleteGroup(_ group: IdolGroup, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users")
            .document(uid)
            .collection("selectedGroups")
            .document(group.id)
            .delete { error in
                if let error = error {
                    print("DEBUG deleteGroup error:", error)
                    completion?(error)
                } else {
                    print("DEBUG deleteGroup success:", group.name)
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
