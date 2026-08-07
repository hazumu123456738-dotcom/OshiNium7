//
//  OshiNiumTabView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI
import FirebaseAuth

// ★ タブバーは自作にしている。標準のTabView().tabItem{}では、個々のタブボタンに
//   長押しジェスチャーを付けられない（マイページタブの長押しでグループ切り替えを出すため）。
struct OshiNiumTabView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    @EnvironmentObject var navState: AppNavigationState
    @EnvironmentObject var auth: AuthViewModel

    // ★ 匿名ログイン（閲覧専用）は、投稿・チャット・マイページのような
    //   アカウントに紐づく機能を一切使わせず、カレンダーとオリジナルタブだけ見せる
    private var isAnonymous: Bool { auth.user?.isAnonymous ?? false }

    // HomeView と同じ Binding（アプリ全体で共有される）。
    // ★ このグループが変わると、オリジナル・チャット・マイページタブも連動して切り替わる。
    @Binding var showAddEvent: Bool
    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    @State private var selectedTab: Tab = .home
    @State private var showGroupSwitcher = false

    // ★ タブを押すたび（同じタブの再タップも含む）にそのタブの最初の画面へ戻すためのトークン。
    //   .id()に混ぜ込むことで、そのタブの中身をまるごと作り直し、ネストしたNavigationStackの
    //   奥に居ても必ずルートに戻す。以前は5タブ共通の1つのトークンだったため、
    //   別タブに切り替えるたびに「今から離れる側」のタブまで巻き添えで作り直されてしまい、
    //   それが黒っぽいフェードに見える原因になっていた。タブごとに個別のトークンを持たせ、
    //   実際に押されたタブだけをリセットするようにする
    @State private var resetTokens: [Tab: UUID] = [
        .home: UUID(), .calendar: UUID(), .original: UUID(), .chat: UUID(), .mypage: UUID()
    ]

    // ★ グループ切り替え時の「〇〇に切り替えました」インスタ風トースト
    @State private var switchToastGroup: IdolGroup? = nil
    @State private var switchToastToken = UUID()

    enum Tab: Int, CaseIterable {
        case home, calendar, original, chat, mypage
    }

    private func selectTab(_ tab: Tab) {
        // ★ 押されたタブだけを最初の画面に戻す（.id()の変更はアニメーション対象外にして
        //   即座に反映する。ここをアニメーションで包むと、作り直された瞬間の中身が
        //   フェードの最中にチラつくことがある）
        resetTokens[tab] = UUID()

        guard tab != selectedTab else {
            // ★ 同じタブの再タップは「最初の画面に戻す」だけなので、切り替えアニメーションは不要
            return
        }

        // ★ 5タブすべてを常時マウントしたまま、選択中タブだけOpacity 1・それ以外は
        //   Opacity 0にする。ビューの再生成（Group{switch}での差し替え）を挟まないため
        //   各タブのナビゲーション状態やスクロール位置がそのまま保たれ、黒みや消える瞬間の
        //   ないなめらかなクロスフェードになる（Apple純正アプリのタブ切り替えに近い自然さ）
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedTab = tab
        }
    }

    // ★ 切り替えた瞬間に「〇〇に切り替えました」を一瞬表示し、少し経ったら自動で消す。
    //   連続で切り替えても直前のタイマーで消されないようトークンで世代管理する
    private func showSwitchToast(for group: IdolGroup) {
        let token = UUID()
        switchToastToken = token
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            switchToastGroup = group
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard switchToastToken == token else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                switchToastGroup = nil
            }
        }
    }

    var body: some View {
        // ★ 以前はGroup{switch}で選択中タブのビューだけをその都度作り直していたが、
        //   これだと切り替えのたびに「今まで見ていたビュー」が消え「新しいビュー」が
        //   生成される、いわゆるView再生成が発生し、その入れ替わりの瞬間に一瞬何も
        //   描画されない（背景色がのぞく＝暗く見える）ことがあった。
        //   5タブすべてを常時ZStackにマウントしたままOpacityだけを切り替える方式にすることで、
        //   ビューそのものは生き続け（ナビゲーション状態やスクロール位置が保たれる）、
        //   常にどちらかの画面が透けて見えている自然なクロスフェードになる
        ZStack {
            NavigationStack {
                if isAnonymous {
                    AnonymousLockedView()
                } else {
                    HomeView(
                        selectedDate: $selectedDate,
                        selectedGroup: $selectedGroup,
                        showAddEvent: $showAddEvent
                    )
                }
            }
            .id("home|\(selectedGroup?.id ?? "")|\(navState.resetToken)|\(resetTokens[.home]?.uuidString ?? "")")
            .opacity(selectedTab == .home ? 1 : 0)
            .allowsHitTesting(selectedTab == .home)
            .zIndex(selectedTab == .home ? 1 : 0)
            .transition(.opacity)

            // ★ FullCalendarTab 内部で NavigationStack を保持しているため、ここでは重ねない
            //   （二重に NavigationStack をネストすると戻るボタンが正しく機能しなくなる）
            FullCalendarTab(
                selectedGroup: $selectedGroup,
                selectedDate: $selectedDate
            )
            .id("calendar|\(selectedGroup?.id ?? "")|\(navState.resetToken)|\(resetTokens[.calendar]?.uuidString ?? "")")
            .opacity(selectedTab == .calendar ? 1 : 0)
            .allowsHitTesting(selectedTab == .calendar)
            .zIndex(selectedTab == .calendar ? 1 : 0)
            .transition(.opacity)

            // ★ ホームで選択中のグループに連動し、そのグループのイベントだけを扱う
            NavigationStack {
                OshiNiumOriginalTab(
                    selectedGroup: selectedGroup,
                    onOpenCalendar: { selectTab(.calendar) }
                )
            }
            .id("original|\(selectedGroup?.id ?? "")|\(navState.resetToken)|\(resetTokens[.original]?.uuidString ?? "")")
            .opacity(selectedTab == .original ? 1 : 0)
            .allowsHitTesting(selectedTab == .original)
            .zIndex(selectedTab == .original ? 1 : 0)
            .transition(.opacity)

            NavigationStack {
                if isAnonymous {
                    AnonymousLockedView()
                } else {
                    ChatTab(selectedGroup: selectedGroup)
                }
            }
            .id("chat|\(selectedGroup?.id ?? "")|\(navState.resetToken)|\(resetTokens[.chat]?.uuidString ?? "")")
            .opacity(selectedTab == .chat ? 1 : 0)
            .allowsHitTesting(selectedTab == .chat)
            .zIndex(selectedTab == .chat ? 1 : 0)
            .transition(.opacity)

            // ★ マイページはユーザー本人の投稿・統計を出す「グループに依存しない共通ページ」。
            //   他のタブと同じキーでリセットすると、グループを切り替えるたびにビューごと
            //   作り直されてしまい、投稿や統計が一瞬消えて「切り替わった」ように見えてしまう。
            //   マイページの.id()にはselectedGroupを含めず、タブの再タップ時だけリセットする
            NavigationStack {
                if isAnonymous {
                    AnonymousLockedView()
                } else {
                    MyPageTab(selectedGroup: selectedGroup)
                }
            }
            .id("mypage|\(resetTokens[.mypage]?.uuidString ?? "")")
            .opacity(selectedTab == .mypage ? 1 : 0)
            .allowsHitTesting(selectedTab == .mypage)
            .zIndex(selectedTab == .mypage ? 1 : 0)
            .transition(.opacity)
        }
        .tint(.primary)
        // ★ 各タブが独自のNavigationStackを持つため.safeAreaInsetだけでは
        //   下タブバーの高さが伝わらない画面があるので、環境値としても明示的に流す。
        //   トーク画面でタブバーを隠している間は0を流し、隠れたタブバー分の余白が
        //   下に空いたままにならないようにする
        .environment(\.customTabBarHeight, navState.hidesCustomTabBar ? 0 : customTabBarHeight)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !navState.hidesCustomTabBar {
                customTabBar
            }
        }
        .overlay {
            if showGroupSwitcher {
                groupSwitcherOverlay
            }
        }
        .overlay(alignment: .top) {
            if let switchToastGroup {
                switchToastView(for: switchToastGroup)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // ★ 予定の追加・保存・削除などの完了お知らせ。モーダル（追加・編集）から
        //   dismiss()した直後や、一覧画面での削除など、どこからでも同じ見た目で表示する
        .overlay {
            if let message = navState.toastMessage {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                SavedToastOverlay(
                    message: message,
                    actionLabel: navState.toastAction?.label,
                    action: navState.toastAction != nil ? { navState.performToastAction() } : nil
                )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: navState.toastMessage)
        // ★ 予定の保存後などに「カレンダータブへ戻る」リクエストを受け取る。
        //   何段階もネストした画面の奥から呼ばれても、タブごと切り替えることで
        //   まとめて破棄できる（.id()の変更と合わせて、既に同じタブにいても必ずルートに戻す）
        .onChange(of: navState.requestedTab) { _, newValue in
            guard let newValue else { return }
            selectedTab = newValue
            navState.requestedTab = nil
        }
    }

    // MARK: - グループ切り替えトースト（インスタの「アカウントを切り替えました」風）

    private func switchToastView(for group: IdolGroup) -> some View {
        HStack(spacing: 10) {
            GroupIcon(group: group, isSelected: false, size: 26)
            Text("\(group.name)に切り替えました")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.82)))
        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    // MARK: - カスタムタブバー

    private var customTabBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.home, systemImage: "house.fill", label: "ホーム")
            tabButton(.calendar, systemImage: "calendar", label: "カレンダー")
            originalTabButton
            tabButton(.chat, systemImage: "message.fill", label: "チャット")
            tabButton(.mypage, systemImage: "person.crop.circle.fill", label: "マイページ", isLongPressable: true)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            // ★ .safeAreaInsetで確保される下端の領域（ホームインジケーター分）は
            //   デフォルトだと塗られず、タブアイコンの下に余白が見えてしまっていた。
            //   背景だけ.ignoresSafeAreaで画面の一番下まで伸ばし、アイコン列自体の位置は変えない
            Color.appBackground
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // ★ デザインコンセプト「少しの立体感」の象徴として、オリジナルタブだけバーの上に
    //   浮かせた円形のグラデーションボタンにする（他タブと機能は同じ、見た目だけ格上げ）
    private var originalTabButton: some View {
        let isSelected = selectedTab == .original

        return Button {
            selectTab(.original)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.oshiniumPrimary, Color(red: 0.78, green: 0.64, blue: 0.99)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: Color.oshiniumPrimary.opacity(0.35), radius: isSelected ? 10 : 7, x: 0, y: 4)
                    .overlay(
                        Circle().stroke(Color.appBackground, lineWidth: 3)
                    )

                BrilliantDiamondIcon(fill: AnyShapeStyle(Color.white), strokeColor: Color.oshiniumPrimary)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        // ★ HStack(alignment: .bottom)の中で他タブ(高さ38pt)より背の高い円(46pt)を
        //   置くことで、下端は揃ったまま上だけ自然にバーの上へ少しはみ出す。
        //   以前は追加でoffset(y:-18)も重ねていたため、はみ出し量が二重になり
        //   バーから浮き上がりすぎて不自然な位置になっていた
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("オリジナル")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // ★ customTabBarの実測高さ（アイコン38pt + 上パディング8pt + 下パディング6pt）。
    //   各タブ側で.customTabBarHeight環境値として使い、下端に浮かせたボタン等の
    //   パディングに足し合わせる
    private var customTabBarHeight: CGFloat { 52 }

    private func tabButton(
        _ tab: Tab,
        systemImage: String,
        label: String,
        isLongPressable: Bool = false
    ) -> some View {
        tabButtonBody(
            tab: tab,
            icon: Image(systemName: systemImage).font(.system(size: 21)),
            label: label,
            accessibilityLabel: label,
            isLongPressable: isLongPressable
        )
    }

    private func tabButtonBody(tab: Tab, icon: some View, label: String?, accessibilityLabel: String, isLongPressable: Bool) -> some View {
        let isSelected = selectedTab == tab

        return VStack(spacing: 2) {
            Spacer(minLength: 0)
            icon
            if let label {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 38)
        .padding(.horizontal, 14)
        .foregroundColor(isSelected ? .primary : .gray)
        // ★ ハイライトはこの中身（アイコン＋ラベル）だけを包む形にすることで、
        //   外側でmaxWidth:.infinityで中央寄せされても常にそのタブの真下に来る
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(isSelected ? 0.15 : 0))
        )
        // ★ 画面側のコンテンツ切り替えは即時のままにしたいので、
        //   ここでは.animation(value:)をこのボタンだけに限定して付ける。
        //   selectTab()自体はwithAnimationで包んでいないので、コンテンツのGroupには
        //   一切影響せず、タブバー上のアイコン色・ハイライトの濃淡だけが流れるように変わる
        .animation(.easeInOut(duration: 0.25), value: isSelected)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .modifier(TabButtonGesture(isLongPressable: isLongPressable, onTap: {
            selectTab(tab)
        }, onLongPress: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showGroupSwitcher = true
            }
        }))
        // ★ アクセシビリティ：VoiceOverでは中身（アイコン＋ラベル）を1つの要素として読み上げ、
        //   「ホーム、選択中、タブ」のように名前・選択状態・役割が伝わるようにする。
        //   長押しでグループ切り替えができるマイページタブには、その旨もヒントとして加える
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isLongPressable ? "長押しで推しグループを切り替えます" : "")
    }

    // MARK: - グループ切り替えオーバーレイ（マイページタブの長押しで表示。Instagramのアカウント切り替え風）

    private var groupSwitcherOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showGroupSwitcher = false }
                }

            VStack(spacing: 16) {
                ForEach(groupViewModel.groups) { group in
                    Button {
                        // ★ マイページに強制的に飛ばさず、切り替えた瞬間にいたタブの
                        //   最初の画面のまま新しいグループの内容に切り替える
                        //   （.id(selectedGroup?.id)により、そのタブが自動的にルートへ戻る）
                        //   ★ withAnimationで包むことで.transition(.crossDissolve)を発火させ、
                        //     黒みのない純粋なクロスフェードで新しいグループの内容に差し替える
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedGroup = group
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showGroupSwitcher = false
                        }
                        showSwitchToast(for: group)
                    } label: {
                        GroupIcon(group: group, isSelected: group.id == selectedGroup?.id, size: 50)
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.trailing, 20)
            .padding(.bottom, 100)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottomTrailing)))
    }
}

