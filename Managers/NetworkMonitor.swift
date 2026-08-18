//
//  NetworkMonitor.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import Foundation
import Network
import Combine
import FirebaseFirestore

// ★ ネットワーク接続状態をアプリ全体で共有する。Firestoreはオフラインでも
//   キャッシュ済みのデータをそのまま表示し続けられる（永続キャッシュはSDKのデフォルトで
//   有効）が、キャッシュが無い初回起動時などにオフラインだと、リスナーが一度も発火せず
//   「読み込み中」のまま止まって見えてしまう。ここで接続状態を検知し、
//   画面側に「オフラインです」と明示することで、単なる無言のローディングと区別できるようにする
//
// ★ 2026/08/16：一時期、回線種別の変化やフォアグラウンド復帰のたびにFirestoreの接続を
//   disableNetwork→enableNetworkで強制的に張り直す仕組みを入れていたが、これは
//   「見た目はオンラインなのにストリームだけ死んでいる」という未検証の仮説に基づく
//   対策で、むしろこの変更の直後から実機で「グループの読み込みに失敗しました」が
//   良好な電波環境下でも繰り返し出るようになったとの報告を受け、撤回した。
//   Firestore SDK自体が本来ネットワーク状態の変化を検知して自動的に再接続する設計であり、
//   ここから手動で介入する必要はそもそも無かったと判断している
final class NetworkMonitor: ObservableObject {
    // ★ 2026/08/16追加：GroupViewModel等のプレーンなSwiftクラス(SwiftUIの
    //   @EnvironmentObjectを持てない)からも接続状態を参照できるように、
    //   AppNavigationStateと同じ形でsharedシングルトンを公開する。
    //   OshiNium7App側の@StateObjectもこの同じインスタンスを使う
    static let shared = NetworkMonitor()

    // ★ NWPathMonitorの生の判定。セルラー回線（特に電車移動中のような基地局の
    //   切り替えが頻発する状況）では、実際には数秒後には繋がり直すごく短い不安定化が
    //   頻繁に起きる。これを画面側にそのまま出すと「オフラインです」バナーが
    //   ちらつき続けてしまうため、UI表示用には下のshowOfflineBannerを別に持つ
    @Published private(set) var isConnected = true
    // ★ 画面のオフラインバナー表示用。切断が一定時間(offlineBannerDelay)継続して
    //   初めて表示し、復帰時は即座に消す（「繋がった時はすぐ安心させる、切れた時は
    //   一瞬のちらつきで済むなら騒がない」という非対称な扱いにする）
    @Published private(set) var showOfflineBanner = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.oshinium.networkmonitor")

    private var offlineBannerWorkItem: DispatchWorkItem?
    private let offlineBannerDelay: TimeInterval = 3

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let nowConnected = path.status == .satisfied

            DispatchQueue.main.async {
                self.isConnected = nowConnected
                self.updateOfflineBanner(nowConnected: nowConnected)
            }
        }
        monitor.start(queue: queue)
    }

    private func updateOfflineBanner(nowConnected: Bool) {
        offlineBannerWorkItem?.cancel()
        if nowConnected {
            // ★ 復帰は即座に反映（不安要素を長引かせない）
            showOfflineBanner = false
        } else {
            let workItem = DispatchWorkItem { [weak self] in
                self?.showOfflineBanner = true
            }
            offlineBannerWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + offlineBannerDelay, execute: workItem)
        }
    }

    deinit {
        monitor.cancel()
    }
}

// ★ 2026/08/16追加：アプリ全体の各ViewModel（GroupViewModel・FollowViewModel・
//   EventViewModel・PostViewModel等、15箇所以上）が、Firestoreリスナーのエラー時に
//   指数バックオフで再接続を試みる同じパターンを持っている。真にオフライン（圏外・
//   機内モード）の間にこれを繰り返すと、実際には繋がらないFirestoreリスナーの
//   張り直しをCPUコストをかけて延々と試み続けることになり、体感的な「カクつき」の
//   原因になっていた。オフラインの間は実際の再接続処理(action)を呼ばず、
//   軽いisConnectedの確認だけを一定間隔で繰り返し、オンライン復帰後に初めて実行する
//   共通ヘルパーとして切り出す
extension NetworkMonitor {
    static func retryWhenOnline(_ action: @escaping () -> Void) {
        guard NetworkMonitor.shared.isConnected else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                retryWhenOnline(action)
            }
            return
        }
        action()
    }

    // ★ 2026/08/18追加：ユーザー報告により発覚。予定の追加・編集の保存処理が、
    //   Firestoreの書き込み完了コールバック（addEventReturningEvent／
    //   EditEventView.writeEvent）を無期限に待つ作りになっており、通信が不安定な間は
    //   「保存中」のまま画面が固まって見えていた。Firestoreへの書き込み自体は
    //   setData()を呼んだ時点でSDKのローカルキューに積まれる（オフラインでもデータは
    //   消えず、繋がり次第自動送信される）ため、サーバーからの確認応答を待つのを
    //   一定時間で諦めても、データが失われるわけではない。指定秒数経っても応答が
    //   無ければタイムアウトとして打ち切り、以降はバックグラウンドでの自動同期に任せる
    static func awaitWithTimeout(
        seconds: TimeInterval = 8,
        _ work: @escaping (@escaping (Error?) -> Void) -> Void
    ) async -> Error? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
            var didResume = false
            let lock = NSLock()
            func resumeOnce(_ error: Error?) {
                lock.lock()
                let alreadyDone = didResume
                didResume = true
                lock.unlock()
                guard !alreadyDone else { return }
                continuation.resume(returning: error)
            }

            work { error in resumeOnce(error) }

            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                resumeOnce(nil)
            }
        }
    }
}
