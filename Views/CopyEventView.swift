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

    @StateObject private var calendarViewModel = CalendarViewModel()

    @State private var selectedCalendarId: String?
    @State private var pickerDate: Date
    @State private var selectedDates: [Date] = []
    @State private var isSaving = false

    init(event: Event, eventViewModel: EventViewModel) {
        self.event = event
        self.eventViewModel = eventViewModel
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
        .onChange(of: calendarViewModel.calendars) { _, calendars in
            guard selectedCalendarId == nil else { return }
            selectedCalendarId = event.calendarId ?? calendars.first(where: { $0.isCommunity })?.id
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
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
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
        eventViewModel.duplicateEvent(event, toCalendarId: calendarId, dates: selectedDates)
        isSaving = false
        dismiss()
    }
}
