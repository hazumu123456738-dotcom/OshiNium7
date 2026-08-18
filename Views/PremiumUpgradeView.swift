//
//  PremiumUpgradeView.swift
//  OshiNium7
//

import SwiftUI
import StoreKit

// ★ 無課金(2グループまで)とプレミアム(5グループまで)の違いを見せ、実際にStoreKit経由で
//   購入できる画面。App Store Connect側でSubscriptionManager.monthlyProductIdの商品を
//   まだ作成していない間は、purchasePremium()が.productNotConfiguredを返すため、
//   その旨をそのままユーザーに伝える（黙って失敗させない）
//   ★ この画面は常に「宇宙・きらきら」の濃紺背景で固定したいが、.preferredColorScheme(.dark)は
//   使わない。マイページ→設定→プレミアムのようにsheetが二重に重なった状態でこの画面を開くと、
//   閉じた後もpreferredColorSchemeの指定がウィンドウ側に残ってしまい、下の設定画面までダークモードに
//   変わって戻らなくなる既知のSwiftUIの罠がある(ネストしたsheetでの既知の不具合)。
//   そのため背景・文字色はすべて明示的な色(.white/.black系)だけで組み、システムのcolorSchemeには
//   一切依存しない形にする(.ultraThinMaterialのような、colorSchemeで見た目が変わる部品も使わない)
struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var didFinishSuccessfully = false
    // ★ App Store審査ガイドライン3.1.2: 購入前の画面に「サービス内容・期間・価格」を
    //   明示する必要がある。App Store Connectに実際に設定した価格をStoreKitから取得して
    //   表示する(未設定の間はfallbackTextを使う。SubscriptionManager.monthlyProductIdの
    //   コメント通り、実際の金額は月額400円で登録済み)
    @State private var fetchedPriceText: String?
    private var priceText: String { fetchedPriceText ?? "¥400" }

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2
    private let premiumGold = Color(red: 1.0, green: 0.84, blue: 0.55)

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        header

                        comparisonCard

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(10)
                                .background(Color.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        purchaseButton

                        subscriptionDisclosure

                        Button {
                            restore()
                        } label: {
                            Text("購入を復元する")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .disabled(isPurchasing)

                        legalLinks
                    }
                    .padding(20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .tint(.white)
                }
            }
            .fullScreenCover(isPresented: $didFinishSuccessfully) {
                PremiumSuccessView { dismiss() }
            }
            .task {
                await loadPrice()
            }
            .onAppear {
                AnalyticsManager.logPremiumUpgradeViewShown()
            }
        }
    }

    // ★ 審査ガイドライン3.1.2が求める「期間・価格・自動更新に関する説明」。
    //   購入ボタンのすぐ下、一番目立つ位置に置く
    private var subscriptionDisclosure: some View {
        Text("月額\(priceText)（税込）・1か月ごとの自動更新。いつでも解約できます。")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.55))
            .multilineTextAlignment(.center)
    }

    // ★ 審査ガイドライン3.1.2が求める「利用規約・プライバシーポリシーへの実動リンク」
    private var legalLinks: some View {
        HStack(spacing: 16) {
            NavigationLink("利用規約") {
                TermsOfServiceView()
            }
            NavigationLink("プライバシーポリシー") {
                PrivacyPolicyView()
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.white.opacity(0.6))
        .padding(.top, 4)
    }

    // ★ StoreKitから実際の価格を取得する。App Store Connect側の審査待ち・未設定の間は
    //   products(for:)が空を返すため、priceTextのfallback(¥400)がそのまま使われる
    private func loadPrice() async {
        if let product = try? await Product.products(for: [SubscriptionManager.monthlyProductId]).first {
            await MainActor.run {
                fetchedPriceText = product.displayPrice
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            SparkleBurstIcon(colors: [premiumGold, accentColor2, accentColor])
                .frame(width: 56, height: 56)

            Text("もっと推せる、もっと広がる")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
            Text("プレミアムに登録すると、推し活を支える機能の上限がまとめて広がります")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // ★ 以前は推しグループの件数だけを見せていたが、実際にはグループ・テンプレート・
    //   カレンダー・グループチャットの4系統すべてに差があるため、それを漏れなく
    //   一覧できる表形式にする(ユーザーからの「全部何ができるか分かるようにして」指示)
    private struct ComparisonFeature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let freeValue: String
        let premiumValue: String
    }

    private var comparisonFeatures: [ComparisonFeature] {
        [
            ComparisonFeature(icon: "person.3.fill", title: "推しグループ登録", freeValue: "2件", premiumValue: "5件"),
            ComparisonFeature(icon: "checklist", title: "持ち物テンプレート保存", freeValue: "3件", premiumValue: "10件"),
            ComparisonFeature(icon: "calendar.badge.plus", title: "追加カレンダー作成", freeValue: "1件", premiumValue: "5件"),
            ComparisonFeature(icon: "arrow.triangle.2.circlepath", title: "カレンダーの作り直し", freeValue: "10日で1回", premiumValue: "10日で5回"),
            ComparisonFeature(icon: "bubble.left.and.bubble.right.fill", title: "グループチャット作成", freeValue: "利用不可", premiumValue: "3件"),
            ComparisonFeature(icon: "person.2.fill", title: "グループチャット参加", freeValue: "1件", premiumValue: "3件")
        ]
    }

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("できること")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("無課金")
                    .frame(width: 64)
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill").font(.system(size: 9))
                    Text("プレミアム")
                }
                .frame(width: 76)
                .foregroundColor(premiumGold)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ForEach(comparisonFeatures) { feature in
                Divider().overlay(Color.white.opacity(0.1))
                comparisonRow(feature)
            }
        }
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [premiumGold.opacity(0.5), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    private func comparisonRow(_ feature: ComparisonFeature) -> some View {
        HStack(spacing: 8) {
            Image(systemName: feature.icon)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 16)
            Text(feature.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Text(feature.freeValue)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 64)
            Text(feature.premiumValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(premiumGold)
                .frame(width: 76)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var purchaseButton: some View {
        Button {
            purchase()
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(subscriptionManager.isPremium ? "登録済みです" : "プレミアムにアップグレード")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(ShiftingGradient(colors: [accentColor, accentColor2, premiumGold, accentColor2]))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: accentColor.opacity(0.55), radius: 18, x: 0, y: 8)
            .opacity(subscriptionManager.isPremium ? 0.5 : 1)
        }
        .disabled(isPurchasing || subscriptionManager.isPremium)
    }

    private func purchase() {
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                let outcome = try await subscriptionManager.purchasePremium()
                await MainActor.run {
                    isPurchasing = false
                    switch outcome {
                    case .success:
                        didFinishSuccessfully = true
                    case .cancelled:
                        break
                    case .pending:
                        errorMessage = "承認待ちです。家族の代表者の承認などが完了すると自動的に反映されます。"
                    case .productNotConfigured:
                        errorMessage = "現在、購入手続きを準備中です。しばらくお待ちください。"
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restore() {
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                let restored = try await subscriptionManager.restorePurchases()
                await MainActor.run {
                    isPurchasing = false
                    if restored {
                        didFinishSuccessfully = true
                    } else {
                        errorMessage = "復元できる購入履歴が見つかりませんでした。"
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 購入完了後の演出画面

// ★ 以前は購入完了を素っ気ないシステムアラート1つで伝えていたが、この画面自体の
//   「宇宙・きらきら」の世界観と落差がありすぎる、かつ「推しグループの上限」しか
//   触れておらず他の特典が伝わらない、という指摘を受けて全面刷新。
//   PremiumUpgradeViewの中からfullScreenCoverとして開く専用画面にする
struct PremiumSuccessView: View {
    var onClose: () -> Void

    @State private var didAppear = false

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2
    private let premiumGold = Color(red: 1.0, green: 0.84, blue: 0.55)

    private let unlockedFeatures: [(icon: String, text: String)] = [
        ("person.3.fill", "推しグループを5件まで登録できます"),
        ("checklist", "持ち物テンプレートを10件まで保存できます"),
        ("calendar.badge.plus", "追加カレンダーを5件まで作成できます"),
        ("arrow.triangle.2.circlepath", "カレンダーの作り直しが10日で5回までできます"),
        ("bubble.left.and.bubble.right.fill", "招待制グループチャットを3件まで作成・参加できます")
    ]

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView {
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [premiumGold.opacity(0.35), .clear],
                                    center: .center, startRadius: 0, endRadius: 90
                                )
                            )
                            .frame(width: 180, height: 180)

                        CelebrationSparkles(colors: [premiumGold, accentColor2, accentColor])
                            .frame(width: 120, height: 120)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(LinearGradient(colors: [premiumGold, accentColor2], startPoint: .top, endPoint: .bottom))
                            .shadow(color: premiumGold.opacity(0.6), radius: 12)
                            .scaleEffect(didAppear ? 1 : 0.4)
                            .opacity(didAppear ? 1 : 0)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 8) {
                        Text("プレミアムにアップグレードしました")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("これから、以下の機能がご利用いただけます")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    VStack(spacing: 12) {
                        ForEach(Array(unlockedFeatures.enumerated()), id: \.offset) { index, feature in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: feature.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                Text(feature.text)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(premiumGold)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 10)
                            .animation(.easeOut(duration: 0.4).delay(0.15 + Double(index) * 0.08), value: didAppear)
                        }
                    }

                    Button {
                        onClose()
                    } label: {
                        Text("推し活を続ける")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                            .shadow(color: accentColor.opacity(0.5), radius: 16, x: 0, y: 8)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                didAppear = true
            }
        }
    }
}

// ★ 成功演出専用の、少し賑やかな祝祭スパークル(ヘッダーの控えめなSparkleBurstIconとは
//   区別し、購入完了という特別な瞬間だけ使う)
private struct CelebrationSparkles: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * 60 + t * 20
                    let radius: CGFloat = 46 + 6 * sin(t * 1.2 + Double(i))
                    Image(systemName: "sparkle")
                        .font(.system(size: i.isMultiple(of: 2) ? 13 : 9))
                        .foregroundColor(colors[i % colors.count])
                        .opacity(0.6 + 0.4 * sin(t * 1.8 + Double(i)))
                        .offset(
                            x: radius * cos(angle * .pi / 180),
                            y: radius * sin(angle * .pi / 180)
                        )
                }
            }
        }
    }
}

