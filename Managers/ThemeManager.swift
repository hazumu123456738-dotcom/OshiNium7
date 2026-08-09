//
//  ThemeManager.swift
//  OshiNium7
//

import Foundation
import UIKit
import Combine
import FirebaseFirestore
import FirebaseAuth

// ★ 着せ替えカスタマイズの状態管理。ユーザーが保存した自作テーマ(users/{uid}/customThemes)、
//   運営が用意した限定テーマの解放状況(users/{uid}.unlockedThemeIds)、現在適用中のテーマID
//   (users/{uid}.activeThemeId)をまとめて扱う。
//   ★ 2026-08-08: カスタマイズツール自体もポイント交換景品に変更(100pt)。以前は誰でも無料で
//   使えたが、ツールの解放状況をusers/{uid}.themeToolUnlockedで管理し、解放済みの人だけ
//   オシニウムタブのツール一覧に「着せ替え」タイルが表示される
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private init() {
        loadCachedActiveTheme()
    }

    static let toolUnlockCost = 100

    // ★ activeThemeは「実際に保存されているテーマ」と「着せ替え画面でプレビュー中の
    //   ドラフト」を合成した値。previewOverrideがある間はそちらを優先して返す。
    //   これにより、既にactiveThemeを見ている場所(5タブの.oshiniumThemeDecoration()や
    //   Color.themedAccent/themedBase)がそのままプレビュー用の実況反映先としても働く
    @Published private var storedActiveTheme: CustomTheme = .default
    @Published var previewOverride: CustomTheme?
    var activeTheme: CustomTheme { previewOverride ?? storedActiveTheme }

    @Published private(set) var savedThemes: [CustomTheme] = []
    @Published private(set) var unlockedBuiltInThemeIds: Set<String> = []
    @Published private(set) var isToolUnlocked: Bool = false

    private let db = Firestore.firestore()
    private var themesListener: ListenerRegistration?
    private var userDocListener: ListenerRegistration?

    // ★ 起動直後・オフライン時でも前回のテーマを即座に反映できるよう、
    //   アクティブテーマだけは軽量にUserDefaultsへも複製しておく
    private static let activeThemeCacheKey = "activeCustomTheme"

    private func loadCachedActiveTheme() {
        guard let data = UserDefaults.standard.data(forKey: Self.activeThemeCacheKey),
              let theme = try? JSONDecoder().decode(CustomTheme.self, from: data) else { return }
        storedActiveTheme = theme
    }

    private func cacheActiveTheme(_ theme: CustomTheme) {
        guard let data = try? JSONEncoder().encode(theme) else { return }
        UserDefaults.standard.set(data, forKey: Self.activeThemeCacheKey)
    }

    // MARK: - 購読開始・終了

    func startListening(uid: String) {
        stopListening()

        themesListener = db.collection("users").document(uid).collection("customThemes")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 ThemeManager customThemes 購読エラー:", error)
                    return
                }
                let themes = (snapshot?.documents.compactMap { Self.decode($0) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
                DispatchQueue.main.async {
                    self.savedThemes = themes
                }
            }

        userDocListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("🔥 ThemeManager users購読エラー:", error)
                    return
                }
                let data = snapshot?.data() ?? [:]
                let unlockedIds = Set(data["unlockedThemeIds"] as? [String] ?? [])
                let toolUnlocked = data["themeToolUnlocked"] as? Bool ?? false
                DispatchQueue.main.async {
                    self.unlockedBuiltInThemeIds = unlockedIds
                    self.isToolUnlocked = toolUnlocked
                }

                if let activeThemeId = data["activeThemeId"] as? String {
                    self.resolveActiveTheme(id: activeThemeId, uid: uid)
                }
            }
    }

    func stopListening() {
        themesListener?.remove()
        userDocListener?.remove()
        themesListener = nil
        userDocListener = nil
    }

    // ★ activeThemeIdはビルトインのIDかもしれないし、自作テーマ(Firestoreドキュメント)の
    //   IDかもしれない。ビルトインはローカル定数から即座に見つかるが、自作テーマは
    //   customThemesの購読が届くまで一瞬ラグがありうるため、両方から探す
    private func resolveActiveTheme(id: String, uid: String) {
        if let builtIn = CustomTheme.curatedPresets.first(where: { $0.id == id }) {
            DispatchQueue.main.async { [weak self] in
                self?.storedActiveTheme = builtIn
                self?.cacheActiveTheme(builtIn)
            }
            return
        }
        if id == CustomTheme.default.id {
            DispatchQueue.main.async { [weak self] in
                self?.storedActiveTheme = .default
                self?.cacheActiveTheme(.default)
            }
            return
        }
        db.collection("users").document(uid).collection("customThemes").document(id).getDocument { [weak self] snapshot, _ in
            guard let self, let doc = snapshot, let theme = Self.decode(doc) else { return }
            DispatchQueue.main.async {
                self.storedActiveTheme = theme
                self.cacheActiveTheme(theme)
            }
        }
    }

    // ★ 着せ替え画面がドラフトを編集するたびに呼ぶ。nilに戻すとプレビューを終了し、
    //   実際に保存されているテーマ(storedActiveTheme)の表示へ戻る
    func setPreviewOverride(_ theme: CustomTheme?) {
        previewOverride = theme
    }

    // ★ 2026-08-09: タブ画面・ウィジェットへのテーマ反映は一旦保留(CEOの判断で、まずは
    //   アプリアイコンの着せ替えだけをリリースする方針に変更)。この関数自体とSharedWidgetStore側の
    //   実装は残してあるので、再開する際はapplyTheme(_:)/resolveActiveTheme(id:uid:)から
    //   呼び出しを復活させるだけでよい
    private func saveWidgetSnapshot(for theme: CustomTheme) {
        SharedWidgetStore.saveTheme(WidgetThemeSnapshot(
            isDefault: theme.isVisuallyDefault,
            baseColorHex: theme.resolvedBaseColor.toHexString(),
            accentColorHex: theme.resolvedAccentColor.toHexString()
        ))
    }

    // MARK: - デコード／エンコード（Firestoreは手書きのdictionaryで扱う既存パターンに合わせる）

    private static func decode(_ doc: QueryDocumentSnapshot) -> CustomTheme? {
        decode(id: doc.documentID, data: doc.data())
    }

    private static func decode(_ doc: DocumentSnapshot) -> CustomTheme? {
        guard let data = doc.data() else { return nil }
        return decode(id: doc.documentID, data: data)
    }

    private static func decode(id: String, data: [String: Any]) -> CustomTheme? {
        guard let name = data["name"] as? String,
              let baseColor = ThemeColorOption(rawValue: data["baseColor"] as? String ?? ""),
              let accentColor = ThemeColorOption(rawValue: data["accentColor"] as? String ?? ""),
              let background = ThemeBackgroundStyle(rawValue: data["background"] as? String ?? ""),
              let ribbon = ThemeRibbonStyle(rawValue: data["ribbon"] as? String ?? ""),
              let icon = ThemeIconAccent(rawValue: data["icon"] as? String ?? ""),
              let font = ThemeFontStyle(rawValue: data["font"] as? String ?? ""),
              let effect = ThemeEffectStyle(rawValue: data["effect"] as? String ?? "")
        else { return nil }

        return CustomTheme(
            id: id, name: name, baseColor: baseColor, accentColor: accentColor,
            background: background, ribbon: ribbon, icon: icon, font: font, effect: effect,
            baseColorCustomHex: data["baseColorCustomHex"] as? String,
            accentColorCustomHex: data["accentColorCustomHex"] as? String,
            colorOpacity: data["colorOpacity"] as? Double ?? 1.0,
            isBuiltIn: false, pointCost: 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    private static func encode(_ theme: CustomTheme) -> [String: Any] {
        var data: [String: Any] = [
            "name": theme.name,
            "baseColor": theme.baseColor.rawValue,
            "accentColor": theme.accentColor.rawValue,
            "background": theme.background.rawValue,
            "ribbon": theme.ribbon.rawValue,
            "icon": theme.icon.rawValue,
            "font": theme.font.rawValue,
            "effect": theme.effect.rawValue,
            "colorOpacity": theme.colorOpacity,
            "createdAt": Timestamp(date: theme.createdAt)
        ]
        data["baseColorCustomHex"] = theme.baseColorCustomHex
        data["accentColorCustomHex"] = theme.accentColorCustomHex
        return data
    }

    // MARK: - 保存・適用・削除

    // ★ 自作テーマの保存数に上限は設けない(着せ替えは収益機能ではなく、上限で
    //   ユーザー体験を損なう理由が無いため。他の上限機能とは性質が異なる)
    func saveTheme(name: String, draft: CustomTheme, completion: ((Result<CustomTheme, Error>) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var theme = draft
        theme.name = name
        theme.createdAt = Date()

        let ref = db.collection("users").document(uid).collection("customThemes").document()
        theme.id = ref.documentID

        ref.setData(Self.encode(theme)) { error in
            if let error {
                completion?(.failure(error))
            } else {
                completion?(.success(theme))
            }
        }
    }

    func deleteTheme(_ theme: CustomTheme) {
        guard let uid = Auth.auth().currentUser?.uid, !theme.isBuiltIn else { return }
        db.collection("users").document(uid).collection("customThemes").document(theme.id).delete { error in
            if let error { print("🔥 ThemeManager deleteTheme error:", error) }
        }
    }

    func applyTheme(_ theme: CustomTheme) {
        storedActiveTheme = theme
        cacheActiveTheme(theme)
        updateAppIcon(for: theme)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).setData(["activeThemeId": theme.id], merge: true) { error in
            if let error { print("🔥 ThemeManager applyTheme error:", error) }
        }
    }

    // MARK: - アプリアイコン(ダイアモンドの位置・形状は固定、色だけ切り替え)

    // ★ iOSのアプリアイコンは事前にInfo.plist(CFBundleAlternateIcons)へ登録した
    //   候補からしか切り替えられない(実行時に任意のカスタムカラーへ動的着色はできない)。
    //   そのため自由なカスタムカラーではなく、5つの限定テーマ(curatedPresets)にだけ
    //   専用アイコンを用意している。それ以外(デフォルト・自作テーマ)は標準アイコンに戻す
    static func iconName(for themeId: String) -> String? {
        switch themeId {
        case "preset_kongou_diamond": return "AppIcon-kongou-diamond"
        case "preset_sakuragyoku_pinksapphire": return "AppIcon-sakuragyoku-pinksapphire"
        case "preset_sousen_fancyblue": return "AppIcon-sousen-fancyblue"
        case "preset_kougyoku_ruby": return "AppIcon-kougyoku-ruby"
        case "preset_suigyoku_emerald": return "AppIcon-suigyoku-emerald"
        case "preset_sougyoku_sapphire": return "AppIcon-sougyoku-sapphire"
        case "preset_shigyoku_amethyst": return "AppIcon-shigyoku-amethyst"
        default: return nil
        }
    }

    private func updateAppIcon(for theme: CustomTheme) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let iconName = Self.iconName(for: theme.id)
        guard UIApplication.shared.alternateIconName != iconName else { return }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error { print("🔥 ThemeManager setAlternateIconName error:", error) }
        }
    }

    // MARK: - 限定テーマのポイント交換

    enum UnlockError: LocalizedError {
        case notEnoughPoints(needed: Int, current: Int)

        var errorDescription: String? {
            switch self {
            case .notEnoughPoints(let needed, let current):
                return "ポイントが足りません(必要\(needed)pt・現在\(current)pt)。"
            }
        }
    }

    func isUnlocked(_ theme: CustomTheme) -> Bool {
        !theme.isBuiltIn || theme.pointCost == 0 || unlockedBuiltInThemeIds.contains(theme.id)
    }

    // ★ ポイント消費はUserSettingsViewModel.spendPointsに委譲し、成功したら
    //   unlockedThemeIdsへそのテーマIDを追加する。「交換しました。現在のポイントは○ptです」
    //   という結果表示に必要な残ポイント数をcompletionでそのまま返す
    func unlock(_ theme: CustomTheme, settingsVM: UserSettingsViewModel, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard theme.isBuiltIn, theme.pointCost > 0 else {
            completion(.success(settingsVM.settings.points))
            return
        }
        guard settingsVM.settings.points >= theme.pointCost else {
            completion(.failure(UnlockError.notEnoughPoints(needed: theme.pointCost, current: settingsVM.settings.points)))
            return
        }

        settingsVM.spendPoints(theme.pointCost) { [weak self] success in
            guard let self else { return }
            guard success else {
                completion(.failure(UnlockError.notEnoughPoints(needed: theme.pointCost, current: settingsVM.settings.points)))
                return
            }
            self.db.collection("users").document(uid).setData(
                ["unlockedThemeIds": FieldValue.arrayUnion([theme.id])], merge: true
            ) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(settingsVM.settings.points))
                }
            }
        }
    }

    // ★ カスタマイズツール自体の解放。個別テーマのunlockと同じ形の
    //   Result<Int(残ポイント), Error>を返し、呼び出し元は同じ「交換しました。現在の
    //   ポイントは○ptです」の表示パターンをそのまま使い回せる
    func unlockTool(settingsVM: UserSettingsViewModel, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard !isToolUnlocked else {
            completion(.success(settingsVM.settings.points))
            return
        }
        guard settingsVM.settings.points >= Self.toolUnlockCost else {
            completion(.failure(UnlockError.notEnoughPoints(needed: Self.toolUnlockCost, current: settingsVM.settings.points)))
            return
        }

        settingsVM.spendPoints(Self.toolUnlockCost) { [weak self] success in
            guard let self else { return }
            guard success else {
                completion(.failure(UnlockError.notEnoughPoints(needed: Self.toolUnlockCost, current: settingsVM.settings.points)))
                return
            }
            self.db.collection("users").document(uid).setData(
                ["themeToolUnlocked": true], merge: true
            ) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(settingsVM.settings.points))
                }
            }
        }
    }
}
