//
//  DeletedEventsListView.swift
//  OshiNium7
//

import SwiftUI
import FirebaseAuth

// ★ カレンダーの「…」管理メニューから開く、削除して3日以内の予定を復元できる画面。
//   常時購読するほどの画面ではないため、開いたタイミングで一度だけ取得する。
//   ★ 2026/08/13：見た目・操作感をEventApprovalListView（予定承認画面）と統一した。
//   どちらも「グループの予定に対する自分だけの意思表示（承認する／削除する⇔復元する）」
//   という同じ性質の操作のため、同じアイコン＋説明文＋ボタンの並びにすることで、
//   ユーザーが一度覚えた操作感をそのまま使い回せるようにする
struct DeletedEventsListView: View {

    @ObservedObject var eventViewModel: EventViewModel

    @State private var deletedEvents: [Event] = []
    @State private var isLoading = true
    @State private var restoringIds: Set<String> = []
    // ★ 承認画面のapprovedSnapshotsと同じ考え方：復元した予定をこの画面が開いている間は
    //   薄く積み重ねて残し、「復元できた」という結果が一覧からすぐ消えて分からなくならないようにする
    @State private var restoredSnapshots: [String: Event] = [:]

    private var myUid: String? { Auth.auth().currentUser?.uid }

    private var pendingEvents: [Event] {
        deletedEvents.filter { restoredSnapshots[$0.id ?? ""] == nil }
    }

    private var restoredEvents: [Event] {
        restoredSnapshots.values.sorted { effectiveDeletedAt($0) ?? .distantPast > effectiveDeletedAt($1) ?? .distantPast }
    }

    var body: some View {
        List {
            Section {
                noticeCard
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 30)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if pendingEvents.isEmpty && restoredEvents.isEmpty {
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
                            DeletedEventRow(
                                event: event,
                                subLabel: eventSubLabel(event),
                                deletedAtLabel: deletedAtLabel(event),
                                isRestoring: restoringIds.contains(event.id ?? ""),
                                onRestore: { restore(event) }
                            )
                        }
                    } header: {
                        Text("削除した予定（\(pendingEvents.count)件）")
                    }
                }

                if !restoredEvents.isEmpty {
                    Section {
                        ForEach(restoredEvents, id: \.id) { event in
                            RestoredEventRow(event: event, subLabel: eventSubLabel(event))
                        }
                    } header: {
                        Text("復元済み（\(restoredEvents.count)件）")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("削除した予定")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear(perform: reload)
    }

    private var noticeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 11, weight: .bold))
                    .accessibilityHidden(true)
                Text("削除した予定（3日以内なら復元できます）")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.60, blue: 0.68), Color(red: 0.35, green: 0.40, blue: 0.48)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )

            // ★ コミュニティカレンダーの予定削除は「自分のカレンダーからだけ」消える個人の意思表示
            //   （他のメンバーには影響しない）という前提を、承認画面の説明文と対になる形で明記する
            Text("削除した予定は完全には消えず、カレンダー表示からのみ除外されます。3日以内であれば「復元する」でいつでも元に戻せます。")
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
            Image(systemName: "trash")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.3))
                .accessibilityHidden(true)
            Text("削除した予定はありません（3日以内）")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func effectiveDeletedAt(_ event: Event) -> Date? {
        guard let uid = myUid else { return event.deletedAt }
        return event.effectiveDeletedAt(for: uid)
    }

    private func deletedAtLabel(_ event: Event) -> String {
        guard let deletedAt = effectiveDeletedAt(event) else { return "" }
        let days = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        let remaining = max(0, 3 - days)
        if days <= 0 {
            return "本日削除（復元期限: あと\(remaining)日）"
        }
        return "\(days)日前に削除（復元期限: あと\(remaining)日）"
    }

    private func reload() {
        isLoading = true
        eventViewModel.fetchRecentlyDeletedEvents { events in
            deletedEvents = events
            isLoading = false
        }
    }

    private func restore(_ event: Event) {
        guard let id = event.id else { return }
        restoringIds.insert(id)
        eventViewModel.restoreEvent(event) { _ in
            restoringIds.remove(id)
            restoredSnapshots[id] = event
        }
    }
}

// MARK: - 1行分（承認画面のEventApprovalRowと同じ並び：アイコン＋説明文＋「復元する」）

private struct DeletedEventRow: View {
    let event: Event
    let subLabel: String
    let deletedAtLabel: String
    let isRestoring: Bool
    let onRestore: () -> Void

    private var eventColor: Color {
        event.type?.iconColor ?? Color.oshiniumPrimary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DeletedEventIcon(event: event, color: eventColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title.isEmpty ? "未設定" : event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(deletedAtLabel)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary.opacity(0.8))

                if isRestoring {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                } else {
                    Button(action: onRestore) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .semibold))
                            Text("復元する")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(eventColor))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 160)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 復元済み行（積み重ね表示。承認画面のApprovedEventRowと同じく全体を薄く表示）

private struct RestoredEventRow: View {
    let event: Event
    let subLabel: String

    private var eventColor: Color {
        event.type?.iconColor ?? Color.oshiniumPrimary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DeletedEventIcon(event: event, color: eventColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title.isEmpty ? "未設定" : event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Label("復元済み", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .opacity(0.45)
    }
}

// ★ 承認画面は「誰から追加されたか」が主眼のためアバターを出すが、この画面は
//   「削除したのはどの予定か」が主眼のため、予定の種類アイコンを代わりに使う
private struct DeletedEventIcon: View {
    let event: Event
    let color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.12))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: event.type?.iconName ?? "star")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(color)
            )
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
