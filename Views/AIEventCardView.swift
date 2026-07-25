//
//  AIEventCardView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/21.
//

import SwiftUI

struct AIEventCardView: View {

    let result: AIEventResult
    let groupName: String?
    let imageURL: URL?

    // MARK: - カテゴリ判定
    private var categoryText: String {
        // tags は [String] 非Optionalなので ? は不要、first は Optional
        let tag = result.tags.first?.lowercased() ?? ""

        if tag.contains("live") || tag.contains("ライブ") { return "ライブ" }
        if tag.contains("fan") || tag.contains("ミーティング") { return "ファンミーティング" }
        if tag.contains("tv") || tag.contains("テレビ") { return "テレビ" }
        if tag.contains("release") || tag.contains("リリース") { return "リリース" }
        if tag.contains("event") || tag.contains("イベント") { return "イベント" }

        return "その他"
    }

    private var categoryColor: Color {
        switch categoryText {
        case "ライブ": return Color.purple
        case "ファンミーティング": return Color.pink
        case "テレビ": return Color.blue
        case "リリース": return Color.green
        case "イベント": return Color.orange
        default: return Color.gray
        }
    }

    private var displayGroupName: String {
        groupName ?? "イベント"
    }

    private var displayEventTitle: String {
        if let g = groupName, result.title.hasPrefix(g) {
            return result.title
                .replacingOccurrences(of: g, with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        return result.title
    }

    // MARK: - UI
    var body: some View {
        HStack(spacing: 14) {

            // 左：画像 or プレースホルダー
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))

                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().scaleEffect(0.8)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 150)
                                .clipped()

                        case .failure:
                            placeholderView

                        @unknown default:
                            placeholderView
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    placeholderView
                }
            }
            .frame(width: 110, height: 150)

            // 中央テキスト
            VStack(alignment: .leading, spacing: 8) {

                Text(categoryText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(categoryColor))

                Text(displayGroupName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(displayEventTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer().frame(height: 6)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(result.dateString)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                if let place = result.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(place)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.trailing, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    // MARK: - プレースホルダー（画像なし時）
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [categoryColor.opacity(0.7), categoryColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                Text(categoryText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .frame(width: 110, height: 150)
    }
}
