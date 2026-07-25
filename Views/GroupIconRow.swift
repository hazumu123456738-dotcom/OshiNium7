//
//  GroupIconRow.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/14.
//

import SwiftUI

struct GroupIconRow: View {
    var groups: [IdolGroup]
    var selectedGroup: IdolGroup?

    // HomeView から渡される
    var onAddGroup: () -> Void = {}
    var onRequestSwitchGroup: (IdolGroup) -> Void = { _ in }
    var onDeleteGroup: (IdolGroup) -> Void = { _ in }

    @State private var deleteTargetID: String? = nil

    // ★ 全アイコンのサイズを統一（ここを変えれば全体が変わる）
    private let iconSize: CGFloat = 80

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {

                Spacer(minLength: 16)

                ForEach(groups) { group in
                    ZStack(alignment: .top) {

                        VStack(spacing: 6) {

                            GroupIcon(
                                group: group,
                                isSelected: selectedGroup?.id == group.id,
                                size: iconSize
                            )
                            .onTapGesture {

                                // ★ 削除モード中なら削除モード解除
                                if deleteTargetID != nil {
                                    withAnimation { deleteTargetID = nil }
                                    return
                                }

                                // ★ 現在選択中のグループなら何もしない
                                if selectedGroup?.id == group.id {
                                    return
                                }

                                // ★ HomeView に「切り替え要求」を送る
                                onRequestSwitchGroup(group)
                            }
                            .onLongPressGesture {
                                withAnimation {
                                    deleteTargetID = group.id
                                }
                            }

                            Text(group.name)
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }

                        // MARK: - 削除ボタン
                        if deleteTargetID == group.id {
                            Button(action: {
                                withAnimation {
                                    onDeleteGroup(group)
                                    deleteTargetID = nil
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                            .offset(x: iconSize * 0.35, y: -10)
                        }
                    }
                }

                // MARK: - 追加ボタン（アイコンサイズ統一）
                Button(action: onAddGroup) {
                    VStack(spacing: 6) {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.gray)
                            .frame(width: iconSize, height: iconSize)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: iconSize * 0.35))
                                    .foregroundColor(.gray)
                            )

                        Text("追加")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer(minLength: 16)
            }
            .padding(.horizontal)
        }
    }
}

struct GroupIcon: View {
    var group: IdolGroup
    var isSelected: Bool
    var size: CGFloat   // ← サイズを外から受け取る

    var body: some View {
        ZStack {
            if let data = group.imageData,
               let uiImage = UIImage(data: data) {

                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)   // ← 余白を無視して最大化
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .clipped()

                    // ★ 以下はあなたのシャボン玉エフェクトをそのまま残す
                    .overlay(
                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.8)
                                    ]),
                                    center: .center
                                ),
                                lineWidth: isSelected ? 3 : 2
                            )
                            .opacity(0.9)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isSelected ? 0.55 : 0.35), lineWidth: 1.5)
                            .blur(radius: isSelected ? 2 : 1.5)
                            .offset(x: -2, y: -2)
                            .mask(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.white, .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    )
                    .shadow(color: Color.white.opacity(0.25), radius: 3, x: 0, y: 1)
                    .shadow(color: Color.white.opacity(isSelected ? 1.0 : 0),
                            radius: isSelected ? 14 : 0)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isSelected ? 0.9 : 0),
                                    lineWidth: isSelected ? 4 : 0)
                            .blur(radius: isSelected ? 3 : 0)
                    )
            }
        }
    }
}
