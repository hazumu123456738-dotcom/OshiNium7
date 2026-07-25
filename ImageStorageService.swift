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

        // 画像データ変換
        guard let imageData = image.jpegData(compressionQuality: 0.9) ??
                              image.pngData() else {
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

    // MARK: - 画像削除
    func deleteEventImage(eventId: String, fileName: String) async throws {
        let ref = storage.reference()
            .child("events")
            .child(eventId)
            .child(fileName)

        try await ref.delete()
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
