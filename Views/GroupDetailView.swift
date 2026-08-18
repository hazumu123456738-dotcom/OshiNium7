//
//  GroupDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/19.
//

import SwiftUI
import PhotosUI

struct GroupDetailView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var navState: AppNavigationState
    // ★ 2026/08/18追加：Gemini API利用規約の年齢要件対応のため
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @State private var localGroup: IdolGroup
    @State private var isSearchingAI = false
    @State private var aiSearchFailed = false
    @State private var showEdit = false

    // ★ 2026/08/15追加：グループ選択画面に出る元々の画像はそのままに、参加済みメンバーが
    //   各自の画面にだけ表示するアイコンを変更できるようにする機能
    @State private var iconPickerItem: PhotosPickerItem? = nil
    // ★ 2026/08/16追加：選んだ直後はまだ確定させず、プレビューとして保持しておく
    @State private var pendingIconImage: UIImage? = nil
    @State private var isUploadingIcon = false

    init(group: IdolGroup) {
        _localGroup = State(initialValue: group)
    }

    private let accentColor = Color.oshiniumPrimary

    // 詳細が1つでもあるかどうか
    private var hasDetail: Bool {
        localGroup.concept != nil ||
        localGroup.history != nil ||
        localGroup.groupDescription != nil
    }

    // ★ 自分が参加しているグループだけ、AI自動入力（＝自分の手元データの更新）を許可する
    private var isOwnGroup: Bool {
        groupViewModel.groups.contains(where: { $0.id == localGroup.id })
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                heroCard

                if hasDetail {
                    infoCard {
                        HStack(spacing: 28) {
                            labeledValue(label: "読み方", value: localGroup.reading)
                            labeledValue(label: "ファンダム名", value: localGroup.fandom)
                            Spacer()
                        }
                    }

                    infoCard {
                        sectionBlock(icon: "sparkles", title: "コンセプト", text: localGroup.concept)
                    }

                    infoCard {
                        sectionBlock(icon: "clock.arrow.circlepath", title: "歴史", text: localGroup.history)
                    }

                    infoCard {
                        sectionBlock(icon: "text.alignleft", title: "説明", text: localGroup.groupDescription)
                    }

                    // ★ 2026/08/16追加：この詳細カードはAIが検索結果をもとに自動生成したものが
                    //   多く、実在しないグループ名に対しても実在の第三者を交えた誤情報を
                    //   自信ありげに生成してしまう事例が確認された。内容を鵜呑みにされないよう、
                    //   常に見える位置に注記を出す
                    Text("この内容はAIが自動で調べたものです。誤りが含まれる場合があるため、正確な情報は公式情報でご確認ください。")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    emptyDetailCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(localGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnGroup {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(accentColor)
                    }
                    .accessibilityLabel("グループ情報を編集")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NavigationStack {
                GroupDetailEditView(group: localGroup)
            }
        }
        // ★ グループ作成直後はAIによる自動調査がバックグラウンドで走っている最中のことがあるため、
        //   Firestoreの最新データ（groupViewModel.groups）が更新されたら手動操作なしで画面に反映する。
        //   IdolGroup.== はidだけを見る実装なので、onChangeではなく毎回発火するonReceiveを使う。
        .onReceive(groupViewModel.$groups) { updated in
            if let latest = updated.first(where: { $0.id == localGroup.id }) {
                localGroup = latest
            }
        }
    }

    // MARK: - 詳細未設定時のカード（AI自動入力）
    private var emptyDetailCard: some View {
        infoCard {
            VStack(spacing: 12) {
                Text("このグループはまだ詳細カードが設定されていません。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isOwnGroup {
                    Button {
                        runAISearch()
                    } label: {
                        HStack(spacing: 6) {
                            if isSearchingAI {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isSearchingAI ? "AIが調べています…" : "AIで自動入力")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(
                                colors: [accentColor, Color.oshiniumPrimary2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .disabled(isSearchingAI)

                    if aiSearchFailed {
                        Text("情報が見つかりませんでした。もう一度試すか、右上の編集ボタンから手入力してください。")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }

                    Button {
                        showEdit = true
                    } label: {
                        Text("自分で入力する")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
    }

    // ★ 2026/08/18追加：Gemini API利用規約の年齢要件対応
    private func runAISearch() {
        guard settingsVM.settings.isAdult else {
            aiSearchFailed = true
            return
        }
        guard !isSearchingAI else { return }
        isSearchingAI = true
        aiSearchFailed = false

        Task {
            let result = await GroupInfoSearchService.shared.searchGroupInfo(groupName: localGroup.name)

            await MainActor.run {
                isSearchingAI = false

                guard let result,
                      (result.reading ?? result.fandom ?? result.concept ?? result.history ?? result.groupDescription) != nil
                else {
                    aiSearchFailed = true
                    return
                }

                localGroup.reading = result.reading
                localGroup.fandom = result.fandom
                localGroup.concept = result.concept
                localGroup.history = result.history
                localGroup.groupDescription = result.groupDescription

                groupViewModel.updateGroup(localGroup)
            }
        }
    }

    // MARK: - Heroカード
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            // ★ 2026/08/16修正：選んだ直後にすぐアップロードしていたため、
            //   ユーザーからは「本当に変わったのか」がその場で分かりにくかった。
            //   選択直後はまずプレビューとして表示し、「変更する」を押した時点で確定させる
            if let pendingIconImage {
                Image(uiImage: pendingIconImage)
                    .resizable()
                    .scaledToFill()
            } else if let data = localGroup.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackHero
            }

            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                startPoint: .bottom,
                endPoint: .center
            )

            // ★ 2026/08/16修正：アイコン変更のプレビュー中に「変更する」バーとグループ名が
            //   同じ左下に重なって表示されていた。プレビュー中はグループ名側を隠し、
            //   確認バーだけがはっきり見えるようにする
            if pendingIconImage == nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let fandom = localGroup.fandom, !fandom.isEmpty {
                        Text(fandom)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.25))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    Text(localGroup.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(20)
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        .overlay(alignment: .topTrailing) {
            // ★ 参加済みのグループだけ、自分専用のアイコン変更ボタンを出す。
            //   グループ選択画面（catalog由来の元々の画像）には影響しない
            if isOwnGroup, pendingIconImage == nil {
                PhotosPicker(selection: $iconPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.4), in: Circle())
                }
                .accessibilityLabel("自分のアイコンを変更")
                .padding(12)
                .onChange(of: iconPickerItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await loadPendingIcon(newItem) }
                }
            }
        }
        .overlay(alignment: .bottom) {
            // ★ プレビュー中だけ出す「変更する／キャンセル」の確認バー。
            //   ここではっきり操作させることで「選んだら即・無言で変わる」を避け、
            //   変更したこと・していないことが自分でも分かるようにする
            if pendingIconImage != nil {
                HStack(spacing: 10) {
                    Button {
                        pendingIconImage = nil
                        iconPickerItem = nil
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.25), in: Capsule())
                    }
                    .disabled(isUploadingIcon)

                    Button {
                        Task { await confirmIconChange() }
                    } label: {
                        HStack(spacing: 6) {
                            if isUploadingIcon {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            Text("このアイコンに変更する")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(accentColor, in: Capsule())
                    }
                    .disabled(isUploadingIcon)
                }
                .padding(.bottom, 14)
            }
        }
    }

    // ★ 2026/08/16追加：選んだ直後はまだ確定させず、まずプレビュー用に読み込むだけ。
    //   ここではFirestoreへの書き込みは一切行わない
    private func loadPendingIcon(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            iconPickerItem = nil
            return
        }
        pendingIconImage = uiImage
    }

    // ★ 「変更する」を押した時点で確定させる。groups/{id}本体やcatalogには一切書き込まず、
    //   users/{自分のuid}/selectedGroups/{groupId}のimageDataだけを差し替える
    //   （GroupViewModel.updateMyGroupIcon参照）。保存後はlocalGroupも即座に更新し、
    //   このまま画面を閉じなくてもすぐ反映されたことが分かるようにする
    private func confirmIconChange() async {
        guard let pendingIconImage, let jpegData = pendingIconImage.jpegData(compressionQuality: 0.8) else {
            self.pendingIconImage = nil
            iconPickerItem = nil
            return
        }

        isUploadingIcon = true
        groupViewModel.updateMyGroupIcon(groupId: localGroup.id, imageData: jpegData) { error in
            isUploadingIcon = false
            iconPickerItem = nil
            self.pendingIconImage = nil
            if error == nil {
                localGroup.imageData = jpegData
                navState.showToast("アイコンを変更しました")
            } else {
                navState.showToast("アイコンを変更できませんでした")
            }
        }
    }

    private var fallbackHero: some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.85), Color.oshiniumPrimary2.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(localGroup.name.prefix(1)))
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: - 共通カード
    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

            content()
                .padding(16)
        }
    }

    // ★ AIが確証を持てず空にした項目や未入力の項目は、適当な作り話で埋めず「特になし」と
    //   はっきり表示する。ユーザーが後から編集ボタンで正しい情報に書き換えられるようにするため。
    private func labeledValue(label: String, value: String?) -> some View {
        let resolved = value.nonEmptyOrNil
        return VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(resolved ?? "特になし")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(resolved == nil ? .secondary.opacity(0.7) : .primary)
        }
    }

    private func sectionBlock(icon: String, title: String, text: String?) -> some View {
        let resolved = text.nonEmptyOrNil
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(resolved ?? "特になし")
                .font(.system(size: 14))
                .foregroundColor(resolved == nil ? .secondary.opacity(0.7) : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
