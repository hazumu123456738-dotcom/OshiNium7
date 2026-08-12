//
//  EventDetailView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/16.
//

import SwiftUI
import NukeUI
import FirebaseAuth

struct EventDetailView: View {
    let event: Event
    let isOwner: Bool
    @ObservedObject var eventViewModel: EventViewModel
    @EnvironmentObject var navState: AppNavigationState
    @EnvironmentObject var groupViewModel: GroupViewModel

    // ★ 荒らし対策：編集できるのは、その予定を追加した本人か、グループの管理者・オーナーだけ。
    //   isOwnerは「秘密の予定を自分のカレンダーとして見ているか」という別の意味で使われているため、
    //   ここでは混同せず別のプロパティとして持つ
    private var canModify: Bool {
        guard let myUid = Auth.auth().currentUser?.uid else { return false }
        if event.creatorUid == myUid { return true }
        guard let groupId = event.groupId,
              let group = groupViewModel.groups.first(where: { $0.id == groupId }) else { return false }
        return groupViewModel.myRole(in: group).canModerateContent
    }

    @Namespace private var animation
    @State private var isEditing: Bool = false
    @State private var showReportDialog: Bool = false
    @State private var showReportThanks: Bool = false
    @Environment(\.dismiss) private var dismiss
    // ★ このタブは独自のNavigationStackを持つため、外側の.safeAreaInsetによる
    //   下タブバー分の安全域の縮小が伝わってこない。編集ボタンがタブバーの裏に
    //   隠れないよう、スクロール内容の下パディングに明示的に足し合わせる
    @Environment(\.customTabBarHeight) private var customTabBarHeight

    // ★ 予定に画像URLが登録されていない場合に、公式URLから拾ってきたヒーロー画像
    @State private var scrapedHeroImageURL: URL?

    // ★ 「誰が追加したか」を表示するための追加者名。creatorUidは以前から権限判定に
    //   使われていたが、画面上には一切表示されておらず、他のメンバーから見て
    //   「この情報は誰の発信か」が分からなかった。安心して情報を共有できる環境作りの一環として表示する
    @State private var creatorName: String?

    // MARK: - イベントカラー（種類別）
    private var eventColor: Color {
        event.type?.iconColor ?? .gray
    }

    // MARK: - 日付＋曜日＋時刻
    private var dateText: String {
        return CachedFormatters.date(format: "yyyy年M月d日（E） H:mm").string(from: event.date)
    }

    // MARK: - グループ名（未設定フォールバック）
    private var groupName: String {
        let name = eventViewModel.groupName(for: event.groupId)
        return name.isEmpty ? "未設定" : name
    }

    // MARK: - 共有範囲（秘密／コミュニティ／プライベート／共有カレンダーの4パターン）
    //   ★ calendarIdの命名規則（"{groupId}_community" / "{groupId}_private_{uid}"）は
    //   CalendarViewModel.createCommunityCalendarIfNeeded/createPrivateCalendarIfNeededと同じもの
    private enum ShareScope {
        case secret, community, `private`, sharedCalendar
    }

    private var shareScope: ShareScope {
        if event.isSecret { return .secret }
        guard let calendarId = event.calendarId, let groupId = event.groupId else { return .community }
        if calendarId == "\(groupId)_community" { return .community }
        if calendarId.hasPrefix("\(groupId)_private_") { return .private }
        return .sharedCalendar
    }

    private var shareScopeIcon: String {
        switch shareScope {
        case .secret: return "lock.fill"
        case .community: return "person.2.fill"
        case .private: return "lock.fill"
        case .sharedCalendar: return "person.crop.circle.badge.checkmark"
        }
    }

    private var shareScopeTitle: String {
        switch shareScope {
        case .secret: return "秘密イベント"
        case .community: return "共有イベント"
        case .private: return "プライベートの予定"
        case .sharedCalendar: return "共有カレンダーの予定"
        }
    }

