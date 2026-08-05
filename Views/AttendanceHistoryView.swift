//
//  AttendanceHistoryView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import FirebaseAuth

// ★ オシニウムタブの「あったら便利な機能」その4：参戦記録。
//   過去のすべての予定を一覧に出し、1件ずつ「参戦しましたか？」と聞いて、
//   答えたものだけをEventAttendanceRecordとしてFirestoreに保存する
//   （自動で「過去の予定＝参戦した」とみなさない。実際に行ったかは本人しかわからないため）
struct AttendanceHistoryView: View {
    @EnvironmentObject var eventViewModel: EventViewModel
    @StateObject private var attendanceVM = AttendanceViewModel()
    let group: IdolGroup?

    private let accentColor = Color(red: 0.25, green: 0.65, blue: 0.72)
    private let accentColor2 = Color(red: 0.35, green: 0.80, blue: 0.78)
    private var myUid: String? { Auth.auth().currentUser?.uid }

    // ★ 「全部のイベントが表示されて」の指示どおり、種別を問わずすべての過去の予定を対象にする
    private var pastEvents: [Event] {
        let now = Date()
        return eventViewModel.events
            .filter { $0.groupId == group?.id && $0.date < now }
            .sorted { $0.date > $1.date }
    }

    private var attendedCount: Int {
        pastEvents.reduce(0) { count, event in
            guard let id = event.id, attendanceVM.record(for: id)?.attended == true else { return count }
            return count + 1
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                summaryCard

                if pastEvents.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(pastEvents) { event in
                            eventRow(event)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("参戦記録")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let myUid { attendanceVM.startListening(uid: myUid) }
        }
        .onDisappear { attendanceVM.stopListening() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.map { "\($0.name)への参戦回数" } ?? "参戦回数")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(attendedCount)")
                    .font(.system(size: 34, weight: .bold))
                Text("回")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)

            let answeredCount = pastEvents.filter { $0.id.flatMap { attendanceVM.record(for: $0) } != nil }.count
            if answeredCount < pastEvents.count {
                Text("未回答の予定が\(pastEvents.count - answeredCount)件あります")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [accentColor, accentColor2], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accentColor.opacity(0.3), radius: 14, x: 0, y: 8)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 32))
                .foregroundColor(accentColor.opacity(0.3))
            Text("まだ過去の予定はありません")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("開催日を過ぎた予定が、自動でここに一覧されます")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func eventRow(_ event: Event) -> some View {
        let record = event.id.flatMap { attendanceVM.record(for: $0) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                EventThumbnailImage(event: event, group: group, width: 56, height: 56, cornerRadius: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(dateLabel(event.date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if let place = event.place, !place.isEmpty {
                        Label(place, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            attendanceControl(for: event, record: record)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // ★ 未回答なら「参戦しましたか？」と2択で聞く。回答済みなら結果を出し、
    //   タップすればいつでも回答を変えられるようにする
    @ViewBuilder
    private func attendanceControl(for event: Event, record: EventAttendanceRecord?) -> some View {
        if let eventId = event.id, let myUid {
        if let record {
            HStack(spacing: 8) {
                Label(record.attended ? "参戦した" : "行けなかった", systemImage: record.attended ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(record.attended ? accentColor : .secondary)

                Spacer(minLength: 0)

                Button {
                    attendanceVM.answer(uid: myUid, eventId: eventId, attended: !record.attended)
                } label: {
                    Text("回答を変える")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 2)
        } else {
            HStack(spacing: 8) {
                Text("参戦しましたか？")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)

                Button {
                    attendanceVM.answer(uid: myUid, eventId: eventId, attended: true)
                } label: {
                    Text("参戦した")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(accentColor))
                }

                Button {
                    attendanceVM.answer(uid: myUid, eventId: eventId, attended: false)
                } label: {
                    Text("行けなかった")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().stroke(accentColor, lineWidth: 1))
                }
            }
        }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月d日(E)"
        return f.string(from: date)
    }
}
