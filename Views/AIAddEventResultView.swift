//
//  AIAddEventResultView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import SwiftUI
import SafariServices
import NukeUI

struct AIAddEventResultView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.customTabBarHeight) private var customTabBarHeight
    @EnvironmentObject var navState: AppNavigationState

    let result: AIEventResult
    let selectedGroup: IdolGroup?
    let defaultDate: Date
    let imageURL: URL?
    // ★ 呼び出し元（カレンダータブ）で今見ているカレンダーへそのまま保存する。
    //   nilの場合はコミュニティカレンダーへ保存される（AddEventViewのcalendarIdと同じ考え方）
    var calendarId: String? = nil

    // Firestore 保存用
    @ObservedObject var eventVM: EventViewModel

    @State private var showSafari = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    // ★ コミュニティカレンダー（calendarId == nil）に保存する場合のみ、保存ボタンを押した瞬間に確認する。
    //   「今後は表示しない」を選ぶとUserSettingsViewShared.hideCommunityCalendarSaveWarningが
    //   trueになり、以後この確認は出ない（マイページの設定から再度有効化できる）
    @AppStorage(CommunityCalendarSaveWarning.storageKey) private var hideCommunityCalendarSaveWarning = false
    @State private var showCommunitySaveConfirm = false

    // MARK: - カテゴリ判定（tags: [String] 前提）
    private var categoryText: String {
        // tags は [String] 非Optionalなので、そのまま first を取る
        let tag = result.tags.first?.lowercased() ?? ""

        if tag.contains("live") || tag.contains("ライブ") { return "ライブ" }
        if tag.contains("fan") || tag.contains("ミーティング") { return "ファンミーティング" }
        if tag.contains("tv") || tag.contains("テレビ") { return "テレビ" }
        if tag.contains("release") || tag.contains("リリース") { return "リリース" }
        if tag.contains("event") || tag.contains("イベント") { return "イベント" }
        return "イベント"
    }

    private var categoryColor: Color {
        switch categoryText {
        case "ライブ": return Color.blue
        case "ファンミーティング": return Color.pink
        case "リリース": return Color.purple
        default: return Color.orange
        }
    }

    private var groupName: String {
        selectedGroup?.name ?? "イベント"
    }

    private var eventTitle: String {
        if result.title.hasPrefix(groupName) {
            return result.title
                .replacingOccurrences(of: groupName, with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        return result.title
    }

    private var descriptionText: String { "" }

    private var infoSourceName: String {
        guard let urlString = result.officialURL,
              let url = URL(string: urlString),
              let host = url.host else {
            return "公式サイト"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var officialURL: URL? {
        guard let urlString = result.officialURL else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - 画像エリア
                    ZStack(alignment: .top) {
                        GeometryReader { geo in
                            let width = geo.size.width
                            let height = width * 0.6

                            ZStack(alignment: .bottom) {
                                if let url = imageURL {
                                    LazyImage(url: url) { state in
                                        if let image = state.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: width, height: height)
                                                .clipped()
                                        } else {
                                            placeholderGradient(width: width, height: height)
                                        }
                                    }
                                } else {
                                    placeholderGradient(width: width, height: height)
                                }

                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.0),
                                        Color.black.opacity(0.35),
                                        Color.black.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: height)
                            }
                            .frame(width: width, height: height)
                        }
                        .frame(height: UIScreen.main.bounds.width * 0.6)

                        // ナビゲーション（戻る・共有）
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .semibold))
                                    )
                            }
                            .accessibilityLabel("閉じる")

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // MARK: - 情報エリア
                    VStack(alignment: .leading, spacing: 20) {

                        // 種別タグ
                        Text(categoryText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    colors: [
                                        categoryColor,
                                        categoryColor.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())

                        // グループ名 & タイトル
                        VStack(alignment: .leading, spacing: 4) {
                            Text(groupName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)

                            Text(eventTitle)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !descriptionText.isEmpty {
                            Text(descriptionText)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }

                        // イベント情報カード
                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(icon: "calendar", title: "日付", value: result.dateString)

                            if let place = result.location, !place.isEmpty {
                                infoRow(icon: "mappin.and.ellipse", title: "会場", value: place)
                            }

                            if let start = result.startTime, !start.isEmpty {
                                infoRow(icon: "clock", title: "開演時間", value: start)
                            }

                            infoRow(icon: "globe", title: "情報元", value: infoSourceName)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.appCardBackground)
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        )

                        // 情報元リンク
                        if let url = officialURL {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("情報元")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)

                                Button {
                                    showSafari = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "safari")
                                            .font(.system(size: 14))
                                        Text(infoSourceName)
                                            .font(.system(size: 14))
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.oshiniumPrimary)
                                }
                            }
                            .sheet(isPresented: $showSafari) {
                                SafariView(url: url)
                            }
                        }

                        Text("情報はAIによる解析結果です。内容を確認の上ご利用ください。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 8)

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }

            // MARK: - 下部固定ボタン
            VStack(spacing: 6) {
                Divider()

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }

                Button {
                    if calendarId != nil || hideCommunityCalendarSaveWarning {
                        Task { await handleSave() }
                    } else {
                        showCommunitySaveConfirm = true
                    }
                } label: {
                    ZStack {
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 56)
                        .cornerRadius(28)

                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSaving ? "保存中..." : "予定を保存する")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                .padding(.horizontal, 20)
                // ★ このNavigationStackは自作の下タブバー分の安全域を引き継がないため、
                //   環境値で受け取ったタブバーの高さを明示的に足して、タブバーの裏に
                //   隠れないようにする
                .padding(.bottom, 12 + customTabBarHeight)
            }
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
        .confirmationDialog(
            "この予定はコミュニティカレンダーに保存されます。よろしいでしょうか？",
            isPresented: $showCommunitySaveConfirm,
            titleVisibility: .visible
        ) {
            Button("はい、確認済みです") {
                Task { await handleSave() }
            }
            Button("今後はこの確認を表示しない") {
                hideCommunityCalendarSaveWarning = true
                Task { await handleSave() }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - 保存処理本体（カレンダー + Firestore）
    private func handleSave() async {
        guard !isSaving else { return }
        isSaving = true
        saveErrorMessage = nil

        // 1. カレンダー許可
        let granted = await EventKitManager.shared.requestAccess()

        // 2. 日付パース
        let year = Calendar.current.component(.year, from: defaultDate)
        let dates = result.parsedDates(defaultYear: year)

        guard let startDate = dates.first else {
            print("❌ 日付パース失敗 dateString=\(result.dateString)")
            isSaving = false
            saveErrorMessage = "日付を解析できませんでした"
            return
        }

        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate

        // 3. カレンダー追加
        if granted {
            do {
                try EventKitManager.shared.addEvent(
                    title: result.title,
                    startDate: startDate,
                    endDate: endDate,
                    location: result.location
                )
                print("📅 カレンダー追加成功")
            } catch {
                print("❌ カレンダー追加失敗:", error.localizedDescription)
            }
        } else {
            print("⚠️ カレンダー許可なし → Firestore のみ保存")
        }

        // 4. Firestore 保存
        let finalGroupId = result.groupId ?? selectedGroup?.id

        // ★ AI の tags から EventType を推定（最重要）
        let (eventType, eventSubType) = eventVM.inferType(from: result)

        let event = Event(
            id: nil,
            title: result.title,
            date: startDate,
            startDate: nil,
            endDate: nil,
            isSecret: false,
            groupId: finalGroupId,
            calendarId: calendarId,
            type: eventType,            // ← ★ Enum をそのまま渡す
            subType: eventSubType,      // ← ★ ここも Enum
            customSubType: nil,
            place: result.location,
            timeText: nil,
            condition: nil,
            applyDate: nil,
            channel: nil,
            programName: nil,
            url: result.officialURL ?? result.thumbnailURL,
            notes: nil,
            notifyOffsets: nil,
            openTime: result.openTime,
            startTime: result.startTime,
            endTime: result.endTime,
            access: result.access,
            organizer: result.organizer,
            contact: result.contact,
            officialURL: result.officialURL,
            thumbnailURL: result.thumbnailURL,
            tags: result.tags,
            ticketPrice: result.ticketPrice,
            ticketStartDate: result.ticketStartDate
        )

        guard let saved = await eventVM.addEventReturningEvent(event) else {
            print("🔥 Firestore 保存に失敗しました")
            isSaving = false
            saveErrorMessage = "保存に失敗しました。もう一度お試しください"
            return
        }
        print("✅ Firestore 保存処理完了 id:", saved.id ?? "nil")

        // 保存完了 → カレンダータブへ戻り、そこで「予定を追加しました」を表示する
        isSaving = false
        navState.showToast("予定を追加しました")
        navState.jumpToCalendar()
    }

    // MARK: - サブビュー

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    private func placeholderGradient(width: CGFloat, height: CGFloat) -> some View {
        LinearGradient(
            colors: [
                categoryColor.opacity(0.9),
                categoryColor.opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: width, height: height)
    }
}

// MARK: - SafariView ラッパー

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
