//
//  NextEventCardView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/07.
//

import SwiftUI
import Combine

struct NextEventCardView: View {
    let event: Event
    let group: IdolGroup
    @EnvironmentObject var eventViewModel: EventViewModel

    @State private var animate = false
    @State private var hasStarted = false
    @State private var startAnimation = false

    @State private var startedEvent: Event? = nil
    @State private var startHandled = false

    @State private var tick: Int = 0
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - 種別色（EventType に統一）
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

            HStack(spacing: 16) {

                GroupIcon(
                    group: group,
                    isSelected: hasStarted,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 6) {

                    if hasStarted {
                        Text("✨ イベントが開始しました")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.8))
                    } else {
                        Text("🔥 次のイベントまで")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.black.opacity(0.7))
                    }

                    // MARK: - カウントダウン or タイトル
                    if hasStarted {
                        Text(startedEvent?.title ?? event.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(typeColor)   // ← 統一
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    } else {
                        Text(timeRemainingString)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(typeColor)   // ← 統一
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    // MARK: - グループ名タグ（色統一）
                    Text(group.name)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(typeColor.opacity(0.85))   // ← 統一
                        .foregroundColor(.white)
                        .clipShape(Capsule())

                    if !hasStarted {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                    }

                    Text(formatDate((startedEvent ?? event).date))
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.black.opacity(0.6))
            }
            .padding(18)
            .background(backgroundView)
            .cornerRadius(26)
            .shadow(color: Color.black.opacity(0.1),
                    radius: 18, x: 0, y: 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 130, maxHeight: 150)
        }
        .buttonStyle(PlainButtonStyle())
        .onReceive(timer) { _ in
            tick += 1
            updateCountdown()
        }
        .onAppear {
            startGradientAnimation()
        }
    }

    // MARK: - 背景ビュー
    private var backgroundView: AnyView {
        if hasStarted {
            return AnyView(startedBackground)
        } else {
            return AnyView(animatedBackground)
        }
    }

    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.91, blue: 0.95),
                Color(red: 1.00, green: 0.85, blue: 0.93),
                Color(red: 0.97, green: 0.91, blue: 1.00)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var startedBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.95, blue: 0.6),
                Color(red: 1.0, green: 0.8, blue: 0.9),
                Color(red: 0.9, green: 0.9, blue: 1.0)
            ],
            startPoint: startAnimation ? .topLeading : .bottomTrailing,
            endPoint: startAnimation ? .bottomTrailing : .topLeading
        )
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: startAnimation)
    }

    // MARK: - カウントダウン
    private var timeRemainingString: String {
        _ = tick

        let now = Date()
        let diff = event.date.timeIntervalSince(now)

        if diff <= 0 {
            return "00日 00時間 00分 00秒"
        }

        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(diff.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(diff.truncatingRemainder(dividingBy: 60))

        return String(format: "%02d日 %02d時間 %02d分 %02d秒", days, hours, minutes, seconds)
    }

    // MARK: - 開始判定
    private func updateCountdown() {
        let now = Date()

        if now >= event.date && !startHandled {
            startHandled = true
            hasStarted = true
            startAnimation = true
            startedEvent = event

            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                withAnimation {
                    hasStarted = false
                    startAnimation = false
                    startedEvent = nil
                }
            }
        }
    }

    private func startGradientAnimation() {
        withAnimation(
            .easeInOut(duration: 9)
                .repeatForever(autoreverses: true)
        ) {
            animate = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E) HH:mm"
        return f.string(from: date)
    }
}
