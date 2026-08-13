//
//  SharedEventLinkView.swift
//  OshiNium7
//

import SwiftUI
import FirebaseFirestore

// ★ https://oshinium-79256.web.app/e/<eventId> のUniversal Link・oshinium://event?id=<eventId>の
//   カスタムスキームの入口。EventDetailViewは編集権限・秘密の予定判定などグループメンバー前提の
//   ロジックを多く抱えているため、そのまま流用せず、共有リンクから来た閲覧者向けの
//   読み取り専用の簡易表示をここで別に持つ（このアプリのユーザーである必要すらない前提のため、
//   Firestoreのevents読み取りルールもisSignedInのみで足りる）
struct SharedEventLinkView: View {
    let eventId: String

    @Environment(\.dismiss) private var dismiss

    @State private var event: Event?
    @State private var isLoading = true

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    var body: some View {
        NavigationStack {
            Group {
                if let event {
                    content(for: event)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("予定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("閉じる")
                }
            }
        }
        .task {
            await loadEvent()
        }
    }

    private func content(for event: Event) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: event.type?.iconName ?? "star.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                    Text(event.type?.displayName ?? "予定")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(event.type?.iconColor ?? accentColor))

                Text(event.title.isEmpty ? "予定" : event.title)
                    .font(.system(size: 20, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Label(dateText(for: event), systemImage: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if let place = event.place, !place.isEmpty {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("この予定はOshiNiumで共有されました")
                        .font(.system(size: 13, weight: .semibold))
                    Text("OshiNiumは推し活のためのカレンダー・SNSアプリです。アプリを開くと、この予定を含むコミュニティカレンダーを見ることができます。")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.appCardBackground))
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
                .accessibilityHidden(true)
            Text("この予定は見つかりませんでした")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text("削除されたか、閲覧できる権限がない可能性があります")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func dateText(for event: Event) -> String {
        CachedFormatters.date(format: "yyyy年M月d日（E） H:mm").string(from: event.date)
    }

    private func loadEvent() async {
        do {
            let snapshot = try await Firestore.firestore().collection("events").document(eventId).getDocument()
            if let data = snapshot.data(), let fetched = EventViewModel.decodeEvent(id: snapshot.documentID, data: data) {
                event = fetched
            }
        } catch {
            // ★ 取得失敗時はeventがnilのままなのでbody側のemptyStateがそのまま出る
        }
        isLoading = false
    }
}
