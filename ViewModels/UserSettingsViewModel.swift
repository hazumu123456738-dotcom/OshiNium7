//
//  UserSettingsViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/26.
//

import SwiftUI
import UIKit
import Combine
import FirebaseFirestore
import FirebaseAuth

class UserSettingsViewModel: ObservableObject {
    @Published var settings = UserSettings.empty
    @Published var isUploadingImage = false

    private var db = Firestore.firestore()

    func loadSettings() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                DispatchQueue.main.async {
                    self.settings = UserSettings(
                        displayName: data["displayName"] as? String ?? "",
                        bio: data["bio"] as? String ?? "",
                        iconURL: data["iconURL"] as? String ?? "",
                        birthday: data["birthday"] as? String ?? "",
                        snsLinks: data["snsLinks"] as? [String] ?? [],
                        defaultNotifyMinutes: data["defaultNotifyMinutes"] as? Int,
                        points: data["points"] as? Int ?? 0,
                        isPrivateAccount: data["isPrivateAccount"] as? Bool ?? false,
                        commentPermission: CommentPermission(rawValue: data["commentPermission"] as? String ?? "") ?? .everyone,
                        dmPermission: DMPermission(rawValue: data["dmPermission"] as? String ?? "") ?? .everyone,
                        liveNotifyEnabled: data["liveNotifyEnabled"] as? Bool ?? true,
                        chatNotifyEnabled: data["chatNotifyEnabled"] as? Bool ?? true,
                        followNotifyEnabled: data["followNotifyEnabled"] as? Bool ?? true,
                        postNotifyEnabled: data["postNotifyEnabled"] as? Bool ?? true
                    )
                }
            }
        }
    }

    // MARK: - プロフィール画像アップロード
    func uploadIcon(_ image: UIImage) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        await MainActor.run { isUploadingImage = true }

        do {
            let url = try await ImageStorageService.shared.uploadProfileImage(image, uid: uid)
            await MainActor.run {
                settings.iconURL = url
                isUploadingImage = false
            }
        } catch {
            print("❌ UserSettingsViewModel: アイコンアップロード失敗:", error)
            await MainActor.run { isUploadingImage = false }
        }
    }

    func saveSettings() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let data: [String: Any] = [
            "displayName": settings.displayName,
            "bio": settings.bio,
            "iconURL": settings.iconURL,
            "birthday": settings.birthday,
            "snsLinks": settings.snsLinks,
            "defaultNotifyMinutes": settings.defaultNotifyMinutes as Any,
            "isPrivateAccount": settings.isPrivateAccount,
            "commentPermission": settings.commentPermission.rawValue,
            "dmPermission": settings.dmPermission.rawValue,
            "liveNotifyEnabled": settings.liveNotifyEnabled,
            "chatNotifyEnabled": settings.chatNotifyEnabled,
            "followNotifyEnabled": settings.followNotifyEnabled,
            "postNotifyEnabled": settings.postNotifyEnabled
        ]

        db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - ポイント
    //   ★ saveSettings()の対象データには含めない。プロフィール編集画面が古いポイント数を
    //     保持したまま保存すると、その間に増えた分を上書きしてしまうため、
    //     ここだけFieldValue.increment()で独立して安全に加算する。
    //   ★ アプリ起動直後は、常時マウントされているマイページタブの.onAppear経由で
    //     loadSettings()が非同期に走っていることがある。そのfetchがこの加算より後に
    //     解決すると、サーバー上ではまだ反映前の古いポイント数でローカルの楽観的更新を
    //     上書きしてしまう。書き込み完了後に改めてサーバーの最新値を取り直すことで、
    //     この競合が起きても最終的には必ず正しい値に収束するようにする
    //   ★ 名称・関数名を「大吉ポイント」専用から汎用の「ポイント」に統一(2026-08-08)。
    //   推し活占い以外にも、予定追加・コミュニティ貢献・投稿・イベント参加など
    //   行動全般に対する共通の報酬として今後拡張していく前提のため、呼び出し元は
    //   amountに何ポイント付与するかだけを渡せばよく、獲得理由をこの関数名に含めない
    func addPoints(_ amount: Int = 1) {
        guard amount > 0, let uid = Auth.auth().currentUser?.uid else { return }
        settings.points += amount
        let ref = db.collection("users").document(uid)
        ref.setData(["points": FieldValue.increment(Int64(amount))], merge: true) { [weak self] _ in
            ref.getDocument { snapshot, _ in
                guard let points = snapshot?.data()?["points"] as? Int else { return }
                DispatchQueue.main.async {
                    self?.settings.points = points
                }
            }
        }
    }

    // ★ 限定テーマの交換などで使う、ポイント消費。addPointsと対になる関数で、
    //   同じくFieldValue.increment()（マイナス方向）で他のフォーム編集と競合しないようにする。
    //   残高不足はここでチェックし、呼び出し元(ThemeManager.unlock等)には
    //   「消費できたかどうか」だけをBoolで返す
    func spendPoints(_ amount: Int, completion: @escaping (Bool) -> Void) {
        guard amount > 0, let uid = Auth.auth().currentUser?.uid, settings.points >= amount else {
            completion(false)
            return
        }
        settings.points -= amount
        let ref = db.collection("users").document(uid)
        ref.setData(["points": FieldValue.increment(Int64(-amount))], merge: true) { [weak self] error in
            guard error == nil else {
                DispatchQueue.main.async { self?.settings.points += amount }
                completion(false)
                return
            }
            ref.getDocument { snapshot, _ in
                let points = snapshot?.data()?["points"] as? Int
                DispatchQueue.main.async {
                    if let points { self?.settings.points = points }
                    completion(true)
                }
            }
        }
    }
}
