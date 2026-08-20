//
//  PackingTemplatePostView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI
import FirebaseAuth

// ★ 持ち物テンプレートをそのまま投稿として共有する画面。PostComposerViewと同じ
//   「白いカードを積んだ」構成に揃え、テンプレートの中身（持ち物リスト）はそのまま
//   読み取り専用で載せつつ、キャプションだけ自由に書けるようにする
struct PackingTemplatePostView: View {

    let template: PackingTemplate

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @EnvironmentObject var navState: AppNavigationState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroupId: String?
    @State private var caption = ""
    @State private var isPosting = false

    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)
    private let accentColor2 = Color(red: 0.55, green: 0.82, blue: 0.60)

    private var canPost: Bool { selectedGroupId != nil }

    // ★ PackingTemplateManagerViewのNavigationStackからNavigationLinkでpushして使う画面のため、
    //   ここでは自前のNavigationStackを持たない（二重ネストすると戻る導線がおかしくなるため）
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                templateCard
                captionCard

                if !groupViewModel.groups.isEmpty {
                    groupChips
                }

                postButton
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("持ち物リストを投稿")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedGroupId == nil {
                selectedGroupId = groupViewModel.groups.first?.id
            }
        }
    }

    // MARK: - テンプレートの中身（読み取り専用）

    private var templateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(template.name, systemImage: "checklist")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(accentColor)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(template.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "circle")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor.opacity(0.6))
                        Text(item)
                            .font(.system(size: 13))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - キャプション

    private var captionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("キャプション（任意）")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("この持ち物リストについてひとこと", text: $caption, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(3...8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - グループ選択チップ

    private var groupChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("どの推しの投稿？")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groupViewModel.groups) { group in
                        let isSelected = group.id == selectedGroupId
                        Button {
                            selectedGroupId = group.id
                        } label: {
                            Text(group.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if isSelected {
                                            Capsule().fill(
                                                LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                                            )
                                        } else {
                                            Capsule().fill(Color.appCardBackground)
                                        }
                                    }
                                )
                                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 投稿ボタン

    private var postButton: some View {
        Button {
            post()
        } label: {
            HStack(spacing: 6) {
                if isPosting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .accessibilityHidden(true)
                }
                Text(isPosting ? "投稿しています…" : "投稿する")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
            .clipShape(Capsule())
            .opacity(canPost ? 1 : 0.5)
        }
        .disabled(!canPost || isPosting)
    }

    private func post() {
        guard let uid = Auth.auth().currentUser?.uid,
              let groupId = selectedGroupId,
              let group = groupViewModel.groups.first(where: { $0.id == groupId })
        else { return }

        isPosting = true

        postViewModel.createPost(
            groupId: groupId,
            groupName: group.name,
            mediaURL: nil,
            mediaType: nil,
            caption: caption,
            authorUid: uid,
            packingTemplateName: template.name,
            packingTemplateItems: template.items
        ) { error in
            DispatchQueue.main.async {
                isPosting = false
                if let error {
                    navState.showToast("投稿できませんでした。もう一度お試しください")
                    print("🔥 PackingTemplatePostView post error: \(error.localizedDescription)")
                } else {
                    dismiss()
                }
            }
        }
    }
}
