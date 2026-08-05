//
//  OshiFortuneView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import NukeUI

// ★ オシニウムタブの「あったら便利な機能」その2：今日の推し活占い。
//   完全にクライアント側で完結する遊び要素（バックエンド不要）。同じ日にもう一度開いても
//   結果が変わらないよう、日付＋グループIDをシードにして結果と当日の日付をUserDefaultsに保存する
struct OshiFortuneView: View {
    let group: IdolGroup?

    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @State private var result: OshiFortuneResult? = nil
    @State private var isRevealing = false

    // ★ 大吉を引いた時だけの派手な演出（本人のアイコンを中心にきらめきが弾ける）
    @State private var showCelebration = false
    @State private var celebrationPulse = false

    private let accentColor = Color(red: 0.95, green: 0.72, blue: 0.35)
    private let accentColor2 = Color(red: 0.95, green: 0.55, blue: 0.55)

    private var storageKey: String {
        "oshiFortune_\(group?.id ?? "default")"
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    if let result {
                        resultCard(result)
                    } else {
                        drawButton
                    }
                }
                .padding(20)
                .padding(.top, 12)
            }
            .background(Color.appBackground.ignoresSafeArea())

            if showCelebration {
                daikichiCelebrationOverlay
            }
        }
        .navigationTitle("今日の推し活占い")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadTodayResultIfAny)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundColor(accentColor)
            Text(group.map { "\($0.name)との今日の相性は？" } ?? "今日の推し活運勢")
                .font(.system(size: 15, weight: .bold))
            Text(todayLabel())
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            fortunePointsBadge
                .padding(.top, 6)
        }
    }

    // ★ 大吉ポイントの現在地。タップすると交換画面（アプリの着せ替え機能）に進める
    private var fortunePointsBadge: some View {
        NavigationLink {
            FortunePointExchangeView()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 11))
                Text("大吉ポイント \(settingsVM.settings.oshiFortunePoints) pt")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(accentColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var drawButton: some View {
        Button {
            draw()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 26))
                Text("占いを引く")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: accentColor.opacity(0.35), radius: 14, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private func resultCard(_ result: OshiFortuneResult) -> some View {
        VStack(spacing: 16) {
            Text(result.rank)
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
                .scaleEffect(isRevealing ? 1 : 0.6)
                .opacity(isRevealing ? 1 : 0)

            if result.rank == "大吉" {
                Text("大吉ポイント +1 獲得！")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.25)))
                    .opacity(isRevealing ? 1 : 0)
            }

            Text(result.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Color.white.opacity(0.3))

            HStack {
                VStack(spacing: 2) {
                    Text("ラッキーアクション")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text(result.luckyAction)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30).overlay(Color.white.opacity(0.3))

                VStack(spacing: 2) {
                    Text("ラッキーカラー")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text(result.luckyColor)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accentColor.opacity(0.35), radius: 16, x: 0, y: 8)
        )
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                isRevealing = true
            }
            if result.rank == "大吉" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    triggerCelebration()
                }
            }
        }
    }

    // MARK: - 大吉の演出（アイコンが弾む＋きらめきが放射状に飛び散る）

    private func triggerCelebration() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showCelebration = true
        celebrationPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                celebrationPulse = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showCelebration = false
            }
        }
    }

    private var daikichiCelebrationOverlay: some View {
        ZStack {
            Color.black.opacity(celebrationPulse ? 0.35 : 0)
                .ignoresSafeArea()

            ForEach(0..<18, id: \.self) { index in
                sparkleParticle(index: index)
            }

            avatarBurst
        }
        .transition(.opacity)
        .onDisappear { celebrationPulse = false }
    }

    private var avatarBurst: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.85), Color.orange.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(celebrationPulse ? 1.15 : 0.6)
                .opacity(celebrationPulse ? 0.9 : 0)

            VStack(spacing: 14) {
                userAvatarImage
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.yellow, .white, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 4
                        )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 20)
                    .scaleEffect(celebrationPulse ? 1.0 : 0.4)
                    .rotationEffect(.degrees(celebrationPulse ? 0 : -20))

                Text("大吉！！")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6)
                    .opacity(celebrationPulse ? 1 : 0)
                    .scaleEffect(celebrationPulse ? 1 : 0.7)
            }
        }
    }

    @ViewBuilder
    private var userAvatarImage: some View {
        if let url = URL(string: settingsVM.settings.iconURL), !settingsVM.settings.iconURL.isEmpty {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(String(settingsVM.settings.displayName.prefix(1)))
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // ★ 中心から放射状に18個のきらめきを飛ばす。インデックスだけで角度・見た目を決める
    //   ことで、再描画のたびに位置がランダムに変わってチラつくのを防ぐ
    private func sparkleParticle(index: Int) -> some View {
        let angle = Double(index) / 18.0 * 2 * Double.pi
        let distance: CGFloat = 130 + CGFloat(index % 3) * 30
        let dx = CGFloat(cos(angle)) * distance
        let dy = CGFloat(sin(angle)) * distance
        let icons = ["sparkle", "star.fill", "sparkles"]
        let icon = icons[index % icons.count]
        let colors: [Color] = [.yellow, .white, .orange]
        let color = colors[index % colors.count]
        let size: CGFloat = 14 + CGFloat(index % 4) * 3

        return Image(systemName: icon)
            .font(.system(size: size))
            .foregroundColor(color)
            .offset(x: celebrationPulse ? dx : 0, y: celebrationPulse ? dy : 0)
            .opacity(celebrationPulse ? 0 : 1)
            .scaleEffect(celebrationPulse ? 1.3 : 0.2)
            .animation(.easeOut(duration: 1.1).delay(Double(index) * 0.015), value: celebrationPulse)
    }

    private func todayLabel() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日(E)"
        return f.string(from: Date())
    }

    // MARK: - 抽選と当日結果の保存

    private func draw() {
        let picked = Self.weightedDraw()
        isRevealing = false
        result = picked
        if let data = try? JSONEncoder().encode(StoredFortune(dateKey: Self.dateKey(for: Date()), result: picked)) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if picked.rank == "大吉" {
            settingsVM.addFortunePoint()
        }
    }

    // ★ 大吉だけ確率10%、残り5種は均等に90%を分け合う重み付き抽選
    //   （OshiFortuneResult.all の先頭が大吉である前提）
    private static func weightedDraw() -> OshiFortuneResult {
        let daikichi = OshiFortuneResult.all[0]
        let others = Array(OshiFortuneResult.all.dropFirst())
        guard !others.isEmpty else { return daikichi }

        if Double.random(in: 0..<1) < 0.10 {
            return daikichi
        }
        return others.randomElement() ?? daikichi
    }

    private func loadTodayResultIfAny() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(StoredFortune.self, from: data),
              stored.dateKey == Self.dateKey(for: Date()) else { return }
        result = stored.result
        isRevealing = true
    }

    private static func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private struct StoredFortune: Codable {
        let dateKey: String
        let result: OshiFortuneResult
    }
}

