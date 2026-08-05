//
//  PrivacyPolicyView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/02.
//

import SwiftUI

// ★ プライバシーポリシー（アプリ内表示用）。
//   内容はOshiNium7の実際の実装（Firebase Auth/Firestore/Storage、カメラ、ローカル通知、
//   Gemini API、Open-Meteo API）に基づいて記載している。実装が変わった場合はこの文書も
//   合わせて更新すること。App Store Connect提出には、この内容をホスティングした
//   公開URLも別途必要（詳しくはLegalDocumentContent.swiftのコメントを参照）
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("プライバシーポリシー")
                    .font(.system(size: 22, weight: .bold))
                Text("最終更新日：\(LegalDocumentContent.lastUpdated)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                LegalSection(title: "はじめに") {
                    Text("OshiNium（以下「本アプリ」）は、推し活（アイドル・アーティスト等の応援活動）を行うユーザーのためのコミュニティアプリです。本ポリシーは、本アプリが取得する情報の種類、利用目的、第三者提供の有無、保管・削除の方針について説明します。")
                }

                LegalSection(title: "1. 取得する情報") {
                    LegalBullet("アカウント情報：Googleアカウントでのログイン時に、氏名・メールアドレス・プロフィール画像をGoogleから取得します。")
                    LegalBullet("プロフィール情報：表示名、自己紹介文、プロフィールアイコン、誕生日、SNSリンクなど、ご自身で入力・設定した情報。")
                    LegalBullet("投稿・コミュニケーション情報：投稿（画像・動画・キャプション）、コメント、いいね、グループチャット・ダイレクトメッセージの本文、フォロー・フォロワー関係。")
                    LegalBullet("推し活記録：参加グループ、カレンダーに登録した予定、持ち物チェックリスト、推し活費用の記録、会場の口コミ・セットリスト投稿。")
                    LegalBullet("通報・モデレーション情報：不適切な投稿・メッセージを通報した場合、その内容と通報者・被通報者の情報。")
                    LegalBullet("カメラ：プロフィールQRコードの読み取り機能を使用する際にのみ、カメラへのアクセス許可を求めます。読み取った画像自体を保存・送信することはありません。")
                    LegalBullet("端末上の通知設定：イベントの予定や持ち物チェックリストのリマインダーは、端末内でスケジュールされるローカル通知であり、これらの通知内容が外部サーバーに送信されることはありません。")
                    LegalBullet("本アプリは、GPS等によるユーザーご自身の位置情報を取得・追跡することはありません。天気表示機能は、イベント会場の座標をもとに取得するものであり、ユーザーの現在地情報ではありません。")
                }

                LegalSection(title: "2. 情報の利用目的") {
                    LegalBullet("アカウントの作成・認証、本アプリの各機能（投稿・チャット・カレンダー・通知等）の提供のため。")
                    LegalBullet("フォロー関係に基づくおすすめ表示、通知の配信のため。")
                    LegalBullet("不適切な投稿・利用者への対応（通報の確認、アカウントの利用制限等）のため。")
                    LegalBullet("グループ情報の自動補完やイベント提案など、AIを用いた機能の提供のため（詳細は次項）。")
                }

                LegalSection(title: "3. 第三者サービスの利用") {
                    Text("本アプリは、以下の外部サービスと連携しています。それぞれのサービスのプライバシーポリシーも合わせてご確認ください。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    LegalBullet("Firebase（Google LLC）：認証、データベース（Firestore）、画像・動画の保管（Storage）に使用しています。")
                    LegalBullet("Google Sign-In：ログイン機能に使用しています。")
                    LegalBullet("Google Gemini API：グループ情報の自動検索、イベントの提案機能に使用しています。この際、グループ名やイベント情報などのテキストがGoogleのサーバーに送信されますが、個人を特定する情報を意図的に送信することはありません。")
                    LegalBullet("Open-Meteo：天気予報の表示に使用しています。APIキー不要の無料サービスで、送信されるのはイベント会場の座標のみです。")
                    Text("本アプリ自体は、広告SDKやアクセス解析（アナリティクス）ツールを組み込んでいません。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }

                LegalSection(title: "4. 情報の第三者提供") {
                    Text("法令に基づく場合を除き、取得した情報をご本人の同意なく第三者に提供することはありません。ただし、上記「3. 第三者サービスの利用」に記載のサービス提供事業者には、機能提供に必要な範囲でデータを預けています。")
                }

                LegalSection(title: "5. 他のユーザーに公開される情報") {
                    Text("表示名・プロフィールアイコン・自己紹介・投稿・コメント・フォロー数などは、本アプリを利用する他のユーザーから閲覧可能です。グループチャットのメッセージは同じグループの参加者に、ダイレクトメッセージは送信相手にのみ表示されます。")
                }

                LegalSection(title: "6. データの保管・削除") {
                    Text("取得した情報は、本アプリの提供に必要な期間保管します。アカウントの削除をご希望の場合は、アプリ内のお問い合わせ、または開発者までご連絡ください。ご本人確認の上、関連データを削除いたします。")
                }

                LegalSection(title: "7. セキュリティ") {
                    Text("本アプリは、Firebaseのセキュリティルールによりデータへのアクセスを制御しています。通信はすべてHTTPS/TLSにより暗号化されています。ただし、インターネット上のデータ送信・保管において絶対的な安全性を保証するものではありません。")
                }

                LegalSection(title: "8. お子様のご利用について") {
                    Text("本アプリは13歳未満のお子様を対象としていません。13歳未満の方が本アプリを利用していることが判明した場合、該当アカウントの情報を削除する場合があります。")
                }

                LegalSection(title: "9. 本ポリシーの変更") {
                    Text("本ポリシーの内容は、本アプリの機能追加・変更等に伴い予告なく変更されることがあります。重要な変更がある場合は、アプリ内でお知らせします。")
                }

                LegalSection(title: "10. お問い合わせ") {
                    Text("本ポリシーに関するお問い合わせは、開発者までご連絡ください。")
                }
            }
            .padding(20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ★ プライバシーポリシー・利用規約で共通して使う見出し＋本文のセクション
struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
            content
                .font(.system(size: 13))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
}

struct LegalBullet: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("・")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
    }
}

// ★ 更新日などをコードとドキュメント（HTML版）の両方から参照する共通定数
enum LegalDocumentContent {
    static let lastUpdated = "2026年8月2日"
}
