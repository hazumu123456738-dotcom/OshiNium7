//
//  CalendarSwitcherRow.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI

struct CalendarSwitcherRow: View {
    var calendars: [OshiCalendar]
    var selectedCalendar: OshiCalendar?

    var onSelect: (OshiCalendar) -> Void = { _ in }
    var onAdd: () -> Void = {}
    var onRequestEdit: (OshiCalendar) -> Void = { _ in }

    private let iconSize: CGFloat = 56

    // ★ コミュニティカレンダー専用の豪華なゴールド演出
    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.85, blue: 0.45),
            Color(red: 0.80, green: 0.62, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {

                ForEach(calendars) { calendar in
                    calendarChip(for: calendar)
                        .onTapGesture {
                            onSelect(calendar)
                        }
                        .onLongPressGesture {
                            guard !calendar.isCommunity else { return }
                            onRequestEdit(calendar)
                        }
                }

                Button(action: onAdd) {
                    VStack(spacing: 4) {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(width: iconSize, height: iconSize)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: iconSize * 0.32, weight: .semibold))
                                    .foregroundColor(.gray.opacity(0.6))
                            )

                        Text("追加")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    // MARK: - チップ1つ分

    private func calendarChip(for calendar: OshiCalendar) -> some View {
        let isSelected = selectedCalendar?.id == calendar.id

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(calendar.isCommunity ? AnyShapeStyle(goldGradient) : AnyShapeStyle(fillColor(for: calendar)))
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: calendar.isCommunity ? "crown.fill" : "lock.fill")
                    .font(.system(size: iconSize * 0.34, weight: .semibold))
                    .foregroundColor(.white)
            }
            // ★ コミュニティは常に薄いゴールドの光沢リングをまとい、選択中はさらに強調
            .overlay(
                Circle()
                    .stroke(
                        calendar.isCommunity ? goldGradient : LinearGradient(colors: [.black, .black], startPoint: .top, endPoint: .bottom),
                        lineWidth: calendar.isCommunity ? (isSelected ? 3 : 1.5) : (isSelected ? 2.5 : 0)
                    )
                    .opacity(calendar.isCommunity ? (isSelected ? 1.0 : 0.55) : (isSelected ? 0.85 : 0))
                    .padding(-3)
            )
            .shadow(
                color: calendar.isCommunity ? Color(red: 0.85, green: 0.65, blue: 0.2).opacity(isSelected ? 0.45 : 0.2) : .black.opacity(isSelected ? 0.15 : 0.05),
                radius: calendar.isCommunity ? (isSelected ? 10 : 5) : (isSelected ? 8 : 3),
                y: 2
            )

            Text(calendar.isCommunity ? "コミュニティ" : calendar.name)
                .font(.system(size: 10, weight: (isSelected || calendar.isCommunity) ? .semibold : .medium))
                .foregroundColor(calendar.isCommunity ? Color(red: 0.72, green: 0.55, blue: 0.15) : (isSelected ? .primary : .secondary))
                .lineLimit(1)
                .frame(width: iconSize + 10)
        }
        .contentShape(Rectangle())
    }

    private func fillColor(for calendar: OshiCalendar) -> Color {
        if let hex = calendar.colorHex {
            return Color(hex: hex)
        }
        return Color(red: 0.70, green: 0.55, blue: 0.98)
    }
}
