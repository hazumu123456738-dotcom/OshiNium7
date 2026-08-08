//
//  DeletedEventDetailView.swift
//  OshiNium7
//

import SwiftUI

// ★ 「削除した予定」一覧からタップした時に開く読み取り専用の詳細画面。
//   EventDetailViewは編集・削除ボタンを持つ前提の作りで、削除済み(deletedAt有り)の
//   ドキュメントに対してそれらを使うと壊れるため、あえて別に軽量な読み取り専用ビューとして作る
struct DeletedEventDetailView: View {
    let event: Event
    let onRestore: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false

    private var eventColor: Color {
        event.type?.iconColor ?? Color.oshiniumPrimary
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日（E） H:mm"
        return formatter.string(from: event.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    infoCard {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(eventColor)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("日時")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(dateText)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Spacer()
                        }
                    }

                    infoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("場所・詳細")
                                .font(.system(size: 15, weight: .semibold))
                            detailRow(icon: "mappin.and.ellipse", title: "場所", value: event.place)
                            detailRow(icon: "clock", title: "補足時間", value: event.timeText)
                            detailRow(icon: "link", title: "URL", value: event.url)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("メモ")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(event.notes?.isEmpty == false ? event.notes! : "未設定")
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    restoreButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("削除した予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: event.type?.iconName ?? "star")
                    .foregroundColor(eventColor)
                Text(event.type?.displayName ?? "予定")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("削除済み")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red.opacity(0.75)))
            }
            Text(event.title)
                .font(.system(size: 20, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var restoreButton: some View {
        Button {
            isRestoring = true
            onRestore()
        } label: {
            HStack {
                if isRestoring {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.uturn.backward")
                    Text("この予定を復元する")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(eventColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isRestoring)
        .padding(.top, 4)
    }

    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
    }

    private func detailRow(icon: String, title: String, value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(value)
                            .font(.system(size: 13, weight: .medium))
                    }
                    Spacer()
                }
            }
        }
    }
}
