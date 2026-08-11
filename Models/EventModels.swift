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
