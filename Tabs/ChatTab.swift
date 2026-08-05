//
//  ChatTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI
import UIKit
import FirebaseAuth

// ★ 「グループ」タブは、ホーム画面（またはマイページタブの長押し）で選択中の
//   グループのチャットを表示する。1つのグループにつき3つの入口が用意されている：
//   1) 通常のコミュニティチャット（名前・アイコン付き）
//   2) コミュニティチャット匿名版（AnonymousTopicListView。誰が言ったか一切表示されない、
//      本音を言いやすくするための場）
//   3) コミュニティチャット公開版（OpenTopicListView。匿名版と同じ「誰でも話題＝
//      トークルームを立てられ、他の人が立てたトークルームにも自由に参加・閲覧できる」
//      掲示板形式だが、こちらは名前・アイコンをそのまま公開する。同じ推しを応援する
//      友達を実アカウントで見つけたい人向けの入口。匿名版の落ち着いた紫グレーとは
//      対照的に、明るく賑やかな配色（コーラル×ゴールド）のバッジで見分けやすくする）
//   すべてカレンダータブと同じ配色・アイコン（金色の王冠＝コミュニティ、鍵＝招待制、
//   person.fill.questionmark＝匿名版、person.2.wave.2.fill＝公開版）をバッジとして使う。
//   別のグループに切り替えたい場合は、既存の「マイページタブを長押し」のグループ切り替えを使う。
//   - 「DM」タブ：相互フォローの相手とのやり取りのみ。
//   - 「DMリクエスト」タブ：相互フォローでない相手とのスレッドを別タブとして独立表示する
//     （DM欄の中に混ぜない）。相手から届いた未対応のリクエスト件数だけをこのタブの
//     横にバッジ表示する（自分から送っただけのものは通知しない）。
//   - 予定通知は「消して」との指示を受けつつも中身自体は有用な機能のため削除はせず、
//     ナビゲーションバーのベルアイコンから開けるシートに退避させた。
//   - 「公式」は準備中のダミー機能だったため削除した。
struct ChatTab: View {

    // ★ ホーム画面で選択中のグループ。予定通知シートの絞り込みに使う
    let selectedGroup: IdolGroup?

    @EnvironmentObject var notificationViewModel: AppNotificationViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var followViewModel: FollowViewModel

    enum ChatSection: String, CaseIterable {
        case group = "グループ"
        case dm = "DM"
        case dmRequest = "DMリクエスト"
    }

    @State private var selectedSection: ChatSection = .group
    @State private var showScheduleSheet = false
    @State private var showComposeSheet = false
    @StateObject private var dmThreadListVM = DMThreadListViewModel()
    @State private var lastMessages: [String: Message] = [:]
    @State private var latestAnonymousTopics: [String: AnonymousTopic] = [:]
    @State private var latestOpenTopics: [String: OpenTopic] = [:]
    @State private var myLastReadAt: [String: Date] = [:]

