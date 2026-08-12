//
//  UserSettingsView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/26.
//

import SwiftUI
import PhotosUI
import NukeUI

struct UserSettingsView: View {
    @ObservedObject var viewModel: UserSettingsViewModel
    @EnvironmentObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) var dismiss

    @State private var photoPickerItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, bio, sns(Int)
    }

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                iconSection
                profileCard
                birthdayCard
                privacyCard
                snsCard
                saveButton
                    .padding(.top, 4)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadSettings()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await viewModel.uploadIcon(uiImage)
                }
            }
        }
    }

    // MARK: - アイコン

    private var iconSection: some View {
        HStack {
            Spacer()
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                ZStack {
                    iconPreview

                    if viewModel.isUploadingImage {
                        Circle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 104, height: 104)
                        ProgressView()
                            .tint(.white)
                    }

                    Circle()
                        .fill(
                            LinearGradient(colors: [accentColor, accentColor2],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.appBackground, lineWidth: 3))
                        .offset(x: 36, y: 36)
                }
            }
            .disabled(viewModel.isUploadingImage)
            .accessibilityLabel("プロフィール写真を変更")
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let url = URL(string: viewModel.settings.iconURL), !viewModel.settings.iconURL.isEmpty {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                } else {
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(
                LinearGradient(colors: [accentColor.opacity(0.25), accentColor2.opacity(0.25)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: 104, height: 104)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundColor(accentColor)
            )
    }

    // MARK: - プロフィール（名前・自己紹介）

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            fieldBlock(title: "名前") {
                TextField("名前を入力", text: $viewModel.settings.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .focused($focusedField, equals: .name)
            }

            Divider()

            fieldBlock(title: "自己紹介") {
                TextField("推し活について一言…", text: $viewModel.settings.bio, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .bio)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var birthdayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("誕生日")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.secondary)

            DatePicker(
                "",
                selection: Binding(
                    get: { dateFromString(viewModel.settings.birthday) },
                    set: { viewModel.settings.birthday = stringFromDate($0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "ja_JP"))
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(cardBackground)
    }

    // MARK: - 非公開アカウント（鍵垢）

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $viewModel.settings.isPrivateAccount) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("非公開アカウント")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .tint(accentColor)

            Text("オンにすると、あなたをフォローしていない人には投稿が表示されなくなります。プロフィール自体は引き続き見られます。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(cardBackground)
    }

    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }

    // MARK: - SNSリンク

    private var snsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .semibold))
                Text("SNSリンク")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("プロフィールに表示されます")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .foregroundColor(.secondary)

            if viewModel.settings.snsLinks.isEmpty {
                Text("Instagram・X・TikTokなどのURLを追加すると、アイコンでわかりやすく表示されます。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(Array(viewModel.settings.snsLinks.enumerated()), id: \.offset) { index, link in
                snsRow(index: index, link: link)
            }

            Button {
                let newIndex = viewModel.settings.snsLinks.count
                viewModel.settings.snsLinks.append("")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard viewModel.settings.snsLinks.indices.contains(newIndex) else { return }
                    focusedField = .sns(newIndex)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("リンクを追加")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(cardBackground)
    }

    private func snsRow(index: Int, link: String) -> some View {
        let platform = SNSPlatform.detect(from: link)

        return HStack(spacing: 12) {
            SNSBadgeIcon(platform: platform, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(platform.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)

                TextField("https://…", text: Binding(
                    get: {
                        guard viewModel.settings.snsLinks.indices.contains(index) else { return "" }
                        return viewModel.settings.snsLinks[index]
                    },
                    set: { newValue in
                        guard viewModel.settings.snsLinks.indices.contains(index) else { return }
                        viewModel.settings.snsLinks[index] = newValue
                    }
                ))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .sns(index))
            }

            Button {
                guard viewModel.settings.snsLinks.indices.contains(index) else { return }
                withAnimation {
                    _ = viewModel.settings.snsLinks.remove(at: index)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .accessibilityLabel("このSNSリンクを削除")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.6))
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.appCardBackground)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    // MARK: - 保存ボタン

    private var saveButton: some View {
        Button {
            focusedField = nil
            viewModel.settings.snsLinks = viewModel.settings.snsLinks
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            viewModel.saveSettings()
            // ★ 参加中の全グループの members ミラー（チャット等で参照される名前・アイコン）も同期する
            groupViewModel.syncMemberProfile(
                displayName: viewModel.settings.displayName,
                iconURL: viewModel.settings.iconURL
            )
            dismiss()
        } label: {
            Text("保存する")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(colors: [accentColor, accentColor2],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - 文字列 ⇄ 日付 変換
    func dateFromString(_ str: String) -> Date {
        CachedFormatters.date(format: "yyyy-MM-dd", locale: Locale.current).date(from: str) ?? Date()
    }

    func stringFromDate(_ date: Date) -> String {
        CachedFormatters.date(format: "yyyy-MM-dd", locale: Locale.current).string(from: date)
    }
}
