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
    // ★ 参加グループが変わるたびに、通常イベントの購読をそのグループ集合だけに
    //   絞り込んで張り直す（observeNormalEvents参照）。パフォーマンス改善のため
    //   （後述）、実際に集合が変わった時だけ張り直す
    @Published var groups: [IdolGroup] = [] {
        didSet {
            let newIds = Set(groups.map(\.id))
            guard newIds != lastObservedGroupIds else { return }
            lastObservedGroupIds = newIds
            observeNormalEvents()
        }
    }
    private var lastObservedGroupIds: Set<String> = []

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
        Self.decodeEvent(id: doc.documentID, data: doc.data())
    }

    // ★ 共有リンク(SharedEventLinkView)からdocument(eventId)を単発取得する場合にも
    //   同じデコードロジックを使い回せるよう、インスタンスに依存しない形で切り出す
    //
    // ★ 2026/08/15追加：コミュニティカレンダーの予定編集は「編集した本人のカレンダーにのみ
    //   反映する」仕様のため、EditEventViewは共有ドキュメントの本体フィールドを直接上書きせず、
    //   personalEdits.{uid}という自分専用のマップにだけ編集後の内容を書き込む
    //   (Views/EditEventView.swift参照)。デコード時はここで、自分のuidに対応する
    //   personalEditsがあればそちらの値を優先して使い、無ければ元のフィールド
    //   （＝まだ誰も編集していない、追加者や他メンバーと共通の内容）を使う。
    //   これにより「同じ1件のドキュメントなのに、読む人によって見える内容が変わる」を実現する
    static func decodeEvent(id: String, data rawData: [String: Any]) -> Event? {
        var data = rawData
        if let myUid = Auth.auth().currentUser?.uid,
           let personalEdits = rawData["personalEdits"] as? [String: [String: Any]],
           let myEdit = personalEdits[myUid] {
            data.merge(myEdit) { _, new in new }
        }

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
            id: id,
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
            deletedAt: (data["deletedAt"] as? Timestamp)?.dateValue(),
            approvedBy: data["approvedBy"] as? [String] ?? [],
            creatorName: data["creatorName"] as? String,
            dismissedBy: data["dismissedBy"] as? [String] ?? [],
            dismissedAt: (data["dismissedAt"] as? [String: Timestamp])?.mapValues { $0.dateValue() } ?? [:],
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    // MARK: - Firestore リアルタイム購読（通常）
    //   ★ パフォーマンス改善（2026-08-08）：以前はwhereFieldの絞り込みが一切無く、
    //   アプリ全体・全ユーザー分のeventsコレクションを丸ごと購読していた（ログイン直後の
    //   表示が遅い最大の原因）。実際に使う側は必ずどこか1つのグループのイベントに絞り込んで
    //   から表示しているため、購読の時点で自分の参加グループだけに絞り込む。
    //   FirestoreのwhereField(in:)は最大30件までのため、参加グループ数の上限
    //   （プレミアムでも5件、SubscriptionManager参照）を大きく下回り安全に収まる
    private func observeNormalEvents() {
        normalListener?.remove()

        let groupIds = Array(lastObservedGroupIds.prefix(30))
        guard !groupIds.isEmpty else {
            // ★ 参加グループが無い（または未取得）間はクエリ自体を張らず、
            //   一覧を空のまま確定させる（groupIds.isEmpty以外の理由で
            //   購読していないと誤解しないよう、明示的にclearする）
            Task { @MainActor in
                self.updateEvents(normal: [])
            }
            return
        }

        normalListener = normalCollection
            .whereField("groupId", in: groupIds)
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
    // ★ 2026/08/16追加：真にオフラインの間はNetworkMonitor.retryWhenOnlineで
    //   実際のリスナー張り直しを繰り返さない(体感的な「カクつき」対策)

    private func scheduleNormalRetry() {
        normalListener?.remove()
        let delay = normalRetryDelay
        normalRetryDelay = min(normalRetryDelay * 2, maxRetryDelay)
        print("DEBUG scheduleNormalRetry in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeNormalEvents() }
        }
    }

    private func scheduleSecretRetry() {
        secretListener?.remove()
        let delay = secretRetryDelay
        secretRetryDelay = min(secretRetryDelay * 2, maxRetryDelay)
        print("DEBUG scheduleSecretRetry in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            NetworkMonitor.retryWhenOnline { self?.observeSecretEvents() }
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

    func addEvent(_ event: Event, completion: ((Error?) -> Void)? = nil) {
        let collection = event.isSecret ? secretCollection : normalCollection

        var data: [String: Any] = [
            "title": event.title,
            "date": Timestamp(date: event.startDate ?? event.date),
            "isSecret": event.isSecret,
            "type": (event.type ?? .other).rawValue,
            "subType": (event.subType ?? .other).rawValue,
            // ★ 承認待ちバッジを「未確認件数」として出すための作成日時
            "createdAt": Timestamp(date: Date())
        ]

        // ★ 荒らし対策：予定は誰でも自由に追加できるが、後から編集・削除できるのは
        //   「追加した本人」と「グループの管理者・オーナー」だけ、というルールにするため、
        //   秘密イベントに限らずコミュニティカレンダーの予定にも必ず作成者uidを持たせる
        //   （firestore.rulesのevents/privateEventsコレクションがこのcreatorUidで判定する）
        if let uid = Auth.auth().currentUser?.uid {
            data["creatorUid"] = uid
            // ★ コミュニティカレンダーの承認制：追加した本人は自動で承認済みにする
            //   （他メンバーの承認待ち一覧には出さない。個人・共有カレンダーの予定でも
            //   書いておいて害はないため、常に書き込む）
            data["approvedBy"] = [uid]
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
                completion?(error)
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
            completion?(nil)
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
            "subType": (event.subType ?? .other).rawValue,
            // ★ 承認待ちバッジを「未確認件数」として出すための作成日時
            "createdAt": Timestamp(date: Date())
        ]

        // ★ 荒らし対策：予定は誰でも自由に追加できるが、後から編集・削除できるのは
        //   「追加した本人」と「グループの管理者・オーナー」だけ、というルールにするため、
        //   秘密イベントに限らずコミュニティカレンダーの予定にも必ず作成者uidを持たせる
        //   （firestore.rulesのevents/privateEventsコレクションがこのcreatorUidで判定する）
        if let uid = Auth.auth().currentUser?.uid {
            data["creatorUid"] = uid
            // ★ コミュニティカレンダーの承認制：追加した本人は自動で承認済みにする
            data["approvedBy"] = [uid]
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
        // ★ ドキュメントIDはsetData()を呼ぶ前から確定しているため、応答を待たずに
        //   組み立てておける（タイムアウト時にもこのIDでEventを返せるようにするため）
        var savedEvent = event
        savedEvent.id = docRef.documentID

        // ★ 2026/08/18追加（ユーザー報告）：以前はここに待ち時間の上限が無く、
        //   通信が不安定な間はsetData()の応答が返ってこないまま「保存中」の画面が
        //   無期限に固まって見えていた。setData()自体はこの呼び出し時点でSDKの
        //   ローカルキューに積まれ、繋がり次第自動送信されるため、応答確認を
        //   一定時間で諦めても投稿データが失われるわけではない
        let error = await NetworkMonitor.awaitWithTimeout { completion in
            docRef.setData(data) { error in
                if let error = error {
                    print("🔥 Firestore 保存エラー:", error)
                } else {
                    print("✅ Firestore 保存成功:", event.title, "id:", docRef.documentID)
                    NotificationManager.shared.scheduleNotifications(
                        for: savedEvent,
                        userMinutesBeforeList: event.notifyOffsets ?? []
                    )
                    self.announceEventCreated(savedEvent)
                }
                completion(error)
            }
        }

        return error == nil ? savedEvent : nil
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

    // ★ /ult監査で発見：以前はaddEvent(copy)を完了を待たずに呼びっぱなしにしており、
    //   書き込みが失敗しても(オフライン・権限エラー等)呼び出し元(CopyEventView)は
    //   即座に「コピーしました」と表示していた。全件の書き込み結果を待ってから
    //   1件でも失敗があればエラーとして返すようにする
    func duplicateEvent(_ event: Event, toCalendarId: String, dates: [Date], completion: ((Error?) -> Void)? = nil) {
        guard !dates.isEmpty else {
            completion?(nil)
            return
        }

        var firstError: Error?
        let group = DispatchGroup()

        for d in dates {
            var copy = event
            copy.id = nil
            copy.date = d
            copy.startDate = nil
            copy.endDate = nil
            copy.calendarId = toCalendarId

            group.enter()
            addEvent(copy) { error in
                if let error, firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion?(firstError)
        }
    }

    // MARK: - Firestore 削除（ソフトデリート）
    //   ★ 以前は実際にドキュメントを削除していたが、「消してから3日以内なら復元できる」
    //     要望に合わせ、deletedAtを立てるだけのソフトデリートに変更した。
    //     通常のカレンダー表示からはupdateEvents()のフィルタで除外されるため、
    //     見た目上は今まで通り即座に消えたように見える

    // ★ コミュニティカレンダーの予定は「誰か1人の削除」が他のメンバー全員のカレンダーに
    //   影響してはいけない（承認/削除が一人ひとり個別の判断、というこの画面全体の設計と矛盾するため）。
    //   approvedByから自分のUIDを外し、dismissedByに足すことで「自分のカレンダーからだけ」消え、
    //   予定そのもの（Firestoreドキュメント）や他メンバーの表示には一切触れない。
    //   個人・共有カレンダーの予定は元々自分にしか見えていないため、従来通り本当に削除する
    func deleteEvent(_ event: Event) {
        guard let id = event.id else {
            print("❌ deleteEvent: event.id が nil")
            return
        }

        let collection = event.isSecret ? secretCollection : normalCollection

        // ★ isSecretの予定はcalendarIdがnilになりうる（コミュニティを選択中の画面から
        //   「本人のみ表示」で追加した場合など）。isSecretを見ずにcalendarId==nilだけで
        //   分岐すると、秘密の予定の削除がapprovedBy/dismissedByを書き換えるだけの
        //   個人スコープ削除に誤ってフォールバックし、実際には何も消えなくなる不具合になる
        if !event.isSecret, let groupId = event.groupId,
           event.calendarId == nil || event.calendarId == "\(groupId)_community" {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            collection.document(id).updateData([
                "approvedBy": FieldValue.arrayRemove([uid]),
                "dismissedBy": FieldValue.arrayUnion([uid]),
                "dismissedAt.\(uid)": Timestamp(date: Date())
            ]) { error in
                if let error {
                    print("🔥 deleteEvent(community, 自分のカレンダーからのみ) error:", error)
                    CrashReportManager.recordNonFatal(error)
                    return
                }
                NotificationManager.shared.removeNotifications(for: id)
            }
            return
        }

        print("DEBUG deleteEvent -> soft deleting:", event.title, "id:", id)

        collection.document(id).updateData(["deletedAt": Timestamp(date: Date())]) { [weak self] error in
            if let error = error {
                print("🔥 Firestore 削除エラー:", error)
                return
            }

            print("🗑️ Firestore ソフトデリート成功:", event.title)

            NotificationManager.shared.removeNotifications(for: id)

            Task { @MainActor [weak self] in
                self?.events.removeAll { $0.id == id }
            }
        }
    }

    // ★ 「消した予定」一覧からの復元。
    //   個人・共有カレンダーの予定（本当にdeletedAtが立っている）はdeletedAtを取り除くだけで、
    //   あとはリスナーが自動的に拾い直して通常のカレンダー表示に戻る。
    //   コミュニティカレンダーの予定はdeleteEvent側と対称に、dismissedByから自分のuidを外し、
    //   approvedByへ戻し、dismissedAt.{uid}を消すことで元の「承認済み」状態に復元する
    func restoreEvent(_ event: Event, completion: @escaping (Error?) -> Void = { _ in }) {
        guard let id = event.id else { return }
        let collection = event.isSecret ? secretCollection : normalCollection

        if event.deletedAt != nil {
            collection.document(id).updateData(["deletedAt": FieldValue.delete()]) { error in
                if let error {
                    print("🔥 restoreEvent error:", error)
                    CrashReportManager.recordNonFatal(error)
                }
                completion(error)
            }
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        collection.document(id).updateData([
            "approvedBy": FieldValue.arrayUnion([uid]),
            "dismissedBy": FieldValue.arrayRemove([uid]),
            "dismissedAt.\(uid)": FieldValue.delete()
        ]) { error in
            if let error {
                print("🔥 restoreEvent(community) error:", error)
                CrashReportManager.recordNonFatal(error)
            }
            completion(error)
        }
    }

    // ★ 「消した予定」一覧の中身。deletedAt/dismissedAt[uid]が3日以内のものだけを対象にする
    //   一度きりの取得（常時購読するほどではない画面のため、リスナーではなくgetDocumentsで十分）。
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
        var communityDismissedResults: [Event] = []
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

        // ★ コミュニティカレンダーの予定は「カレンダーから削除」してもdeletedAtは立たず、
        //   dismissedAt.{uid}にだけ記録される（deleteEvent参照）。この経路の削除もここに含める
        group.enter()
        normalCollection
            .whereField("dismissedAt.\(uid)", isGreaterThan: threeDaysAgo)
            .getDocuments { snapshot, error in
                if let error { print("🔥 fetchRecentlyDeletedEvents(communityDismissed) error:", error) }
                let all = snapshot?.documents.compactMap { self.decodeEvent(doc: $0) } ?? []
                communityDismissedResults = all.filter { myGroupIds.contains($0.groupId ?? "") }
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
            let merged = (normalResults + communityDismissedResults + secretResults).sorted {
                ($0.effectiveDeletedAt(for: uid) ?? .distantPast) > ($1.effectiveDeletedAt(for: uid) ?? .distantPast)
            }
            completion(merged)
        }
    }

    // MARK: - コミュニティカレンダーの承認制

    // ★ グループの誰かがコミュニティカレンダーに追加した予定を「承認」する。
    //   承認済みユーザーの配列にuidを足すだけ（arrayUnion）で、拒否という状態は存在しない。
    //   承認しない場合は何もしなければ良く、pendingApprovalEvents(groupId:)にいつまでも残り続ける
    // ★ 2026/08/16修正：completionが無く、呼び出し元(EventApprovalListView)は書き込みの
    //   成否を待たずに「承認済み」として一覧から消していた。一時的な通信エラーで書き込みが
    //   実際には失敗すると、approvedByが更新されないためカレンダーにも反映されないまま
    //   「承認待ち一覧からは消えた」状態になり、予定が事実上消失したように見えていた
    func approveEvent(_ event: Event, completion: ((Error?) -> Void)? = nil) {
        guard let eventId = event.id, let uid = Auth.auth().currentUser?.uid else { return }
        let collection = event.isSecret ? secretCollection : normalCollection
        collection.document(eventId).updateData([
            "approvedBy": FieldValue.arrayUnion([uid])
        ]) { error in
            if let error {
                print("🔥 approveEvent error:", error)
                CrashReportManager.recordNonFatal(error)
            }
            completion?(error)
        }

        // ★ 承認待ち一覧画面で「承認済み」として一定期間(10日)積み重ね表示し続けるための記録。
        //   以前は画面を閉じると消える@State止まりだったが、再度開いても残ってほしいという
        //   要望を受けてFirestoreに記録するようにした。ドキュメントIDをeventIdにすることで
        //   何度呼ばれても1件に収束する(重複記録の心配がない)
        if let groupId = event.groupId {
            Firestore.firestore()
                .collection("users").document(uid)
                .collection("approvalLog").document(eventId)
                .setData([
                    "approvedAt": Timestamp(date: Date()),
                    "groupId": groupId
                ]) { error in
                    if let error {
                        print("🔥 approvalLog書き込みエラー:", error)
                    }
                }
        }
    }

    // ★ 直近10日以内に自分が承認した予定一覧（承認待ち画面の「承認済み」積み重ね表示用）。
    //   approvalLogはeventIdだけの軽い記録のため、実際のEvent本体はここで
    //   すでに購読済みのeventsから引き当てる(二重にイベント情報を持たない)
    func fetchRecentlyApprovedEvents(groupId: String, completion: @escaping ([Event]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()

        Firestore.firestore()
            .collection("users").document(uid)
            .collection("approvalLog")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("approvedAt", isGreaterThan: Timestamp(date: tenDaysAgo))
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 approvalLog取得エラー:", error)
                    completion([])
                    return
                }
                let ids = Set((snapshot?.documents ?? []).map { $0.documentID })
                let matched = self.events.filter { ids.contains($0.id ?? "") }
                completion(matched)
            }
    }

    // ★ 承認待ち一覧の「削除」。approvedByと同じ配列方式で、自分のUIDをdismissedByに
    //   足すだけ。これで二度とpendingApprovalEvents(groupId:)に出てこなくなる
    //   （他メンバーのdismissedByには影響しない、あくまで個人の意思表示）
    //   ★ 2026/08/15修正：dismissedAt.{uid}を立てていなかったため、承認待ち画面から
    //     「削除」した予定がfetchRecentlyDeletedEvents（＝カレンダー管理メニューの
    //     「削除済みの予定」画面、3日以内なら復元できる）に一切出てこなかった。
    //     承認済みの予定を削除する場合（deleteEvent）と同じdismissedAt付与に揃えることで、
    //     承認待ち・承認済みのどちらの「削除」も同じ「削除済みの予定」画面から復元できるようにする
    func dismissApprovalEvent(_ event: Event, completion: ((Error?) -> Void)? = nil) {
        guard let eventId = event.id, let uid = Auth.auth().currentUser?.uid else { return }
        let collection = event.isSecret ? secretCollection : normalCollection
        collection.document(eventId).updateData([
            "dismissedBy": FieldValue.arrayUnion([uid]),
            "dismissedAt.\(uid)": Timestamp(date: Date())
        ]) { error in
            if let error {
                print("🔥 dismissApprovalEvent error:", error)
                CrashReportManager.recordNonFatal(error)
            }
            completion?(error)
        }
    }

    // ★ 指定グループのコミュニティカレンダーの予定のうち、自分がまだ承認していないもの一覧。
    //   一度「あとで判断する」を選んでも消えず、常にここに残る（＝拒否＝完全削除ではない）。
    //   「削除」でdismissedByに自分のUIDが入った予定だけは、以後ここに出てこなくなる。
    //   すでに日付が過ぎた予定は表示から自動的に外れる
    func pendingApprovalEvents(groupId: String) -> [Event] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let communityCalendarId = "\(groupId)_community"
        let startOfToday = Calendar.current.startOfDay(for: Date())

        return events.filter { event in
            guard event.groupId == groupId, !event.isSecret, event.deletedAt == nil else { return false }
            guard event.calendarId == nil || event.calendarId == communityCalendarId else { return false }
            guard !event.approvedBy.contains(uid), event.creatorUid != uid else { return false }
            guard !event.dismissedBy.contains(uid) else { return false }
            let eventDate = event.startDate ?? event.date
            return eventDate >= startOfToday
        }
        .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
    }

    // MARK: - 承認待ちバッジ（未確認件数）
    //   ★ 2026/08/15追加：以前はpendingApprovalEvents(groupId:).countをそのままバッジに出しており、
    //   「承認待ちの予定」画面を一度開いて中身を見ても、実際に承認/削除しない限りバッジの数字が
    //   消えなかった（ユーザー報告：確認済みなのに「1」が表示され続ける）。
    //   このバッジは「未確認の件数」を示す表示のはずなので、画面を開いた時点を
    //   端末のUserDefaultsに記録し、その時刻より後に作られた予定だけを数えるようにする。
    //   createdAtが無い（この修正より前に作られた）予定は常に既読扱いとし、安全側に倒す。

    private func pendingApprovalCheckedKey(groupId: String, uid: String) -> String {
        "pendingApprovalLastCheckedAt_\(uid)_\(groupId)"
    }

    /// 「承認待ちの予定」画面を開いた時点を記録する。以後、この時刻より前に作られた予定は
    /// バッジの未確認件数に数えない（画面自体には引き続き表示され続ける＝承認/削除は別の話）。
    func markPendingApprovalChecked(groupId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        UserDefaults.standard.set(Date(), forKey: pendingApprovalCheckedKey(groupId: groupId, uid: uid))
    }

    /// カレンダー管理メニュー等に出す「未確認の承認待ち件数」。
    func unseenPendingApprovalCount(groupId: String) -> Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }
        let lastChecked = UserDefaults.standard.object(forKey: pendingApprovalCheckedKey(groupId: groupId, uid: uid)) as? Date
        return pendingApprovalEvents(groupId: groupId).filter { event in
            guard let createdAt = event.createdAt else { return false }
            guard let lastChecked else { return true }
            return createdAt > lastChecked
        }.count
    }

    // ★ 2026/08/11追加：ホーム画面・オシニウムタブなど、特定のカレンダー選択に紐づかず
    //   「自分が今見られる予定」をまとめて扱いたい画面向けの共通フィルタ。
    //   コミュニティカレンダーの予定は自分が承認した（＝approvedByに自分が入っている）ものだけ、
    //   個人・共有カレンダーの予定は常に含める（承認制の対象外）。
    //   MonthlyCalendarView.isApprovedForMeと同じ判定をここに集約し、各画面での実装コピーによる
    //   フィルタ漏れ（＝カレンダータブでは出ないのにホームには出る、という食い違い）を防ぐ
    func myVisibleEvents(groupId: String) -> [Event] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let communityCalendarId = "\(groupId)_community"

        return events.filter { event in
            guard event.groupId == groupId, event.deletedAt == nil else { return false }
            let isCommunityEvent = event.calendarId == nil || event.calendarId == communityCalendarId
            guard isCommunityEvent else { return true }
            return event.approvedBy.contains(uid)
        }
    }

    // MARK: - グループ連携（コミュニティカレンダーの予定追加・削除をグループチャット／通知に流す）
    //   ★ 秘密の予定（isSecret）は本人にしか見えないものなので、グループには一切知らせない。
    //     groupIdが無い（どのグループにも属さない）予定も同様に対象外とする。
    //   ★ 表示名・アイコンは users/{uid} が大元のソース（ChatViewModel.fetchUserProfileと同じ考え方）

    private func announceEventCreated(_ event: Event) {
        guard !event.isSecret, let groupId = event.groupId, let uid = Auth.auth().currentUser?.uid else { return }
        let groupName = groupName(for: groupId)
        // ★ コミュニティカレンダーの予定だけが承認制の対象。個人・共有カレンダーの予定は
        //   従来通り「追加されました」の通知のみで、承認なしにそのまま見える
        let isCommunity = (event.calendarId == nil || event.calendarId == "\(groupId)_community")

        Task {
            let profile = await ChatViewModel.fetchUserProfile(uid: uid)
            let actorName = profile?.displayName ?? "名無しさん"

            // ★ 承認待ち一覧を出すたびにusers/{uid}を引き直さずに済むよう、
            //   追加した人の表示名をイベントドキュメントに非正規化して書き戻す
            if let eventId = event.id {
                let collection = event.isSecret ? self.secretCollection : self.normalCollection
                try? await collection.document(eventId).setData(["creatorName": actorName], merge: true)
            }

            if isCommunity {
                // ★ グループチャットへのお知らせ・全メンバーへの承認依頼通知は、
                //   全員に見えるコミュニティカレンダーの予定追加時だけに限定する。
                //   以前はプライベート/共有カレンダーに追加した時もここが無条件に
                //   実行され、他のメンバーの目に触れるはずのない個人的な予定の
                //   追加までチャットお知らせ・プッシュ通知として広報されてしまっていた
                ChatViewModel.postSystemMessage(
                    groupId: groupId,
                    text: "🗓️ 新しい予定が追加されました\n「\(event.title)」\n📅 \(Self.chatDateLabel(for: event))",
                    category: "eventAdded"
                )
                AppNotificationViewModel.notifyEventApprovalRequest(
                    groupId: groupId,
                    groupName: groupName,
                    eventId: event.id,
                    eventTitle: event.title,
                    actorUid: uid,
                    actorName: actorName,
                    actorIconURL: profile?.iconURL
                )
            } else if let calendarId = event.calendarId {
                // ★ プライベート/共有カレンダーは、そのカレンダーを実際に閲覧できる
                //   メンバー（OshiCalendar.memberIds）だけに通知する。プライベート
                //   カレンダー（isPrivate、自分だけの非公開カレンダー）は本人以外
                //   誰にも見えないため、そもそも通知自体を一切出さない
                if let data = try? await self.db.collection("calendars").document(calendarId).getDocument().data() {
                    let isPrivateCalendar = data["isPrivate"] as? Bool ?? false
                    let memberIds = data["memberIds"] as? [String] ?? []
                    if !isPrivateCalendar && !memberIds.isEmpty {
                        AppNotificationViewModel.notifyEventCreated(
                            groupId: groupId,
                            groupName: groupName,
                            eventId: event.id,
                            eventTitle: event.title,
                            actorUid: uid,
                            actorName: actorName,
                            actorIconURL: profile?.iconURL,
                            recipientUids: memberIds
                        )
                    }
                }
            }
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
