//
//  PostPagerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ マイページ・他ユーザーページの投稿グリッドで写真をタップした際、
//   1枚だけの詳細画面ではなく、そのユーザーの写真付き投稿を縦スワイプで
//   次々に見ていける画面。タップされた投稿から開始し、上下スワイプで
//   前後の投稿へページ送りする（Reels等と同じ「1スワイプ＝1投稿」の挙動）
struct PostPagerView: View {
    let posts: [Post]
    let initialPostId: String

    @State private var scrollPosition: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(posts) { post in
                    page(post)
                        .id(post.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPosition, anchor: .top)
        .onAppear { scrollPosition = initialPostId }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func page(_ post: Post) -> some View {
        ScrollView(showsIndicators: false) {
            PostFeedCard(post: post)
                .padding(16)
        }
        .containerRelativeFrame(.vertical)
    }
}
