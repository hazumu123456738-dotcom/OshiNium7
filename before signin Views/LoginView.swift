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

                            Spacer(minLength: 12)

                            featuresCard

                            Spacer(minLength: 32)

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
        .fullScreenCover(isPresented: $showEmailSheet) {
            EmailSignInView()
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
                Text("メールアドレスでサインイン")
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

    // MARK: - 機能紹介カード（ログインするとできること）
    //   ★ 2026/08/21更新：プレミアム限定の機能(動画投稿・招待制グループチャットの作成等)は
    //   含めず、無課金の一般ユーザーがそのまま使える範囲だけを列挙する
    //   (SubscriptionLimits.swiftの各上限値と突き合わせて確認済み：グループ2つ/持ち物
    //   テンプレ3個/DM新規スレッド20件/日/予定作成20件/日/投稿画像5枚まで、はいずれも
    //   「上限はあるが利用自体はできる」ため掲載、動画投稿のみプレミアム限定のため掲載しない)
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
                featureItem("推し活タイムラインへの投稿")
                featureItem("いいね・コメント・保存")
                featureItem("他のユーザーのフォロー")
                featureItem("グループチャット・DM")
                featureItem("予定の追加・編集")
                featureItem("チャット・予定などの通知")
                featureItem("マイページ・ポイント")
                featureItem("推しグループを2つまで登録")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Color(.systemGray6))
        .cornerRadius(20)
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

// MARK: - メールアドレス・パスワード入力画面（画面全体表示、既存ユーザーのサインイン専用）
//   ★ 2026/08/21修正：以前はsignIn失敗時に自動でcreateUserへフォールバックしていたが、
//     「新規の人はまだパスワードを持っていない」という前提が崩れていた
//     (パスワード欄に何を入れればいいか分からない)。サインイン(既存ユーザー)と
//     新規登録(パスワードを新しく設定する)を別画面に分離し、この画面はサインイン専用にする
//   ★ 以前は.sheet(.medium)のコンパクトなシートだったが、アプリ全体のデザイン
//     コンセプト（高級感×白×純正アップル×少しの立体感、AppTheme.swift参照）に
//     揃えるため、他の入力画面（NewGroupView等）と同じappCardBackground/
//     CornerRadius.card/紫グラデーションボタンを使った画面全体表示に変更した
private struct EmailSignInView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var resetSentMessage: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    // ★ ここは既存アカウントのサインイン専用のため、新規登録時のパスワード強度要件
    //   (8文字以上・記号を含む等)を課さない。既に設定済みのパスワードを入力させるだけ
    private var isFormValid: Bool {
        email.contains("@") && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor.opacity(0.16), accentColor2.opacity(0.16)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                        .padding(.top, 8)

                        Text("メールアドレスでサインイン")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.primary)

                        Text("既にアカウントをお持ちの方は、\n登録済みのメールアドレスとパスワードを入力してください")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("メールアドレス")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            TextField("your@email.com", text: $email)
                                .font(.system(size: 16))
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                .fill(Color.appCardBackground)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("パスワード")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            SecureField("パスワードを入力", text: $password)
                                .font(.system(size: 16))
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { Task { await signIn() } }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                                .fill(Color.appCardBackground)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                        )
                    }

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
                                Text("メールアドレスでサインイン")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .frame(height: 54)
                        .background(
                            isFormValid
                                ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.gray.opacity(0.35))
                        )
                        .cornerRadius(27)
                        .shadow(color: accentColor.opacity(isFormValid ? 0.25 : 0), radius: 8, y: 4)
                    }
                    .disabled(!isFormValid || isLoading)

                    // ★ 2026/08/21追加：新規の人はまだパスワードを持っていないため、
                    //   ここでいきなりパスワード欄に入力させるのは不親切。
                    //   パスワードを「新しく設定する」新規登録専用の画面へ案内する。
                    //   「パスワードをお忘れの方」と同じ色・書式で統一し、上下の順番も
                    //   ユーザー指示通り新規登録を上に置く
                    NavigationLink {
                        EmailSignUpView(initialEmail: email)
                    } label: {
                        Text("新規登録の方はこちら")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(accentColor)
                    }

                    // ★ /ult監査(2026/08/21)で発見：メール+パスワード認証を追加したのに
                    //   パスワードを忘れた場合の再設定手段が無く、忘れると二度とその
                    //   アカウントに入れなくなる欠落があった。Firebaseのパスワード
                    //   再設定メール送信だけで完結する軽量な導線を追加する
                    Button {
                        Task { await sendPasswordReset() }
                    } label: {
                        Text("パスワードをお忘れの方はこちら")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                    .disabled(email.isEmpty || isLoading)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear { focusedField = .email }
        }
        .alert(
            "サインインに失敗しました",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(
            "パスワード再設定",
            isPresented: Binding(get: { resetSentMessage != nil }, set: { if !$0 { resetSentMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetSentMessage ?? "")
        }
    }

    // ★ 入力中のメールアドレス宛にFirebaseの再設定メールを送信する。パスワード認証を
    //   追加したのに再設定手段が無いと、忘れた時点でそのアカウントに二度と入れなくなるため
    @MainActor
    private func sendPasswordReset() async {
        guard !email.isEmpty else { return }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            resetSentMessage = "\(email) 宛にパスワード再設定用のメールを送信しました。メール内のリンクから新しいパスワードを設定してください。"
        } catch {
            resetSentMessage = emailAuthFriendlyMessage(error as NSError)
        }
    }

    // ★ 2026/08/21修正：以前はここでcreateUserへの自動フォールバックを行っていたが、
    //   新規登録は専用画面(EmailSignUpView)に分離したため、ここは純粋にsignInのみ行う
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
            print("メールログイン失敗:", error.localizedDescription)
            errorMessage = emailAuthFriendlyMessage(error as NSError)
        }
    }
}

