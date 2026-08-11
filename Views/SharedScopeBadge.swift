//
//  SharedScopeBadge.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/07.
//

import SwiftUI

// ★ 「この画面の内容は共有されるのか、自分だけに表示されるのか」を一目で伝えるための
//   小さなバッジ。予定はグループに共有されるが、持ち物チェックリスト・推し活の金額・
//   思い出日記・秘密の予定は自分だけにしか見えない（Firestoreルールでもuid限定）。
//   この違いが画面を見ただけでは分かりにくいという指摘を受けて追加した
struct SharedScopeBadge: View {
    enum Scope {
        // ★ sharedCalendar(2026/08/12追加): プライベート/共有カレンダーへ保存する予定は
        //   isSecretがfalseでも「グループ全員」には共有されない。「共有=グループ全員」と
        //   誤解される表示を避けるため、カレンダー種別ごとに区別できるケースを追加した
        case shared, `private`, sharedCalendar

        var icon: String {
            switch self {
            case .shared: return "person.2.fill"
            case .private: return "lock.fill"
            case .sharedCalendar: return "person.crop.circle.badge.checkmark"
            }
        }

        var label: String {
            switch self {
            case .shared: return "グループに共有されます"
            case .private: return "自分だけに表示されます"
            case .sharedCalendar: return "このカレンダーのメンバーにのみ共有されます"
            }
        }
    }

    let scope: Scope
    // ★ 白カード上ではtintの色文字＋薄いtint背景、グラデーションのヒーローカード上では
    //   白文字＋半透明の白背景にする（どちらの背景でも読みやすくするため）
    var tint: Color = .secondary
    var onGradient: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scope.icon)
                .font(.system(size: 9, weight: .bold))
                .accessibilityHidden(true)
            Text(scope.label)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(onGradient ? .white.opacity(0.95) : tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(onGradient ? Color.white.opacity(0.22) : tint.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }
}
