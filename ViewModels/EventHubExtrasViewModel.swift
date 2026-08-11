//
//  EventHubExtrasViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ イベント当日ハブの「チケット情報」「グッズ情報」「公式お知らせ」を
//   イベント単位でリアルタイム購読する。VenueReportViewModelと同じ構成
final class EventHubExtrasViewModel: ObservableObject {

    @Published private(set) var tickets: [EventTicketInfo] = []
    @Published private(set) var goods: [EventGoodsItem] = []
    @Published private(set) var announcements: [EventAnnouncement] = []

    private let db = Firestore.firestore()
    private var ticketsListener: ListenerRegistration?
    private var goodsListener: ListenerRegistration?
    private var announcementsListener: ListenerRegistration?

    deinit {
        ticketsListener?.remove()
        goodsListener?.remove()
        announcementsListener?.remove()
    }

    // MARK: - 購読

    func startListening(eventId: String) {
        guard !eventId.isEmpty else { return }
        stopListening()

        // ★ whereField + order(by:) を同時に使うとFirestore側で複合インデックスの作成が必要になり、
        //   未作成の場合はリスナーごと失敗してしまう。並び替えはクライアント側で行い、
        //   単純な等価フィルタのみ（自動インデックスで動く）に留める
        ticketsListener = db.collection("eventTickets")
            .whereField("eventId", isEqualTo: eventId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 eventTickets 購読エラー:", error)
                    return
                }
                let items = (snapshot?.documents.compactMap { Self.decodeTicket($0) } ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                DispatchQueue.main.async { self.tickets = items }
            }

        goodsListener = db.collection("eventGoods")
            .whereField("eventId", isEqualTo: eventId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 eventGoods 購読エラー:", error)
                    return
                }
                let items = (snapshot?.documents.compactMap { Self.decodeGoods($0) } ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                DispatchQueue.main.async { self.goods = items }
            }

        announcementsListener = db.collection("eventAnnouncements")
            .whereField("eventId", isEqualTo: eventId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 eventAnnouncements 購読エラー:", error)
                    return
                }
                let items = (snapshot?.documents.compactMap { Self.decodeAnnouncement($0) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                DispatchQueue.main.async { self.announcements = items }
            }
    }

    func stopListening() {
        ticketsListener?.remove(); ticketsListener = nil
        goodsListener?.remove(); goodsListener = nil
        announcementsListener?.remove(); announcementsListener = nil
        tickets = []
        goods = []
        announcements = []
    }

    // MARK: - 追加（誰でも追加できる。ファン同士で情報を持ち寄る想定）

    // ★ 2026/08/11修正：以前はcompletionが無く、呼び出し元（EventHubDetailView）は
    //   書き込み結果を待たずに即dismiss()していた。通報を受けて制限されたユーザーの投稿は
    //   firestore.rulesの!isRestricted()で拒否されるが、それが起きても保存できたかのように
    //   シートが閉じてしまい、実際には何も保存されていないことに気づけなかった
    func addTicket(eventId: String, groupId: String, name: String, price: String, saleStart: String?, note: String?, url: String?, authorUid: String, completion: ((Error?) -> Void)? = nil) {
        let data: [String: Any] = [
            "eventId": eventId,
            "groupId": groupId,
            "name": name,
            "price": price,
            "saleStart": saleStart as Any? ?? NSNull(),
            "note": note as Any? ?? NSNull(),
            "url": url as Any? ?? NSNull(),
            "authorUid": authorUid,
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("eventTickets").addDocument(data: data) { error in
            if let error { print("🔥 addTicket error:", error) }
            completion?(error)
        }
    }

    func addGoods(eventId: String, groupId: String, name: String, price: String?, note: String?, authorUid: String, completion: ((Error?) -> Void)? = nil) {
        let data: [String: Any] = [
            "eventId": eventId,
            "groupId": groupId,
            "name": name,
            "price": price as Any? ?? NSNull(),
            "note": note as Any? ?? NSNull(),
            "authorUid": authorUid,
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("eventGoods").addDocument(data: data) { error in
            if let error { print("🔥 addGoods error:", error) }
            completion?(error)
        }
    }

    func addAnnouncement(eventId: String, groupId: String, title: String, body: String?, url: String?, authorUid: String, completion: ((Error?) -> Void)? = nil) {
        let data: [String: Any] = [
            "eventId": eventId,
            "groupId": groupId,
            "title": title,
            "body": body as Any? ?? NSNull(),
            "url": url as Any? ?? NSNull(),
            "authorUid": authorUid,
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("eventAnnouncements").addDocument(data: data) { error in
            if let error { print("🔥 addAnnouncement error:", error) }
            completion?(error)
        }
    }

    // MARK: - 削除（投稿者本人のみ。UI側でauthorUidを見てボタン表示を制御する）

    func deleteTicket(_ item: EventTicketInfo) {
        db.collection("eventTickets").document(item.id).delete()
    }

    func deleteGoods(_ item: EventGoodsItem) {
        db.collection("eventGoods").document(item.id).delete()
    }

    func deleteAnnouncement(_ item: EventAnnouncement) {
        db.collection("eventAnnouncements").document(item.id).delete()
    }

    // MARK: - デコード

    private static func decodeTicket(_ doc: QueryDocumentSnapshot) -> EventTicketInfo? {
        let d = doc.data()
        guard let eventId = d["eventId"] as? String,
              let groupId = d["groupId"] as? String,
              let name = d["name"] as? String,
              let price = d["price"] as? String,
              let authorUid = d["authorUid"] as? String,
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return EventTicketInfo(
            id: doc.documentID,
            eventId: eventId,
            groupId: groupId,
            name: name,
            price: price,
            saleStart: d["saleStart"] as? String,
            note: d["note"] as? String,
            url: d["url"] as? String,
            authorUid: authorUid,
            createdAt: createdAt
        )
    }

    private static func decodeGoods(_ doc: QueryDocumentSnapshot) -> EventGoodsItem? {
        let d = doc.data()
        guard let eventId = d["eventId"] as? String,
              let groupId = d["groupId"] as? String,
              let name = d["name"] as? String,
              let authorUid = d["authorUid"] as? String,
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return EventGoodsItem(
            id: doc.documentID,
            eventId: eventId,
            groupId: groupId,
            name: name,
            price: d["price"] as? String,
            note: d["note"] as? String,
            authorUid: authorUid,
            createdAt: createdAt
        )
    }

    private static func decodeAnnouncement(_ doc: QueryDocumentSnapshot) -> EventAnnouncement? {
        let d = doc.data()
        guard let eventId = d["eventId"] as? String,
              let groupId = d["groupId"] as? String,
              let title = d["title"] as? String,
              let authorUid = d["authorUid"] as? String,
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return EventAnnouncement(
            id: doc.documentID,
            eventId: eventId,
            groupId: groupId,
            title: title,
            body: d["body"] as? String,
            url: d["url"] as? String,
            authorUid: authorUid,
            createdAt: createdAt
        )
    }
}
