//
//  GroupDetailEditView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct GroupDetailEditView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel

    let group: IdolGroup

    @State private var reading: String = ""
    @State private var fandom: String = ""
    @State private var concept: String = ""
    @State private var history: String = ""
    @State private var description: String = ""

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("詳細カードを編集")
                    .font(.title2)
                    .bold()

                Group {
                    TextField("読み方（例：ハートトゥーハーツ）", text: $reading)
                    TextField("ファンダム名（例：H2H）", text: $fandom)
                    TextField("コンセプト", text: $concept)
                    TextField("歴史", text: $history)
                    TextField("説明", text: $description)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Button(action: saveDetail) {
                    Text("保存する")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            // 既存データを初期値に反映
            reading = group.reading ?? ""
            fandom = group.fandom ?? ""
            concept = group.concept ?? ""
            history = group.history ?? ""
            description = group.groupDescription ?? ""
        }
        .navigationTitle("詳細カード編集")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveDetail() {
        let updated = IdolGroup(
            id: group.id,
            name: group.name,
            imageData: group.imageData,
            reading: reading.isEmpty ? nil : reading,
            fandom: fandom.isEmpty ? nil : fandom,
            concept: concept.isEmpty ? nil : concept,
            history: history.isEmpty ? nil : history,
            groupDescription: description.isEmpty ? nil : description,
            createdAt: group.createdAt
        )

        groupViewModel.updateGroup(updated)
        dismiss()
    }
}

