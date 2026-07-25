//
//  TodayEventRow.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/05.
//

// TodayEventRow.swift
import SwiftUI

struct TodayEventRow: View {
    let event: Event
    let selectedDate: Date
    let isOwner: Bool

    // MARK: - 範囲イベント判定
    func isRangeEvent(_ event: Event) -> Bool {
        if let s = event.startDate, let e = event.endDate {
            return s != e
        }
        return false
    }

    // MARK: - 選択日が範囲内か判定
    func isDate(_ date: Date, inRangeOf event: Event) -> Bool {
        if let s = event.startDate, let e = event.endDate {
            return (s...e).contains(date)
        }
        return Calendar.current.isDate(event.date, inSameDayAs: date)
    }

    // MARK: - 種別色（EventType に完全統一）
    private func color(for type: EventType) -> Color {
        switch type {
        case .live, .event:
            return .red
        case .tv:
            return .green
        case .release:
            return .green
        case .sns:
            return .orange
        case .anniversary:
            return .purple
        case .other:
            return .gray
        }
    }

    var body: some View {

        let type = event.type ?? .other

        VStack(alignment: .leading, spacing: 12) {

            // MARK: - 画像（手動画像 → AI画像 → アイコン）
            imageSection

            // MARK: - 種別タグ
            Text(type.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(type.iconColor.opacity(0.8))
                .clipShape(Capsule())

            // MARK: - タイトル
            HStack(spacing: 6) {
                Text(event.title)
                    .font(.headline)

                if isRangeEvent(event) && isDate(selectedDate, inRangeOf: event) {
                    Text("📘")
                        .font(.caption)
                }
            }

            // MARK: - タグ
            if let tags = event.tags, !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color(for: type).opacity(0.15))
                            .foregroundColor(color(for: type))
                            .cornerRadius(6)
                    }
                }
            }

            // MARK: - 情報カード
            VStack(alignment: .leading, spacing: 8) {

                infoRow(icon: "calendar", title: "日付", value: dateText(event.date))

                if let place = event.place, !place.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", title: "会場", value: place)
                }

                if let start = event.startTime, !start.isEmpty {
                    infoRow(icon: "clock", title: "開演時間", value: start)
                }

                if let price = event.ticketPrice {
                    infoRow(icon: "yensign.circle", title: "チケット", value: price)
                }

                if let start = event.ticketStartDate {
                    infoRow(icon: "ticket", title: "販売開始", value: start)
                }

                infoRow(icon: "globe", title: "情報元", value: event.officialURL ?? "不明")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )

            // MARK: - 情報元リンク
            if let urlString = event.officialURL,
               let url = URL(string: urlString) {
                Link("情報元を見る", destination: url)
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Text("情報はAIによる解析結果です。内容を確認の上ご利用ください。")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - 画像セクション（手動画像 → AI画像 → アイコン）
    @ViewBuilder
    private var imageSection: some View {

        // ★ 1. 手動画像（imageURLs）
        if let manual = event.imageURLs?.first,
           let url = URL(string: manual) {

            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.2)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.2)
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(height: 140)
            .clipped()
            .cornerRadius(12)

        // ★ 2. AI画像（thumbnailURL）
        } else if let ai = event.thumbnailURL,
                  let url = URL(string: ai) {

            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.2)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.2)
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(height: 140)
            .clipped()
            .cornerRadius(12)

        // ★ 3. アイコン（画像なし）
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    Image(systemName: event.type?.iconName ?? "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(event.type?.iconColor ?? .gray)
                )
                .frame(height: 140)
        }
    }

    // MARK: - 情報行
    func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    // MARK: - 日付フォーマット
    func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年 M月d日 (E)"
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }
}
