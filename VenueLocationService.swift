//
//  VenueLocationService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import CoreLocation
import MapKit

// ★ event.place（会場名の文字列）を緯度経度に変換する。
//   「Kアリーナ横浜」のような施設名は住所ジオコーディング（CLGeocoder）よりも、
//   Apple MapsのPOI検索（MKLocalSearch）の方が正確に解決できるため、こちらを使う。
//   日本国内のイベント会場を想定し、検索範囲のヒントとして日本全体を渡す。
//   同じ会場名を何度も引かないよう、プロセス内メモリキャッシュを持つ。APIキー不要。
@MainActor
final class VenueLocationService {
    static let shared = VenueLocationService()

    private var cache: [String: CLLocationCoordinate2D] = [:]

    private init() {}

    // ★ 会場名だけでは1回のPOI検索で見つからないことがある（施設名の表記ゆれ、
    //   Apple Mapsに未登録の会場、号室・棟名などの補足が混ざっているケース等）ため、
    //   ①そのままPOI検索 → ②括弧書きなどを除いた簡略名で再検索 → ③住所ジオコーディング
    //   の順に段階的にフォールバックし、会場名が分かっていれば極力マップを出せるようにする
    func coordinate(for place: String) async -> CLLocationCoordinate2D? {
        let key = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        if let cached = cache[key] { return cached }

        if let coordinate = await searchPOI(query: key) {
            cache[key] = coordinate
            return coordinate
        }

        let simplified = Self.simplify(key)
        if simplified != key, !simplified.isEmpty, let coordinate = await searchPOI(query: simplified) {
            cache[key] = coordinate
            return coordinate
        }

        if let coordinate = await geocodeAddress(key) {
            cache[key] = coordinate
            return coordinate
        }

        print("🔥 VenueLocationService: 会場の位置を特定できませんでした:", key)
        return nil
    }

    private func searchPOI(query: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            latitudinalMeters: 2_500_000,
            longitudinalMeters: 2_500_000
        )

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            print("🔥 VenueLocationService POI検索エラー(\(query)):", error)
            return nil
        }
    }

    // ★ POI検索でも見つからない場合、住所としてのジオコーディングを試す
    //   （マイナーな会場でも、住所表記であれば解決できることがある）
    private func geocodeAddress(_ query: String) async -> CLLocationCoordinate2D? {
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            return placemarks.first?.location?.coordinate
        } catch {
            print("🔥 VenueLocationService ジオコーディングエラー(\(query)):", error)
            return nil
        }
    }

    // ★ 括弧書きの補足（最寄り駅・アクセス情報など）や、号室・階数の細かい表記を取り除き、
    //   施設の本体名だけで再検索できるようにする
    private static func simplify(_ text: String) -> String {
        var result = text.replacingOccurrences(
            of: #"(\(|（).*?(\)|）)"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"[0-9０-９]+(F|階|号室|号館)"#,
            with: "",
            options: .regularExpression
        )

        // ★「お台場・青海周辺エリア」のように複数の地名を「・」でつなぎ、
        //   末尾に「周辺エリア」等の曖昧な範囲表現を付けただけの文字列は、
        //   POI検索でも住所ジオコーディングでも解決できないことが多い。
        //   最初の地名だけを取り出し、範囲を表す接尾語を落として再検索できるようにする
        if let firstSegment = result.split(separator: "・").first {
            result = String(firstSegment)
        }
        for suffix in ["周辺エリア", "周辺", "エリア", "付近"] {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
