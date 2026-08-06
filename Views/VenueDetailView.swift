//
//  VenueDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI
import MapKit

// ★ 「会場口コミ」ツールで会場を選んだ先の詳細ページ。会場名・住所・地図・口コミを表示する。
//   会場写真は権利面（無断でのGoogle画像検索・公式サイト画像の転載）を避けるため一切使わない。
//   写真が無くても名前・住所・地図・口コミだけで成立するデザインにする
struct VenueDetailView: View {
    let place: String
    @ObservedObject var venueReportVM: VenueReportViewModel
    let myGroupIds: Set<String>
    let myCategories: Set<GroupCategory>

    @State private var showOtherOshi: Bool
    @State private var locationInfo: VenueLocationInfo?
    @State private var isLoadingLocation = true
    @State private var cameraPosition: MapCameraPosition = .automatic

    private let accentColor = Color.oshiniumPrimary

    init(
        place: String,
        venueReportVM: VenueReportViewModel,
        myGroupIds: Set<String>,
        myCategories: Set<GroupCategory>,
        initialShowOtherOshi: Bool
    ) {
        self.place = place
        self._venueReportVM = ObservedObject(wrappedValue: venueReportVM)
        self.myGroupIds = myGroupIds
        self.myCategories = myCategories
        self._showOtherOshi = State(initialValue: initialShowOtherOshi)
    }

    // ★ 検索結果一覧（EventHubPickerView）と同じ絞り込みルールを、この会場だけに適用する
    private var reviews: [VenueReport] {
        venueReportVM.allReviews
            .filter { report in
                guard (report.place ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == place else { return false }
                if myGroupIds.contains(report.groupId) { return true }
                guard showOtherOshi,
                      let categoryRaw = report.groupCategory,
                      let category = GroupCategory(rawValue: categoryRaw)
                else { return false }
                return myCategories.contains(category)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if let locationInfo {
                    mapCard(locationInfo)
                }

                if !myCategories.isEmpty {
                    otherOshiToggleCard
                }

                reviewsSection
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(place)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            locationInfo = await VenueLocationService.shared.locationInfo(for: place)
            isLoadingLocation = false
            if let coordinate = locationInfo?.coordinate {
                cameraPosition = .region(
                    MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
                )
            }
        }
    }

    // MARK: - 会場名・住所

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [accentColor, Color.oshiniumPrimary2],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image(systemName: "building.2.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(place)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)

                if isLoadingLocation {
                    Text("住所を調べています…")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else if let address = locationInfo?.address {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("住所は見つかりませんでした")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .glossyHighlight(cornerRadius: 20)
    }

    // MARK: - 地図（MapKit・APIキー不要。静的プレビューとして表示するのみ）

    private func mapCard(_ info: VenueLocationInfo) -> some View {
        Map(position: $cameraPosition) {
            Marker(place, coordinate: info.coordinate)
                .tint(accentColor)
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 「他の推しの口コミを見る」トグル

    private var otherOshiToggleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $showOtherOshi) {
                Text("他の推しの口コミを見る")
                    .font(.system(size: 13, weight: .semibold))
            }
            .tint(accentColor)

            let categoryLabel = myCategories.map(\.rawValue).sorted().joined(separator: "・")
            Text("同じカテゴリ（\(categoryLabel)）の口コミも表示します")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - 口コミ一覧

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("口コミ \(reviews.count)件")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)

            if reviews.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text("この会場の口コミはまだありません")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 10) {
                    ForEach(reviews) { report in
                        reviewRow(report)
                    }
                }
            }
        }
    }

    // ★ 匿名投稿のため書いた人は表示しない。参加目的・その回の日付・本文中の#タグだけを添える
    private func reviewRow(_ report: VenueReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let purpose = report.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }
                if let eventDate = report.eventDate {
                    Text(Self.dateFormatter.string(from: eventDate))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                Text(relativeTime(report.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Text(report.text)
                .font(.system(size: 13.5))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            let tags = Self.hashtags(in: report.text)
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accentColor.opacity(0.08)))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }()

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func hashtags(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "#[\\p{L}0-9_]+") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
