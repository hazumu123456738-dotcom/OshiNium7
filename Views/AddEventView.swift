//
//  AddEventView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import SwiftUI
import PhotosUI
import UIKit

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var navState: AppNavigationState

    let selectedGroup: IdolGroup
    let calendarId: String?

    @State private var date: Date

    @State private var title: String = ""
    @State private var isSecret: Bool = false

    @State private var selectedType: EventType = .live
    @State private var selectedSubType: EventSubType = .oneman
    @State private var customSubType: String = ""

    @State private var place: String = ""
    @State private var timeText: String = ""
    @State private var condition: String = ""
    @State private var applyDate: String = ""
    @State private var channel: String = ""
    @State private var programName: String = ""
    @State private var url: String = ""
    @State private var notes: String = ""
    @State private var notifyOffsets: [Int] = []

    @State private var selectedImages: [UIImage] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []

    @State private var appear = false
    @State private var pageIndex: Int = 0
    @State private var isSaving: Bool = false

    // ★ 似た予定を重複して追加してしまうミスを防ぐための軽い確認ダイアログ
    @State private var duplicateCandidate: Event? = nil
    @State private var showDuplicateConfirm = false

    // ★ コミュニティカレンダー（calendarId == nil）に保存する場合のみ、保存ボタンを
    //   押した瞬間に確認する。「今後は表示しない」を選ぶと以後この確認は出ない
    //   （マイページの設定から再度有効化できる）
    @AppStorage(CommunityCalendarSaveWarning.storageKey) private var hideCommunityCalendarSaveWarning = false
    @State private var showCommunitySaveConfirm = false

    // ★ 選んだイベントの種類によって色が変わる（OshiNiumタブと同じ「イベントの色を強く反映する」コンセプト）
    private var accentColor: Color { selectedType.iconColor }
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.65)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    init(selectedGroup: IdolGroup, defaultDate: Date, calendarId: String? = nil) {
        self.selectedGroup = selectedGroup
        self.calendarId = calendarId
        self._date = State(initialValue: defaultDate)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                headerView

                TabView(selection: $pageIndex) {
                    ScrollView {
                        VStack(spacing: 4.8) {
                            stepHeader(step: 1, title: "基本情報", showBack: false)
                            groupCard
                            relatedImagesCard
                            titleCard
                            dateCard
                            typeCard
                            nextButton
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .tag(0)

                    ScrollView {
                        VStack(spacing: 10) {
                            stepHeader(step: 2, title: "場所・詳細", showBack: true)
                            detailAndMemoCard
                            secretCard
                            notifyCard
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.top, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appear = true
            }
        }
        .confirmationDialog(
            duplicateCandidate.map { "似た予定が既にあります\n「\($0.title)」(\(duplicateDateText($0)))" } ?? "",
            isPresented: $showDuplicateConfirm,
            titleVisibility: .visible
        ) {
            Button("それでも追加する") {
                Task { await saveEvent() }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "この予定はコミュニティカレンダーに保存されます。よろしいでしょうか？",
            isPresented: $showCommunitySaveConfirm,
            titleVisibility: .visible
        ) {
            Button("はい、確認済みです") {
                proceedToSaveAfterCommunityConfirm()
            }
            Button("今後はこの確認を表示しない") {
                hideCommunityCalendarSaveWarning = true
                proceedToSaveAfterCommunityConfirm()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - ヘッダー
    private var headerView: some View {
        HStack {
            // 閉じるボタン
            Button {
                if !isSaving { dismiss() }
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }
            .disabled(isSaving)
            .accessibilityLabel("閉じる")

            Spacer()

            // タイトル
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))

                Text("イベントを追加")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))
            }

            Spacer()

            // 保存ボタン（暗くなる＋二度押し防止）
            Button {
                if !isSaving {
                    if calendarId == nil && !hideCommunityCalendarSaveWarning {
                        showCommunitySaveConfirm = true
                    } else {
                        proceedToSaveAfterCommunityConfirm()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }

                    Text(isSaving ? "保存中…" : "保存")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSaving {
                            // ← 保存中はかなり暗い色にする
                            Color.gray.opacity(0.6)
                        } else {
                            accentGradient
                        }
                    }
                )
                .clipShape(Capsule())
                .opacity(isSaving ? 0.6 : 1.0)   // ← 保存中はボタン全体を暗くする
            }
            .disabled(isSaving)
            .scaleEffect(appear ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appear)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - カード共通コンテナ（OshiNiumタブと同じ白カード）
    private func cardContainer<Content: View>(_ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)

            content()
                .padding(16)
        }
    }

    // MARK: - グループカード
    private var groupCard: some View {
        cardContainer {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(accentColor)

                VStack(alignment: .leading) {
                    Text("登録先グループ")
                        .font(.system(size: 14, weight: .semibold))
                    Text(selectedGroup.name)
                        .font(.system(size: 16, weight: .medium))
                }

                Spacer()
            }
        }
    }

    // MARK: - 関連画像カード
    private var relatedImagesCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(accentColor)
                    Text("関連画像")
                        .font(.system(size: 15, weight: .semibold))
                }

                Text("イベントのビジュアルを設定（任意）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {

                        // 画像追加ボタン
                        PhotosPicker(
                            selection: $photoPickerItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            addImageTile
                        }
                        .onChange(of: photoPickerItems) { _, newItems in
                            Task {
                                for item in newItems {

                                    // Data で読み込む（PNG / JPEG / HEIC / iCloud 全対応）
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImages.append(uiImage)
                                    }
                                }
                            }
                        }

                        // 選択済み画像の表示
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, img in
                            imageThumbnail(image: Image(uiImage: img)) {
                                selectedImages.remove(at: index)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - 画像追加タイル
    private var addImageTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accentColor.opacity(0.07))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.4, dash: [6]))

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accentColor)
                }
                Text("画像を追加")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .frame(width: 88, height: 88)
    }

    // MARK: - 選択済み画像のサムネイル（共通）
    private func imageThumbnail(image: Image, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 88)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
            }
            .accessibilityLabel("この画像を削除")
            .padding(6)
        }
    }

    // MARK: - タイトルカード
    private var titleCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(accentColor)
                    Text("タイトル")
                        .font(.system(size: 15, weight: .semibold))
                }

                TextField("イベント名を入力", text: $title)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
            }
        }
    }

    // MARK: - 日時カード
    private var dateCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(accentColor)
                    Text("日時")
                        .font(.system(size: 15, weight: .semibold))
                }

                DatePicker("開始日時", selection: $date)
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - 種類カード
    private var typeCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(accentColor)
                    Text("種類")
                        .font(.system(size: 15, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("カテゴリ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("カテゴリ", selection: $selectedType) {
                        ForEach(EventType.allCases, id: \.self) { t in
                            Text("\(t.emoji) \(t.displayName)").tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("詳しい種類")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("詳しい種類", selection: $selectedSubType) {
                        ForEach(selectedType.subTypes(), id: \.self) { st in
                            Text(st.displayName).tag(st)
                        }
                        Text("その他").tag(EventSubType.other)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    if selectedSubType == .other {
                        TextField("種類を自由に入力（例：〇〇コラボ企画）", text: $customSubType)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                }
            }
        }
        .onChange(of: selectedType) { _, newType in
            selectedSubType = newType.subTypes().first ?? .other
            if selectedSubType != .other {
                customSubType = ""
            }
        }
        .onChange(of: selectedSubType) { _, newSub in
            if newSub != .other {
                customSubType = ""
            }
        }
    }

    // MARK: - ステップ見出し（今どこのステップか＋戻るボタン）
    private func stepHeader(step: Int, title: String, showBack: Bool) -> some View {
        HStack(spacing: 10) {
            if showBack {
                Button {
                    withAnimation { pageIndex = 0 }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
                }
            }

            Text("STEP \(step)/2")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accentGradient)
                .clipShape(Capsule())

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(step == 1 ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(step == 2 ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    // MARK: - 次へボタン
    private var nextButton: some View {
        Button {
            withAnimation {
                pageIndex = 1
            }
        } label: {
            HStack {
                Spacer()
                Text("次へ（場所・詳細）")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(
                accentGradient
            )
            .cornerRadius(28)
        }
        .buttonStyle(GradientTapStyle())
    }

    // MARK: - 場所・詳細＋メモカード
    //   ★ 「どんなユーザーでも理解できるように」：全種類共通の項目だけを常に出し、
    //     テレビ出演／応募制イベントなど、選んだ種類に関係する項目だけを追加で出す
    private var detailAndMemoCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("場所・詳細")
                        .font(.system(size: 15, weight: .semibold))
                    Text("わかる範囲でOK。あとから編集もできます")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Group {
                    detailField(icon: "mappin.and.ellipse", title: "場所", placeholder: "例：東京ドーム", text: $place)
                    detailField(icon: "clock", title: "補足時間", placeholder: "例：開場17:00 / 開演18:00", text: $timeText)

                    if selectedType == .event {
                        detailField(icon: "person.badge.key", title: "応募条件", placeholder: "例：友情/応援チケット対象者", text: $condition)
                        detailField(icon: "calendar", title: "応募期間", placeholder: "例：7/1〜7/10", text: $applyDate)
                    }

                    if selectedType == .tv {
                        detailField(icon: "tv", title: "放送局", placeholder: "例：日本テレビ", text: $channel)
                        detailField(icon: "play.tv", title: "番組名", placeholder: "例：〇〇魂", text: $programName)
                    }

                    detailField(icon: "link", title: "URL", placeholder: "例：https://...", text: $url)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("メモ")
                        .font(.system(size: 15, weight: .semibold))

                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("自由にメモを書けます（任意）")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 18)
                        }
                        TextEditor(text: $notes)
                            .frame(height: 120)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
        }
    }

    private func detailField(icon: String, title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }

            TextField(placeholder, text: text)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(16)
        }
    }

    // MARK: - 秘密イベントカード
    //   ★ オフ（通常）だと予定はグループ全員に共有される。オンにすると自分だけにしか
    //     見えなくなる。この違いがトグルの見た目だけでは伝わりにくいという指摘を受け、
    //     状態に応じて切り替わるバッジを添えて、今どちらの状態かを常にはっきり示す
    private var secretCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("秘密イベント")
                            .font(.system(size: 15, weight: .semibold))  // ✅ 正しい
                        Text(isSecret ? "本人のみ表示" : "グループ全員に共有されます")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isSecret)
                        .labelsHidden()
                }

                SharedScopeBadge(scope: isSecret ? .private : .shared, tint: accentColor)
            }
        }
    }

    // MARK: - 通知カード
    private var notifyCard: some View {
        cardContainer {
            ReminderOffsetsEditor(offsets: $notifyOffsets, accentColor: accentColor)
        }
    }

    // MARK: - 重複予定チェック

    // ★ 同じグループ・同じ日に、タイトルが似ている予定が既に無いか確認する。
    //   完全一致だけでなく「〇〇ライブ」と「ライブ」のような部分一致もゆるく拾い、
    //   誤って同じ予定を二重に追加してしまうミスに気づけるようにする（保存自体は止めない）
    private func findPossibleDuplicate() -> Event? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        let normalizedTitle = trimmedTitle.lowercased()

        return eventViewModel.events.first { existing in
            guard existing.groupId == selectedGroup.id else { return false }
            guard Calendar.current.isDate(existing.date, inSameDayAs: date) else { return false }
            let normalizedExisting = existing.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedExisting.isEmpty else { return false }
            return normalizedExisting.contains(normalizedTitle) || normalizedTitle.contains(normalizedExisting)
        }
    }

    private func proceedToSaveAfterCommunityConfirm() {
        if let duplicate = findPossibleDuplicate() {
            duplicateCandidate = duplicate
            showDuplicateConfirm = true
        } else {
            Task { await saveEvent() }
        }
    }

    private func duplicateDateText(_ event: Event) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: event.date)
    }

    // MARK: - 保存処理（完全安定版）
    private func saveEvent() async {

        // すでに保存中なら即 return（最重要）
        guard !isSaving else { return }
        isSaving = true   // ← ここでボタンを完全にロックする

        // カスタムサブタイプ整形
        let trimmedCustom = customSubType.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCustom: String? = trimmedCustom.isEmpty ? nil : trimmedCustom

        // Firestore に保存する Event（画像なし）
        let newEvent = Event(
            id: nil,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            isSecret: isSecret,
            groupId: selectedGroup.id,
            calendarId: calendarId,
            type: selectedType,
            subType: selectedSubType,
            customSubType: finalCustom,
            place: place.isEmpty ? nil : place,
            timeText: timeText.isEmpty ? nil : timeText,
            condition: condition.isEmpty ? nil : condition,
            applyDate: applyDate.isEmpty ? nil : applyDate,
            channel: channel.isEmpty ? nil : channel,
            programName: programName.isEmpty ? nil : programName,
            url: url.isEmpty ? nil : url,
            notes: notes.isEmpty ? nil : notes,
            notifyOffsets: notifyOffsets.isEmpty ? nil : notifyOffsets,
            imageURLs: []
        )

        // ① Firestore に保存 → Event を受け取る
        guard let savedEvent = await eventViewModel.addEventReturningEvent(newEvent),
              let eventId = savedEvent.id else {
            isSaving = false
            dismiss()
            return
        }
        AnalyticsManager.logEventCreated(groupId: selectedGroup.id, method: "manual")

        print("DEBUG selectedImages count =", selectedImages.count)

        // ② Storage に画像アップロード
        var uploadedURLs: [String] = []

        for img in selectedImages {
            if let url = try? await ImageStorageService.shared.uploadEventImage(img, eventId: eventId) {
                uploadedURLs.append(url)
            }
        }

        // ③ Firestore に imageURLs を反映
        var updatedEvent = savedEvent
        updatedEvent.imageURLs = uploadedURLs

        // isSecret が nil になる事故防止（iOS17で起きる）
        updatedEvent.isSecret = savedEvent.isSecret

        eventViewModel.updateEventFull(updatedEvent)

        // 保存完了 → カレンダータブへ戻り、そこで「予定を追加しました」を表示する
        isSaving = false
        navState.showToast("予定を追加しました")
        navState.jumpToCalendar()
        dismiss()
    }

    // MARK: - ボタンスタイル
    struct GradientTapStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }

    // MARK: - FlowLayout（必要なら再利用用）
    struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
        let data: Data
        let content: (Data.Element) -> Content

        init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
            self.data = data
            self.content = content
        }

        var body: some View {
            GeometryReader { geometry in
                var width = CGFloat.zero
                var height = CGFloat.zero

                ZStack(alignment: .topLeading) {
                    ForEach(Array(data), id: \.self) { item in
                        content(item)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .alignmentGuide(.leading) { d in
                                if width + d.width > geometry.size.width {
                                    width = 0
                                    height += d.height
                                }
                                let result = width
                                width += d.width
                                return result
                            }
                            .alignmentGuide(.top) { _ in height }
                    }
                }
            }
        }
    }
}
