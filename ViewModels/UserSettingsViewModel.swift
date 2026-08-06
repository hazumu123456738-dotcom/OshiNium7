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
                        oshiFortunePoints: data["oshiFortunePoints"] as? Int ?? 0,
                        isPrivateAccount: data["isPrivateAccount"] as? Bool ?? false
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
            "isPrivateAccount": settings.isPrivateAccount
        ]

        db.collection("users").document(uid).setData(data, merge: true)
    }

    // MARK: - 大吉ポイント
    //   ★ saveSettings()の対象データには含めない。プロフィール編集画面が古いポイント数を
    //     保持したまま保存すると、その間に増えた分を上書きしてしまうため、
    //     ここだけFieldValue.increment()で独立して安全に加算する。
    //   ★ アプリ起動直後は、常時マウントされているマイページタブの.onAppear経由で
    //     loadSettings()が非同期に走っていることがある。そのfetchがこの加算より後に
    //     解決すると、サーバー上ではまだ反映前の古いポイント数でローカルの楽観的更新を
    //     上書きしてしまう。書き込み完了後に改めてサーバーの最新値を取り直すことで、
    //     この競合が起きても最終的には必ず正しい値に収束するようにする
    func addFortunePoint(_ amount: Int = 1) {
        guard amount > 0, let uid = Auth.auth().currentUser?.uid else { return }
        settings.oshiFortunePoints += amount
        let ref = db.collection("users").document(uid)
        ref.setData(["oshiFortunePoints": FieldValue.increment(Int64(amount))], merge: true) { [weak self] _ in
            ref.getDocument { snapshot, _ in
                guard let points = snapshot?.data()?["oshiFortunePoints"] as? Int else { return }
                DispatchQueue.main.async {
                    self?.settings.oshiFortunePoints = points
                }
            }
        }
    }
}
