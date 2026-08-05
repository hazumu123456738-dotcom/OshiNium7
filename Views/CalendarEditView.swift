//
//  CalendarEditView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI

struct CalendarEditView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupViewModel: GroupViewModel

    let calendar: OshiCalendar
    let calendarViewModel: CalendarViewModel
    var onDeleted: () -> Void = {}
    var onUpdated: (OshiCalendar) -> Void = { _ in }

    @State private var name: String
    @State private var selectedMemberIds: Set<String>
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    init(
        calendar: OshiCalendar,
        calendarViewModel: CalendarViewModel,
        onDeleted: @escaping () -> Void = {},
        onUpdated: @escaping (OshiCalendar) -> Void = { _ in }
    ) {
        self.calendar = calendar
        self.calendarViewModel = calendarViewModel
        self.onDeleted = onDeleted
        self.onUpdated = onUpdated
        _name = State(initialValue: calendar.name)
        _selectedMemberIds = State(initialValue: Set(calendar.memberIds))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("カレンダー名")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("カレンダー名", text: $name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("メンバー")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        memberList
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("このカレンダーを削除")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.red.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .padding(.top, 12)
                }
                .padding(20)
            }
            .navigationTitle("カレンダーを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            groupViewModel.fetchMembers(for: calendar.groupId)
        }
        .alert("このカレンダーを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) { deleteCalendar() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除すると、このカレンダーに登録された予定も表示されなくなります。")
        }
    }

    // MARK: - メンバーリスト

    private var memberList: some View {
        VStack(spacing: 0) {
            ForEach(groupViewModel.members) { member in
                memberRow(member)
                if member.id != groupViewModel.members.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func memberRow(_ member: GroupMember) -> some View {
        let isOwner = member.uid == calendar.ownerId
        let isSelected = isOwner || selectedMemberIds.contains(member.uid)

        return Button {
            guard !isOwner else { return }
            if isSelected {
                selectedMemberIds.remove(member.uid)
            } else {
                selectedMemberIds.insert(member.uid)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(member.displayName.prefix(1)))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)

                    if isOwner {
                        Text("オーナー")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .black : .gray.opacity(0.4))
                    .opacity(isOwner ? 0.4 : 1.0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isOwner)
    }

    // MARK: - 保存・削除

    private func saveChanges() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = calendar
        updated.name = trimmed
        updated.memberIds = Array(selectedMemberIds)

        calendarViewModel.renameCalendar(calendarId: calendar.id, name: trimmed) { [self] renameError in
            if let renameError {
                isSaving = false
                errorMessage = renameError.localizedDescription
                return
            }

            calendarViewModel.updateCalendarMembers(calendarId: calendar.id, memberIds: Array(selectedMemberIds)) { memberError in
                isSaving = false
                if let memberError {
                    errorMessage = memberError.localizedDescription
                    return
                }
                onUpdated(updated)
                dismiss()
            }
        }
    }

    private func deleteCalendar() {
        calendarViewModel.deleteCalendar(calendar) { error in
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            onDeleted()
            dismiss()
        }
    }
}
