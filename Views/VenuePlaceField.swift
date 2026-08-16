//
//  VenuePlaceField.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/16.
//

import SwiftUI
import MapKit

// ★ AddEventView・EditEventViewの「場所」欄で共通して使う、MapKitオートコンプリート付きの
//   入力フィールド。既存のdetailField(アイコン+タイトル+TextField)と見た目を揃えつつ、
//   入力中に候補をドロップダウンで出し、タップするとAppleの正式名称がそのまま確定する。
//   候補を選ばずそのまま自由入力で確定することもできる（従来通りの挙動を維持）。
struct VenuePlaceField: View {
    @Binding var text: String
    let accentColor: Color

    @StateObject private var autocomplete = VenueAutocompleteService()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(accentColor)
                Text("場所")
                    .font(.system(size: 14, weight: .medium))
            }

            TextField("例：東京ドーム", text: $text)
                .focused($isFocused)
                .padding(13)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .onChange(of: text) { _, newValue in
                    autocomplete.update(query: newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { autocomplete.clear() }
                }

            if isFocused && !autocomplete.results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(autocomplete.results.enumerated()), id: \.offset) { index, suggestion in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        Button {
                            // ★ suggestion.titleがAppleマップ上の正式名称。表記ゆれを防ぐ本体
                            text = suggestion.title
                            autocomplete.clear()
                            isFocused = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ★ 2026/08/16追加：場所を入力すると、オシニウムタブ「今後の予定・会場情報」に
            //   会場の天気・地図・おすすめ駅・周辺ホテル等とセットで表示されるようになる
            //   （EventHubPickerView.upcomingEventsWithPlace参照）ことを、入力時点で伝えておく
            Text("入力すると、オシニウムタブの「今後の予定・会場情報」に表示されます")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
                .padding(.horizontal, 2)
        }
        .animation(.easeOut(duration: 0.15), value: autocomplete.results.count)
    }
}
