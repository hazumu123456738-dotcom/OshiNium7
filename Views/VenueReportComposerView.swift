//
//  VenueReportComposerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import FirebaseAuth

// ★ 「会場の口コミ」「その日のセトリ」の投稿シート。
//   投稿とは違い匿名掲載のため、名前・アイコンの入力は一切ない
struct VenueReportComposerView: View {

    let title: String
    let placeholder: String
    let kind: String
    let eventId: String
    let groupId: String
    let accentColor: Color
    let onSubmitted: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isSubmitting = false

    private let maxLength = 300

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Label("匿名で投稿されます。名前やアイコンは表示されません", systemImage: "eye.slash.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accentColor.opacity(0.08))
                    )

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.top, 10)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 14))
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )

                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)

                Button {
                    submit()
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "投稿しています…" : "匿名で投稿する")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(accentColor, in: Capsule())
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxLength
    }

    private func submit() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        onSubmitted(trimmed, uid)
        dismiss()
    }
}
