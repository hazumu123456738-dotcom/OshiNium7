//
//  EventHubVenueReportsSheet.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI

// ★ 2026/08/20（oshiスキル監査）：EventHubDetailView.swiftが2,592行まで肥大化していたため、
//   すでに独立したstructだった会場口コミ・セトリシートをこのファイルへ切り出した。
//   EventHubDetailView本体からVenueReportsSheet(...)として呼ばれるためprivateは外している

// MARK: - 会場の口コミ・その日のセトリ（匿名投稿。ハッシュタグで絞り込みできる）

struct VenueReportsSheet: View {
    let event: Event
    let group: IdolGroup?
    @ObservedObject var venueReportVM: VenueReportViewModel
    let accentColor: Color
    // ★ 「会場の口コミ」はこのイベント単体ではなく、同じ会場に書かれた全ての口コミを対象にする
    let place: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind = "review"
    @State private var selectedHashtag: String?
    @State private var showComposer = false

    private var kindTitle: String { selectedKind == "review" ? "会場の口コミ" : "その日のセトリ" }
    private var placeholder: String {
        selectedKind == "review"
            ? "会場の様子、混雑状況、注意点など（#ハッシュタグも使えます）"
            : "セットリストを書こう（例: 1. オープニング 2. ○○ ...）"
    }

    // ★ 口コミ（review）は場所単位、セトリ（setlist）はこのイベント単位のまま
    private var baseEntries: [VenueReport] {
        selectedKind == "review" ? venueReportVM.placeReviewEntries : venueReportVM.entries(kind: "setlist")
    }

    private var entries: [VenueReport] {
        guard let selectedHashtag else { return baseEntries }
        return baseEntries.filter { Self.hashtags(in: $0.text).contains(selectedHashtag) }
    }

    // ★ 表示中の一覧に登場する全ハッシュタグを、出現数の多い順にチップとして出す
    private var availableHashtags: [String] {
        let all = baseEntries.flatMap { Self.hashtags(in: $0.text) }
        var counts: [String: Int] = [:]
        for tag in all { counts[tag, default: 0] += 1 }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                kindPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // ★ ここでの投稿は「このイベントだけのもの」だと誤解されやすいため、
                //   実際には同じ会場の口コミとしてオシニウムタブの「会場口コミ」ツールに
                //   集約保存され、他の予定・他ユーザーからも見えることを明記する
                if selectedKind == "review" {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("この会場の口コミとして「会場口コミ」ツールに保存され、他の予定からも見られます", systemImage: "info.circle")
                        Label("口コミは匿名で記載されます。投稿者の名前やアイコンは表示されません", systemImage: "eye.slash")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if !availableHashtags.isEmpty {
                    hashtagChips
                        .padding(.top, 10)
                }

                if entries.isEmpty {
                    EventHubExtraEmptyState(
                        icon: "bubble.left.and.bubble.right.fill",
                        text: selectedHashtag.map { "「\($0)」の投稿はまだありません" } ?? "まだ投稿がありません",
                        accentColor: accentColor
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                // ★ 口コミは場所単位で集約表示するため、「いつ・何のために
                                //   訪れた回の口コミか」がわかるようメタ情報を添える
                                if selectedKind == "review", entry.eventDate != nil || entry.purpose != nil {
                                    HStack(spacing: 6) {
                                        if let eventDate = entry.eventDate {
                                            Label(reportDateText(eventDate), systemImage: "calendar")
                                        }
                                        if let purpose = entry.purpose, !purpose.isEmpty {
                                            Text(purpose)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(accentColor.opacity(0.12)))
                                                .foregroundColor(accentColor)
                                        }
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                }

                                Text(entry.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                Text(relativeTime(entry.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(kindTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("\(kindTitle)を投稿")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showComposer) {
                VenueReportComposerView(
                    title: kindTitle,
                    placeholder: placeholder,
                    kind: selectedKind,
                    eventId: event.id ?? "",
                    groupId: event.groupId ?? group?.id ?? "",
                    accentColor: accentColor
                ) { text, uid, rating, imageURL, completion in
                    venueReportVM.submit(
                        eventId: event.id ?? "",
                        groupId: event.groupId ?? group?.id ?? "",
                        kind: selectedKind,
                        text: text,
                        uid: uid,
                        place: selectedKind == "review" ? place : nil,
                        eventDate: selectedKind == "review" ? (event.startDate ?? event.date) : nil,
                        purpose: selectedKind == "review" ? event.type?.displayName : nil,
                        groupCategory: selectedKind == "review" ? group?.category : nil,
                        rating: selectedKind == "review" ? rating : nil,
                        imageURL: selectedKind == "review" ? imageURL : nil,
                        completion: completion
                    )
                }
            }
        }
    }

    private var kindPicker: some View {
        Picker("種類", selection: $selectedKind) {
            Text("口コミ").tag("review")
            Text("セトリ").tag("setlist")
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedKind) { _, _ in selectedHashtag = nil }
    }

    private var hashtagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableHashtags, id: \.self) { tag in
                    let isSelected = tag == selectedHashtag
                    Button {
                        selectedHashtag = isSelected ? nil : tag
                    } label: {
                        Text(tag)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isSelected ? accentColor : accentColor.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // ★ 口コミに添える「その回はいつだったか」の日付表示
    private func reportDateText(_ date: Date) -> String {
        return CachedFormatters.date(format: "yyyy/M/d").string(from: date)
    }

    // ★ 「#」から始まる、記号・空白を含まないひとかたまりをハッシュタグとして抽出する
    //   （日本語の漢字・ひらがな・カタカナも含む）
    private static func hashtags(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "#[\\p{L}0-9_]+") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
