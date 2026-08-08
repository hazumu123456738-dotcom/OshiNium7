//
//  EventViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

final class EventViewModel: ObservableObject {

    @Published private(set) var events: [Event] = []

    // 日付ごとのイベント辞書（events が更新されたときだけ再計算するキャッシュ）
    @Published private(set) var eventsByDate: [Date: [Event]] = [:]

    // グループ一覧（IdolGroup を使う）
    @Published var groups: [IdolGroup] = []

    // ★ 登録している（参加している）グループの予定だけに絞った日付辞書。推し活の金額計算・
    //   持ち物チェックリストのカレンダーで、未参加グループの予定まで混ざって見えてしまう
    //   問題を避けるために使う（eventsByDate自体はアプリ全体の予定を無絞り込みで持つ）
    var myEventsByDate: [Date: [Event]] {
        let myGroupIds = Set(groups.map(\.id))
        var result: [Date: [Event]] = [:]
        for (day, dayEvents) in eventsByDate {
            let filtered = dayEvents.filter { myGroupIds.contains($0.groupId ?? "") }
            if !filtered.isEmpty { result[day] = filtered }
        }
        return result
    }

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
                notifyOffsets: nil,
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
                notifyOffsets: nil,
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
            creatorUid: data["creatorUid"] as? String,
            groupId: data["groupId"] as? String,
            calendarId: data["calendarId"] as? String,
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
            // ★ 旧フィールド（単一値のnotifyBefore）が残っている既存データも1件の配列として読み込む
            notifyOffsets: (data["notifyOffsets"] as? [Int]) ?? (data["notifyBefore"] as? Int).map { [$0] },
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
            imageURLs: data["imageURLs"] as? [String],
            deletedAt: (data["deletedAt"] as? Timestamp)?.dateValue()
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
    //   ★ 秘密イベントは登録した本人にしか見せてはいけないため、Firestoreクエリの時点で
    //     creatorUidが自分のものだけに絞り込む（クライアントに他人の秘密イベントを
    //     一切ダウンロードさせない）。orderByをwhereFieldと組み合わせると複合インデックスが
    //     必要になるため、並び替えはupdateEvents側の既存のソートに任せる。
    private func observeSecretEvents() {
        secretListener?.remove()

        guard let uid = Auth.auth().currentUser?.uid else {
            Task { @MainActor in
                self.updateEvents(secret: [])
            }
            return
        }

        secretListener = secretCollection
            .whereField("creatorUid", isEqualTo: uid)
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

        // ★ ソフトデリート済み（deletedAtが設定されている）ものは、通常のカレンダー表示からは
        //   常に除外する。復元可能な間も「消した予定」一覧側からしか見えないようにするため
        let merged = Array(dict.values)
            .filter { $0.deletedAt == nil }
            .sorted {
                ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date)
            }

