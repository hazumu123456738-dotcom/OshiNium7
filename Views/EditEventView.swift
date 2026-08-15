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
import FirebaseAuth
import NukeUI

struct EditEventView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var navState: AppNavigationState
    @ObservedObject var eventViewModel: EventViewModel

    @State var event: Event

    // グループ名だけ表示したいので、呼び出し側から渡す
    let groupName: String

    // ★ 保存直後に「元に戻す」を出せるよう、編集前の内容をそのまま保持しておく
    private let originalEvent: Event

    // ★ 「AI解析情報」カードは、AI予定追加（AIAddEventResultView）経由で作られた予定にだけ
    //   意味のある項目（開場時間・アクセス・チケット価格など）で構成されている。手動作成の予定は
    //   これらの項目自体を入力する画面が無いため、常に空欄のこのカードが出るだけで紛らわしかった。
    //   編集中の変化で急に出たり消えたりしないよう、編集前の状態（originalEvent）で判定する
    private var hasAIOriginData: Bool {
        originalEvent.openTime.nonEmptyOrNil != nil
            || originalEvent.startTime.nonEmptyOrNil != nil
            || originalEvent.endTime.nonEmptyOrNil != nil
            || originalEvent.access.nonEmptyOrNil != nil
            || originalEvent.organizer.nonEmptyOrNil != nil
            || originalEvent.contact.nonEmptyOrNil != nil
            || originalEvent.officialURL.nonEmptyOrNil != nil
            || originalEvent.thumbnailURL.nonEmptyOrNil != nil
            || originalEvent.ticketPrice.nonEmptyOrNil != nil
            || originalEvent.ticketStartDate.nonEmptyOrNil != nil
            || !(originalEvent.tags ?? []).isEmpty
    }

    @State private var appear: Bool = false
    @State private var pageIndex: Int = 0
    @State private var isSaving: Bool = false

    @State private var photoPickerItems: [PhotosPickerItem] = []
    // ★ 2026/08/15：関連画像は1枚までに変更。新しく選び直した画像はこちらに入る
    @State private var selectedImage: UIImage? = nil
    // ★ 元々設定されていた画像をxで消した（＝差し替え待ちの空欄にした）かどうか
    @State private var removedExistingImage: Bool = false

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
        self.originalEvent = event
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
                            if hasAIOriginData {
                                aiInfoCard
                            }
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

                // ★ 2026/08/16修正：画像が無い状態でも「xで消してから選び直してください」と
                //   固定表示していたため、消すべきxが無いのに矛盾した案内になっていた。
                //   状態に関わらず常に成り立つ「追加した画像が、現在の画像と入れ替わって
                //   設定される」という結果の説明に統一する
                Text("イベントのビジュアルを設定（任意・1枚まで）。ここで追加した画像は、現在の画像と入れ替えて設定されます")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                // ★ 2026/08/15：1枚までに変更。表示する画像は優先順に
                //   「新しく選び直した画像」→「元々の画像（xで消していなければ）」→「追加タイル」の1枚だけ
                let existingURL: URL? = removedExistingImage ? nil : event.imageURLs?.first.flatMap(URL.init(string:))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if let selectedImage {
                            localImageThumbnail(image: selectedImage) {
                                self.selectedImage = nil
                                photoPickerItems = []
                            }
                        } else if let existingURL {
                            existingImageThumbnail(url: existingURL) {
                                removedExistingImage = true
                            }
                        } else {
                            PhotosPicker(
                                selection: $photoPickerItems,
                                maxSelectionCount: 1,
                                matching: .images
                            ) {
                                addImageTile
                            }
                            .onChange(of: photoPickerItems) { _, newItems in
                                guard let item = newItems.first else { return }
                                Task {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImage = uiImage
                                    }
                                }
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
    // ★ 2026/08/15修正：以前は削除ボタンが無く、元々設定されていた画像を編集画面から
    //   一切変更できなかった（新しい画像を追加しても、この既存画像と並んで増えるだけだった）
    private func existingImageThumbnail(url: URL, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
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
                            get: { event.isSecret },
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

    private func firestoreData(for event: Event) -> [String: Any] {
        var data: [String: Any] = [
            "title": event.title,
            "date": Timestamp(date: event.date),
            "isSecret": event.isSecret,
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
        return data
    }

    // ★ 2026/08/15追加：コミュニティカレンダーの予定かどうか。個人・共有カレンダーの予定は
    //   calendarIdが特定のカレンダーIDを指すのに対し、コミュニティカレンダーの予定は
    //   calendarId未設定（nil）または"{groupId}_community"になる（firestore.rulesの
    //   isCommunityEventDocと同じ判定）
    private func isCommunityEvent(_ event: Event) -> Bool {
        guard !event.isSecret, let groupId = event.groupId else { return false }
        return event.calendarId == nil || event.calendarId == "\(groupId)_community"
    }

    // ★ save/revert共通の書き込み処理。保存時と「元に戻す」時の両方から使う
    //   ★ 2026/08/15修正：コミュニティカレンダーの予定は、共有ドキュメントの本体フィールドを
    //   直接書き換えると編集した内容が他の全メンバーのカレンダーにもそのまま反映されてしまう
    //   （＝「自分のカレンダーにだけ反映してほしい」という仕様と矛盾する）。そのため
    //   personalEdits.{自分のuid}という自分専用の領域にだけ書き込み、本体フィールドには
    //   触れないようにする（EventViewModel.decodeEventが読み取り時に自分のpersonalEditsを
    //   優先してマージする）。個人・共有カレンダーの予定は元々自分（たち）にしか見えていないため、
    //   従来通り本体フィールドを直接編集する
    private func writeEvent(_ eventToWrite: Event, completion: (() -> Void)? = nil) {
        guard let id = eventToWrite.id else { return }
        let db = Firestore.firestore()
        let collection = eventToWrite.isSecret
            ? db.collection("privateEvents")
            : db.collection("events")

        if isCommunityEvent(eventToWrite), let uid = Auth.auth().currentUser?.uid {
            collection.document(id).updateData([
                "personalEdits.\(uid)": firestoreData(for: eventToWrite)
            ]) { error in
                if let error = error {
                    print("🔥 EditEventView: Firestore 更新エラー(personalEdits):", error)
                } else {
                    print("✅ EditEventView: Firestore 更新成功(personalEdits・自分のカレンダーにのみ反映)")
                }
                completion?()
            }
        } else {
            collection.document(id).setData(firestoreData(for: eventToWrite), merge: true) { error in
                if let error = error {
                    print("🔥 EditEventView: Firestore 更新エラー:", error)
                } else {
                    print("✅ EditEventView: Firestore 更新成功")
                }
                completion?()
            }
        }

        NotificationManager.shared.removeNotifications(for: id)
        NotificationManager.shared.scheduleNotifications(
            for: eventToWrite,
            userMinutesBeforeList: eventToWrite.notifyOffsets ?? []
        )
    }

    // ★ 2026/08/15修正：以前はselectedImages（新しく選び直した画像）を一切アップロードせず
    //   writeEvent(event)をそのまま呼んでいたため、編集画面で新しい画像を選んでも保存後に
    //   何も反映されなかった（プレビュー表示だけで実際には保存されていなかった不具合）。
    //   Storageへのアップロードを待ってからimageURLsを確定させる必要があるため、
    //   保存処理をTask化した
    private func saveEvent() {
        guard !isSaving else { return }
        isSaving = true

        print("🔥 EditEventView DEBUG event.id:", event.id as Any)

        guard let id = event.id else {
            print("🔥 EditEventView: event.id が nil（異常）")
            isSaving = false
            return
        }

        Task {
            var eventToSave = event

            if let selectedImage {
                if let url = try? await ImageStorageService.shared.uploadEventImage(selectedImage, eventId: id) {
                    eventToSave.imageURLs = [url]
                }
            } else if removedExistingImage {
                eventToSave.imageURLs = []
            }

            writeEvent(eventToSave)

            await MainActor.run {
                isSaving = false
                // ★ 保存直後、数秒だけ「元に戻す」を出す。間違えて編集してしまった時に
                //   予定詳細まで戻って再編集し直さなくても、その場で編集前の内容に戻せるようにする
                navState.showToast(
                    "予定を保存しました",
                    actionLabel: "元に戻す",
                    duration: 2
                ) { [originalEvent] in
                    writeEvent(originalEvent)
                }
                dismiss()
            }
        }
    }

    // MARK: - ボタンスタイル
    struct GradientTapStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
        }
    }
}
