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
    @State private var category: GroupCategory? = nil

    // ★ フィールドごとに「AIで修正中」かどうかを持つ（他の項目を編集中でも待たされないように）
    @State private var refiningFields: Set<String> = []
    @State private var refineFailedField: String? = nil

    @Environment(\.dismiss) var dismiss

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                categoryCard
                fieldCard(key: "読み方", placeholder: "例：ハートトゥーハーツ", text: $reading)
                fieldCard(key: "ファンダム名", placeholder: "特になければ空欄のままでOK", text: $fandom)
                fieldCard(key: "コンセプト", placeholder: "特になければ空欄のままでOK", text: $concept, multiline: true)
                fieldCard(key: "歴史", placeholder: "特になければ空欄のままでOK", text: $history, multiline: true)
                fieldCard(key: "説明", placeholder: "特になければ空欄のままでOK", text: $description, multiline: true)

                Text("空欄の項目は詳細画面に「特になし」と表示されます。各項目の✨ボタンでAIに調べ直させることもできます。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                saveButton
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            reading = group.reading ?? ""
            fandom = group.fandom ?? ""
            concept = group.concept ?? ""
            history = group.history ?? ""
            description = group.groupDescription ?? ""
            category = group.category
        }
        .navigationTitle("詳細カードを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") { dismiss() }
            }
        }
    }

    // ★ 「会場口コミ」で同じカテゴリの他グループの口コミも見られるようにするための分類。
    //   この機能より前に作られたグループはカテゴリ未設定のことがあるため、ここで後から設定できるようにする
    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                spacing: 8
            ) {
                ForEach(GroupCategory.allCases) { item in
                    let isSelected = item == category
                    Button {
                        category = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(isSelected ? AnyShapeStyle(
                                    LinearGradient(colors: [accentColor, Color.oshiniumPrimary2],
                                                   startPoint: .leading, endPoint: .trailing)
                                ) : AnyShapeStyle(accentColor.opacity(0.1)))
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func fieldCard(key: String, placeholder: String, text: Binding<String>, multiline: Bool = false) -> some View {
        let isRefining = refiningFields.contains(key)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    refineField(key: key, currentText: text)
                } label: {
                    HStack(spacing: 4) {
                        if isRefining {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isRefining ? "調べています…" : "AIで修正")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .disabled(isRefining)
            }

            if multiline {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(3...8)
            } else {
                TextField(placeholder, text: text)
            }

            if refineFailedField == key {
                Text("情報が見つかりませんでした。表現を変えて手入力してみてください。")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
        .font(.system(size: 15))
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func refineField(key: String, currentText: Binding<String>) {
        guard !refiningFields.contains(key) else { return }
        refiningFields.insert(key)
        refineFailedField = nil

        let snapshot = currentText.wrappedValue

        Task {
            let result = await GroupInfoSearchService.shared.refineField(
                groupName: group.name,
                fieldLabel: key,
                currentValue: snapshot
            )

            await MainActor.run {
                refiningFields.remove(key)
                if let result {
                    currentText.wrappedValue = result
                } else {
                    refineFailedField = key
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: saveDetail) {
            Text("保存する")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [accentColor, Color.oshiniumPrimary2],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
        }
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
            createdAt: group.createdAt,
            category: category
        )

        groupViewModel.updateGroup(updated)
        dismiss()
    }
}
