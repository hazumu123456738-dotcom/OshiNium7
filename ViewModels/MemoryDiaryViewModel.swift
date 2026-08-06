//
//  MemoryDiaryViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import Foundation
import Combine
import UIKit
import FirebaseFirestore

// ★ 思い出日記。OshiExpenseViewModelと同じ構成
//   （トップレベルコレクション＋uidで絞り込み、whereField単独のみで複合インデックスを避ける）
final class MemoryDiaryViewModel: ObservableObject {

    @Published private(set) var entries: [MemoryDiaryEntry] = []
    @Published var isSaving = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var diariesCollection: CollectionReference {
        db.collection("memoryDiaries")
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = diariesCollection
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("🔥 思い出日記 購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let loaded = snapshot?.documents.compactMap { self.decode($0) } ?? []
                self.retryDelay = 1

                DispatchQueue.main.async {
                    // ★ 新しい日付が上に来るように並べる
                    self.entries = loaded.sorted { $0.date > $1.date }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func scheduleRetry(uid: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListening(uid: uid)
        }
    }

    private func decode(_ doc: QueryDocumentSnapshot) -> MemoryDiaryEntry? {
        let d = doc.data()
        guard let uid = d["uid"] as? String,
              let groupId = d["groupId"] as? String,
              let date = (d["date"] as? Timestamp)?.dateValue(),
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return MemoryDiaryEntry(
            id: doc.documentID,
            uid: uid,
            groupId: groupId,
            date: date,
            text: d["text"] as? String ?? "",
            imageURLs: d["imageURLs"] as? [String] ?? [],
            createdAt: createdAt
        )
    }

    // MARK: - 保存（画像アップロード込み）

    func save(
        uid: String,
        groupId: String,
        date: Date,
        text: String,
        images: [UIImage],
        completion: ((Error?) -> Void)? = nil
    ) {
        isSaving = true

        Task {
            do {
                var imageURLs: [String] = []
                for image in images {
                    let url = try await ImageStorageService.shared.uploadDiaryImage(image, uid: uid)
                    imageURLs.append(url)
                }

                let data: [String: Any] = [
                    "uid": uid,
                    "groupId": groupId,
                    "date": Timestamp(date: date),
                    "text": text,
                    "imageURLs": imageURLs,
                    "createdAt": Timestamp(date: Date())
                ]

                try await diariesCollection.addDocument(data: data)

                await MainActor.run {
                    isSaving = false
                    completion?(nil)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    completion?(error)
                }
            }
        }
    }

    func delete(_ entry: MemoryDiaryEntry, completion: ((Error?) -> Void)? = nil) {
        diariesCollection.document(entry.id).delete { error in
            completion?(error)
        }
    }

    // ★ グループ横断で購読しているentriesのうち、指定グループだけに絞る
    func entries(groupId: String) -> [MemoryDiaryEntry] {
        entries.filter { $0.groupId == groupId }
    }
}
