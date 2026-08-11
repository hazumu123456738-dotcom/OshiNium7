//
//  ChatRoomView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import FirebaseAuth
import NukeUI
import PhotosUI
import AVKit

// ★ ChatRoomView・DirectMessageThreadViewで共通の「選択したメディア（画像/動画）」表現。
//   PhotosPickerは1枚ずつ画像か動画かが混在しうるため、どちらでも保持できるようにする
enum SelectedChatMedia {
    case image(UIImage)
    case video(URL)
}

struct ChatRoomView: View {
    let group: IdolGroup

    @StateObject private var chatViewModel = ChatViewModel()
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var navState: AppNavigationState

    @State private var inputText: String = ""

    // ★ 画像・動画添付。キャプション（inputText）とメディアはどちらか片方だけでも送信できる。
    //   複数枚（画像・動画混在可）まとめて選択でき、それぞれ個別のメッセージとして送信される
    //   （キャプションは先頭の1件にだけ添える）。ピッカーの選択状態自体はChatMediaInputBarが
    //   内部で持つため、ここではメッセージ送信対象のselectedMediaだけを保持する
    @State private var selectedMedia: [SelectedChatMedia] = []
    @State private var isSending = false
    @State private var imageViewerItem: IdentifiableURL?
    @State private var galleryContext: ChatImageGalleryContext?

    // ★ users/{uid} から取得したプロフィールのキャッシュ（大元のソースなので必ず最新が取れる）
    @State private var profileCache: [String: ChatViewModel.RemoteUserProfile] = [:]
    @State private var fetchingUids: Set<String> = []