// ★ タブボタンのタップ／長押しを排他的に処理する。
//   以前は.onTapGesture と .simultaneousGesture(LongPressGesture) を並べていたが、
//   これだと長押しでグループ切り替えを開いた後、指を離した瞬間に「タップ」も
//   別途成立してしまい、直前にいたタブに関係なくマイページへ切り替わってしまっていた
//   （長押し成立後の指離しもTapGestureの条件を満たしてしまうSwiftUIの挙動が原因）。
//   .exclusively(before:)で「長押しが成立したらタップは発生させない」ようにする
private struct TabButtonGesture: ViewModifier {
    let isLongPressable: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    func body(content: Content) -> some View {
        if isLongPressable {
            content.gesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in onLongPress() }
                    .exclusively(before: TapGesture().onEnded { onTap() })
            )
        } else {
            content.onTapGesture { onTap() }
        }
    }
}

// ★ タブ・グループ切り替え共通の画面遷移。UIKitの.transitionCrossDissolveと同じく、
//   黒いオーバーレイやぼかしは一切使わず、旧画面のOpacityが下がると同時に
//   新画面のOpacityが上がるだけの純粋なクロスフェードにする。常にどちらかの画面が
//   透けて見えている状態を保ち、画面が黒くなる瞬間を作らない
private extension AnyTransition {
    static var crossDissolve: AnyTransition {
        .opacity
    }
}

// ★ 自作の下タブバーの高さを子孫ビューへ明示的に伝える環境値。
//   .safeAreaInset(edge: .bottom)で下タブバー分の余白を確保しているつもりでも、
//   各タブの中身がそれぞれ独自のNavigationStackを持っているため、その内部で
//   .bottomTrailingに浮かせたボタン等は「本当の下端」がタブバーの高さぶんズレて
//   認識され、タブバーの裏に隠れてしまう。この値を各タブ側で足りない分の
//   下パディングとして明示的に使う
private struct CustomTabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var customTabBarHeight: CGFloat {
        get { self[CustomTabBarHeightKey.self] }
        set { self[CustomTabBarHeightKey.self] = newValue }
    }
}
