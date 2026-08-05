//
//  RecommendedGroupRowView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

// ★ 全ユーザー共通カタログ（/groups）に載っている、まだ参加していないグループの一覧行。
//   タップで参加（selectedGroups に追加）できる。
struct RecommendedGroupRowView: View {

    let group: IdolGroup
    var onJoin: () -> Void = {}

    @State private var isJoining = false

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)
    private let accentColor2 = Color(red: 0.90, green: 0.60, blue: 0.95)

    var body: some View {
        HStack(spacing: 16) {

            if let data = group.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(colors: [accentColor, accentColor2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(group.name.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .foregroundColor(.primary)
                    .font(.system(size: 15, weight: .semibold))
                if let fandom = group.fandom, !fandom.isEmpty {
                    Text(fandom)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                isJoining = true
                onJoin()
            } label: {
                if isJoining {
                    ProgressView()
                        .frame(width: 60, height: 28)
                } else {
                    Text("参加する")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(colors: [accentColor, accentColor2],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
            }
            .disabled(isJoining)
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}
