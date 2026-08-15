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
    var groupId: String? = nil
    var groupName: String? = nil
    var onDeleted: (OshiCalendar) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    // ★ 常にゆっくり色相が回り続ける「色が移り変わる」演出用のアニメーション角度
    @State private var hueAngle: Double = 0

    // ★ 2026/08/15修正：総件数ではなく「未確認件数」を出す（EventViewModel.unseenPendingApprovalCount参照）。
    //   以前は承認待ち画面を開いて中身を確認しても、承認/削除しない限りこのバッジが消えなかった
    private var pendingApprovalCount: Int {
        guard let groupId else { return 0 }
        return eventViewModel.unseenPendingApprovalCount(groupId: groupId)
    }

    // ★ OshiNiumのブランドカラー（紫〜ピンク〜ゴールド）を使った、常時色相が回転する
    //   特別なグラデーション。承認待ちの予定は「他のメンバーの情報を信頼して自分の
    //   カレンダーを作る」重要な操作のため、他の管理項目より一段目立たせる
    private var shiftingGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.oshiniumPrimary,
                Color.oshiniumPrimary2,
                Color(red: 0.98, green: 0.75, blue: 0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if let groupId {
                    Section {
                        NavigationLink {
                            EventApprovalListView(eventViewModel: eventViewModel, groupId: groupId, groupName: groupName)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(shiftingGradient)
                                        .hueRotation(.degrees(hueAngle))
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 32, height: 32)

                                Text("承認待ちの予定")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(shiftingGradient)
                                    .hueRotation(.degrees(hueAngle))

                                Spacer()

                                if pendingApprovalCount > 0 {
                                    Text("\(pendingApprovalCount)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(shiftingGradient).hueRotation(.degrees(hueAngle)))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onAppear {
                            withAnimation(.linear(duration: 6).repeatForever(autoreverses: true)) {
                                hueAngle = 40
                            }
                        }
                    } footer: {
                        Text("メンバーの方が追加されたコミュニティカレンダーの予定は、あなたが承認されるまでカレンダーには表示されません。判断を後回しにされた予定も、こちらにずっと残りますのでご安心ください。")
                    }
                }

                Section {
                    NavigationLink {
                        DeletedEventsListView(eventViewModel: eventViewModel)
                    } label: {
                        Label("削除した予定を復元", systemImage: "arrow.uturn.backward")
                    }
                } footer: {
                    Text("削除してから3日以内であれば、こちらから予定を復元していただけます。")
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
                    Text("コミュニティカレンダーとプライベートカレンダーは、仕組み上削除することができません。あらかじめご了承ください。")
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
                Text("削除できるカレンダーは現在ありません。")
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
                        .accessibilityLabel("「\(calendar.name)」を削除")
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
            Text("削除すると、このカレンダーに登録されている予定も表示されなくなりますので、ご注意ください。")
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