        self.events = merged
        self.eventsByDate = Self.buildEventsByDate(merged)
        print("DEBUG updateEvents -> total:", self.events.count)
    }

    private static func buildEventsByDate(_ events: [Event]) -> [Date: [Event]] {
        let calendar = Calendar.current
        var dict: [Date: [Event]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.date)
            dict[day, default: []].append(event)
        }
        return dict
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

        // ★ 荒らし対策：予定は誰でも自由に追加できるが、後から編集・削除できるのは
        //   「追加した本人」と「グループの管理者・オーナー」だけ、というルールにするため、
        //   秘密イベントに限らずコミュニティカレンダーの予定にも必ず作成者uidを持たせる
        //   （firestore.rulesのevents/privateEventsコレクションがこのcreatorUidで判定する）
        if let uid = Auth.auth().currentUser?.uid {
            data["creatorUid"] = uid
        }

        if let s = event.startDate { data["startDate"] = Timestamp(date: s) }
        if let e = event.endDate { data["endDate"] = Timestamp(date: e) }

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.calendarId { data["calendarId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        if let v = event.notifyOffsets, !v.isEmpty { data["notifyOffsets"] = v }

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
                userMinutesBeforeList: event.notifyOffsets ?? []
            )

            print("🔔 通知登録完了:", savedEvent.title)

            self.announceEventCreated(savedEvent)
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

        // ★ 荒らし対策：予定は誰でも自由に追加できるが、後から編集・削除できるのは
        //   「追加した本人」と「グループの管理者・オーナー」だけ、というルールにするため、
        //   秘密イベントに限らずコミュニティカレンダーの予定にも必ず作成者uidを持たせる
        //   （firestore.rulesのevents/privateEventsコレクションがこのcreatorUidで判定する）
        if let uid = Auth.auth().currentUser?.uid {
            data["creatorUid"] = uid
        }

        if let s = event.startDate { data["startDate"] = Timestamp(date: s) }
        if let e = event.endDate { data["endDate"] = Timestamp(date: e) }

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.calendarId { data["calendarId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        if let v = event.notifyOffsets, !v.isEmpty { data["notifyOffsets"] = v }

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
                    userMinutesBeforeList: event.notifyOffsets ?? []
                )

                self.announceEventCreated(savedEvent)

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

        // ★ 更新時はcreatorUidを書き換えない（管理者が他人の予定を修正しても、
        //   作成者名義が管理者に奪われないようにするため）。秘密イベントのみ、
        //   念のため本人のuidで上書きしておく
        if event.isSecret, let uid = Auth.auth().currentUser?.uid {
            data["creatorUid"] = uid
        }

        if let s = event.startDate { data["startDate"] = Timestamp(date: s) }
        if let e = event.endDate { data["endDate"] = Timestamp(date: e) }

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.calendarId { data["calendarId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        if let v = event.notifyOffsets, !v.isEmpty { data["notifyOffsets"] = v }

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
                userMinutesBeforeList: event.notifyOffsets ?? []
            )
        }
    }

    // MARK: - コピー（複数日付・別カレンダー対応）

    func duplicateEvent(_ event: Event, toCalendarId: String, dates: [Date]) {
        for d in dates {
            var copy = event
            copy.id = nil
            copy.date = d
            copy.startDate = nil
            copy.endDate = nil
            copy.calendarId = toCalendarId
            addEvent(copy)
        }
    }

    // MARK: - Firestore 削除（ソフトデリート）
    //   ★ 以前は実際にドキュメントを削除していたが、「消してから3日以内なら復元できる」
    //     要望に合わせ、deletedAtを立てるだけのソフトデリートに変更した。
    //     通常のカレンダー表示からはupdateEvents()のフィルタで除外されるため、
    //     見た目上は今まで通り即座に消えたように見える

    func deleteEvent(_ event: Event) {
        guard let id = event.id else {
            print("❌ deleteEvent: event.id が nil")
            return
        }

        let collection = event.isSecret ? secretCollection : normalCollection

        print("DEBUG deleteEvent -> soft deleting:", event.title, "id:", id)

        collection.document(id).updateData(["deletedAt": Timestamp(date: Date())]) { [weak self] error in
            if let error = error {
                print("🔥 Firestore 削除エラー:", error)
                return
            }

            print("🗑️ Firestore ソフトデリート成功:", event.title)

            NotificationManager.shared.removeNotifications(for: id)

            self?.announceEventDeleted(event)

            Task { @MainActor [weak self] in
                self?.events.removeAll { $0.id == id }
            }
        }
    }

    // ★ 「消した予定」一覧からの復元。deletedAtを取り除くだけで、あとはリスナーが
    //   自動的に拾い直して通常のカレンダー表示に戻す
    func restoreEvent(_ event: Event, completion: @escaping (Error?) -> Void = { _ in }) {
        guard let id = event.id else { return }
        let collection = event.isSecret ? secretCollection : normalCollection
        collection.document(id).updateData(["deletedAt": FieldValue.delete()]) { error in
            if let error {
                print("🔥 restoreEvent error:", error)
            }
            completion(error)
        }
    }

    // ★ 「消した予定」一覧の中身。deletedAtが3日以内のものだけを対象にする一度きりの取得
    //   （常時購読するほどではない画面のため、リスナーではなくgetDocumentsで十分）。
    //   通常予定のクエリ（events）は絞り込み条件なしでも読める権限のため、単一フィールドの
    //   範囲検索だけで完結させ、グループ等の絞り込みはクライアント側で行う（複合インデックス回避）
    func fetchRecentlyDeletedEvents(completion: @escaping ([Event]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        let threeDaysAgo = Timestamp(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date())

        let group = DispatchGroup()
        var normalResults: [Event] = []
        var secretResults: [Event] = []

        // ★ eventsコレクション自体はグループ絞り込み無しで読める権限のため（メインの購読と同じ設計）、
        //   ここでも取得後に「自分が参加しているグループ」だけへクライアント側で絞り込む
        let myGroupIds = Set(self.groups.map(\.id))

        group.enter()
        normalCollection
            .whereField("deletedAt", isGreaterThan: threeDaysAgo)
            .getDocuments { snapshot, error in
                if let error { print("🔥 fetchRecentlyDeletedEvents(normal) error:", error) }
                let all = snapshot?.documents.compactMap { self.decodeEvent(doc: $0) } ?? []
                normalResults = all.filter { myGroupIds.contains($0.groupId ?? "") }
                group.leave()
            }

        group.enter()
        secretCollection
            .whereField("creatorUid", isEqualTo: uid)
            .getDocuments { snapshot, error in
                if let error { print("🔥 fetchRecentlyDeletedEvents(secret) error:", error) }
                let allMine = snapshot?.documents.compactMap { self.decodeEvent(doc: $0) } ?? []
                secretResults = allMine.filter { event in
                    guard let deletedAt = event.deletedAt else { return false }
                    return deletedAt >= threeDaysAgo.dateValue()
                }
                group.leave()
            }

        group.notify(queue: .main) {
            let merged = (normalResults + secretResults).sorted {
                ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
            }
            completion(merged)
        }
    }

    // MARK: - グループ連携（コミュニティカレンダーの予定追加・削除をグループチャット／通知に流す）
    //   ★ 秘密の予定（isSecret）は本人にしか見えないものなので、グループには一切知らせない。
    //     groupIdが無い（どのグループにも属さない）予定も同様に対象外とする。
    //   ★ 表示名・アイコンは users/{uid} が大元のソース（ChatViewModel.fetchUserProfileと同じ考え方）

    private func announceEventCreated(_ event: Event) {
        guard !event.isSecret, let groupId = event.groupId, let uid = Auth.auth().currentUser?.uid else { return }
        let groupName = groupName(for: groupId)

        Task {
            let profile = await ChatViewModel.fetchUserProfile(uid: uid)
            let actorName = profile?.displayName ?? "名無しさん"

            ChatViewModel.postSystemMessage(
                groupId: groupId,
                text: "🗓️ 新しい予定が追加されました\n「\(event.title)」\n📅 \(Self.chatDateLabel(for: event))"
            )

            AppNotificationViewModel.notifyEventCreated(
                groupId: groupId,
                groupName: groupName,
                eventId: event.id,
                eventTitle: event.title,
                actorUid: uid,
                actorName: actorName,
                actorIconURL: profile?.iconURL
            )
        }
    }

    private func announceEventDeleted(_ event: Event) {
        guard !event.isSecret, let groupId = event.groupId, let uid = Auth.auth().currentUser?.uid else { return }
        let groupName = groupName(for: groupId)

        Task {
            let profile = await ChatViewModel.fetchUserProfile(uid: uid)
            let actorName = profile?.displayName ?? "名無しさん"

            ChatViewModel.postSystemMessage(
                groupId: groupId,
                text: "🗑️ 予定が削除されました\n「\(event.title)」\n📅 \(Self.chatDateLabel(for: event))"
            )

            AppNotificationViewModel.notifyEventDeleted(
                groupId: groupId,
                groupName: groupName,
                eventTitle: event.title,
                actorUid: uid,
                actorName: actorName,
                actorIconURL: profile?.iconURL
            )
        }
    }

    // ★ グループチャットのお知らせに添える「いつの予定か」の表示（例: 8/18(火) 18:00）
    private static func chatDateLabel(for event: Event) -> String {
        let target = event.startDate ?? event.date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) HH:mm"
        return formatter.string(from: target)
    }
}
