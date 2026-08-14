//
//  FollowListView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import NukeUI

// ★ フォロー中／フォロワー一覧。MyPageTab・UserProfileViewの統計数字をタップすると開く
struct FollowListView: View {
    let uid: String
    let kind: String   // "followers" または "following"

    @State private var profiles: [(uid: String, name: String, iconURL: String?)] = []
    @State private var isLoading = true

    private let accentColor = Color.oshiniumPrimary

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if profiles.isEmpty {
                    Text(kind == "followers" ? "フォロワーはまだいません" : "フォロー中のユーザーはいません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(profiles, id: \.uid) { profile in
                            NavigationLink {
                                UserProfileView(uid: profile.uid, fallbackName: profile.name, fallbackIconURL: profile.iconURL)
                            } label: {
                                row(for: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(kind == "followers" ? "フォロワー" : "フォロー中")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func row(for profile: (uid: String, name: String, iconURL: String?)) -> some View {
        HStack(spacing: 12) {
            if let urlString = profile.iconURL, let url = URL(string: urlString) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } else {
                        placeholderIcon(profile.name)
                    }
                }
            } else {
                placeholderIcon(profile.name)
            }

            Text(profile.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func placeholderIcon(_ name: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [accentColor, Color.oshiniumPrimary2],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 46, height: 46)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func load() async {
        let uids = await FollowViewModel.fetchUids(for: uid, kind: kind)
        // ★ 自分がブロックしている相手は、他人のフォロワー/フォロー中一覧に紛れ込んでいても
        //   自分の画面からは見えないようにする（グループ所属等には一切影響しない、表示だけの絞り込み）
        let blockedUids = await withCheckedContinuation { continuation in
            ModerationService.fetchBlockedUids { continuation.resume(returning: $0) }
        }

        var loaded: [(uid: String, name: String, iconURL: String?)] = []
        for targetUid in uids where !blockedUids.contains(targetUid) {
            let profile = await ChatViewModel.fetchUserProfile(uid: targetUid)
            loaded.append((targetUid, profile?.displayName ?? "名無しさん", profile?.iconURL))
        }

        await MainActor.run {
            self.profiles = loaded
            self.isLoading = false
        }
    }
}
