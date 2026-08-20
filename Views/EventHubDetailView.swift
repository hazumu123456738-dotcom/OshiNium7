//
//  EventHubDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import Nuke
import MapKit
import CoreLocation
import FirebaseAuth

// ★ 2026/08/20（oshiスキル監査）：以前はここに天気詳細シート・チケット/グッズ/お知らせシート・
//   会場口コミシートも含めて2,592行あったが、EventHubWeatherDetailSheet.swift・
//   EventHubExtrasSheets.swift・EventHubVenueReportsSheet.swiftへ分割した。
//   このファイルには「当日ハブ」本体のダッシュボードだけが残る

// ★ イベントを1件選んだあとの「当日ハブ」画面。
//   会場マップ・天気・周辺施設・おすすめ駅・周辺ホテルは、会場名をジオコーディングした座標をもとに
//   MapKit（地図・周辺検索）とOpen-Meteo（天気）で実データを取得して表示する。
//   チケット・グッズ・公式お知らせは、ファン同士で持ち寄る実データ（EventHubExtrasViewModel）として
//   複数件登録できるようにし、AIおすすめは画面に表示している実データだけを根拠にGeminiで生成する
//   （EventAIRecommendationService。googleSearchで裏取りし、推測は断定しないよう指示している）。
struct EventHubDetailView: View {
    let event: Event
    let group: IdolGroup?
    var onChangeEvent: () -> Void

    // ★ 2026/08/18追加：Gemini API利用規約の年齢要件対応のため
    @EnvironmentObject var settingsVM: UserSettingsViewModel

    // ★ カード横の矢印・スワイプで前後のイベントに移動するための隣接イベント。
    //   端（最初/最後）にいるときはnilにして、ボタンを非表示/無効化する
    var previousEvent: Event? = nil
    var nextEvent: Event? = nil
    var onSelectEvent: (Event) -> Void = { _ in }

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    // MARK: - 会場データ（ジオコーディング・天気・周辺検索）

    // ★ loadVenueData()の「古い呼び出しの結果を捨てる」ための世代カウンタ
    @State private var venueLoadGeneration = 0

    @State private var venueCoordinate: CLLocationCoordinate2D?
    @State private var venueResolutionFailed = false
    @State private var isResolvingVenue = false

    @State private var weather: DailyWeather?
    @State private var isLoadingWeather = false

    @State private var nearbyResults: [NearbyCategory: [NearbyPlace]] = [:]
    @State private var isLoadingNearby = false

    // ★ 会場マップのミニカード用の静止画スナップショット。以前はMap(position:)を直接
    //   小さいタイルに埋め込んでいたが、URL経由で追加した予定など実際の座標が解決された
    //   場合に限って、Map自身にはどんな明示的なサイズ指定（.frame()/GeometryReader/
    //   initialPosition化）を試してもカード全体どころかヒーローセクションまで画面幅を
    //   超えてはみ出す再現性のある不具合があった（実機・シミュレーターで特定済み、
    //   Mapを完全に取り除くとだけ症状が消えることを確認している）。原因はSwiftUIの
    //   Map自体の既知の不具合と見られ、根本原因の特定より安全な回避を優先し、
    //   タップ後の本物の地図(VenueMapView)はそのまま維持しつつ、このミニカードだけ
    //   MKMapSnapshotterで生成した静止画に置き換えて完全に回避する
    @State private var mapSnapshotImage: UIImage?
    // ★ 発見(全画面UIレビュー)：以前はスナップショット生成が失敗しても何の状態も
    //   変わらず、ProgressViewが無期限に回り続けて見えていた
    @State private var mapSnapshotFailed = false
    @State private var showVenueMap = false
    @State private var mapInitialCategories: Set<NearbyCategory> = []
    @State private var mapOverrideResults: [NearbyCategory: [NearbyPlace]]?
    // ★ 駅ごとの「会場から最も近い出口」（キーはNearbyPlace.id）。見つからなければ入らない
    @State private var stationExits: [UUID: String] = [:]

    // ★ 天気カード・駅/ホテルの各行をタップしたときの詳細表示
    @State private var showWeatherDetail = false
    @State private var tappedPlace: (category: NearbyCategory, place: NearbyPlace)?

    // ★ チケット・グッズ（複数件登録できる実データ）
    @StateObject private var extrasVM = EventHubExtrasViewModel()
    @State private var showTicketSheet = false
    @State private var showGoodsSheet = false

    // ★ AIおすすめ（このハブ画面に表示している実データだけを根拠に生成する）
    @State private var aiTips: EventAITips?
    @State private var isGeneratingAITips = false
    @State private var aiTipsErrorText: String?

