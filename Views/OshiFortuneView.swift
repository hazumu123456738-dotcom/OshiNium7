//
//  OshiFortuneView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import NukeUI
import FirebaseFirestore
import FirebaseAuth

// ★ オシニウムタブの「あったら便利な機能」その2：今日の推し活占い。
//   完全にクライアント側で完結する遊び要素（バックエンド不要）。同じ日にもう一度開いても
//   結果が変わらないよう、日付＋グループIDをシードにして結果と当日の日付をUserDefaultsに保存する
struct OshiFortuneView: View {
    let group: IdolGroup?

    @EnvironmentObject var settingsVM: UserSettingsViewModel

    @State private var result: OshiFortuneResult? = nil
    @State private var isRevealing = false

    // ★ 大吉～小吉を引いた時の演出（本人のアイコンや色つきのきらめきが弾ける。
    //   ランクごとの派手さの違いはOshiFortuneResult.celebrationTier参照）
    @State private var showCelebration = false
    @State private var celebrationPulse = false

    private let accentColor = Color(red: 0.95, green: 0.72, blue: 0.35)
    private let accentColor2 = Color(red: 0.95, green: 0.55, blue: 0.55)

    // ★ 2026-08-08: 以前はグループIDを含めていたため、グループを切り替えるたびに
    //   別の抽選として何度でも引けてしまっていた(ポイントの不正な稼ぎ放題にもなりうる)。
    //   「今日の推し活占い」は1日1回、どのグループを見ていても共通の1回にする
    private var storageKey: String { "oshiFortune" }

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
                fortuneCelebrationOverlay
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

