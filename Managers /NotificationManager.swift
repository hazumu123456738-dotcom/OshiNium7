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

    // MARK: - 事前通知（24時間前＋ユーザー設定）
    func scheduleNotifications(for event: Event, userMinutesBefore: Int?) {

        // 24時間前
        scheduleSingleNotification(event, minutesBefore: 1440)

        // ユーザー設定
        if let userMinutesBefore {
            scheduleSingleNotification(event, minutesBefore: userMinutesBefore)
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

            UNUserNotificationCenter.current().add(request)
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

            UNUserNotificationCenter.current().add(request)
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
}