// MARK: - 星々が瞬く宇宙背景

// ★ プレミアム画面専用の背景。濃紺〜紫のグラデーションに、ふわっと光るグロー2つと
//   ランダムに瞬く星を重ねる。starsは@Stateで一度だけ生成し、親の再描画(購入中のスピナー表示等)で
//   毎回星の位置が飛び直さないようにする
struct CosmicBackground: View {
    private struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let phase: Double
    }

    @State private var stars: [Star] = (0..<55).map { _ in
        Star(x: .random(in: 0...1), y: .random(in: 0...1), size: .random(in: 1...2.6), phase: .random(in: 0...(2 * .pi)))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.045, green: 0.028, blue: 0.12),
                    Color(red: 0.13, green: 0.07, blue: 0.26),
                    Color(red: 0.22, green: 0.11, blue: 0.32)
                ],
                startPoint: .top, endPoint: .bottom
            )

            Circle()
                .fill(Color.oshiniumPrimary.opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -110, y: -220)

            Circle()
                .fill(Color.oshiniumPrimary2.opacity(0.28))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .offset(x: 130, y: 160)

            GeometryReader { geo in
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ForEach(stars) { star in
                        Circle()
                            .fill(Color.white)
                            .frame(width: star.size, height: star.size)
                            .opacity(0.25 + 0.55 * (0.5 + 0.5 * sin(t * 1.4 + star.phase)))
                            .position(x: star.x * geo.size.width, y: star.y * geo.size.height)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 常にゆっくり色が移り変わるグラデーション（購入ボタン用）

// ★ 「若干色が移り変わっている工夫」の実装。TimelineViewで時間を駆動源にし、
//   hueRotationを穏やかに揺らすことで、派手な虹色回転ではなく上品な色移ろいにする
private struct ShiftingGradient: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                .hueRotation(.degrees(sin(t * 0.6) * 18))
        }
    }
}

// MARK: - ヘッダーのきらめくスパークルアイコン

// ★ 中心のsparklesアイコンをゆっくり脈打たせつつ、周囲に小さなsparkleを配置して
//   きらきら感を出す。過剰にならないよう動きは控えめにする
private struct SparkleBurstIcon: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let angle = Double(i) * 120 + t * 14
                    let radius: CGFloat = 22
                    Image(systemName: "sparkle")
                        .font(.system(size: 10))
                        .foregroundColor(colors[i % colors.count])
                        .opacity(0.55 + 0.45 * sin(t * 1.6 + Double(i)))
                        .offset(
                            x: radius * cos(angle * .pi / 180),
                            y: radius * sin(angle * .pi / 180)
                        )
                }

                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .scaleEffect(1 + 0.06 * sin(t * 1.8))
            }
        }
    }
}
