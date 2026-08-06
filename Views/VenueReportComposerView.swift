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
    // ★ text, uid, rating(1〜5・未選択ならnil), imageURL(未添付ならnil)
    let onSubmitted: (String, String, Int?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isSubmitting = false
    @State private var rating: Int = 0
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var uploadErrorText: String? = nil

    private let maxLength = 300

    // ★ 「会場口コミ」で実際に参加した人だからこそ分かる情報が蓄積されるよう、
    //   よく書かれる観点をワンタップで#ハッシュタグとして挿入できるようにする。
    //   セトリ投稿では使わないため口コミ(review)のときだけ出す
    private let suggestedTags = VenueReport.commonTags

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
                    ratingRow
                    imageAttachRow
                }

                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let uploadErrorText {
                    Text(uploadErrorText)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }

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

    // ★ 会場の評価（任意）。タップした星の数がそのままratingになる。もう一度同じ星をタップすると解除できる
    private var ratingRow: some View {
        HStack(spacing: 6) {
            Text("会場の評価（任意）")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = (rating == star) ? 0 : star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(star <= rating ? .orange : .secondary.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // ★ 会場の様子が伝わる写真を1枚だけ添付できる（任意）
    private var imageAttachRow: some View {
        HStack(spacing: 10) {
            Button {
                showImagePicker = true
            } label: {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor.opacity(0.08))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                                .foregroundColor(accentColor)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedImage == nil ? "写真を添付（任意）" : "写真を変更できます")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text("会場の様子が伝わる写真があれば添付できます")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            if selectedImage != nil {
                Button {
                    selectedImage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
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
        uploadErrorText = nil

        Task {
            var imageURL: String? = nil
            if let selectedImage {
                do {
                    imageURL = try await ImageStorageService.shared.uploadVenueReportImage(selectedImage, uid: uid)
                } catch {
                    await MainActor.run {
                        isSubmitting = false
                        uploadErrorText = "写真のアップロードに失敗しました。写真無しで投稿するか、もう一度お試しください"
                    }
                    return
                }
            }

            await MainActor.run {
                onSubmitted(trimmed, uid, rating > 0 ? rating : nil, imageURL)
                dismiss()
            }
        }
    }
}
