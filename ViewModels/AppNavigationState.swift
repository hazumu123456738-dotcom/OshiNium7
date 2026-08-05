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
    private var toastToken = UUID()

    func showToast(_ message: String) {
        let token = UUID()
        toastToken = token
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.toastMessage = nil
        }
    }
}
