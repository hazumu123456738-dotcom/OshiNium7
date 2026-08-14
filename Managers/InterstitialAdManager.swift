//
//  InterstitialAdManager.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/14.
//

import Foundation
import UIKit
import GoogleMobileAds

// ★ 「今日の推し活占い」を引く直前に一度だけ挟む、短めの動画広告。
//   ★ 現時点ではGoogle公式のテスト広告ユニットID(動画クリエイティブ対応)を使用している。
//   AdBannerView.swiftと同様、本番のAdMobアカウント(ca-app-pub-8871310610756032)で
//   「インタースティシャル」広告ユニットを新規発行したら、下のadUnitIDを差し替えること
//   （現状のままだと常にGoogleのテスト広告しか表示されない）
//
//   常に1件だけ先読みしておき、表示直後に次の分をまた読み込む設計。読み込みが間に合って
//   いない・失敗した場合でも、占い自体（無料の1日1回の機能）をブロックしないよう、
//   広告なしでそのまま先へ進める（ユーザーの体験を広告のロード状況に依存させない）
@MainActor
final class InterstitialAdManager: NSObject {
    static let shared = InterstitialAdManager()

    private static let adUnitID = "ca-app-pub-3940256099942544/5135589807"

    private var interstitial: GADInterstitialAd?
    private var pendingCompletion: (() -> Void)?

    private override init() {
        super.init()
        loadAd()
    }

    // ★ シングルトンであり参照が消えることは無いため、[weak self]は使わずTask内では
    //   直接InterstitialAdManager.sharedを参照する（selfをSendableクロージャ境界に
    //   キャプチャすることによるSwift 6の並行性警告を避けるため）
    private func loadAd() {
        GADInterstitialAd.load(withAdUnitID: Self.adUnitID, request: GADRequest()) { ad, error in
            Task { @MainActor in
                if let error {
                    print("🔥 InterstitialAdManager load error:", error.localizedDescription)
                    return
                }
                InterstitialAdManager.shared.interstitial = ad
                InterstitialAdManager.shared.interstitial?.fullScreenContentDelegate = InterstitialAdManager.shared
            }
        }
    }

    // ★ 広告を表示し、閉じた（または表示自体に失敗した/そもそも読み込めていなかった）タイミングで
    //   completionを呼ぶ。呼び出し側はcompletion内で実際の抽選処理を行う
    func showAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let interstitial else {
            completion()
            loadAd()
            return
        }
        pendingCompletion = completion
        interstitial.present(fromRootViewController: viewController)
    }
}

extension InterstitialAdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        interstitial = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
        loadAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("🔥 InterstitialAdManager present error:", error.localizedDescription)
        interstitial = nil
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
        loadAd()
    }
}
