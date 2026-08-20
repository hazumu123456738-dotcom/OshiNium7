//
//  VenueMapView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import MapKit

// ★ アプリ内で完結する会場マップ。外部のマップアプリに遷移せず、
//   コンビニ・飲食店・カフェ・トイレ・ホテルのカテゴリボタンを押すと
//   その場でピンが地図上に表示される。
struct VenueMapView: View {
    let event: Event
    let venueCoordinate: CLLocationCoordinate2D
    let nearbyResults: [NearbyCategory: [NearbyPlace]]
    let accentColor: Color

    @State private var activeCategories: Set<NearbyCategory>
    @State private var cameraPosition: MapCameraPosition
    // ★ Map(selection:)には繋げない、完全に独立した状態にする。
    //   Mapの内部選択管理と競合すると、シートが一瞬出てすぐ閉じるバグが起きるため。
    @State private var tappedPlace: (category: NearbyCategory, place: NearbyPlace)?
    @Environment(\.dismiss) private var dismiss

    private let filterCategories: [NearbyCategory] = [
        .station, .convenienceStore, .restaurant, .cafe, .restroom, .hotel, .parking,
        .coinLocker, .smokingArea, .aed
    ]

    init(
        event: Event,
        venueCoordinate: CLLocationCoordinate2D,
        nearbyResults: [NearbyCategory: [NearbyPlace]],
        accentColor: Color,
        initialCategories: Set<NearbyCategory> = []
    ) {
        self.event = event
        self.venueCoordinate = venueCoordinate
        self.nearbyResults = nearbyResults
        self.accentColor = accentColor
        _activeCategories = State(initialValue: initialCategories)
        _cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(center: venueCoordinate, latitudinalMeters: 1100, longitudinalMeters: 1100)
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $cameraPosition) {
                    Marker(event.place ?? event.title, coordinate: venueCoordinate)
                        .tint(accentColor)

                    // ★ 各ピンは自前のボタンでタップを拾い、tappedPlaceに直接代入する
                    //   （Mapの内部選択機構は使わない）
                    ForEach(visiblePlaces, id: \.place.id) { entry in
                        Annotation(entry.place.name, coordinate: entry.place.coordinate) {
                            Button {
                                tappedPlace = entry
                            } label: {
                                ZStack {
                                    Circle().fill(entry.category.color)
                                    Image(systemName: entry.category.icon)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                            }
                            .accessibilityLabel(entry.place.name)
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mapStyle(.standard)
                .frame(maxHeight: .infinity)

                categoryFilterBar
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
            }
            .navigationTitle(event.place.nonEmptyOrNil ?? "会場マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                // ★ 経路検索はアプリ内で完結させず、iPhone純正の「マップ」アプリに遷移する
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        venueMapItem.openInMaps()
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    }
                    .accessibilityLabel("マップアプリで経路を開く")
                }
            }
        }
        // ★ ピンをタップすると施設の詳細シートを表示する（自作・アプリのデザインに統一）
        .sheet(isPresented: Binding(
            get: { tappedPlace != nil },
            set: { if !$0 { tappedPlace = nil } }
        )) {
            if let tappedPlace {
                PlaceDetailSheet(category: tappedPlace.category, place: tappedPlace.place)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // ★ 会場自体をiPhone純正マップアプリで開くためのMapItem
    private var venueMapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: venueCoordinate))
        item.name = event.place.nonEmptyOrNil ?? event.title
        return item
    }

    private var visibleCategories: [NearbyCategory] {
        filterCategories.filter { activeCategories.contains($0) }
    }

    // ★ MapContentBuilder内でのネストしたForEachは選択判定と相性が悪いことがあるため、
    //   （カテゴリ, 施設）のペアに一度平坦化してから単一階層のForEachでMarkerを並べる
    private var visiblePlaces: [(category: NearbyCategory, place: NearbyPlace)] {
        visibleCategories.flatMap { category in
            (nearbyResults[category] ?? []).map { (category, $0) }
        }
    }

    // MARK: - カテゴリフィルターバー（複数選択可）

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filterCategories) { category in
                    categoryChip(category)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryChip(_ category: NearbyCategory) -> some View {
        let isActive = activeCategories.contains(category)
        let count = nearbyResults[category]?.count ?? 0

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isActive {
                    activeCategories.remove(category)
                } else {
                    activeCategories.insert(category)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.rawValue)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isActive ? .white : category.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                // ★ 発見(全画面UIレビュー)：Color.white固定だったため、ダークモードでは
                //   非選択状態のチップだけ常に白いまま浮いて見えていた
                Capsule().fill(isActive ? category.color : Color.appCardBackground)
            )
            .overlay(
                Capsule().stroke(category.color.opacity(0.4), lineWidth: isActive ? 0 : 1.2)
            )
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.4 : 1.0)
    }
}

// MARK: - タップした施設の詳細シート（OshiNiumのデザインに統一したカード）
//   ★ EventHubDetailView（おすすめ駅カードなど）からも直接呼び出すため internal のままにする

struct PlaceDetailSheet: View {
    let category: NearbyCategory
    let place: NearbyPlace

    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    private var address: String? {
        let title = place.mapItem.placemark.title
        return (title?.isEmpty == false) ? title : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    infoCard
                    if category == .aed {
                        aedDisclaimer
                    }
                    routeButton
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(category.color)
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)
            .shadow(color: category.color.opacity(0.35), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .font(.system(size: 19, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(category.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(category.color.opacity(0.9)))
            }

            Spacer(minLength: 0)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            infoRow(icon: "figure.walk", label: "会場からの距離", value: place.distanceLabel)

            if let address {
                infoRow(icon: "mappin.and.ellipse", label: "住所", value: address)
            }

            if let phone = place.mapItem.phoneNumber, !phone.isEmpty {
                infoRow(icon: "phone.fill", label: "電話番号", value: phone)
            }

            if let url = place.mapItem.url {
                Link(destination: url) {
                    infoRow(icon: "globe", label: "ウェブサイト", value: url.absoluteString, valueColor: accentColor)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ 2026/08/20追加：AEDはMapKitの一般POI検索から拾っているため（施設名に「AED」を
    //   含む地点のみに絞ってはいるが）、実在・稼働している保証まではできない。救急時に
    //   使う情報のため、必ず一般財団法人日本救急医療財団が運営する公式の全国AEDマップ
    //   （厚生労働省の指示に基づく唯一の全国版登録型AEDマップ、要出典URL: qqzaidanmap.jp）
    //   への導線を添え、最終確認はそちらで行うよう案内する
    private var aedDisclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                Text("地図アプリの情報を基にしており、実際の設置・稼働状況までは保証できません。緊急時は下記の公式AEDマップも併せてご確認ください。")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Link(destination: URL(string: "https://www.qqzaidanmap.jp/")!) {
                HStack(spacing: 4) {
                    Text("財団全国AEDマップ（日本救急医療財団）")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                }
                .foregroundColor(category.color)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(category.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(valueColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    // ★ 経路検索はアプリ内で完結させず、iPhone純正の「マップ」アプリに遷移する
    private var routeButton: some View {
        Button {
            place.mapItem.openInMaps()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                Text("経路を確認（マップアプリを開く）")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: accentColor.opacity(0.35), radius: 14, x: 0, y: 8)
        }
    }
}
