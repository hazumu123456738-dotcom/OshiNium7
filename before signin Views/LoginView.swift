//
//  LoginView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/23.
//

import SwiftUI
import GoogleSignIn
import FirebaseAuth
import FirebaseCore

struct LoginView: View {

    @EnvironmentObject var auth: AuthViewModel

    @State private var rotateSatellite = false
    @State private var starOffset: CGFloat = -200
    @State private var showAppleAlert = false

    var body: some View {

        ZStack {

            // MARK: - 画面全体の宇宙背景（白帯を完全に消す）
            universeBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - ロゴ〜サブタイトル（宇宙空間）
                    universeContent
                        .padding(.top, 40)
                        .padding(.bottom, 20)

                    // MARK: - 白背景エリア
                    VStack(spacing: 16) {

                        appleButton
                        googleButton

                        VStack(spacing: 8) {
                            dividerWithOr
                            anonymousButton

                            Text("※閲覧専用です。投稿や編集はできません。")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }

                        featuresCard

                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.checkerboard")
                                    .foregroundColor(Color.blue.opacity(0.8))
                                Text("OshiNiumは安心・安全な環境を提供します")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)

                            Text("あなたの情報は暗号化され、安全に保護されます。")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }

                        Text("v1.0.0")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.bottom, 16)

                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .background(Color.white)
                    .cornerRadius(24)
                    .padding(.top, -8)
                }
            }
        }
        .alert("すいません、まだ設定中です。", isPresented: $showAppleAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - 宇宙背景（流れ星＋キラキラ）
    private var universeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.15, blue: 0.45),
                    Color(red: 0.25, green: 0.15, blue: 0.65),
                    Color(red: 0.35, green: 0.20, blue: 0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // キラキラ
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.25...0.7)))
                    .frame(width: CGFloat.random(in: 2...4))
                    .offset(
                        x: CGFloat.random(in: -160...160),
                        y: CGFloat.random(in: -300...200)
                    )
            }

            // 流れ星
            LinearGradient(
                colors: [
                    Color.white.opacity(0.0),
                    Color.white.opacity(0.7),
                    Color.white.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 170, height: 3)
            .rotationEffect(.degrees(-20))
            .offset(x: starOffset, y: -120)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 2.5)
                        .repeatForever(autoreverses: false)
                ) {
                    starOffset = 200
                }
            }
        }
    }

    // MARK: - ロゴ・タイトル（シャイン削除済み）
    private var universeContent: some View {
        VStack(spacing: 10) {

            ZStack {

                // ダイヤ本体
                Image("LoginLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.white.opacity(0.8), radius: 14)

                // 衛星（円軌道）
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .offset(x: 70)
                    .rotationEffect(.degrees(rotateSatellite ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 6)
                            .repeatForever(autoreverses: false),
                        value: rotateSatellite
                    )
            }
            .onAppear {
                rotateSatellite = true
            }

            diamondTitle

            Text("推し活のすべてを、ひとつに。")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
        }
    }

    // MARK: - OshiNium（i の点をダイヤに）
    private var diamondTitle: some View {
        HStack(spacing: 0) {
            Text("Osh")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            ZStack(alignment: .top) {
                Text("ı")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appCardBackground)
                    .frame(width: 6, height: 6)
                    .rotationEffect(.degrees(45))
                    .offset(y: -8)
            }

            Text("Nium")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Apple ログインボタン
    private var appleButton: some View {
        Button { showAppleAlert = true } label: {
            HStack {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text("Appleでサインイン")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.25),
                        Color(red: 0.10, green: 0.12, blue: 0.35)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.22), radius: 6, y: 3)
        }
    }

    // MARK: - Google ログインボタン
    private var googleButton: some View {
        Button {
            Task { await googleLogin() }
        } label: {
            HStack {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)

                Spacer()
                Text("Googleでサインイン")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(Color.blue.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.white)
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.10), radius: 5, y: 2)
        }
    }

    // MARK: - 匿名ログイン
    private var anonymousButton: some View {
        Button { anonymousLogin() } label: {
            HStack {
                Image(systemName: "person.circle")
                    .font(.system(size: 18))
                Spacer()
                Text("匿名で続ける（閲覧専用）")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .foregroundColor(Color.blue.opacity(0.8))
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.blue.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(26)
        }
    }

    // MARK: - 「または」
    private var dividerWithOr: some View {
        HStack {
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
            Text("または")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
        }
    }

    // MARK: - 機能カード
    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ログインするとできること")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                featureItem("公開イベントの追加")
                featureItem("公開イベントの編集・削除（投稿者のみ）")
                featureItem("秘密イベントの作成・閲覧（本人のみ）")
                featureItem("通知（リマインダー）")
                featureItem("マルチデバイス同期")
                featureItem("編集提案機能")
                featureItem("自分の投稿履歴の管理")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
    }

    private func featureItem(_ title: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("・")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 10, alignment: .leading)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Google ログイン処理
    @MainActor
    func googleLogin() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

            guard let idToken = result.user.idToken else { return }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken.tokenString,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            auth.user = authResult.user

        } catch {
            print("Google ログイン失敗:", error.localizedDescription)
        }
    }

    // MARK: - 匿名ログイン
    func anonymousLogin() {
        Auth.auth().signInAnonymously { result, error in
            if let error = error {
                print("匿名ログイン失敗:", error.localizedDescription)
                return
            }
            auth.user = result?.user
        }
    }
}
