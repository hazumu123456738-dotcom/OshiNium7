//
//  NewGroupView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct NewGroupView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    // ★ 2026/08/18追加：Gemini API利用規約の年齢要件対応のため
    @EnvironmentObject var settingsVM: UserSettingsViewModel
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
    @State private var showGroupLimitReached = false
    @State private var leaveCooldownDaysRemaining: Int?
    @State private var showPremiumUpgrade = false

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    // ★ 以前はここに独自の大見出し「新しいグループを作る」を置いていたが、
    //   .navigationTitle("新規グループ")と同じ役割の見出しが2つ並ぶ上に、このViewが
    //   ScrollViewで包まれていなかったため、ナビゲーションバーの安全領域を無視して
    //   画面最上部に張り付き、ナビゲーションバーの文字と物理的に重なって表示されていた
    //   （「ページとして機能していない」という指摘の原因）。見出しは削除し、説明文だけを
    //   AIバッジ付きの案内カードとして残す。ScrollViewで包むことで、常にナビゲーションバーの
    //   下から安全に始まるようにする
    var body: some View {
        ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 24) {

            introNoticeCard

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
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )

            // MARK: - カテゴリ（「会場口コミ」で同じカテゴリの他グループの口コミも
            //   見られるようにするための分類。必須項目にする）
            VStack(alignment: .leading, spacing: 8) {
                Text("カテゴリ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                // ★ 2026/08/16修正：minimum幅が100ptと狭く、長いラベルだけ2行に折り返されて
                //   カプセル背景が縦に伸び、他のチップと見た目が揃わなかった。
                //   幅を広げつつ、1行固定＋自動縮小でどのラベルも同じ高さのチップに揃える
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(GroupCategory.allCases) { category in
                        let isSelected = category == selectedCategory
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundColor(isSelected ? .white : accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule().fill(isSelected ? AnyShapeStyle(
                                        LinearGradient(colors: [accentColor, accentColor2],
                                                       startPoint: .leading, endPoint: .trailing)
                                    ) : AnyShapeStyle(accentColor.opacity(0.1)))
                                )
                                .overlay(
                                    Capsule().stroke(isSelected ? Color.clear : accentColor.opacity(0.15), lineWidth: 1)
                                )
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
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
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
        }
        .padding(20)
        .padding(.bottom, 12)
        }
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
                    groupViewModel.addGroup(existing) { error in
                        if let error, case GroupCreationError.groupLimitReached = error {
                            showGroupLimitReached = true
                            return
                        }
                        if let error, case GroupCreationError.leaveCooldownActive(let daysRemaining) = error {
                            leaveCooldownDaysRemaining = daysRemaining
                            return
                        }
                        onComplete?(existing)
                        dismiss()
                    }
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
        .alert("推しグループの上限に達しました", isPresented: $showGroupLimitReached) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text("無課金では推しグループを2件まで登録できます。プレミアムにアップグレードすると5件まで登録できます。")
        }
        .alert("少し待ってください", isPresented: Binding(
            get: { leaveCooldownDaysRemaining != nil },
            set: { if !$0 { leaveCooldownDaysRemaining = nil } }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text(GroupCreationError.leaveCooldownActive(daysRemaining: leaveCooldownDaysRemaining ?? 0).errorDescription ?? "")
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    // ★ AIバッジ付きの案内カード。ナビゲーションバーの見出し「新規グループ」と役割が
    //   重複しないよう、ここでは「何が起きるか」の説明だけに徹する
    private var introNoticeCard: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [accentColor, accentColor2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)

            Text("写真と名前を登録すると、あとはAIが詳細を自動で調べてくれます。すでに登録されているグループの場合は、そのグループに参加します。")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
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
                // ★ 2026/08/18追加：Gemini API利用規約の年齢要件対応。18歳未満のユーザーが
                //   作成した場合はこの自動補完だけをスキップする（グループ作成自体は続行）
                if settingsVM.settings.isAdult {
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
            } catch GroupCreationError.groupLimitReached {
                await MainActor.run {
                    isCreating = false
                    showGroupLimitReached = true
                }
            } catch let GroupCreationError.leaveCooldownActive(daysRemaining) {
                await MainActor.run {
                    isCreating = false
                    leaveCooldownDaysRemaining = daysRemaining
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
