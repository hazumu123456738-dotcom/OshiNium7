//
//  EventHubExtrasSheets.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import FirebaseAuth

// ★ 2026/08/20（oshiスキル監査）：EventHubDetailView.swiftが2,592行まで肥大化していたため、
//   すでに独立したstructだったチケット/グッズ/お知らせの一覧・追加シートをこのファイルへ切り出した。
//   EventHubDetailView本体からEventTicketsSheet(...)等として呼ばれるものはprivateを外している

// MARK: - チケット情報の一覧・追加シート（ファン同士で持ち寄る実データ）

struct EventTicketsSheet: View {
    let event: Event
    @ObservedObject var extrasVM: EventHubExtrasViewModel
    let accentColor: Color
    @EnvironmentObject var navState: AppNavigationState

    @Environment(\.dismiss) private var dismiss
    @State private var showAddForm = false

    var body: some View {
        NavigationStack {
            Group {
                if extrasVM.tickets.isEmpty {
                    EventHubExtraEmptyState(icon: "ticket.fill", text: "まだチケット情報がありません", accentColor: accentColor)
                } else {
                    List {
                        ForEach(extrasVM.tickets) { ticket in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(ticket.name)
                                        .font(.system(size: 15, weight: .bold))
                                    Spacer(minLength: 8)
                                    Text(ticket.price)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(accentColor)
                                }
                                if let saleStart = ticket.saleStart, !saleStart.isEmpty {
                                    Text("販売開始: \(saleStart)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                if let note = ticket.note, !note.isEmpty {
                                    Text(note)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                if let urlString = ticket.url, let url = URL(string: urlString) {
                                    Link("購入ページを開く", destination: url)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                if ticket.authorUid == Auth.auth().currentUser?.uid {
                                    Button("削除", role: .destructive) {
                                        extrasVM.deleteTicket(ticket) { error in
                                            if error != nil { navState.showToast("削除できませんでした") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("チケット情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("チケット情報を追加")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddTicketFormView(event: event, extrasVM: extrasVM, accentColor: accentColor)
            }
        }
    }
}

private struct AddTicketFormView: View {
    let event: Event
    @ObservedObject var extrasVM: EventHubExtrasViewModel
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var saleStart = ""
    @State private var note = ""
    @State private var urlString = ""
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !price.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("券種") {
                    TextField("例: 一般指定席", text: $name)
                }
                Section("料金") {
                    TextField("例: ¥8,800", text: $price)
                }
                Section("販売開始（任意）") {
                    TextField("例: 2026/8/1 12:00〜", text: $saleStart)
                }
                Section("メモ（任意）") {
                    TextField("補足事項があれば", text: $note)
                }
                Section("購入ページURL（任意）") {
                    TextField("https://...", text: $urlString)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("チケットを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        guard let uid = Auth.auth().currentUser?.uid else { return }
                        extrasVM.addTicket(
                            eventId: event.id ?? "",
                            groupId: event.groupId ?? "",
                            name: name.trimmingCharacters(in: .whitespaces),
                            price: price.trimmingCharacters(in: .whitespaces),
                            saleStart: saleStart.isEmpty ? nil : saleStart,
                            note: note.isEmpty ? nil : note,
                            url: urlString.isEmpty ? nil : urlString,
                            authorUid: uid
                        ) { error in
                            if error != nil {
                                errorMessage = "保存に失敗しました。もう一度お試しください。"
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

// MARK: - グッズ情報の一覧・追加シート

struct EventGoodsSheet: View {
    let event: Event
    @ObservedObject var extrasVM: EventHubExtrasViewModel
    let accentColor: Color
    @EnvironmentObject var navState: AppNavigationState

    @Environment(\.dismiss) private var dismiss
    @State private var showAddForm = false

    var body: some View {
        NavigationStack {
            Group {
                if extrasVM.goods.isEmpty {
                    EventHubExtraEmptyState(icon: "bag.fill", text: "まだグッズ情報がありません", accentColor: accentColor)
                } else {
                    List {
                        ForEach(extrasVM.goods) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .bold))
                                    Spacer(minLength: 8)
                                    if let price = item.price, !price.isEmpty {
                                        Text(price)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(accentColor)
                                    }
                                }
                                if let note = item.note, !note.isEmpty {
                                    Text(note)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                if item.authorUid == Auth.auth().currentUser?.uid {
                                    Button("削除", role: .destructive) {
                                        extrasVM.deleteGoods(item) { error in
                                            if error != nil { navState.showToast("削除できませんでした") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("グッズ情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("グッズ情報を追加")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddGoodsFormView(event: event, extrasVM: extrasVM, accentColor: accentColor)
            }
        }
    }
}

private struct AddGoodsFormView: View {
    let event: Event
    @ObservedObject var extrasVM: EventHubExtrasViewModel
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var note = ""
    @State private var errorMessage: String?

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("グッズ名") {
                    TextField("例: ペンライト", text: $name)
                }
                Section("価格（任意）") {
                    TextField("例: ¥3,500", text: $price)
                }
                Section("メモ（任意）") {
                    TextField("販売場所・在庫状況など", text: $note)
                }
            }
            .navigationTitle("グッズを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        guard let uid = Auth.auth().currentUser?.uid else { return }
                        extrasVM.addGoods(
                            eventId: event.id ?? "",
                            groupId: event.groupId ?? "",
                            name: name.trimmingCharacters(in: .whitespaces),
                            price: price.isEmpty ? nil : price,
                            note: note.isEmpty ? nil : note,
                            authorUid: uid
                        ) { error in
                            if error != nil {
                                errorMessage = "保存に失敗しました。もう一度お試しください。"
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

// MARK: - 公式お知らせの一覧・追加シート

struct EventAnnouncementsSheet: View {
    let event: Event
    @ObservedObject var extrasVM: EventHubExtrasViewModel
    let accentColor: Color
    @EnvironmentObject var navState: AppNavigationState

    @Environment(\.dismiss) private var dismiss
    @State private var showAddForm = false

    var body: some View {
        NavigationStack {
            Group {
                if extrasVM.announcements.isEmpty {
                    EventHubExtraEmptyState(icon: "megaphone.fill", text: "まだお知らせがありません", accentColor: accentColor)
                } else {
                    List {
                        ForEach(extrasVM.announcements) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .bold))
                                if let body = item.body, !body.isEmpty {
                                    Text(body)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                if let urlString = item.url, let url = URL(string: urlString) {
                                    Link("詳しく見る", destination: url)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                if item.authorUid == Auth.auth().currentUser?.uid {
                                    Button("削除", role: .destructive) {
                                        extrasVM.deleteAnnouncement(item) { error in
                                            if error != nil { navState.showToast("削除できませんでした") }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("公式お知らせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAddForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("お知らせを追加")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddAnnouncementFormView(event: event, extrasVM: extrasVM, accentColor: accentColor)
            }
        }
    }
}

private struct AddAnnouncementFormView: View {
    let event: Event
    @ObservedObject var extrasVM: EventHubExtrasViewModel
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var urlString = ""
    @State private var errorMessage: String?

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var bodyView: some View {
        Form {
            Section("タイトル") {
                TextField("例: 会場変更のお知らせ", text: $title)
            }
            Section("内容（任意）") {
                TextField("詳しい内容", text: $bodyText, axis: .vertical)
                    .lineLimit(3...6)
            }
            Section("関連URL（任意）") {
                TextField("https://...", text: $urlString)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
        }
        .navigationTitle("お知らせを追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    guard let uid = Auth.auth().currentUser?.uid else { return }
                    extrasVM.addAnnouncement(
                        eventId: event.id ?? "",
                        groupId: event.groupId ?? "",
                        title: title.trimmingCharacters(in: .whitespaces),
                        body: bodyText.isEmpty ? nil : bodyText,
                        url: urlString.isEmpty ? nil : urlString,
                        authorUid: uid
                    ) { error in
                        if error != nil {
                            errorMessage = "保存に失敗しました。もう一度お試しください。"
                        } else {
                            dismiss()
                        }
                    }
                }
                .disabled(!canSave)
            }
        }
        .alert("エラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            bodyView
        }
    }
}

// MARK: - 一覧が空のときの共通表示

struct EventHubExtraEmptyState: View {
    let icon: String
    let text: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("右上の＋から追加できます")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
