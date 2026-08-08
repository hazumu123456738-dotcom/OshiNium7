//
//  CalendarRecreatePolicy.swift
//  OshiNium7
//

import Foundation

// ★ カレンダーの「作り直し」(削除して同グループにまた新規作成)判定ロジックを、
//   Firestoreクエリから切り離した純粋関数として切り出したもの。CalendarViewModel.
//   checkRecreateLimitはFirestoreから取得したタイムスタンプ配列をここに渡すだけにし、
//   判定ロジック自体はDirectMessagePolicyと同じくXCTestで直接検証できるようにする
enum CalendarRecreatePolicy {
    // ★ このグループで過去に一度でも個人カレンダーを削除したことがあれば「作り直し」とみなす。
    //   期間の制限はここでは設けない(いつ削除したかに関わらず、削除履歴があれば以後の作成は
    //   すべて「作り直し」として扱う。レート制限自体は直近の"recreate"ログの件数で別途行う)
    static func isRecreate(deleteTimestamps: [Date]) -> Bool {
        !deleteTimestamps.isEmpty
    }

    // ★ windowDays日以内に記録された「作り直し」ログの件数
    static func recentRecreateCount(recreateTimestamps: [Date], windowDays: Int, now: Date = Date()) -> Int {
        let windowStart = Calendar.current.date(byAdding: .day, value: -windowDays, to: now) ?? .distantPast
        return recreateTimestamps.filter { $0 >= windowStart }.count
    }

    // ★ 今回の作成を許可してよいか。削除履歴が無ければ(=純粋な新規作成)常に許可する。
    //   削除履歴があれば、直近windowDays日以内の"recreate"件数がlimit未満の場合のみ許可する
    static func canCreate(deleteTimestamps: [Date], recreateTimestamps: [Date], windowDays: Int, limit: Int, now: Date = Date()) -> Bool {
        guard isRecreate(deleteTimestamps: deleteTimestamps) else { return true }
        return recentRecreateCount(recreateTimestamps: recreateTimestamps, windowDays: windowDays, now: now) < limit
    }
}
