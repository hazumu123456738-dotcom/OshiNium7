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

    // ★ 「会場口コミ」で実際に参加した人だからこそ分かる情報が蓄積されるよう、
    //   よく書かれる観点をワンタップで#ハッシュタグとして挿入できるようにする。
    //   セトリ投稿では使わないため口コミ(review)のときだけ出す
    private let suggestedTags = ["入場ゲート", "座席の見え方", "音響ステージ", "混雑状況", "トイレ売店", "規制退場", "周辺情報"]

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

                if kind == "review" {
                    suggestedTagsRow
                }

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

    private var suggestedTagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedTags, id: \.self) { tag in
                    Button {
                        insertTag(tag)
                    } label: {
                        Label("#\(tag)", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accentColor.opacity(0.1)))
                    }
                }
            }
        }
    }

    // ★ 既に本文に含まれるタグは重複挿入しない。文末に半角スペース区切りで追記する
    private func insertTag(_ tag: String) {
        let hashtag = "#\(tag)"
        guard !text.contains(hashtag) else { return }
        if text.isEmpty || text.hasSuffix(" ") || text.hasSuffix("\n") {
            text += hashtag
        } else {
            text += " \(hashtag)"
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
