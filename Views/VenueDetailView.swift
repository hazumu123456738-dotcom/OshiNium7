//
//  VenueDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI
import MapKit
import NukeUI

// ★ 「会場口コミ」ツールで会場を選んだ先の詳細ページ。会場名・住所・地図・口コミを表示する。
//   会場写真は権利面（無断でのGoogle画像検索・公式サイト画像の転載）を避けるため一切使わない。
//   写真が無くても名前・住所・地図・口コミだけで成立するデザインにする
struct VenueDetailView: View {
    let place: String
    @ObservedObject var venueReportVM: VenueReportViewModel
    let myGroupIds: Set<String>
    let myCategories: Set<GroupCategory>
    // ★ このツールから直接口コミを書けるようにするための「投稿者としてのグループ」。
    //   nilなら（グループ未選択などで）書き込みボタンを出さない
    let writeGroup: IdolGroup?

    @State private var showOtherOshi: Bool
    @State private var locationInfo: VenueLocationInfo?
    @State private var isLoadingLocation = true
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedTagFilter: String? = nil
    @State private var showComposer = false
    // ★ 会場口コミは匿名投稿でありながら通報導線が無かったため新設。ModerationServiceの
    //   既存パターン（ReportComposerSheet）をそのまま流用する
    @State private var reportTarget: VenueReport?
    @State private var showReportThanks = false

    private let accentColor = Color.oshiniumPrimary

    init(
        place: String,
        venueReportVM: VenueReportViewModel,
        myGroupIds: Set<String>,
        myCategories: Set<GroupCategory>,
        initialShowOtherOshi: Bool,
        writeGroup: IdolGroup? = nil
    ) {
        self.place = place
        self._venueReportVM = ObservedObject(wrappedValue: venueReportVM)
        self.myGroupIds = myGroupIds
        self.myCategories = myCategories
        self._showOtherOshi = State(initialValue: initialShowOtherOshi)
        self.writeGroup = writeGroup
    }

    // ★ 検索結果一覧（EventHubPickerView）と同じ絞り込みルールを、この会場だけに適用する
    private var visibleReviews: [VenueReport] {
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

    // ★ タグ絞り込みチップで選んだ観点だけに更に絞る
    private var reviews: [VenueReport] {
        guard let selectedTagFilter else { return visibleReviews }
        return visibleReviews.filter { Self.hashtags(in: $0.text).contains("#\(selectedTagFilter)") }
    }

    private var averageRating: Double? {
        let ratings = visibleReviews.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
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
            .padding(.bottom, writeGroup != nil ? 60 : 0)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(place)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            if let writeGroup {
                writeButton(group: writeGroup)
            }
        }
        .task {
            locationInfo = await VenueLocationService.shared.locationInfo(for: place)
            isLoadingLocation = false
            if let coordinate = locationInfo?.coordinate {
                cameraPosition = .region(
                    MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
                )
            }
        }
        .sheet(item: $reportTarget) { report in
            ReportComposerSheet(
                title: "この口コミを報告",
                reasons: ["スパム・宣伝", "虚偽の情報", "嫌がらせ・誹謗中傷", "不適切な内容", "その他"]
            ) { reason, detail in
                ModerationService.reportVenueReview(
                    venueReportId: report.id,
                    groupId: report.groupId,
                    text: report.text,
                    authorUid: report.uid,
                    reason: reason,
                    detail: detail
                )
                showReportThanksBriefly()
            }
        }
        .overlay(alignment: .top) {
            if showReportThanks {
                ReportThanksToast()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showReportThanks)
    }

    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
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

            if let averageRating {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", averageRating))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    Text("\(visibleReviews.count)件")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .glossyHighlight(cornerRadius: CornerRadius.card)
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
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
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
            HStack {
                Text("口コミ \(reviews.count)件")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }

            if !visibleReviews.isEmpty {
                tagFilterRow
            }

            if reviews.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28))
                        .foregroundColor(accentColor.opacity(0.3))
                        .accessibilityHidden(true)
                    Text(visibleReviews.isEmpty ? "この会場の口コミはまだありません" : "この観点の口コミはまだありません")
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

    // ★ 「入場ゲート」「座席・見え方」など、実際に参加した人だから分かる観点で絞り込めるチップ列
    private var tagFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagFilterChip(label: "すべて", isSelected: selectedTagFilter == nil) {
                    selectedTagFilter = nil
                }
                ForEach(VenueReport.commonTags, id: \.self) { tag in
                    tagFilterChip(label: tag, isSelected: selectedTagFilter == tag) {
                        selectedTagFilter = (selectedTagFilter == tag) ? nil : tag
                    }
                }
            }
        }
    }

    private func tagFilterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .white : accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? AnyShapeStyle(accentColor) : AnyShapeStyle(accentColor.opacity(0.1))))
        }
    }

    // ★ 匿名投稿のため書いた人は表示しない。参加目的・その回の日付・評価・写真・本文中の#タグを添える
    private func reviewRow(_ report: VenueReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let rating = report.rating, rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                    }
                }
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

                Button {
                    reportTarget = report
                } label: {
                    Image(systemName: "flag")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .accessibilityLabel("この口コミを報告する")
            }

            Text(report.text)
                .font(.system(size: 13.5))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let imageURLString = report.imageURL, let url = URL(string: imageURLString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color(.systemGray6)
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipped()
            }

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

    // MARK: - ツール内から直接投稿

    private func writeButton(group: IdolGroup) -> some View {
        Button {
            showComposer = true
        } label: {
            Label("口コミを書く", systemImage: "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [accentColor, Color.oshiniumPrimary2],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                )
                .shadow(color: accentColor.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .padding(16)
        .sheet(isPresented: $showComposer) {
            VenueReportComposerView(
                title: "会場の口コミ",
                placeholder: "会場の様子、混雑状況、注意点など（#ハッシュタグも使えます）",
                kind: "review",
                eventId: "",
                groupId: group.id,
                accentColor: accentColor
            ) { text, uid, rating, imageURL, completion in
                venueReportVM.submit(
                    eventId: "",
                    groupId: group.id,
                    kind: "review",
                    text: text,
                    uid: uid,
                    place: place,
                    eventDate: nil,
                    purpose: nil,
                    groupCategory: group.category,
                    rating: rating,
                    imageURL: imageURL,
                    completion: completion
                )
            }
        }
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
