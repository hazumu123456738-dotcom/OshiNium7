//
//  PackingTemplateManagerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import SwiftUI
import FirebaseAuth

// ★ 持ち物チェックリストの「マイテンプレート」管理画面。日付に紐付けない
//   「よく持っていくものセット」を保存しておき、①選択中の日にまとめて追加する、
//   ②そのまま投稿として共有する、の2つの使い方ができる
struct PackingTemplateManagerView: View {

    // ★ 「この日に追加」を押したときに、テンプレートの持ち物をどの日付へ追加するか
    let targetDate: Date
    // ★ 追加が終わったら呼ばれる（PackingChecklistView側でchecklistVM.addItemを実行してもらう）
    let onAddToDay: ([String]) -> Void

    @StateObject private var templateVM = PackingTemplateViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSheet = false
    @State private var selectedTemplate: PackingTemplate?

    private let accentColor = Color(red: 0.40, green: 0.72, blue: 0.55)
    private let accentColor2 = Color(red: 0.55, green: 0.82, blue: 0.60)
    private var myUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if templateVM.templates.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 10) {
                            ForEach(templateVM.templates) { template in
                                templateRow(template)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("マイテンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("テンプレートを作る")
                }
            }
            .onAppear {
                if let myUid { templateVM.startListening(uid: myUid) }
            }
            .onDisappear { templateVM.stopListening() }
            .sheet(isPresented: $showCreateSheet) {
                CreatePackingTemplateView(templateVM: templateVM, accentColor: accentColor, accentColor2: accentColor2)
            }
            .sheet(item: $selectedTemplate) { template in
                PackingTemplateDetailSheet(
                    template: template,
                    targetDate: targetDate,
                    accentColor: accentColor,
                    accentColor2: accentColor2,
                    onAddToDay: {
                        onAddToDay(template.items)
                        selectedTemplate = nil
                        dismiss()
                    }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
                .accessibilityHidden(true)
            Text("まだテンプレートがありません")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("よく持っていくものセットを保存しておくと、次の予定にまとめて追加したり、投稿として共有できます")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    private func templateRow(_ template: PackingTemplate) -> some View {
        Button {
            selectedTemplate = template
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accentColor.opacity(0.12))
                    Image(systemName: "checklist")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                        .accessibilityHidden(true)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(template.items.joined(separator: "・"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("削除", role: .destructive) {
                templateVM.deleteTemplate(template)
            }
        }
    }
}

// MARK: - テンプレート詳細（この日に追加する／投稿する）

private struct PackingTemplateDetailSheet: View {
    let template: PackingTemplate
    let targetDate: Date
    let accentColor: Color
    let accentColor2: Color
    let onAddToDay: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(template.items, id: \.self) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(accentColor.opacity(0.6))
                                    .accessibilityHidden(true)
                                Text(item)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    Button(action: onAddToDay) {
                        Text("\(dayLabel(targetDate))に追加する")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }

                    NavigationLink {
                        PackingTemplatePostView(template: template)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityHidden(true)
                            Text("投稿する")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().stroke(accentColor, lineWidth: 1.3))
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f.string(from: date)
    }
}

// MARK: - テンプレート作成フォーム

private struct CreatePackingTemplateView: View {
    @ObservedObject var templateVM: PackingTemplateViewModel
    let accentColor: Color
    let accentColor2: Color

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var itemTexts: [String] = [""]

    private var trimmedItems: [String] {
        itemTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !trimmedItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    nameCard
                    itemsCard
                    saveButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("テンプレートを作る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テンプレート名")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("例：遠征セット", text: $name)
                .font(.system(size: 17, weight: .semibold))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("持ち物")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(itemTexts.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("例：ペンライト", text: $itemTexts[index])
                            .font(.system(size: 14))

                        if itemTexts.count > 1 {
                            Button {
                                itemTexts.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .accessibilityLabel("この持ち物を削除")
                        }
                    }
                }
            }

            Button {
                itemTexts.append("")
            } label: {
                Label("持ち物を追加", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private var saveButton: some View {
        Button {
            guard let uid = Auth.auth().currentUser?.uid else { return }
            templateVM.addTemplate(uid: uid, name: name.trimmingCharacters(in: .whitespacesAndNewlines), items: trimmedItems)
            dismiss()
        } label: {
            Text("保存する")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .opacity(canSave ? 1 : 0.5)
        }
        .disabled(!canSave)
    }
}
