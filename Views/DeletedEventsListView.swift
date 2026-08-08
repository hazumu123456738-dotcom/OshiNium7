//
//  DeletedEventsListView.swift
//  OshiNium7
//

import SwiftUI

// ★ カレンダーの「…」管理メニューから開く、削除して3日以内の予定を復元できる画面。
//   常時購読するほどの画面ではないため、開いたタイミングで一度だけ取得する
struct DeletedEventsListView: View {

    @ObservedObject var eventViewModel: EventViewModel

    @State private var deletedEvents: [Event] = []
    @State private var isLoading = true
    @State private var restoringIds: Set<String> = []
    @State private var selectedEvent: Event?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if deletedEvents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("直近3日以内に削除した予定はありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
                .listRowSeparator(.hidden)
            } else {
                ForEach(deletedEvents, id: \.id) { event in
                    row(for: event)
                }
            }
        }
        .navigationTitle("削除した予定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .sheet(item: $selectedEvent) { event in
            DeletedEventDetailView(event: event) {
                restore(event)
            }
        }
    }

    private func row(for event: Event) -> some View {
        let id = event.id ?? ""
        return HStack(spacing: 12) {
            Button {
                selectedEvent = event
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(deletedAtLabel(event))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            if restoringIds.contains(id) {
                ProgressView()
            } else {
                Button("復元する") {
                    restore(event)
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
    }

    private func deletedAtLabel(_ event: Event) -> String {
        guard let deletedAt = event.deletedAt else { return "" }
        let days = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        let remaining = max(0, 3 - days)
        if days <= 0 {
            return "本日削除・あと\(remaining)日以内なら復元できます"
        }
        return "\(days)日前に削除・あと\(remaining)日以内なら復元できます"
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
            deletedEvents.removeAll { $0.id == id }
            if selectedEvent?.id == id {
                selectedEvent = nil
            }
        }
    }
}
