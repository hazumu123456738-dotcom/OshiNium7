//
//  MemoryDiaryListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import SwiftUI
import NukeUI
import AVKit
import FirebaseAuth

// ★ オシニウムタブの「ツール」内、以前は「参戦記録」だった枠を「思い出日記」に置き換えた
//   一覧画面。カレンダーの日付長押しから書いた日記をまとめて振り返れる
struct MemoryDiaryListView: View {

    let group: IdolGroup?

    @StateObject private var diaryViewModel = MemoryDiaryViewModel()
    @State private var entryPendingDelete: MemoryDiaryEntry?
    @State private var playingVideoURL: IdentifiableURL?

    private let accentColor = Color(red: 0.25, green: 0.65, blue: 0.72)
    private let accentColor2 = Color(red: 0.35, green: 0.80, blue: 0.78)
    private var myUid: String? { Auth.auth().currentUser?.uid }

    private var entries: [MemoryDiaryEntry] {
        guard let group else { return [] }
        return diaryViewModel.entries(groupId: group.id)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                summaryCard

                if entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(entries) { entry in
                            entryCard(entry)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("思い出日記")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let myUid { diaryViewModel.startListening(uid: myUid) }
        }
        .onDisappear { diaryViewModel.stopListening() }
        .alert(
            "この日記を削除しますか？",
            isPresented: Binding(
                get: { entryPendingDelete != nil },
                set: { if !$0 { entryPendingDelete = nil } }
            )
        ) {
            Button("キャンセル", role: .cancel) { entryPendingDelete = nil }
            Button("削除する", role: .destructive) {
                if let entry = entryPendingDelete {
                    diaryViewModel.delete(entry)
                }
                entryPendingDelete = nil
            }
        } message: {
            Text("この操作は取り消せません。")
        }
        .fullScreenCover(item: $playingVideoURL) { wrapped in
            NavigationStack {
                VideoPlayer(player: AVPlayer(url: wrapped.url))
                    .background(Color.black.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                playingVideoURL = nil
                            } label: {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(group?.name ?? "")の思い出")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entries.count)")
                    .font(.system(size: 34, weight: .bold))
                Text("件")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)

            Text("カレンダーの日付を長押しすると、その日の思い出を記録できます")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))

            SharedScopeBadge(scope: .private, onGradient: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accentColor.opacity(0.3), radius: 14, x: 0, y: 8)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
            Text("まだ思い出日記がありません")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("カレンダーの日付を長押しして、最初の1件を書いてみましょう")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func entryCard(_ entry: MemoryDiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dateLabel(entry.date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                Spacer()
                Button {
                    entryPendingDelete = entry
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("この日記を削除")
            }

            if !entry.text.isEmpty {
                Text(entry.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !entry.imageURLs.isEmpty || !entry.videoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.imageURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                LazyImage(url: url) { state in
                                    if let image = state.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color(.systemGray6)
                                    }
                                }
                                .frame(width: 130, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                        ForEach(entry.videoURLs, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                Button {
                                    playingVideoURL = IdentifiableURL(url: url)
                                } label: {
                                    ZStack {
                                        Color.black
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .frame(width: 130, height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("動画を再生")
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日(E)"
        return f.string(from: date)
    }
}
