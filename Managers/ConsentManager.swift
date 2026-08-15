//
//  ConsentManager.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/14.
//

import Foundation
import UIKit
import UserMessagingPlatform
import GoogleMobileAds

// ★ AdMobをEEA/UK圏のユーザーに配信する場合、Googleの広告ポリシー上UMP(User Messaging
//   Platform)による同意取得フローが事実上必須。UMPConsentInformation自身が端末の地域を
//   判定し、対象地域以外では同意フォームを一切出さない（呼び出し側で地域を絞り込む必要はない）。
//   GADMobileAds.start()は同意状況が確定してから呼ぶのがGoogle公式の推奨手順のため、
//   AppDelegateの起動時ではなくここで呼ぶように移した
enum ConsentManager {

    // ★ ATTと同じくメイン画面が表示され落ち着いてから呼ぶ想定（AppRootView側で制御）
    static func requestConsentAndStartAdsIfNeeded(from viewController: UIViewController) {
        let parameters = UMPRequestParameters()
        // ★ 2026/08/16更新：ProfileSetupViewの導入により、13歳未満のユーザーは
        //   オンボーディング時点でブロックされ、本アプリを継続利用できない
        //   （Road 画面/AppRootView.swift参照）。この同意取得・広告配信フロー自体、
        //   年齢確認を通過済み(hasCompletedOnboarding==true)のユーザーにしか
        //   呼ばれないルートなので、falseで問題ない
        parameters.tagForUnderAgeOfConsent = false

        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { error in
            if let error {
                print("🔥 UMP requestConsentInfoUpdate error:", error.localizedDescription)
                // ★ 同意情報の取得自体に失敗しても、既存の挙動を壊さないよう
                //   AdMob SDK自体は起動しておく（起動しないと広告が一切出せなくなる）
                startGoogleMobileAdsIfPossible()
                return
            }

            UMPConsentForm.loadAndPresentIfRequired(from: viewController) { formError in
                if let formError {
                    print("🔥 UMP loadAndPresentIfRequired error:", formError.localizedDescription)
                }
                startGoogleMobileAdsIfPossible()
            }
        }
    }

    private static func startGoogleMobileAdsIfPossible() {
        guard UMPConsentInformation.sharedInstance.canRequestAds else { return }
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
}
