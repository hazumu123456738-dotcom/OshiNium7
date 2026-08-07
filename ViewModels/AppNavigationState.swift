//
//  AppNavigationState.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/30.
//

import Foundation
import Combine

// ★ 予定の保存後などに「カレンダータブへ戻る」ための、アプリ全体で共有するナビゲーション状態。
//   AddEventView/AIAddEventResultView はホーム・カレンダー・AIフローなど何段階も
//   ネストしたNavigationStackの奥深くから呼ばれるため、個別にdismiss()を積み重ねるのではなく、
//   OshiNiumTabViewの表示タブそのものを切り替えさせて、奥にある画面ごとまとめて破棄させる。
final class AppNavigationState: ObservableObject {
    // ★ AppDelegate（UIKit・SwiftUIのEnvironmentObjectを持たない）からプッシュ通知タップ時の
    //   遷移リクエストを渡すためのアクセス経路。OshiNium7App側で@StateObjectとして
    //   保持するインスタンスもこのsharedと同一にすることで、両方から同じ状態を触れるようにする
    static let shared = AppNavigationState()

    @Published var requestedTab: OshiNiumTabView.Tab? = nil
    // ★ 既にカレンダータブにいる場合でも、深い画面（AI追加フローなど）から
    //   確実にルートまで戻したいので、毎回値を変えてOshiNiumTabView側の.id()を更新させる
    @Published var resetToken = UUID()

    // ★ トーク画面（グループ／DM／オープン／匿名チャット）を開いている間、下タブバーを隠す。
    //   自作タブバーはOshiNiumTabViewの一番外側の.safeAreaInsetで常時マウントされているため、
    //   トーク画面でキーボードが出るとその上にタブバーが浮いてしまう問題があった。
    //   トーク画面にいる間はタブバー自体を非表示にすることで解消する
    @Published var hidesCustomTabBar = false

    func jumpToCalendar() {
        requestedTab = .calendar
        resetToken = UUID()
    }

    // ★ 予定を保存・追加・削除した時などの完了お知らせ。OshiNiumTabView側で一箇所だけ
    //   描画することで、モーダル（追加・編集）からでも、タブ内の一覧（削除）からでも、
    //   どこから呼んでも同じ見た目で表示できる
    @Published var toastMessage: String? = nil
    // ★ 予定の編集後など、「元に戻す」のようにトーストからその場で取り消せるようにするための
    //   任意のアクション。ラベル・実行内容の両方を渡す（無ければ今まで通りの通知だけのトースト）
    struct ToastAction {
        let label: String
        let handler: () -> Void
    }
    @Published var toastAction: ToastAction? = nil
    private var toastToken = UUID()

    func showToast(_ message: String, actionLabel: String? = nil, duration: TimeInterval = 1.8, action: (() -> Void)? = nil) {
        let token = UUID()
        toastToken = token
        toastMessage = message
        if let actionLabel, let action {
            toastAction = ToastAction(label: actionLabel, handler: action)
        } else {
            toastAction = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.toastMessage = nil
            self.toastAction = nil
        }
    }

    // ★ トーストのアクションボタンをタップした時に呼ぶ。実行後は即座にトーストを消す
    func performToastAction() {
        toastAction?.handler()
        toastMessage = nil
        toastAction = nil
    }

    // MARK: - プッシュ通知タップ時のチャット/DM遷移
    //   ★ 通知をタップした瞬間、アプリが未起動／バックグラウンド／フォアグラウンドの
    //     どの状態からでも、チャットタブに切り替えた上で該当のグループチャット/DMスレッドを
    //     直接開けるようにする。ChatTab側がpendingChatDeepLinkを監視し、消費したらnilに戻す
    enum ChatDeepLink: Equatable {
        case groupChat(groupId: String)
        case dm(otherUid: String)
    }

    @Published var pendingChatDeepLink: ChatDeepLink? = nil

    // ★ resetTokenは更新しない。resetTokenを変えるとOshiNiumTabView側の.id()により
    //   ChatTabのビュー自体が新しいインスタンスとして作り直され、まさにこの直後に
    //   pendingChatDeepLinkを受け取るはずだった古いインスタンスが読む前に消えてしまう
    //   （結果、チャットタブへの切り替えだけ起きて肝心のスレッドが開かない不具合の原因だった）
    func openGroupChat(groupId: String) {
        pendingChatDeepLink = .groupChat(groupId: groupId)
        requestedTab = .chat
    }

    func openDM(otherUid: String) {
        pendingChatDeepLink = .dm(otherUid: otherUid)
        requestedTab = .chat
    }
}
