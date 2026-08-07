//
//  OpenSourceLicensesView.swift
//  OshiNium7
//

import SwiftUI

// ★ Package.resolvedに実際に含まれる依存関係を元にした一覧。ライセンス全文は
//   各リポジトリを参照する形にする（正確な条文をここに複製すると、更新時に
//   食い違うリスクがあるため）
struct OpenSourceLicensesView: View {

    private struct Dependency: Identifiable {
        let id = UUID()
        let name: String
        let url: String
    }

    private let dependencies: [Dependency] = [
        Dependency(name: "Firebase iOS SDK", url: "https://github.com/firebase/firebase-ios-sdk"),
        Dependency(name: "Nuke", url: "https://github.com/kean/Nuke"),
        Dependency(name: "FSCalendar", url: "https://github.com/WenchaoD/FSCalendar"),
        Dependency(name: "GoogleSignIn-iOS", url: "https://github.com/google/GoogleSignIn-iOS"),
        Dependency(name: "AppAuth-iOS", url: "https://github.com/openid/AppAuth-iOS"),
        Dependency(name: "GoogleAppMeasurement", url: "https://github.com/google/GoogleAppMeasurement"),
        Dependency(name: "GoogleUtilities", url: "https://github.com/google/GoogleUtilities"),
        Dependency(name: "GTMAppAuth", url: "https://github.com/google/GTMAppAuth"),
        Dependency(name: "gtm-session-fetcher", url: "https://github.com/google/gtm-session-fetcher"),
        Dependency(name: "Promises", url: "https://github.com/google/promises")
    ]

    var body: some View {
        List(dependencies) { dependency in
            if let url = URL(string: dependency.url) {
                Link(destination: url) {
                    HStack {
                        Text(dependency.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .navigationTitle("オープンソースライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}
