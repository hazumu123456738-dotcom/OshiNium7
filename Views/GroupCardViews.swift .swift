//
//  GroupCardViews.swift .swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/19.
//

import SwiftUI

struct GroupCard: View {
    let group: IdolGroup
    let isSelected: Bool
    @State private var showDetail = false

    var body: some View {

        ZStack(alignment: .topTrailing) {

            VStack(spacing: 8) {

                // MARK: - 画像（imageData → UIImage → SwiftUI Image）
                if let data = group.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    // 画像がない場合のプレースホルダー
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Text(group.name)
                                .foregroundColor(.gray)
                        )
                }

                // MARK: - グループ名
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // MARK: - ファンダム名
                if let fandom = group.fandom {
                    Text(fandom)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 4)

            // MARK: - 詳細ボタン
            Button {
                showDetail = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
                    .padding(6)
            }

            // MARK: - 選択チェック
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.purple)
                    .padding(6)
            }
        }
        .sheet(isPresented: $showDetail) {
            GroupDetailView(group: group)
        }
    }
}
