//
//  EventModels.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import Foundation

// ★ コミュニティカレンダーに保存する直前に出す確認ダイアログの「今後は表示しない」設定。
//   端末単位の@AppStorage設定なので、保存画面(AddEventView/AIAddEventResultView)と
//   設定画面(UserSettingsView、再表示ボタン用)で同じキーを共有する
enum CommunityCalendarSaveWarning {
    static let storageKey = "hideCommunityCalendarSaveWarning"
}

struct Event: Identifiable, Codable, Equatable, Hashable {

    var id: String?

    // MARK: - 基本情報
    var title: String

    /// 単一日付イベント用（従来の date）
    var date: Date

    /// 範囲イベント用（start〜end）
    var startDate: Date?
    var endDate: Date?

    var isSecret: Bool
    /// 秘密イベントを登録した本人のuid（秘密イベントは本人にしか読み込ませない）
    var creatorUid: String?
    var groupId: String?
    /// このイベントが属するカレンダー（nilの場合はグループのコミュニティカレンダー扱い）
    var calendarId: String?

    // MARK: - カテゴリ（★ Optional）
    var type: EventType?
    var subType: EventSubType?
    var customSubType: String?

    // MARK: - 手動入力項目
    var place: String?
    var timeText: String?
    var condition: String?
    var applyDate: String?
    var channel: String?
    var programName: String?
    var url: String?
    var notes: String?

    /// 通知タイミング（分前）。ユーザーが自由に何個でも追加できる
    var notifyOffsets: [Int]?

    // MARK: - AI追加項目
    var openTime: String?
    var startTime: String?
    var endTime: String?

    var access: String?
    var organizer: String?
    var contact: String?

    var officialURL: String?
    var thumbnailURL: String?

    var tags: [String]?

    var ticketPrice: String?
    var ticketStartDate: String?

    // MARK: - ★ 手動追加イベントの画像（Firebase Storage）
    /// Firebase Storage に保存した画像URL（複数対応）
    var imageURLs: [String]?      // ← 新規追加

    // ★ ソフトデリート用。設定されていれば「削除済み」として通常のカレンダー表示からは除外するが、
    //   削除から3日以内であれば「削除した予定」一覧から本人が復元できる（EventViewModel参照）
    var deletedAt: Date? = nil

    // MARK: - コミュニティカレンダーの承認制
    //   ★ コミュニティカレンダーの予定は、追加した本人以外のメンバーそれぞれが
    //   個別に「承認」してはじめて、その人自身のカレンダー表示に反映される
    //   （MonthlyCalendarView.isCommunityEventの表示フィルタ参照）。
    //   追加した本人は作成時に自動で承認済みとして書き込まれる。
    //   個人・共有カレンダーの予定ではこの配列は使われない(表示フィルタの対象外)
    var approvedBy: [String] = []
    /// 予定を追加した人の表示名（非正規化。承認待ち一覧を出すたびにusers/{uid}を
    /// 引き直さずに済むように、EventViewModel.announceEventCreatedが追加登録する）
    var creatorName: String? = nil
    /// ★ 承認待ち一覧で「削除」を選んだユーザーのUID一覧。approvedByと同じ考え方で、
    ///   「自分は今後この予定を承認待ちに出さない」という個人の意思表示。他メンバーには影響しない
    var dismissedBy: [String] = []

    /// ★ コミュニティカレンダーの予定を「カレンダーから削除」した日時（uidごと）。
    ///   deletedAtと違い、コミュニティの予定は1人が削除しても他メンバーには影響しない
    ///   （dismissedByに自分のuidが足されるだけ）ため、deletedAtのような単一のTimestampでは
    ///   「誰が・いつ削除したか」を表現できない。uidごとのTimestampをマップで持つことで、
    ///   deletedAtと同様に「削除して3日以内なら復元できる」を各メンバー個別に実現する
    var dismissedAt: [String: Date] = [:]

    /// ★ 承認待ちバッジ（CalendarManageMenuView等）を「未確認件数」として出すために必要。
    ///   これが無い予定（作成日時が記録される前の既存データ）はnilのままとなり、
    ///   常に「既読」扱い（バッジの対象外）として安全側にフォールバックする
    var createdAt: Date? = nil

