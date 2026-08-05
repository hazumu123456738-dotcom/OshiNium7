//
//  ReminderOffsetsEditor.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI

// ★ 予定の通知タイミング（分前）を人間が読みやすい文字列にする共通フォーマッタ。
//   通知時間の好みは人によるので、日・時間・分を自由に組み合わせて何個でも設定できるようにする
enum ReminderFormatting {
    static func label(forMinutes minutes: Int) -> String {
        guard minutes > 0 else { return "開始時刻" }

        if minutes < 60 {
            return "\(minutes)分前"
        }
        if minutes < 1440 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)時間前" : "\(h)時間\(m)分前"
        }
        let d = minutes / 1440
        let remH = (minutes % 1440) / 60
        return remH == 0 ? "\(d)日前" : "\(d)日\(remH)時間前"
    }
}

// ★ ダイヤル式（日・時間・分のホイール）で通知タイミングを1件選んで追加するシート
struct ReminderPickerSheet: View {
    let accentColor: Color
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var days = 0
    @State private var hours = 0
    @State private var minutes = 10

    private var totalMinutes: Int { days * 1440 + hours * 60 + minutes }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("開始の")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(ReminderFormatting.label(forMinutes: totalMinutes))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(accentColor)
                }
                .padding(.top, 12)

                HStack(spacing: 0) {
                    wheelColumn(title: "日", selection: $days, range: 0...7)
                    wheelColumn(title: "時間", selection: $hours, range: 0...23)
                    wheelColumn(title: "分", selection: $minutes, range: 0...59)
                }
                .frame(height: 180)

                Button {
                    onAdd(totalMinutes)
                    dismiss()
                } label: {
                    Text("この時間を追加")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(accentColor, in: Capsule())
                        .opacity(totalMinutes > 0 ? 1 : 0.4)
                }
                .disabled(totalMinutes <= 0)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("通知を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func wheelColumn(title: String, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }
    }
}

// ★ 予定の追加・編集画面に埋め込む、複数の通知タイミングを管理するチップ+追加ボタンのUI
struct ReminderOffsetsEditor: View {
    @Binding var offsets: [Int]
    let accentColor: Color

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("通知")
                .font(.system(size: 15, weight: .semibold))

            Text("好きなタイミングを何個でも追加できます")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if offsets.isEmpty {
                Text("通知は設定されていません")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(offsets.sorted(), id: \.self) { minutes in
                            chip(for: minutes)
                        }
                    }
                }
            }

            Button {
                showPicker = true
            } label: {
                Label("通知を追加", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .sheet(isPresented: $showPicker) {
            ReminderPickerSheet(accentColor: accentColor) { minutes in
                guard !offsets.contains(minutes) else { return }
                offsets.append(minutes)
            }
        }
    }

    private func chip(for minutes: Int) -> some View {
        HStack(spacing: 6) {
            Text(ReminderFormatting.label(forMinutes: minutes))
                .font(.system(size: 12, weight: .semibold))
            Button {
                offsets.removeAll { $0 == minutes }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
            }
        }
        .foregroundColor(accentColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(accentColor.opacity(0.12))
        .clipShape(Capsule())
    }
}
