//
//  AdminReportsView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/19.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// ★ /ult監査(2026/08/18)で指摘された「管理者向けUIが皆無で、通報の確認・対応が
//   全てFirebaseコンソール頼みになっている」という運営面の課題への、最小限の対応。
//   通報の一覧表示のみを担う(対応そのもの=restrictedUsersへの手動追加は、
//   引き続きFirebaseコンソールから行う運用のまま。firestore.rulesのisAdmin()で
//   運営者本人(CEOのuid)にだけmessageReportsの読み取りを許可している)
struct AdminReport: Identifiable {
    let id: String
    let reporterUid: String
    let reportedUid: String
    let context: String
    let contextId: String
    let messageId: String?
    let messageText: String
    let reason: String
    let detail: String
    let createdAt: Date
}

struct AdminReportsView: View {
    @State private var reports: [AdminReport] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedReport: AdminReport?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reports.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("通報はありません")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(reports) { report in
                    Button {
                        selectedReport = report
                    } label: {
                        reportRow(report)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("通報一覧")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .sheet(item: $selectedReport) { report in
            AdminReportDetailView(report: report)
        }
    }

    private func reportRow(_ report: AdminReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(contextLabel(report.context))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.oshiniumPrimary))
                Spacer()
                Text(Self.dateFormatter.string(from: report.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Text(report.reason)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            if !report.detail.isEmpty {
                Text(report.detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    private func contextLabel(_ context: String) -> String {
        switch context {
        case "dm": return "DM"
        case "group": return "グループチャット"
        case "anonymous": return "匿名トークルーム"
        case "open": return "公開トークルーム"
        case "venue": return "会場口コミ"
        case "event": return "予定"
        default: return context
        }
    }

    private func load() async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("messageReports")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments()

            reports = snapshot.documents.compactMap { doc -> AdminReport? in
                let data = doc.data()
                guard let reporterUid = data["reporterUid"] as? String,
                      let reportedUid = data["reportedUid"] as? String,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                else { return nil }
                return AdminReport(
                    id: doc.documentID,
                    reporterUid: reporterUid,
                    reportedUid: reportedUid,
                    context: data["context"] as? String ?? "",
                    contextId: data["contextId"] as? String ?? "",
                    messageId: data["messageId"] as? String,
                    messageText: data["messageText"] as? String ?? "",
                    reason: data["reason"] as? String ?? "",
                    detail: data["detail"] as? String ?? "",
                    createdAt: createdAt
                )
            }
            isLoading = false
        } catch {
            print("🔥 AdminReportsView load error:", error)
            CrashReportManager.recordNonFatal(error)
            errorMessage = "通報一覧を読み込めませんでした"
            isLoading = false
        }
    }
}

// MARK: - 通報詳細（被通報者のプロフィールへの導線つき）

private struct AdminReportDetailView: View {
    let report: AdminReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailRow(title: "種別", value: report.context)
                    detailRow(title: "理由", value: report.reason)
                    if !report.detail.isEmpty {
                        detailRow(title: "詳細", value: report.detail)
                    }
                    if !report.messageText.isEmpty {
                        detailRow(title: "本文/タイトル", value: report.messageText)
                    }
                    detailRow(title: "通報者uid", value: report.reporterUid)
                    detailRow(title: "被通報者uid", value: report.reportedUid)
                    detailRow(title: "対象ID", value: report.contextId)

                    NavigationLink {
                        UserProfileView(uid: report.reportedUid)
                    } label: {
                        Text("被通報者のプロフィールを見る")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.oshiniumPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 8)

                    // ★ このUIからは直接制限できない(firestore.rulesでrestrictedUsersは
                    //   クライアントから完全に書き込み不可の設計、[[project_account_restriction_policy]]
                    //   参照)。悪用防止のため、必ず内容を確認した人間がFirebaseコンソールから
                    //   手動でrestrictedUsers/{被通報者uid}を作成する運用のまま
                    Text("この画面からは制限できません。対応する場合はFirebaseコンソールのrestrictedUsersコレクションから手動で行ってください。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("通報詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

extension AdminReport: Equatable {
    static func == (lhs: AdminReport, rhs: AdminReport) -> Bool { lhs.id == rhs.id }
}