    // ★ 会場の口コミ・その日のセトリ（匿名投稿）
    @StateObject private var venueReportVM = VenueReportViewModel()
    @State private var showVenueReportsSheet = false

    // ★ ヒーローカードの左右スワイプで前後のイベントに移動するためのドラッグ量
    @State private var heroDragOffset: CGFloat = 0

    // ★ 予定に画像URLが登録されていない場合に、公式URLから拾ってきたヒーロー画像
    @State private var scrapedHeroImageURL: URL?
    // ★ 関連画像を探している最中はグループアイコンにフォールバックせず、
    //   中立なプレースホルダーを出す（「グループアイコンが一瞬映ってから関連画像に差し替わる」
    //   というチラつきを防ぐため。グループアイコンは本当に画像が見つからなかった時の最終手段にする）
    @State private var isResolvingHeroImage = true

    // ★ ヒーロー画像本体。以前はLazyImageに直接描画させていたが、URLインポートで取得される
    //   ロゴ画像など極端な横長比率の画像で、.frame()をどこに置いてもLazyImageコンテナ自身が
    //   要求するサイズを矯正できず、ヒーローセクション～画面全体が左右にはみ出す不具合があった
    //   （会場マップのMap(position:)で発生したのと同種の、SwiftUI側の.frame()指定が効かない
    //   不具合と見られる）。同じ回避策として、Nukeのパイプラインで一度UIImageとして取得してから
    //   プレーンなImage(uiImage:)で描画することで、.frame()が確実に効くようにする
    @State private var heroUIImage: UIImage?

    @Environment(\.customTabBarHeight) private var customTabBarHeight

    // ★ 参加グループのグリッドと同じ「横2列の正方形カード」に統一し、規則的で見やすくする
    private let gridSpacing: CGFloat = 14