struct OshiFortuneResult: Codable, Equatable {
    let rank: String
    let message: String
    let luckyAction: String
    let luckyColor: String

    static let all: [OshiFortuneResult] = [
        OshiFortuneResult(rank: "大吉", message: "今日はきっと嬉しいお知らせが届く日。SNSのチェックを忘れずに！", luckyAction: "新曲を聴く", luckyColor: "ゴールド"),
        OshiFortuneResult(rank: "吉", message: "推しの魅力を再発見できそう。過去の写真や動画を見返してみて。", luckyAction: "過去の投稿を見返す", luckyColor: "ピンク"),
        OshiFortuneResult(rank: "中吉", message: "グッズとの出会いに恵まれる日。ふらっと立ち寄ったお店で掘り出し物が。", luckyAction: "お店に立ち寄る", luckyColor: "ラベンダー"),
        OshiFortuneResult(rank: "小吉", message: "ファン仲間との会話が弾む一日。感想をシェアしてみよう。", luckyAction: "感想を投稿する", luckyColor: "スカイブルー"),
        OshiFortuneResult(rank: "末吉", message: "焦らずマイペースに。推し活の予定をゆっくり立てるのに向いている日。", luckyAction: "次のイベントを調べる", luckyColor: "ミントグリーン"),
        OshiFortuneResult(rank: "凶", message: "無理は禁物。今日はゆっくり休んで、また明日から推し活を楽しもう。", luckyAction: "早めに休む", luckyColor: "グレー")
    ]
}
