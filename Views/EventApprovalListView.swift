//
//  EventApprovalListView.swift
//  OshiNium7
//

import SwiftUI
import NukeUI

// ★ コミュニティカレンダーの承認制：グループの誰かが追加した予定を、自分が承認するまでの
//   「承認待ちの予定」一覧。カレンダータブ右上の「…」から、通知をあとで判断した場合も
//   含めて常にここへ戻ってこれる。
//   ★ 見た目はInstagramのフォローリクエスト一覧をイメージし、アイコン＋説明文＋
//   「承認」「削除」の横並び2択にしている。「削除」はFirestore側のdismissedByに
//   自分のuidを足す（EventViewModel.dismissApprovalEvent）ため、以後この画面を
//   開き直しても二度と出てこない（＝自分だけの恒久的な非表示。他メンバーには影響しない）
struct EventApprovalListView: View {

    @ObservedObject var eventViewModel: EventViewModel
    let groupId: String
    var groupName: String? = nil

    @State private var justApprovedIds: Set<String> = []
    @State private var dismissedIds: Set<String> = []
    // ★ 承認した瞬間、Firestoreの反映（＝pendingApprovalEventsから消える）の方が
    //   「承認しました」の表示より先に終わってしまい、確認メッセージを見せる間もなく
    //   行ごと一覧から消えてしまっていた。承認した予定はここに一時的に保持しておき、
    //   本来のpending一覧から消えても「承認しました」を実際に見せてから一覧を更新する
    @State private var approvedSnapshots: [String: Event] = [:]

    private var pendingEvents: [Event] {
        let livePending = eventViewModel.pendingApprovalEvents(groupId: groupId)
        var merged = livePending
        for (id, snapshot) in approvedSnapshots where !merged.contains(where: { $0.id == id }) {
            merged.append(snapshot)
        }
        return merged
            .filter { !dismissedIds.contains($0.id ?? "") }
            .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
    }

    var body: some View {
        List {
            Section {
                noticeCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if pendingEvents.isEmpty {
                Section {
                    emptyState
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(pendingEvents, id: \.id) { event in
                        EventApprovalRow(
                            event: event,
                            isApproved: justApprovedIds.contains(event.id ?? ""),
                            onApprove: {
                                guard let id = event.id else { return }
                                justApprovedIds.insert(id)
                                approvedSnapshots[id] = event
                                eventViewModel.approveEvent(event)
                                // ★ 「承認しました」を実際に見せてから、少し待って一覧から取り除く
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                    approvedSnapshots.removeValue(forKey: id)
                                    justApprovedIds.remove(id)
                                }
                            },
                            onDismiss: {
                                if let id = event.id { dismissedIds.insert(id) }
                                eventViewModel.dismissApprovalEvent(event)
                            }
                        )
                    }
                } header: {
                    Text("承認待ち（\(pendingEvents.count)件）")
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(groupName.map { "\($0)の承認待ちの予定" } ?? "承認待ちの予定")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var noticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                    .accessibilityHidden(true)
                Text("コミュニティカレンダー（グループ全員で共有）")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.85, blue: 0.45), Color(red: 0.80, green: 0.62, blue: 0.18)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )

            // ★ 「承認」は"グループ全員に公開してよいか"の許可ではなく、あくまで
            //   "自分自身のコミュニティカレンダーに表示してよいか"という、一人ひとり個別の判断。
            //   ここを誤解されると「自分の承認で他のメンバーにも予定が広まってしまう」かのように
            //   見えてしまうため、はっきり書く。見やすさのため段落を分けて短くまとめている
            Text("承認した予定だけが、あなた自身のカレンダーに表示されます。（他のメンバーには影響しません）\n\n一人ひとりが承認して、自分だけのカレンダーを作っていくイメージです。\n\n承認する前に、予定の信憑性をご確認ください。")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.appCardBackground))
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.3))
                .accessibilityHidden(true)
            Text("承認待ちの予定はありません")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

// MARK: - 1行分（Instagramのフォローリクエスト行のイメージ：アイコン＋説明文＋承認/削除）

private struct EventApprovalRow: View {
    let event: Event
    let isApproved: Bool
    let onApprove: () -> Void
    let onDismiss: () -> Void

    @State private var creatorIconURL: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            creatorAvatar

            VStack(alignment: .leading, spacing: 6) {
                (Text(event.creatorName ?? "メンバー").fontWeight(.bold)
                    + Text("さんから「\(event.title)」の予定がコミュニティカレンダーに追加されました"))
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if isApproved {
                    Label("承認しました", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                } else {
                    HStack(spacing: 8) {
                        Button(action: onApprove) {
                            Text("承認")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color.blue))
                        }
                        .buttonStyle(.plain)

                        Button(action: onDismiss) {
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
                }
            }
        }
        .padding(.vertical, 8)
        .task {
            guard let uid = event.creatorUid else { return }
            creatorIconURL = await ChatViewModel.fetchUserProfile(uid: uid)?.iconURL
        }
    }

    private var subLabel: String {
        let target = event.startDate ?? event.date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) HH:mm"
        let dateText = formatter.string(from: target)
        if let place = event.place, !place.isEmpty {
            return "\(dateText)・\(place)"
        }
        return dateText
    }

    @ViewBuilder
    private var creatorAvatar: some View {
        if let iconURL = creatorIconURL, let url = URL(string: iconURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.oshiniumPrimary, Color.oshiniumPrimary2],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Text(String((event.creatorName ?? "メ").prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}
