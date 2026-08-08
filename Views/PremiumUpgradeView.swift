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
            .alert("アップグレードしました", isPresented: $didFinishSuccessfully) {
                Button("OK") { dismiss() }
            } message: {
                Text("推しグループを5件まで登録できるようになりました。")
            }
            .task {
                await loadPrice()
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
            Text("プレミアムに登録すると、登録できる推しグループの上限が広がります")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            comparisonRow(title: "無課金", value: "2グループまで", isHighlighted: false)
            Divider().overlay(Color.white.opacity(0.12))
            comparisonRow(title: "プレミアム", value: "5グループまで", isHighlighted: true)
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

    private func comparisonRow(title: String, value: String, isHighlighted: Bool) -> some View {
        HStack {
            HStack(spacing: 6) {
                if isHighlighted {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(premiumGold)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isHighlighted ? premiumGold : .white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(16)
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
