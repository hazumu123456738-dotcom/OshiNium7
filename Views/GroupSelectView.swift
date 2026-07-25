import SwiftUI

struct GroupSelectView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel

    @State private var selectedGroup: IdolGroup? = nil
    @State private var showDuplicateAlert = false
    @State private var showCreateGroupSheet = false

    @AppStorage("hasSelectedGroup") private var hasSelectedGroup = false

    var onComplete: () -> Void

    let allGroups: [IdolGroup] = [
        IdolGroup(
            id: "xikers-id",
            name: "xikers",
            imageData: UIImage(named: "xikers")?.pngData(),
            reading: "サイカーズ",
            fandom: "Roady",
            concept: "冒険・旅・エネルギッシュな世界観",
            history: "2023年デビュー。KQエンタ所属。ATEEZの弟分。"
        ),
        IdolGroup(
            id: "ATEEZ-id",
            name: "ATEEZ",
            imageData: UIImage(named: "ATEEZ")?.pngData(),
            reading: "エイティーズ / アチズ",
            fandom: "ATINY",
            concept: "海賊・冒険・ストーリー性の強いパフォーマンス",
            history: "2018年デビュー。世界的人気のK-POPボーイズグループ。"
        ),
        IdolGroup(
            id: "Heart2Heart-id",
            name: "Heart2Heart",
            imageData: UIImage(named: "Heart2Heart")?.pngData(),
            reading: "ハーツトゥーハーツ",
            fandom: "H2H",
            concept: "愛・癒し・ポップで明るい世界観",
            history: "架空グループとして扱う場合は自由に設定可能。"
        )
    ]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let horizontalPadding: CGFloat = 16 * 3
            let availableWidth = max(screenWidth - horizontalPadding, 0)
            let cardSide = max(availableWidth / 2, 0)

            ScrollView {
                VStack(spacing: 20) {

                    Text("推しグループを選択")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 20)

                    // MARK: - グループ一覧
                    LazyVGrid(columns: columns, spacing: 20) {

                        let totalCells = 10
                        let count = min(allGroups.count, totalCells)
                        let filled = Array(allGroups.prefix(count))
                        let items: [IdolGroup?] = filled + Array(repeating: nil, count: max(0, totalCells - filled.count))

                        ForEach(0..<items.count, id: \.self) { index in
                            if let group = items[index] {

                                GroupCard(
                                    group: group,
                                    isSelected: selectedGroup?.id == group.id
                                )
                                .frame(width: cardSide, height: cardSide)
                                .clipped()
                                .onTapGesture {
                                    selectedGroup = group
                                }

                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray6))
                                    .frame(width: cardSide, height: cardSide)
                                    .overlay(
                                        Text("空欄")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // MARK: - 新規グループ作成ボタン
                    Button(action: {
                        showCreateGroupSheet = true
                    }) {
                        Text("＋ 新しいグループを作成")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .sheet(isPresented: $showCreateGroupSheet) {
                        NewGroupView { newGroup in
                            // Firestore に保存されたグループをローカルにも反映
                            groupViewModel.addGroup(newGroup)
                            selectedGroup = newGroup
                        }
                        .environmentObject(groupViewModel)
                    }

                    // MARK: - 決定ボタン（選択時のみ表示）
                    if let selected = selectedGroup {
                        Button(action: {

                            // Firestore 側の重複チェック（id ベース）
                            if groupViewModel.groups.contains(where: { $0.id == selected.id }) {
                                showDuplicateAlert = true
                                return
                            }

                            // Firestore に保存
                            groupViewModel.addGroup(selected)

                            hasSelectedGroup = true

                            DispatchQueue.main.async {
                                onComplete()
                            }

                        }) {
                            Text("決定する")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .alert("このグループはすでに選択済みです", isPresented: $showDuplicateAlert) {
                            Button("OK", role: .cancel) {}
                        }
                    }

                    // MARK: - スキップボタン
                    Button(action: {
                        hasSelectedGroup = true
                        onComplete()
                    }) {
                        Text("スキップ")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
        }
    }
}

