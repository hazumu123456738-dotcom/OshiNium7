//
//  GroupDetailCardView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct GroupDetailCardView: View {

    let group: IdolGroup

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - グループ画像
                if let data = group.imageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .padding(.top, 20)
                }

                // MARK: - グループ名
                Text(group.name)
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 10)

                Divider()

                // MARK: - 詳細カードが未設定の場合
                if group.reading == nil &&
                    group.fandom == nil &&
                    group.concept == nil &&
                    group.history == nil &&
                    group.groupDescription == nil {

                    VStack(alignment: .leading, spacing: 12) {
                        Text("このグループはまだ詳細カードが設定されていません。")
                            .font(.body)
                            .foregroundColor(.secondary)

                        NavigationLink {
                            GroupDetailEditView(group: group)
                        } label: {
                            Text("詳細カードを設定する")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal)

                } else {

                    // MARK: - 詳細カードがある場合
                    VStack(alignment: .leading, spacing: 16) {

                        if let reading = group.reading {
                            Text("読み方：\(reading)")
                        }

                        if let fandom = group.fandom {
                            Text("ファンダム名：\(fandom)")
                        }

                        if let concept = group.concept {
                            Text("コンセプト：\(concept)")
                        }

                        if let history = group.history {
                            Text("歴史：\(history)")
                        }

                        if let desc = group.groupDescription {
                            Text("説明：\(desc)")
                        }

                        NavigationLink {
                            GroupDetailEditView(group: group)
                        } label: {
                            Text("詳細カードを編集する")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .navigationTitle("グループ詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}
