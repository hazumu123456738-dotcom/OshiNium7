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
    @State private var appleLoginErrorMessage: String?
    // ★ ASAuthorizationControllerのdelegateがコールバックしている間、Viewの再描画で
    //   このコーディネーター自体が解放されてしまわないよう@Stateで保持する
    @State private var appleSignInCoordinator = AppleSignInCoordinator()

    // ★ Apple/Googleと横並びの見た目で「メール」ボタンを1つ置き、タップしたら
    //   メールアドレス・パスワードの入力欄をシートで開く（常時フォームを画面に出さない）
    @State private var showEmailSheet = false

    var body: some View {

        ZStack {

            // MARK: - 画面全体の宇宙背景（白帯を完全に消す）
            universeBackground
                .ignoresSafeArea()

            // ★ ボタン群はこれまで通りカード上部に固定したまま、白カードの面積だけ
            //   画面いっぱいまで広げ、余った分を安心・安全の一言＋バージョン表示の
            //   直前に挟むSpacerで吸収して画面下部へ押し下げる。GeometryReaderで
            //   画面の高さを取り、外側VStackにminHeightとして与えることで、
            //   白カード側の.frame(maxHeight: .infinity)が残り全部を引き受ける
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - ロゴ〜サブタイトル（宇宙空間）
                        universeContent
                            .padding(.top, 40)
                            .padding(.bottom, 20)

                        // MARK: - 白背景エリア
                        VStack(spacing: 0) {

                            VStack(spacing: 14) {
                                appleButton
                                googleButton
                                mailButton
                            }
                            .padding(.top, 16)

                            Spacer(minLength: 24)

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
                                .padding(.top, 8)
                                .padding(.bottom, 24)

                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .cornerRadius(24)
                        .padding(.top, -8)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .alert(
            "Appleサインインに失敗しました",
            isPresented: Binding(get: { appleLoginErrorMessage != nil }, set: { if !$0 { appleLoginErrorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appleLoginErrorMessage ?? "")
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInSheet()
                .environmentObject(auth)
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
        Button { Task { await appleLogin() } } label: {
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

    // MARK: - メールログインボタン（Apple/Googleと同じ見た目の並び）
    private var mailButton: some View {
        Button {
            showEmailSheet = true
        } label: {
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.oshiniumPrimary)
                Spacer()
                Text("メールでサインイン")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(Color.oshiniumPrimary.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.oshiniumPrimary.opacity(0.35), lineWidth: 1.2)
            )
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
        }
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
            if authResult.additionalUserInfo?.isNewUser == true {
                AnalyticsManager.logSignUp(method: "google")
            } else {
                AnalyticsManager.logLogin(method: "google")
            }

        } catch {
            print("Google ログイン失敗:", error.localizedDescription)
        }
    }

    // MARK: - Apple ログイン処理
    @MainActor
    func appleLogin() async {
        await withCheckedContinuation { continuation in
            appleSignInCoordinator.signIn { result in
                switch result {
                case .success(let user):
                    auth.user = user
                case .failure(let error):
                    print("Apple ログイン失敗:", error.localizedDescription)
                    appleLoginErrorMessage = error.localizedDescription
                }
                continuation.resume()
            }
        }
    }

}

// MARK: - メールアドレス・パスワード入力シート
//   ★ 新規登録・ログインを画面で切り替えさせず、1つのボタンにまとめる
//     (emailLogin側でアカウント有無を見て自動的にsignIn/createUserを切り替える)
private struct EmailSignInSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var isFormValid: Bool {
        email.contains("@") && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("メールアドレスをお持ちの方は\nそのままサインイン、初めての方は\n自動で新規登録されます")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                TextField("メールアドレス", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("パスワード（6文字以上）", text: $password)
                    .textContentType(.password)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await signIn() } }

                Button {
                    focusedField = nil
                    Task { await signIn() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("メールでサインイン")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .background(isFormValid ? Color.oshiniumPrimary : Color.gray.opacity(0.4))
                    .cornerRadius(25)
                }
                .disabled(!isFormValid || isLoading)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("メールでサインイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear { focusedField = .email }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .alert(
            "サインインに失敗しました",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // ★ まずsignInを試み、「該当ユーザーなし」の場合だけ自動でcreateUserにフォールバックする。
    //   ユーザーからは「登録画面」と「ログイン画面」を分けずに1つの操作で済むようにするため
    @MainActor
    private func signIn() async {
        guard isFormValid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            auth.user = result.user
            AnalyticsManager.logLogin(method: "email")
            dismiss()
        } catch {
            let nsError = error as NSError
            guard nsError.code == AuthErrorCode.userNotFound.rawValue else {
                print("メールログイン失敗:", error.localizedDescription)
                errorMessage = Self.friendlyMessage(nsError)
                return
            }
            do {
                let result = try await Auth.auth().createUser(withEmail: email, password: password)
                auth.user = result.user
                AnalyticsManager.logSignUp(method: "email")
                dismiss()
            } catch {
                print("メール新規登録失敗:", error.localizedDescription)
                errorMessage = Self.friendlyMessage(error as NSError)
            }
        }
    }

    private static func friendlyMessage(_ error: NSError) -> String {
        switch AuthErrorCode(rawValue: error.code) {
        case .invalidEmail:
            return "メールアドレスの形式が正しくありません"
        case .wrongPassword, .invalidCredential:
            return "メールアドレスまたはパスワードが正しくありません"
        case .weakPassword:
            return "パスワードは6文字以上で入力してください"
        case .emailAlreadyInUse:
            return "このメールアドレスは別の方法（Apple/Google等）で既に登録されています"
        case .networkError:
            return "通信環境をご確認のうえ、もう一度お試しください"
        case .tooManyRequests:
            return "試行回数が多すぎます。しばらくしてからもう一度お試しください"
        default:
            return error.localizedDescription
        }
    }
}
