//
//  NotificationsTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI
import NukeUI
import FirebaseAuth

// ★ フォローされた時などのアプリ内通知一覧。
//   サーバー側のpush基盤（Cloud Functions/FCM）がまだ無いため、アプリを開いている間に
//   Firestoreのリアルタイム購読で届く「アプリ内通知」という位置づけ
struct NotificationsTab: View {

    @EnvironmentObject var notificationViewModel: AppNotificationViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var followViewModel: FollowViewModel

    // ★ イベント関連（予定の追加・削除）とユーザー関連（フォロー・グループ招待）を
    //   一目で見分けられるように、タブで絞り込めるようにする
    private enum Category: String, CaseIterable {
        case all = "すべて"
        case event = "イベント"
        case user = "ユーザー"

        func matches(_ notification: AppNotification) -> Bool {
            switch self {
            case .all:
                return true
            case .event:
                return notification.type == "event_created" || notification.type == "event_deleted" || notification.type == "event_approval_request"
            case .user:
                return notification.type == "follow" || notification.type == "group_invite"
                    || notification.type == "follow_request" || notification.type == "follow_request_accepted"
            }
        }
    }

    @State private var selectedCategory: Category = .all

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var filteredNotifications: [AppNotification] {
        notificationViewModel.notifications.filter { selectedCategory.matches($0) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                categoryPicker

                if filteredNotifications.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(filteredNotifications) { notification in
                            notificationRow(notification)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notificationViewModel.markAllRead()
        }
    }

    // MARK: - カテゴリ切り替え（丸みのあるピル方式。アプリ共通のスタイル）

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(Category.allCases, id: \.self) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedCategory = category
                    }
                } label: {
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedCategory == category ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Group {
                                if selectedCategory == category {
                                    Capsule().fill(
                                        LinearGradient(colors: [accentColor, accentColor2],
                                                       startPoint: .leading, endPoint: .trailing)
                                    )
                                } else {
                                    Capsule().fill(Color.appCardBackground)
                                }
                            }
                        )
                        .shadow(color: .black.opacity(selectedCategory == category ? 0.12 : 0.04), radius: 6, x: 0, y: 3)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.4))
                .accessibilityHidden(true)
            Text("通知はまだありません")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func notificationRow(_ notification: AppNotification) -> some View {
        if notification.type == "follow_request" {
            followRequestRow(notification)
        } else {
            standardNotificationRow(notification)
        }
    }

    private func standardNotificationRow(_ notification: AppNotification) -> some View {
        NavigationLink {
            destination(for: notification)
        } label: {
            HStack(spacing: 12) {
                actorIcon(notification)

                VStack(alignment: .leading, spacing: 3) {
                    (Text(notification.actorName).fontWeight(.bold) + Text(" ") + Text(bodyText(for: notification)))
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(relativeTime(notification.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                if !notification.isRead {
                    Circle().fill(accentColor).frame(width: 8, height: 8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // ★ 非公開アカウントへのフォローリクエスト通知だけは、行に「承認」「削除」ボタンを
    //   直接埋め込む特別なレイアウト（コミュニティカレンダーの承認待ち一覧と同じ考え方）。
    //   タップで遷移するのはアイコン・本文部分のみ（プロフィールへ）
    private func followRequestRow(_ notification: AppNotification) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                UserProfileView(uid: notification.actorUid, fallbackName: notification.actorName, fallbackIconURL: notification.actorIconURL)
            } label: {
                HStack(spacing: 12) {
                    actorIcon(notification)
                    VStack(alignment: .leading, spacing: 3) {
                        (Text(notification.actorName).fontWeight(.bold) + Text(" さんがあなたにフォローリクエストを送りました"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(relativeTime(notification.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    if !notification.isRead {
                        Circle().fill(accentColor).frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)

            if let request = followViewModel.incomingRequests.first(where: { $0.fromUid == notification.actorUid }) {
                HStack(spacing: 8) {
                    Button {
                        acceptRequest(request)
                    } label: {
                        Text("承認")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)

                    Button {
                        followViewModel.declineFollowRequest(request)
                    } label: {
                        Text("削除")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 220)
            } else {
                // ★ 承認/削除済みで、リクエスト自体はもう無いが通知だけ残っているケース
                Text("処理済み")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func acceptRequest(_ request: FollowRequest) {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        Task {
            let profile = await ChatViewModel.fetchUserProfile(uid: myUid)
            followViewModel.acceptFollowRequest(
                request,
                myName: profile?.displayName ?? "名無しさん",
                myIconURL: profile?.iconURL
            )
        }
    }

    private func bodyText(for notification: AppNotification) -> String {
        switch notification.type {
        case "follow":
            return "さんにフォローされました"
        case "event_created":
            return "さんが「\(notification.eventTitle ?? "")」の予定を追加しました"
        case "event_deleted":
            return "さんが「\(notification.eventTitle ?? "")」の予定を削除しました"
        case "event_approval_request":
            return "さんが追加した「\(notification.eventTitle ?? "")」の予定が承認待ちです"
        case "follow_request_accepted":
            return "さんがあなたのフォローリクエストを承認しました"
        case "group_invite":
            return "さんが「\(notification.groupName ?? "")」に招待しました"
        default:
            return ""
        }
    }

    // ★ フォロー通知はプロフィールへ、予定の追加/削除通知はそのグループのチャット
    //   （＝予定のお知らせメッセージが届いている場所）へ遷移させる。招待通知は
    //   まだメンバーでない可能性があるため、タップした時点でその場で参加させる
    @ViewBuilder
    private func destination(for notification: AppNotification) -> some View {
        switch notification.type {
        case "event_created", "event_deleted":
            if let groupId = notification.groupId,
               let group = groupViewModel.groups.first(where: { $0.id == groupId }) {
                ChatRoomView(group: group)
            } else {
                EmptyView()
            }
        case "event_approval_request":
            if let groupId = notification.groupId {
                EventApprovalListView(eventViewModel: eventViewModel, groupId: groupId, groupName: notification.groupName ?? "グループ")
            } else {
                EmptyView()
            }
        case "group_invite":
            if let groupId = notification.groupId {
                GroupInviteAcceptView(groupId: groupId, groupName: notification.groupName ?? "グループ")
            } else {
                EmptyView()
            }
        default:
            UserProfileView(uid: notification.actorUid, fallbackName: notification.actorName, fallbackIconURL: notification.actorIconURL)
        }
    }

    @ViewBuilder
    private func actorIcon(_ notification: AppNotification) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let urlString = notification.actorIconURL, let url = URL(string: urlString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        placeholderIcon(notification)
                    }
                }
            } else {
                placeholderIcon(notification)
            }

            if let badge = typeBadgeIcon(notification) {
                Image(systemName: badge.symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(badge.color))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: 3, y: 3)
                    .accessibilityHidden(true)
            }
        }
    }

    private func typeBadgeIcon(_ notification: AppNotification) -> (symbol: String, color: Color)? {
        switch notification.type {
        case "event_created":
            return ("calendar.badge.plus", Color(red: 0.40, green: 0.72, blue: 0.55))
        case "event_deleted":
            return ("calendar.badge.minus", Color(red: 0.90, green: 0.45, blue: 0.45))
        case "event_approval_request":
            return ("checkmark.seal.fill", Color(red: 0.95, green: 0.65, blue: 0.20))
        case "follow_request":
            return ("person.badge.plus.fill", Color.blue)
        case "follow_request_accepted":
            return ("checkmark.circle.fill", Color.blue)
        case "group_invite":
            return ("bubble.left.and.bubble.right.fill", Color.oshiniumPrimary)
        default:
            return nil
        }
    }

    private func placeholderIcon(_ notification: AppNotification) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [accentColor, Color.oshiniumPrimary2],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(notification.actorName.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// ★ グループ招待通知をタップした時の遷移先。まだメンバーでない可能性があるため、
//   表示のたびにその場でjoinGroup(byId:)を叩いてから（すでにメンバーなら無害に上書きされるだけ）
//   ChatRoomViewへ切り替える
private struct GroupInviteAcceptView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel
    let groupId: String
    let groupName: String

    @State private var joinedGroup: IdolGroup?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let joinedGroup {
                ChatRoomView(group: joinedGroup)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                        .accessibilityHidden(true)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("「\(groupName)」に参加しています…")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear(perform: join)
    }

    private func join() {
        groupViewModel.joinGroup(byId: groupId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let group):
                    joinedGroup = group
                case .failure:
                    errorMessage = "グループへの参加に失敗しました"
                }
            }
        }
    }
}
