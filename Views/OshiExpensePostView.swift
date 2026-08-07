//
//  OshiExpensePostView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI
import FirebaseAuth

// ★ 推し活の金額記録をそのまま投稿として共有する画面。PackingTemplatePostViewと
//   全く同じ「白いカードを積んだ」構成に揃える。記録済みの金額・カテゴリ・画像は
//   そのまま読み取り専用で載せ、キャプションだけ自由に書けるようにする
struct OshiExpensePostView: View {

    let expense: OshiExpense

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var postViewModel: PostViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedGroupId: String?
    @State private var caption = ""
    @State private var isPosting = false

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var canPost: Bool { selectedGroupId != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    expenseCard
                    captionCard

                    if !groupViewModel.groups.isEmpty {
                        groupChips
                    }

                    postButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("金額の記録を投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                if selectedGroupId == nil {
                    selectedGroupId = expense.groupId ?? groupViewModel.groups.first?.id
                }
            }
        }
    }

    // MARK: - 記録の中身（読み取り専用）

    private var expenseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(expense.spentOnLabel)に\(yenText(expense.amount))かかった", systemImage: "yensign.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(accentColor)

            Text(expense.category)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(accentColor.opacity(0.1)))

            if let urlString = expense.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipped()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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

            TextField("この記録についてひとこと", text: $caption, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(3...8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
            mediaURL: expense.imageURL,
            mediaType: expense.imageURL != nil ? "image" : nil,
            caption: caption,
            authorUid: uid,
            expenseAmount: expense.amount,
            expenseCategory: expense.spentOnLabel
        ) { _ in
            DispatchQueue.main.async {
                isPosting = false
                dismiss()
            }
        }
    }

    private func yenText(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "¥" + (f.string(from: NSNumber(value: amount)) ?? "\(amount)")
    }
}
