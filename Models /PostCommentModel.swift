//
//  PostCommentModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation

struct PostComment: Identifiable, Codable, Equatable {
    var id: String
    var authorUid: String
    var authorName: String
    var text: String
    var createdAt: Date
}
