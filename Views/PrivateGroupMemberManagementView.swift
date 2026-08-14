//
//  PrivateGroupMemberManagementView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/14.
//

import SwiftUI
import FirebaseAuth
import NukeUI

// ★ 招待制グループチャット(isPrivate)専用のメンバー管理画面。コミュニティ（推し）グループの
//   ような権限差（オーナー・管理者）は一切存在しない設計のままだが、招待制グループチャットは
//   少人数・高信頼という前提のもと、全メンバーが対等に他の全メンバー（自分自身も含め、
//   例外なし）を退会させられる特別な機能として、この画面だけに用意する。
//   コミュニティグループにはこの画面自体を出さない（ChatRoomView側でisPrivateの時だけ導線を出す）
struct PrivateGroupMemberManagementView: View {
    let group: IdolGroup

    @EnvironmentObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var removeTarget: GroupMember?
    @State private var toastMessage: String?
    // ★ ブロックはあくまで「表示・接触の制限」であり、グループ所属そのものは変えない。
    //   そのためgroupViewModel.members（実際のメンバー構成・退会機能の対象）はそのままに、
    //   この画面に表示する行だけをブロック相手を除いた一覧にする
    @State private var blockedUids: Set<String> = []

    private let accentColor = Color.oshiniumPrimary
    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var visibleMembers: [GroupMember] {
        groupViewModel.members.filter { !blockedUids.contains($0.uid) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                noticeCard

                VStack(spacing: 0) {
                    ForEach(visibleMembers) { member in
                        memberRow(member)
                        if member.id != visibleMembers.last?.id {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("メンバー")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            groupViewModel.fetchMembers(for: group.id)
            ModerationService.fetchBlockedUids { uids in
                DispatchQueue.main.async { blockedUids = uids }
            }
        }
        .onDisappear {
            groupViewModel.stopFetchingMembers()
        }
        .confirmationDialog(
            removeTarget.map { $0.uid == currentUid ? "このグループを退会しますか？" : "\($0.displayName)さんを退会させますか？" } ?? "",
            isPresented: Binding(
                get: { removeTarget != nil },
                set: { if !$0 { removeTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(removeTarget?.uid == currentUid ? "退会する" : "退会させる", role: .destructive) {
                guard let target = removeTarget else { return }
                groupViewModel.removeOtherMember(groupId: group.id, targetUid: target.uid) { _ in
                    withAnimation { toastMessage = "\(target.displayName)さんを退会させました" }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { toastMessage = nil }
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                SimpleToast(text: toastMessage)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
    }

    // MARK: - 案内カード

    private var noticeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text("招待制グループチャットでは、メンバー全員が対等に他のメンバーを退会させることができます。")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
    }

    // MARK: - メンバー行

    private func memberRow(_ member: GroupMember) -> some View {
        HStack(spacing: 12) {
            if let iconURL = member.iconURL, let url = URL(string: iconURL) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Circle().fill(Color(.systemGray4))
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle().fill(Color(.systemGray4)).frame(width: 40, height: 40)
            }

            Text(member.displayName)
                .font(.system(size: 14, weight: .semibold))

            if member.uid == currentUid {
                Text("あなた")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accentColor.opacity(0.12)))
            }

            Spacer(minLength: 0)

            Button {
                removeTarget = member
            } label: {
                Text(member.uid == currentUid ? "退会する" : "退会させる")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.red)
            }
            .accessibilityLabel(member.uid == currentUid ? "グループを退会する" : "\(member.displayName)さんを退会させる")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
