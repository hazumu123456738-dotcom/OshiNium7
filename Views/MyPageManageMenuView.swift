//
//  MyPageManageMenuView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import FirebaseAuth
import Nuke

// ★ マイページ右上の歯車ボタンから開く設定画面。プライバシー・通知・アプリ・サポート・
//   情報・アカウントの6セクションに整理する。特に「プライバシー」「情報」「アカウント」は
//   App Storeの審査ガイドライン（アカウント削除の提供義務・プライバシーポリシーの明示等）に
//   関わるため、実際に機能するところまで作り込む
struct MyPageManageMenuView: View {

    var onLogout: () -> Void

    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountErrorMessage: String?

    @AppStorage(AppThemeMode.storageKey) private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("dataSaverModeEnabled") private var dataSaverModeEnabled = false
    @State private var showClearCacheConfirm = false
    @State private var didClearCache = false

    private var themeMode: Binding<AppThemeMode> {
        Binding(
            get: { AppThemeMode(rawValue: themeModeRaw) ?? .system },
            set: { themeModeRaw = $0.rawValue }
        )
    }

    // ★ このアプリはまだ日本語のみに対応している（Localizable.strings等の多言語基盤が
    //   無い）ため、「言語」は切り替え可能なピッカーではなく、現状を正直に示すだけにする
    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "バージョン \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                privacySection
                notificationSection
                appSection
                supportSection
                infoSection
                accountSection
            }
            // ★ Label/Toggle/Pickerのアイコン・スイッチ色を、指定しない限り出てしまう
            //   システム標準の青ではなく、アプリのブランドカラー(紫)に揃える
            .tint(Color.oshiniumPrimary)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("ログアウトしてよろしいですか？", isPresented: $showLogoutConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    dismiss()
                    onLogout()
                }
            }
            .alert("アカウントを削除しますか？", isPresented: $showDeleteAccountConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("削除する", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("プロフィール情報が削除され、この操作は取り消せません。投稿やメッセージなど他のデータは別途サポートまでご連絡ください。")
            }
            .alert("削除できませんでした", isPresented: Binding(
                get: { deleteAccountErrorMessage != nil },
                set: { if !$0 { deleteAccountErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { deleteAccountErrorMessage = nil }
            } message: {
                Text(deleteAccountErrorMessage ?? "")
            }
            .alert("キャッシュを削除しますか？", isPresented: $showClearCacheConfirm) {
                Button("キャンセル", role: .cancel) {}
                Button("削除する") { clearCache() }
            } message: {
                Text("読み込み済みの画像データを端末から消去します。次回表示時に再度ダウンロードされます。")
            }
        }
    }

    // MARK: - 🔒 プライバシー

    private var privacySection: some View {
        Section {
            Toggle(isOn: $settingsVM.settings.isPrivateAccount) {
                Label("非公開アカウント", systemImage: "lock.fill")
            }
            .onChange(of: settingsVM.settings.isPrivateAccount) { _, _ in settingsVM.saveSettings() }

            Picker(selection: Binding(
                get: { settingsVM.settings.commentPermission },
                set: { settingsVM.settings.commentPermission = $0; settingsVM.saveSettings() }
            )) {
                ForEach(CommentPermission.allCases, id: \.self) { permission in
                    Text(permission.label).tag(permission)
                }
            } label: {
                Label("コメント許可", systemImage: "bubble.left.fill")
            }

            Picker(selection: Binding(
                get: { settingsVM.settings.dmPermission },
                set: { settingsVM.settings.dmPermission = $0; settingsVM.saveSettings() }
            )) {
                ForEach(DMPermission.allCases, id: \.self) { permission in
                    Text(permission.label).tag(permission)
                }
            } label: {
                Label("メッセージ受信設定", systemImage: "envelope.fill")
            }

            NavigationLink {
                BlockedUsersListView()
            } label: {
                Label("ブロックしたユーザー", systemImage: "person.crop.circle.badge.xmark")
            }

            NavigationLink {
                MutedUsersListView()
            } label: {
                Label("ミュートしたユーザー", systemImage: "speaker.slash.fill")
            }
        } header: {
            Text("🔒 プライバシー")
        } footer: {
            Text("非公開アカウントをオンにすると、あなたをフォローしていない人には投稿が表示されなくなります。")
        }
    }

    // MARK: - 🔔 通知
    //   ★ ここではON/OFFの管理のみ行う。実際に届く・届かないの細かい制御は今後の課題

    private var notificationSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settingsVM.settings.liveNotifyEnabled },
                set: { settingsVM.settings.liveNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                Label("ライブ通知", systemImage: "music.mic")
            }
            Toggle(isOn: Binding(
                get: { settingsVM.settings.chatNotifyEnabled },
                set: { settingsVM.settings.chatNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                Label("チャット通知", systemImage: "message.fill")
            }
            Toggle(isOn: Binding(
                get: { settingsVM.settings.followNotifyEnabled },
                set: { settingsVM.settings.followNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                Label("フォロー通知", systemImage: "person.fill.badge.plus")
            }
            Toggle(isOn: Binding(
                get: { settingsVM.settings.postNotifyEnabled },
                set: { settingsVM.settings.postNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                Label("投稿通知", systemImage: "square.and.pencil")
            }
        } header: {
            Text("🔔 通知")
        } footer: {
            Text("通知のON/OFFのみを管理します。端末本体の通知許可がオフの場合は、そちらの設定が優先されます。")
        }
    }

    // MARK: - 🎨 アプリ

    private var appSection: some View {
        Section {
            Picker(selection: themeMode) {
                ForEach(AppThemeMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            } label: {
                Label("テーマ", systemImage: "circle.righthalf.filled")
            }

            HStack {
                Label("言語", systemImage: "globe")
                Spacer()
                Text("日本語")
                    .foregroundColor(.secondary)
            }

            Button {
                showClearCacheConfirm = true
            } label: {
                HStack {
                    Label("キャッシュ削除", systemImage: "trash")
                    Spacer()
                    if didClearCache {
                        Text("削除しました")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.primary)

            Toggle(isOn: $dataSaverModeEnabled) {
                Label("データ通信節約モード", systemImage: "antenna.radiowaves.left.and.right.slash")
            }
        } header: {
            Text("🎨 アプリ")
        } footer: {
            Text("データ通信節約モードをオンにすると、タイムラインの画像先読みを控えめにします。")
        }
    }

    // MARK: - 💬 サポート
    //   ★ 専用の問い合わせ窓口システムはまだ無いため、メール下書きを開く方式にする

    private var supportSection: some View {
        Section {
            NavigationLink {
                HelpCenterView()
            } label: {
                Label("ヘルプセンター", systemImage: "questionmark.circle")
            }

            supportMailLink(
                title: "お問い合わせ",
                icon: "envelope.badge",
                subject: "【OshiNium】お問い合わせ"
            )
            supportMailLink(
                title: "不具合を報告",
                icon: "ladybug",
                subject: "【OshiNium】不具合報告"
            )
            supportMailLink(
                title: "機能をリクエスト",
                icon: "lightbulb",
                subject: "【OshiNium】機能リクエスト"
            )
        } header: {
            Text("💬 サポート")
        }
    }

    private func supportMailLink(title: String, icon: String, subject: String) -> some View {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let url = URL(string: "mailto:support@oshinium.app?subject=\(encodedSubject)")
        return Group {
            if let url {
                Link(destination: url) {
                    Label(title, systemImage: icon)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - 📄 情報

    private var infoSection: some View {
        Section {
            NavigationLink {
                TermsOfServiceView()
            } label: {
                Label("利用規約", systemImage: "doc.text")
            }
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }
            NavigationLink {
                OpenSourceLicensesView()
            } label: {
                Label("オープンソースライセンス", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        } header: {
            Text("📄 情報")
        } footer: {
            HStack {
                Spacer()
                Text(appVersionText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 🚪 アカウント

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
            }

            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                if isDeletingAccount {
                    HStack {
                        Label("アカウント削除", systemImage: "person.crop.circle.badge.minus")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Label("アカウント削除", systemImage: "person.crop.circle.badge.minus")
                }
            }
            .disabled(isDeletingAccount)
        } header: {
            Text("🚪 アカウント")
        }
    }

    private func clearCache() {
        // ★ Nuke（画像読み込みライブラリ）のメモリ・ディスクキャッシュを消去する。
        //   Firestoreの永続キャッシュはオフライン表示の要なので、ここでは触らない
        ImagePipeline.shared.cache.removeAll()
        withAnimation { didClearCache = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { didClearCache = false }
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        authViewModel.deleteAccount { result in
            isDeletingAccount = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                if let authError = error as NSError?, authError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    deleteAccountErrorMessage = "セキュリティのため、アカウント削除には最近のログインが必要です。一度ログアウトしてから再度ログインし、もう一度お試しください。"
                } else {
                    deleteAccountErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
