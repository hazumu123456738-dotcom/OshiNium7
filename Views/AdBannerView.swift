//
//  AdBannerView.swift
//  OshiNium7
//

import SwiftUI
import GoogleMobileAds

// ★ Google AdMobのバナー広告をSwiftUIから使うための薄いラッパー。
//   ★ 2026/08/13、本番のAdMobアカウントで広告ユニットIDを発行したため、表示箇所ごとに
//   実際のIDを呼び出し側から明示的に渡す形にしている(既定値は持たせない)。
//   呼び出し側: ChatTab(チャット一覧用)・HomeView(タイムライン用)
struct AdBannerView: UIViewControllerRepresentable {
    var adUnitID: String
    // ★ 固定320x50(GADAdSizeBanner)だとカード内側の実際の余白次第で画面幅からはみ出す
    //   端末(iPhone SEで発生)があったため、呼び出し側が確保できる実幅を渡し、
    //   GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidthでその幅ぴったりに
    //   収まるサイズを都度算出させる(release-check 2026/08/20で発見)
    var width: CGFloat

    // ★ 呼び出し側(SwiftUI)がGoogleMobileAdsをimportせずに.frame(height:)を
    //   正しく指定できるよう、実際に使うのと同じ算出関数で高さだけ公開する
    static func adaptiveHeight(forWidth width: CGFloat) -> CGFloat {
        GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width).size.height
    }

    func makeUIViewController(context: Context) -> AdBannerHostController {
        AdBannerHostController(adUnitID: adUnitID, width: width)
    }

    func updateUIViewController(_ uiViewController: AdBannerHostController, context: Context) {}
}

// ★ GADBannerViewのrootViewControllerには広告タップ後の全画面コンテンツを載せる
//   UIViewControllerが必要なため、UIView単体ではなくUIViewControllerでラップする
final class AdBannerHostController: UIViewController {
    private let adUnitID: String
    private let bannerView: GADBannerView

    init(adUnitID: String, width: CGFloat) {
        self.adUnitID = adUnitID
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        self.bannerView = GADBannerView(adSize: adSize)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        bannerView.load(GADRequest())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preferredContentSize = bannerView.adSize.size
    }
}
