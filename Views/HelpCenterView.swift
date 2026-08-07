//
//  HelpCenterView.swift
//  OshiNium7
//

import SwiftUI

// ★ 専用のFAQバックエンドはまだ無いため、よくある質問を静的なリストとしてまとめておく画面。
//   将来的に問い合わせが増えたら、ここに項目を足していく想定
struct HelpCenterView: View {

    private struct FAQItem: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    private let items: [FAQItem] = [
        FAQItem(
            question: "非公開アカウントにするとどうなりますか？",
            answer: "あなたをフォローしていない人には投稿が表示されなくなります。設定画面の「プライバシー」からいつでも切り替えられます。"
        ),
        FAQItem(
            question: "ブロックとミュートの違いは何ですか？",
            answer: "ブロックはお互いにメッセージを送れなくなる双方向の制限です。ミュートは相手に気づかれずに、自分のタイムラインからその人の投稿を見えなくするだけの機能です。"
        ),
        FAQItem(
            question: "通知が届きません",
            answer: "設定画面の「通知」で対象の通知がONになっているか、また端末本体の「設定」アプリ→OshiNium→通知が許可されているかをご確認ください。"
        ),
        FAQItem(
            question: "アカウントを削除するとどうなりますか？",
            answer: "設定画面の「アカウント」からアカウントを削除できます。この操作は取り消せません。投稿など一部のデータの完全な削除については、お問い合わせ窓口までご連絡ください。"
        )
    ]

    var body: some View {
        List(items) { item in
            VStack(alignment: .leading, spacing: 6) {
                Text(item.question)
                    .font(.system(size: 14, weight: .bold))
                Text(item.answer)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("ヘルプセンター")
        .navigationBarTitleDisplayMode(.inline)
    }
}
