//
//  ReportComposerSheet.swift
//  OshiNium7
//

import SwiftUI

// ★ 通報のたびに「何が起きたか」をユーザー自身の言葉で書いてもらうための共通シート。
//   これまでは選択式の理由(スパム・誹謗中傷など)を選ぶだけで送信できてしまい、
//   運営側が状況を正しく把握できなかったため、自由記述の詳細欄を必須にして刷新した。
//   投稿・コメント・メッセージ・イベント・ユーザープロフィールの全ての通報導線で共通利用する
struct ReportComposerSheet: View {
    let title: String
    var reasons: [String] = ["スパム・宣伝", "嫌がらせ・誹謗中傷", "不適切な内容", "なりすまし", "その他"]
    let onSubmit: (_ reason: String, _ detail: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: String?
    @State private var detail: String = ""
    @FocusState private var detailFocused: Bool

    private var canSubmit: Bool {
        selectedReason != nil && !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("該当する項目を選んでください")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            ForEach(reasons, id: \.self) { reason in
                                Button {
                                    selectedReason = reason
                                } label: {
                                    HStack {
                                        Text(reason)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedReason == reason {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color.oshiniumPrimary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(selectedReason == reason ? Color.oshiniumPrimary.opacity(0.10) : Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(selectedReason == reason ? Color.oshiniumPrimary : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("どんなことが起きましたか？")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("具体的な状況を教えてください。内容は運営チームの確認・対応にのみ使用します。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            if detail.isEmpty {
                                Text("例：〇〇について繰り返し悪口を書き込まれた、など")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                            }
                            TextEditor(text: $detail)
                                .focused($detailFocused)
                                .font(.system(size: 14))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(height: 130)
                        }
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(detailFocused ? Color.oshiniumPrimary : Color.primary.opacity(0.08), lineWidth: 1.2)
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信する") {
                        guard let selectedReason else { return }
                        onSubmit(selectedReason, detail.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSubmit)
                }
            }
        }
    }
}

// ★ 通報送信後に表示する感謝の表示。「送信したのに何も反応が無い」という不安を無くすため、
//   保存系トースト(例：「マイテンプレートに保存しました」)と同じ見た目のパターンで統一する
struct ReportThanksToast: View {
    var body: some View {
        SimpleToast(text: "通報にご協力いただきありがとうございます")
    }
}

// ★ 「ブロック完了しました」「ミュート完了しました」など、操作の完了だけを短く伝えたい
//   場面で使う汎用トースト。ReportThanksToastと同じ見た目パターンを、文言だけ差し替えて使い回す
struct SimpleToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.85)))
    }
}
