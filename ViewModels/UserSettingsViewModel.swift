//
//  UserSettingsViewModel.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/26.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class UserSettingsViewModel: ObservableObject {
    @Published var settings = UserSettings.empty

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
                        defaultNotifyMinutes: data["defaultNotifyMinutes"] as? Int
                    )
                }
            }
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
            "defaultNotifyMinutes": settings.defaultNotifyMinutes as Any
        ]

        db.collection("users").document(uid).setData(data, merge: true)
    }
}
