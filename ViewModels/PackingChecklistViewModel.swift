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

    // ★ 「その日ぶん揃いました」通知を既に送った日を覚えておき、次のsnapshot更新でも
    //   毎回送り直さないようにする（＝チェック済み→チェック済みのまま、では再送しない）。
    //   ★ 2026/08/11修正：このViewModelはPackingChecklistView側で@StateObjectとして
    //   保持されているため、画面を離れて戻るたびに作り直され、このSetがリセットされていた。
    //   結果、既に「揃いました」通知を送った日でも画面を開き直すたびに重複通知が飛んでいた。
    //   UserDefaultsに永続化し、ViewModelの再生成をまたいで覚えておくようにする
    private static let notifiedCompleteDateKeysDefaultsKey = "packingNotifiedCompleteDateKeys"

    private var notifiedCompleteDateKeys: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: Self.notifiedCompleteDateKeysDefaultsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.notifiedCompleteDateKeysDefaultsKey)
        }
    }

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
                    self.refreshDayCompletionNotifications()
                }
            }
    }

    // MARK: - 日単位の「揃いました」通知・「まだ揃っていません」警告
    //   ★ 持ち物はアイテム単位でしか管理していないため、日付ごとにグルーピングし直して
    //   「その日ぶんが全部チェック済みか」をここで判定する。addItem/updateItem/toggleChecked/
    //   deleteItemのどれで呼ばれても、この関数が最終的な状態から辻褄を合わせる
    //   （個々の操作ごとに通知ロジックを分散させない）
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func refreshDayCompletionNotifications() {
        let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }

        for (day, dayItems) in grouped {
            let dateKey = Self.dayKeyFormatter.string(from: day)
            let allChecked = dayItems.allSatisfy(\.isChecked)
            let groupName = dayItems.first(where: { $0.groupName?.isEmpty == false })?.groupName

            if allChecked {
                NotificationManager.shared.cancelUncheckedWarning(dateKey: dateKey)

                // ★ 揃った瞬間だけ完了通知を送る。既に送信済みの日は再送しない
                if !notifiedCompleteDateKeys.contains(dateKey) {
                    notifiedCompleteDateKeys.insert(dateKey)
                    NotificationManager.shared.sendPackingAllCheckedNotification(
                        dateKey: dateKey, groupName: groupName, itemCount: dayItems.count
                    )
                }
            } else {
                // ★ チェックが外れて未完了に戻ったら、次に揃った時にまた通知できるようにする
                notifiedCompleteDateKeys.remove(dateKey)

                // ★ その日の朝9時の時点でまだ未完了なら警告する。既に朝9時を過ぎている日
                //   （今日の午後に追加した等）は、意味のある予約ができないためスキップする
                let remaining = dayItems.filter { !$0.isChecked }.count
                if let warningTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                   warningTime > Date() {
                    NotificationManager.shared.scheduleUncheckedWarning(
                        dateKey: dateKey, at: warningTime, remainingCount: remaining, groupName: groupName
                    )
                } else {
                    NotificationManager.shared.cancelUncheckedWarning(dateKey: dateKey)
                }
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
            NetworkMonitor.retryWhenOnline { self?.startListening(uid: uid) }
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
            // ★ 旧フィールド（単一値のremindAt）が残っている既存データも1件の配列として読み込む
            remindAts: (d["remindAts"] as? [Timestamp])?.map { $0.dateValue() }
                ?? (d["remindAt"] as? Timestamp).map { [$0.dateValue()] }
                ?? []
        )
    }

    // MARK: - 追加・更新・削除

    // ★ 1回の登録画面でまとめて追加する複数の持ち物用。以前はアイテムごとに個別の通知を
    //   予約していたため、同じ時刻に3件登録すると同じ時刻に3件別々の通知が届いてしまっていた。
    //   Firestoreへの保存自体はアイテムごとに行う（個別にチェック・編集できる必要があるため）が、
    //   リマインド通知だけは全アイテム名をまとめた1件の通知として、登録1回につき1回だけ予約する
    // ★ 2026/08/15修正：completionが無く、書き込み失敗をUI側が一切検知できなかった。
    //   複数件まとめて追加するため、1件でも失敗したら呼び出し元へ知らせる
    func addItems(uid: String, groupId: String?, groupName: String?, titles: [String], date: Date, remindAts: [Date], completion: ((Error?) -> Void)? = nil) {
        let trimmed = titles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }

        var firstError: Error?
        let group = DispatchGroup()

        for title in trimmed {
            var data: [String: Any] = [
                "uid": uid,
                "title": title,
                "isChecked": false,
                "date": Timestamp(date: date),
                "createdAt": Timestamp(date: Date())
            ]
            if let groupId { data["groupId"] = groupId }
            if let groupName { data["groupName"] = groupName }
            if !remindAts.isEmpty { data["remindAts"] = remindAts.map { Timestamp(date: $0) } }
            group.enter()
            itemsCollection.addDocument(data: data) { error in
                if let error {
                    print("🔥 addItems error:", error)
                    if firstError == nil { firstError = error }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(firstError)
        }

        if !remindAts.isEmpty {
            // ★ 個々のアイテムIDには紐づかない、この登録バッチ専用の通知識別子を使う
            let batchId = "batch_\(UUID().uuidString)"
            NotificationManager.shared.schedulePackingReminders(
                itemId: batchId, title: trimmed.joined(separator: "・"), groupName: groupName, at: remindAts
            )
        }
    }

    // ★ 既存アイテムの編集（タイトル・日付・通知リマインド）。addItemと違い、
    //   古い通知("packing_<id>_*")を必ず一度キャンセルしてから、必要なら新しい時刻で
    //   予約し直す。remindAtsが空になった場合（すべてオフに戻した場合）はキャンセルだけで終わる
    func updateItem(_ item: PackingChecklistItem, title: String, date: Date, remindAts: [Date], completion: ((Error?) -> Void)? = nil) {
        var data: [String: Any] = [
            "title": title,
            "date": Timestamp(date: date)
        ]
        data["remindAts"] = remindAts.isEmpty ? FieldValue.delete() : remindAts.map { Timestamp(date: $0) }
        data["remindAt"] = FieldValue.delete()

        NotificationManager.shared.removePackingReminder(itemId: item.id)

        itemsCollection.document(item.id).updateData(data) { error in
            if let error {
                print("🔥 updateItem error:", error)
                completion?(error)
                return
            }
            if !remindAts.isEmpty {
                NotificationManager.shared.schedulePackingReminders(
                    itemId: item.id, title: title, groupName: item.groupName, at: remindAts
                )
            }
            completion?(nil)
        }
    }

    func toggleChecked(_ item: PackingChecklistItem, completion: ((Error?) -> Void)? = nil) {
        itemsCollection.document(item.id).updateData(["isChecked": !item.isChecked]) { error in
            if let error { print("🔥 toggleChecked error:", error) }
            completion?(error)
        }
    }

    func deleteItem(_ item: PackingChecklistItem, completion: ((Error?) -> Void)? = nil) {
        NotificationManager.shared.removePackingReminder(itemId: item.id)
        itemsCollection.document(item.id).delete { error in
            if let error { print("🔥 deleteItem error:", error) }
            completion?(error)
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
