//
//  EventCardView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/02.
//

import SwiftUI
import NukeUI   // ← 追加

struct EventCardView: View {

    let event: Event
    let groupName: String?
    let imageURLString: String?   // ← そのまま

    // MARK: - 色ルール（EventType）
    // ★ 2026/08/16修正：EventType.iconColorと重複定義していたため一本化する
    private var categoryColor: Color {
        (event.type ?? .other).iconColor
    }

    // ★ 2026/08/15修正：EventType.displayNameと重複定義しており、"テレビ"/"出演・放送"の
    //   ようにラベルが食い違っていたため一本化する
    private var categoryText: String {
        (event.type ?? .other).displayName
    }

    private var displayGroupName: String {
        groupName ?? "イベント"
    }

    var body: some View {
        HStack(spacing: 14) {

            // MARK: - 左：画像 or プレースホルダー
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))

                if let urlString = imageURLString,
                   let url = URL(string: urlString) {

                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 150)
                                .clipped()
                        } else {
                            placeholderView
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                } else {
                    placeholderView
                }
            }
            .frame(width: 110, height: 150)

            // MARK: - 中央テキスト
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

                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer().frame(height: 6)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(CachedFormatters.date(format: "yyyy/M/d").string(from: event.date))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                if let place = event.place {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
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
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    // MARK: - プレースホルダー
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
                    .accessibilityHidden(true)

                Text(categoryText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        .frame(width: 110, height: 150)
    }
}
