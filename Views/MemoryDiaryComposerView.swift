//
//  MemoryDiaryComposerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

// ★ カレンダーの日付長押し「思い出日記をつける」から開く、文章＋画像（任意・複数枚）の
//   日記エントリ作成画面
struct MemoryDiaryComposerView: View {

    let date: Date
    let group: IdolGroup

    @ObservedObject var diaryViewModel: MemoryDiaryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideoURLs: [URL] = []
    @State private var isLoadingImages = false
    @State private var errorMessage: String?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2
    private let maxMediaItems = 6
    private let maxVideoBytes = 50 * 1024 * 1024
    private var mediaCount: Int { selectedImages.count + selectedVideoURLs.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                        Text("今日の推し活を記録しよう")
                            .font(.system(size: 18, weight: .bold))
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 15))
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.appCardBackground)
                        )
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("どんな一日だった？（任意）")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    imageSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }

                    saveButton
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("思い出日記")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                loadImages(newItems)
            }
        }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return "\(group.name) ・ \(f.string(from: date))"
    }

    // MARK: - 写真・動画

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("写真・動画（任意）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if mediaCount < maxMediaItems {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: maxMediaItems - mediaCount,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("追加", systemImage: "photo.on.rectangle.angled")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                }
            }

            if isLoadingImages {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if mediaCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            mediaThumbnail(isVideo: false) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } onDelete: {
                                selectedImages.remove(at: index)
                            }
                        }
                        ForEach(Array(selectedVideoURLs.enumerated()), id: \.offset) { index, _ in
                            mediaThumbnail(isVideo: true) {
                                Color.black
                            } onDelete: {
                                selectedVideoURLs.remove(at: index)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaThumbnail<Content: View>(
        isVideo: Bool,
        @ViewBuilder content: () -> Content,
        onDelete: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 110, height: 110)
                    .allowsHitTesting(false)
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.black.opacity(0.55), in: Circle())
            }
            .padding(6)
            .accessibilityLabel(isVideo ? "この動画を削除" : "この写真を削除")
        }
    }

    private func loadImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoadingImages = true

        Task {
            var loadedImages: [UIImage] = []
            var loadedVideoURLs: [URL] = []

            for item in items {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                if isVideo {
                    if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                        let attributes = try? FileManager.default.attributesOfItem(atPath: movie.url.path)
                        let size = attributes?[.size] as? Int
                        if let size, size > maxVideoBytes {
                            await MainActor.run {
                                errorMessage = "動画のサイズが大きすぎます（50MBまで）。短い動画を選んでください。"
                            }
                        } else {
                            loadedVideoURLs.append(movie.url)
                        }
                    }
                } else if let data = try? await item.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) {
                    loadedImages.append(uiImage)
                }
            }

            await MainActor.run {
                selectedImages.append(contentsOf: loadedImages)
                selectedVideoURLs.append(contentsOf: loadedVideoURLs)
                if mediaCount > maxMediaItems {
                    let overflow = mediaCount - maxMediaItems
                    if overflow > 0 {
                        selectedVideoURLs = Array(selectedVideoURLs.dropLast(min(overflow, selectedVideoURLs.count)))
                    }
                }
                pickerItems = []
                isLoadingImages = false
            }
        }
    }

    // MARK: - 保存

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mediaCount > 0
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 6) {
                if diaryViewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "book.closed.fill")
                }
                Text(diaryViewModel.isSaving ? "保存しています…" : "日記を保存")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                (canSave && !diaryViewModel.isSaving)
                    ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.gray.opacity(0.35))
            )
            .clipShape(Capsule())
        }
        .disabled(!canSave || diaryViewModel.isSaving)
    }

    private func save() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        errorMessage = nil

        diaryViewModel.save(
            uid: uid,
            groupId: group.id,
            date: date,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            images: selectedImages,
            videoURLs: selectedVideoURLs
        ) { error in
            if let error {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                return
            }
            dismiss()
        }
    }
}