// ★ サインイン画面・新規登録画面の両方で使うエラーメッセージ変換。
//   2箇所に同じswitchを重複させないよう、ファイルスコープの共有関数として切り出す
private func emailAuthFriendlyMessage(_ error: NSError) -> String {
    switch AuthErrorCode(rawValue: error.code) {
    case .invalidEmail:
        return "メールアドレスの形式が正しくありません"
    case .wrongPassword, .invalidCredential:
        return "メールアドレスまたはパスワードが正しくありません"
    case .userNotFound:
        return "このメールアドレスのアカウントが見つかりません。初めての方は「新規登録の方はこちら」からご登録ください"
    case .weakPassword:
        return "パスワードは8文字以上で、英字・数字・記号をすべて含めてください"
    case .emailAlreadyInUse:
        return "このメールアドレスは既に登録されています。サインイン画面からお試しください"
    case .networkError:
        return "通信環境をご確認のうえ、もう一度お試しください"
    case .tooManyRequests:
        return "試行回数が多すぎます。しばらくしてからもう一度お試しください"
    default:
        return error.localizedDescription
    }
}

// MARK: - 新規登録画面（パスワードを新しく設定する専用画面）
//   ★ 2026/08/21新設：EmailSignInViewから分離。新規の人はまだパスワードを
//   持っていないため、「入力」ではなく「設定」であることが伝わる専用画面にする。
//   単純な6文字だけの制約だと使い回されやすい弱いパスワードになりやすいため、
//   8文字以上・英字/数字/記号をすべて含める要件にし、満たすごとにチェックが
//   付く簡易チェックリストでリアルタイムに分かるようにする（複雑だが迷わない設計）
private struct EmailSignUpView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var email: String
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    private var hasMinLength: Bool { password.count >= 8 }
    private var hasLetterAndDigit: Bool {
        password.rangeOfCharacter(from: .letters) != nil
            && password.rangeOfCharacter(from: .decimalDigits) != nil
    }
    private var hasSymbol: Bool {
        password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?/~`")) != nil
    }
    private var isPasswordStrongEnough: Bool { hasMinLength && hasLetterAndDigit && hasSymbol }
    private var isFormValid: Bool { email.contains("@") && isPasswordStrongEnough }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.16), accentColor2.opacity(0.16)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accentColor)
                    }
                    .padding(.top, 8)

                    Text("新規登録")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.primary)

                    Text("メールアドレスと、これから使うパスワードを\n新しく設定してください")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("メールアドレス")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("your@email.com", text: $email)
                            .font(.system(size: 16))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("パスワードを設定")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        SecureField("新しいパスワード", text: $password)
                            .font(.system(size: 16))
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await signUp() } }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .fill(Color.appCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        passwordRequirementRow("8文字以上", satisfied: hasMinLength)
                        passwordRequirementRow("英字と数字の両方を含む", satisfied: hasLetterAndDigit)
                        passwordRequirementRow("記号を含む（例：! @ # $ %）", satisfied: hasSymbol)
                    }
                    .padding(.horizontal, 4)
                }

                Button {
                    focusedField = nil
                    Task { await signUp() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "person.badge.plus.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("アカウントを作成")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .frame(height: 54)
                    .background(
                        isFormValid
                            ? AnyShapeStyle(LinearGradient(colors: [accentColor, accentColor2], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.gray.opacity(0.35))
                    )
                    .cornerRadius(27)
                    .shadow(color: accentColor.opacity(isFormValid ? 0.25 : 0), radius: 8, y: 4)
                }
                .disabled(!isFormValid || isLoading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("新規登録")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "登録に失敗しました",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func passwordRequirementRow(_ title: String, satisfied: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(satisfied ? accentColor : .secondary.opacity(0.5))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(satisfied ? .primary : .secondary)
        }
    }

    // ★ 新規登録専用のため、ここではcreateUserのみを行う。成功後は明示的なdismiss()を
    //   呼ばない：auth.userが更新されるとAppRootViewが即座にLoginView自体を丸ごと
    //   切り替える（このEmailSignUpView・親のEmailSignInView・fullScreenCoverもろとも
    //   消える）ため、この画面だけを個別に閉じる操作は不要かつ二度手間になる
    @MainActor
    private func signUp() async {
        guard isFormValid else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            auth.user = result.user
            AnalyticsManager.logSignUp(method: "email")
        } catch {
            print("メール新規登録失敗:", error.localizedDescription)
            errorMessage = emailAuthFriendlyMessage(error as NSError)
        }
    }
}
