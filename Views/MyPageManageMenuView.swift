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
//   ★ 見た目の方針（Instagram「設定とアクティビティ」を参考にした指定）：
//   絵文字・多色使いは安っぽく見えるため使わない。アイコンは単色（.primary/.secondary）に統一し、
//   複数選択肢を持つ項目は必ず「タップ→専用画面で選ぶ」形にして、一覧側の行の高さを揃える
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
    //   無い）ため、「言語」は切り替え可能な項目にせず、現状を正直に示すだけにする
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

    // MARK: - 行の共通部品（アイコン単色・トレーリングに現在値・必ず1行の高さ）

    private func settingIcon(_ systemImage: String, color: Color = .primary) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17))
            .foregroundColor(color)
            .frame(width: 26)
            .accessibilityHidden(true)
    }

    private func settingRow(_ icon: String, _ title: String, value: String? = nil, color: Color = .primary) -> some View {
        HStack(spacing: 14) {
            settingIcon(icon, color: color)
            Text(title)
                .foregroundColor(color)
            Spacer()
            if let value {
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - プライバシー

    private var privacySection: some View {
        Section {
            Toggle(isOn: $settingsVM.settings.isPrivateAccount) {
                HStack(spacing: 14) {
                    settingIcon("lock")
                    Text("非公開アカウント")
                }
            }
            .onChange(of: settingsVM.settings.isPrivateAccount) { _, _ in settingsVM.saveSettings() }

            NavigationLink {
                CommentPermissionSettingView(settingsVM: settingsVM)
            } label: {
                settingRow("bubble.left", "コメント許可", value: settingsVM.settings.commentPermission.label)
            }

            NavigationLink {
                DMPermissionSettingView(settingsVM: settingsVM)
            } label: {
                settingRow("envelope", "メッセージ受信設定", value: shortLabel(settingsVM.settings.dmPermission))
            }

            NavigationLink {
                BlockedUsersListView()
            } label: {
                settingRow("person.crop.circle.badge.xmark", "ブロックしたユーザー")
            }

            NavigationLink {
                MutedUsersListView()
            } label: {
                settingRow("speaker.slash", "ミュートしたユーザー")
            }
        } header: {
            Text("プライバシー")
        } footer: {
            Text("非公開アカウントをオンにすると、あなたをフォローしていない人には投稿が表示されなくなります。")
        }
    }

    // ★ メッセージ受信設定の値は一覧側では短く（1行に収まる長さで）見せる
    private func shortLabel(_ permission: DMPermission) -> String {
        switch permission {
        case .everyone: return "全員"
        case .none: return "受け取らない"
        }
    }

    // MARK: - 通知
    //   ★ ここではON/OFFの管理のみ行う。実際に届く・届かないの細かい制御は今後の課題

    private var notificationSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settingsVM.settings.liveNotifyEnabled },
                set: { settingsVM.settings.liveNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                HStack(spacing: 14) {
                    settingIcon("music.mic")
                    Text("ライブ通知")
                }
            }
            Toggle(isOn: Binding(
                get: { settingsVM.settings.chatNotifyEnabled },
                set: { settingsVM.settings.chatNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                HStack(spacing: 14) {
                    settingIcon("message")
                    Text("チャット通知")
                }
            }
            Toggle(isOn: Binding(
                get: { settingsVM.settings.followNotifyEnabled },
                set: { settingsVM.settings.followNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                HStack(spacing: 14) {
                    settingIcon("person.badge.plus")
                    Text("フォロー通知")
                }
            }
            Toggle(isOn: Binding(
                get: { settingsVM.settings.postNotifyEnabled },
                set: { settingsVM.settings.postNotifyEnabled = $0; settingsVM.saveSettings() }
            )) {
                HStack(spacing: 14) {
                    settingIcon("square.and.pencil")
                    Text("投稿通知")
                }
            }
        } header: {
            Text("通知")
        } footer: {
            Text("通知のON/OFFのみを管理します。端末本体の通知許可がオフの場合は、そちらの設定が優先されます。")
        }
    }

    // MARK: - アプリ

    private var appSection: some View {
        Section {
            NavigationLink {
                AppThemeSettingView(themeMode: themeMode)
            } label: {
                settingRow("circle.righthalf.filled", "テーマ", value: themeMode.wrappedValue.label)
            }

            settingRow("globe", "言語", value: "日本語")

            Button {
                showClearCacheConfirm = true
            } label: {
                settingRow("trash", "キャッシュ削除", value: didClearCache ? "削除しました" : nil)
            }

            Toggle(isOn: $dataSaverModeEnabled) {
                HStack(spacing: 14) {
                    settingIcon("antenna.radiowaves.left.and.right.slash")
                    Text("データ通信節約モード")
                }
            }
        } header: {
            Text("アプリ")
        } footer: {
            Text("データ通信節約モードをオンにすると、タイムラインの画像先読みを控えめにします。")
        }
    }

    // MARK: - サポート
    //   ★ 専用の問い合わせ窓口システムはまだ無いため、メール下書きを開く方式にする

    private var supportSection: some View {
        Section {
            NavigationLink {
                HelpCenterView()
            } label: {
                settingRow("questionmark.circle", "ヘルプセンター")
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
            Text("サポート")
        }
    }

    private func supportMailLink(title: String, icon: String, subject: String) -> some View {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let url = URL(string: "mailto:support@oshinium.app?subject=\(encodedSubject)")
        return Group {
            if let url {
                Link(destination: url) {
                    settingRow(icon, title)
                }
            }
        }
    }

    // MARK: - 情報

    private var infoSection: some View {
        Section {
            NavigationLink {
                TermsOfServiceView()
            } label: {
                settingRow("doc.text", "利用規約")
            }
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                settingRow("hand.raised", "プライバシーポリシー")
            }
            NavigationLink {
                OpenSourceLicensesView()
            } label: {
                settingRow("chevron.left.forwardslash.chevron.right", "オープンソースライセンス")
            }
        } header: {
            Text("情報")
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

    // MARK: - アカウント

    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                showLogoutConfirm = true
            } label: {
                settingRow("rectangle.portrait.and.arrow.right", "ログアウト", color: .red)
            }

            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                settingRow("person.crop.circle.badge.minus", "アカウント削除", value: isDeletingAccount ? "処理中…" : nil, color: .red)
            }
            .disabled(isDeletingAccount)
        } header: {
            Text("アカウント")
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
