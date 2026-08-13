//
//  DirectMessageThreadView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import FirebaseAuth
import NukeUI
import PhotosUI
import AVKit

// ★ DMの個別チャット画面（ChatRoomViewのDM版）
struct DirectMessageThreadView: View {
    let otherUid: String
    let otherName: String
    let otherIconURL: String?

    @StateObject private var dmViewModel = DirectMessageViewModel()
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var navState: AppNavigationState
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    @State private var inputText: String = ""
    @State private var reportTarget: Message?
    @State private var showReportThanks = false
    @State private var isBlockedEitherWay = false
    @State private var amIBlockingThem = false
    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false

    // ★ 画像・動画添付。ChatRoomViewと同じくキャプションとメディアはどちらか片方だけでも送信できる。
    //   複数選択（画像・動画混在可）でき、それぞれ個別のメッセージとして送信される（キャプションは先頭の1件にだけ添える）。
    //   ピッカーの選択状態自体はChatMediaInputBarが内部で持つ
    @State private var selectedMedia: [SelectedChatMedia] = []
    @State private var isSending = false
    @State private var imageViewerItem: IdentifiableURL?
    @State private var galleryContext: ChatImageGalleryContext?
    // ★ 投稿シェアカード(sharedPostCard)をタップした時、その投稿者のプロフィールへ飛ぶための状態
    @State private var sharedProfileUid: String?

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var threadId: String? {
        guard let currentUid else { return nil }
        return DMThread.threadId(currentUid, otherUid)
    }

    // ★ 実際の判定ロジックはDirectMessagePolicy（Firebase非依存の純粋関数、ユニットテスト対象）に
    //   切り出してあり、ここではその場の状態を渡して呼ぶだけにする
    private var isMutual: Bool { followViewModel.isMutual(otherUid) }
    private var isRequestLimited: Bool {
        guard let currentUid else { return false }
        return DirectMessagePolicy.isRequestLimited(
            messages: dmViewModel.messages,
            currentUid: currentUid,
            otherUid: otherUid,
            isMutual: isMutual
        )
    }

