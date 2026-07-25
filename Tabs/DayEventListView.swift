//
//  DayEventListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/25.
//

import SwiftUI

struct DayEventListView: View {

    let date: Date
    let selectedGroup: IdolGroup
    let onSelect: (Event) -> Void   // ★ ここが追加

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @State private var imageURLs: [String: URL] = [:]

    @State private var showAddMethodSelect = false
    @State private var showManualAdd = false
    @State private var showAIAdd = false

    // MARK: - 選択日のイベント（選択グループでフィルタ）
    private var eventsForDay: [Event] {
        let key = Calendar.current.startOfDay(for: date)
        let allEvents = eventViewModel.eventsByDate[key] ?? []
        return allEvents.filter { $0.groupId == selectedGroup.id }
    }

    // MARK: - 色ルール
    private func color(for type: EventType?) -> Color {
        switch type ?? .other {
        case .live, .event: return .red
        case .tv: return .green
        case .release: return .blue
        case .sns: return .orange
        case .anniversary: return .purple
        case .other: return .gray
        }
    }

    private func typeName(for type: EventType?) -> String {
        switch type ?? .other {
        case .live: return "ライブ"
        case .event: return "イベント"
        case .tv: return "出演・放送"
        case .release: return "リリース"
        case .sns: return "SNS"
        case .anniversary: return "記念日"
        case .other: return "その他"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // MARK: - イベントなし
                if eventsForDay.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.7))

                        Text("この日の予定はありません。")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 60)

                // MARK: - イベントあり
                } else {
                    ForEach(eventsForDay) { event in
                        Button {
                            onSelect(event)
                        } label: {
                            eventRow(for: event)
                        }
                        .buttonStyle(.plain)
                        .task {
                            await loadImageIfNeeded(for: event)
                        }
                    }

                    Spacer(minLength: 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle(date.formatted(.dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)

        // ★ ここから下の遷移は「追加用の sheet」だけ残す

        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddMethodSelect = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            }
        }

        .sheet(isPresented: $showAddMethodSelect) {
            AddMethodSelectView(
                onSelectAI: {
                    showAddMethodSelect = false
                    showAIAdd = true
                },
                onSelectManual: {
                    showAddMethodSelect = false
                    showManualAdd = true
                }
            )
        }

        .sheet(isPresented: $showManualAdd) {
            NavigationStack {
                AddEventView(
                    selectedGroup: selectedGroup,
                    defaultDate: date
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            }
        }

        .sheet(isPresented: $showAIAdd) {
            NavigationStack {
                AIAddEventView(
                    selectedGroup: selectedGroup,
                    defaultDate: date
                )
                .environmentObject(eventViewModel)
                .environmentObject(settingsVM)
            }
        }
    }

    // MARK: - カードUI
    private func eventRow(for event: Event) -> some View {
        HStack(spacing: 14) {

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))

                if let id = event.id,
                   let url = imageURLs[id] {

                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().scaleEffect(0.8)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 150)
                                .clipped()

                        case .failure:
                            placeholder(for: event)

                        @unknown default:
                            placeholder(for: event)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                } else {
                    placeholder(for: event)
                }
            }
            .frame(width: 110, height: 150)

            VStack(alignment: .leading, spacing: 8) {

                Text(typeName(for: event.type))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(color(for: event.type)))

                Text(eventViewModel.group(for: event.groupId ?? "")?.name ?? "イベント")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer().frame(height: 6)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(event.date.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                if let place = event.place {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(place)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.trailing, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private func placeholder(for event: Event) -> some View {
        ZStack {
            LinearGradient(
                colors: [color(for: event.type).opacity(0.7),
                         color(for: event.type).opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                Text(typeName(for: event.type))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .frame(width: 110, height: 150)
    }

    private func loadImageIfNeeded(for event: Event) async {

        guard let id = event.id else { return }
        if imageURLs[id] != nil { return }

        if let urls = event.imageURLs,
           let first = urls.first,
           let directURL = URL(string: first) {

            DispatchQueue.main.async {
                imageURLs[id] = directURL
            }
            return
        }

        guard let urlString = event.officialURL else { return }

        EventImageFetcher.fetchImageURL(from: urlString) { url in
            guard let url else { return }
            DispatchQueue.main.async {
                imageURLs[id] = url
            }
        }
    }
}
