//
//  NotificationManager.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/27.
//

import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseAuth

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let db = Firestore.firestore()

    // MARK: - 丁寧な事前通知メッセージ（まもなく）
    private func friendlyMessage(for event: Event) -> String {

        let type = event.type ?? .other

        switch type {
        case .live:
            return "ライブ開始時間はまもなくです。"
        case .tv:
            return "番組の放送開始時間はまもなくです。"
        case .event:
            return "イベント開始時間はまもなくです。"
        case .release:
            return "リリース公開時間はまもなくです。"
        case .sns:
            return "配信開始時間はまもなくです。"
        case .anniversary:
            return "記念日の時間が近づいています。"
        case .other:
            return "開始時間はまもなくです。"
        }
    }

    // MARK: - 開始通知メッセージ（カウントダウン0の瞬間）
    private func startMessage(for event: Event) -> String {

        let type = event.type ?? .other

        switch type {
        case .live:
            return "🎤 ライブが始まりました。"
        case .tv:
            return "📺 番組の放送が始まりました。"
        case .event:
            return "🎪 イベントが始まりました。"
        case .release:
            return "💿 リリースが公開されました。"
        case .sns:
            return "📱 配信が始まりました。"
        case .anniversary:
            return "🎉 記念日を迎えました。"
        case .other:
            return "⭐️ 予定が開始しました。"
        }
    }

    // MARK: - Firestore からグループ名を取得
    private func fetchGroupName(for groupId: String, completion: @escaping (String) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion("未設定グループ")
            return
        }

        db.collection("users")
            .document(uid)
            .collection("selectedGroups")
            .document(groupId)
            .getDocument { snapshot, error in

                if let error = error {
                    print("DEBUG fetchGroupName error:", error)
                    completion("未設定グループ")
                    return
                }

                let name = snapshot?.data()?["name"] as? String ?? "未設定グループ"
                completion(name)
            }
    }

    // MARK: - 事前通知（24時間前＋ユーザーが自由に設定した複数の通知タイミング）
    func scheduleNotifications(for event: Event, userMinutesBeforeList: [Int]) {

        // 24時間前
        scheduleSingleNotification(event, minutesBefore: 1440)

        // ユーザーが追加した通知タイミング（複数可・重複は1回にまとめる）
        for minutesBefore in Set(userMinutesBeforeList) where minutesBefore != 1440 {
            scheduleSingleNotification(event, minutesBefore: minutesBefore)
        }

        // 🔥 開始通知（カウントダウン0の瞬間）
        scheduleStartNotification(for: event)
    }

    // MARK: - 単発通知（まもなく）
    private func scheduleSingleNotification(_ event: Event, minutesBefore: Int) {

        let safeGroupId = event.groupId ?? ""

        fetchGroupName(for: safeGroupId) { [weak self] groupName in
            guard let self = self else { return }

            let content = UNMutableNotificationContent()

            let eventName = event.title
            let emoji = event.type?.emoji ?? "⭐️"

            // 上段タイトル：絵文字＋グループ名＋予定名
            content.title = "\(emoji) 【\(groupName)】\(eventName)"

            // 下段本文：まもなく通知
            content.body = self.friendlyMessage(for: event)
            content.sound = .default

            // 通知時刻
            let triggerDate = Calendar.current.date(
                byAdding: .minute,
                value: -minutesBefore,
                to: event.date
            ) ?? event.date

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )

            let identifier = "\(event.id ?? UUID().uuidString)_\(minutesBefore)"

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            // ★ 2026/08/11修正：以前はエラーハンドリングが無く、通知の許可が下りていない・
            //   保留中の通知がiOSの上限(64件)に達している等で予約が失敗しても気づく術が
            //   無かった（持ち物リマインドは既にこの形で修正済みだったが、より重要な
            //   予定の事前通知の方には反映されていなかった）
            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("🔥 scheduleSingleNotification error:", error) }
            }
        }
    }

    // MARK: - 🔥 イベント開始通知（カウントダウン0の瞬間）
    private func scheduleStartNotification(for event: Event) {

        let safeGroupId = event.groupId ?? ""

        fetchGroupName(for: safeGroupId) { [weak self] groupName in
            guard let self = self else { return }

            let content = UNMutableNotificationContent()

            let emoji = event.type?.emoji ?? "⭐️"

            // 上段タイトル：絵文字＋グループ名＋イベント名
            content.title = "\(emoji) 【\(groupName)】\(event.title)"

            // 下段本文：開始を丁寧に伝える
            content.body = self.startMessage(for: event)
            content.sound = .default

            // イベント開始時刻
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: event.date
            )

            let identifier = "\(event.id ?? UUID().uuidString)_start"

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("🔥 scheduleStartNotification error:", error) }
            }
        }
    }

    // MARK: - 通知削除
    func removeNotifications(for eventId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(eventId) }

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - 持ち物チェックリストのリマインド通知
    //   ★ イベント予定と違って開始時刻という概念が無く、ユーザーが直接「何時に知らせてほしいか」を
    //     選ぶだけのシンプルな通知。1アイテムにつき何個でも自由に設定できるよう、
    //     識別子は"packing_"接頭辞＋アイテムID＋連番で管理する（配列のindexで一意にする）

    func schedulePackingReminders(itemId: String, title: String, groupName: String?, at dates: [Date]) {
        // ★ 予約し直すたびに、そのアイテムの古い予約（旧・単数時代の識別子も含む）を
        //   一旦すべて消してから、現在のdatesぶんだけ新しく積み直す
        removePackingReminder(itemId: itemId)

        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "🎒 持ち物の確認"
            if let groupName, !groupName.isEmpty {
                content.body = "【\(groupName)】「\(title)」を忘れずに準備しましょう"
            } else {
                content.body = "「\(title)」を忘れずに準備しましょう"
            }
            content.sound = .default

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )

            let identifier = "packing_\(itemId)_\(index)"

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            // ★ 以前はエラーハンドリングが無く、通知の許可が下りていない・保留中の通知が
            //   iOSの上限(64件)に達している等で予約が失敗しても気づく術が無かった。
            //   ログに残すことで、「リマインドを設定したのに来ない」の切り分けに使えるようにする
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("🔥 schedulePackingReminders error:", error)
                }
            }
        }
    }

    func removePackingReminder(itemId: String) {
        // ★ 何個あるか分からないため、いったんすべての保留中通知を取得し、
        //   このアイテムに属する識別子（新形式・旧形式どちらも）だけを絞り込んで消す
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0 == "packing_\(itemId)" || $0.hasPrefix("packing_\(itemId)_") }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - 持ち物チェックリストの「その日ぶん揃いました」お知らせ・「まだ揃っていません」警告
    //   ★ 揃った瞬間に鳴らす完了通知は即時発火（未来の予約ではない）。
    //   未完了の警告は指定日の朝に予約しておき、それより前に全部チェックが付いた場合は
    //   PackingChecklistViewModel側でcancelUncheckedWarningを呼んでキャンセルする
    //   （＝実際に発火するのは「その時点でまだ揃っていない場合だけ」という設計）

    func sendPackingAllCheckedNotification(dateKey: String, groupName: String?, itemCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎒 持ち物の準備が完了しました"
        let bodyDetail = "\(itemCount)件すべてにチェックが付きました。準備万端です！"
        content.body = (groupName.flatMap { $0.isEmpty ? nil : $0 }).map { "【\($0)】\(bodyDetail)" } ?? bodyDetail
        content.sound = .default

        let request = UNNotificationRequest(identifier: "packing_complete_\(dateKey)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("🔥 sendPackingAllCheckedNotification error:", error) }
        }
    }

    func scheduleUncheckedWarning(dateKey: String, at date: Date, remainingCount: Int, groupName: String?) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 持ち物、まだ準備できていません"
        let bodyDetail = "あと\(remainingCount)件チェックが付いていません"
        content.body = (groupName.flatMap { $0.isEmpty ? nil : $0 }).map { "【\($0)】\(bodyDetail)" } ?? bodyDetail
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let identifier = "packing_warning_\(dateKey)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("🔥 scheduleUncheckedWarning error:", error) }
        }
    }

    func cancelUncheckedWarning(dateKey: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["packing_warning_\(dateKey)"])
    }
}
