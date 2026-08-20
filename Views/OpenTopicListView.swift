//
//  OpenTopicListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI
import FirebaseAuth

// ★ コミュニティチャットの「公開版」のトップ画面。匿名版と同じ「メンバーなら誰でも
//   自由に話題（トークルーム）を立てられ、他の人が立てたトークルームにも自由に
//   参加・閲覧できる」掲示板形式だが、こちらは名前・アイコンをそのまま出す。
//   「同じ推しを応援する友達を見つける」ことをメインの目的に据えた入口
struct OpenTopicListView: View {
    let group: IdolGroup

    @StateObject private var chatViewModel = ChatViewModel()
    @State private var showCreateSheet = false
    @State private var showSearchSheet = false

    // ★ 匿名版の落ち着いた紫グレーとは対照的に、「生誕祭」のような明るく賑やかな
    //   配色にして、見た瞬間に「こっちはオープンで賑やかな場」だと分かるようにする
    private let accentColor = Color(red: 1.0, green: 0.45, blue: 0.42)
    private let accentColor2 = Color(red: 1.0, green: 0.70, blue: 0.30)

    private let gridSpacing: CGFloat = 14

    private var tileSide: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return max((screenWidth - 32 - gridSpacing) / 2, 0)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: gridSpacing), GridItem(.flexible(), spacing: gridSpacing)]
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            content
        }
        .navigationTitle("\(group.name)（公開）")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSearchSheet = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("トークルームを検索")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("トークルームを作る")
            }
        }
        .onAppear {
            chatViewModel.observeOpenTopics(groupId: group.id)
        }
        .onDisappear {
            chatViewModel.stopObservingOpenTopics()
        }
        .sheet(isPresented: $showCreateSheet) {
            NewOpenTopicSheet(group: group, chatViewModel: chatViewModel)
                .presentationDetents([.height(260)])
        }
        .sheet(isPresented: $showSearchSheet) {
            OpenTopicSearchView(group: group, chatViewModel: chatViewModel)
        }
    }

    // MARK: - 案内バナー

    private var banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityHidden(true)
            Text("名前もアイコンも公開。推し活の友達を見つけよう")
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
        )
    }

    // MARK: - トークルーム一覧

    @ViewBuilder
    private var content: some View {
        if !chatViewModel.isOpenTopicsLoaded {
            Spacer()
            ProgressView().padding(.top, 40)
            Spacer()
        } else if chatViewModel.openTopics.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                    ForEach(chatViewModel.openTopics) { topic in
                        NavigationLink {
                            OpenChatRoomView(group: group, topic: topic)
                        } label: {
                            topicCard(topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)
            Text("まだトークルームがありません")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("＋ボタンから最初の話題を立ててみましょう")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
            Button {
                showCreateSheet = true
            } label: {
                Label("トークルームを作る", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                    )
            }
            .padding(.top, 4)
            Spacer()
        }
    }

    private func topicCard(_ topic: OpenTopic) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Circle()
                    .fill(
                        LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)
                    )
                Spacer(minLength: 0)
                Text(relativeTime(topic.lastMessageAt))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Text(topic.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("\(topic.messageCount)件の発言")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(width: tileSide, height: tileSide, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - トークルーム作成シート

private struct NewOpenTopicSheet: View {
    let group: IdolGroup
    @ObservedObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var isCreating = false

    private let accentColor = Color(red: 1.0, green: 0.45, blue: 0.42)
    private let accentColor2 = Color(red: 1.0, green: 0.70, blue: 0.30)
    private let maxLength = 30

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("新しいトークルーム")
                        .font(.system(size: 17, weight: .bold))
                    Text("どんな話題か一目で分かるタイトルをつけましょう（名前・アイコンは公開されます）")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                TextField("例：一緒に参戦する友達探してます", text: $title)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                    .onChange(of: title) { _, newValue in
                        if newValue.count > maxLength {
                            title = String(newValue.prefix(maxLength))
                        }
                    }

                Text("\(title.count)/\(maxLength)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Button {
                    create()
                } label: {
                    HStack(spacing: 8) {
                        if isCreating { ProgressView().tint(.white) }
                        Text(isCreating ? "作成しています…" : "作成する")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        (title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                            ? AnyShapeStyle(Color.gray.opacity(0.35))
                            : AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func create() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isCreating = true
        chatViewModel.createOpenTopic(groupId: group.id, title: title, creatorUid: uid) { _ in
            DispatchQueue.main.async {
                isCreating = false
                dismiss()
            }
        }
    }
}
