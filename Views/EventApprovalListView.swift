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

    @State private var dismissedIds: Set<String> = []
    // ★ 承認すると、その予定はeventViewModel.pendingApprovalEvents(groupId:)の
    //   結果から消える（承認待ちの定義上そうなる）。以前はその瞬間に一覧からも
    //   消えていたが、「承認した予定を積み重ねて残しておきたい」という要望を受け、
    //   このセッション中に自分が承認した予定はここに保持し、専用の「承認済み」
    //   セクションに薄い表示でずっと積み重ねていく
    @State private var approvedSnapshots: [String: Event] = [:]

    private var pendingEvents: [Event] {
        eventViewModel.pendingApprovalEvents(groupId: groupId)
            .filter { !dismissedIds.contains($0.id ?? "") && approvedSnapshots[$0.id ?? ""] == nil }
            .sorted { ($0.startDate ?? $0.date) < ($1.startDate ?? $1.date) }
    }

    // ★ 承認した順（新しく承認したものほど上）に積み重ねる
    private var approvedEvents: [Event] {
        approvedSnapshots.values.sorted { ($0.startDate ?? $0.date) > ($1.startDate ?? $1.date) }
    }

    var body: some View {
        List {
            Section {
                noticeCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if pendingEvents.isEmpty && approvedEvents.isEmpty {
                Section {
                    emptyState
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                if !pendingEvents.isEmpty {
                    Section {
                        ForEach(pendingEvents, id: \.id) { event in
                            EventApprovalRow(
                                event: event,
                                onApprove: {
                                    guard let id = event.id else { return }
                                    approvedSnapshots[id] = event
                                    eventViewModel.approveEvent(event)
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

                if !approvedEvents.isEmpty {
                    Section {
                        ForEach(approvedEvents, id: \.id) { event in
                            ApprovedEventRow(event: event)
                        }
                    } header: {
                        Text("承認済み（\(approvedEvents.count)件）")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(groupName.map { "\($0)の承認待ちの予定" } ?? "承認待ちの予定")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            // ★ 画面を開き直すたびに、直近10日以内に自分が承認した予定をFirestoreから
            //   読み直して「承認済み」セクションに復元する。この画面を閉じても消えず、
            //   10日経つと自然に一覧から外れる(fetchRecentlyApprovedEvents側の期間フィルタ)
            eventViewModel.fetchRecentlyApprovedEvents(groupId: groupId) { events in
                for event in events {
                    if let id = event.id {
                        approvedSnapshots[id] = event
                    }
                }
            }
        }
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
            Text("承認された予定だけが、あなた自身のカレンダーに表示される仕組みです。（他のメンバーの方には影響しません）\n\n一人ひとりが承認することで、自分だけのカレンダーを作っていくイメージです。\n\n承認される前に、予定の内容にお間違いがないかご確認いただけますと安心です。")
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
            Text("承認待ちの予定は現在ありません。")
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
    let onApprove: () -> Void
    let onDismiss: () -> Void

    @State private var creatorIconURL: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            EventApprovalAvatar(event: event, iconURL: creatorIconURL)

            VStack(alignment: .leading, spacing: 6) {
                (Text(event.creatorName ?? "メンバー").fontWeight(.bold)
                    + Text("さんから「\(event.title)」の予定がコミュニティカレンダーに追加されました"))
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(eventSubLabel(event))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

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
        .padding(.vertical, 8)
        .task {
            guard let uid = event.creatorUid else { return }
            creatorIconURL = await ChatViewModel.fetchUserProfile(uid: uid)?.iconURL
        }
    }
}

// MARK: - 承認済み行（積み重ね表示。区別がつくよう全体を薄い色にし、操作ボタンは持たない）

private struct ApprovedEventRow: View {
    let event: Event

    @State private var creatorIconURL: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            EventApprovalAvatar(event: event, iconURL: creatorIconURL)

            VStack(alignment: .leading, spacing: 6) {
                (Text(event.creatorName ?? "メンバー").fontWeight(.bold)
                    + Text("さんから「\(event.title)」の予定がコミュニティカレンダーに追加されました"))
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(eventSubLabel(event))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Label("承認済み", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        // ★ 承認待ちの行と一目で区別がつくよう、行全体を薄く表示する
        .opacity(0.45)
        .task {
            guard let uid = event.creatorUid else { return }
            creatorIconURL = await ChatViewModel.fetchUserProfile(uid: uid)?.iconURL
        }
    }
}

private func eventSubLabel(_ event: Event) -> String {
    let target = event.startDate ?? event.date
    let dateText = CachedFormatters.date(format: "M/d(E) HH:mm").string(from: target)
    if let place = event.place, !place.isEmpty {
        return "\(dateText)・\(place)"
    }
    return dateText
}

private struct EventApprovalAvatar: View {
    let event: Event
    let iconURL: String?

    var body: some View {
        if let iconURL, let url = URL(string: iconURL) {
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
