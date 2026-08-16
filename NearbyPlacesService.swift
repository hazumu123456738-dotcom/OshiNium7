//
//  NearbyPlacesService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import MapKit
import SwiftUI

// ★ 会場周辺の「何があるか」を表す1件（コンビニ・飲食店・駅など）
//   mapItem を保持しておくことで、地図上のピンをタップしたときにAppleマップ純正の
//   詳細カード（mapItemDetailSelectionAccessory）をそのまま表示できる。
struct NearbyPlace: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let distanceMeters: Double

    var name: String { mapItem.name ?? "不明な施設" }
    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }

    var distanceLabel: String {
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m"
        } else {
            return String(format: "%.1fkm", distanceMeters / 1000)
        }
    }
}

// ★ 会場周辺検索のカテゴリ。MKLocalSearchの自然言語クエリで検索する
//   （MapKitの厳密なPOIカテゴリより、日本語クエリの方がコンビニ等の実データにヒットしやすい）
enum NearbyCategory: String, CaseIterable, Identifiable {
    case convenienceStore = "コンビニ"
    case restaurant = "飲食店"
    case cafe = "カフェ"
    case restroom = "トイレ"
    case hotel = "ホテル"
    case station = "駅"
    case parking = "駐車場"
    case coinLocker = "コインロッカー"
    case smokingArea = "喫煙所"
    case aed = "AED"

    var id: String { rawValue }

    var query: String {
        switch self {
        case .convenienceStore: return "コンビニ"
        case .restaurant: return "レストラン"
        case .cafe: return "カフェ"
        case .restroom: return "トイレ"
        case .hotel: return "ホテル"
        case .station: return "駅"
        case .parking: return "駐車場"
        case .coinLocker: return "コインロッカー"
        case .smokingArea: return "喫煙所"
        case .aed: return "AED"
        }
    }

    var icon: String {
        switch self {
        case .convenienceStore: return "cart.fill"
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .restroom: return "toilet.fill"
        case .hotel: return "bed.double.fill"
        case .station: return "tram.fill"
        case .parking: return "parkingsign.circle.fill"
        case .coinLocker: return "shippingbox.fill"
        case .smokingArea: return "smoke.fill"
        case .aed: return "cross.case.fill"
        }
    }

    // ★ 地図上でカテゴリごとに見分けやすいよう固有の色を持たせる
    var color: Color {
        switch self {
        case .convenienceStore: return .green
        case .restaurant: return .orange
        case .cafe: return .brown
        case .restroom: return .blue
        case .hotel: return .pink
        case .station: return .red
        case .parking: return .indigo
        case .coinLocker: return .teal
        case .smokingArea: return .gray
        case .aed: return .mint
        }
    }
}

enum NearbyPlacesService {
    static let resultLimit = 20

    // ★ 検索件数が上限に達している場合は「N件以上」と表記し、実際より少なく見せない
    static func countLabel(_ count: Int) -> String {
        count >= resultLimit ? "\(count)件以上" : "\(count)件"
    }

    // ★ 会場詳細画面ではこのメソッドを10カテゴリ同時に(TaskGroupで並列)呼び出す。
    //   MKLocalSearchは通信状況やシミュレーター環境によって、有効なクエリでも
    //   一時的なエラー（タイムアウト・混雑等）を返すことがあり、その場合旧実装は
    //   即座に空配列を返していたため「実際には駅もホテルも存在するのに
    //   "準備中"/"見つかりませんでした"のまま」という実害のある不具合になっていた。
    //   一時的な失敗と本当に0件だった場合を区別できないため、エラー発生時のみ
    //   短い間隔を空けて最大2回まで再試行する（0件という正常な結果はリトライしない）
    static func search(
        category: NearbyCategory,
        around coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 1200
    ) async -> [NearbyPlace] {
        await withRetry(label: category.rawValue) {
            try await performSearch(query: category.query, poiFilter: nil, coordinate: coordinate, radius: radius)
        }
    }

