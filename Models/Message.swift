//
//  Message.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import Foundation

struct Message: Identifiable, Codable, Equatable {
    var id: String?
    var senderUid: String
    var senderName: String
    var text: String
    // ★ 画像・動画付きメッセージ用。キャプション（text）だけ、メディアだけ、両方、のいずれも許可する。
    //   imageURLという名前だが動画のURLもここに入る（Postのmediaと同じ設計）。
    //   mediaTypeが"video"の時だけ動画として扱い、それ以外（nilや"image"）は画像として扱う
    var imageURL: String? = nil
    var mediaType: String? = nil
    // ★ 複数枚まとめて送信した画像・動画を、後でUI側で「1つの束」としてまとめて
    //   表示するための識別子。同じバッチ内の全メッセージに同じ値を入れる。
    //   1枚だけの送信やテキストのみの場合はnilのまま（束にしない）
    var batchId: String? = nil
    var createdAt: Date
    // ★ 予定の追加/削除などをお知らせする自動メッセージ。trueのときは吹き出しではなく
    //   中央寄せのピル表示にする（ChatRoomView側で分岐）
    var isSystem: Bool = false
    // ★ Instagram DM風の「ダブルタップでハートを付ける」リアクション。postsのlikedByと同じ設計
    var likedBy: [String] = []
    // ★ 投稿をDMでシェアした時に入る（SharePostSheet参照）。imageURL/mediaTypeは
    //   従来通り画像・動画の表示に使い、これらは「タップした瞬間に投稿者のプロフィールへ
    //   飛べる」ようにするための追加情報。nilなら通常の画像・動画メッセージとして扱う
    var sharedPostId: String? = nil
    var sharedPostAuthorUid: String? = nil
    var sharedPostAuthorName: String? = nil
    var sharedPostGroupName: String? = nil
    // ★ isSystemメッセージの種類（"join"・"leave"・"eventAdded"・"eventDeleted"）。
    //   ChatRoomViewでお知らせの種類ごとに色分けするために使う。この項目が無い過去のメッセージは
    //   nilのままになるため、ChatRoomView.SystemMessageCategory.infer(from:)で本文から推測する
    var systemCategory: String? = nil
}
