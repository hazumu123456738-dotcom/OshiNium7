//
//  EditEventView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/16.
//

import SwiftUI
import PhotosUI
import UIKit
import FirebaseFirestore
import NukeUI

struct EditEventView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var navState: AppNavigationState
    @ObservedObject var eventViewModel: EventViewModel

    @State var event: Event

    // グループ名だけ表示したいので、呼び出し側から渡す
    let groupName: String

    @State private var appear: Bool = false
    @State private var pageIndex: Int = 0
    @State private var isSaving: Bool = false

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // MARK: - AI用タグ編集用（カンマ区切り）
    private var tagsBinding: Binding<String> {
        Binding(
            get: { (event.tags ?? []).joined(separator: ", ") },
            set: { text in
                let parts = text
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                event.tags = parts.isEmpty ? nil : parts
            }
        )
    }

    // ★ このイベントの種類によって色が変わる（OshiNiumタブと同じ「イベントの色を強く反映する」コンセプト）
    private var accentColor: Color { (event.type ?? .other).iconColor }
    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColor.opacity(0.65)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - 初期化
    init(eventViewModel: EventViewModel, event: Event, groupName: String) {
        self.eventViewModel = eventViewModel
        self._event = State(initialValue: event)
        self.groupName = groupName
    }

    var body: some View {
        ZStack {
            // ★ OshiNiumタブと同じフラットな背景
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                headerView

                TabView(selection: $pageIndex) {

                    // 1ページ目：グループ〜種類
                    ScrollView {
                        VStack(spacing: 10) {
                            groupCard
                            relatedImagesCard
                            titleCard
                            dateCard
                            typeCard
                            pageIndicator
                            nextButton
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .tag(0)

                    // 2ページ目：詳細・AI・公開設定
                    ScrollView {
                        VStack(spacing: 10) {
                            detailCard
                            aiInfoCard
                            secretAndNotifyCard
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.top, 16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appear = true
            }
        }
    }

    // MARK: - ヘッダー（×・イベント編集・修正）
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
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    )
            }
            .disabled(isSaving)

            Spacer()

            // タイトル
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))

                Text("イベントを編集")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)

                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))
            }

            Spacer()

            // 修正ボタン（AddEventView の保存ボタンと同じ挙動）
            Button {
                if !isSaving {
                    saveEvent()
                }
            } label: {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }

                    Text(isSaving ? "修正中…" : "修正")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSaving {
                            Color.gray.opacity(0.6)
                        } else {
                            accentGradient
                        }
                    }
                )
                .clipShape(Capsule())
                .opacity(isSaving ? 0.6 : 1.0)
            }
            .disabled(isSaving)
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

    // MARK: - 登録先グループカード
    private var groupCard: some View {
        cardContainer {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(accentColor)

                VStack(alignment: .leading) {
                    Text("登録先グループ")
                        .font(.system(size: 14, weight: .semibold))
                    Text(groupName)
                        .font(.system(size: 16, weight: .medium))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.7))
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
                        .onChange(of: photoPickerItems) { newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImages.append(uiImage)
                                    }
                                }
                            }
                        }

                        // 既存の imageURLs を表示
                        if let urls = event.imageURLs {
                            ForEach(urls, id: \.self) { urlString in
                                if let url = URL(string: urlString) {
                                    existingImageThumbnail(url: url)
                                }
                            }
                        }

                        // 編集画面で新しく追加した画像
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, img in
                            localImageThumbnail(image: img) {
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

    // MARK: - 新しく選んだ画像のサムネイル
    private func localImageThumbnail(image: UIImage, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
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

    // MARK: - すでにアップロード済みの画像のサムネイル
    private func existingImageThumbnail(url: URL) -> some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 88, height: 88)
                    .clipped()
            } else {
                ZStack {
                    Color(.systemGray5)
                    ProgressView()
                }
                .frame(width: 88, height: 88)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
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

                TextField("イベント名を入力", text: $event.title)
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

                DatePicker(
                    "開始日時",
                    selection: $event.date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - 種類カード
    private var typeCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(accentColor)
                    Text("種類")
                        .font(.system(size: 15, weight: .semibold))
                }

                VStack(spacing: 8) {
                    Picker("大分類", selection: Binding(
                        get: { event.type ?? .other },
                        set: { event.type = $0 }
                    )) {
                        ForEach(EventType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("小分類", selection: Binding(
                        get: { event.subType ?? .other },
                        set: { event.subType = $0 }
                    )) {
                        ForEach((event.type ?? .other).subTypes(), id: \.self) { st in
                            Text(st.displayName).tag(st)
                        }
                        Text("その他").tag(EventSubType.other)
                    }
                    .pickerStyle(.menu)

                    if (event.subType ?? .other) == .other {
                        TextField("カスタム小分類", text: Binding(
                            get: { event.customSubType ?? "" },
                            set: { event.customSubType = $0.isEmpty ? nil : $0 }
                        ))
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - ページインジケータ
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pageIndex == 0 ? accentColor : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Circle()
                .fill(pageIndex == 1 ? accentColor : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
            .background(accentGradient)
            .cornerRadius(28)
        }
        .buttonStyle(GradientTapStyle())
    }

    // MARK: - 詳細カード
    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("場所・詳細")
                .font(.headline)

            cardContainer {
                VStack(alignment: .leading, spacing: 10) {

                    detailField(icon: "mappin.and.ellipse", title: "場所", placeholder: "会場名など", text: Binding(
                        get: { event.place ?? "" },
                        set: { event.place = $0.isEmpty ? nil : $0 }
                    ))

                    detailField(icon: "clock", title: "補足時間", placeholder: "例: 集合時間など", text: Binding(
                        get: { event.timeText ?? "" },
                        set: { event.timeText = $0.isEmpty ? nil : $0 }
                    ))

                    detailField(icon: "person.badge.key", title: "応募条件", placeholder: "例: FC会員限定 など", text: Binding(
                        get: { event.condition ?? "" },
                        set: { event.condition = $0.isEmpty ? nil : $0 }
                    ))

                    detailField(icon: "calendar", title: "応募期間", placeholder: "例: 5/1〜5/10", text: Binding(
                        get: { event.applyDate ?? "" },
                        set: { event.applyDate = $0.isEmpty ? nil : $0 }
                    ))

                    detailField(icon: "tv", title: "放送局", placeholder: "例: 日本テレビ", text: Binding(
                        get: { event.channel ?? "" },
                        set: { event.channel = $0.isEmpty ? nil : $0 }
                    ))

                    detailField(icon: "play.tv", title: "番組名", placeholder: "例: 音楽番組名など", text: Binding(
                        get: { event.programName ?? "" },
                        set: { event.programName = $0.isEmpty ? nil : $0 }
                    ))

                    detailField(icon: "link", title: "URL", placeholder: "関連リンク", text: Binding(
                        get: { event.url ?? "" },
                        set: { event.url = $0.isEmpty ? nil : $0 }
                    ))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("メモ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("自由メモ", text: Binding(
                            get: { event.notes ?? "" },
                            set: { event.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    // MARK: - 詳細フィールド共通UI
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

    // MARK: - AI解析情報カード
    private var aiInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("AI解析情報")
                .font(.headline)

            cardContainer {
                VStack(alignment: .leading, spacing: 10) {

                    field("開場時間", placeholder: "例: 17:00", text: Binding(
                        get: { event.openTime ?? "" },
                        set: { event.openTime = $0.isEmpty ? nil : $0 }
                    ))

                    field("開演時間", placeholder: "例: 18:00", text: Binding(
                        get: { event.startTime ?? "" },
                        set: { event.startTime = $0.isEmpty ? nil : $0 }
                    ))

                    field("終演時間", placeholder: "例: 20:30", text: Binding(
                        get: { event.endTime ?? "" },
                        set: { event.endTime = $0.isEmpty ? nil : $0 }
                    ))

                    field("アクセス", placeholder: "会場までの行き方など", text: Binding(
                        get: { event.access ?? "" },
                        set: { event.access = $0.isEmpty ? nil : $0 }
                    ))

                    field("主催者", placeholder: "主催団体・会社名など", text: Binding(
                        get: { event.organizer ?? "" },
                        set: { event.organizer = $0.isEmpty ? nil : $0 }
                    ))

                    field("問い合わせ先", placeholder: "メール・電話番号など", text: Binding(
                        get: { event.contact ?? "" },
                        set: { event.contact = $0.isEmpty ? nil : $0 }
                    ))

                    field("公式サイトURL（情報元）", placeholder: "公式情報ページ", text: Binding(
                        get: { event.officialURL ?? "" },
                        set: { event.officialURL = $0.isEmpty ? nil : $0 }
                    ))

                    field("サムネイル画像URL", placeholder: "画像URL", text: Binding(
                        get: { event.thumbnailURL ?? "" },
                        set: { event.thumbnailURL = $0.isEmpty ? nil : $0 }
                    ))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("タグ（カンマ区切り）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("例: ライブ, 抽選, 有料", text: tagsBinding)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }

                    field("チケット価格", placeholder: "例: 5,000円", text: Binding(
                        get: { event.ticketPrice ?? "" },
                        set: { event.ticketPrice = $0.isEmpty ? nil : $0 }
                    ))

                    field("チケット販売開始日", placeholder: "例: 5/1 10:00〜", text: Binding(
                        get: { event.ticketStartDate ?? "" },
                        set: { event.ticketStartDate = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
        }
    }

    // MARK: - 共通フィールドUI（ラベル＋TextField）
    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(placeholder, text: text)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(16)
        }
    }

    // MARK: - 秘密イベント & 通知カード
    private var secretAndNotifyCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("表示設定・通知")
                .font(.headline)

            cardContainer {
                VStack(alignment: .leading, spacing: 12) {

                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("秘密イベント")
                                .font(.system(size: 15, weight: .semibold))
                            Text("本人のみ表示")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { event.isSecret ?? false },
                            set: { event.isSecret = $0 }
                        ))
                        .labelsHidden()
                    }

                    ReminderOffsetsEditor(
                        offsets: Binding(
                            get: { event.notifyOffsets ?? [] },
                            set: { event.notifyOffsets = $0.isEmpty ? nil : $0 }
                        ),
                        accentColor: accentColor
                    )
                }
            }
        }
    }

    // MARK: - Firestore 更新処理
    private func saveEvent() {
        guard !isSaving else { return }
        isSaving = true

        print("🔥 EditEventView DEBUG event.id:", event.id as Any)

        guard let id = event.id else {
            print("🔥 EditEventView: event.id が nil（異常）")
            isSaving = false
            return
        }

        let db = Firestore.firestore()
        let collection = (event.isSecret ?? false)
            ? db.collection("privateEvents")
            : db.collection("events")

        var data: [String: Any] = [
            "title": event.title,
            "date": Timestamp(date: event.date),
            "isSecret": event.isSecret ?? false,
            "type": (event.type ?? .other).rawValue,
            "subType": (event.subType ?? .other).rawValue
        ]

        if let v = event.groupId { data["groupId"] = v }
        if let v = event.calendarId { data["calendarId"] = v }
        if let v = event.customSubType { data["customSubType"] = v }
        if let v = event.place { data["place"] = v }
        if let v = event.timeText { data["timeText"] = v }
        if let v = event.condition { data["condition"] = v }
        if let v = event.applyDate { data["applyDate"] = v }
        if let v = event.channel { data["channel"] = v }
        if let v = event.programName { data["programName"] = v }
        if let v = event.url { data["url"] = v }
        if let v = event.notes { data["notes"] = v }
        data["notifyOffsets"] = event.notifyOffsets ?? []

        if let v = event.openTime { data["openTime"] = v }
        if let v = event.startTime { data["startTime"] = v }
        if let v = event.endTime { data["endTime"] = v }
        if let v = event.access { data["access"] = v }
        if let v = event.organizer { data["organizer"] = v }
        if let v = event.contact { data["contact"] = v }
        if let v = event.officialURL { data["officialURL"] = v }
        if let v = event.thumbnailURL { data["thumbnailURL"] = v }
        if let v = event.tags { data["tags"] = v }
        if let v = event.ticketPrice { data["ticketPrice"] = v }
        if let v = event.ticketStartDate { data["ticketStartDate"] = v }
        if let v = event.imageURLs { data["imageURLs"] = v }

        collection.document(id).setData(data, merge: true) { error in
            if let error = error {
                print("🔥 EditEventView: Firestore 更新エラー:", error)
            } else {
                print("✅ EditEventView: Firestore 更新成功")
            }
        }

        NotificationManager.shared.removeNotifications(for: id)
        NotificationManager.shared.scheduleNotifications(
            for: event,
            userMinutesBeforeList: event.notifyOffsets ?? []
        )

        isSaving = false
        navState.showToast("予定を保存しました")
        dismiss()
    }

    // MARK: - ボタンスタイル
    struct GradientTapStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }
}