            pointsBadge
                .padding(.top, 6)
        }
    }

    // ★ ポイントの現在地。タップすると交換画面（アプリの着せ替え機能）に進める
    private var pointsBadge: some View {
        NavigationLink {
            PointExchangeView()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 11))
                Text("ポイント \(settingsVM.settings.points) pt")
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

            if result.pointsAwarded > 0 {
                Text("ポイント +\(result.pointsAwarded) 獲得！")
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
                .fill(LinearGradient(colors: result.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: result.gradientColors[0].opacity(0.35), radius: 16, x: 0, y: 8)
        )
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                isRevealing = true
            }
            if result.celebrationTier != .none {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    triggerCelebration(for: result)
                }
            }
        }
    }

    // MARK: - 結果ごとの演出（運勢が良いほど派手に、大吉だけアイコンが弾む＋きらめきが放射状に飛び散る。
    //   凶・末吉は演出自体を出さず、resultCardの通常のフェード＋拡大だけの控えめな見せ方にする）

    private func triggerCelebration(for result: OshiFortuneResult) {
        let tier = result.celebrationTier
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showCelebration = true
        celebrationPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                celebrationPulse = true
            }
        }
        // ★ 演出の強さに応じて表示時間も変える（大吉は長く余韻を残し、軽い演出はさっと消す）
        let holdDuration: Double = tier == .grand ? 2.6 : (tier == .medium ? 1.9 : 1.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
            withAnimation(.easeOut(duration: 0.4)) {
                showCelebration = false
            }
        }
    }

    private var fortuneCelebrationOverlay: some View {
        let tier = result?.celebrationTier ?? .none
        let particleCount = tier == .grand ? 18 : (tier == .medium ? 12 : 6)
        return ZStack {
            Color.black.opacity(celebrationPulse ? (tier == .grand ? 0.35 : 0.2) : 0)
                .ignoresSafeArea()

            ForEach(0..<particleCount, id: \.self) { index in
                sparkleParticle(index: index, total: particleCount)
            }

            avatarBurst
        }
        .transition(.opacity)
        .onDisappear { celebrationPulse = false }
    }

    private var avatarBurst: some View {
        let color = result?.celebrationColor ?? .yellow
        let tier = result?.celebrationTier ?? .none
        // ★ 大吉だけアイコン自体が弾む演出にする。吉・中吉・小吉はアイコンを動かさず、
        //   周りの色つきグローとランクの文字だけで「良い結果だった」ことを伝える
        let showsAvatar = tier == .grand

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.85), color.opacity(0)],
                        center: .center, startRadius: 0, endRadius: tier == .grand ? 140 : 100
                    )
                )
                .frame(width: tier == .grand ? 280 : 200, height: tier == .grand ? 280 : 200)
                .scaleEffect(celebrationPulse ? 1.15 : 0.6)
                .opacity(celebrationPulse ? 0.9 : 0)

            VStack(spacing: 14) {
                if showsAvatar {
                    userAvatarImage
                        .frame(width: 108, height: 108)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [color, .white, color], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 4
                            )
                        )
                        .shadow(color: color.opacity(0.6), radius: 20)
                        .scaleEffect(celebrationPulse ? 1.0 : 0.4)
                        .rotationEffect(.degrees(celebrationPulse ? 0 : -20))
                }

                if let result {
                    Text(tier == .grand ? "\(result.rank)！！" : "\(result.rank)！")
                        .font(.system(size: tier == .grand ? 26 : 20, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6)
                        .opacity(celebrationPulse ? 1 : 0)
                        .scaleEffect(celebrationPulse ? 1 : 0.7)
                }
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

    // ★ 中心から放射状にきらめきを飛ばす。インデックスだけで角度・見た目を決めることで、
    //   再描画のたびに位置がランダムに変わってチラつくのを防ぐ。個数・色は運勢のランクに応じて変える
    private func sparkleParticle(index: Int, total: Int) -> some View {
        let mainColor = result?.celebrationColor ?? .yellow
        let angle = Double(index) / Double(total) * 2 * Double.pi
        let distance: CGFloat = 130 + CGFloat(index % 3) * 30
        let dx = CGFloat(cos(angle)) * distance
        let dy = CGFloat(sin(angle)) * distance
        let icons = ["sparkle", "star.fill", "sparkles"]
        let icon = icons[index % icons.count]
        let colors: [Color] = [mainColor, .white, mainColor.opacity(0.7)]
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
        return CachedFormatters.date(format: "M月d日(E)").string(from: Date())
    }

    // MARK: - 抽選と当日結果の保存

    // ★ 2026/08/08にグループ切り替えでの稼ぎ放題は塞いだが、UserDefaultsは端末ローカルの
    //   保存先でしかなく、アプリの再インストール・端末変更で簡単にリセットできてしまい、
    //   その回数だけポイントを再取得できる抜け穴が残っていた（占い結果自体はローカル保存のままで
    //   問題ないが、ポイント付与だけはusers/{uid}/fortuneLog/{今日の日付}の存在をFirestore側でも
    //   確認し、既にその日ぶんを受け取っていれば再入手できないようにする）
    private func draw() {
        let picked = Self.weightedDraw()
        isRevealing = false
        result = picked
        if let data = try? JSONEncoder().encode(StoredFortune(dateKey: Self.dateKey(for: Date()), result: picked)) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        let points = picked.pointsAwarded
        guard points > 0, let uid = Auth.auth().currentUser?.uid else { return }

        let logRef = Firestore.firestore()
            .collection("users").document(uid)
            .collection("fortuneLog").document(Self.dateKey(for: Date()))

        logRef.getDocument { snapshot, _ in
            guard snapshot?.exists != true else { return }
            logRef.setData(["grantedAt": Timestamp(date: Date()), "points": points]) { error in
                if let error {
                    print("🔥 fortuneLog書き込みエラー:", error)
                    return
                }
                settingsVM.addPoints(points)
            }
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
        CachedFormatters.date(format: "yyyy-MM-dd", locale: Locale.current).string(from: date)
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

    // ★ 小吉以上(大吉/吉/中吉/小吉)でポイント獲得。大吉に近いほど大きくなる（末吉/凶は0）。
    //   2026/08/13：着せ替えアイコンの交換ポイントを500/200/100pt→100/50/25ptへ引き下げたのに
    //   合わせ、大吉の獲得ポイントも4pt→10ptに引き上げた（以前は最安の桜輝100ptまで大吉のみで
    //   25回引く必要があった。10ptなら2.5回でよく、行動報酬として現実的な距離になる）。
    //   他のランクは大吉との相対的な差を保ったまま同じ比率で引き上げている
    var pointsAwarded: Int {
        switch rank {
        case "大吉": return 10
        case "吉": return 6
        case "中吉": return 4
        case "小吉": return 2
        default: return 0
        }
    }

    static let all: [OshiFortuneResult] = [
        OshiFortuneResult(rank: "大吉", message: "今日はきっと嬉しいお知らせが届く日。SNSのチェックを忘れずに！", luckyAction: "新曲を聴く", luckyColor: "ゴールド"),
        OshiFortuneResult(rank: "吉", message: "推しの魅力を再発見できそう。過去の写真や動画を見返してみて。", luckyAction: "過去の投稿を見返す", luckyColor: "ピンク"),
        OshiFortuneResult(rank: "中吉", message: "グッズとの出会いに恵まれる日。ふらっと立ち寄ったお店で掘り出し物が。", luckyAction: "お店に立ち寄る", luckyColor: "ラベンダー"),
        OshiFortuneResult(rank: "小吉", message: "ファン仲間との会話が弾む一日。感想をシェアしてみよう。", luckyAction: "感想を投稿する", luckyColor: "スカイブルー"),
        OshiFortuneResult(rank: "末吉", message: "焦らずマイペースに。推し活の予定をゆっくり立てるのに向いている日。", luckyAction: "次のイベントを調べる", luckyColor: "ミントグリーン"),
        OshiFortuneResult(rank: "凶", message: "無理は禁物。今日はゆっくり休んで、また明日から推し活を楽しもう。", luckyAction: "早めに休む", luckyColor: "グレー")
    ]
}

// MARK: - 運勢ごとの見た目（色・演出の強さ）
//   ★ 2026/08/13追加：以前は結果カードの色も演出（大吉の弾むアイコン＋きらめき）も
//   全ランク共通で、運勢が良くても悪くても見た目が同じだった。各ランクのluckyColorに
//   実際に対応する色をカード背景に使い、運勢が良いほど演出も派手にすることで、
//   結果を見た瞬間に「良い/悪い」が直感的に伝わるようにする
extension OshiFortuneResult {
    enum CelebrationTier {
        case none    // 末吉・凶：resultCard自身の通常のフェード＋拡大だけ。演出は出さない
        case light   // 小吉：控えめなきらめきのみ、アイコンは動かさない
        case medium  // 吉・中吉：きらめき＋グローだが、アイコンは動かさない
        case grand   // 大吉：アイコンが弾む、最も派手な演出
    }

    var celebrationTier: CelebrationTier {
        switch rank {
        case "大吉": return .grand
        case "吉", "中吉": return .medium
        case "小吉": return .light
        default: return .none
        }
    }

    // ★ luckyColorの文言（ゴールド／ピンク／ラベンダー／スカイブルー／ミントグリーン／グレー）と
    //   実際に対応する色にしている
    var gradientColors: [Color] {
        switch rank {
        case "大吉":
            return [Color(red: 0.96, green: 0.76, blue: 0.28), Color(red: 0.94, green: 0.56, blue: 0.20)]
        case "吉":
            return [Color(red: 0.96, green: 0.56, blue: 0.66), Color(red: 0.89, green: 0.38, blue: 0.55)]
        case "中吉":
            return [Color(red: 0.68, green: 0.56, blue: 0.92), Color(red: 0.55, green: 0.40, blue: 0.85)]
        case "小吉":
            return [Color(red: 0.45, green: 0.72, blue: 0.96), Color(red: 0.28, green: 0.55, blue: 0.90)]
        case "末吉":
            return [Color(red: 0.46, green: 0.80, blue: 0.66), Color(red: 0.28, green: 0.68, blue: 0.53)]
        default: // 凶
            return [Color(red: 0.62, green: 0.62, blue: 0.66), Color(red: 0.46, green: 0.46, blue: 0.50)]
        }
    }

    // ★ きらめき・グローに使う主色。カード背景よりやや明るく、白背景の演出オーバーレイ上でも
    //   はっきり見えるようにしている
    var celebrationColor: Color {
        switch rank {
        case "大吉": return .yellow
        case "吉": return Color(red: 1.0, green: 0.62, blue: 0.75)
        case "中吉": return Color(red: 0.75, green: 0.65, blue: 0.98)
        case "小吉": return Color(red: 0.55, green: 0.82, blue: 1.0)
        default: return .white
        }
    }
}
