//
//  CrashReportManager.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import Foundation
import FirebaseCrashlytics

// ★ Firebase Crashlyticsへの薄いラッパー（AnalyticsManagerと同じ考え方）。
//   クラッシュ自体はSDKをリンクした時点で自動収集されるため、ここでは
//   「誰が」「何をしている時に」起きたかを後から追えるようにするための
//   付加情報（ユーザーID・パンくず・非致命的エラー）だけを担当する
enum CrashReportManager {

    // ★ サインイン状態が変わるたびに呼ぶ。クラッシュレポート上で
    //   「どのユーザーで起きたか」を突き合わせられるようにする（個人情報はuidのみ）
    static func setUserId(_ uid: String?) {
        Crashlytics.crashlytics().setUserID(uid ?? "")
    }

    // ★ クラッシュ発生直前の状況を追うためのパンくずログ
    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    // ★ クラッシュには至らないが握りつぶさずに記録しておきたいエラー
    //   （アップロード失敗など、doで復帰できるがユーザー体験には影響しているもの）
    static func recordNonFatal(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
