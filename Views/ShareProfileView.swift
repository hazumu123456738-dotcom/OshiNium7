//
//  ShareProfileView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import NukeUI

// ★ 自分のプロフィールを他の人に見つけて（フォローして）もらうための共有画面。
//   招待制グループのShareLinkと同じく、リンクをタップすると相手のアプリで
//   自分のUserProfileViewが直接開く（oshinium://profile?uid=<自分のuid>）
struct ShareProfileView: View {
    let uid: String
    let displayName: String
    let iconURL: String?

    @State private var didCopyLink = false
    @State private var showScanner = false
    @State private var scannedProfileUid: String?
    @State private var scanErrorMessage: String?

    private let accentColor = Color(red: 0.70, green: 0.55, blue: 0.98)
    private let accentColor2 = Color(red: 0.90, green: 0.60, blue: 0.95)

    private var profileLink: String { "oshinium://profile?uid=\(uid)" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    iconView
                    Text(displayName)
                        .font(.system(size: 17, weight: .bold))
                    Text("このQRコードやリンクを知っている人は、あなたのプロフィールをすぐに見つけてフォローできます")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.top, 12)

                qrCodeCard

                VStack(alignment: .leading, spacing: 8) {
                    Text("プロフィールリンク")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text(profileLink)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 8)

                        Button {
                            UIPasteboard.general.string = profileLink
                            withAnimation(.easeInOut(duration: 0.15)) { didCopyLink = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.15)) { didCopyLink = false }
                            }
                        } label: {
                            Image(systemName: didCopyLink ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(didCopyLink ? .green : accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.appCardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                )

                ShareLink(item: URL(string: profileLink) ?? URL(string: "https://oshinium.app")!,
                          subject: Text("\(displayName)さんのOshiNiumプロフィール"),
                          message: Text("OshiNiumでフォローしてね！")) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("プロフィールをシェア")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
                }

                // ★ 相手のプロフィールQRコードをこちらから読み取ってフォローしに行く導線
                Button {
                    showScanner = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("QRコードをスキャンする")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().stroke(accentColor, lineWidth: 1.3))
                }
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("プロフィールをシェア")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerScreen { value in
                handleScannedValue(value)
            }
        }
        .sheet(isPresented: Binding(
            get: { scannedProfileUid != nil },
            set: { if !$0 { scannedProfileUid = nil } }
        )) {
            if let scannedProfileUid {
                NavigationStack {
                    UserProfileView(uid: scannedProfileUid)
                }
            }
        }
        .alert("読み取れませんでした", isPresented: Binding(
            get: { scanErrorMessage != nil },
            set: { if !$0 { scanErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { scanErrorMessage = nil }
        } message: {
            Text(scanErrorMessage ?? "")
        }
    }

    // ★ 読み取った文字列がOshiNiumのプロフィールリンクかどうかを判定する
    private func handleScannedValue(_ value: String) {
        guard let url = URL(string: value),
              url.scheme == "oshinium", url.host == "profile",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scannedUid = components.queryItems?.first(where: { $0.name == "uid" })?.value,
              !scannedUid.isEmpty else {
            scanErrorMessage = "これはOshiNiumのプロフィールQRコードではないようです"
            return
        }
        scannedProfileUid = scannedUid
    }

    // ★ インスタのように、QRコードを単色の白黒ではなくアプリのアクセントカラーの
    //   グラデーションで塗る。生成したQRコードを透明背景のテンプレート画像にし、
    //   .foregroundStyleでグラデーションを重ねて着色する
    private var qrCodeCard: some View {
        Group {
            if let uiImage = Self.generateQRTemplateImage(from: profileLink) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none)
                    .renderingMode(.template)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaledToFit()
                    .frame(width: 210, height: 210)
                    .padding(20)
            } else {
                Text("QRコードを生成できませんでした")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 210, height: 210)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL, let url = URL(string: iconURL), !iconURL.isEmpty {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                } else {
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Circle()
            .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 72, height: 72)
            .overlay(
                Text(String(displayName.prefix(1)))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // ★ QRコードのモジュール（黒）だけを不透明、それ以外（白）を透明にした
    //   テンプレート画像を作る。CIMaskToAlphaが「黒→不透明、白→透明」に変換してくれる
    private static func generateQRTemplateImage(from string: String) -> UIImage? {
        let context = CIContext()

        let qrFilter = CIFilter.qrCodeGenerator()
        qrFilter.message = Data(string.utf8)
        qrFilter.correctionLevel = "M"
        guard let qrImage = qrFilter.outputImage else { return nil }

        let maskFilter = CIFilter.maskToAlpha()
        maskFilter.inputImage = qrImage
        guard let alphaImage = maskFilter.outputImage else { return nil }

        let transformed = alphaImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
