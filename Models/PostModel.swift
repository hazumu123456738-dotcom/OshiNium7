//
//  PostModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

// ★ 複数枚投稿(mediaItems)の1件分。従来の単一mediaURL/mediaTypeとは別に持たせ、
//   既存の全画面（グリッド・ランキング等）がそのまま単一メディアの投稿として動き続けられるようにする
struct PostMediaItem: Identifiable, Codable, Equatable {
    var url: String
    var type: String   // "image" | "video"
    var id: String { url }
}

struct Post: Identifiable, Codable, Equatable {
    var id: String
    var authorUid: String
    // ★ 投稿者が非公開アカウントかどうかを、投稿ドキュメント自体に非正規化して持たせる。
    //   Firestoreのlistクエリは「クエリのwhere条件だけで安全性を静的に証明できる」場合しか
    //   通らないため、投稿者のuserドキュメントをget()で毎回参照するルールのままだと
    //   絞り込み条件の無い全件購読クエリそのものが権限エラーで丸ごと失敗してしまう。
    //   このフィールドをそのままwhere条件に使えるようにして、その問題を回避する
    var authorIsPrivate: Bool = false
    var groupId: String
    var groupName: String
    // ★ Threadsのようにテキストだけの投稿もできるよう、メディアは任意にしている。
    //   複数枚投稿の場合もmediaURL/mediaTypeには常に1枚目を入れておき（後方互換：
    //   グリッド・ランキング等、単一サムネイルしか使わない既存画面がそのまま動く）、
    //   全件はmediaItemsに持つ
    var mediaURL: String?
    var mediaType: String?   // "image" | "video" | nil（テキストのみ）
    var mediaItems: [PostMediaItem]?
    var caption: String?
    // ★ 持ち物テンプレートをそのまま投稿として共有した場合に入る。
    //   非nilならPostFeedCard側で「持ち物リスト」カードとして表示し、長押しで
    //   閲覧者が自分のテンプレートとして保存できるようにする（保存すると投稿者に自動でいいねが付く）
    var packingTemplateName: String?
    var packingTemplateItems: [String]?
    // ★ 「推し活ペンライト・グッズ」ツールから投稿された場合に入る。非nilならPostFeedCard側で
    //   種類バッジ＋名前を通常のタイムラインでも表示し、そのグループのショーケース・
    //   いいねランキングにも同じ投稿がそのまま反映される（専用の投稿・別コレクションを持たず、
    //   通常の投稿と完全に同じ扱いにするための設計）
    var goodsKind: String?
    var goodsTitle: String?
    // ★ 推し活の金額記録をそのまま投稿として共有した場合に入る。非nilならPostFeedCard側で
    //   「いくら使ったか」カードとして表示する（persisting先はpackingTemplate等と同じく
    //   専用コレクションを作らず、通常の投稿にフィールドを足すだけの設計）
    var expenseAmount: Int?
    var expenseCategory: String?
    var createdAt: Date
    var likedBy: [String]
    // ★ コメント一覧はposts/{id}/commentsのサブコレクションに持つため、
    //   フィード上で毎回それを読みに行かなくて済むよう件数だけ非正規化して持たせる
    var commentCount: Int

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id && lhs.likedBy == rhs.likedBy && lhs.commentCount == rhs.commentCount
    }
}
