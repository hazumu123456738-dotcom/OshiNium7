//
//  OshiExpenseViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation
import Combine
import FirebaseFirestore
import WidgetKit

// ★ 「推し活の金額を計算」機能。トップレベルコレクション＋uidで絞り込みという
//   既存のViewModel群と同じ構成。whereField単独のみ（order(by:)と組み合わせない）にして、
//   複合インデックス未作成によるリスナー失敗を避ける（並び替えはクライアント側で行う）
final class OshiExpenseViewModel: ObservableObject {

    @Published private(set) var expenses: [OshiExpense] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var expensesCollection: CollectionReference {
        db.collection("oshiExpenses")
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = expensesCollection
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("🔥 推し活金額 購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let newExpenses = (snapshot?.documents.compactMap { self.decode($0) } ?? [])
                    .sorted { $0.date > $1.date }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.expenses = newExpenses
                    self.updateWidgetSnapshot()
                }
            }
    }

    // ★ ホーム画面ウィジェット（推し活費用カレンダー）用に、今月分を「その日に何件記録が
    //   あるか」の軽量なドットカレンダーとしてApp Group経由で書き出す
    private func updateWidgetSnapshot() {
        let cal = Calendar.current
        let now = Date()
        guard let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return }

        var dayCounts: [Int: Int] = [:]
        for expense in expenses where cal.isDate(expense.date, equalTo: firstOfMonth, toGranularity: .month) {
            let day = cal.component(.day, from: expense.date)
            dayCounts[day, default: 0] += 1
        }

        let snapshot = WidgetDotCalendarSnapshot(
            title: "推し活費用シミュレーター",
            year: cal.component(.year, from: now),
            month: cal.component(.month, from: now),
            firstWeekday: cal.component(.weekday, from: firstOfMonth),
            daysInMonth: range.count,
            days: dayCounts.map { WidgetDotCalendarDay(day: $0.key, count: $0.value) },
            todayDay: cal.component(.day, from: now),
            updatedAt: now
        )

        SharedWidgetStore.saveExpense(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "ExpenseCalendarWidget")
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

    private func decode(_ doc: QueryDocumentSnapshot) -> OshiExpense? {
        let d = doc.data()
        guard let uid = d["uid"] as? String,
              let category = d["category"] as? String,
              let amount = d["amount"] as? Int,
              let date = (d["date"] as? Timestamp)?.dateValue(),
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return OshiExpense(
            id: doc.documentID,
            uid: uid,
            groupId: d["groupId"] as? String,
            groupName: d["groupName"] as? String,
            category: category,
            amount: amount,
            note: d["note"] as? String,
            imageURL: d["imageURL"] as? String,
            date: date,
            createdAt: createdAt
        )
    }

    // MARK: - 追加・削除

    func addExpense(uid: String, groupId: String?, groupName: String?, category: String, amount: Int, note: String?, imageURL: String? = nil, date: Date) {
        var data: [String: Any] = [
            "uid": uid,
            "category": category,
            "amount": amount,
            "date": Timestamp(date: date),
            "createdAt": Timestamp(date: Date())
        ]
        if let groupId { data["groupId"] = groupId }
        if let groupName { data["groupName"] = groupName }
        if let note, !note.isEmpty { data["note"] = note }
        if let imageURL { data["imageURL"] = imageURL }

        expensesCollection.addDocument(data: data) { error in
            if let error { print("🔥 addExpense error:", error) }
        }
    }

    func deleteExpense(_ expense: OshiExpense) {
        expensesCollection.document(expense.id).delete { error in
            if let error { print("🔥 deleteExpense error:", error) }
        }
    }

    // MARK: - 集計

    var totalAmount: Int {
        expenses.reduce(0) { $0 + $1.amount }
    }

    // ★ グループごとの合計。未分類（グループ選択なし）は「その他」として集計する
    var totalsByGroup: [(name: String, amount: Int)] {
        var totals: [String: Int] = [:]
        for e in expenses {
            let key = e.groupName ?? "未分類"
            totals[key, default: 0] += e.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (name: $0.key, amount: $0.value) }
    }

    var totalsByCategory: [(category: String, amount: Int)] {
        var totals: [String: Int] = [:]
        for e in expenses {
            totals[e.category, default: 0] += e.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (category: $0.key, amount: $0.value) }
    }

    // MARK: - 月・日単位での絞り込み（カレンダー表示用）

    func expenses(inMonth month: Date) -> [OshiExpense] {
        expenses.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    func total(inMonth month: Date) -> Int {
        expenses(inMonth: month).reduce(0) { $0 + $1.amount }
    }

    // ★ 記録がある日（startOfDayに正規化済み）の集合。ミニカレンダーのドット表示に使う
    var markedDates: Set<Date> {
        Set(expenses.map { Calendar.current.startOfDay(for: $0.date) })
    }
}
