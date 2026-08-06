//
//  VenueReportViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import Combine
import FirebaseFirestore

final class VenueReportViewModel: ObservableObject {

    @Published private(set) var reports: [VenueReport] = []
    // ★ 「会場の口コミ」は場所単位で蓄積する別の一覧として持つ。
    //   同じ会場の別イベントを開いたときも、過去にその会場へ書かれた口コミが見られる
    @Published private(set) var placeReports: [VenueReport] = []
    // ★ オシニウムタブの「会場口コミ」ツール用。グループ内で書かれた口コミを
    //   会場を横断して一覧・検索できるようにするための購読
    @Published private(set) var groupReports: [VenueReport] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var placeListener: ListenerRegistration?
    private var groupListener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60
    private var placeRetryDelay: TimeInterval = 1
    private var groupRetryDelay: TimeInterval = 1

    deinit {
        listener?.remove()
        placeListener?.remove()
        groupListener?.remove()
    }

    private var reportsCollection: CollectionReference {
        db.collection("venueReports")
    }

    // MARK: - Firestore リアルタイム購読（イベント単位。主に「その日のセトリ」用）

    // ★ whereField + order(by:) を同時に使うと複合インデックスが必要になり、未作成だと
    //   リスナーごと失敗して口コミが永遠に表示されなくなる（EventHubExtrasViewModelと同じ問題）。
    //   並び替えはクライアント側で行い、単純な等価フィルタのみに留める
    func startListening(eventId: String) {
        listener?.remove()
        listener = reportsCollection
            .whereField("eventId", isEqualTo: eventId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 口コミ購読エラー:", error)
                    self.scheduleRetry(eventId: eventId)
                    return
                }

                let newReports = (snapshot?.documents.compactMap { self.decodeReport(doc: $0) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.reports = newReports
                }
            }
    }

    // MARK: - Firestore リアルタイム購読（会場＝場所単位。「会場の口コミ」用）

    func startListeningByPlace(_ place: String) {
        placeListener?.remove()
        guard !place.isEmpty else {
            placeReports = []
            return
        }

        placeListener = reportsCollection
            .whereField("place", isEqualTo: place)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 会場口コミ購読エラー:", error)
                    self.schedulePlaceRetry(place: place)
                    return
                }

                let newReports = (snapshot?.documents.compactMap { self.decodeReport(doc: $0) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                self.placeRetryDelay = 1

                DispatchQueue.main.async {
                    self.placeReports = newReports
                }
            }
    }

    // MARK: - Firestore リアルタイム購読（グループ単位。「会場口コミ」ツールの一覧・検索用）

    // ★ EventHubExtrasViewModelと同じ理由で、whereField + order(by:)の複合インデックスを
    //   避けるため単純な等価フィルタ（groupIdのみ）に留め、kindでの絞り込みと並び替えは
    //   クライアント側で行う
    func startListeningByGroup(_ groupId: String) {
        groupListener?.remove()
        guard !groupId.isEmpty else {
            groupReports = []
            return
        }

        groupListener = reportsCollection
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 グループ口コミ購読エラー:", error)
                    self.scheduleGroupRetry(groupId: groupId)
                    return
                }

                let newReports = (snapshot?.documents.compactMap { self.decodeReport(doc: $0) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                self.groupRetryDelay = 1

                DispatchQueue.main.async {
                    self.groupReports = newReports
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        placeListener?.remove()
        placeListener = nil
        groupListener?.remove()
        groupListener = nil
    }

    private func scheduleRetry(eventId: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListening(eventId: eventId)
        }
    }

    private func schedulePlaceRetry(place: String) {
        placeListener?.remove()
        let delay = placeRetryDelay
        placeRetryDelay = min(placeRetryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListeningByPlace(place)
        }
    }

    private func scheduleGroupRetry(groupId: String) {
        groupListener?.remove()
        let delay = groupRetryDelay
        groupRetryDelay = min(groupRetryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListeningByGroup(groupId)
        }
    }

    private func decodeReport(doc: QueryDocumentSnapshot) -> VenueReport? {
        let data = doc.data()
        guard let eventId = data["eventId"] as? String,
              let groupId = data["groupId"] as? String,
              let kind = data["kind"] as? String,
              let text = data["text"] as? String,
              let uid = data["uid"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return VenueReport(
            id: doc.documentID,
            eventId: eventId,
            groupId: groupId,
            kind: kind,
            text: text,
            uid: uid,
            createdAt: createdAt,
            place: data["place"] as? String,
            eventDate: (data["eventDate"] as? Timestamp)?.dateValue(),
            purpose: data["purpose"] as? String
        )
    }

    // MARK: - 投稿（匿名。uidは連投防止・モデレーション用にのみ保持し、画面には表示しない）

    func submit(
        eventId: String,
        groupId: String,
        kind: String,
        text: String,
        uid: String,
        place: String? = nil,
        eventDate: Date? = nil,
        purpose: String? = nil
    ) {
        var data: [String: Any] = [
            "eventId": eventId,
            "groupId": groupId,
            "kind": kind,
            "text": text,
            "uid": uid,
            "createdAt": Timestamp(date: Date())
        ]
        if let place, !place.isEmpty { data["place"] = place }
        if let eventDate { data["eventDate"] = Timestamp(date: eventDate) }
        if let purpose, !purpose.isEmpty { data["purpose"] = purpose }

        reportsCollection.addDocument(data: data) { error in
            if let error = error {
                print("🔥 venueReport submit error:", error)
            }
        }
    }

    // MARK: - フィルタ

    func entries(kind: String) -> [VenueReport] {
        reports.filter { $0.kind == kind }
    }

    // ★ 会場（場所）単位で蓄積された「会場の口コミ」一覧
    var placeReviewEntries: [VenueReport] {
        placeReports.filter { $0.kind == "review" }
    }

    // ★ グループ内で書かれた「会場の口コミ」を会場横断で一覧化（オシニウムタブのツール用）
    var groupReviewEntries: [VenueReport] {
        groupReports.filter { $0.kind == "review" }
    }
}
