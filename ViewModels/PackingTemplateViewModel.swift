//
//  PackingTemplateViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/04.
//

import Foundation
import Combine
import FirebaseFirestore

// ★ 持ち物テンプレート機能。他のuid絞り込みViewModel群と同じ構成
//   （トップレベルコレクション＋uidで絞り込み、whereField単独のみで複合インデックスを避ける）
final class PackingTemplateViewModel: ObservableObject {

    @Published private(set) var templates: [PackingTemplate] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private var retryDelay: TimeInterval = 1
    private let maxRetryDelay: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    private var templatesCollection: CollectionReference {
        db.collection("packingTemplates")
    }

    func startListening(uid: String) {
        listener?.remove()
        listener = templatesCollection
            .whereField("uid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    print("🔥 持ち物テンプレート 購読エラー:", error)
                    self.scheduleRetry(uid: uid)
                    return
                }

                let newTemplates = (snapshot?.documents.compactMap { self.decode($0) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                self.retryDelay = 1

                DispatchQueue.main.async {
                    self.templates = newTemplates
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

    private func decode(_ doc: QueryDocumentSnapshot) -> PackingTemplate? {
        let d = doc.data()
        guard let uid = d["uid"] as? String,
              let name = d["name"] as? String,
              let items = d["items"] as? [String],
              let createdAt = (d["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return PackingTemplate(id: doc.documentID, uid: uid, name: name, items: items, createdAt: createdAt)
    }

    // MARK: - 追加・削除

    // ★ 2026/08/11修正：以前は呼び出し元（PackingTemplateManagerView）がtemplates配列
    //   （リスナー経由のローカルキャッシュ）の件数だけを見て上限チェックしていたため、
    //   リスナーの反映が追いついていないタイミング（別端末で追加した直後等）に上限を
    //   すり抜けられる可能性があった。static saveと同じく、保存直前にFirestoreへ
    //   件数を問い合わせるサーバー基準のチェックに統一する
    func addTemplate(uid: String, name: String, items: [String], completion: ((Error?) -> Void)? = nil) {
        Self.save(uid: uid, name: name, items: items, completion: completion)
    }

    func deleteTemplate(_ template: PackingTemplate, completion: ((Error?) -> Void)? = nil) {
        templatesCollection.document(template.id).delete { error in
            if let error { print("🔥 deleteTemplate error:", error) }
            completion?(error)
        }
    }

    // ★ 既存テンプレートの名前・アイテムを変更する（アイテムの追加・削除もこれで完結する。
    //   itemsを丸ごと差し替えるだけなので、呼び出し側で編集後の配列を組み立てて渡す）
    func updateTemplate(_ template: PackingTemplate, name: String, items: [String], completion: ((Error?) -> Void)? = nil) {
        templatesCollection.document(template.id).updateData([
            "name": name,
            "items": items
        ]) { error in
            if let error { print("🔥 updateTemplate error:", error) }
            completion?(error)
        }
    }

    // ★ 投稿の持ち物リストを他ユーザーが自分のテンプレートとして保存するときに使う、
    //   スタンドアロンの保存関数（このViewModelのlistener購読の有無に関係なく呼べる）。
    //   この経路はlistener購読していないタイミングでも呼ばれるため、保存前に一度だけ
    //   件数を数えて上限をチェックする(addTemplateはtemplates配列を使って呼び出し側でチェックする)
    static func save(uid: String, name: String, items: [String], completion: ((Error?) -> Void)? = nil) {
        let collection = Firestore.firestore().collection("packingTemplates")
        collection.whereField("uid", isEqualTo: uid).getDocuments { snapshot, error in
            if let error {
                completion?(error)
                return
            }
            let limit = SubscriptionManager.shared.packingTemplateLimit
            if (snapshot?.documents.count ?? 0) >= limit {
                completion?(PackingTemplateError.limitReached(limit: limit))
                return
            }

            let data: [String: Any] = [
                "uid": uid,
                "name": name,
                "items": items,
                "createdAt": Timestamp(date: Date())
            ]
            collection.addDocument(data: data) { error in
                if let error { print("🔥 PackingTemplate save error:", error) }
                completion?(error)
            }
        }
    }
}

enum PackingTemplateError: LocalizedError {
    case limitReached(limit: Int)

    var errorDescription: String? {
        switch self {
        case .limitReached(let limit):
            return "持ち物テンプレートは\(limit)件まで保存できます。もっと保存するにはプレミアムにアップグレードしてください。"
        }
    }
}
