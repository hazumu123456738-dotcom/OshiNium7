//
//  EventViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import Foundation
import Combine
import FirebaseFirestore

final class EventViewModel: ObservableObject {

    @Published private(set) var events: [Event] = []

    // グループ一覧（IdolGroup を使う）
    @Published var groups: [IdolGroup] = []

    // groupId からグループを取得
    func group(for id: String?) -> IdolGroup? {
        guard let id else { return nil }
        return groups.first { $0.id == id }
    }
    // groupId からグループ名を取得（EditEventView 用）
    func groupName(for groupId: String?) -> String {
        guard let groupId = groupId else { return "未設定" }
        return groups.first(where: { $0.id == groupId })?.name ?? "未設定"
    }

    private let db = Firestore.firestore()
    private var normalListener: ListenerRegistration?
    private var secretListener: ListenerRegistration?

    private var normalRetryDelay: TimeInterval = 1
    private var secretRetryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    init() {
        print("DEBUG EventViewModel init")
    }

    deinit {
        normalListener?.remove()
        secretListener?.remove()
    }

    // MARK: - Firestore パス

    private var normalCollection: CollectionReference {
        db.collection("events")
    }

    private var secretCollection: CollectionReference {
        db.collection("privateEvents")
    }

    // MARK: - 単日パース（曜日・カッコ付き対応）

    static func parseDate(_ rawText: String) -> Date? {
        var text = rawText.replacingOccurrences(
            of: #"(\(|（).*?(\)|）)"#,
            with: "",
            options: .regularExpression
        )

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "yyyy.MM.dd",
            "yyyy年M月d日",
            "M月d日",
            "M/d",
            "M.d"
        ]

        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")

        for format in formats {
            f.dateFormat = format
            if let d = f.date(from: text) {
                return d
            }
        }

