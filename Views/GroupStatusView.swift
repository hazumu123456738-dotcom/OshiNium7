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

    @State private var memberCount: Int? = nil
    @State private var isLoading = true
    @State private var showLeaveAlert = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: - グループ画像（中央）
                if let data = group.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .padding(.top, 20)
                }

                // MARK: - グループ名（中央）
                Text(group.name)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)

                Divider()

                // MARK: - 所属ユーザー数
                VStack(spacing: 8) {
                    Text("所属ユーザー数")
                        .font(.headline)

                    if isLoading {
                        ProgressView()
                    } else if let count = memberCount {
                        Text("\(count) 人")
                            .font(.title2)
                            .bold()
                    } else {
                        Text("取得できませんでした")
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // MARK: - イベント数
                VStack(spacing: 8) {
                    Text("イベント数")
                        .font(.headline)

                    Text("\(eventCount()) 件")
                        .font(.title2)
                        .bold()
                }

                Divider()

                // MARK: - 作成日（数字で表示）
                if let created = group.createdAt {
                    VStack(spacing: 8) {
                        Text("作成日")
                            .font(.headline)

                        Text(formatDate(created))
                            .font(.title3)
                    }
                }

                Divider()

                // MARK: - 退出ボタン（確認ダイアログ付き）
                Button(role: .destructive) {
                    showLeaveAlert = true
                } label: {
                    Text("このグループから退出する")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.top, 10)
                .alert("本当に退出しますか？", isPresented: $showLeaveAlert) {
                    Button("退出する", role: .destructive) {
                        leaveGroup()
                    }
                    Button("キャンセル", role: .cancel) {}
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("グループ情報")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchMemberCount()
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
        groupViewModel.deleteGroup(group) { _ in
            dismiss()
        }
    }

    // MARK: - 日付フォーマット（数字のみ）
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
