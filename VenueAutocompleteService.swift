//
//  VenueAutocompleteService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/16.
//

import Foundation
import MapKit
import Combine

// ★ 予定の「場所」欄で、入力中の文字列に対してApple MapsのPOI候補をリアルタイムに出す。
//   MKLocalSearchCompleterはMKLocalSearchと違い、1文字打つたびに何度呼んでも
//   軽量に候補を返す設計になっている（Appleマップのアプリの検索バーと同じ仕組み）。
//
//   ★ 導入の背景：会場口コミ機能（VenueReportViewModel）はFirestoreの`place`フィールドの
//   完全一致(`whereField("place", isEqualTo:)`)で口コミを紐付けているため、「東京ドーム」
//   「トウキョウドーム」のように自由入力の表記が少しでも違うと口コミが分散してしまっていた。
//   候補から選んだ場合はAppleが返す正式名称がそのまま入るため、表記が自然と揃う。
//   候補に無いマイナーな会場（自宅配信・小規模会場等）は従来通り自由入力のまま確定できる
//   （選択を強制しない）。その場合は表記ゆれ防止の効果は無いが、これは今までと同じ挙動であり、
//   後退ではない。会場の座標が最終的に解決できるかどうかはVenueLocationService側の
//   段階的フォールバック（POI検索→簡略名再検索→住所ジオコーディング）に委ねられ、
//   このサービスの役割はあくまで「候補を出す」ことだけに留める
final class VenueAutocompleteService: NSObject, ObservableObject {
    @Published private(set) var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
        // ★ VenueLocationService.searchPOIと同じく、日本全体を検索範囲のヒントにする
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            latitudinalMeters: 2_500_000,
            longitudinalMeters: 2_500_000
        )
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }
        completer.queryFragment = query
    }

    func clear() {
        completer.queryFragment = ""
        results = []
    }
}

extension VenueAutocompleteService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // ★ 住所そのものの候補（例："東京都文京区後楽1丁目3-61"）より、施設名としての候補を
        //   優先したいため、subtitleが番地だけになりがちな.pointOfInterest系を上に残しつつ、
        //   件数は多すぎても選びにくいので上位8件に絞る
        results = Array(completer.results.prefix(8))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("🔥 VenueAutocompleteService error:", error)
        results = []
    }
}