        return nil
    }

    // MARK: - 範囲日付パース（〜, - など）強化版

    func parseDateRange(_ text: String) -> (Date, Date)? {

        let separators = ["～", "〜", "-", "ー", "to", "→"]
        var parts = [text]

        for sep in separators {
            if text.contains(sep) {
                parts = text.components(separatedBy: sep)
                break
            }
        }

        if parts.count == 1 {
            if let d = Self.parseDate(parts[0].trimmingCharacters(in: .whitespaces)) {
                return (d, d)
            }
            return nil
        }

        let startText = parts[0].trimmingCharacters(in: .whitespaces)
        let endRaw   = parts[1].trimmingCharacters(in: .whitespaces)

        guard let start = Self.parseDate(startText) else {
            return nil
        }

        if let endFull = Self.parseDate(endRaw) {
            return (start, endFull)
        }

        let pattern = #"(\d{1,2})日?"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: endRaw, range: NSRange(location: 0, length: (endRaw as NSString).length)) {

            let dayRange = match.range(at: 1)
            if let range = Range(dayRange, in: endRaw) {
                let dayString = String(endRaw[range])
                if let day = Int(dayString) {
                    let cal = Calendar(identifier: .gregorian)
                    var comps = cal.dateComponents([.year, .month, .day], from: start)
                    comps.day = day
                    if let end = cal.date(from: comps) {
                        return (start, end)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - カンマ区切り複数日付パース（例: 2026年8月4日, 5日, 6日）

    func parseDateList(_ text: String) -> [Date]? {
        let separators: [Character] = [",", "、"]
        guard text.contains(",") || text.contains("、") else { return nil }

        let rawParts = text.split(whereSeparator: { separators.contains($0) })
        let parts = rawParts.map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first,
              let baseDate = Self.parseDate(first) else {
            return nil
        }

        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: baseDate)
        let month = cal.component(.month, from: baseDate)

        var result: [Date] = []

        for (index, p) in parts.enumerated() {
            if index == 0 {
                result.append(baseDate)
                continue
            }

            var textPart = p

            if !textPart.contains("年") && !textPart.contains("月") {
                textPart = "\(year)年\(month)月\(textPart)"
            } else if !textPart.contains("年") && textPart.contains("月") {
                textPart = "\(year)年\(textPart)"
            }

            if let d = Self.parseDate(textPart) {
                result.append(d)
            }
        }

        return result.isEmpty ? nil : result
    }

    // MARK: - AI イベント種別推定（tags: [String] 前提版）

    func inferType(from result: AIEventResult) -> (EventType, EventSubType) {

        let safeTags = result.tags
            .map { $0.lowercased() }
            .joined(separator: " ")

        let base = (result.title + " " + safeTags).lowercased()

        if base.contains("live") ||
           base.contains("concert") ||
           base.contains("ライブ") ||
           base.contains("公演") ||
           base.contains("ステージ") {
            return (.live, .other)
        }

        if base.contains("fanmeeting") ||
           base.contains("ファンミ") ||
           base.contains("ファンミーティング") ||
           base.contains("イベント") ||
           base.contains("event") {
            return (.event, .other)
        }

        if base.contains("発売記念") ||
           base.contains("release") ||
           base.contains("album") ||
           base.contains("single") ||
           base.contains("リリース") ||
           base.contains("発売") {
            return (.release, .other)
        }

        if base.contains("tv") ||
           base.contains("放送") ||
           base.contains("番組") ||
           base.contains("配信") ||
           base.contains("stream") ||
           base.contains("youtube") {
            return (.tv, .other)
        }

        if base.contains("sns") ||
           base.contains("twitter") ||
           base.contains("x ") ||
           base.contains("instagram") ||
           base.contains("tiktok") {
            return (.sns, .other)
        }

        return (.other, .other)
    }

    // MARK: - AI → Event 保存（groupId 完全対応版）

    func addEventFromAI(result: AIEventResult, groupId: String?) {

        let finalGroupId = result.groupId ?? groupId

        let (eventType, eventSubType) = inferType(from: result)

        let year = Calendar.current.component(.year, from: Date())
        let parsed = result.parsedDates(defaultYear: year)

        guard !parsed.isEmpty else {
            print("DEBUG addEventFromAI: failed to parse dateString=\(result.dateString), fallback to today")
            let today = Date()

            let event = Event(
                id: nil,
                title: result.title,
                date: today,
                startDate: nil,
                endDate: nil,
                isSecret: false,
                groupId: finalGroupId,
                type: eventType,
                subType: eventSubType,
                customSubType: nil,
                place: result.location,
                timeText: nil,
                condition: nil,
                applyDate: nil,
                channel: nil,
                programName: nil,
                url: result.officialURL ?? result.thumbnailURL,
                notes: nil,
                notifyBefore: nil,
                openTime: result.openTime,
                startTime: result.startTime,
                endTime: result.endTime,
                access: result.access,
                organizer: result.organizer,
                contact: result.contact,
                officialURL: result.officialURL,
                thumbnailURL: result.thumbnailURL,
                tags: result.tags,
                ticketPrice: result.ticketPrice,
                ticketStartDate: result.ticketStartDate,
                imageURLs: nil
            )

            addEvent(event)
            return
        }

        let limitedDates = Array(parsed.prefix(3))
        print("DEBUG addEventFromAI: parsed dates -> \(limitedDates)")

        for d in limitedDates {
            let event = Event(
                id: nil,
                title: result.title,
                date: d,
                startDate: nil,
                endDate: nil,
                isSecret: false,
                groupId: finalGroupId,
                type: eventType,
                subType: eventSubType,
                customSubType: nil,
                place: result.location,
                timeText: nil,
                condition: nil,
                applyDate: nil,
                channel: nil,
                programName: nil,
                url: result.officialURL ?? result.thumbnailURL,
                notes: nil,
                notifyBefore: nil,
                openTime: result.openTime,
                startTime: result.startTime,
                endTime: result.endTime,
                access: result.access,
                organizer: result.organizer,
                contact: result.contact,
                officialURL: result.officialURL,
                thumbnailURL: result.thumbnailURL,
                tags: result.tags,
                ticketPrice: result.ticketPrice,
                ticketStartDate: result.ticketStartDate,
                imageURLs: nil
            )

            addEvent(event)
        }
    }

    // MARK: - Firestore リスナー

    func startListeners() {
        observeNormalEvents()
        observeSecretEvents()
    }

    func stopListeners() {
        normalListener?.remove()
        secretListener?.remove()
    }

    // MARK: - Firestore デコード

    private func decodeEvent(doc: QueryDocumentSnapshot) -> Event? {
        let data = doc.data()

        let title = data["title"] as? String ?? ""

        let startDate = (data["startDate"] as? Timestamp)?.dateValue()
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()

        let date = startDate ??
            (data["date"] as? Timestamp)?.dateValue() ??
            Date()

        let isSecret = data["isSecret"] as? Bool ?? false

        let typeRaw = data["type"] as? String ?? "other"
        let subTypeRaw = data["subType"] as? String ?? "other"

        let type = EventType(rawValue: typeRaw) ?? .other
        let subType = EventSubType(rawValue: subTypeRaw) ?? .other

        return Event(
            id: doc.documentID,
            title: title,
            date: date,
            startDate: startDate,
            endDate: endDate,
            isSecret: isSecret,
            groupId: data["groupId"] as? String,
            type: type,
            subType: subType,
            customSubType: data["customSubType"] as? String,
            place: data["place"] as? String,
            timeText: data["timeText"] as? String,
            condition: data["condition"] as? String,
            applyDate: data["applyDate"] as? String,
            channel: data["channel"] as? String,
            programName: data["programName"] as? String,
            url: data["url"] as? String,
            notes: data["notes"] as? String,
            notifyBefore: data["notifyBefore"] as? Int,
            openTime: data["openTime"] as? String,
            startTime: data["startTime"] as? String,
            endTime: data["endTime"] as? String,
            access: data["access"] as? String,
            organizer: data["organizer"] as? String,
            contact: data["contact"] as? String,
            officialURL: data["officialURL"] as? String,
            thumbnailURL: data["thumbnailURL"] as? String,
            tags: data["tags"] as? [String],
            ticketPrice: data["ticketPrice"] as? String,
            ticketStartDate: data["ticketStartDate"] as? String,
            imageURLs: data["imageURLs"] as? [String]
        )
    }

    // MARK: - Firestore リアルタイム購読（通常）

    private func observeNormalEvents() {
        normalListener?.remove()
        normalListener = normalCollection
            .order(by: "date")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 通常イベント購読エラー:", error)
                    self.scheduleNormalRetry()
                    return
                }

                let newEvents = snapshot?.documents.compactMap { self.decodeEvent(doc: $0) } ?? []
                self.normalRetryDelay = 1

                Task { @MainActor in
                    self.updateEvents(normal: newEvents)
                }
            }
    }

    // MARK: - Firestore リアルタイム購読（秘密）

    private func observeSecretEvents() {
        secretListener?.remove()
        secretListener = secretCollection
            .order(by: "date")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    print("🔥 秘密イベント購読エラー:", error)
                    self.scheduleSecretRetry()
                    return
                }

                let newEvents = snapshot?.documents.compactMap { self.decodeEvent(doc: $0) } ?? []
                self.secretRetryDelay = 1

                Task { @MainActor in
                    self.updateEvents(secret: newEvents)
                }
            }
    }

    // MARK: - 再接続（指数バックオフ）

    private func scheduleNormalRetry() {
        normalListener?.remove()
        let delay = normalRetryDelay
        normalRetryDelay = min(normalRetryDelay * 2, maxRetryDelay)
        print("DEBUG scheduleNormalRetry in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.observeNormalEvents()
        }
    }

    private func scheduleSecretRetry() {
        secretListener?.remove()
        let delay = secretRetryDelay
        secretRetryDelay = min(secretRetryDelay * 2, maxRetryDelay)
        print("DEBUG scheduleSecretRetry in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.observeSecretEvents()
        }
    }

    // MARK: - 統合（startDate 優先ソート）

    private func updateEvents(normal: [Event]? = nil, secret: [Event]? = nil) {
        var currentNormal = events.filter { !$0.isSecret }
        var currentSecret = events.filter { $0.isSecret }

        if let normal { currentNormal = normal }
        if let secret { currentSecret = secret }

        var dict: [String: Event] = [:]
        for e in currentNormal + currentSecret {
            let key = e.id ?? UUID().uuidString
            dict[key] = e
        }

        let merged = Array(dict.values).sorted {
            ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date)
        }

        self.events = merged
        print("DEBUG updateEvents -> total:", self.events.count)
    }

    // MARK: - Firestore 追加

    func addEvent(_ event: Event) {
        let collection = event.isSecret ? secretCollection : normalCollection

        var data: [String: Any] = [
            "title": event.title,
            "date": Timestamp(date: event.startDate ?? event.date),
            "isSecret": event.isSecret,
            "type": (event.type ?? .other).rawValue,
            "subType": (event.subType ?? .other).rawValue
        ]

        if let s = event.startDate { data["startDate"] = Timestamp(date: s) }
        if let e = event.endDate { data["endDate"] = Timestamp(date: e) }

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        if let v = event.notifyBefore { data["notifyBefore"] = v }

        if let v = event.openTime { data["openTime"] = v }
        if let v = event.startTime { data["startTime"] = v }
        if let v = event.endTime { data["endTime"] = v }
        if let v = event.access { data["access"] = v }
        if let v = event.organizer { data["organizer"] = v }
        if let v = event.contact { data["contact"] = v }
        if let v = event.officialURL { data["officialURL"] = v }
        if let v = event.thumbnailURL { data["thumbnailURL"] = v }
        if let v = event.tags { data["tags"] = v }
        if let v = event.ticketPrice { data["ticketPrice"] = v }
        if let v = event.ticketStartDate { data["ticketStartDate"] = v }
        if let v = event.imageURLs { data["imageURLs"] = v }

        print("DEBUG addEvent -> writing to Firestore:", event.title)

        let docRef = collection.document()

        docRef.setData(data) { error in
            if let error = error {
                print("🔥 Firestore 保存エラー:", error)
                return
            }

            let newId = docRef.documentID
            print("✅ Firestore 保存成功:", event.title, "id:", newId)

            var savedEvent = event
            savedEvent.id = newId

            NotificationManager.shared.scheduleNotifications(
                for: savedEvent,
                userMinutesBefore: event.notifyBefore
            )

            print("🔔 通知登録完了:", savedEvent.title)
        }
    }
    // MARK: - Firestore 追加（ID返却版）
    func addEventReturningEvent(_ event: Event) async -> Event? {

        let collection = event.isSecret ? secretCollection : normalCollection

        var data: [String: Any] = [
            "title": event.title,
            "date": Timestamp(date: event.startDate ?? event.date),
            "isSecret": event.isSecret,
            "type": (event.type ?? .other).rawValue,
            "subType": (event.subType ?? .other).rawValue
        ]

        if let s = event.startDate { data["startDate"] = Timestamp(date: s) }
        if let e = event.endDate { data["endDate"] = Timestamp(date: e) }

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        if let v = event.notifyBefore { data["notifyBefore"] = v }

        if let v = event.openTime { data["openTime"] = v }
        if let v = event.startTime { data["startTime"] = v }
        if let v = event.endTime { data["endTime"] = v }
        if let v = event.access { data["access"] = v }
        if let v = event.organizer { data["organizer"] = v }
        if let v = event.contact { data["contact"] = v }
        if let v = event.officialURL { data["officialURL"] = v }
        if let v = event.thumbnailURL { data["thumbnailURL"] = v }
        if let v = event.tags { data["tags"] = v }
        if let v = event.ticketPrice { data["ticketPrice"] = v }
        if let v = event.ticketStartDate { data["ticketStartDate"] = v }
        if let v = event.imageURLs { data["imageURLs"] = v }

        let docRef = collection.document()

        return await withCheckedContinuation { continuation in
            docRef.setData(data) { error in
                if let error = error {
                    print("🔥 Firestore 保存エラー:", error)
                    continuation.resume(returning: nil)
                    return
                }

                let newId = docRef.documentID
                print("✅ Firestore 保存成功:", event.title, "id:", newId)

                var savedEvent = event
                savedEvent.id = newId

                NotificationManager.shared.scheduleNotifications(
                    for: savedEvent,
                    userMinutesBefore: event.notifyBefore
                )

                continuation.resume(returning: savedEvent)
            }
        }
    }

    // MARK: - Firestore 更新

    func updateEventFull(_ event: Event) {
        guard let id = event.id else {
            print("❌ updateEventFull: event.id が nil")
            return
        }

        let collection = event.isSecret ? secretCollection : normalCollection

        var data: [String: Any] = [
            "title": event.title,
            "date": Timestamp(date: event.startDate ?? event.date),
            "isSecret": event.isSecret,
            "type": (event.type ?? .other).rawValue,
            "subType": (event.subType ?? .other).rawValue
        ]

        if let s = event.startDate { data["startDate"] = Timestamp(date: s) }
        if let e = event.endDate { data["endDate"] = Timestamp(date: e) }

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        if let v = event.notifyBefore { data["notifyBefore"] = v }

        if let v = event.openTime { data["openTime"] = v }
        if let v = event.startTime { data["startTime"] = v }
        if let v = event.endTime { data["endTime"] = v }
        if let v = event.access { data["access"] = v }
        if let v = event.organizer { data["organizer"] = v }
        if let v = event.contact { data["contact"] = v }
        if let v = event.officialURL { data["officialURL"] = v }
        if let v = event.thumbnailURL { data["thumbnailURL"] = v }
        if let v = event.tags { data["tags"] = v }
        if let v = event.ticketPrice { data["ticketPrice"] = v }
        if let v = event.ticketStartDate { data["ticketStartDate"] = v }
        if let v = event.imageURLs { data["imageURLs"] = v }

        print("DEBUG updateEventFull -> updating Firestore:", event.title, "id:", id)

        collection.document(id).setData(data, merge: true) { error in
            if let error = error {
                print("🔥 Firestore 更新エラー:", error)
                return
            }

            print("✅ Firestore 更新成功:", event.title)

            NotificationManager.shared.removeNotifications(for: id)

            NotificationManager.shared.scheduleNotifications(
                for: event,
                userMinutesBefore: event.notifyBefore
            )
        }
    }

    // MARK: - Firestore 削除

    func deleteEvent(_ event: Event) {
        guard let id = event.id else {
            print("❌ deleteEvent: event.id が nil")
            return
        }

        let collection = event.isSecret ? secretCollection : normalCollection

        print("DEBUG deleteEvent -> deleting from Firestore:", event.title, "id:", id)

        collection.document(id).delete { [weak self] error in
            if let error = error {
                print("🔥 Firestore 削除エラー:", error)
                return
            }

            print("🗑️ Firestore 削除成功:", event.title)

            NotificationManager.shared.removeNotifications(for: id)

            Task { @MainActor in
                self?.events.removeAll { $0.id == id }
            }
        }
    }
}

// MARK: - 日付ごとのイベント辞書

extension EventViewModel {
    var eventsByDate: [Date: [Event]] {
        var dict: [Date: [Event]] = [:]
        let calendar = Calendar.current

        for event in events {
            let day = calendar.startOfDay(for: event.date)
            dict[day, default: []].append(event)
        }
        return dict
    }
}