    // ★ MKLocalSearch呼び出し自体の共通部分。エラー発生時はthrowし、呼び出し元(withRetry)で
    //   再試行の要否を判断する（従来はここでdo/catchして揉み消し、常に[]を返していた）。
    //   nameFilterは駅検索専用の「名前が"駅"で終わるものだけに絞る」条件を共通化するためのフック
    private static func performSearch(
        query: String,
        poiFilter: MKPointOfInterestFilter?,
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        nameFilter: ((String) -> Bool)? = nil
    ) async throws -> [NearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let poiFilter { request.pointOfInterestFilter = poiFilter }
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let places = response.mapItems.compactMap { item -> NearbyPlace? in
            guard let name = item.name, nameFilter?(name) ?? true, let location = item.placemark.location else {
                return nil
            }
            let distance = location.distance(from: origin)
            return NearbyPlace(mapItem: item, distanceMeters: distance)
        }
        // ★ regionはMKLocalSearchにとって「目安」でしかなく範囲外の結果も混ざりうるため、
        //   実際の距離で明確に足切りする（駅・ホテルは少し広めに許容）
        .filter { $0.distanceMeters <= radius * 2.5 }
        .sorted { $0.distanceMeters < $1.distanceMeters }

        return Array(places.prefix(resultLimit))
    }

    // ★ エラー発生時のみ最大2回まで再試行(計3回)、成功した場合や0件で正常終了した
    //   場合はそのまま返す。全て失敗した場合のみ最終的に[]を返す
    private static func withRetry(
        label: String,
        maxAttempts: Int = 3,
        _ operation: () async throws -> [NearbyPlace]
    ) async -> [NearbyPlace] {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("🔥 NearbyPlacesService search error (\(label), \(attempt)/\(maxAttempts)):", error)
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
            }
        }
        print("🔥 NearbyPlacesService search failed after \(maxAttempts) attempts (\(label)):", lastError as Any)
        return []
    }

    // ★ 全カテゴリを並列で検索する（駅だけは実際の駅に絞り込む専用ロジックを使う）
    static func searchAll(around coordinate: CLLocationCoordinate2D) async -> [NearbyCategory: [NearbyPlace]] {
        await withTaskGroup(of: (NearbyCategory, [NearbyPlace]).self) { group in
            for category in NearbyCategory.allCases {
                group.addTask {
                    let places: [NearbyPlace]
                    if category == .station {
                        places = await searchStations(around: coordinate)
                    } else {
                        places = await search(category: category, around: coordinate)
                    }
                    return (category, places)
                }
            }

            var result: [NearbyCategory: [NearbyPlace]] = [:]
            for await (category, places) in group {
                result[category] = places
            }
            return result
        }
    }

    // ★ 駅専用の検索。自然言語クエリ「駅」だけだと「〇〇駅前店」のような店舗名にもヒットしてしまうため、
    //   MapKitのPOIカテゴリ（公共交通機関）で絞り込み、さらに駅名が「駅」で終わるものだけに限定する。
    static func searchStations(
        around coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance = 1200
    ) async -> [NearbyPlace] {
        await withRetry(label: "駅") {
            try await performSearch(
                query: "駅",
                poiFilter: MKPointOfInterestFilter(including: [.publicTransport]),
                coordinate: coordinate,
                radius: radius,
                nameFilter: { $0.hasSuffix("駅") }
            )
        }
    }

    // ★ 駅の出口・改札の中で会場から最も近いものを推定する（駅名＋「出口」で検索し、
    //   出口を示すキーワードを含む結果だけを候補にする）。見つからない場合は素直にnilを返す
    //   （不確かな出口名を捏造しない）。
    private static let exitKeywords = ["東口", "西口", "南口", "北口", "中央口", "正面口", "東改札", "西改札", "南改札", "北改札"]

    static func nearestExit(to station: NearbyPlace, venueCoordinate: CLLocationCoordinate2D) async -> String? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(station.name) 出口"
        request.region = MKCoordinateRegion(
            center: station.coordinate,
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)

        guard let response = try? await search.start() else { return nil }

        let origin = CLLocation(latitude: venueCoordinate.latitude, longitude: venueCoordinate.longitude)

        let candidates: [(exit: String, distance: Double)] = response.mapItems.compactMap { item in
            guard let name = item.name,
                  let matched = exitKeywords.first(where: { name.contains($0) }),
                  let location = item.placemark.location else {
                return nil
            }
            return (matched, location.distance(from: origin))
        }

        return candidates.min(by: { $0.distance < $1.distance })?.exit
    }
}
