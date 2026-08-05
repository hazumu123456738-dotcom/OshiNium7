//
//  AttendanceViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ 参戦記録機能。OshiExpenseViewModel・PackingChecklistViewModelと同じ構成
//   （トップレベルコレクション＋uidで絞り込み、whereField単独のみで複合インデックスを避ける）
final class AttendanceViewModel: ObservableObject {

    @Published private(set) var records: [EventAttendanceRecord] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var recordsCollection: CollectionReference {
        db.collection("eventAttendance")
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = recordsCollection
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("🔥 参戦記録 購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let newRecords = snapshot?.documents.compactMap { self.decode($0) } ?? []
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.records = newRecords
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func scheduleRetry(uid: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListening(uid: uid)
        }
    }

    private func decode(_ doc: QueryDocumentSnapshot) -> EventAttendanceRecord? {
        let d = doc.data()
        guard let uid = d["uid"] as? String,
              let eventId = d["eventId"] as? String,
              let attended = d["attended"] as? Bool,
              let answeredAt = (d["answeredAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return EventAttendanceRecord(id: doc.documentID, uid: uid, eventId: eventId, attended: attended, answeredAt: answeredAt)
    }

    // ★ 「参戦した」「行けなかった」の回答を保存（同じ予定への回答は上書き）
    func answer(uid: String, eventId: String, attended: Bool) {
        let docId = "\(uid)_\(eventId)"
        let data: [String: Any] = [
            "uid": uid,
            "eventId": eventId,
            "attended": attended,
            "answeredAt": Timestamp(date: Date())
        ]
        recordsCollection.document(docId).setData(data) { error in
            if let error { print("🔥 参戦記録 保存エラー:", error) }
        }
    }

    func record(for eventId: String) -> EventAttendanceRecord? {
        records.first { $0.eventId == eventId }
    }
}
