//
//  GroupMemberManagementView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import FirebaseAuth
import NukeUI

// ★ グループのメンバー一覧・権限管理画面。オーナー・管理者は他メンバーの権限変更／削除、
//   オーナーはグループそのものの削除ができる。一般メンバーは一覧を見るだけの読み取り専用になる
struct GroupMemberManagementView: View {
    let group: IdolGroup

    @EnvironmentObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pendingRoleChange: (member: GroupMember, role: GroupRole)?
    @State private var pendingRemoval: GroupMember?
    @State private var showDeleteGroupConfirm = false
    @State private var isDeletingGroup = false
    @State private var deleteErrorMessage: String?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var myUid: String? { Auth.auth().currentUser?.uid }
    private var myRole: GroupRole { groupViewModel.myRole(in: group) }

    private var sortedMembers: [GroupMember] {
        groupViewModel.members.sorted { lhs, rhs in
            if lhs.effectiveRole != rhs.effectiveRole {
                return rolePriority(lhs.effectiveRole) < rolePriority(rhs.effectiveRole)
            }
            return lhs.displayName < rhs.displayName
        }
    }

    private func rolePriority(_ role: GroupRole) -> Int {
        switch role {
        case .owner: return 0
        case .admin: return 1
        case .member: return 2
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard

                VStack(spacing: 10) {
                    ForEach(sortedMembers) { member in
                        memberRow(member)
                    }
                }

                if myRole.canDeleteGroup {
                    dangerZone
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("メンバー管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { groupViewModel.fetchMembers(for: group.id) }
        .onDisappear { groupViewModel.stopFetchingMembers() }
        .alert("グループから削除しますか？", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )) {
            Button("キャンセル", role: .cancel) { pendingRemoval = nil }
            Button("削除する", role: .destructive) {
                if let member = pendingRemoval {
                    groupViewModel.removeMember(groupId: group.id, uid: member.uid)
                }
                pendingRemoval = nil
            }
        } message: {
            if let member = pendingRemoval {
                Text("「\(member.displayName)」さんをこのグループから削除します")
            }
        }
        .alert("権限を変更しますか？", isPresented: Binding(
            get: { pendingRoleChange != nil },
            set: { if !$0 { pendingRoleChange = nil } }
        )) {
            Button("キャンセル", role: .cancel) { pendingRoleChange = nil }
            Button("変更する") {
                if let change = pendingRoleChange {
                    groupViewModel.updateMemberRole(groupId: group.id, uid: change.member.uid, role: change.role)
                }
                pendingRoleChange = nil
            }
        } message: {
            if let change = pendingRoleChange {
                Text("「\(change.member.displayName)」さんを\(change.role.displayLabel)にします")
            }
        }
        .alert("グループを削除しますか？", isPresented: $showDeleteGroupConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) { deleteGroup() }
        } message: {
            Text("「\(group.name)」を削除すると元に戻せません。グループ自体とメンバー一覧が削除されます（イベント・投稿などの記録は残ります）")
        }
        .alert("削除できませんでした", isPresented: Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .overlay {
            if isDeletingGroup {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(accentColor)
            Text("メンバー \(sortedMembers.count)人")
                .font(.system(size: 14, weight: .bold))
            Spacer(minLength: 0)
            Text("あなたの権限：\(myRole.displayLabel)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func memberRow(_ member: GroupMember) -> some View {
        let isMe = member.uid == myUid

        return HStack(spacing: 12) {
            avatarView(member)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    if isMe {
                        Text("自分")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                roleBadge(member.effectiveRole)
            }

            Spacer(minLength: 0)

            if !isMe, myRole.canManageMembers, canModerate(member) {
                Menu {
                    if myRole == .owner {
                        if member.effectiveRole != .admin {
                            Button {
                                pendingRoleChange = (member, .admin)
                            } label: {
                                Label("管理者にする", systemImage: "person.badge.shield.checkmark")
                            }
                        } else {
                            Button {
                                pendingRoleChange = (member, .member)
                            } label: {
                                Label("管理者を解除", systemImage: "person.badge.minus")
                            }
                        }
                    }
                    Button(role: .destructive) {
                        pendingRemoval = member
                    } label: {
                        Label("グループから削除", systemImage: "person.fill.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // ★ 管理者はオーナーを操作できない。オーナー同士（＝常に自分だけ）も対象外なので、
    //   実質「管理者がオーナーを弄れない」ことだけを防げればよい
    private func canModerate(_ member: GroupMember) -> Bool {
        if member.effectiveRole == .owner { return false }
        return true
    }

    @ViewBuilder
    private func avatarView(_ member: GroupMember) -> some View {
        if let iconURL = member.iconURL, let url = URL(string: iconURL) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder(member)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            avatarPlaceholder(member)
        }
    }

    private func avatarPlaceholder(_ member: GroupMember) -> some View {
        Circle()
            .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(member.displayName.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func roleBadge(_ role: GroupRole) -> some View {
        let color: Color = {
            switch role {
            case .owner: return Color(red: 0.85, green: 0.65, blue: 0.2)
            case .admin: return accentColor
            case .member: return .secondary
            }
        }()

        return Text(role.displayLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }

    // MARK: - 危険操作（グループ削除。オーナーのみ）

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("危険な操作")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            Button(role: .destructive) {
                showDeleteGroupConfirm = true
            } label: {
                Label("グループを削除", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.top, 8)
    }

    private func deleteGroup() {
        isDeletingGroup = true
        groupViewModel.deleteGroupCompletely(group) { error in
            isDeletingGroup = false
            if let error {
                deleteErrorMessage = error.localizedDescription
            } else {
                dismiss()
            }
        }
    }
}
