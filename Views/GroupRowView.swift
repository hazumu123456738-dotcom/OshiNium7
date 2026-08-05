//
//  GroupRowView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct GroupRowView: View {

    let group: IdolGroup

    var body: some View {
        NavigationLink {
            GroupStatusView(group: group)   // ← 遷移先をステータス画面に変更
        } label: {
            HStack(spacing: 16) {

                // MARK: - グループ画像
                if let data = group.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 48, height: 48)
                }

                // MARK: - グループ名
                Text(group.name)
                    .foregroundColor(.primary)
                    .font(.body)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.appCardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
    }
}
