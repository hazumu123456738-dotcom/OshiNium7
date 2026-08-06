//
//  CalendarInviteView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import SwiftUI

// ★ 個人カレンダーは作成時にしかメンバーを選べなかったため、作成後いつでも
//   長押し→「招待する」から追加できるようにする。招待できるのは相互フォローの
//   相手だけ（NewPrivateGroupChatViewの招待フローと同じ制限・見た目に揃える）
struct CalendarInviteView: View {

    let calendar: OshiCalendar
    @ObservedObject var calendarViewModel: CalendarViewModel

    @EnvironmentObject var followViewModel: FollowViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mutualProfiles: [(uid: String, name: String, iconURL: String?)] = []
    @State private var selectedUids: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var mutualUids: Set<String> {
        followViewModel.followingIds.intersection(followViewModel.followerIds)
    }

    // ★ すでにメンバーの人は選択肢に出さない
    private var invitableProfiles: [(uid: String, name: String, iconURL: String?)] {
        mutualProfiles.filter { !calendar.memberIds.contains($0.uid) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("「\(calendar.name)」に招待")
                            .font(.system(size: 18, weight: .bold))
                        Text("招待できるのは相互フォローの相手だけです。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    if invitableProfiles.isEmpty {
                        emptyState
                    } else {
                        memberList
                    }

                    inviteButton
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task(id: mutualUids) {
            await loadMutualProfiles()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.6))
            Text("招待できる相手がいません")
                .font(.system(size: 13, weight: .semibold))
            Text("相互フォローの相手で、まだこのカレンダーに参加していない人が表示されます。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var memberList: some View {
        VStack(spacing: 0) {
            ForEach(invitableProfiles, id: \.uid) { profile in
                memberRow(profile)
                if profile.uid != invitableProfiles.last?.uid {
                    Divider()
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func memberRow(_ profile: (uid: String, name: String, iconURL: String?)) -> some View {
        let isSelected = selectedUids.contains(profile.uid)

        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                if isSelected { selectedUids.remove(profile.uid) } else { selectedUids.insert(profile.uid) }
            }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let iconURL = profile.iconURL, let url = URL(string: iconURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(.systemGray4)
                            }
                        }
                    } else {
                        Color(.systemGray4)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                Text(profile.name)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? accentColor : .gray.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var inviteButton: some View {
        Button {
            invite()
        } label: {
            HStack(spacing: 6) {
                if isSaving {
                    ProgressView().tint(.white)
                }
                Text(isSaving ? "招待しています…" : "招待する")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                (selectedUids.isEmpty || isSaving)
                    ? AnyShapeStyle(Color.gray.opacity(0.35))
                    : AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
            )
            .clipShape(Capsule())
        }
        .disabled(selectedUids.isEmpty || isSaving)
    }

    private func loadMutualProfiles() async {
        var loaded: [(uid: String, name: String, iconURL: String?)] = []
        for uid in mutualUids {
            let profile = await ChatViewModel.fetchUserProfile(uid: uid)
            loaded.append((uid, profile?.displayName ?? "名無しさん", profile?.iconURL))
        }
        await MainActor.run { self.mutualProfiles = loaded }
    }

    private func invite() {
        guard !selectedUids.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        let newMemberIds = Array(Set(calendar.memberIds).union(selectedUids))

        calendarViewModel.updateCalendarMembers(calendarId: calendar.id, memberIds: newMemberIds) { error in
            isSaving = false
            if let error {
                errorMessage = error.localizedDescription
                return
            }
            dismiss()
        }
    }
}
