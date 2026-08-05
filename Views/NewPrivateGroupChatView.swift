//
//  NewPrivateGroupChatView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import FirebaseAuth

// ★ 友だち同士の招待制グループチャットを作る画面。
//   誰でも作成できるが、招待できるのは相互フォローの相手だけ（DMと同じ制限）。
//   作成すると同時にそのグループ専用のコミュニティチャット・カレンダーが自動的に
//   用意される（CalendarViewModel.startListening側の自動作成の仕組みをそのまま利用）ため、
//   ユーザーがカレンダー側で何か操作をする必要はない――という説明をここで案内する
struct NewPrivateGroupChatView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var followViewModel: FollowViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var groupName = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var selectedUids: Set<String> = []
    @State private var mutualProfiles: [(uid: String, name: String, iconURL: String?)] = []

    @State private var isCreating = false
    @State private var createdGroup: IdolGroup?
    @State private var errorMessage: String?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var myUid: String? { Auth.auth().currentUser?.uid }
    private var mutualUids: Set<String> { followViewModel.followingIds.intersection(followViewModel.followerIds) }

    private var inviteLink: String {
        guard let id = createdGroup?.id else { return "" }
        return "oshinium://join?group=\(id)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let createdGroup {
                confirmationCard(for: createdGroup)
            } else {
                formCard
            }
        }
        .padding(20)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("グループチャットを作る")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: mutualUids) {
            await loadMutualProfiles()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 入力フォーム

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("新しいグループチャット")
                    .font(.system(size: 20, weight: .bold))
                Text("友だちとの招待制チャットです。招待できるのは相互フォローの相手だけ。招待リンクを送ることもできます。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // ★ チャット一覧でどのグループか見分けやすいよう、アイコンを設定できるようにする
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 92, height: 92)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(LinearGradient(colors: [accentColor.opacity(0.18), accentColor2.opacity(0.18)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 92, height: 92)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(accentColor)
                            )
                    }

                    Circle()
                        .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: 32, y: 32)
                }
            }
            .accessibilityLabel("グループ画像を選択")
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text("グループ名")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("例：担当仲間", text: $groupName)
                    .font(.system(size: 16))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("招待する相手（相互フォローのみ）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                if mutualProfiles.isEmpty {
                    Text("相互フォローの相手がまだいません。作成後に招待リンクで誘うこともできます。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.vertical, 4)
                } else {
                    inviteFlow
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            Button(action: create) {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView().tint(.white)
                    }
                    Text(isCreating ? "作成しています…" : "作成する")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    (groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                        ? AnyShapeStyle(Color.gray.opacity(0.35))
                        : AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2],
                                                        startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: (groupName.isEmpty || isCreating) ? .clear : accentColor.opacity(0.35),
                        radius: 12, x: 0, y: 6)
            }
            .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
        }
    }

    private var inviteFlow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mutualProfiles, id: \.uid) { profile in
                    let isSelected = selectedUids.contains(profile.uid)
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            if isSelected { selectedUids.remove(profile.uid) } else { selectedUids.insert(profile.uid) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(profile.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                            }
                        }
                        .foregroundColor(isSelected ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                isSelected
                                    ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Color(.systemGray6))
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 作成完了（招待リンク案内）

    private func confirmationCard(for group: IdolGroup) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accentColor.opacity(0.18), accentColor2.opacity(0.18)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(accentColor)
                }
                Text("「\(group.name)」を作成しました！")
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("専用のグループチャットとカレンダーが自動的に用意されます。カレンダータブを開くと、このグループのコミュニティカレンダーがすぐに使えます。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)

            if !selectedUids.isEmpty {
                Label("選んだ\(selectedUids.count)人に招待を送りました", systemImage: "paperplane.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("招待リンク")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(inviteLink)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            ShareLink(item: URL(string: inviteLink) ?? URL(string: "https://oshinium.app")!,
                      subject: Text("「\(group.name)」に招待するよ"),
                      message: Text("OshiNiumのグループチャット「\(group.name)」に招待するよ！")) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("招待リンクを送る")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
            }

            Button {
                dismiss()
            } label: {
                Text("チャット一覧に戻る")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }

    // MARK: - 読み込み・作成処理

    private func loadMutualProfiles() async {
        var loaded: [(uid: String, name: String, iconURL: String?)] = []
        for uid in mutualUids {
            let profile = await ChatViewModel.fetchUserProfile(uid: uid)
            loaded.append((uid, profile?.displayName ?? "名無しさん", profile?.iconURL))
        }
        await MainActor.run { self.mutualProfiles = loaded }
    }

    private func create() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true

        Task {
            do {
                let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                let newGroup = try await groupViewModel.createPrivateGroup(name: trimmedName, imageData: imageData)

                if let myUid {
                    let myName = settingsVM.settings.displayName.isEmpty ? "名無しさん" : settingsVM.settings.displayName
                    let myIcon = settingsVM.settings.iconURL.isEmpty ? nil : settingsVM.settings.iconURL
                    for uid in selectedUids {
                        AppNotificationViewModel.notifyGroupInvite(
                            recipientUid: uid,
                            groupId: newGroup.id,
                            groupName: newGroup.name,
                            actorUid: myUid,
                            actorName: myName,
                            actorIconURL: myIcon
                        )
                    }
                }

                await MainActor.run {
                    isCreating = false
                    createdGroup = newGroup
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
