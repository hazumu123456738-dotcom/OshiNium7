//
//  CopyEventView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/28.
//

import SwiftUI
import FirebaseAuth

struct CopyEventView: View {

    @Environment(\.dismiss) private var dismiss

    let event: Event
    @ObservedObject var eventViewModel: EventViewModel
    // ★ 2026/08/20（oshiスキル監査で発見）：コピー元の予定がホーム/カレンダータブで
    //   現在選択中のグループと別のグループに属する場合、この画面のonAppearが共有の
    //   calendarViewModelを一時的にコピー先候補グループへ向け直す。以前はonDisappearでの
    //   復元が無く、この画面を閉じた後もカレンダータブが元のグループへ戻らず、
    //   ユーザーが手動でグループを切り替えるまでカレンダー表示が壊れたままになっていた。
    //   復元先として、この画面を開く前に選択されていたグループを保持しておく
    let originalGroup: IdolGroup

    // ★ HomeView/FullCalendarTabと同じアプリ全体で共有の1インスタンス(OshiNium7App)を使う。
    //   以前はここだけ独自にCalendarViewModel()を保持しており、無駄な重複購読になっていた
    @EnvironmentObject var calendarViewModel: CalendarViewModel

    @State private var selectedCalendarId: String?
    @State private var pickerDate: Date
    @State private var selectedDates: [Date] = []
    @State private var isSaving = false
    @State private var showCopiedToast = false
    @State private var errorMessage: String?

    init(event: Event, eventViewModel: EventViewModel, originalGroup: IdolGroup) {
        self.event = event
        self.eventViewModel = eventViewModel
        self.originalGroup = originalGroup
        _pickerDate = State(initialValue: event.startDate ?? event.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - コピー先カレンダー
                    VStack(alignment: .leading, spacing: 10) {
                        Text("コピー先カレンダー")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        if let lastError = calendarViewModel.lastError {
                            Text("カレンダーの取得に失敗しました:\n\(lastError)")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        } else if calendarViewModel.calendars.isEmpty {
                            Text("読み込み中…")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(calendarViewModel.calendars) { calendar in
                                    calendarRow(calendar)
                                    if calendar.id != calendarViewModel.calendars.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                    }

                    // MARK: - コピー先日付（複数選択）
                    VStack(alignment: .leading, spacing: 10) {
                        Text("コピーする日付")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 12) {
                            DatePicker("", selection: $pickerDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .labelsHidden()

                            Button {
                                addPickerDate()
                            } label: {
                                Label("この日付を追加", systemImage: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.black.opacity(0.85))
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)

                        if !selectedDates.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedDates, id: \.self) { date in
                                        dateChip(date)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("予定をコピー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "コピー中…" : "コピー") {
                        copy()
                    }
                    .disabled(selectedCalendarId == nil || selectedDates.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            guard let groupId = event.groupId else { return }
            let groupName = eventViewModel.group(for: groupId)?.name ?? ""
            let uid = Auth.auth().currentUser?.uid ?? ""
            calendarViewModel.startListening(groupId: groupId, groupName: groupName, currentUid: uid)
        }
        .onDisappear {
            // ★ onAppearで一時的に向け直した共有calendarViewModelを、この画面を開く前に
            //   選択されていたグループへ戻す（コピー元イベントが別グループの場合のみ実際に意味を持つ）
            guard event.groupId != originalGroup.id else { return }
            let uid = Auth.auth().currentUser?.uid ?? ""
            calendarViewModel.startListening(groupId: originalGroup.id, groupName: originalGroup.name, currentUid: uid)
        }
        .onChange(of: calendarViewModel.calendars) { _, calendars in
            guard selectedCalendarId == nil else { return }
            selectedCalendarId = event.calendarId ?? calendars.first(where: { $0.isCommunity })?.id
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                SimpleToast(text: "コピーしました")
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCopiedToast)
        .alert("コピーできませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "もう一度お試しください")
        }
    }

    // MARK: - カレンダー選択行

    private func calendarRow(_ calendar: OshiCalendar) -> some View {
        let isSelected = selectedCalendarId == calendar.id

        return Button {
            selectedCalendarId = calendar.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: calendar.isCommunity ? "person.3.fill" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(calendar.isCommunity ? Color.black.opacity(0.85) : colorFrom(calendar))
                    .clipShape(Circle())

                Text(calendar.isCommunity ? "コミュニティカレンダー" : calendar.name)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .black : .gray.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func colorFrom(_ calendar: OshiCalendar) -> Color {
        if let hex = calendar.colorHex { return Color(hex: hex) }
        return Color.oshiniumPrimary
    }

    // MARK: - 日付チップ

    private func dateChip(_ date: Date) -> some View {
        HStack(spacing: 4) {
            // ★ .formatted(.dateTime...)は端末のシステム言語に依存し、英語設定の端末では
            //   "Aug 14"のように英語表記になってしまう。このアプリは全画面で日本語固定表示
            //   のため、CachedFormatters（ja_JP固定）で他の日付チップと同じ書式に揃える
            Text(CachedFormatters.date(format: "M/d(E)").string(from: date))
                .font(.system(size: 12, weight: .semibold))

            Button {
                selectedDates.removeAll { Calendar.current.isDate($0, inSameDayAs: date) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("この日付を削除")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }

    private func addPickerDate() {
        let alreadyAdded = selectedDates.contains {
            Calendar.current.isDate($0, inSameDayAs: pickerDate)
        }
        guard !alreadyAdded else { return }
        selectedDates.append(pickerDate)
    }

    // MARK: - コピー実行

    private func copy() {
        guard let calendarId = selectedCalendarId, !selectedDates.isEmpty else { return }
        isSaving = true
        // ★ /ult監査で発見：以前はduplicateEventの完了を待たずに「コピーしました」と表示して
        //   いたため、書き込みが失敗しても(オフライン・権限エラー等)ユーザーには常に成功したように
        //   見えていた。完了を待ってから結果に応じて表示を分ける
        eventViewModel.duplicateEvent(event, toCalendarId: calendarId, dates: selectedDates) { error in
            isSaving = false
            if let error {
                errorMessage = error.localizedDescription
                return
            }

            // ★ 以前はduplicateEvent呼び出し直後に即dismiss()していたため、
            //   コピーが実行されたことをユーザーが確認する間もなく画面が閉じ、
            //   「本当にコピーされたのか分かりにくい」という声があった。
            //   一瞬「コピーしました」を見せてから閉じる
            withAnimation { showCopiedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                dismiss()
            }
        }
    }
}
