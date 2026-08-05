//
//  DMThreadListViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import Combine
import FirebaseFirestore

final class DMThreadListViewModel: ObservableObject {

    @Published private(set) var threads: [DMThread] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var threadsCollection: CollectionReference {
        db.collection("dmThreads")
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = threadsCollection
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 DMスレッド購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let loaded: [DMThread] = (snapshot?.documents ?? []).compactMap { doc in
                    let data = doc.data()
                    guard let participants = data["participants"] as? [String],
                          let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue()
                    else { return nil }

                    return DMThread(
                        id: doc.documentID,
                        participants: participants,
                        lastMessage: data["lastMessage"] as? String ?? "",
                        lastMessageAt: lastMessageAt,
                        lastSenderUid: data["lastSenderUid"] as? String
                    )
                }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.threads = loaded.sorted { $0.lastMessageAt > $1.lastMessageAt }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        threads = []
    }

    private func scheduleRetry(uid: String) {
        listener?.remove()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, maxRetryDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startListening(uid: uid)
        }
    }
}
