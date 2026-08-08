//
//  CalendarManageMenuView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/31.
//

import SwiftUI

// ★ カレンダータブ右上の「…」から開く管理メニュー。今はカレンダー削除だけだが、
//   今後カレンダーまわりの細かい機能（並び替え・色変更など）が増えたら
//   ここに行を足していく、いわば管理機能の集約先
struct CalendarManageMenuView: View {

    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var eventViewModel: EventViewModel
    var onDeleted: (OshiCalendar) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DeletedEventsListView(eventViewModel: eventViewModel)
                    } label: {
                        Label("削除した予定を復元", systemImage: "arrow.uturn.backward")
                    }
                } footer: {
                    Text("削除してから3日以内の予定はここから復元できます。")
                }

                Section {
                    NavigationLink {
                        CalendarDeleteListView(
                            calendarViewModel: calendarViewModel,
                            onDeleted: onDeleted
                        )
                    } label: {
                        Label("カレンダーを削除", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } footer: {
                    Text("コミュニティカレンダーとプライベートカレンダーは削除できません。")
                }
            }
            .navigationTitle("カレンダーの管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 削除するカレンダーを選ぶ画面（コミュニティカレンダーは一覧に出さない＝絶対に消せない）

private struct CalendarDeleteListView: View {

    @ObservedObject var calendarViewModel: CalendarViewModel
    var onDeleted: (OshiCalendar) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var calendarPendingDelete: OshiCalendar?
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    private var deletableCalendars: [OshiCalendar] {
        calendarViewModel.calendars.filter { !$0.isCommunity && !$0.isPrivate }
    }

    var body: some View {
        List {
            if deletableCalendars.isEmpty {
                Text("削除できるカレンダーがありません")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            } else {
                ForEach(deletableCalendars) { calendar in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(fillColor(for: calendar))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        Text(calendar.name)
                            .font(.system(size: 15))

                        Spacer()

                        Button(role: .destructive) {
                            calendarPendingDelete = calendar
                            showDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("カレンダーを削除")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "「\(calendarPendingDelete?.name ?? "")」を削除しますか？",
            isPresented: $showDeleteAlert
        ) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                if let calendar = calendarPendingDelete {
                    delete(calendar)
                }
            }
        } message: {
            Text("削除すると、このカレンダーに登録された予定も表示されなくなります。")
        }
    }

    private func delete(_ calendar: OshiCalendar) {
        calendarViewModel.deleteCalendar(calendar) { error in
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            onDeleted(calendar)
            // ★ 一覧から消えたら自動的にこの画面から戻る必要はない
            //   （複数消したい場合もあるため、リストに留まって次を選べるようにする）
        }
    }

    private func fillColor(for calendar: OshiCalendar) -> Color {
        if let hex = calendar.colorHex {
            return Color(hex: hex)
        }
        return Color.oshiniumPrimary
    }
}
