// TodayEventRow.swift
import SwiftUI

struct TodayEventRow: View {
    let event: Event
    let selectedDate: Date
    let isOwner: Bool

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)

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

    var body: some View {

        let type = event.type ?? .other

        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 8) {
                Text(timeText(event.date))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)

                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(type.iconColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(type.iconColor.opacity(0.12))
                    .clipShape(Capsule())

                if let tags = event.tags, !tags.isEmpty {
                    ForEach(tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))

                if isRangeEvent(event) && isDate(selectedDate, inRangeOf: event) {
                    Text("📘")
                        .font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                infoRow(icon: "calendar", value: dateText(event.date))

                if let place = event.place, !place.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", value: place)
                }

                if let start = event.startTime, !start.isEmpty {
                    infoRow(icon: "clock", value: "開演 \(start)")
                }

                if let price = event.ticketPrice, !price.isEmpty {
                    infoRow(icon: "yensign.circle", value: price)
                }

                if let start = event.ticketStartDate, !start.isEmpty {
                    infoRow(icon: "ticket", value: "販売開始 \(start)")
                }
            }

            if let urlString = event.officialURL,
               let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("情報元を見る")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - 情報行（アイコン＋テキストのみ）
    private func infoRow(icon: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(accentColor)
                .frame(width: 16)

            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.primary)

            Spacer(minLength: 0)
        }
    }

    // MARK: - 日付フォーマット
    func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年 M月d日 (E)"
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }

    // MARK: - 時刻フォーマット
    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