    private func isLastMineSeen(_ message: Message) -> Bool {
        guard let currentUid else { return false }
        return DirectMessagePolicy.isLastMineSeen(
            message: message,
            lastMessageId: dmViewModel.messages.last?.id,
            currentUid: currentUid,
            otherReadAt: dmViewModel.otherReadAt
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            messageArea
            if isBlockedEitherWay {
                blockedNotice
            } else if isRequestLimited {
                requestLimitNotice
            } else {
                inputBar
            }
        }
        .padding(.bottom, customTabBarHeight)
        .navigationTitle(otherName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if amIBlockingThem {
                        Button {
                            showUnblockConfirm = true
                        } label: {
                            Label("ブロックを解除", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    } else {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("ブロックする", systemImage: "person.crop.circle.badge.xmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
        .onAppear {
            guard let threadId, let currentUid else { return }
            dmViewModel.observeMessages(threadId: threadId)
            dmViewModel.observeOtherRead(threadId: threadId, otherUid: otherUid)
            dmViewModel.markThreadRead(threadId: threadId, uid: currentUid)
            refreshBlockState()
            navState.hidesCustomTabBar = true
        }
        // ★ 開いたまま新着が届いた場合も、その都度既読にする（グループチャットと同じ考え方）
        .onChange(of: dmViewModel.messages.count) { _, _ in
            if let threadId, let currentUid {
                dmViewModel.markThreadRead(threadId: threadId, uid: currentUid)
            }
        }
        .onDisappear {
            dmViewModel.stopObserving()
            dmViewModel.stopObservingRead()
            navState.hidesCustomTabBar = false
        }
        .alert("\(otherName)さんをブロックしますか？", isPresented: $showBlockConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("ブロックする", role: .destructive) {
                ModerationService.blockUser(otherUid) { _ in refreshBlockState() }
            }
        } message: {
            Text("ブロックすると、お互いにメッセージを送れなくなります")
        }
        .alert("\(otherName)さんのブロックを解除しますか？", isPresented: $showUnblockConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("解除する") {
                ModerationService.unblockUser(otherUid) { _ in refreshBlockState() }
            }
        }
        .sheet(item: $reportTarget) { message in
            ReportComposerSheet(title: "このメッセージを報告") { reason, detail in
                if let threadId {
                    ModerationService.reportMessage(
                        context: "dm",
                        contextId: threadId,
                        messageId: message.id,
                        messageText: message.text,
                        reportedUid: message.senderUid,
                        reason: reason,
                        detail: detail
                    )
                }
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
        .sheet(isPresented: Binding(
            get: { sharedProfileUid != nil },
            set: { if !$0 { sharedProfileUid = nil } }
        )) {
            if let sharedProfileUid {
                NavigationStack {
                    UserProfileView(uid: sharedProfileUid)
                }
            }
        }
    }

    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
        }
    }

    private var blockedNotice: some View {
        Text("ブロックしているため、メッセージを送信できません")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appCardBackground.shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3))
    }

    // ★ リクエストする側が既に1通送っていて、相手からの返信がまだ無い状態
    private var requestLimitNotice: some View {
        Text("\(otherName)さんからの返信があるまで、次のメッセージは送れません")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appCardBackground.shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3))
    }

    private func refreshBlockState() {
        guard let currentUid else { return }
        ModerationService.amIBlocking(otherUid) { blocking in
            amIBlockingThem = blocking
        }
        ModerationService.isBlockedEitherWay(myUid: currentUid, otherUid: otherUid) { blocked in
            isBlockedEitherWay = blocked
        }
    }

    // ★ 同じbatchId（複数枚同時送信時にのみ付与される）を持つ連続したメッセージを
    //   1つの束としてまとめ、「重なった写真束」として1つの視覚単位で表示するための下ごしらえ
    //   （ChatRoomViewと同じ考え方）
    private var messageGroups: [[Message]] {
        var result: [[Message]] = []
        for message in dmViewModel.messages {
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

    @ViewBuilder
    private var messageArea: some View {
        if !dmViewModel.isLoaded {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        } else if dmViewModel.messages.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                Text("まだメッセージがありません")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("\(otherName)さんに最初のメッセージを送ってみましょう")
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
                                mediaGroupRow(group, isLastMineSeen: group.last.map(isLastMineSeen) ?? false)
                                    .id(group.last?.id)
                            } else {
                                ForEach(group) { message in
                                    messageRow(message, isLastMineSeen: isLastMineSeen(message))
                                        .id(message.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                // ★ ChatRoomViewと同じく、下スワイプでキーボードを閉じられるようにする
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: dmViewModel.messages.count) { _, _ in
                    guard let lastId = dmViewModel.messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
                .onAppear {
                    guard let lastId = dmViewModel.messages.last?.id else { return }
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func avatarImage() -> some View {
        if let otherIconURL, let url = URL(string: otherIconURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 28, height: 28)
            .overlay(
                Text(String(otherName.prefix(1)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func messageRow(_ message: Message, isLastMineSeen: Bool = false) -> some View {
        let isMine = message.senderUid == currentUid

        return VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .bottom, spacing: 6) {
                if isMine { Spacer(minLength: 40) }
                if !isMine { avatarImage() }

                messageContent(message, isMine: isMine)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.68, alignment: isMine ? .trailing : .leading)

                if isMine { avatarImage() }
                if !isMine { Spacer(minLength: 40) }
            }

            Text(message.createdAt.formatted(.dateTime.hour().minute()))
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(isMine ? .trailing : .leading, 36)

            // ★ Instagram DM風の既読表示。自分が送った直近のメッセージが相手に読まれたら表示する
            if isLastMineSeen {
                Text("既読")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.trailing, 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .contextMenu {
            if isMine, let threadId {
                Button(role: .destructive) {
                    dmViewModel.deleteMessage(threadId: threadId, message: message)
                } label: {
                    Label("削除", systemImage: "trash")
                }
            } else if !isMine {
                Button {
                    reportTarget = message
                } label: {
                    Label("報告する", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    // ★ 複数枚まとめて送信された画像を、1件ずつ別々の吹き出しに並べるのではなく、
    //   重なった写真束（スタック）として1つの視覚単位にまとめて表示する（ChatRoomViewと同じ考え方）。
    //   いいねは束の先頭メッセージを代表として扱う。タップで全画像をスワイプで見られるギャラリーを開く
    private func mediaGroupRow(_ group: [Message], isLastMineSeen: Bool = false) -> some View {
        guard let first = group.first else { return AnyView(EmptyView()) }
        let isMine = first.senderUid == currentUid
        let lastCreatedAt = group.last?.createdAt ?? first.createdAt
        let caption = group.first(where: { !$0.text.isEmpty })?.text ?? ""

        return AnyView(
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 6) {
                    if isMine { Spacer(minLength: 40) }
                    if !isMine { avatarImage() }

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

                    if isMine { avatarImage() }
                    if !isMine { Spacer(minLength: 40) }
                }

                Text(lastCreatedAt.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(isMine ? .trailing : .leading, 36)

                if isLastMineSeen {
                    Text("既読")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.trailing, 36)
                }
            }
            .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
            .contextMenu {
                if isMine, let threadId {
                    Button(role: .destructive) {
                        for message in group {
                            dmViewModel.deleteMessage(threadId: threadId, message: message)
                        }
                    } label: {
                        Label("\(group.count)枚まとめて削除", systemImage: "trash")
                    }
                } else if !isMine {
                    Button {
                        reportTarget = first
                    } label: {
                        Label("報告する", systemImage: "exclamationmark.bubble")
                    }
                }
            }
        )
    }

    // ★ 写真が少しずつ回転・オフセットしながら重なった「束」の見た目（ChatRoomViewと同じ）
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
            guard let currentUid, let threadId else { return }
            dmViewModel.toggleLike(threadId: threadId, message: first, uid: currentUid)
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
            guard let currentUid, let threadId else { return }
            dmViewModel.toggleLike(threadId: threadId, message: first, uid: currentUid)
        }
    }

    // ★ 画像付きメッセージは吹き出し（Capsule）ではなく角丸の写真カードで表示し、
    //   キャプション（text）があればその下に添える（ChatRoomViewと同じパターン）。
    //   画像は正方形に切り抜かず、実際の縦横比のまま（見切れなく）表示する。
    //   画像はシングルタップで全画面表示、ダブルタップでハートリアクション。
    //   テキストのみのバブルはダブルタップでハートリアクション
    @ViewBuilder
    private func messageContent(_ message: Message, isMine: Bool) -> some View {
        // ★ 投稿シェア(SharePostSheet)由来のメッセージは、画像だけのメッセージと区別し、
        //   「誰の投稿か」が一目でわかるカードにする。タップした瞬間に投稿者のプロフィールへ飛べる
        //   （ダブルタップは他の画像メッセージと同じくハートリアクションのまま残す）
        if let sharedAuthorUid = message.sharedPostAuthorUid,
           let imageURLString = message.imageURL,
           let mediaURL = URL(string: imageURLString) {
            sharedPostCard(message, isMine: isMine, mediaURL: mediaURL, sharedAuthorUid: sharedAuthorUid)
        } else if let imageURLString = message.imageURL, let mediaURL = URL(string: imageURLString) {
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.mediaType == "video" {
                        ChatVideoBubble(videoURL: mediaURL) {
                            guard let currentUid, let threadId else { return }
                            dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
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
                            guard let currentUid, let threadId else { return }
                            dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
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
                            guard let currentUid, let threadId else { return }
                            dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
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
                    guard let currentUid, let threadId else { return }
                    dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
                }
                .accessibilityAction(named: currentUid.map { message.likedBy.contains($0) } == true ? "いいねを取り消す" : "いいね") {
                    guard let currentUid, let threadId else { return }
                    dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
                }
        }
    }

    // ★ 投稿シェアカード。画像の下に「〇〇さんの投稿・グループ名」のラベルを添え、
    //   カード全体（画像＋ラベル）をシングルタップで投稿者のプロフィールへ飛べるようにする。
    //   ダブルタップは他のメッセージと揃えてハートリアクションのまま残す
    private func sharedPostCard(_ message: Message, isMine: Bool, mediaURL: URL, sharedAuthorUid: String) -> some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 0) {
            Group {
                if message.mediaType == "video" {
                    ChatVideoBubble(videoURL: mediaURL) {
                        guard let currentUid, let threadId else { return }
                        dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
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
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(message.text.isEmpty ? "投稿を見る" : message.text)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(isMine ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 220, alignment: .leading)
            .background(chatBubbleBackground(isMine: isMine, primary: Color.oshiniumPrimary, primary2: Color.oshiniumPrimary2))
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
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard let currentUid, let threadId else { return }
            dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
        }
        .onTapGesture(count: 1) {
            sharedProfileUid = sharedAuthorUid
        }
        .accessibilityLabel("\(message.sharedPostAuthorName ?? "投稿者")さんの投稿")
        .accessibilityHint("タップしてプロフィールを見る")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            sharedProfileUid = sharedAuthorUid
        }
        .accessibilityAction(named: currentUid.map { message.likedBy.contains($0) } == true ? "いいねを取り消す" : "いいね") {
            guard let currentUid, let threadId else { return }
            dmViewModel.toggleLike(threadId: threadId, message: message, uid: currentUid)
        }
    }

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
        guard let currentUid, let threadId, !isBlockedEitherWay, !isRequestLimited, canSend else { return }
        let name = settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName
        let text = inputText
        let mediaToSend = selectedMedia

        inputText = ""
        selectedMedia = []

        guard !mediaToSend.isEmpty else {
            dmViewModel.sendMessage(
                threadId: threadId,
                participants: [currentUid, otherUid],
                text: text,
                senderUid: currentUid,
                senderName: name
            ) { error in
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
            // ★ 複数選択した場合、1件ずつ個別のメッセージとして順に送信する。キャプションは先頭の1件にだけ添える
            for (index, media) in mediaToSend.enumerated() {
                do {
                    switch media {
                    case .image(let image):
                        let url = try await ImageStorageService.shared.uploadChatImage(image, groupId: "dm_\(threadId)")
                        dmViewModel.sendMessage(
                            threadId: threadId,
                            participants: [currentUid, otherUid],
                            text: index == 0 ? text : "",
                            senderUid: currentUid,
                            senderName: name,
                            imageURL: url,
                            batchId: batchId
                        )
                    case .video(let fileURL):
                        let url = try await ImageStorageService.shared.uploadChatVideo(fileURL: fileURL, groupId: "dm_\(threadId)")
                        dmViewModel.sendMessage(
                            threadId: threadId,
                            participants: [currentUid, otherUid],
                            text: index == 0 ? text : "",
                            senderUid: currentUid,
                            senderName: name,
                            imageURL: url,
                            mediaType: "video",
                            batchId: batchId
                        )
                    }
                } catch {
                    print("🔥 DMメディアアップロードエラー:", error.localizedDescription)
                    await MainActor.run {
                        navState.showToast("メッセージを送信できませんでした")
                    }
                }
            }
        }
    }
}
