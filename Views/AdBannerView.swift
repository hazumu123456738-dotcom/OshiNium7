//
//  AdBannerView.swift
//  OshiNium7
//

import SwiftUI
import GoogleMobileAds

// ★ Google AdMobのバナー広告をSwiftUIから使うための薄いラッパー。
//   ★ 今はGoogle公式のテスト用広告ユニットID(ca-app-pub-3940256099942544/2934735716)を
//   固定で使っており、常にGoogleのテスト広告(「Test Ad」と表示される)しか出ない。
//   本番のAdMobアカウントで広告ユニットIDを発行したら、adUnitIDを差し替える必要がある。
//   ★ 表示箇所ごとに用途が伝わるようアクセシビリティラベルを付け、VoiceOverでも
//   「広告」であることが分かるようにしている
struct AdBannerView: UIViewControllerRepresentable {
    var adUnitID: String = "ca-app-pub-3940256099942544/2934735716"

    func makeUIViewController(context: Context) -> AdBannerHostController {
        AdBannerHostController(adUnitID: adUnitID)
    }

    func updateUIViewController(_ uiViewController: AdBannerHostController, context: Context) {}
}

// ★ GADBannerViewのrootViewControllerには広告タップ後の全画面コンテンツを載せる
//   UIViewControllerが必要なため、UIView単体ではなくUIViewControllerでラップする
final class AdBannerHostController: UIViewController {
    private let adUnitID: String
    private let bannerView = GADBannerView(adSize: GADAdSizeBanner)

    init(adUnitID: String) {
        self.adUnitID = adUnitID
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