    private var shareScopeDescription: String {
        switch shareScope {
        case .secret: return "本人のみ表示されるイベントです"
        case .community: return "グループのメンバー全員に共有されています"
        case .private: return "あなたのプライベートカレンダーの予定です。他のメンバーには表示されません"
        case .sharedCalendar: return "このカレンダーを共有しているメンバーにのみ表示されています"
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {

                    // ① Hero画像カード
                    heroCard

                    // ② 日時カード
                    infoCard {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(eventColor)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("日時")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(dateText)
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Spacer()
                        }
                    }

                    // ③ 登録先グループカード（＋誰が追加したか。荒らし対策で編集は追加者本人か
                    //   管理者にしか許可していないが、それが画面上では見えず「これは誰の情報か」
                    //   分からなかったため、安心材料として追加者名も添える）
                    infoCard {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(eventColor)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("登録先グループ")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(groupName)
                                    .font(.system(size: 14, weight: .medium))
                            }

                            Spacer()

                            if !event.isSecret, let creatorName {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("追加者")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(creatorName)
                                        .font(.system(size: 13, weight: .medium))
                                }
                            }
                        }
                    }

                    // ④ 種類カード
                    infoCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: event.type?.iconName ?? "star")
                                    .foregroundColor(eventColor)
                                    .accessibilityHidden(true)
                                Text("種類")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("大分類")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(event.type?.displayName ?? "未設定")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("小分類")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(event.subType?.displayName ?? "未設定")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }

                            if let custom = event.customSubType, !custom.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("カスタム小分類")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(custom)
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                        }
                    }

                    // ⑤ 詳細情報カード（場所・詳細＋メモ）
                    infoCard {
                        VStack(alignment: .leading, spacing: 12) {

                            Text("場所・詳細")
                                .font(.system(size: 15, weight: .semibold))

                            detailRow(icon: "mappin.and.ellipse", title: "場所", value: event.place)
                            detailRow(icon: "clock", title: "補足時間", value: event.timeText)
                            detailRow(icon: "person.badge.key", title: "応募条件", value: event.condition)
                            detailRow(icon: "calendar", title: "応募期間", value: event.applyDate)
                            detailRow(icon: "tv", title: "放送局", value: event.channel)
                            detailRow(icon: "play.tv", title: "番組名", value: event.programName)
                            detailRow(icon: "link", title: "URL", value: event.url, isLink: true)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("メモ")
                                    .font(.system(size: 15, weight: .semibold))

                                Text(event.notes.nonEmptyOrNil ?? "未設定")
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 4)
                        }
                    }

                    // ⑥ 秘密イベント／共有状態カード
                    //   ★ 以前は「秘密イベントかどうか」しか見ておらず、非秘密イベントは
                    //     カレンダー種別に関わらず一律で「グループのメンバー全員に共有されています」と
                    //     表示していた。実際にはプライベートカレンダーの予定は本人にしか見えず、
                    //     共有カレンダーの予定もそのカレンダーのメンバーにしか見えないため、
                    //     カレンダー種別ごとに正しい説明文を出す
                    infoCard {
                        HStack(spacing: 8) {
                            Image(systemName: shareScopeIcon)
                                .foregroundColor(eventColor)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(shareScopeTitle)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(shareScopeDescription)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // ⑦ 通知カード
                    infoCard {
                        HStack(spacing: 8) {
                            Image(systemName: "bell")
                                .foregroundColor(eventColor)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("通知")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(notificationText(from: event.notifyOffsets))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // ⑧ 編集／閉じるボタン
                    //   ★ 以前は画面下部に固定表示していたが、独自タブバーの実際の高さを
                    //     考慮していなかったため、タブバーの裏に隠れてボタンが見えなくなって
                    //     いた。通知カードの下に他のカードと同じ並びで置くことで、スクロールの
                    //     一部として必ず操作できる位置に表示されるようにする
                    bottomButtons
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24 + customTabBarHeight)
            }
        }
        .fullScreenCover(isPresented: $isEditing) {
            EditEventView(
                eventViewModel: eventViewModel,
                event: event,
                groupName: groupName
            )
            .environmentObject(navState)
        }
        .task(id: event.id) {
            scrapedHeroImageURL = nil
            guard EventImageResolver.resolvedURL(for: event) == nil else { return }
            scrapedHeroImageURL = await EventImageResolver.resolveImageURL(for: event)
        }
        .task(id: event.creatorUid) {
            creatorName = nil
            guard let creatorUid = event.creatorUid else { return }
            creatorName = await ChatViewModel.fetchUserProfile(uid: creatorUid)?.displayName
        }
        // ★ canModifyがグループの権限（オーナー/管理者判定）を正しく解決できるよう、
        //   このイベントが属するグループのメンバー情報を読み込んでおく
        .onAppear {
            if let groupId = event.groupId {
                groupViewModel.fetchMembers(for: groupId)
            }
        }
    }

    // MARK: - シェア用テキスト
    private var shareText: String {
        var lines: [String] = ["【\(event.title.isEmpty ? "予定" : event.title)】"]
        lines.append(dateText)
        if let place = event.place, !place.isEmpty {
            lines.append("場所: \(place)")
        }
        if let url = event.url, !url.isEmpty {
            lines.append(url)
        } else if let officialURL = event.officialURL, !officialURL.isEmpty {
            lines.append(officialURL)
        }
        lines.append("via OshiNium")
        return lines.joined(separator: "\n")
    }

    // ★ このイベントが属するグループ（画像フォールバック・アイコン表示用）
    private var eventGroup: IdolGroup? {
        eventViewModel.group(for: event.groupId)
    }

    // MARK: - Hero画像カード（関連画像がなければグループのアイコン画像、それもなければ色＋アイコン）
    //   ★ 画像がカードからはみ出していたバグ修正：LazyImage内部の実寸がZStack経由の
    //     .frame(height:240)だけでは正しく伝わらないことがあるため、背景画像自体に
    //     直接.frame(height:240)+.clipped()を明示して確実に240pt内へ収める
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {

            heroBackgroundImage
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .clipped()

            // ★ 種類タグは「大分類」を色付きバッジ、「小分類」をその隣に控えめなピルで
            //   1行にまとめて表示する（以前は同じ「ライブ」表記が上のバッジと下のピルに
            //   二重に出てしまっていたため、ここで一本化して整理する）
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if let type = event.type {
                        Text(type.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(eventColor.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    if let sub = event.subType {
                        pillTag(text: sub.displayName)
                    }
                }

                Text(event.title.isEmpty ? "未設定" : event.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topTrailing) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("予定を共有")
            .padding(14)
        }
    }

    @ViewBuilder
    private var heroBackgroundImage: some View {
        if let url = EventImageResolver.resolvedURL(for: event) ?? scrapedHeroImageURL {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    fallbackHeroBackground
                }
            }
        } else if let data = eventGroup?.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            fallbackHeroBackground
        }
    }

    // MARK: - 画像なし時の背景
    private var fallbackHeroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    eventColor.opacity(0.85),
                    eventColor.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .accessibilityHidden(true)

                Text(event.type?.displayName ?? "イベント")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
    }

    // MARK: - 共通カード
    private func infoCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)

            content()
                .padding(12)
        }
    }

    // MARK: - 詳細行
    private func detailRow(icon: String, title: String, value: String?, isLink: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(eventColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if let v = value, !v.isEmpty {
                    if isLink {
                        if let url = normalizedURL(v) {
                            Link(destination: url) {
                                Text(v)
                                    .font(.system(size: 13))
                                    .foregroundColor(.oshiniumPrimary)
                                    .underline()
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        } else {
                            Text(v)
                                .font(.system(size: 13))
                                .foregroundColor(.oshiniumPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    } else {
                        Text(v)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("未設定")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            Spacer()
        }
        .frame(height: 40)
    }

    // ★ 「example.com」のようにスキームが省略されたURLでも開けるようにする
    private func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    // MARK: - タグピル
    private func pillTag(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(eventColor.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    // MARK: - 通知テキスト
    private func notificationText(from offsets: [Int]?) -> String {
        guard let offsets, !offsets.isEmpty else { return "通知しない" }
        return offsets.sorted().map { ReminderFormatting.label(forMinutes: $0) }.joined(separator: "・")
    }

    // MARK: - 下部ボタン
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if isOwner && canModify {
                    editButton
                } else if isOwner {
                    // ★ 荒らし対策：自分の予定でも管理者でもない場合、編集の代わりに
                    //   「報告する」を出す（虚偽の予定・スパム的な予定などをここから報告できる）
                    reportButton
                    closeButton
                } else {
                    closeButton
                }
            }
        }
        .sheet(isPresented: $showReportDialog) {
            ReportComposerSheet(title: "この予定を報告", reasons: ["スパム・宣伝", "虚偽の情報", "嫌がらせ・誹謗中傷", "不適切な内容", "その他"]) { reason, detail in
                if let groupId = event.groupId {
                    ModerationService.reportEvent(
                        groupId: groupId,
                        eventId: event.id ?? "",
                        eventTitle: event.title,
                        creatorUid: event.creatorUid,
                        reason: reason,
                        detail: detail
                    )
                }
                showReportThanksBriefly()
            }
        }
        .overlay(alignment: .top) {
            if showReportThanks {
                ReportThanksToast()
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showReportThanks)
    }

    private func showReportThanksBriefly() {
        withAnimation { showReportThanks = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { showReportThanks = false }
        }
    }

    private var editButton: some View {
        Button {
            isEditing = true
        } label: {
            Text("編集")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [eventColor.opacity(0.95), eventColor.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var reportButton: some View {
        Button {
            showReportDialog = true
        } label: {
            Text("報告する")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Text("閉じる")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.9), Color.gray.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

}

// MARK: - Hexカラー簡易拡張
extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
