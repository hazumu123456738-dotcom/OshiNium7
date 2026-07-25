//
//  EventDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/16.
//

import SwiftUI

struct EventDetailView: View {
    let event: Event
    let isOwner: Bool
    @ObservedObject var eventViewModel: EventViewModel

    @Namespace private var animation
    @State private var isEditing: Bool = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - イベントカラー（種類別）
    private var eventColor: Color {
        event.type?.iconColor ?? .gray
    }

    // MARK: - 日付＋曜日＋時刻
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日（E） H:mm"
        return formatter.string(from: event.date)
    }

    // MARK: - グループ名（未設定フォールバック）
    private var groupName: String {
        let name = eventViewModel.groupName(for: event.groupId)
        return name.isEmpty ? "未設定" : name
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(hex: "#FAFAFC")
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {

                    // ① Hero画像カード
                    heroCard

                    // ② 日時カード
                    infoCard {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(eventColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("日時")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(dateText)
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Spacer()
                        }
                    }

                    // ③ 登録先グループカード
                    infoCard {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(eventColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("登録先グループ")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(groupName)
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Spacer()
                        }
                    }

                    // ④ 種類カード
                    infoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: event.type?.iconName ?? "star")
                                    .foregroundColor(eventColor)
                                Text("種類")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("大分類")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(event.type?.displayName ?? "未設定")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("小分類")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(event.subType?.displayName ?? "未設定")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }

                            if let custom = event.customSubType, !custom.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("カスタム小分類")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(custom)
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                        }
                    }

                    // ⑤ 詳細情報カード（場所・詳細＋メモ）
                    infoCard {
                        VStack(alignment: .leading, spacing: 12) {

                            Text("場所・詳細")
                                .font(.system(size: 15, weight: .semibold))

                            detailRow(icon: "mappin.and.ellipse", title: "場所", value: event.place)
                            detailRow(icon: "clock", title: "補足時間", value: event.timeText)
                            detailRow(icon: "person.badge.key", title: "応募条件", value: event.condition)
                            detailRow(icon: "calendar", title: "応募期間", value: event.applyDate)
                            detailRow(icon: "tv", title: "放送局", value: event.channel)
                            detailRow(icon: "play.tv", title: "番組名", value: event.programName)
                            detailRow(icon: "link", title: "URL", value: event.url, isLink: true)

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

                    // ⑥ 秘密イベントカード
                    if event.isSecret {
                        infoCard {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(eventColor)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("秘密イベント")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("本人のみ表示されるイベントです")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                    }

                    // ⑦ 通知カード
                    infoCard {
                        HStack(spacing: 8) {
                            Image(systemName: "bell")
                                .foregroundColor(eventColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("通知")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(notificationText(from: event.notifyBefore))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomButtons
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(
                    Color(hex: "#FAFAFC")
                        .opacity(0.95)
                )
        }
        .fullScreenCover(isPresented: $isEditing) {
            EditEventView(
                eventViewModel: eventViewModel,
                event: event,
                groupName: groupName
            )
        }
    }

    // MARK: - Hero画像カード（画像なし時は色＋アイコン）
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {

            if let urls = event.imageURLs,
               let first = urls.first,
               let url = URL(string: first) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackHeroBackground
                    }
                }
            } else {
                fallbackHeroBackground
            }

            VStack(alignment: .leading, spacing: 8) {
                if let type = event.type {
                    Text(type.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(eventColor.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }

                Text(event.title.isEmpty ? "未設定" : event.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let type = event.type {
                        pillTag(text: type.displayName)
                    }
                    if let sub = event.subType {
                        pillTag(text: sub.displayName)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - 画像なし時の背景
    private var fallbackHeroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    eventColor.opacity(0.85),
                    eventColor.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))

                Text(event.type?.displayName ?? "イベント")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
    }

    // MARK: - 共通カード
    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

            content()
                .padding(12)
        }
    }

    // MARK: - 詳細行
    private func detailRow(icon: String, title: String, value: String?, isLink: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(eventColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if let v = value, !v.isEmpty {
                    if isLink {
                        Text(v)
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text(v)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("未設定")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            Spacer()
        }
        .frame(height: 40)
    }

    // MARK: - タグピル
    private func pillTag(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(eventColor.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    // MARK: - 通知テキスト
    private func notificationText(from minutes: Int?) -> String {
        guard let m = minutes else { return "通知しない" }
        switch m {
        case 5: return "5分前"
        case 10: return "10分前"
        case 30: return "30分前"
        case 60: return "1時間前"
        default: return "\(m)分前"
        }
    }

    // MARK: - 下部ボタン
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            if isOwner {
                Button {
                    isEditing = true
                } label: {
                    Text("編集")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    eventColor.opacity(0.95),
                                    eventColor.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                Button {
                    eventViewModel.deleteEvent(event)
                    dismiss()
                } label: {
                    Text("削除")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.95),
                                    Color.pink.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            } else {
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.9),
                                    Color.gray.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Hexカラー簡易拡張
extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
