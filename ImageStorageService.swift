//
//  ImageStorageService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/03.
//

import Foundation
import FirebaseStorage
import UIKit

final class ImageStorageService {

    static let shared = ImageStorageService()
    private init() {}

    // 🔥 テスト用：firebasestorage.app を使う
    private let storage = Storage.storage(url: "gs://oshinium-79256.firebasestorage.app")

    // MARK: - 画像アップロード（イベント用）
    func uploadEventImage(_ image: UIImage, eventId: String) async throws -> String {

        let resized = image.resized(maxDimension: 1200)

        // 画像データ変換
        guard let imageData = resized.jpegData(compressionQuality: 0.9) ??
                              resized.pngData() else {
            print("❌ ImageStorageService: 画像データ変換に失敗")
            throw NSError(domain: "ImageStorageService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "画像データの変換に失敗しました"
            ])
        }

        print("DEBUG Storage: imageData size =", imageData.count, "bytes")

        // Storage パス: events/eventId/uuid.png
        let fileName = UUID().uuidString + ".png"
        let ref = storage.reference()
            .child("events")
            .child(eventId)
            .child(fileName)

        print("DEBUG Storage: upload path =", "events/\(eventId)/\(fileName)")

        // アップロード
        let metadata = StorageMetadata()
        metadata.contentType = "image/png"

        do {
            let meta = try await ref.putDataAsync(imageData, metadata: metadata)
            print("DEBUG Storage: putDataAsync success, size =", meta.size)
        } catch {
            print("❌ Storage putDataAsync error:", error)
            throw error
        }

        // ダウンロードURL取得
        do {
            let url = try await ref.downloadURL()
            print("DEBUG Storage: downloadURL =", url.absoluteString)
            return url.absoluteString
        } catch {
            print("❌ Storage downloadURL error:", error)
            throw error
        }
    }

    // MARK: - 画像アップロード（プロフィール用）
    func uploadProfileImage(_ image: UIImage, uid: String) async throws -> String {

        let resized = image.resized(maxDimension: 1200)

        guard let imageData = resized.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageStorageService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "画像データの変換に失敗しました"
            ])
        }

        let fileName = UUID().uuidString + ".jpg"
        let ref = storage.reference()
            .child("profileImages")
            .child(uid)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - 画像アップロード（チャット用）
    func uploadChatImage(_ image: UIImage, groupId: String) async throws -> String {

        let resized = image.resized(maxDimension: 1600)

        guard let imageData = resized.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "ImageStorageService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "画像データの変換に失敗しました"
            ])
        }

        let fileName = UUID().uuidString + ".jpg"
        let ref = storage.reference()
            .child("chatMedia")
            .child(groupId)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - 動画アップロード（チャット用）
    func uploadChatVideo(fileURL: URL, groupId: String) async throws -> String {

        let videoData = try Data(contentsOf: fileURL)

        let fileName = UUID().uuidString + ".mov"
        let ref = storage.reference()
            .child("chatMedia")
            .child(groupId)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"

        _ = try await ref.putDataAsync(videoData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - 画像アップロード（投稿用）
    func uploadPostImage(_ image: UIImage, uid: String) async throws -> String {

        let resized = image.resized(maxDimension: 1600)

        guard let imageData = resized.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageStorageService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "画像データの変換に失敗しました"
            ])
        }

        let fileName = UUID().uuidString + ".jpg"
        let ref = storage.reference()
            .child("postMedia")
            .child(uid)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - 画像アップロード（思い出日記用）

    func uploadDiaryImage(_ image: UIImage, uid: String) async throws -> String {

        let resized = image.resized(maxDimension: 1600)

        guard let imageData = resized.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "ImageStorageService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "画像データの変換に失敗しました"
            ])
        }

        let fileName = UUID().uuidString + ".jpg"
        let ref = storage.reference()
            .child("diaryMedia")
            .child(uid)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - 動画アップロード（投稿用）
    func uploadPostVideo(fileURL: URL, uid: String) async throws -> String {

        let videoData = try Data(contentsOf: fileURL)

        let fileName = UUID().uuidString + ".mov"
        let ref = storage.reference()
            .child("postMedia")
            .child(uid)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"

        _ = try await ref.putDataAsync(videoData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - 画像削除
    func deleteEventImage(eventId: String, fileName: String) async throws {
        let ref = storage.reference()
            .child("events")
            .child(eventId)
            .child(fileName)

        try await ref.delete()
    }
}

// MARK: - アスペクト比を維持したリサイズ（正方形に強制しない）
extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

//
// MARK: - Firebase Storage async/await 拡張
//
extension StorageReference {

    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            self.putData(uploadData, metadata: metadata) { meta, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let meta = meta {
                    continuation.resume(returning: meta)
                } else {
                    continuation.resume(throwing: NSError(domain: "Storage", code: -1))
                }
            }
        }
    }

    func downloadURL() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.downloadURL { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "Storage", code: -1))
                }
            }
        }
    }
}
