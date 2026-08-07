//
//  NewGroupView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct NewGroupView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) var dismiss

    var onComplete: ((IdolGroup) -> Void)? = nil   // ★追加

    @State private var groupName = ""
    @State private var selectedCategory: GroupCategory? = nil
    // ★ 「GON」のように同名の別人・別グループが存在する場合、AIがコンセプト・歴史欄で
    //   情報を混同してしまう問題への対策。カテゴリだけでは絞りきれない時のための任意ヒント欄
    @State private var activityHint = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isCreating = false
    @State private var duplicateGroup: IdolGroup? = nil
    @State private var errorMessage: String? = nil

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            VStack(alignment: .leading, spacing: 4) {
                Text("新しいグループを作る")
                    .font(.system(size: 20, weight: .bold))
                Text("写真と名前を登録すると、あとはAIが詳細を自動で調べてくれます。すでに登録されているグループの場合は、そのグループに参加します。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // MARK: - グループ画像
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 116, height: 116)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(colors: [accentColor.opacity(0.18), accentColor2.opacity(0.18)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 116, height: 116)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(accentColor)
                            )
                    }

                    Circle()
                        .fill(
                            LinearGradient(colors: [accentColor, accentColor2],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .offset(x: 40, y: 40)
                }
            }
            .accessibilityLabel("グループ画像を選択")
            .frame(maxWidth: .infinity)
            .padding(.top, 6)

            // MARK: - グループ名
            VStack(alignment: .leading, spacing: 8) {
                Text("グループ名")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("例：xikers", text: $groupName)
                    .font(.system(size: 16))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            // MARK: - カテゴリ（「会場口コミ」で同じカテゴリの他グループの口コミも
            //   見られるようにするための分類。必須項目にする）
            VStack(alignment: .leading, spacing: 8) {
                Text("カテゴリ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(GroupCategory.allCases) { category in
                        let isSelected = category == selectedCategory
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isSelected ? .white : accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule().fill(isSelected ? AnyShapeStyle(
                                        LinearGradient(colors: [accentColor, accentColor2],
                                                       startPoint: .leading, endPoint: .trailing)
                                    ) : AnyShapeStyle(accentColor.opacity(0.1)))
                                )
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            // MARK: - 活動内容のヒント（任意。同名の別人・別グループとAIが混同するのを防ぐ）
            VStack(alignment: .leading, spacing: 8) {
                Text("活動内容のヒント（任意）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("例：元プロゲーマー、VALORANT配信者", text: $activityHint)
                    .font(.system(size: 14))
                Text("同じ名前で活動する別人・別グループがいる場合、ここに書いておくとAIが正しい情報を見つけやすくなります")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            // MARK: - 作成ボタン
            Button(action: createGroup) {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView().tint(.white)
                    }
                    Text(isCreating ? "確認しています…" : "作成する")
                }
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    !canCreate
                        ? AnyShapeStyle(Color.gray.opacity(0.35))
                        : AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2],
                                                        startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: !canCreate ? .clear : accentColor.opacity(0.35),
                        radius: 12, x: 0, y: 6)
            }
            .disabled(!canCreate)

            Spacer()
        }
        .padding(20)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("新規グループ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .alert(item: $duplicateGroup) { existing in
            Alert(
                title: Text("「\(existing.name)」はすでに登録されています"),
                message: Text("同じグループを重複して作成することはできません。既存のグループに参加しますか？"),
                primaryButton: .default(Text("参加する")) {
                    groupViewModel.addGroup(existing)
                    onComplete?(existing)
                    dismiss()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
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

    private var canCreate: Bool {
        !groupName.isEmpty && selectedImage != nil && selectedCategory != nil && !isCreating
    }

    // MARK: - グループ作成処理（既存カタログとの重複チェック込み）
    private func createGroup() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8),
              let selectedCategory else { return }

        isCreating = true

        Task {
            do {
                let newGroup = try await groupViewModel.createGroup(name: groupName, imageData: imageData, category: selectedCategory)

                // ★ 推し活の自動化：AIが裏側でグループ情報を調べて詳細カードを自動で埋める
                //   （画面はすぐ閉じてよいのでawaitせず、完了したらFirestoreを更新するだけにする）
                Task {
                    if let result = await GroupInfoSearchService.shared.searchGroupInfo(
                        groupName: newGroup.name,
                        category: selectedCategory,
                        activityHint: activityHint
                    ) {
                        var filled = newGroup
                        filled.reading = result.reading
                        filled.fandom = result.fandom
                        filled.concept = result.concept
                        filled.history = result.history
                        filled.groupDescription = result.groupDescription
                        groupViewModel.updateGroup(filled)
                    }
                }

                await MainActor.run {
                    isCreating = false
                    onComplete?(newGroup)
                    dismiss()
                }
            } catch let GroupCreationError.duplicate(existing) {
                await MainActor.run {
                    isCreating = false
                    duplicateGroup = existing
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
