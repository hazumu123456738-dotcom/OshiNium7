//
//  ChatRoomView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import FirebaseAuth

// ★ 2026/08/13：コミュニティチャットの仕様変更により、自由な会話（テキスト入力・画像/動画送信）
//   はこの画面から完全に無くした。代わりに「〜がコミュニティに参加しました」「新しい予定が
//   追加されました」「〜が退会しました」といったシステムメッセージだけを時系列で表示する、
//   グループの活動お知らせ掲示板として再設計している（firestore.rulesも合わせて
//   senderUid:'system'固定の書き込みしか許可しない形に締めた）。
//   自由な会話がしたい場合はDM（ChatTab側の別セクション）を使う設計に一本化した。
struct ChatRoomView: View {
    let group: IdolGroup

    @StateObject private var chatViewModel = ChatViewModel()
    @EnvironmentObject var navState: AppNavigationState

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    // ★ 過去（この仕様変更より前）に送信された通常の会話メッセージがドキュメントとして
    //   残っていても、この画面ではもう表示しない。isSystemのお知らせだけを対象にする
    private var systemMessages: [Message] {
        chatViewModel.messages.filter { $0.isSystem }
    }

    var body: some View {
        messageArea
            .padding(.bottom, customTabBarHeight)
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ★ メンバー管理（権限の確認・付与剥奪・強制退出・グループ削除）への入り口を
                //   チャット画面自体に置く。以前はマイページ→参加グループ経由でしか辿り着けず、
                //   実際に使う場面から遠かったため
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
                if let uid = currentUid {
                    chatViewModel.markGroupChatRead(groupId: group.id, uid: uid)
                }
                navState.hidesCustomTabBar = true
            }
            .onDisappear {
                chatViewModel.stopObserving()
                navState.hidesCustomTabBar = false
            }
    }

    // MARK: - お知らせ表示エリア（読み込み中／空／一覧を出し分け）

    @ViewBuilder
    private var messageArea: some View {
        if !chatViewModel.isLoaded {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        } else if systemMessages.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                Text("まだお知らせがありません")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("メンバーの参加・退会や予定の追加・削除がここに表示されます")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(systemMessages) { message in
                            systemMessageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .onChange(of: systemMessages.count) { _, _ in
                    guard let lastId = systemMessages.last?.id else { return }
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
                .onAppear {
                    guard let lastId = systemMessages.last?.id else { return }
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - システムメッセージ（参加・退会・予定の追加/削除など。吹き出しではなく中央寄せのピルで表示）
    //   ★ 以前は種類を問わず一律Color(.systemGray6)の灰色ピルだったため、参加・退会・予定追加・
    //   予定削除のどれなのか、流し読みでは見分けがつかなかった。種類ごとに色分けし、
    //   淡い色のピル背景＋アイコン＋濃い同系色の文字にすることで一目で区別できるようにする

    private func systemMessageRow(_ message: Message) -> some View {
        let category = SystemMessageCategory.resolve(message)
        return VStack(spacing: 3) {
            HStack {
                Spacer(minLength: 24)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.top, 1)
                    // ★ 種類を示すアイコンを追加したので、本文の先頭の絵文字(🎉/👋/🗓️/🗑️)は
                    //   アイコンと二重になるため表示上だけ取り除く(保存データ自体は変更しない)
                    Text(category.stripLeadingEmoji(from: message.text))
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(category.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(category.color.opacity(0.13))
                )
                Spacer(minLength: 24)
            }
            Text(message.createdAt.formatted(.dateTime.month().day().hour().minute()))
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

// ★ コミュニティチャットのお知らせ種別。Message.systemCategoryを優先し、
//   過去のメッセージ(この項目追加前に投稿済みで値が無いもの)は本文の絵文字から推測する。
//   ChatTab（グループ一覧の最新メッセージプレビュー行）でも同じ色分けを使うため、
//   fileprivateではなくinternalにしてある
enum SystemMessageCategory: String {
    case join, leave, eventAdded, eventDeleted, other

    static func resolve(_ message: Message) -> SystemMessageCategory {
        if let raw = message.systemCategory, let category = SystemMessageCategory(rawValue: raw) {
            return category
        }
        return infer(from: message.text)
    }

    private static func infer(from text: String) -> SystemMessageCategory {
        if text.hasPrefix("🎉") { return .join }
        if text.hasPrefix("👋") { return .leave }
        if text.hasPrefix("🗓️") { return .eventAdded }
        if text.hasPrefix("🗑️") { return .eventDeleted }
        return .other
    }

    var iconName: String {
        switch self {
        case .join: return "person.badge.plus"
        case .leave: return "person.badge.minus"
        case .eventAdded: return "calendar.badge.plus"
        case .eventDeleted: return "calendar.badge.minus"
        case .other: return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .join: return Color(red: 0.20, green: 0.62, blue: 0.42)
        case .leave: return Color(red: 0.55, green: 0.55, blue: 0.60)
        case .eventAdded: return Color.oshiniumPrimary
        case .eventDeleted: return Color(red: 0.88, green: 0.32, blue: 0.32)
        case .other: return .secondary
        }
    }

    // ★ 種別ごとの絵文字プレフィックス(+続く空白1文字)だけを取り除く。iconNameで
    //   同じ意味をすでに示しているため、本文側の絵文字は不要（二重表示になるのを防ぐ）
    func stripLeadingEmoji(from text: String) -> String {
        let prefixes = ["🎉 ", "👋 ", "🗓️ ", "🗑️ "]
        for prefix in prefixes where text.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count))
        }
        return text
    }
}
