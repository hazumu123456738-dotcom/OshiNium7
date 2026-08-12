//
//  TodayEventsSection.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import SwiftUI

struct TodayEventsSection: View {
    let title: String
    let events: [Event]
    let isOwner: Bool
    @ObservedObject var eventViewModel: EventViewModel
    @EnvironmentObject var navState: AppNavigationState

    @Binding var isExpanded: Bool
    let selectedDate: Date

    // MARK: - 種別色
    private func color(for type: EventType) -> Color {
        switch type {
        case .live, .event: return .red
        case .tv: return .green
        case .release: return .blue
        case .sns: return .orange
        case .anniversary: return .purple
        case .other: return .gray
        }
    }

    private func gradientColors(for type: EventType) -> [Color] {
        let base = color(for: type)
        return [base.opacity(0.95), base.opacity(0.55)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(title)
                .font(.headline)
                .padding(.horizontal)

            if events.isEmpty {
                Text("予定はありません")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .padding(.horizontal)

            } else {

                let displayedEvents = isExpanded ? events : Array(events.prefix(3))

                VStack(alignment: .leading, spacing: 16) {

                    ForEach(displayedEvents) { event in
                        if event.isSecret && !isOwner {
                            EmptyView()
                        } else {
                            NavigationLink(
                                destination: EventDetailView(
                                    event: event,
                                    isOwner: isOwner,
                                    eventViewModel: eventViewModel
                                )
                            ) {
                                eventCard(event)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    eventViewModel.deleteEvent(event)
                                    navState.showToast("予定を削除しました")
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }

                    if events.count > 3 {
                        Button {
                            withAnimation(.easeInOut) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Text(isExpanded ? "閉じる" : "予定をすべて見る")
                                .font(.caption)
                                .foregroundColor(.oshiniumPrimary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - イベントカード（完全修正版）
    @ViewBuilder
    func eventCard(_ event: Event) -> some View {
        let type = event.type ?? .other
        let grad = gradientColors(for: type)

        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: grad,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 10) {

                // 種類タグ
                Text(type.displayName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                // タイトル
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                // 日付
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                    Text(dateText(event.date))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.95))
                }

                // 場所
                if let place = event.place, !place.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                        Text(place)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 日付フォーマット
    func dateText(_ date: Date) -> String {
        CachedFormatters.date(format: "yyyy年 M月d日 (E)").string(from: date)
    }
}
