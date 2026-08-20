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
    @State private var showReportThanks = false
    @State private var showDeleteTopicConfirm = false

    // ★ 2026/08/18（/ultスキル監査）追加：以前は匿名チャットに「報告する」しか無く、
    //   迷惑な相手を個別に見えなくする手段が無かった。senderUidはモデレーション用に
    //   残っているため、既存のブロック機構(ModerationService.blockUser、
    //   users/{uid}/blockedUsers)をそのまま使う。ブロックしても相手のプロフィール等は
    //   一切表示しないため、「匿名」自体は破らない（自分の画面から今後の発言が
    //   消えるだけで、相手が誰かは最後まで分からないまま）
    @State private var blockedUids: Set<String> = []
    @State private var blockTarget: Message?
    @State private var showBlockConfirm = false

    // ★ 2026/08/16追加：投稿前ガイドライン。トークルームごとではなく「匿名チャット全体」で
    //   1度確認すれば十分なため、端末単位でAppStorageに保存する（毎回出すと逆に読まれなくなる）
    @AppStorage("hasSeenAnonymousChatGuideline") private var hasSeenGuideline = false
    @State private var showGuideline = false
    @State private var pendingSendText: String?
    @State private var pendingOriginalText: String?

    // ★ 2026/08/16追加：NGワード検知回数（匿名・公開トークルーム共通でカウント）。
    //   実際にアカウントを自動停止する処理はここでは行わない（restrictedUsersはFirestore
    //   ルール上クライアントから一切書き込めず、運営が通報内容を確認した上で手動制限する方針
    //   のため）。ここではあくまで「繰り返すと制限され得る」ことを本人に伝える警告のみを行う
    @AppStorage("ngWordViolationCount") private var violationCount = 0
    @State private var showViolationWarning = false
    @State private var showSuspensionWarning = false

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
            ModerationService.fetchBlockedUids { blockedUids = $0 }
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
        .sheet(item: $reportTarget) { message in
            ReportComposerSheet(title: "このメッセージを報告") { reason, detail in
                ModerationService.reportMessage(
                    context: "groupChatAnonymous",
                    contextId: group.id,
                    messageId: message.id,
                    messageText: message.text,
                    reportedUid: message.senderUid,
                    reason: reason,
                    detail: detail
                ) { error in
                    if error != nil {
                        navState.showToast("通報を送信できませんでした。もう一度お試しください")
                    } else {
                        showReportThanksBriefly()
                    }
                }
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
            Text("匿名だからといって何を書いてもよいわけではありません。誹謗中傷・個人が特定できる内容・性的な内容の投稿は禁止されています。「匿名」は他のユーザーから見えないという意味であり、運営者はいつでも投稿者を特定できる形で記録しています。悪質な投稿は利用制限の対象になります。")
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
        .confirmationDialog(
            "この匿名ユーザーをブロックしますか？",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("ブロックする", role: .destructive) {
                guard let uid = blockTarget?.senderUid else { return }
                ModerationService.blockUser(uid) { error in
                    if error != nil {
                        navState.showToast("ブロックできませんでした。もう一度お試しください")
                    } else {
                        blockedUids.insert(uid)
                        navState.showToast("ブロックしました")
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今後、この人の発言はあなたの画面には表示されなくなります。相手には通知されません。")
        }
    }

    // ★ ブロック済みの相手の発言は自分の画面からだけ丸ごと非表示にする
    //   （グループの共有データ自体には影響させない、既存のPostViewModel等と同じ方針）
    private var visibleMessages: [Message] {
        chatViewModel.anonymousMessages.filter {
            $0.senderUid == currentUid || !blockedUids.contains($0.senderUid)
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
        } else if visibleMessages.isEmpty {
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
                        LoadOlderMessagesTrigger(
                            isLoading: chatViewModel.isLoadingOlderAnonymousMessages,
                            hasMore: chatViewModel.hasMoreOlderAnonymousMessages
                        ) {
                            chatViewModel.loadOlderAnonymousMessages(groupId: group.id, topicId: topic.id)
                        }
                        ForEach(visibleMessages) { message in
                            messageRow(message)
                                .id(message.id)
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

    // ★ 2026/08/16追加：匿名アイコンをタップしても相手のアカウントは分からないようにしたまま、
    //   その場で通報できるようにする（今までは長押しの「報告する」でしか通報できなかった）
    private func reportableAnonymousAvatar(for message: Message) -> some View {
        Button {
            reportTarget = message
        } label: {
            anonymousAvatar
        }
        .buttonStyle(.plain)
        .accessibilityLabel("この匿名ユーザーを通報する")
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
                if !isMine { reportableAnonymousAvatar(for: message) }

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

            Text(CachedFormatters.date(format: "HH:mm").string(from: message.createdAt))
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
                Button {
                    reportTarget = message
                } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive) {
                    blockTarget = message
                    showBlockConfirm = true
                } label: {
                    Label("この人をブロックする", systemImage: "hand.raised.fill")
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

    // ★ 2026/08/16修正：NGワードチェック→初回のみガイドライン確認、の順に通してから送信する
    // ★ 2026/08/16修正：トーストの通知に加えて、はっきり閉じるまで消えない警告アラートに変更。
    //   違反を検知するたびにviolationCountを積み上げ、一定回数（3回目）からは
    //   より強い「このままだとアカウント停止」警告に切り替える。
    //   ★ 実際にアカウントを止める処理はここでは行わない。restrictedUsersはFirestoreルール上
    //   クライアントから書き込めない設計になっており（通報内容を運営が確認した上で
    //   手動制限する方針）、ここは本人に自覚を促す警告表示だけにとどめる
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
        chatViewModel.sendAnonymousMessage(groupId: group.id, topicId: topic.id, text: text, senderUid: uid, originalText: originalText) { error in
            // ★ 発見(全画面UIレビュー)：利用制限中のユーザー等、送信が拒否された場合に
            //   入力欄だけ空になり何も起きなかったように見えていた
            if error != nil {
                navState.showToast("メッセージを送信できませんでした")
            }
        }
        inputText = ""
    }
}
