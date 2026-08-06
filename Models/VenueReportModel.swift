//
//  VenueReportModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation

// ★ イベント当日ハブの「会場の口コミ」「その日のセトリ」用モデル。
//   投稿とは違い、ユーザーそれぞれ匿名で掲載する機能のため、画面には uid を一切出さない
//   （本音を言いやすくするための仕様。uid はサーバー側のモデレーション用にのみ保持する）
struct VenueReport: Identifiable, Codable, Equatable {
    var id: String
    var eventId: String
    var groupId: String
    var kind: String   // "review"（会場の口コミ）| "setlist"（その日のセトリ）
    var text: String
    var uid: String
    var createdAt: Date

    // ★ 「会場の口コミ」は場所ごとに蓄積して、別のイベントでも同じ会場なら
    //   過去の口コミが見られるようにする。そのために書いた本人の予定から
    //   会場名・その回の日付・目的（種類）をスナップショットとして保存しておく
    var place: String?
    var eventDate: Date?
    var purpose: String?   // event.type?.displayName（「ライブ」「イベント」など）

    // ★ 「会場口コミ」ツールの「他の推しの口コミを見る」用。書いた本人のグループの
    //   カテゴリ（K-POP等）をスナップショットしておくことで、口コミ1件ごとに
    //   投稿元グループのカテゴリを都度引き直さずに横断フィルタできるようにする
    var groupCategory: String?

    // ★ 会場口コミ(kind == "review")のみで使う評価・画像。セトリには使わない
    var rating: Int?       // 1〜5
    var imageURL: String?

    // ★ 「実際に参加した人だから分かる情報」を蓄積しやすくするための定番タグ。
    //   投稿画面のワンタップ挿入チップ・会場詳細ページの絞り込みチップの両方で共有する
    static let commonTags = ["入場ゲート", "座席の見え方", "音響ステージ", "混雑状況", "トイレ売店", "規制退場", "周辺情報"]
}
