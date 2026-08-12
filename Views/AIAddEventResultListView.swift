//
//  AIAddEventResultListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import SwiftUI

struct AIAddEventResultListView: View {

    @ObservedObject var eventViewModel: EventViewModel

    let results: [AIEventResult]
    let selectedGroup: IdolGroup?
    let defaultDate: Date
    var calendarId: String? = nil

    @State private var imageURLs: [UUID: URL] = [:]

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - ヘッダー
            VStack(alignment: .leading, spacing: 8) {
                Text("AI解析結果")
                    .font(.system(size: 22, weight: .bold))

                Text("✨ AIが\(results.count)件の予定候補を見つけました")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("追加したい予定を選択してください")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if results.isEmpty {

                VStack(spacing: 16) {

                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 52))
                        .foregroundColor(.gray.opacity(0.7))

                    Text("今回の条件に合うイベントは見つかりませんでした")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("日本での開催情報がまだ出ていない可能性があります。\n別の日付や地域でもう一度検索してみてください。")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("新しいイベントが発表されたら、すぐにお知らせします。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)

            } else {

                ScrollView {
                    LazyVStack(spacing: 16) {

                        ForEach(results) { item in
                            NavigationLink {
                                AIAddEventResultView(
                                    result: item,
                                    selectedGroup: selectedGroup,
                                    defaultDate: defaultDate,
                                    imageURL: imageURLs[item.id],
                                    calendarId: calendarId,
                                    eventVM: eventViewModel   // ← ★ 修正ポイント
                                )
                            } label: {
                                AIEventCardView(
                                    result: item,
                                    groupName: selectedGroup?.name,
                                    imageURL: imageURLs[item.id]
                                )
                            }
                            .buttonStyle(.plain)
                            .task {
                                await loadImageIfNeeded(for: item)
                            }
                        }

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 画像URLの遅延取得
    private func loadImageIfNeeded(for item: AIEventResult) async {

        if imageURLs[item.id] != nil { return }
        guard let urlString = item.officialURL else { return }

        EventImageFetcher.fetchImageURL(from: urlString) { url in
            guard let url else { return }
            DispatchQueue.main.async {
                imageURLs[item.id] = url
            }
        }
    }
}

