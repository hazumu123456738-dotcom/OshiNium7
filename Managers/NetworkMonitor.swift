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
// ★ 2026/08/16追加：会場内など電波の混雑する場所では、端末は「オンライン」のまま
//   （NWPathMonitor上は経路がある）でも、Firestoreのリアルタイムリスナーが張っている
//   gRPCストリームだけがサイレントに切れて（携帯キャリア側のNATがアイドル状態の
//   コネクションを黙って破棄する等）、新着投稿・チャットが実際にはもう届かなくなる
//   ことがある。この状態は見た目上「オンライン」なので、従来の isConnected バナーだけでは
//   検知できない。回線の種別が切り替わった（Wi-Fi⇄モバイル通信）、または一度オフラインから
//   オンラインに復帰したタイミングで、Firestoreの接続を明示的に張り直す
//   （disableNetwork→enableNetworkで既存のストリームを強制的に破棄し、新しいストリームを
//   確立させる）ことで、生きているように見えて実際には死んでいる接続を回復させる。
//   これはFirestoreを使う実際のアプリで広く使われている対策
final class NetworkMonitor: ObservableObject {
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

    private var wasConnected = true
    private var lastInterfaceType: NWInterface.InterfaceType?
    private var lastReconnectAt: Date = .distantPast
    // ★ 経路の変化が短時間に何度も発火する（セル基地局の切り替え中など）ことがあるため、
    //   張り直し自体は最低間隔を空けて行う（無駄な再接続の連打を防ぐ）
    private let minReconnectInterval: TimeInterval = 8
    private var offlineBannerWorkItem: DispatchWorkItem?
    private let offlineBannerDelay: TimeInterval = 3

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let nowConnected = path.status == .satisfied
            // ★ 実際に使われている経路の種別だけを見る（Wi-Fi⇄モバイル通信の切り替え検知用）
            let candidateTypes: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet]
            let currentInterface = candidateTypes.first(where: { path.usesInterfaceType($0) })

            DispatchQueue.main.async {
                self.isConnected = nowConnected
                self.updateOfflineBanner(nowConnected: nowConnected)

                let regainedConnection = nowConnected && !self.wasConnected
                let interfaceChanged = nowConnected && self.lastInterfaceType != nil && currentInterface != self.lastInterfaceType

                if regainedConnection || interfaceChanged {
                    self.reconnectFirestoreIfNeeded()
                }

                self.wasConnected = nowConnected
                if nowConnected {
                    self.lastInterfaceType = currentInterface
                }
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

    // ★ アプリがバックグラウンドから復帰した時（電波の弱い会場でしばらく画面を
    //   閉じていた等）にも、念のため同じ張り直しを行う。回線自体は変わっていなくても、
    //   バックグラウンド中にOS側でストリームが切られていることがあるため
    func reconnectFirestoreOnForeground() {
        reconnectFirestoreIfNeeded()
    }

    private func reconnectFirestoreIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastReconnectAt) >= minReconnectInterval else { return }
        lastReconnectAt = now

        let db = Firestore.firestore()
        db.disableNetwork { error in
            if let error { print("🔥 NetworkMonitor: disableNetwork error:", error) }
            db.enableNetwork { error in
                if let error { print("🔥 NetworkMonitor: enableNetwork error:", error) }
            }
        }
    }

    deinit {
        monitor.cancel()
    }
}