    /// ★ 「削除した予定」一覧向けの共通ヘルパー。個人・共有カレンダーの予定はdeletedAt、
    ///   コミュニティカレンダーの予定はdismissedAt[uid]と、削除の記録場所が異なるため、
    ///   呼び出し側がその違いを意識しなくて済むよう一本化する
    func effectiveDeletedAt(for uid: String) -> Date? {
        deletedAt ?? dismissedAt[uid]
    }

    /// ★ 2026/08/15追加：カレンダータブの月表示（MonthlyCalendarView.filteredEvents）と
    ///   日別一覧（DayEventListView.eventsForDay）が、それぞれ手で同じ判定ロジックを
    ///   再実装していたことで一度ズレが発生した経緯がある（2026/08/11のDayEventListView修正
    ///   コメント参照：月表示には出ない未承認の予定が日別一覧にだけ出てしまっていた）。
    ///   「選択中カレンダー＋コミュニティ承認制」の判定をここに一本化し、両画面はこれを
    ///   呼ぶだけにすることで、今後どちらか一方だけ直して食い違う、という再発を防ぐ
    static func visibleEvents(
        from events: [Event],
        groupId: String,
        communityCalendarId: String?,
        selectedCalendar: OshiCalendar?,
        myUid: String?
    ) -> [Event] {
        guard let myUid else { return [] }

        func isCommunityEvent(_ event: Event) -> Bool {
            event.calendarId == nil || event.calendarId == communityCalendarId
        }
        func isApprovedForMe(_ event: Event) -> Bool {
            event.approvedBy.contains(myUid)
        }

        return events.filter { event in
            guard event.groupId == groupId else { return false }
            // ★ 選択中カレンダーが未確定の間は、安全側のデフォルトとして
            //   「コミュニティかつ承認済み」だけを対象にする
            guard let oshiCalendar = selectedCalendar else {
                return isCommunityEvent(event) && isApprovedForMe(event)
            }
            if oshiCalendar.isCommunity {
                return isCommunityEvent(event) && isApprovedForMe(event)
            } else {
                return event.calendarId == oshiCalendar.id || (isCommunityEvent(event) && isApprovedForMe(event))
            }
        }
    }

    /// ★ 2026/08/21追加：PackingChecklistView・OshiExpenseTrackerViewの日付選択ミニカレンダーが、
    ///   EventViewModel.myEventsByDate(「参加グループの予定」というだけの絞り込み、承認状態を見ない)を
    ///   groupIdだけでさらに絞って使っていたため、コミュニティカレンダーの未承認予定(他メンバーが
    ///   追加したがまだ自分が承認していない予定)まで、まっさらな新規アカウントのミニカレンダーに
    ///   表示されてしまうバグの原因になっていた（カレンダータブ本体はvisibleEventsを正しく
    ///   経由しているため空のまま、という食い違いが発生していた）。
    ///   visibleEventsは「今どのカレンダーを選んでいるか」という単一選択の文脈が前提だが、
    ///   こちらは「そのグループのどのカレンダーであってもカレンダータブに実際に表示される予定」を
    ///   横断的に集める、より単純な用途向け
    static func visibleEventsForGroup(
        from events: [Event],
        groupId: String,
        communityCalendarId: String?,
        myUid: String?
    ) -> [Event] {
        guard let myUid else { return [] }
        return events.filter { event in
            guard event.groupId == groupId else { return false }
            let isCommunity = event.calendarId == nil || event.calendarId == communityCalendarId
            return isCommunity ? event.approvedBy.contains(myUid) : true
        }
    }
}

//
// MARK: - Event → AIEventResult 変換（DayEventListView でカードUIを使うため）
//
extension Event {

    func toAIEventResult() -> AIEventResult {

        return AIEventResult(
            groupId: self.groupId,
            title: self.title,
            dateString: self.date.toDateString(),
            location: self.place,

            openTime: self.openTime,
            startTime: self.startTime,
            endTime: self.endTime,

            access: self.access,
            organizer: self.organizer,
            contact: self.contact,

            officialURL: self.officialURL,
            thumbnailURL: self.thumbnailURL,

            tags: self.tags ?? [],

            ticketPrice: self.ticketPrice,
            ticketStartDate: self.ticketStartDate
        )
    }
}

//
// MARK: - Date → String 変換（AIEventResult 用）
//
extension Date {
    func toDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: self)
    }
}
