//
//  OshiNiumOriginalTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI

// ★ 旧AIタブの後継。「イベント当日ハブ」として設計していく（[[oshinium_original_tab_vision]] 参照）。
//   イベントを選ぶと EventHubDetailView に遷移し、会場・天気・チケット・グッズなどの情報を
//   一画面にまとめて確認できる。UIの骨組みをまず作り、あとから各項目を実データに差し替えていく。
struct OshiNiumOriginalTab: View {

    @EnvironmentObject var eventViewModel: EventViewModel

    // ★ ホーム画面で選択中のグループ。このタブもホームと連動させ、
    //   そのグループのイベントだけを扱う（他グループのイベントは表示しない）
    let selectedGroup: IdolGroup?

    @State private var selectedEvent: Event? = nil
    var onOpenCalendar: (() -> Void)? = nil

    // ★ ヒーローカードの矢印/スワイプで前後に移動する対象。
    //   同じグループの予定を日付順に並べたものを「ひとつの時系列」として扱う
    private var orderedGroupEvents: [Event] {
        eventViewModel.events
            .filter { $0.groupId == selectedGroup?.id }
            .sorted { $0.date < $1.date }
    }

    private func adjacentEvent(to event: Event, offset: Int) -> Event? {
        guard let index = orderedGroupEvents.firstIndex(where: { $0.id == event.id }) else { return nil }
        let target = index + offset
        guard orderedGroupEvents.indices.contains(target) else { return nil }
        return orderedGroupEvents[target]
    }

    var body: some View {
        Group {
            if let event = selectedEvent {
                EventHubDetailView(
                    event: event,
                    group: eventViewModel.group(for: event.groupId),
                    onChangeEvent: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedEvent = nil
                        }
                    },
                    previousEvent: adjacentEvent(to: event, offset: -1),
                    nextEvent: adjacentEvent(to: event, offset: 1),
                    onSelectEvent: { newEvent in
                        selectedEvent = newEvent
                    }
                )
            } else {
                EventHubPickerView(
                    selectedEvent: $selectedEvent,
                    currentGroup: selectedGroup,
                    onOpenCalendar: onOpenCalendar
                )
            }
        }
        // ★ ホームでグループを切り替えたら、選択中だったイベント（別グループのもの）は破棄する
        .onChange(of: selectedGroup?.id) { _ in
            selectedEvent = nil
        }
        // ★ このタブは独自のヘッダー（EventHubPickerViewのtopBar／EventHubDetailViewのヒーロー）を
        //   持っているため、空のナビゲーションバー分の余白が画面上部に無駄にできてしまっていた。
        //   非表示にしてもNotificationsTabへのpushは通常通り動作し、遷移先で自前のバーが出る
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - ブリリアントカットダイアモンドの図形（アウトライン）

struct BrilliantGemShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        let topLeft = CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.16)
        let topRight = CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.16)
        let right = CGPoint(x: rect.maxX, y: rect.minY + h * 0.40)
        let bottom = CGPoint(x: rect.minX + w * 0.50, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.minY + h * 0.40)

        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: right)
        path.addLine(to: bottom)
        path.addLine(to: left)
        path.closeSubpath()

        return path
    }
}

// MARK: - クラウン・パビリオンのファセット線（大きく表示するときだけ使用）

struct BrilliantGemFacetLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height

        let topLeft = CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.16)
        let topRight = CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.16)
        let right = CGPoint(x: rect.maxX, y: rect.minY + h * 0.40)
        let bottom = CGPoint(x: rect.minX + w * 0.50, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.minY + h * 0.40)

        // パビリオンのファセット（テーブル両端 → 底の頂点）
        path.move(to: topLeft)
        path.addLine(to: bottom)
        path.move(to: topRight)
        path.addLine(to: bottom)

        // クラウンのファセット（左右のガードル頂点 → 対角のテーブル角）
        path.move(to: left)
        path.addLine(to: topRight)
        path.move(to: right)
        path.addLine(to: topLeft)

        return path
    }
}

// MARK: - 共通コンポーネント（塗り＋輪郭＋任意でファセット線）

struct BrilliantDiamondIcon: View {
    var fill: AnyShapeStyle
    var strokeColor: Color = .white
    var showFacets: Bool = true

    var body: some View {
        ZStack {
            BrilliantGemShape()
                .fill(fill)
            BrilliantGemShape()
                .stroke(strokeColor.opacity(0.7), lineWidth: 1.5)
            if showFacets {
                BrilliantGemFacetLines()
                    .stroke(strokeColor.opacity(0.55), lineWidth: 1)
            }
        }
    }
}

// MARK: - タブバー用アイコン（テンプレート画像として1回だけ生成しキャッシュする）

enum BrilliantDiamondTabIcon {
    @MainActor
    static let image: Image = {
        let content = BrilliantGemShape()
            .fill(Color.black)
            .frame(width: 26, height: 26)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale

        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage.withRenderingMode(.alwaysTemplate))
        }
        return Image(systemName: "diamond.fill")
    }()
}
