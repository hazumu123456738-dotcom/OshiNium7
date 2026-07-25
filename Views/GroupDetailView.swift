//
//  GroupDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/19.
//

import SwiftUI

struct GroupDetailView: View {
    let group: IdolGroup

    // 詳細が1つでもあるかどうか
    private var hasDetail: Bool {
        group.reading != nil ||
        group.fandom != nil ||
        group.concept != nil ||
        group.history != nil ||
        group.groupDescription != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // --- グループ画像（imageData 対応） ---
                if let data = group.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .padding(.bottom, 10)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(group.name.prefix(2))
                                .font(.title)
                                .foregroundColor(.gray)
                        )
                        .padding(.bottom, 10)
                }

                // グループ名
                Text(group.name)
                    .font(.largeTitle)
                    .bold()

                Divider()

                if !hasDetail {
                    // 🔹 詳細カードが未設定の場合
                    Text("このグループはまだ詳細カードが設定されていません。")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                } else {
                    // 🔹 詳細カードが設定されている場合

                    // 読み方
                    if let reading = group.reading {
                        Text("読み方：\(reading)")
                            .font(.title3)
                    }

                    // ファンダム名
                    if let fandom = group.fandom {
                        Text("ファンダム名：\(fandom)")
                            .font(.title3)
                    }

                    // コンセプト
                    if let concept = group.concept {
                        Text("コンセプト")
                            .font(.headline)
                            .padding(.top, 8)
                        Text(concept)
                    }

                    // 歴史
                    if let history = group.history {
                        Text("歴史")
                            .font(.headline)
                            .padding(.top, 8)
                        Text(history)
                    }

                    // 説明
                    if let desc = group.groupDescription {
                        Text("説明")
                            .font(.headline)
                            .padding(.top, 8)
                        Text(desc)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("グループ詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}
