//
//  EventKitManager.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/23.
//

import EventKit

class EventKitManager {
    static let shared = EventKitManager()
    private let store = EKEventStore()

    // MARK: - iOS17対応の権限リクエスト
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted
            } catch {
                print("❌ カレンダー権限エラー:", error.localizedDescription)
                return false
            }
        } else {
            do {
                let granted = try await store.requestAccess(to: .event)
                return granted
            } catch {
                print("❌ カレンダー権限エラー:", error.localizedDescription)
                return false
            }
        }
    }

    // MARK: - カレンダー保存
    func addEvent(title: String, startDate: Date, endDate: Date, location: String?) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)
    }
}