    private var tileSide: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return max((screenWidth - 32 - gridSpacing) / 2, 0)
    }

    // ★ 以前は9枚のカードを1つの平坦なグリッドに並べていたため、下までスクロールしないと
    //   何があるか把握しづらかった。「会場情報」「みんなの情報」「お知らせ・AI」の3セクションに
    //   見出し付きでグルーピングし、規則正しく整理して一覧性を上げる
    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: gridSpacing), GridItem(.flexible(), spacing: gridSpacing)]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                heroSection

                hubSection(title: "会場情報", icon: "mappin.and.ellipse") {
                    weatherCard
                    mapCard
                    stationsCard
                    hotelsCard
                }

                hubSection(title: "みんなの情報", icon: "person.2.fill") {
                    venueReportsCard
                    ticketCard
                    goodsCard
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text("お知らせ・AI")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.primary)

                    aiTipsCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            // ★ 自作の下タブバー分の余白が無く、一番下の「AIおすすめ」カードが
            //   タブバーの裏に隠れて最後まで見えなかったため、その高さぶんも足す。
            //   タブバーぶんだけだと際どく足りない実機があったため、少し多めに余裕を持たせる
            .padding(.bottom, 60 + customTabBarHeight)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task(id: event.id) {
            await loadVenueData()
        }
        .task(id: event.id) {
            scrapedHeroImageURL = nil
            guard EventImageResolver.resolvedURL(for: event) == nil else {
                isResolvingHeroImage = false
                return
            }
            isResolvingHeroImage = true
            scrapedHeroImageURL = await EventImageResolver.resolveImageURL(for: event)
            isResolvingHeroImage = false
        }
        // ★ heroBackground参照。URLが解決/変化するたびにUIImageとして取り直す
        .task(id: heroImageURL) {
            guard let heroImageURL else {
                heroUIImage = nil
                return
            }
            heroUIImage = try? await ImagePipeline.shared.image(for: heroImageURL)
        }
        .onAppear { startExtrasListeningIfNeeded() }
        .onChange(of: event.id) { _, _ in
            startExtrasListeningIfNeeded()
            aiTips = nil
            aiTipsErrorText = nil
        }
        .onDisappear {
            extrasVM.stopListening()
            venueReportVM.stopListening()
        }
        .sheet(isPresented: $showVenueMap) {
            if let venueCoordinate {
                VenueMapView(
                    event: event,
                    venueCoordinate: venueCoordinate,
                    nearbyResults: mapOverrideResults ?? nearbyResults,
                    accentColor: accentColor,
                    initialCategories: mapInitialCategories
                )
            }
        }
        // ★ 天気カードをタップしたときの詳細（気圧・湿度・体調アドバイスなどをまとめて見せる）
        .sheet(isPresented: $showWeatherDetail) {
            if let weather {
                WeatherDetailSheet(
                    event: event,
                    weather: weather,
                    accentColor: accentColor,
                    gradientColors: weatherGradient(for: weather.weatherCode)
                )
            }
        }
        // ★ おすすめ駅・周辺ホテルの各行タップで、既存の施設詳細シート（VenueMapViewと共通）を開く
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
        // ★ チケット・グッズ・公式お知らせは、それぞれ「一覧＋追加」のシートを開く
        .sheet(isPresented: $showTicketSheet) {
            EventTicketsSheet(event: event, extrasVM: extrasVM, accentColor: accentColor)
        }
        .sheet(isPresented: $showGoodsSheet) {
            EventGoodsSheet(event: event, extrasVM: extrasVM, accentColor: accentColor)
        }
        // ★ 会場の口コミ・その日のセトリ（匿名投稿。ハッシュタグで絞り込みできる）
        .sheet(isPresented: $showVenueReportsSheet) {
            VenueReportsSheet(event: event, group: group, venueReportVM: venueReportVM, accentColor: accentColor, place: effectiveVenuePlace)
        }
    }

    private func startExtrasListeningIfNeeded() {
        guard let id = event.id, !id.isEmpty else { return }
        extrasVM.startListening(eventId: id)
        venueReportVM.startListening(eventId: id)
        if let place = effectiveVenuePlace {
            venueReportVM.startListeningByPlace(place)
        }
    }

    // ★ 地図をアプリ内で開く（特定カテゴリを最初から表示したい場合はcategoriesを渡す。
    //   overrideResultsを渡すと、そのカテゴリの表示件数を絞り込める＝「この3駅だけ表示」等に使う）
    private func openVenueMap(
        showing categories: Set<NearbyCategory> = [],
        overrideResults: [NearbyCategory: [NearbyPlace]]? = nil
    ) {
        guard venueCoordinate != nil else { return }
        mapInitialCategories = categories
        mapOverrideResults = overrideResults
        showVenueMap = true
    }

    // MARK: - 会場データの読み込み

    // ★ カード横の矢印/スワイプで素早く別イベントに切り替えると、前のイベント用の
    //   非同期処理（MKLocalSearch・Open-Meteo等）がキャンセルされずに裏で動き続け、
    //   新しいイベントの結果が確定した後に古い結果で上書きしてしまうことがあった
    //   （地図は先に確定するのに、駅・ホテルだけ古い/空のデータになるバグの原因）。
    //   世代カウンタで「今からコミットしようとしている結果が最新の呼び出しのものか」を
    //   毎回確認し、古い呼び出しの結果は捨てる
    private func loadVenueData() async {
        venueLoadGeneration += 1
        let myGeneration = venueLoadGeneration

        // ★ 前のイベントの会場・天気・周辺情報が一瞬残って見えてしまわないよう、
        //   読み込み開始時に必ずリセットする
        venueCoordinate = nil
        venueResolutionFailed = false
        weather = nil
        nearbyResults = [:]
        stationExits = [:]
        mapOverrideResults = nil
        mapInitialCategories = []

        guard let place = effectiveVenuePlace else {
            venueResolutionFailed = true
            return
        }

        isResolvingVenue = true
        guard let coordinate = await VenueLocationService.shared.coordinate(for: place) else {
            guard myGeneration == venueLoadGeneration else { return }
            isResolvingVenue = false
            venueResolutionFailed = true
            return
        }
        guard myGeneration == venueLoadGeneration else { return }

        venueCoordinate = coordinate
        isResolvingVenue = false
        generateMapSnapshot(coordinate: coordinate)

        isLoadingWeather = true
        isLoadingNearby = true

        async let weatherResult = WeatherService.fetchDailyForecast(coordinate: coordinate, date: event.date)
        async let nearbyResult = NearbyPlacesService.searchAll(around: coordinate)

        let resolvedWeather = await weatherResult
        let resolvedNearby = await nearbyResult
        guard myGeneration == venueLoadGeneration else { return }

        weather = resolvedWeather
        isLoadingWeather = false
        nearbyResults = resolvedNearby
        isLoadingNearby = false

        // ★ おすすめ駅（上位3件）について、会場から最も近い出口を追加で調べる
        let topStations = Array((nearbyResults[.station] ?? []).prefix(3))
        guard !topStations.isEmpty else { return }

        var resolvedExits: [UUID: String] = [:]
        await withTaskGroup(of: (UUID, String?).self) { group in
            for station in topStations {
                group.addTask {
                    let exit = await NearbyPlacesService.nearestExit(to: station, venueCoordinate: coordinate)
                    return (station.id, exit)
                }
            }
            for await (id, exit) in group {
                if let exit {
                    resolvedExits[id] = exit
                }
            }
        }
        guard myGeneration == venueLoadGeneration else { return }
        stationExits = resolvedExits
    }

    // ★ 会場マップのミニカード用に、MKMapSnapshotterで静止画を生成する（上のmapSnapshotImage
    //   の宣言コメント参照：Map(position:)を直接埋め込むと再現性のあるレイアウト崩れが
    //   起きるための回避策）。ピン自体はスナップショットに含まれないため、
    //   中心座標＝画像の中央にSwiftUI側でオーバーレイして描く
    private func generateMapSnapshot(coordinate: CLLocationCoordinate2D) {
        let myGeneration = venueLoadGeneration
        let side = tileSide
        guard side > 0 else { return }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900)
        options.size = CGSize(width: side, height: side)
        options.scale = UIScreen.main.scale
        options.mapType = .standard

        mapSnapshotFailed = false
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot else {
                if let error { print("🔥 会場マップのスナップショット生成に失敗:", error) }
                DispatchQueue.main.async {
                    guard myGeneration == self.venueLoadGeneration else { return }
                    self.mapSnapshotFailed = true
                }
                return
            }
            DispatchQueue.main.async {
                guard myGeneration == self.venueLoadGeneration else { return }
                self.mapSnapshotImage = snapshot.image
            }
        }
    }

    // ★ 「場所」欄が空でも、「アクセス」欄（AIの背景補完などで埋まることがある）に
    //   会場らしき文字列が入っていれば、それを会場名として使う。
    //   例：手動追加した予定でユーザーが「場所」を空欄のまま保存し、保存後のAI補完で
    //   「アクセス」欄だけが埋まった場合に、天気・マップ・周辺ホテルが
    //   ずっと「会場が未登録」のままになってしまうバグの修正
    private var effectiveVenuePlace: String? {
        if let place = event.place, !place.isEmpty { return place }
        if let access = event.access, !access.isEmpty { return access }
        return nil
    }

    // ★ 会場が取得できなかった理由をカードごとに使い回す
    private var venueUnavailableText: String {
        if effectiveVenuePlace == nil {
            return "会場が未登録のため取得できません"
        } else if venueResolutionFailed {
            return "会場の位置を取得できませんでした"
        } else {
            return "準備中"
        }
    }

    // MARK: - ヒーロー（イベント概要）

    private var typeColor: Color { (event.type ?? .other).iconColor }

    private var formattedDateTime: String {
        return CachedFormatters.date(format: "M月d日(E) HH:mm開演").string(from: event.date)
    }

    // ★ 会場名＋日時を横並びHStackにしていた頃は、長い会場名や日時と組み合わさると
    //   折り返してカードの高さからはみ出し、下端が見切れることがあった。
    //   縦並びに変え、カード自体も少し高くして必ず収まるようにする
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackground

            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0.05)],
                startPoint: .bottom, endPoint: .top
            )

            VStack(alignment: .leading, spacing: 8) {
                Text((event.type ?? .other).displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(typeColor))

                Text(event.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 4) {
                    if let place = event.place, !place.isEmpty {
                        Label(place, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                    Label(formattedDateTime, systemImage: "calendar")
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.92))
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .frame(height: 236)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .offset(x: heroDragOffset)
        // ★ 左右スワイプで前後のイベントに切り替える。指を離した時点の移動量で判定し、
        //   閾値に届かなければ元の位置にバネで戻す
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // ★ 隣が無い方向には強く抵抗させ、行き止まりが分かるようにする
                    let translation = value.translation.width
                    if (translation > 0 && previousEvent == nil) || (translation < 0 && nextEvent == nil) {
                        heroDragOffset = translation * 0.15
                    } else {
                        heroDragOffset = translation
                    }
                }
                .onEnded { value in
                    let translation = value.translation.width
                    let threshold: CGFloat = 70

                    if translation > threshold, let previousEvent {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            onSelectEvent(previousEvent)
                            heroDragOffset = 0
                        }
                    } else if translation < -threshold, let nextEvent {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            onSelectEvent(nextEvent)
                            heroDragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            heroDragOffset = 0
                        }
                    }
                }
        )
        // ★ 矢印は写真の縦中央に置くとタイトル下の「ライブ」等のバッジと重なってしまうため、
        //   既存のコントロールがある上端の角に、グループアイコン／イベント変更ボタンと
        //   並べて置く（「カードの横に<>」＝隣接コントロールとして自然に見える位置）
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                if let previousEvent {
                    heroNavButton(systemImage: "chevron.left") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            onSelectEvent(previousEvent)
                        }
                    }
                }
                if let group {
                    GroupIcon(group: group, isSelected: false, size: 40)
                }
            }
            .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Button(action: onChangeEvent) {
                    HStack(spacing: 4) {
                        Text("イベントを変更")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35), in: Capsule())
                }
                if let nextEvent {
                    heroNavButton(systemImage: "chevron.right") {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            onSelectEvent(nextEvent)
                        }
                    }
                }
            }
            .padding(12)
        }
        .shadow(color: .black.opacity(0.1), radius: 14, x: 0, y: 8)
    }

    private func heroNavButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .accessibilityLabel(systemImage == "chevron.left" ? "前のイベント" : "次のイベント")
    }

    // ★ 予定に画像が登録されていなければ、公式URLからog:imageを拾ってきて表示する。
    //   探している最中はグループアイコンを出さず中立なプレースホルダーにし、
    //   本当に見つからなかった時だけグループ設定のアイコン画像にフォールバックする
    private var heroImageURL: URL? {
        EventImageResolver.resolvedURL(for: event) ?? scrapedHeroImageURL
    }

    @ViewBuilder
    private var heroBackground: some View {
        if heroImageURL != nil {
            if let heroUIImage {
                Image(uiImage: heroUIImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 236)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                heroLoadingPlaceholder
            }
        } else if isResolvingHeroImage {
            heroLoadingPlaceholder
        } else {
            heroFallback
        }
    }

    // ★ 関連画像を読み込み中は、色付きの背景ではなく中立な薄いグレーのプレースホルダーにする
    private var heroLoadingPlaceholder: some View {
        Color(.systemGray5)
    }

    @ViewBuilder
    private var heroFallback: some View {
        if let data = group?.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 236)
                .frame(maxWidth: .infinity)
                .clipped()
        } else {
            LinearGradient(colors: [accentColor, accentColor2],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: - 今日の天気（Open-Meteoの実データ）

    // ★ マップカードと同じ「敷き詰め型」の写真カード風レイアウト。天気の状態に応じたグラデーションを
    //   背景に敷き、大きな天気アイコンをイラスト代わりに薄く重ねて余白を埋める。タップで詳細シートへ
    private var weatherCard: some View {
        Button {
            guard weather != nil else { return }
            showWeatherDetail = true
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: weather.map { weatherGradient(for: $0.weatherCode) }
                                ?? [Color(.systemGray6), Color(.systemGray5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                if let weather {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 86))
                        .foregroundColor(.white.opacity(0.16))
                        .rotationEffect(.degrees(-6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .offset(x: 16, y: 14)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("当日の天気")
                                .font(.system(size: 12, weight: .bold))
                            // ★ 実況ではなく予報であること・精度に限界があることを画面上でも分かるようにする
                            Text("予報")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.25)))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .opacity(0.85)
                        }
                        .foregroundColor(.white)

                        Spacer(minLength: 2)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("\(Int(weather.maxTemp.rounded()))°")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Text("/\(Int(weather.minTemp.rounded()))°")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Text(weather.description)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if weather.averagePressure != nil || weather.averageHumidity != nil {
                            HStack(spacing: 6) {
                                if let pressure = weather.averagePressure {
                                    weatherChip("気圧\(Int(pressure.rounded()))")
                                }
                                if let humidity = weather.averageHumidity {
                                    weatherChip("湿度\(Int(humidity.rounded()))%")
                                }
                            }
                        }
                    }
                    .padding(12)
                } else if isResolvingVenue || isLoadingWeather {
                    VStack {
                        Spacer(minLength: 0)
                        ProgressView()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(accentColor)
                            Text("当日の天気")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer(minLength: 0)
                        }
                        comingSoonFiller(icon: "cloud.sun.fill", text: weatherUnavailableText)
                    }
                    .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(weather == nil)
        .frame(width: tileSide, height: tileSide)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private func weatherChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.22)))
    }

    // ★ WMO天気コードから、天気の雰囲気に合わせたグラデーション配色を返す
    private func weatherGradient(for code: Int) -> [Color] {
        switch code {
        case 0:
            return [Color(hex: "#FFC95C"), Color(hex: "#FF9142")]
        case 1, 2:
            return [Color(hex: "#7FC2F5"), Color(hex: "#FFC95C")]
        case 3:
            return [Color(hex: "#B7C4D6"), Color(hex: "#8894A8")]
        case 45, 48:
            return [Color(hex: "#C7D3DC"), Color(hex: "#9BADB9")]
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return [Color(hex: "#5FA8E0"), Color(hex: "#2B5B93")]
        case 71, 73, 75, 77, 85, 86:
            return [Color(hex: "#CFE0F2"), Color(hex: "#9DB8D6")]
        case 95, 96, 99:
            return [Color(hex: "#5A6DAE"), Color(hex: "#232B52")]
        default:
            return [Color(hex: "#B7C4D6"), Color(hex: "#8894A8")]
        }
    }

    private var weatherUnavailableText: String {
        if effectiveVenuePlace == nil {
            return "会場が未登録のため天気を取得できません"
        } else if venueResolutionFailed {
            return "会場の位置を取得できませんでした"
        } else {
            return "天気予報の対応期間外です（当日〜16日先まで対応）"
        }
    }

    // MARK: - 会場マップ（座標が取れたら実際の地図を表示。タップ/リンクでApple Mapsを開ける）

    // ★ マップは写真カードのように、正方形いっぱいに地図を敷いてタイトルを重ねる
    private var mapCard: some View {
        Button {
            openVenueMap()
        } label: {
            ZStack(alignment: .topLeading) {
                if venueCoordinate != nil {
                    // ★ mapSnapshotImage宣言部のコメント参照：Map(position:)をこのミニカードに
                    //   直接埋め込むとレイアウト崩れの不具合があるため、MKMapSnapshotterで
                    //   生成した静止画を使う。ピンはスナップショットに含まれないため、
                    //   中心座標＝画像の中央にSwiftUI側でオーバーレイして描く
                    if let mapSnapshotImage {
                        Image(uiImage: mapSnapshotImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: tileSide, height: tileSide)
                            .clipped()
                            .overlay {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.white, accentColor)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                    } else if mapSnapshotFailed {
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color(.systemGray6))
                        VStack(spacing: 6) {
                            Image(systemName: "map")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("地図を表示できませんでした")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color(.systemGray6))
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                        .fill(Color(.systemGray6))
                    VStack(spacing: 6) {
                        if isResolvingVenue {
                            ProgressView()
                        } else {
                            Image(systemName: "map")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        Text(mapPlaceholderText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold))
                    Text("会場マップ")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.45), in: Capsule())
                .padding(10)

                if venueCoordinate != nil {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.45), in: Circle())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(venueCoordinate == nil)
        .frame(width: tileSide, height: tileSide)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var mapPlaceholderText: String {
        if let place = effectiveVenuePlace {
            return venueResolutionFailed ? "会場の位置を取得できませんでした" : place
        } else {
            return "会場が未登録です"
        }
    }

    // MARK: - おすすめ駅（会場周辺の駅をMapKitで検索し、徒歩時間を概算する）

    // ★ 上位3駅を行として敷き詰めて表示し、余っていた空白を埋める。行タップで施設詳細シートを開く
    private var stationsCard: some View {
        hubSquareCard(title: "おすすめ駅", icon: "tram.fill") {
            let allStations = nearbyResults[.station] ?? []
            let stations = Array(allStations.prefix(3))

            if !stations.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(stations) { station in
                        placeRow(station, category: .station, showExit: true)
                    }
                    Spacer(minLength: 0)
                    if allStations.count > stations.count {
                        Button {
                            openVenueMap(showing: [.station])
                        } label: {
                            Text("ほかを地図で見る")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                    }
                }
            } else if isResolvingVenue || isLoadingNearby {
                loadingFiller
            } else if let access = event.access, !access.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(access)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(4)
                    Spacer(minLength: 0)
                }
            } else {
                comingSoonFiller(icon: "tram.fill", text: venueUnavailableText)
            }
        }
    }

    // ★ 駅・ホテル共通の1行分の表示（アイコン・名前・徒歩時間、タップで施設詳細シートへ）
    private func placeRow(_ place: NearbyPlace, category: NearbyCategory, showExit: Bool = false) -> some View {
        Button {
            tappedPlace = (category, place)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(category.color.opacity(0.12))
                    Image(systemName: category.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(category.color)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(placeSubtitle(place, showExit: showExit))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }

    private func placeSubtitle(_ place: NearbyPlace, showExit: Bool) -> String {
        var text = "徒歩\(walkMinutes(place.distanceMeters))分・\(place.distanceLabel)"
        if showExit, let exit = stationExits[place.id] {
            text += "・\(exit)"
        }
        return text
    }

    private var loadingFiller: some View {
        VStack {
            Spacer(minLength: 0)
            ProgressView()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func walkMinutes(_ meters: Double) -> Int {
        max(1, Int((meters / 80).rounded(.up)))
    }

    private func countLabel(_ count: Int) -> String {
        NearbyPlacesService.countLabel(count)
    }


    // MARK: - 周辺のホテル（MapKitで実検索）

    // ★ 上位3件のホテルを行として敷き詰めて表示する（駅カードと同じ構成）
    private var hotelsCard: some View {
        hubSquareCard(title: "周辺のホテル", icon: "bed.double.fill") {
            let allHotels = nearbyResults[.hotel] ?? []
            let hotels = Array(allHotels.prefix(3))

            if !hotels.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(hotels) { hotel in
                        placeRow(hotel, category: .hotel)
                    }
                    Spacer(minLength: 0)
                    if allHotels.count > hotels.count {
                        Button {
                            openVenueMap(showing: [.hotel])
                        } label: {
                            Text("ほか\(countLabel(allHotels.count - hotels.count))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                    }
                }
            } else if isResolvingVenue || isLoadingNearby {
                loadingFiller
            } else {
                comingSoonFiller(
                    icon: "bed.double.fill",
                    text: venueCoordinate == nil ? venueUnavailableText : "周辺にホテルが見つかりませんでした"
                )
            }
        }
    }

    // MARK: - 会場の口コミ（匿名投稿。ハッシュタグを付けると絞り込みに使える）

    private var venueReportsCard: some View {
        Button {
            showVenueReportsSheet = true
        } label: {
            hubSquareCard(title: "会場の口コミ", icon: "bubble.left.and.bubble.right.fill") {
                // ★ このイベントだけでなく、同じ会場で過去に書かれた口コミも合わせて数える
                let reviews = venueReportVM.placeReviewEntries
                if let latest = reviews.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(latest.text)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text("\(reviews.count)件の口コミ")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                } else {
                    addOnlyFiller(icon: "bubble.left.and.bubble.right.fill", text: "口コミはまだありません")
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - チケット情報（ファン同士で持ち寄る複数件のチケット情報。無ければevent.ticketPrice等の単項目にフォールバック）

    private var ticketCard: some View {
        Button {
            showTicketSheet = true
        } label: {
            hubSquareCard(title: "チケット情報", icon: "ticket.fill") {
                if !extrasVM.tickets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(extrasVM.tickets.prefix(2)) { ticket in
                            ticketRow(ticket)
                        }
                        Spacer(minLength: 0)
                        if extrasVM.tickets.count > 2 {
                            Text("ほか\(extrasVM.tickets.count - 2)件")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                    }
                } else if event.ticketPrice?.isEmpty == false || event.ticketStartDate?.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        if let price = event.ticketPrice, !price.isEmpty {
                            ticketInfoRow(icon: "yensign.circle.fill", label: "料金", value: price)
                        }
                        if let start = event.ticketStartDate, !start.isEmpty {
                            ticketInfoRow(icon: "calendar.badge.clock", label: "販売開始", value: start)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    addOnlyFiller(icon: "ticket.fill", text: "チケット情報はまだありません")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func ticketRow(_ ticket: EventTicketInfo) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(accentColor.opacity(0.12))
                Image(systemName: "ticket.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(ticket.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(ticket.price)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func ticketInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(accentColor.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - グッズ情報（ファン同士で持ち寄る複数件のグッズ情報）

    private var goodsCard: some View {
        Button {
            showGoodsSheet = true
        } label: {
            hubSquareCard(title: "グッズ情報", icon: "bag.fill") {
                if !extrasVM.goods.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(extrasVM.goods.prefix(2)) { item in
                            goodsRow(item)
                        }
                        Spacer(minLength: 0)
                        if extrasVM.goods.count > 2 {
                            Text("ほか\(extrasVM.goods.count - 2)件")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                    }
                } else {
                    addOnlyFiller(icon: "bag.fill", text: "グッズ情報はまだありません")
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func goodsRow(_ item: EventGoodsItem) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(accentColor.opacity(0.12))
                Image(systemName: "bag.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let price = item.price, !price.isEmpty {
                    Text(price)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - AIおすすめ（このハブ画面に表示している実データだけを根拠に、タップで生成する）

    private var aiTipsCard: some View {
        hubWideCard(title: "AIおすすめ", icon: "sparkles", badge: "Beta") {
            if let aiTips {
                VStack(alignment: .leading, spacing: 10) {
                    aiTipLine(icon: "person.3.fill", text: aiTips.congestion)
                    aiTipLine(icon: "arrow.triangle.turn.up.right.circle.fill", text: aiTips.route)
                    aiTipLine(icon: "exclamationmark.triangle.fill", text: aiTips.precautions)
                    Button {
                        generateAITips()
                    } label: {
                        Text("再生成する")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                    .padding(.top, 2)
                }
            } else if isGeneratingAITips {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("会場・天気・チケット等の情報から分析中…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                Button {
                    generateAITips()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 26))
                            .foregroundColor(accentColor.opacity(0.6))
                        Text("このイベントの情報からAIおすすめを生成")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentColor)
                            .multilineTextAlignment(.center)
                        if let aiTipsErrorText {
                            Text(aiTipsErrorText)
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func aiTipLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ★ 各カードに実際に表示している内容だけをそのままAIに渡す（推測・非表示情報は渡さない）
    private func buildAITipsPrompt() -> String {
        var lines: [String] = []
        lines.append("イベント名: \(event.title)")
        lines.append("開催日時: \(formattedDateTime)")
        if let place = effectiveVenuePlace {
            lines.append("会場: \(place)")
        }

        if let weather {
            var weatherLine = "天気予報: \(weather.description)、最高\(Int(weather.maxTemp.rounded()))度/最低\(Int(weather.minTemp.rounded()))度"
            if let precip = weather.precipitationProbability {
                weatherLine += "、降水確率\(precip)%"
            }
            lines.append(weatherLine)
            if let pressure = weather.averagePressure {
                lines.append("平均気圧: 約\(Int(pressure.rounded()))hPa")
            }
            if let humidity = weather.averageHumidity {
                lines.append("平均湿度: 約\(Int(humidity.rounded()))%")
            }
            if let uv = weather.uvIndexMax {
                lines.append("UV指数: 最大約\(String(format: "%.1f", uv))")
            }
        } else {
            lines.append("天気予報: 取得できていません")
        }

        let stations = Array((nearbyResults[.station] ?? []).prefix(3))
        if !stations.isEmpty {
            let text = stations.map { "\($0.name)(徒歩\(walkMinutes($0.distanceMeters))分・\($0.distanceLabel))" }.joined(separator: "、")
            lines.append("最寄り駅: \(text)")
        }

        if !extrasVM.tickets.isEmpty {
            let text = extrasVM.tickets.map { "\($0.name) \($0.price)" }.joined(separator: "、")
            lines.append("チケット情報: \(text)")
        } else if let price = event.ticketPrice, !price.isEmpty {
            lines.append("チケット料金: \(price)")
        }

        if !extrasVM.goods.isEmpty {
            let text = extrasVM.goods.map { $0.name }.joined(separator: "、")
            lines.append("グッズ: \(text)")
        }

        if !extrasVM.announcements.isEmpty {
            let text = extrasVM.announcements.map { $0.title }.joined(separator: "、")
            lines.append("公式からのお知らせ: \(text)")
        }

        return lines.joined(separator: "\n")
    }

    // ★ 2026/08/18追加：Gemini API利用規約は「18歳未満に利用される可能性が高いアプリ」
    //   でのAPI使用を禁止している。誕生日は既にProfileSetupViewで取得済みのため、
    //   新たな情報収集なしにここで判定できる
    private func generateAITips() {
        guard settingsVM.settings.isAdult else {
            aiTipsErrorText = "この機能は18歳以上の方のみご利用いただけます"
            return
        }
        isGeneratingAITips = true
        aiTipsErrorText = nil
        let prompt = buildAITipsPrompt()
        EventAIRecommendationService.shared.generateTips(eventInfo: prompt) { result in
            DispatchQueue.main.async {
                isGeneratingAITips = false
                switch result {
                case .success(let tips):
                    aiTips = tips
                    AnalyticsManager.logAIRecommendationGenerated(feature: "event_hub_ai_tips")
                case .failure:
                    aiTipsErrorText = "生成に失敗しました。時間をおいて再度お試しください"
                }
            }
        }
    }

    // MARK: - セクション見出し＋横2列グリッド（カードをジャンルごとにまとめて規則正しく並べる）

    @ViewBuilder
    private func hubSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.primary)

            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                content()
            }
        }
    }

    // MARK: - 共通パーツ（参加グループと同じ横2列の正方形カード）

    private func hubSquareCard<Content: View>(
        title: String,
        icon: String,
        badge: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(12)
        .frame(width: tileSide, height: tileSide, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        // ★ 行を詰め込んだ結果まれに1〜2pt溢れても、丸角の外に見えてしまわないようにする保険
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
    }

    // ★ 横2列の正方形カードとは別に、1枚で横幅いっぱいを使い、高さは内容に応じて伸びるカード
    //   （AIおすすめのような文章量が多いものを、正方形カードに詰めて途中で切れさせないため）
    private func hubWideCard<Content: View>(
        title: String,
        icon: String,
        badge: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                if let badge {
                    Text(badge)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    // ★ データが無い/準備中のカードを、上下Spacerで縦中央に寄せて余白を均等に埋める共通パーツ
    private func comingSoonFiller(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(accentColor.opacity(0.22))
            Text(text)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // ★ まだ何も登録されていない「追加できるカード」（チケット・グッズ・お知らせ）の共通表示
    private func addOnlyFiller(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(accentColor.opacity(0.1))
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
            }
            .frame(width: 30, height: 30)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("タップして追加")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(accentColor)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
