//
//  NetworkMonitor.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/05.
//

import Foundation
import Network
import Combine

// ★ ネットワーク接続状態をアプリ全体で共有する。Firestoreはオフラインでも
//   キャッシュ済みのデータをそのまま表示し続けられる（永続キャッシュはSDKのデフォルトで
//   有効）が、キャッシュが無い初回起動時などにオフラインだと、リスナーが一度も発火せず
//   「読み込み中」のまま止まって見えてしまう。ここで接続状態を検知し、
//   画面側に「オフラインです」と明示することで、単なる無言のローディングと区別できるようにする
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.oshinium.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
