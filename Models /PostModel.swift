//
//  PostModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

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
    // ★ Threadsのようにテキストだけの投稿もできるよう、メディアは任意にしている
    var mediaURL: String?
    var mediaType: String?   // "image" | "video" | nil（テキストのみ）
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
    var createdAt: Date
    var likedBy: [String]
    // ★ コメント一覧はposts/{id}/commentsのサブコレクションに持つため、
    //   フィード上で毎回それを読みに行かなくて済むよう件数だけ非正規化して持たせる
    var commentCount: Int

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id && lhs.likedBy == rhs.likedBy && lhs.commentCount == rhs.commentCount
    }
}