    // ★ 通報（不適切なメッセージの報告）
    @State private var reportTarget: Message?
    @State private var showReportThanks = false

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 0) {
            messageArea
            inputBar
        }
        .padding(.bottom, customTabBarHeight)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ★ メンバー管理（権限の確認・付与剥奪・強制退出・グループ削除）への入り口を
            //   チャット画面自体に置く。以前はマイページ→参加グループ経由でしか辿り着けず、
            //   実際に使う場面（チャット中の不適切な発言への対処）から遠かったため
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    GroupMemberManagementView(group: group)
                } label: {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.primary)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            chatViewModel.observeMessages(groupId: group.id)
            groupViewModel.fetchMembers(for: group.id)
            if let uid = currentUid {
                chatViewModel.markGroupChatRead(groupId: group.id, uid: uid)
            }
            navState.hidesCustomTabBar = true
        }
        // ★ 画面を開いたままでいる間に新着メッセージが届いた場合も、その都度既読にする
        //   （閉じるまで未読バッジが古いままにならないように）
        .onChange(of: chatViewModel.messages.count) { _, _ in
            if let uid = currentUid {
                chatViewModel.markGroupChatRead(groupId: group.id, uid: uid)
            }
        }
        .onDisappear {
            chatViewModel.stopObserving()
            groupViewModel.stopFetchingMembers()
            navState.hidesCustomTabBar = false
        }
        .sheet(item: $reportTarget) { message in
            ReportComposerSheet(title: "このメッセージを報告") { reason, detail in
                ModerationService.reportMessage(
                    context: "groupChat",
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
        .fullScreenCover(item: $imageViewerItem) { item in
            ChatImageViewerView(imageURL: item.url)
        }
        .fullScreenCover(item: $galleryContext) { context in
            ChatImageGalleryView(imageURLs: context.urls, initialIndex: context.initialIndex)
        }
    }

    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
        }
    }

    // MARK: - 複数枚まとめ送信のグルーピング

    // ★ 同じbatchId（複数枚同時送信時にのみ付与される）を持つ連続したメッセージを
    //   1つの束としてまとめ、「重なった写真束」として1つの視覚単位で表示するための下ごしらえ。
    //   batchIdがnilのメッセージ（テキストのみ・単体メディア）は1件だけの束として扱う
    private var messageGroups: [[Message]] {
        var result: [[Message]] = []
        for message in chatViewModel.messages {
            if let batchId = message.batchId,
               let lastBatchId = result.last?.first?.batchId,
               lastBatchId == batchId {
                result[result.count - 1].append(message)
            } else {
                result.append([message])
            }
        }
        return result
    }

    // MARK: - メッセージ表示エリア（読み込み中／空／一覧を出し分け）

    @ViewBuilder
    private var messageArea: some View {
        if !chatViewModel.isLoaded {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        } else if chatViewModel.messages.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                Text("まだメッセージがありません")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("「\(group.name)」の最初のメッセージを送ってみましょう")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(messageGroups.enumerated()), id: \.offset) { _, group in
                            // ★ 動画が混ざったバッチは画像スタック表示の対象外（LazyImageでは
                            //   動画サムネイルを描画できないため）。その場合は1件ずつ従来通り表示する
                            if group.count > 1 && group.allSatisfy({ $0.mediaType != "video" }) {
                                mediaGroupRow(group)
                                    .id(group.last?.id)
                                    .task {
                                        if let uid = group.first?.senderUid {
                                            await loadProfileIfNeeded(for: uid)
                                        }
                                    }
                            } else {
                                ForEach(group) { message in
                                    Group {
                                        if message.isSystem {
                                            systemMessageRow(message)
                                        } else {
                                            messageRow(message)
                                                .task {
                                                    await loadProfileIfNeeded(for: message.senderUid)
                                                }
                                        }
                                    }
                                    .id(message.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
                // ★ メッセージ入力中にキーボードが出たままになりがちなので、
                //   Messagesアプリと同じくスクロール（下スワイプ）に連動してキーボードを閉じられるようにする
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chatViewModel.messages.count) { _, _ in
                    guard let lastId = chatViewModel.messages.last?.id else { return }
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
                .onAppear {
                    guard let lastId = chatViewModel.messages.last?.id else { return }
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 送信者情報（users/{uid} を直接見て、常に最新の名前・アイコンを表示する）
    //   ※ message.senderName は送信時点で固定されたスナップショットなので、
    //     プロフィール変更後の過去メッセージにも反映されるようここを経由して表示する。
    //   ※ groups/{id}/members のミラーは「参加した瞬間」のスナップショットで、
    //     機能追加前から参加している古いメンバーには存在しないことがあるためフォールバック止まりにする。

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

    // ★ タップでその発言者のプロフィールを閲覧できるようにする
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

    // MARK: - システムメッセージ（予定の追加・削除など。吹き出しではなく中央寄せのピルで表示）

    private func systemMessageRow(_ message: Message) -> some View {
        HStack {
            Spacer(minLength: 24)
            Text(message.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color(.systemGray6))
                )
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    // MARK: - メッセージ吹き出し（Instagram DM風：アイコンは吹き出し横・下揃え）

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

                messageContent(message, isMine: isMine)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.68, alignment: isMine ? .trailing : .leading)

                if isMine { senderAvatar(for: message) }

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
                    chatViewModel.deleteMessage(groupId: group.id, message: message)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } else {
                // ★ オーナー・管理者は他人の不適切な発言も削除できる
                if groupViewModel.myRole(in: group).canModerateContent {
                    Button(role: .destructive) {
                        chatViewModel.deleteMessage(groupId: group.id, message: message)
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


    // ★ 複数枚まとめて送信された画像を、1件ずつ別々の吹き出しに並べるのではなく、
    //   重なった写真束（スタック）として1つの視覚単位にまとめて表示する。
    //   キャプションは束の中の最初のメッセージに添えられているのでそれをそのまま使う。
    //   いいねは束の先頭メッセージを代表として扱う。タップで全画像をスワイプで見られる
    //   ギャラリーを開く
    private func mediaGroupRow(_ group: [Message]) -> some View {
        guard let first = group.first else { return AnyView(EmptyView()) }
        let isMine = first.senderUid == currentUid
        let lastCreatedAt = group.last?.createdAt ?? first.createdAt
        let caption = group.first(where: { !$0.text.isEmpty })?.text ?? ""

        return AnyView(
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if !isMine {
                    Text(liveSenderName(for: first))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    if isMine { Spacer(minLength: 40) }
                    if !isMine { senderAvatar(for: first) }

                    VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                        mediaStack(group, isMine: isMine)

                        if !caption.isEmpty {
                            Text(caption)
                                .font(.system(size: 15))
                                .foregroundColor(isMine ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(chatBubbleBackground(isMine: isMine, primary: Color.oshiniumPrimary, primary2: Color.oshiniumPrimary2))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.68, alignment: isMine ? .trailing : .leading)

                    if isMine { senderAvatar(for: first) }
                    if !isMine { Spacer(minLength: 40) }
                }

                Text(lastCreatedAt.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(isMine ? .trailing : .leading, 36)
            }
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            .contextMenu {
                if isMine {
                    Button(role: .destructive) {
                        for message in group {
                            chatViewModel.deleteMessage(groupId: self.group.id, message: message)
                        }
                    } label: {
                        Label("\(group.count)枚まとめて削除", systemImage: "trash")
                    }
                } else {
                    if groupViewModel.myRole(in: self.group).canModerateContent {
                        Button(role: .destructive) {
                            for message in group {
                                chatViewModel.deleteMessage(groupId: self.group.id, message: message)
                            }
                        } label: {
                            Label("\(group.count)枚まとめて削除（管理者）", systemImage: "trash")
                        }
                    }
                    Button {
                        reportTarget = first
                    } label: {
                        Label("報告する", systemImage: "exclamationmark.bubble")
                    }
                }
            }
        )
    }

    // ★ 写真が少しずつ回転・オフセットしながら重なった「束」の見た目。
    //   先頭（最初に送った1枚）が一番手前に来るようにZStackの描画順を後ろから積む。
    //   4枚以上ある場合は見えている一番奥の1枚に「+N」バッジを重ねて、
    //   実際の枚数がひと目でわかるようにする
    private func mediaStack(_ group: [Message], isMine: Bool) -> some View {
        let urls: [URL] = group.compactMap { $0.imageURL.flatMap(URL.init) }
        let visibleLayers = min(urls.count, 3)
        let extraCount = urls.count - visibleLayers
        let first = group[0]

        return ZStack(alignment: .topTrailing) {
            ForEach(Array((0..<visibleLayers).reversed()), id: \.self) { i in
                LazyImage(url: urls[i]) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray6)
                    }
                }
                .frame(width: 200, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.appBackground, lineWidth: i == 0 ? 0 : 2)
                )
                .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
                .rotationEffect(.degrees(Double(i) * 3))
                .offset(x: CGFloat(i) * 7, y: CGFloat(i) * 7)
                .zIndex(Double(visibleLayers - i))

                if i == visibleLayers - 1 && extraCount > 0 {
                    Text("+\(extraCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .offset(x: CGFloat(i) * 7 + 6, y: CGFloat(i) * 7 - 6)
                        .zIndex(Double(visibleLayers + 1))
                }
            }
        }
        .frame(width: 220, height: 260, alignment: .topLeading)
        .overlay(alignment: isMine ? .bottomLeading : .bottomTrailing) {
            if !first.likedBy.isEmpty {
                ChatReactionBadge(count: first.likedBy.count)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: first.likedBy)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard let uid = currentUid else { return }
            chatViewModel.toggleLike(groupId: self.group.id, message: first, uid: uid)
        }
        .onTapGesture(count: 1) {
            galleryContext = ChatImageGalleryContext(urls: urls, initialIndex: 0)
        }
        .accessibilityLabel(first.likedBy.isEmpty ? "画像\(urls.count)枚" : "画像\(urls.count)枚、いいね\(first.likedBy.count)件")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            galleryContext = ChatImageGalleryContext(urls: urls, initialIndex: 0)
        }
        .accessibilityAction(named: currentUid.map { first.likedBy.contains($0) } == true ? "いいねを取り消す" : "いいね") {
            guard let uid = currentUid else { return }
            chatViewModel.toggleLike(groupId: self.group.id, message: first, uid: uid)
        }
    }

    // ★ 画像付きメッセージは吹き出し（Capsule）ではなく角丸の写真カードで表示し、
    //   キャプション（text）があればその下に添える。テキストのみの場合は従来通りのCapsule。
    //   画像は正方形に切り抜かず、実際の縦横比のまま（見切れなく）表示する。
    //   画像はシングルタップで全画面表示、ダブルタップでハートリアクション。
    //   テキストのみのバブルはダブルタップでハートリアクション
    @ViewBuilder
    private func messageContent(_ message: Message, isMine: Bool) -> some View {
        if let imageURLString = message.imageURL, let mediaURL = URL(string: imageURLString) {
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.mediaType == "video" {
                        ChatVideoBubble(videoURL: mediaURL) {
                            guard let uid = currentUid else { return }
                            chatViewModel.toggleLike(groupId: group.id, message: message, uid: uid)
                        }
                    } else {
                        LazyImage(url: mediaURL) { state in
                            if let image = state.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 200, height: 200)
                            }
                        }
                        .frame(maxWidth: 220, maxHeight: 280)
                        .onTapGesture(count: 2) {
                            guard let uid = currentUid else { return }
                            chatViewModel.toggleLike(groupId: group.id, message: message, uid: uid)
                        }
                        .onTapGesture(count: 1) {
                            imageViewerItem = IdentifiableURL(url: mediaURL)
                        }
                        .accessibilityLabel(message.likedBy.isEmpty ? "画像" : "画像、いいね\(message.likedBy.count)件")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            imageViewerItem = IdentifiableURL(url: mediaURL)
                        }
                        .accessibilityAction(named: currentUid.map { message.likedBy.contains($0) } == true ? "いいねを取り消す" : "いいね") {
                            guard let uid = currentUid else { return }
                            chatViewModel.toggleLike(groupId: group.id, message: message, uid: uid)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(isMine ? 0.12 : 0.05), radius: 6, x: 0, y: 3)
                .overlay(alignment: isMine ? .bottomLeading : .bottomTrailing) {
                    if !message.likedBy.isEmpty {
                        ChatReactionBadge(count: message.likedBy.count)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: message.likedBy)

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(isMine ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(chatBubbleBackground(isMine: isMine, primary: Color.oshiniumPrimary, primary2: Color.oshiniumPrimary2))
                        .clipShape(Capsule())
                }
            }
        } else {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundColor(isMine ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(chatBubbleBackground(isMine: isMine, primary: Color.oshiniumPrimary, primary2: Color.oshiniumPrimary2))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(isMine ? 0.12 : 0.05), radius: 6, x: 0, y: 3)
                .overlay(alignment: isMine ? .bottomLeading : .bottomTrailing) {
                    if !message.likedBy.isEmpty {
                        ChatReactionBadge(count: message.likedBy.count)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: message.likedBy)
                .accessibilityValue(message.likedBy.isEmpty ? "" : "いいね\(message.likedBy.count)件")
                .onTapGesture(count: 2) {
                    guard let uid = currentUid else { return }
                    chatViewModel.toggleLike(groupId: group.id, message: message, uid: uid)
                }
                .accessibilityAction(named: currentUid.map { message.likedBy.contains($0) } == true ? "いいねを取り消す" : "いいね") {
                    guard let uid = currentUid else { return }
                    chatViewModel.toggleLike(groupId: group.id, message: message, uid: uid)
                }
        }
    }

    // MARK: - 入力バー

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedMedia.isEmpty
    }

    private var inputBar: some View {
        ChatMediaInputBar(
            inputText: $inputText,
            selectedMedia: $selectedMedia,
            isSending: $isSending,
            accentColor: Color.oshiniumPrimary,
            placeholder: "メッセージを入力",
            onSend: send
        )
    }

    private func send() {
        guard let uid = currentUid, canSend else { return }
        let name = settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName
        let text = inputText
        let mediaToSend = selectedMedia

        inputText = ""
        selectedMedia = []

        guard !mediaToSend.isEmpty else {
            chatViewModel.sendMessage(groupId: group.id, groupName: group.name, text: text, senderUid: uid, senderName: name) { error in
                // ★ 通報を受けて制限されたユーザー等、サーバー側で拒否された場合に
                //   黙って何も起きないままにしない
                if error != nil { navState.showToast("メッセージを送信できませんでした") }
            }
            return
        }

        // ★ 2枚以上まとめて選んだ場合は共通のbatchIdを持たせ、チャット一覧側で
        //   「重なった写真束」として1つの視覚単位にまとめて表示できるようにする
        let batchId = mediaToSend.count > 1 ? UUID().uuidString : nil

        isSending = true
        Task {
            defer { isSending = false }
            // ★ 複数選択した場合、1件ずつ個別のメッセージとして順に送信する。
            //   キャプションは先頭の1件にだけ添える（Instagram等のマルチ送信と同じ考え方）
            for (index, media) in mediaToSend.enumerated() {
                do {
                    switch media {
                    case .image(let image):
                        let url = try await ImageStorageService.shared.uploadChatImage(image, groupId: group.id)
                        chatViewModel.sendMessage(
                            groupId: group.id,
                            groupName: group.name,
                            text: index == 0 ? text : "",
                            senderUid: uid,
                            senderName: name,
                            imageURL: url,
                            batchId: batchId
                        )
                    case .video(let fileURL):
                        let url = try await ImageStorageService.shared.uploadChatVideo(fileURL: fileURL, groupId: group.id)
                        chatViewModel.sendMessage(
                            groupId: group.id,
                            groupName: group.name,
                            text: index == 0 ? text : "",
                            senderUid: uid,
                            senderName: name,
                            imageURL: url,
                            mediaType: "video",
                            batchId: batchId
                        )
                    }
                } catch {
                    print("🔥 チャットメディアアップロードエラー:", error.localizedDescription)
                    await MainActor.run {
                        navState.showToast("メッセージを送信できませんでした")
                    }
                }
            }
        }
    }
}
