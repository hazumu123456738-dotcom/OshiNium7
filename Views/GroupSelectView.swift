import SwiftUI

struct GroupSelectView: View {
    @EnvironmentObject var groupViewModel: GroupViewModel

    @State private var selectedGroup: IdolGroup? = nil
    @State private var showDuplicateAlert = false
    @State private var showCreateGroupSheet = false
    @State private var searchText = ""
    @State private var showGroupLimitReached = false
    @State private var leaveCooldownDaysRemaining: Int?
    @State private var showPremiumUpgrade = false

    var onComplete: () -> Void

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    // ★ 全ユーザー共通のカタログ（/groups）から取得。検索文字列で絞り込む。
    //   ★ 招待制のグループチャット（isPrivate）はここには出さない
    private var filteredCatalog: [IdolGroup] {
        let publicOnly = groupViewModel.catalog.filter { !$0.isPrivate }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return publicOnly }
        return publicOnly.filter { group in
            group.name.localizedCaseInsensitiveContains(trimmed)
                || (group.reading?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (group.fandom?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // ★ ジャンル（GroupCategory）ごとにセクション分けする。カテゴリ未設定の古いデータは
    //   「その他」にまとめる。検索中は横断的に探したいはずなのでジャンル分けせずフラットに出す
    private var groupedCatalog: [(category: GroupCategory, groups: [IdolGroup])] {
        let dict = Dictionary(grouping: filteredCatalog) { $0.category ?? .other }
        return GroupCategory.allCases.compactMap { category in
            guard let groups = dict[category], !groups.isEmpty else { return nil }
            return (category: category, groups: groups)
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 32
            let interItemSpacing: CGFloat = 16
            let availableWidth = max(geo.size.width - horizontalPadding - interItemSpacing, 0)
            let cardSide = availableWidth / 2

            ScrollView {
                VStack(spacing: 24) {

                    header
                    searchBar

                    if groupViewModel.isLoadingCatalog && groupViewModel.catalog.isEmpty {
                        ProgressView("読み込み中…")
                            .padding(.top, 40)
                    } else if groupViewModel.catalog.isEmpty {
                        emptyCatalogState
                    } else if filteredCatalog.isEmpty {
                        noSearchResultState
                    } else if isSearching {
                        // ★ 検索中はジャンルを横断して探したいはずなので、フラットな一覧にする
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredCatalog) { group in
                                groupTile(group, cardSide: cardSide)
                            }
                            addGroupCard
                                .frame(width: cardSide, height: cardSide)
                        }
                        .padding(.horizontal, 16)
                    } else {
                        // MARK: - グループ一覧（ジャンルごとにセクション分け）
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(groupedCatalog, id: \.category) { entry in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(entry.category.rawValue)
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(.horizontal, 16)

                                    LazyVGrid(columns: columns, spacing: 16) {
                                        ForEach(entry.groups) { group in
                                            groupTile(group, cardSide: cardSide)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("見つからなかった？")
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(.horizontal, 16)

                                addGroupCard
                                    .frame(width: cardSide, height: cardSide)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }

                    if let selected = selectedGroup {
                        decideButton(for: selected)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedGroup?.id)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            groupViewModel.loadCatalog()
        }
        .sheet(isPresented: $showCreateGroupSheet) {
            NavigationStack {
                NewGroupView { newGroup in
                    selectedGroup = newGroup
                    groupViewModel.loadCatalog()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            showCreateGroupSheet = false
                        }
                    }
                }
            }
            .environmentObject(groupViewModel)
        }
        .alert("このグループはすでに登録済みです", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("推しグループの上限に達しました", isPresented: $showGroupLimitReached) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text("無課金では推しグループを2件まで登録できます。プレミアムにアップグレードすると5件まで登録できます。")
        }
        .alert("少し待ってください", isPresented: Binding(
            get: { leaveCooldownDaysRemaining != nil },
            set: { if !$0 { leaveCooldownDaysRemaining = nil } }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("アップグレード") { showPremiumUpgrade = true }
        } message: {
            Text(GroupCreationError.leaveCooldownActive(daysRemaining: leaveCooldownDaysRemaining ?? 0).errorDescription ?? "")
        }
        .sheet(isPresented: $showPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }

    // MARK: - グループタイル（検索結果・ジャンル別セクションの両方から共通で使う）

    private func groupTile(_ group: IdolGroup, cardSide: CGFloat) -> some View {
        GroupPickCard(
            group: group,
            isSelected: selectedGroup?.id == group.id,
            side: cardSide
        )
        .environmentObject(groupViewModel)
        .frame(width: cardSide, height: cardSide)
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedGroup = group
            }
        }
    }

    // MARK: - 検索バー

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("グループ名やファンダム名で検索", text: $searchText)
                .font(.system(size: 15))
                .autocapitalization(.none)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .accessibilityLabel("検索文字をクリア")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - 空の状態

    private var emptyCatalogState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundColor(accentColor.opacity(0.6))
            Text("まだ登録されているグループがありません")
                .font(.system(size: 14, weight: .semibold))
            Text("最初のグループを作ってみましょう。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            addGroupCard
                .frame(width: 160, height: 160)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var noSearchResultState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.6))
            Text("「\(searchText)」に一致するグループが見つかりませんでした")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Text("新しいグループとして登録できます。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            addGroupCard
                .frame(width: 160, height: 160)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - ヘッダー（何をする画面なのか一目でわかるように）

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [accentColor, accentColor2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: accentColor.opacity(0.35), radius: 14, x: 0, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("推しグループを選ぼう")
                .font(.system(size: 22, weight: .bold))

            Text("気になるグループをタップして選んでね。\nあとからいくつでも追加できます。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
    }

    // MARK: - 新規グループ作成タイル

    private var addGroupCard: some View {
        Button {
            showCreateGroupSheet = true
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundColor(accentColor.opacity(0.5))
                        .background(Circle().fill(accentColor.opacity(0.08)))
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                Text("新しいグループを作る")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.appCardBackground.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 決定ボタン

    private func decideButton(for group: IdolGroup) -> some View {
        Button {
            // Firestore 側の重複チェック（id ベース）
            if groupViewModel.groups.contains(where: { $0.id == group.id }) {
                showDuplicateAlert = true
                return
            }

            // Firestore に保存
            groupViewModel.addGroup(group) { error in
                if let error, case GroupCreationError.groupLimitReached = error {
                    showGroupLimitReached = true
                    return
                }
                if let error, case GroupCreationError.leaveCooldownActive(let daysRemaining) = error {
                    leaveCooldownDaysRemaining = daysRemaining
                    return
                }
                DispatchQueue.main.async {
                    onComplete()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("「\(group.name)」に決定する")
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(colors: [accentColor, accentColor2],
                               startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: accentColor.opacity(0.35), radius: 14, x: 0, y: 8)
        }
    }

}

// MARK: - グループ選択カード（写真＋名前＋ファンダム名を1枚に統一表示）

private struct GroupPickCard: View {
    let group: IdolGroup
    let isSelected: Bool
    let side: CGFloat

    @EnvironmentObject var groupViewModel: GroupViewModel
    // ★ 「このグループに今何人参加しているか」をカードに出す。カタログ一覧のIdolGroup自体は
    //   人数を持たないため、カードが表示された時に軽量なcount()集計クエリで個別に取得する
    @State private var memberCount: Int?

    private let accentColor = Color.oshiniumPrimary
    private let accentColor2 = Color.oshiniumPrimary2

    var body: some View {
        ZStack(alignment: .topTrailing) {

            ZStack(alignment: .bottomLeading) {
                if let data = group.imageData, let uiImage = UIImage(data: data) {
                    // ★ 画像本来の縦横比によって親のサイズがはみ出さないよう、
                    //   Image自体にも明示的に正方形フレーム＋clippedを指定する
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipped()
                } else {
                    LinearGradient(colors: [accentColor, accentColor2],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: side, height: side)
                    Text(String(group.name.prefix(1)))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: side, height: side)
                }

                LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)],
                               startPoint: .bottom, endPoint: .center)
                    .frame(width: side, height: side * 0.55)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let fandom = group.fandom {
                        Text(fandom)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    if let memberCount {
                        Label("\(memberCount)人参加中", systemImage: "person.2.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if isSelected {
                ZStack {
                    Circle().fill(accentColor)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? accentColor : Color.clear, lineWidth: 3)
        )
        .shadow(color: .black.opacity(isSelected ? 0.15 : 0.08),
                radius: isSelected ? 14 : 8, x: 0, y: isSelected ? 8 : 4)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
        .onAppear {
            guard memberCount == nil else { return }
            groupViewModel.fetchMemberCount(groupId: group.id) { count in
                memberCount = count
            }
        }
    }
}