    // ★ カレンダータブの金色グラデーション（コミュニティ）と同じ配色をチャットの
    //   バッジにも使い、「これはコミュニティのチャットだ」と一目で分かるようにする
    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.85, blue: 0.45),
            Color(red: 0.80, green: 0.62, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    // ★ 公開版チャット（推し活の友達を見つける場）のバッジ配色。匿名版の落ち着いた
    //   紫グレーとは対照的に、「生誕祭」のような明るく賑やかな配色にして見分けやすくする
    private let openColor = Color(red: 1.0, green: 0.45, blue: 0.42)
    private let openColor2 = Color(red: 1.0, green: 0.70, blue: 0.30)

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    // ★ 「DMリクエスト」タブの横に表示する件数バッジ。相互フォローでない相手とのスレッドのうち、
    //   直近のメッセージを「相手が」送ってきたもの（＝自分が未対応のもの）だけを数える。
    //   自分から一方的に送っただけのもの（lastSenderUid == 自分）は通知の対象にしない
    private var dmRequestCount: Int {
        guard let currentUid else { return 0 }
        return dmThreadListVM.threads.filter { thread in
            guard let other = thread.otherUid(myUid: currentUid) else { return false }
            guard !followViewModel.isMutual(other) else { return false }
            return thread.lastSenderUid == other
        }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                switch selectedSection {
                case .group:
                    groupInbox
                case .dm:
                    DMListView(mode: .normal)
                case .dmRequest:
                    DMListView(mode: .requests)
                }
            }
            .navigationTitle("チャット")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showScheduleSheet = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("予定のお知らせ")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("新しいグループチャットを作る")
                }
            }
            .sheet(isPresented: $showScheduleSheet) {
                NavigationStack {
                    scheduleNotificationsSection
                        .navigationTitle("予定のお知らせ")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showComposeSheet) {
                NavigationStack {
                    NewPrivateGroupChatView()
                }
            }
        }
        .onAppear {
            if let currentUid {
                dmThreadListVM.startListening(uid: currentUid)
            }
        }
        .onDisappear {
            dmThreadListVM.stopListening()
        }
        .task(id: selectedGroup?.id) {
            await loadLastMessages()
        }
    }

    // MARK: - 選択中グループの2つの会話（通常のコミュニティチャット／匿名版）

    @ViewBuilder
    private var groupInbox: some View {
        if let selectedGroup {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    NavigationLink {
                        ChatRoomView(group: selectedGroup)
                    } label: {
                        groupRow(
                            group: selectedGroup,
                            subtitle: lastMessages[selectedGroup.id]?.text ?? "まだメッセージがありません",
                            timestamp: lastMessages[selectedGroup.id]?.createdAt,
                            badge: AnyView(typeBadge(for: selectedGroup)),
                            isUnread: isUnread(selectedGroup.id)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        OpenTopicListView(group: selectedGroup)
                    } label: {
                        groupRow(
                            group: selectedGroup,
                            subtitle: latestOpenTopics[selectedGroup.id].map { "話題「\($0.title)」" } ?? "まだトークルームがありません",
                            timestamp: latestOpenTopics[selectedGroup.id]?.lastMessageAt,
                            badge: AnyView(openBadge),
                            isOpenAvatar: true
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AnonymousTopicListView(group: selectedGroup)
                    } label: {
                        groupRow(
                            group: selectedGroup,
                            subtitle: latestAnonymousTopics[selectedGroup.id].map { "話題「\($0.title)」" } ?? "まだトークルームがありません",
                            timestamp: latestAnonymousTopics[selectedGroup.id]?.lastMessageAt,
                            badge: AnyView(anonymousBadge),
                            isAnonymousAvatar: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .refreshable {
                await loadLastMessages()
            }
        } else {
            noGroupSelectedState
        }
    }

    private func groupRow(group: IdolGroup, subtitle: String, timestamp: Date?, badge: AnyView, isAnonymousAvatar: Bool = false, isOpenAvatar: Bool = false, isUnread: Bool = false) -> some View {
        HStack(spacing: 12) {
            if isAnonymousAvatar {
                Circle()
                    .fill(Color(red: 0.45, green: 0.40, blue: 0.55))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)
                    )
            } else if isOpenAvatar {
                Circle()
                    .fill(
                        LinearGradient(colors: [openColor, openColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.2.wave.2.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)
                    )
            } else {
                groupAvatar(group)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isAnonymousAvatar ? "\(group.name)（匿名）" : isOpenAvatar ? "\(group.name)（公開）" : group.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    badge
                }
                Text(subtitle)
                    .font(.system(size: 12, weight: isUnread ? .semibold : .regular))
                    .foregroundColor(isUnread ? .primary : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                if let timestamp {
                    Text(relativeTime(timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                if isUnread {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 9, height: 9)
                        .accessibilityLabel("未読")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    @ViewBuilder
    private func groupAvatar(_ group: IdolGroup) -> some View {
        if let data = group.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(
                    LinearGradient(colors: [accentColor, accentColor2],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(group.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    // ★ カレンダータブの「コミュニティカレンダー」バッジと同じ配色・アイコン
    //   （金の王冠＝コミュニティ、鍵＝招待制）で統一する
    private func typeBadge(for group: IdolGroup) -> some View {
        Group {
            if group.isPrivate {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("招待制")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.gray)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(.systemGray5)))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .accessibilityHidden(true)
                    Text("コミュニティ")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(goldGradient))
                .shadow(color: Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.4), radius: 3, y: 1)
            }
        }
    }

    // ★ 匿名版チャットのバッジ（怖い印象を与えないよう、覆面ではなく「誰かわからない人」を
    //   表す person.fill.questionmark を使用。落ち着いた紫）
    private var anonymousBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 8, weight: .semibold))
                .accessibilityHidden(true)
            Text("匿名")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color(red: 0.55, green: 0.48, blue: 0.65), Color(red: 0.38, green: 0.34, blue: 0.50)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        )
    }

    // ★ 公開版チャットのバッジ。匿名版とは対照的に、明るく賑やかな配色で
    //   「ここは実名で友達を見つける場」だと一目で分かるようにする
    private var openBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 8, weight: .semibold))
                .accessibilityHidden(true)
            Text("公開")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(
                LinearGradient(colors: [openColor, openColor2], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        )
        .shadow(color: openColor.opacity(0.35), radius: 3, y: 1)
    }

    // MARK: - 最新メッセージの読み込み（一覧のプレビュー用）

    private func loadLastMessages() async {
        guard let selectedGroup else { return }
        if let message = await ChatViewModel.fetchLastMessage(groupId: selectedGroup.id) {
            await MainActor.run { self.lastMessages[selectedGroup.id] = message }
        }
        if let topic = await ChatViewModel.fetchLatestAnonymousTopic(groupId: selectedGroup.id) {
            await MainActor.run { self.latestAnonymousTopics[selectedGroup.id] = topic }
        }
        if let topic = await ChatViewModel.fetchLatestOpenTopic(groupId: selectedGroup.id) {
            await MainActor.run { self.latestOpenTopics[selectedGroup.id] = topic }
        }
        if let currentUid,
           let lastReadAt = await ChatViewModel.fetchMyLastReadAt(groupId: selectedGroup.id, uid: currentUid) {
            await MainActor.run { self.myLastReadAt[selectedGroup.id] = lastReadAt }
        }
    }

    // ★ 最新メッセージが自分以外からの送信で、最後に開いた時刻より新しければ未読とみなす
    private func isUnread(_ groupId: String) -> Bool {
        guard let message = lastMessages[groupId], message.senderUid != currentUid else { return false }
        let lastRead = myLastReadAt[groupId] ?? .distantPast
        return message.createdAt > lastRead
    }

    private var noGroupSelectedState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)
            Text("ホーム画面でグループを選択してください")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 上部タブ（丸みのあるピル方式）

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(section.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            if section == .dmRequest && dmRequestCount > 0 {
                                Text("\(dmRequestCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                            .foregroundColor(selectedSection == section ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Group {
                                    if selectedSection == section {
                                        Capsule().fill(
                                            LinearGradient(
                                                colors: [accentColor, accentColor2],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    } else {
                                        Capsule().fill(Color.appCardBackground)
                                    }
                                }
                            )
                            .shadow(color: .black.opacity(selectedSection == section ? 0.12 : 0.04), radius: 6, x: 0, y: 3)
                    }
                }
            }
        }
    }

    // MARK: - 予定通知（コミュニティカレンダーの予定追加・削除のお知らせ。選択中グループのみ）

    private var groupScheduleNotifications: [AppNotification] {
        guard let groupId = selectedGroup?.id else { return [] }
        return notificationViewModel.notifications
            .filter { ($0.type == "event_created" || $0.type == "event_deleted") && $0.groupId == groupId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @ViewBuilder
    private var scheduleNotificationsSection: some View {
        if selectedGroup == nil {
            noGroupSelectedState
        } else if groupScheduleNotifications.isEmpty {
            scheduleEmptyState
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(groupScheduleNotifications) { notification in
                        scheduleNotificationRow(notification)
                    }
                }
                .padding(16)
            }
            .refreshable {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    private var scheduleEmptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)
            Text("予定のお知らせはまだありません")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("コミュニティカレンダーに予定が追加・削除されると、ここに届きます")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    @ViewBuilder
    private func scheduleNotificationRow(_ notification: AppNotification) -> some View {
        let isCreated = notification.type == "event_created"
        let tintColor: Color = isCreated ? Color(red: 0.40, green: 0.72, blue: 0.55) : Color(red: 0.90, green: 0.45, blue: 0.45)

        let row = HStack(spacing: 12) {
            ZStack {
                Circle().fill(tintColor)
                Image(systemName: isCreated ? "calendar.badge.plus" : "calendar.badge.minus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(isCreated ? "新しい予定が追加されました" : "予定が削除されました")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text("「\(notification.eventTitle ?? "")」")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(relativeTime(notification.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )

        if let groupId = notification.groupId,
           let group = groupViewModel.groups.first(where: { $0.id == groupId }) {
            NavigationLink {
                ChatRoomView(group: group)
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
