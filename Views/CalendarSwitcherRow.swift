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
    var onRequestInvite: (OshiCalendar) -> Void = { _ in }

    // ★ fillColor(for:)がColor.themedAccentを参照するための購読(FullCalendarTab.swiftと同じ理由)
    @ObservedObject private var themeManager = ThemeManager.shared

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

    // ★ プライベートカレンダー専用のシルバー演出（コミュニティのゴールドと対になる、
    //   常時設置されている感じを出す控えめな輝き）
    private let silverGradient = LinearGradient(
        colors: [
            Color(white: 0.88),
            Color(white: 0.62)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {

                ForEach(calendars) { calendar in
                    // ★ コミュニティ・プライベートはどちらも常時存在の特別枠で、
                    //   招待・改名・メンバー変更・削除のメニュー自体を出さない
                    if !calendar.isCommunity && !calendar.isPrivate {
                        calendarChip(for: calendar)
                            .onTapGesture {
                                onSelect(calendar)
                            }
                            .contextMenu {
                                Button {
                                    onRequestInvite(calendar)
                                } label: {
                                    Label("招待する", systemImage: "person.badge.plus")
                                }
                                Button {
                                    onRequestEdit(calendar)
                                } label: {
                                    Label("編集する", systemImage: "pencil")
                                }
                            }
                    } else {
                        calendarChip(for: calendar)
                            .onTapGesture {
                                onSelect(calendar)
                            }
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

        // ★ コミュニティ（ゴールド）・プライベート（シルバー）・通常の個人カレンダーの
        //   3種類で見た目を出し分ける。前者2つは「常時設置されている」感を出すため、
        //   未選択時も控えめなリング・影を常にまとわせる
        let fillStyle: AnyShapeStyle = {
            if calendar.isCommunity { return AnyShapeStyle(goldGradient) }
            if calendar.isPrivate { return AnyShapeStyle(silverGradient) }
            return AnyShapeStyle(fillColor(for: calendar))
        }()

        let iconName = calendar.isCommunity ? "crown.fill" : "lock.fill"

        let ringGradient = calendar.isCommunity ? goldGradient
            : calendar.isPrivate ? silverGradient
            : LinearGradient(colors: [.black, .black], startPoint: .top, endPoint: .bottom)

        let isAlwaysPresent = calendar.isCommunity || calendar.isPrivate
        let ringLineWidth: CGFloat = isAlwaysPresent ? (isSelected ? 3 : 1.5) : (isSelected ? 2.5 : 0)
        let ringOpacity: Double = isAlwaysPresent ? (isSelected ? 1.0 : 0.55) : (isSelected ? 0.85 : 0)

        let shadowColor: Color = calendar.isCommunity
            ? Color(red: 0.85, green: 0.65, blue: 0.2).opacity(isSelected ? 0.45 : 0.2)
            : calendar.isPrivate
            ? Color(white: 0.5).opacity(isSelected ? 0.4 : 0.18)
            : .black.opacity(isSelected ? 0.15 : 0.05)
        let shadowRadius: CGFloat = isAlwaysPresent ? (isSelected ? 10 : 5) : (isSelected ? 8 : 3)

        let labelText = calendar.isCommunity ? "コミュニティ" : (calendar.isPrivate ? "プライベート" : calendar.name)
        let labelColor: Color = calendar.isCommunity
            ? Color(red: 0.72, green: 0.55, blue: 0.15)
            : calendar.isPrivate
            ? Color(white: 0.4)
            : (isSelected ? .primary : .secondary)

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(fillStyle)
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: iconName)
                    .font(.system(size: iconSize * 0.34, weight: .semibold))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(ringGradient, lineWidth: ringLineWidth)
                    .opacity(ringOpacity)
                    .padding(-3)
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: 2)

            Text(labelText)
                .font(.system(size: 10, weight: (isSelected || isAlwaysPresent) ? .semibold : .medium))
                .foregroundColor(labelColor)
                .lineLimit(1)
                .frame(width: iconSize + 10)
        }
        .contentShape(Rectangle())
    }

    private func fillColor(for calendar: OshiCalendar) -> Color {
        if let hex = calendar.colorHex {
            return Color(hex: hex)
        }
        return Color.themedAccent
    }
}
