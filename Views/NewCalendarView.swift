//
//  NewCalendarView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI

struct NewCalendarView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupViewModel: GroupViewModel

    let groupId: String
    let ownerId: String
    let calendarViewModel: CalendarViewModel
    var onCreated: (OshiCalendar) -> Void = { _ in }

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#B38CFA"
    @State private var selectedMemberIds: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let colorOptions: [String] = [
        "#B38CFA", "#F2A6C4", "#7FD1AE", "#8FB8F6", "#F6C177", "#EF9A9A"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - 名前
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カレンダー名")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        TextField("例）仲良しグループ", text: $name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }

                    // MARK: - 差し色
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カレンダーカラー")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(selectedColorHex == hex ? 0.7 : 0), lineWidth: 2)
                                            .padding(-3)
                                    )
                                    .onTapGesture { selectedColorHex = hex }
                            }
                        }
                    }

                    // MARK: - メンバー招待
                    VStack(alignment: .leading, spacing: 8) {
                        Text("招待するメンバー")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text("同じグループに参加しているメンバーだけを招待できます。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))

                        memberList
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .navigationTitle("個人カレンダーを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "作成中…" : "作成") {
                        createCalendar()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            groupViewModel.fetchMembers(for: groupId)
        }
    }

    // MARK: - メンバーリスト

    private var memberList: some View {
        let invitable = groupViewModel.members.filter { $0.uid != ownerId }

        return VStack(spacing: 0) {
            if invitable.isEmpty {
                Text("招待できるメンバーがまだいません。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            } else {
                ForEach(invitable) { member in
                    memberRow(member)
                    if member.id != invitable.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func memberRow(_ member: GroupMember) -> some View {
        let isSelected = selectedMemberIds.contains(member.uid)

        return Button {
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

                Text(member.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .black : .gray.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 作成処理

    private func createCalendar() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        calendarViewModel.createPersonalCalendar(
            name: trimmed,
            groupId: groupId,
            ownerId: ownerId,
            memberIds: Array(selectedMemberIds),
            colorHex: selectedColorHex
        ) { result in
            isSaving = false
            switch result {
            case .success(let calendar):
                onCreated(calendar)
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
