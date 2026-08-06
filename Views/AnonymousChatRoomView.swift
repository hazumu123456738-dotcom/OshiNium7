//
//  AnonymousChatRoomView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/03.
//

import SwiftUI
import FirebaseAuth

// ★ コミュニティチャットの「匿名版」の、個々のトークルーム（話題）。同じグループの
//   メンバー同士で、名前もアイコンも一切出さずに会話できる（本音を言いやすくするための場）。
//   通常のChatRoomViewとは完全に別のFirestoreサブコレクション
//   （groups/{groupId}/anonymousTopics/{topicId}/messages）を使うため、
//   通常チャットの発言と匿名チャットの発言が混ざることは無い。
//   ★ senderUidはモデレーション（通報・管理者削除）のためだけにドキュメントへ残り、
//     画面上には絶対に表示しない。表示するのは常に「匿名」というラベルのみ
struct AnonymousChatRoomView: View {
    let group: IdolGroup
    let topic: AnonymousTopic

    @StateObject private var chatViewModel = ChatViewModel()
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var navState: AppNavigationState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    @State private var inputText: String = ""
    @State private var reportTarget: Message?
    @State private var showDeleteTopicConfirm = false

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var canDeleteTopic: Bool {
        currentUid == topic.creatorUid || groupViewModel.myRole(in: group).canModerateContent
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            messageArea
            inputBar
        }
        .padding(.bottom, customTabBarHeight)
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar {
            if canDeleteTopic {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteTopicConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("このトークルームを削除")
                }
            }
        }
        .onAppear {
            chatViewModel.observeAnonymousMessages(groupId: group.id, topicId: topic.id)
            groupViewModel.fetchMembers(for: group.id)
            navState.hidesCustomTabBar = true
        }
        .onDisappear {
            chatViewModel.stopObservingAnonymous()
            navState.hidesCustomTabBar = false
        }
        .confirmationDialog(
            "このトークルームを削除しますか？中のメッセージもすべて消えます",
            isPresented: $showDeleteTopicConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                chatViewModel.deleteAnonymousTopic(groupId: group.id, topic: topic)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "このメッセージを報告しますか？",
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            titleVisibility: .visible
        ) {
            ForEach(["スパム・宣伝", "嫌がらせ・誹謗中傷", "不適切な内容", "その他"], id: \.self) { reason in
                Button(reason) {
                    if let message = reportTarget {
                        ModerationService.reportMessage(
                            context: "groupChatAnonymous",
                            contextId: group.id,
                            messageId: message.id,
                            messageText: message.text,
                            reportedUid: message.senderUid,
                            reason: reason
                        )
                    }
                    reportTarget = nil
                }
            }
            Button("キャンセル", role: .cancel) { reportTarget = nil }
        }
    }

    // MARK: - 案内バナー

    private var banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityHidden(true)
            Text("名前もアイコンも表示されない匿名の会話です")
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 0.45, green: 0.40, blue: 0.55), Color(red: 0.30, green: 0.28, blue: 0.42)],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: - メッセージ表示エリア

    @ViewBuilder
    private var messageArea: some View {
        if !chatViewModel.isAnonymousLoaded {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        } else if chatViewModel.anonymousMessages.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                    .accessibilityHidden(true)
                Text("まだメッセージがありません")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("誰が言ったかは表示されません。気軽に投稿してみましょう")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chatViewModel.anonymousMessages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                // ★ ChatRoomViewと同じく、下スワイプでキーボードを閉じられるようにする
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chatViewModel.anonymousMessages.count) { _, _ in
                    guard let lastId = chatViewModel.anonymousMessages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
                .onAppear {
                    guard let lastId = chatViewModel.anonymousMessages.last?.id else { return }
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    private var anonymousAvatar: some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
            )
    }

    private func messageRow(_ message: Message) -> some View {
        let isMine = message.senderUid == currentUid

        return VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if !isMine {
                Text("匿名")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }

            HStack(alignment: .bottom, spacing: 6) {
                if isMine { Spacer(minLength: 40) }
                if !isMine { anonymousAvatar }

                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(isMine ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleBackground(isMine: isMine))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(isMine ? 0.12 : 0.05), radius: 6, x: 0, y: 3)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.68, alignment: isMine ? .trailing : .leading)

                if isMine { anonymousAvatar }
                if !isMine { Spacer(minLength: 40) }
            }

            Text(message.createdAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(isMine ? .trailing : .leading, 36)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    chatViewModel.deleteAnonymousMessage(groupId: group.id, topicId: topic.id, message: message)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } else {
                if groupViewModel.myRole(in: group).canModerateContent {
                    Button(role: .destructive) {
                        chatViewModel.deleteAnonymousMessage(groupId: group.id, topicId: topic.id, message: message)
                    } label: {
                        Label("削除（管理者）", systemImage: "trash")
                    }
                }
                Button {
                    reportTarget = message
                } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    private let accentColor = Color(red: 0.45, green: 0.40, blue: 0.55)
    private let accentColor2 = Color(red: 0.30, green: 0.28, blue: 0.42)

    private func bubbleBackground(isMine: Bool) -> AnyShapeStyle {
        chatBubbleBackground(isMine: isMine, primary: accentColor, primary2: accentColor2)
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        ChatTextOnlyInputBar(
            inputText: $inputText,
            placeholder: "匿名でメッセージを入力",
            accentColor: accentColor,
            onSend: send
        )
    }

    private func send() {
        guard let uid = currentUid else { return }
        chatViewModel.sendAnonymousMessage(groupId: group.id, topicId: topic.id, text: inputText, senderUid: uid)
        inputText = ""
    }
}
