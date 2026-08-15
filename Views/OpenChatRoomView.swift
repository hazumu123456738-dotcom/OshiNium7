//
//  OpenChatRoomView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI
import FirebaseAuth
import NukeUI

// ★ コミュニティチャット「公開版」の、個々のトークルーム（話題）。匿名版と同じ構造だが、
//   発言者の名前・アイコンをそのまま表示する（同じ推しを応援する友達を見つけるための場）。
//   通常のChatRoomView・匿名版のAnonymousChatRoomViewとは完全に別のFirestoreサブコレクション
//   （groups/{groupId}/openTopics/{topicId}/messages）を使う
struct OpenChatRoomView: View {
    let group: IdolGroup
    let topic: OpenTopic

    @StateObject private var chatViewModel = ChatViewModel()
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var navState: AppNavigationState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    @State private var inputText: String = ""
    @State private var reportTarget: Message?
    @State private var showReportThanks = false
    @State private var showDeleteTopicConfirm = false

    // ★ ChatRoomViewと同じく、users/{uid}を直接見て常に最新の名前・アイコンを表示する
    @State private var profileCache: [String: ChatViewModel.RemoteUserProfile] = [:]
    @State private var fetchingUids: Set<String> = []

    // ★ 実名・実アイコンで発言するトークルームのため、匿名版と違いブロックが意味を持つ。
    //   DMのような1対1の送信可否ではなく、「ブロックした相手の発言を自分の画面からだけ
    //   丸ごと非表示にする」という、複数人が居る場に合わせた方式にする
    @State private var blockedUids: Set<String> = []
    @State private var blockTarget: Message?
    @State private var showBlockedUsersSheet = false

    // ★ 2026/08/16追加：投稿前ガイドライン。匿名版と同じ考え方だが、公開版は実名・実アイコンでの
    //   会話のため文言を分け、フラグも別に持つ
    @AppStorage("hasSeenOpenChatGuideline") private var hasSeenGuideline = false
    @State private var showGuideline = false
    @State private var pendingSendText: String?
    @State private var pendingOriginalText: String?

    // ★ 2026/08/16追加：NGワード検知回数（匿名・公開トークルーム共通でカウント）。
    //   実際の停止処理はここでは行わない（restrictedUsersの手動制限方針、
    //   AnonymousChatRoomView.swiftの同名プロパティのコメント参照）
    @AppStorage("ngWordViolationCount") private var violationCount = 0
    @State private var showViolationWarning = false
    @State private var showSuspensionWarning = false

