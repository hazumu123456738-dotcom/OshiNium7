//
//  AppThemeMode.swift
//  OshiNium7
//

import SwiftUI

// ★ 設定画面「🎨 アプリ」のテーマ切り替え。デバイス単位の見た目設定なので
//   Firestoreには同期せず@AppStorage（UserDefaults）にだけ保存する
enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "システムに合わせる"
        case .light: return "ライト"
        case .dark: return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static let storageKey = "appThemeMode"
}
