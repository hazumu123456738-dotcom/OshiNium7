//
//  PackingChecklistViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import Foundation
import Combine
import FirebaseFirestore
import WidgetKit

// ★ 持ち物チェックリスト機能。OshiExpenseViewModelと同じ構成
//   （トップレベルコレクション＋uidで絞り込み、whereField単独のみで複合インデックスを避ける）
final class PackingChecklistViewModel: ObservableObject {

    @Published private(set) var items: [PackingChecklistItem] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var itemsCollection: CollectionReference {
        db.collection("packingChecklistItems")
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = itemsCollection
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("🔥 持ち物チェックリスト 購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let newItems = (snapshot?.documents.compactMap { self.decode($0) } ?? [])
                    .sorted { $0.date > $1.date }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.items = newItems
                    self.updateWidgetSnapshot()
                }
            }
    }

    // ★ ホーム画面ウィジェット（持ち物カレンダー）用に、今月分を「その日に何件あるか」の
    //   軽量なドットカレンダーとしてApp Group経由で書き出す。MiniCalendarWidgetの
    //   updateWidgetSnapshot（AppRootView）と同じ考え方
    private func updateWidgetSnapshot() {
        let cal = Calendar.current
        let now = Date()
        guard let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return }

        var dayCounts: [Int: Int] = [:]
        for item in items where cal.isDate(item.date, equalTo: firstOfMonth, toGranularity: .month) {
            let day = cal.component(.day, from: item.date)
            dayCounts[day, default: 0] += 1
        }

        let snapshot = WidgetDotCalendarSnapshot(
            title: "持ち物チェックリスト",
            year: cal.component(.year, from: now),
            month: cal.component(.month, from: now),
            firstWeekday: cal.component(.weekday, from: firstOfMonth),
            daysInMonth: range.count,
            days: dayCounts.map { WidgetDotCalendarDay(day: $0.key, count: $0.value) },
            todayDay: cal.component(.day, from: now),
            updatedAt: now
        )

        SharedWidgetStore.savePacking(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "PackingCalendarWidget")
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

    private func decode(_ doc: QueryDocumentSnapshot) -> PackingChecklistItem? {
        let d = doc.data()
        guard let uid = d["uid"] as? String,
              let title = d["title"] as? String,
              let isChecked = d["isChecked"] as? Bool,
              let date = (d["date"] as? Timestamp)?.dateValue(),
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return PackingChecklistItem(
            id: doc.documentID,
            uid: uid,
            groupId: d["groupId"] as? String,
            groupName: d["groupName"] as? String,
            title: title,
            isChecked: isChecked,
            date: date,
            createdAt: createdAt,
            remindAt: (d["remindAt"] as? Timestamp)?.dateValue()
        )
    }

    // MARK: - 追加・更新・削除

    // ★ remindAtが指定されていれば、Firestoreへの保存後にローカル通知も予約する。
    //   通知の識別子は"packing_<ドキュメントID>"なので、IDが確定するaddDocumentの
    //   完了後でないと予約できない
    func addItem(uid: String, groupId: String?, groupName: String?, title: String, date: Date, remindAt: Date?) {
        var data: [String: Any] = [
            "uid": uid,
            "title": title,
            "isChecked": false,
            "date": Timestamp(date: date),
            "createdAt": Timestamp(date: Date())
        ]
        if let groupId { data["groupId"] = groupId }
        if let groupName { data["groupName"] = groupName }
        if let remindAt { data["remindAt"] = Timestamp(date: remindAt) }

        var ref: DocumentReference? = nil
        ref = itemsCollection.addDocument(data: data) { error in
            if let error {
                print("🔥 addItem error:", error)
                return
            }
            if let remindAt, let itemId = ref?.documentID {
                NotificationManager.shared.schedulePackingReminder(
                    itemId: itemId, title: title, groupName: groupName, at: remindAt
                )
            }
        }
    }

    func toggleChecked(_ item: PackingChecklistItem) {
        itemsCollection.document(item.id).updateData(["isChecked": !item.isChecked]) { error in
            if let error { print("🔥 toggleChecked error:", error) }
        }
    }

    func deleteItem(_ item: PackingChecklistItem) {
        NotificationManager.shared.removePackingReminder(itemId: item.id)
        itemsCollection.document(item.id).delete { error in
            if let error { print("🔥 deleteItem error:", error) }
        }
    }

    // MARK: - 月・日単位での絞り込み（カレンダー表示用）

    func items(inMonth month: Date) -> [PackingChecklistItem] {
        items.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    // ★ 持ち物がある日（startOfDayに正規化済み）の集合。ミニカレンダーのドット表示に使う
    var markedDates: Set<Date> {
        Set(items.map { Calendar.current.startOfDay(for: $0.date) })
    }
}
