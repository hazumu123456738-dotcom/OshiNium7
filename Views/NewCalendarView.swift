//
//  NewCalendarView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI

struct NewCalendarView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var groupViewModel: GroupViewModel
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    let groupId: String
    let ownerId: String
    let calendarViewModel: CalendarViewModel
    var onCreated: (OshiCalendar) -> Void = { _ in }

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#B38CFA"
    @State private var selectedMemberIds: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showLimitReachedAlert = false
    @State private var showPremiumUpgrade = false

    private let colorOptions: [String] = [
        "#B38CFA", "#F2A6C4", "#7FD1AE", "#8FB8F6", "#F6C177", "#EF9A9A"
    ]

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ★ この画面自体が「何のためのカレンダーか」を一目で伝える案内カード。
                    //   以前は各項目のラベルだけが並び、初めて開いた人には目的が伝わりにくかった
                    introCard

                    // ★ 2026/08/14追加：以前は上限に達してから初めてアラートで知らされていたため、
                    //   「せっかく名前やメンバーを入力したのに、保存しようとしたら弾かれた」という
                    //   体験になっていた。作成前の時点で見出しとして明示し、心構えできるようにする
                    recreatePolicyNotice

                    // MARK: - 名前
                    sectionCard(title: "カレンダー名") {
                        TextField("例）仲良しグループ", text: $name)
                            .font(.system(size: 15))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                    }

                    // MARK: - 差し色
                    sectionCard(title: "カレンダーカラー") {
                        HStack(spacing: 14) {
                            ForEach(colorOptions, id: \.self) { hex in
                                let isSelected = selectedColorHex == hex
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(accentColor, lineWidth: isSelected ? 2.5 : 0)
                                            .padding(-3.5)
                                    )
                                    .shadow(color: Color(hex: hex).opacity(isSelected ? 0.5 : 0), radius: 6, x: 0, y: 2)
                                    .onTapGesture {
                                        withAnimation(.easeOut(duration: 0.15)) { selectedColorHex = hex }
                                    }
                                    .accessibilityLabel("カレンダーカラーを選択")
                                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    // MARK: - メンバー招待
                    sectionCard(
                        title: "招待するメンバー",
                        caption: "同じグループに参加しているメンバーだけを招待できます。"
                    ) {
                        memberList
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("個人カレンダーを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "作成中…" : "作成") {
                        createCalendar()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            groupViewModel.fetchMembers(for: groupId)
        }
        // ★ 上限系のエラー(作成上限・作り直しレート制限)だけは、テキスト表示に加えて
        //   「サブスクに入ると解放されます」の導線をその場で見せる。プレミアム画面自体を
        //   開かせることで、実際にどう見た目が変わるか(宇宙・きらきら演出)も体験してもらう
        .alert("上限に達しました", isPresented: $showLimitReachedAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    // MARK: - 案内カード（この画面が何のための場所かを最初に伝える）

    private var introCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, Color.oshiniumPrimary2],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)

            Text("推し活仲間との予定だけをまとめる、あなた専用のカレンダーです。招待した相手とだけ共有され、他のメンバーには見えません。")
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ 「削除してすぐ作り直す」を無制限に繰り返せてしまうと上限の意味が無くなるため、
    //   一定期間内の作り直し回数を制限している。この見出しで、作成前の時点から
    //   「削除・作り直しには回数制限がある」ことを明示しておく
    private var recreatePolicyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("削除・作り直しには回数制限があります")
                    .font(.system(size: 12.5, weight: .semibold))
                Text(
                    subscriptionManager.isPremium
                        ? "プレミアム会員は\(SubscriptionLimits.calendarRecreateWindowDays)日間に\(subscriptionManager.calendarRecreateLimit)回まで、カレンダーを削除して作り直せます。"
                        : "無料会員は\(SubscriptionLimits.calendarRecreateWindowDays)日間に\(subscriptionManager.calendarRecreateLimit)回まで、カレンダーを削除して作り直せます（プレミアム会員は\(SubscriptionLimits.calendarRecreateLimit(isPremium: true))回まで）。"
                )
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
    }

    // ★ 「カレンダー名」「カレンダーカラー」「招待するメンバー」を、アプリ共通の
    //   白いカード+影のスタイルに統一する共通コンテナ
    private func sectionCard<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - メンバーリスト

    private var memberList: some View {
        let invitable = groupViewModel.members.filter { $0.uid != ownerId }

        return VStack(spacing: 0) {
            if invitable.isEmpty {
                Text("招待できるメンバーがまだいません。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            } else {
                ForEach(invitable) { member in
                    memberRow(member)
                    if member.id != invitable.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private func memberRow(_ member: GroupMember) -> some View {
        let isSelected = selectedMemberIds.contains(member.uid)

        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if isSelected {
                    selectedMemberIds.remove(member.uid)
                } else {
                    selectedMemberIds.insert(member.uid)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.7), Color.oshiniumPrimary2.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(member.displayName.prefix(1)))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    )

                Text(member.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? accentColor : .gray.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - 作成処理

    private func createCalendar() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        calendarViewModel.createPersonalCalendar(
            name: trimmed,
            groupId: groupId,
            ownerId: ownerId,
            memberIds: Array(selectedMemberIds),
            colorHex: selectedColorHex
        ) { result in
            isSaving = false
            switch result {
            case .success(let calendar):
                onCreated(calendar)
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
                if error is CalendarError {
                    showLimitReachedAlert = true
                }
            }
        }
    }
}
