//
//  SNSPlatform.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI

// ★ ユーザーが登録したSNSリンク（URL文字列）から、どのサービスかを推定して
//   ブランドカラー・アイコンで表示するためのヘルパー。
//   モデル側は既存の snsLinks: [String] のまま（マイグレーション不要）。
enum SNSPlatform: CaseIterable {
    case instagram, x, tiktok, youtube, threads, line, other

    static func detect(from urlString: String) -> SNSPlatform {
        let lower = urlString.lowercased()
        if lower.contains("instagram.com") { return .instagram }
        if lower.contains("tiktok.com") { return .tiktok }
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("threads.net") { return .threads }
        if lower.contains("line.me") || lower.contains("lin.ee") { return .line }
        if lower.contains("twitter.com") || lower.contains("x.com") { return .x }
        return .other
    }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .x: return "X"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .threads: return "Threads"
        case .line: return "LINE"
        case .other: return "リンク"
        }
    }

    var symbolName: String {
        switch self {
        case .instagram: return "camera.fill"
        case .x: return "xmark"
        case .tiktok: return "music.note"
        case .youtube: return "play.fill"
        case .threads: return "at"
        case .line: return "bubble.fill"
        case .other: return "link"
        }
    }

    /// バッジ背景。Instagramのみグラデーション、それ以外は単色。
    var badgeGradient: [Color] {
        switch self {
        case .instagram:
            return [
                Color(red: 0.96, green: 0.62, blue: 0.20),
                Color(red: 0.86, green: 0.24, blue: 0.48),
                Color(red: 0.52, green: 0.20, blue: 0.78)
            ]
        case .x:
            return [Color.black, Color.black]
        case .tiktok:
            return [Color.black, Color(red: 0.1, green: 0.1, blue: 0.12)]
        case .youtube:
            return [Color(red: 0.94, green: 0.13, blue: 0.13), Color(red: 0.80, green: 0.08, blue: 0.08)]
        case .threads:
            return [Color.black, Color.black]
        case .line:
            return [Color(red: 0.02, green: 0.78, blue: 0.33), Color(red: 0.0, green: 0.66, blue: 0.28)]
        case .other:
            return [Color.gray.opacity(0.7), Color.gray.opacity(0.5)]
        }
    }

    var iconShape: AnyShape {
        switch self {
        case .youtube, .line:
            return AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        default:
            return AnyShape(Circle())
        }
    }
}

// RoundedRectangle と Circle を同じ型として扱うための薄いラッパー
struct AnyShape: Shape {
    private let pathBuilder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in shape.path(in: rect) }
    }
    func path(in rect: CGRect) -> Path { pathBuilder(rect) }
}

// MARK: - バッジアイコン（共通コンポーネント）
struct SNSBadgeIcon: View {
    let platform: SNSPlatform
    var size: CGFloat = 36

    var body: some View {
        platform.iconShape
            .fill(
                LinearGradient(
                    colors: platform.badgeGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if platform == .x {
                        Text("𝕏")
                            .font(.system(size: size * 0.46, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: platform.symbolName)
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            )
    }
}
