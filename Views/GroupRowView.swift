//
//  GroupRowView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct GroupRowView: View {

    let group: IdolGroup

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    var body: some View {
        NavigationLink {
            GroupStatusView(group: group)   // ← 遷移先をステータス画面に変更
        } label: {
            HStack(spacing: 14) {

                // MARK: - グループ画像（推しグループらしい、うっすら光るグラデーションの縁取り）
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [accentColor, accentColor2],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 54, height: 54)

                    if let data = group.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else {
                        Text(String(group.name.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // MARK: - グループ名
                Text(group.name)
                    .foregroundColor(.primary)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }
}
