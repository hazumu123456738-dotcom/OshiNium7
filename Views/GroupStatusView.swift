//
//  GroupStatusView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/12.
//

import SwiftUI

struct GroupStatusView: View {

    let group: IdolGroup

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var navState: AppNavigationState

    @State private var memberCount: Int? = nil
    @State private var isLoading = true
    @State private var showLeaveAlert = false

    @Environment(\.dismiss) var dismiss

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                heroCard
                statsCard
                createdAtCard
                leaveButton
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("グループ情報")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchMemberCount()
        }
    }

    // MARK: - Heroカード（推しグループ本体と統一した高級感のあるバナー）
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = group.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackHero
            }

            LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0.0)],
                startPoint: .bottom,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("推しグループ")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.22))
                .clipShape(Capsule())

                Text(group.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(20)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: accentColor.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    private var fallbackHero: some View {
        ZStack {
            LinearGradient(
                colors: [accentColor.opacity(0.85), Color.oshiniumPrimary2.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(group.name.prefix(1)))
                .font(.system(size: 70, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    // MARK: - 統計カード（所属ユーザー数・イベント数）
    private var statsCard: some View {
        infoCard {
            HStack(spacing: 0) {
                statColumn(
                    icon: "person.2.fill",
                    isLoading: isLoading,
                    value: memberCount.map { "\($0)" } ?? "-",
                    label: "所属ユーザー数"
                )
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1, height: 44)

                statColumn(
                    icon: "calendar.badge.clock",
                    isLoading: false,
                    value: "\(eventCount())",
                    label: "イベント数"
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func statColumn(icon: String, isLoading: Bool, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accentColor)

            if isLoading {
                ProgressView()
            } else {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
            }

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 作成日カード
    private var createdAtCard: some View {
        infoCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("作成日")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(group.createdAt.map(formatDate) ?? "不明")
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 退出ボタン（確認ダイアログ付き）
    private var leaveButton: some View {
        Button(role: .destructive) {
            showLeaveAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                Text("このグループから退出する")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(.top, 4)
        .alert("本当に退出しますか？", isPresented: $showLeaveAlert) {
            Button("退出する", role: .destructive) {
                leaveGroup()
            }
            Button("キャンセル", role: .cancel) {}
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

    // MARK: - Firestore から所属人数を取得
    private func fetchMemberCount() {
        isLoading = true

        groupViewModel.fetchMemberCount(for: group.id) { count in
            self.memberCount = count
            self.isLoading = false
        }
    }

    // MARK: - イベント数をカウント
    private func eventCount() -> Int {
        eventViewModel.events.filter { $0.groupId == group.id }.count
    }

    // MARK: - グループ退出処理
    private func leaveGroup() {
        groupViewModel.deleteGroup(group) { error in
            // ★ ユーザー要望：退出後に何も表示されず、画面が閉じるだけだったため
            //   「グループを退出しました」を伝える。エラーも握りつぶさず、
            //   失敗時は画面を閉じずに再試行できるようにする
            if let error {
                CrashReportManager.recordNonFatal(error)
                navState.showToast("退出できませんでした。もう一度お試しください")
                return
            }
            navState.showToast("グループを退出しました")
            dismiss()
        }
    }

    // MARK: - 日付フォーマット
    private func formatDate(_ date: Date) -> String {
        return CachedFormatters.date(format: "yyyy/MM/dd HH:mm").string(from: date)
    }
}
