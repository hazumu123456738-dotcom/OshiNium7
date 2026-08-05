//
//  NextEventCardView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/07.
//

import SwiftUI
import Combine

// ★ デザイン一新（旧: ホーム画面の派手なグラデーションカード）。
//   OshiNiumタブ（イベントダッシュボード）の他カードと統一感のある、
//   白背景＋アクセントカラーの縁取り・数字を大きく見せるApple純正ウィジェット風のカードにする
struct NextEventCardView: View {
    let event: Event
    let group: IdolGroup
    @EnvironmentObject var eventViewModel: EventViewModel

    @State private var hasStarted = false
    @State private var startedEvent: Event? = nil
    @State private var startHandled = false

    @State private var tick: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var typeColor: Color {
        (startedEvent?.type ?? event.type ?? .other).iconColor
    }

    var body: some View {
        NavigationLink(
            destination: EventDetailView(
                event: startedEvent ?? event,
                isOwner: true,
                eventViewModel: eventViewModel
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    GroupIcon(group: group, isSelected: false, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasStarted ? "✨ イベントが開始しました" : "次のイベントまで")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(group.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(typeColor)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                if hasStarted {
                    Text(startedEvent?.title ?? event.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(typeColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    countdownRow
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(formatDate((startedEvent ?? event).date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(typeColor.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onReceive(timer) { _ in
            tick += 1
            updateCountdown()
        }
    }

    // MARK: - カウントダウン（日・時間・分・秒を数字ブロックで並べる、ウィジェット風の見せ方）
    private var countdownRow: some View {
        let comps = countdownComponents
        return HStack(spacing: 8) {
            countdownUnit(value: comps.days, label: "日")
            countdownUnit(value: comps.hours, label: "時間")
            countdownUnit(value: comps.minutes, label: "分")
            countdownUnit(value: comps.seconds, label: "秒")
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(typeColor)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(typeColor.opacity(0.08))
        )
    }

    private var countdownComponents: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        _ = tick
        let diff = max(0, event.date.timeIntervalSince(Date()))
        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(diff.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(diff.truncatingRemainder(dividingBy: 60))
        return (days, hours, minutes, seconds)
    }

    // MARK: - 開始判定
    private func updateCountdown() {
        let now = Date()

        if now >= event.date && !startHandled {
            startHandled = true
            hasStarted = true
            startedEvent = event

            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                hasStarted = false
                startedEvent = nil
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E) HH:mm"
        return f.string(from: date)
    }
}
