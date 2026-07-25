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
    
    let selectedGroup: IdolGroup
    
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
    @State private var notifyMinutes: Int? = nil
    
    @State private var selectedImages: [UIImage] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []
    
    @State private var appear = false
    @State private var pageIndex: Int = 0
    @State private var isSaving: Bool = false
    
    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)
    private let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.70, green: 0.55, blue: 0.98),
            Color(red: 0.90, green: 0.60, blue: 0.95)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    init(selectedGroup: IdolGroup, defaultDate: Date) {
        self.selectedGroup = selectedGroup
        self._date = State(initialValue: defaultDate)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                headerView
                
                TabView(selection: $pageIndex) {
                    ScrollView {
                        VStack(spacing: 4.8) {
                            groupCard
                            relatedImagesCard
                            titleCard
                            dateCard
                            typeCard
                            pageIndicator
                            nextButton
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .tag(0)
                    
                    ScrollView {
                        VStack(spacing: 10) {
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
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(backgroundView)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appear = true
            }
        }
    }
    
    // MARK: - 背景
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 36)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.94, blue: 1.0),
                        Color(red: 0.99, green: 0.99, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .blur(radius: 40)
                        .offset(x: -120, y: -180)
                    
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .blur(radius: 60)
                        .offset(x: 140, y: -120)
                }
            )
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
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
                    Task { await saveEvent() }
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
    
    // MARK: - カード共通コンテナ
    private func cardContainer<Content: View>(_ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            
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
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("関連画像")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("イベントのビジュアルを設定（任意）")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        
                        // 画像追加ボタン
                        PhotosPicker(
                            selection: $photoPickerItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(.systemGray4).opacity(0.4))
                                
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [6]))
                                    .foregroundColor(accentColor.opacity(0.4))
                                
                                VStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(accentColor)
                                    Text("画像を追加")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .frame(width: 88, height: 88)
                        }
                        .onChange(of: photoPickerItems, perform: { newItems in
                            Task {
                                for item in newItems {
                                    
                                    // Data で読み込む（PNG / JPEG / HEIC / iCloud 全対応）
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImages.append(uiImage)
                                    }
                                }
                            }
                        })
                        
                        // 選択済み画像の表示
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 88, height: 88)
                                    .clipped()
                                    .cornerRadius(18)
                                
                                Button {
                                    selectedImages.remove(at: index)
                                } label: {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.black)
                                        )
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(accentColor)
                    Text("種類")
                        .font(.system(size: 15, weight: .semibold))
                }
                
                VStack(spacing: 8) {
                    Picker("大分類", selection: $selectedType) {
                        ForEach(EventType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("小分類", selection: $selectedSubType) {
                        ForEach(selectedType.subTypes(), id: \.self) { st in
                            Text(st.displayName).tag(st)
                        }
                        Text("その他").tag(EventSubType.other)
                    }
                    .pickerStyle(.menu)
                    
                    if selectedSubType == .other {
                        TextField("カスタム小分類", text: $customSubType)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onChange(of: selectedType) { newType in
            selectedSubType = newType.subTypes().first ?? .other
            if selectedSubType != .other {
                customSubType = ""
            }
        }
        .onChange(of: selectedSubType) { newSub in
            if newSub != .other {
                customSubType = ""
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
            .background(
                accentGradient
            )
            .cornerRadius(28)
        }
        .buttonStyle(GradientTapStyle())
    }
    
    // MARK: - 場所・詳細＋メモカード
    private var detailAndMemoCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("場所・詳細")
                    .font(.system(size: 15, weight: .semibold))
                
                Group {
                    detailField(icon: "mappin.and.ellipse", title: "場所", text: $place)
                    detailField(icon: "clock", title: "補足時間", text: $timeText)
                    detailField(icon: "person.badge.key", title: "応募条件", text: $condition)
                    detailField(icon: "calendar", title: "応募期間", text: $applyDate)
                    detailField(icon: "tv", title: "放送局", text: $channel)
                    detailField(icon: "play.tv", title: "番組名", text: $programName)
                    detailField(icon: "link", title: "URL", text: $url)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("メモ")
                        .font(.system(size: 15, weight: .semibold))
                    
                    TextEditor(text: $notes)
                        .frame(height: 120)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                }
            }
        }
    }
    
    private func detailField(icon: String, title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            
            TextField("", text: text)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(16)
        }
    }
    
    // MARK: - 秘密イベントカード
    private var secretCard: some View {
        cardContainer {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.purple.opacity(0.8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("秘密イベント")
                        .font(.system(size: 15, weight: .semibold))  // ✅ 正しい
                    Text("本人のみ表示")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isSecret)
                    .labelsHidden()
            }
        }
    }
    
    // MARK: - 通知カード
    private var notifyCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text("通知")
                    .font(.system(size: 15, weight: .semibold))
                
                Picker("通知時間", selection: $notifyMinutes) {
                    Text("通知しない").tag(nil as Int?)
                    Text("5分前").tag(5 as Int?)
                    Text("10分前").tag(10 as Int?)
                    Text("30分前").tag(30 as Int?)
                    Text("1時間前").tag(60 as Int?)
                }
                .pickerStyle(.menu)
            }
        }
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
            notifyBefore: notifyMinutes,
            imageURLs: []
        )
        
        // ① Firestore に保存 → Event を受け取る
        guard let savedEvent = await eventViewModel.addEventReturningEvent(newEvent),
              let eventId = savedEvent.id else {
            isSaving = false
            dismiss()
            return
        }
        
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
        updatedEvent.isSecret = savedEvent.isSecret ?? false
        
        eventViewModel.updateEventFull(updatedEvent)
        
        // 保存完了 → ロック解除して閉じる
        isSaving = false
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