    private let accentColor = Color(red: 1.0, green: 0.45, blue: 0.42)
    private let accentColor2 = Color(red: 1.0, green: 0.70, blue: 0.30)

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var canDeleteTopic: Bool {
        currentUid == topic.creatorUid
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
            if !blockedUids.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showBlockedUsersSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.xmark")
                    }
                    .accessibilityLabel("ブロック中のユーザーを管理")
                }
            }
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
            chatViewModel.observeOpenMessages(groupId: group.id, topicId: topic.id)
            groupViewModel.fetchMembers(for: group.id)
            ModerationService.fetchBlockedUids { blockedUids = $0 }
            navState.hidesCustomTabBar = true
        }
        .onDisappear {
            chatViewModel.stopObservingOpen()
            navState.hidesCustomTabBar = false
        }
        .confirmationDialog(
            "このトークルームを削除しますか？中のメッセージもすべて消えます",
            isPresented: $showDeleteTopicConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                chatViewModel.deleteOpenTopic(groupId: group.id, topic: topic)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(item: $reportTarget) { message in
            ReportComposerSheet(title: "このメッセージを報告") { reason, detail in
                ModerationService.reportMessage(
                    context: "groupChatOpen",
                    contextId: group.id,
                    messageId: message.id,
                    messageText: message.text,
                    reportedUid: message.senderUid,
                    reason: reason,
                    detail: detail
                )
                showReportThanksBriefly()
            }
        }
        .overlay(alignment: .top) {
            if showReportThanks {
                ReportThanksToast()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showReportThanks)
        .alert(
            blockTarget.map { "\(liveSenderName(for: $0))さんをブロックしますか？" } ?? "",
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } })
        ) {
            Button("キャンセル", role: .cancel) { blockTarget = nil }
            Button("ブロックする", role: .destructive) {
                if let uid = blockTarget?.senderUid {
                    ModerationService.blockUser(uid) { _ in
                        ModerationService.fetchBlockedUids { blockedUids = $0 }
                    }
                }
                blockTarget = nil
            }
        } message: {
            Text("このトークルーム内で、この人の発言が表示されなくなります")
        }
        .sheet(isPresented: $showBlockedUsersSheet) {
            BlockedUsersSheet(blockedUids: blockedUids) {
                ModerationService.fetchBlockedUids { blockedUids = $0 }
            }
        }
        .alert(
            "投稿する前に",
            isPresented: $showGuideline
        ) {
            Button("キャンセル", role: .cancel) {
                pendingSendText = nil
                pendingOriginalText = nil
            }
            Button("理解して投稿する") {
                hasSeenGuideline = true
                if let text = pendingSendText, let uid = currentUid {
                    performSend(text, uid: uid, originalText: pendingOriginalText)
                }
                pendingSendText = nil
                pendingOriginalText = nil
            }
        } message: {
            Text("名前とアイコンが表示される会話です。誹謗中傷や個人情報の書き込みなど、他の人を傷つける内容の投稿はご遠慮ください。悪質な投稿は利用制限の対象になります。")
        }
        .alert("規約違反です", isPresented: $showViolationWarning) {
            Button("OK") {}
        } message: {
            Text("「\(group.name)」で不適切な発言が感知されました。該当箇所を伏せ字にして送信しました。何度も感知された場合、アカウントが停止されることがあります。")
        }
        .alert("このままではアカウントが停止されます", isPresented: $showSuspensionWarning) {
            Button("OK") {}
        } message: {
            Text("「\(group.name)」で不適切な発言が繰り返し感知されています。今後も続く場合、確認のうえアカウントが停止されることがあります。")
        }
    }

    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
        }
    }

    // MARK: - 案内バナー

    private var banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityHidden(true)
            Text("名前もアイコンも公開されている会話です")
                .font(.system(size: 11.5, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
        )
    }

    // MARK: - メッセージ表示エリア

    // ★ ブロックした相手の発言は、削除はせず自分の画面からだけ丸ごと隠す
    private var visibleMessages: [Message] {
        chatViewModel.openMessages.filter { !blockedUids.contains($0.senderUid) }
    }

    @ViewBuilder
    private var messageArea: some View {
        if !chatViewModel.isOpenLoaded {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        } else if visibleMessages.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                    .accessibilityHidden(true)
                Text("まだメッセージがありません")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("最初のひとことで、友達づくりを始めてみましょう")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleMessages) { message in
                            messageRow(message)
                                .id(message.id)
                                .task { await loadProfileIfNeeded(for: message.senderUid) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                // ★ ChatRoomViewと同じく、下スワイプでキーボードを閉じられるようにする
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: visibleMessages.count) { _, _ in
                    guard let lastId = visibleMessages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
                .onAppear {
                    // ★ ChatRoomViewと同じ理由（LazyVStackのレイアウト未確定との競合）で、
                    //   1フレーム後に回して確実に最下部へ着地させる
                    guard let lastId = visibleMessages.last?.id else { return }
                    DispatchQueue.main.async {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - 送信者情報（users/{uid} を直接見て、常に最新の名前・アイコンを表示する）

    private func liveSenderName(for message: Message) -> String {
        if let cached = profileCache[message.senderUid] {
            return cached.displayName
        }
        return groupViewModel.members.first(where: { $0.uid == message.senderUid })?.displayName
            ?? message.senderName
    }

    private func avatarURL(for uid: String) -> URL? {
        if let cached = profileCache[uid], let iconURL = cached.iconURL {
            return URL(string: iconURL)
        }
        guard let iconURL = groupViewModel.members.first(where: { $0.uid == uid })?.iconURL else { return nil }
        return URL(string: iconURL)
    }

    private func loadProfileIfNeeded(for uid: String) async {
        guard profileCache[uid] == nil, !fetchingUids.contains(uid) else { return }
        fetchingUids.insert(uid)
        if let profile = await ChatViewModel.fetchUserProfile(uid: uid) {
            profileCache[uid] = profile
        }
        fetchingUids.remove(uid)
    }

    // ★ タップでその発言者のプロフィールを閲覧できるようにする（匿名版と違い実名なので可能）
    private func senderAvatar(for message: Message) -> some View {
        NavigationLink {
            UserProfileView(
                uid: message.senderUid,
                fallbackName: liveSenderName(for: message),
                fallbackIconURL: avatarURL(for: message.senderUid)?.absoluteString
            )
        } label: {
            avatarImage(for: message)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarImage(for message: Message) -> some View {
        if let url = avatarURL(for: message.senderUid) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder(for: message)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            avatarPlaceholder(for: message)
        }
    }

    private func avatarPlaceholder(for message: Message) -> some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(liveSenderName(for: message).prefix(1)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func messageRow(_ message: Message) -> some View {
        let isMine = message.senderUid == currentUid

        return VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if !isMine {
                Text(liveSenderName(for: message))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)
            }

            HStack(alignment: .bottom, spacing: 6) {
                if isMine { Spacer(minLength: 40) }
                if !isMine { senderAvatar(for: message) }

                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(isMine ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleBackground(isMine: isMine))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(isMine ? 0.12 : 0.05), radius: 6, x: 0, y: 3)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.68, alignment: isMine ? .trailing : .leading)

                if isMine { senderAvatar(for: message) }
                if !isMine { Spacer(minLength: 40) }
            }

            Text(CachedFormatters.date(format: "HH:mm").string(from: message.createdAt))
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(isMine ? .trailing : .leading, 36)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    chatViewModel.deleteOpenMessage(groupId: group.id, topicId: topic.id, message: message)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } else {
                Button {
                    reportTarget = message
                } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive) {
                    blockTarget = message
                } label: {
                    Label("ブロックする", systemImage: "person.crop.circle.badge.xmark")
                }
            }
        }
    }

    private func bubbleBackground(isMine: Bool) -> AnyShapeStyle {
        chatBubbleBackground(isMine: isMine, primary: accentColor, primary2: accentColor2)
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        ChatTextOnlyInputBar(
            inputText: $inputText,
            placeholder: "メッセージを入力",
            accentColor: accentColor,
            onSend: send
        )
    }

    // ★ 2026/08/16修正：NGワードチェック→初回のみガイドライン確認、の順に通してから送信する
    // ★ 2026/08/16修正：トーストの通知に加えて、はっきり閉じるまで消えない警告アラートに変更。
    //   違反を検知するたびにviolationCountを積み上げ、一定回数（3回目）からは
    //   より強い「このままだとアカウント停止」警告に切り替える（実際の停止処理は行わない。
    //   AnonymousChatRoomView.swiftの同名プロパティのコメント参照）
    private func send() {
        guard let uid = currentUid else { return }
        let original = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return }

        var trimmed = original
        let isViolation = NGWordFilter.firstProhibitedWord(in: trimmed) != nil
        if isViolation {
            trimmed = NGWordFilter.maskedText(trimmed)
        }

        guard hasSeenGuideline else {
            pendingSendText = trimmed
            pendingOriginalText = isViolation ? original : nil
            showGuideline = true
            return
        }

        if isViolation {
            violationCount += 1
            if violationCount >= 3 {
                showSuspensionWarning = true
            } else {
                showViolationWarning = true
            }
        }

        performSend(trimmed, uid: uid, originalText: isViolation ? original : nil)
    }

    // ★ 2026/08/16修正：伏せ字化された場合、元の発言をモデレーション専用コレクションへ
    //   別途保存する（詳細はModerationService.logFlaggedContentのコメント参照）
    private func performSend(_ text: String, uid: String, originalText: String? = nil) {
        let name = settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName
        chatViewModel.sendOpenMessage(groupId: group.id, topicId: topic.id, text: text, senderUid: uid, senderName: name, originalText: originalText)
        inputText = ""
    }
}

