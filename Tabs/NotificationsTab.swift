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
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var navState: AppNavigationState

    // ★ ホーム画面で選択中のグループ。予定の追加・承認待ち・招待など特定のグループに
    //   紐づく通知は、このグループのものだけに絞り込む（マイページタブの長押しで
    //   グループを切り替えたのに、以前のグループの承認待ち予定などが混ざって
    //   表示され続けてしまっていた不具合の修正）
    let currentGroup: IdolGroup?

    // ★ イベント関連（予定の追加・削除）とユーザー関連（フォロー・グループ招待）を
    //   一目で見分けられるように、タブで絞り込めるようにする。
    //   ★ 2026/08/13：運営（開発者）からの全体お知らせ専用の「運営」カテゴリを追加。
    //   新機能・予定追加方法の変更などを発信する場所として使う（Announcementモデル参照）
    private enum Category: String, CaseIterable {
        case all = "すべて"
        case event = "イベント"
        case user = "ユーザー"
        case official = "運営"

        func matches(_ notification: AppNotification) -> Bool {
            switch self {
            case .all:
                return true
            case .event:
                return notification.type == "event_created" || notification.type == "event_approval_request"
            case .user:
                return notification.type == "follow" || notification.type == "group_invite"
                    || notification.type == "follow_request" || notification.type == "follow_request_accepted"
                    || notification.type == "post_like" || notification.type == "post_comment"
            case .official:
                return false
            }
        }
    }

    @State private var selectedCategory: Category = .all

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var filteredNotifications: [AppNotification] {
        notificationViewModel.notifications
            .filter { selectedCategory.matches($0) }
            .filter { belongsToCurrentGroup($0) }
    }

    // ★ event_created/event_approval_request/group_inviteのようにgroupIdを持つ通知は
    //   currentGroupのものだけに絞る。follow/post_like等、特定のグループに紐づかない
    //   個人的な通知（groupIdなし）は、グループの選択状態に関わらず常に表示する
    private func belongsToCurrentGroup(_ notification: AppNotification) -> Bool {
        guard let groupId = notification.groupId else { return true }
        guard let currentGroup else { return true }
        return groupId == currentGroup.id
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                categoryPicker

                if selectedCategory == .official {
                    if notificationViewModel.announcements.isEmpty {
                        announcementEmptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(notificationViewModel.announcements) { announcement in
                                announcementRow(announcement)
                            }
                        }
                    }
                } else if filteredNotifications.isEmpty {
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

    // MARK: - 運営からのお知らせ

    private var announcementEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "megaphone")
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.4))
                .accessibilityHidden(true)
            Text("運営からのお知らせはまだありません")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func announcementRow(_ announcement: Announcement) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: announcement.iconName ?? "megaphone.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("OshiNium運営")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accentColor)
                    Text("公式")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accentColor.opacity(0.85)))
                }

                Text(announcement.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(announcement.body)
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(relativeTime(announcement.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
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
                        followViewModel.declineFollowRequest(request) { error in
                            if error != nil { navState.showToast("削除できませんでした") }
                        }
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
            ) { error in
                if error != nil { navState.showToast("承認できませんでした") }
            }
        }
    }

    private func bodyText(for notification: AppNotification) -> String {
        switch notification.type {
        case "follow":
            return "さんにフォローされました"
        case "event_created":
            return "さんが「\(notification.eventTitle ?? "")」の予定を追加しました"
        case "event_approval_request":
            return "さんが追加した「\(notification.eventTitle ?? "")」の予定が承認待ちです"
        case "follow_request_accepted":
            return "さんがあなたのフォローリクエストを承認しました"
        case "group_invite":
            return "さんが「\(notification.groupName ?? "")」に招待しました"
        case "post_like":
            return "さんがあなたの投稿にいいねしました"
        case "post_comment":
            return "さんがあなたの投稿にコメントしました"
        default:
            return ""
        }
    }

    // ★ フォロー通知はプロフィールへ、予定の追加通知はそのグループのチャット
    //   （＝予定のお知らせメッセージが届いている場所）へ遷移させる。招待通知は
    //   まだメンバーでない可能性があるため、タップした時点でその場で参加させる
    @ViewBuilder
    private func destination(for notification: AppNotification) -> some View {
        switch notification.type {
        case "event_created":
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
        case "post_like", "post_comment":
            if let postId = notification.postId,
               let post = postViewModel.posts.first(where: { $0.id == postId }) {
                NotifiedPostDetailView(post: post)
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
        case "event_approval_request":
            return ("checkmark.seal.fill", Color(red: 0.95, green: 0.65, blue: 0.20))
        case "follow_request":
            return ("person.badge.plus.fill", Color.blue)
        case "follow_request_accepted":
            return ("checkmark.circle.fill", Color.blue)
        case "group_invite":
            return ("bubble.left.and.bubble.right.fill", Color.oshiniumPrimary)
        case "post_like":
            return ("heart.fill", Color(red: 0.95, green: 0.35, blue: 0.55))
        case "post_comment":
            return ("bubble.left.fill", Color.blue)
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
    // ★ 無課金会員が招待制グループチャットの参加上限(1件)を超える招待を受けた時だけ、
    //   ここをtrueにして「プレミアムなら参加できます」の導線を出す
    @State private var isJoinLimitError = false
    @State private var showPremiumUpgrade = false

    var body: some View {
        Group {
            if let joinedGroup {
                ChatRoomView(group: joinedGroup)
            } else if let errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: isJoinLimitError ? "person.crop.circle.badge.plus" : "exclamationmark.triangle")
                        .font(.system(size: 30))
                        .foregroundColor(isJoinLimitError ? Color.oshiniumPrimary : .orange)
                        .accessibilityHidden(true)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if isJoinLimitError {
                        Button {
                            showPremiumUpgrade = true
                        } label: {
                            Text("プレミアムにアップグレード")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: [Color.oshiniumPrimary, Color.oshiniumPrimary2],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                )
                        }
                    }
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
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    private func join() {
        groupViewModel.joinGroup(byId: groupId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let group):
                    joinedGroup = group
                case .failure(let error):
                    // ★ 以前は理由を問わず一律「グループへの参加に失敗しました」だったため、
                    //   無課金会員が2件目以降の招待制グループチャットに招待されても、
                    //   なぜ参加できないのか・プレミアムなら参加できることが伝わらなかった
                    if case GroupCreationError.privateChatJoinLimitReached = error {
                        isJoinLimitError = true
                    }
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// ★ いいね・コメント通知をタップした時の遷移先。該当の1投稿だけをPostFeedCardで表示する
//   （2026/08/11追加。マイページの「いいねされた投稿」一覧と同じ、投稿1件だけの簡易表示）
private struct NotifiedPostDetailView: View {
    let post: Post

    var body: some View {
        ScrollView {
            PostFeedCard(post: post)
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
                .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("投稿")
        .navigationBarTitleDisplayMode(.inline)
    }
}