// MARK: - ブロック中のユーザー管理シート

// ★ ブロックはユーザー単位のグローバルな設定（users/{uid}/blockedUsers）なので、
//   このトークルームに限らず、ブロックした相手全員をここで解除できるようにする
private struct BlockedUsersSheet: View {
    let blockedUids: Set<String>
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [String: ChatViewModel.RemoteUserProfile] = [:]

    var body: some View {
        NavigationStack {
            List(Array(blockedUids).sorted(), id: \.self) { uid in
                HStack(spacing: 12) {
                    if let iconURL = profiles[uid]?.iconURL, let url = URL(string: iconURL) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Circle().fill(Color(.systemGray4))
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(Color(.systemGray4)).frame(width: 36, height: 36)
                    }

                    Text(profiles[uid]?.displayName ?? "読み込み中…")
                        .font(.system(size: 14, weight: .semibold))

                    Spacer(minLength: 0)

                    Button("解除する") {
                        ModerationService.unblockUser(uid) { _ in onChange() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .task {
                    guard profiles[uid] == nil else { return }
                    if let profile = await ChatViewModel.fetchUserProfile(uid: uid) {
                        profiles[uid] = profile
                    }
                }
            }
            .overlay {
                if blockedUids.isEmpty {
                    Text("ブロック中のユーザーはいません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("ブロック中のユーザー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
