//
//  MonthlyCalendarView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/25.
//

import SwiftUI
import FirebaseAuth

struct MonthlyCalendarView: View {

    let month: Date
    let eventsByDate: [Date: [Event]]
    let selectedCalendar: OshiCalendar?
    let communityCalendarId: String?

    @Binding var selectedGroup: IdolGroup?
    @Binding var selectedDate: Date

    // ★ FullCalendarTab から渡される「イベント選択時の処理」
    let onSelectEvent: (Event) -> Void
    // ★ FullCalendarTab から渡される「この日に予定を追加したい」時の処理
    let onRequestAddEvent: (Date) -> Void
    // ★ FullCalendarTab から渡される「この日の思い出日記をつけたい」時の処理
    let onRequestDiary: (Date) -> Void

    @State private var selectedDateForSheet: Date? = nil
    @State private var showDayEvents = false

    // ★ 日別一覧シートを表示・下スワイプで閉じている間、iOSはモーダル表示中の
    //   親ビューのサイズをカード風に縮小させる（表示中はずっと縮小したまま、
    //   閉じるアニメーションの途中経過も逐一GeometryReaderに伝わってくる）。
    //   これをそのまま高さ計算に使うと、シートを開閉するたびにカレンダーのセルが
    //   伸縮してガタついて見えてしまう。そのため高さは最初の1回だけ測定してこの状態に
    //   固定し、以降はシートの開閉によるジオメトリの変化を一切拾わないようにする
    //   （このタブは向き変更に対応していないため、初回測定を使い回して問題ない）
    @State private var cachedAvailableHeight: CGFloat? = nil

    @EnvironmentObject var eventViewModel: EventViewModel
    @EnvironmentObject var settingsVM: UserSettingsViewModel
    // ★ このタブは独自のNavigationStackを持つため、外側の.safeAreaInsetによる
    //   下タブバー分の安全域の縮小が伝わってこない。GeometryReaderが返す高さは
    //   実際より広く、そのままだと最終週やその下の要素がタブバーの裏に隠れてしまう
    @Environment(\.customTabBarHeight) private var customTabBarHeight
    @Environment(\.colorScheme) private var colorScheme

    // ★ 以前はColor.gray.opacity(0.06)の固定値だったため、ダークモードでは
    //   暗い背景に暗いグレーが重なってほぼ見えなくなっていた。ライト/ダークで
    //   別の値を明示的に持たせ、ダークモードでは白系の線をはっきり見せる
    private var gridLineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.gray.opacity(0.10)
    }

    private let calendar = Calendar(identifier: .gregorian)

    // ★ 帯の描画に使う共通レイアウト値（週の行を跨いだ計算で使い回す）
    private let topInset: CGFloat = 34
    private let bandRowHeight: CGFloat = 14
    private let bandStride: CGFloat = 16
    private let maxVisibleSlots = 4

    // ★ 祝日判定用（セルごとに毎回生成すると重いため使い回す）
    private static let holidayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let holidaySet: Set<String> = [
        "2026-01-01","2026-01-12","2026-02-11","2026-02-23",
        "2026-03-20","2026-04-29","2026-05-03","2026-05-04",
        "2026-05-05","2026-07-20","2026-08-11","2026-09-21",
        "2026-09-22","2026-09-23","2026-10-12","2026-11-03",
        "2026-11-23"
    ]

    var body: some View {

        GeometryReader { geo in
            let stableHeight = cachedAvailableHeight ?? geo.size.height

            VStack(spacing: 0) {

                // ★ 以前は先頭にSpacerを置いてカレンダーを下寄せにしていたが、
                //   セルの高さを可変にした結果、カレンダー上のグループ（コミュニティ等）
                //   アイコン列とカレンダー本体の間に大きな空白ができてしまっていた。
                //   カレンダーは上詰めにして、余りがあれば下に逃がすようにする
                weekdayHeader()

                // ★ セルの高さを画面の余白から逆算する。以前は115pt固定だったため、
                //   タブバー分だけ使える高さが減った状態だと6行はもちろん5行の月でも
                //   最終週やその下の＋ボタンがタブバーの裏に隠れて見切れてしまっていた
                calendarGrid(availableHeight: stableHeight)
            }
            .onAppear {
                // ★ シートを一度も開いていない、確実に正しいタイミングでの1回だけ測定する。
                //   以降はこの値を使い続け、シートの開閉に伴うジオメトリ変化には一切反応しない
                if cachedAvailableHeight == nil { cachedAvailableHeight = geo.size.height }
            }
            // ★ 以前は.sheetで表示していたが、標準の「シート表示中、背後の画面が縮小・後退する」
            //   演出のせいで、カレンダー本体が下にずれて見え、閉じた瞬間に元の位置へガクッと
            //   戻るように見えていた。.fullScreenCoverに変えることで背後の画面には一切
            //   手を加えず、日付一覧画面だけがスライドで出入りするようにして、この見た目のズレ・
            //   カクつきを解消する
            .fullScreenCover(isPresented: $showDayEvents) {

                // ★ Optional を unwrap して渡す
                if let date = selectedDateForSheet,
                   let group = selectedGroup {

                    NavigationStack {
                        DayEventListView(
                            date: date,
                            selectedGroup: group,
                            selectedCalendar: selectedCalendar,
                            communityCalendarId: communityCalendarId
                        ) { event in
                            // ★ イベント選択時の処理は「親に任せる」
                            showDayEvents = false
                            onSelectEvent(event)
                        }
                        .environmentObject(eventViewModel)
                        .environmentObject(settingsVM)
                    }

                } else {
                    Text("グループが選択されていません")
                }
            }
        }
    }

    // MARK: - 曜日ヘッダー
    private func weekdayHeader() -> some View {
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

        return HStack(spacing: 0) {
            ForEach(0..<7) { index in

                let color: Color = {
                    if index == 0 { return Color.red.opacity(0.75) }
                    if index == 6 { return Color.blue.opacity(0.75) }
                    return Color.black.opacity(0.55)
                }()

                Text(weekdays[index])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    // MARK: - カレンダー本体（1日が何曜日か・その月の日数によって5行/6行が自動で決まる）。
    //   週ごとの行として描画する
    //   ★ セルの高さは「その月に実際に必要な行数」で利用可能な高さを割って求める。
    //     行の間や最終行とタブバーの間に余白は作らず、セル同士をぴったりくっつけて
    //     使える領域を無駄なく埋める（5行の月はその分セルが大きく、6行の月は小さくなる）
    private func calendarGrid(availableHeight: CGFloat) -> some View {
        let days = generateCalendarDays(for: month)
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }

        let weekdayHeaderHeight: CGFloat = 24
        // ★ GeometryReaderが返す高さには、独自NavigationStackのせいで隠れてしまう
        //   自作タブバー分が含まれてしまっているため、ここで明示的に差し引く
        let usableHeight = availableHeight - weekdayHeaderHeight - customTabBarHeight
        // ★ 一度「常に6行固定で割る」＝月をまたいで完全に同じ高さにする方式を試したが、
        //   5行の月では最終行の下に使われない空白がまるまる1行分できてしまっていた。
        //   スペースを余らせるより、その月の実際の行数で割って使い切る方を優先する
        //   （5行の月はその分セルが大きく、6行の月はやや小さくなる）
        let cellHeight = weeks.isEmpty ? 0 : max(usableHeight / CGFloat(weeks.count), 60)

        return VStack(spacing: 0) {
            ForEach(weeks.indices, id: \.self) { idx in
                weekRow(weeks[idx], cellHeight: cellHeight)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 指定日のイベント（選択中グループ・カレンダーでフィルタ）
    //   個人カレンダー選択時も、予定を組む上で重要なコミュニティカレンダーの予定は併せて表示する
    private func filteredEvents(for date: Date) -> [Event] {
        let key = calendar.startOfDay(for: date)
        guard let events = eventsByDate[key] else { return [] }
        // ★ グループ未選択（「あとで選ぶ」でスキップした場合）は、
        //   どのグループにも属していないため何も表示しない
        guard let group = selectedGroup else { return [] }

        return events.filter { event in
            guard event.groupId == group.id else { return false }
            guard let oshiCalendar = selectedCalendar else { return true }

            if oshiCalendar.isCommunity {
                return isCommunityEvent(event) && isApprovedForMe(event)
            } else {
                return event.calendarId == oshiCalendar.id || (isCommunityEvent(event) && isApprovedForMe(event))
            }
        }
    }

    // MARK: - コミュニティカレンダーの予定かどうか（既存データのnilフォールバックも考慮）
    private func isCommunityEvent(_ event: Event) -> Bool {
        event.calendarId == nil || event.calendarId == communityCalendarId
    }

    // ★ コミュニティカレンダーの承認制：自分が承認した予定だけを自分のカレンダーに表示する。
    //   追加した本人は書き込み時に自動でapprovedByへ入るため、この条件だけで両方カバーできる
    private func isApprovedForMe(_ event: Event) -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return event.approvedBy.contains(uid)
    }

    private func hasSecretEvent(for date: Date) -> Bool {
        filteredEvents(for: date).contains { e in
            guard e.isSecret else { return false }
            if let start = e.startDate, let end = e.endDate, start <= date, date <= end {
                return true
            }
            return calendar.isDate(e.date, inSameDayAs: date)
        }
    }

    // MARK: - 帯セグメント（週内で連続する同一予定を1本の帯としてまとめる）
    //   ★ 以前は日ごとのセルに個別の帯を敷き、角丸を潰して繋がって見えるようにしていたが、
    //     タイトルは開始日の左端にしか出せず、連日帯でも中央揃えにならなかった。
    //     ここでは週の行単位で「同じタイトル・同じグループの予定が何列目から何列目まで
    //     連続しているか」を直接計算し、後段でその範囲ぶんの1本の帯として描画することで、
    //     どのグループの・何日連続の帯でも自然に中央揃えになるようにする
    private struct BandSegment: Identifiable {
        let id = UUID()
        let event: Event
        var startCol: Int
        var endCol: Int
        var slot: Int = 0
    }

    private func bandSegments(for week: [Date]) -> [BandSegment] {
        struct Key: Hashable { let title: String; let groupId: String? }

        var open: [Key: Int] = [:]
        var result: [BandSegment] = []

        for (col, date) in week.enumerated() {
            let events = filteredEvents(for: date)

            let rangeEvents = events.filter { e in
                if let s = e.startDate, let end = e.endDate { return s <= date && date <= end }
                return false
            }
            let singleEvents = events.filter { e in
                e.startDate == nil && e.endDate == nil &&
                calendar.isDate(e.date, inSameDayAs: date) && !e.isSecret
            }
            let dayEvents = rangeEvents + singleEvents

            let todayKeys = Set(dayEvents.map { Key(title: $0.title, groupId: $0.groupId) })

            // 前のカラムまで続いていたが、今日は続いていない帯を閉じる
            for key in open.keys where !todayKeys.contains(key) {
                open.removeValue(forKey: key)
            }

            // 今日のイベントを反映（継続なら伸ばす、新規なら開始する）
            for event in dayEvents {
                let key = Key(title: event.title, groupId: event.groupId)
                if let idx = open[key] {
                    result[idx].endCol = col
                } else {
                    result.append(BandSegment(event: event, startCol: col, endCol: col))
                    open[key] = result.count - 1
                }
            }
        }

        return result
    }

    // ★ 同じ週内で列が重なる帯同士がぶつからないよう、貪欲法で縦位置（スロット）を割り当てる
    private func assignSlots(_ segments: [BandSegment]) -> [BandSegment] {
        var segs = segments.sorted {
            if $0.startCol != $1.startCol { return $0.startCol < $1.startCol }
            return ($0.endCol - $0.startCol) > ($1.endCol - $1.startCol)
        }

        var slotRanges: [[ClosedRange<Int>]] = []
        for i in segs.indices {
            let range = segs[i].startCol...segs[i].endCol
            var placedSlot: Int? = nil
            for slotIdx in slotRanges.indices where !slotRanges[slotIdx].contains(where: { $0.overlaps(range) }) {
                placedSlot = slotIdx
                break
            }
            if let placedSlot {
                segs[i].slot = placedSlot
                slotRanges[placedSlot].append(range)
            } else {
                segs[i].slot = slotRanges.count
                slotRanges.append([range])
            }
        }
        return segs
    }

    // ★ 表示しきれず隠れた帯（スロット4以上）がその列に何本あるか
    private func overflowCount(_ segments: [BandSegment], col: Int) -> Int {
        segments.filter { $0.slot >= maxVisibleSlots && $0.startCol <= col && col <= $0.endCol }.count
    }

    // MARK: - 色ルール
    private func color(for type: EventType) -> Color {
        switch type {
        case .live, .event: return .red
        case .tv: return .green
        case .release: return .blue
        case .sns: return .orange
        case .anniversary: return .purple
        case .other: return .gray
        }
    }

    // MARK: - 半角/全角考慮したタイトル制限（半角=0.6文字）
    private func truncatedTitle(_ title: String, limit: Double = 6.0) -> String {
        var count: Double = 0
        var result = ""

        for char in title {
            if char.isASCII {
                count += 0.6
            } else {
                count += 1.0
            }

            if count > limit { break }
            result.append(char)
        }

        return result
    }

    // MARK: - 半角英字は tracking を広げる
    private func adjustedTitle(_ title: String) -> Text {
        let isAscii = title.unicodeScalars.allSatisfy { $0.isASCII }

        if isAscii {
            return Text(title).tracking(0.8)
        } else {
            return Text(title)
        }
    }

    // MARK: - 週の行（7日ぶんの日付セル＋帯オーバーレイをまとめて描画）
    private func weekRow(_ week: [Date], cellHeight: CGFloat) -> some View {
        let segments = assignSlots(bandSegments(for: week))
        let visibleSegments = segments.filter { $0.slot < maxVisibleSlots }

        return GeometryReader { geo in
            let colWidth = geo.size.width / 7

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { date in
                        dayNumberCell(date, cellHeight: cellHeight)
                            .frame(width: colWidth)
                            .overlay(
                                Rectangle().stroke(gridLineColor, lineWidth: 0.5)
                            )
                    }
                }

                // ★ 帯そのものはタップ対象ではない（日付セル側のタップ/長押しがそのまま効くようにする）
                ForEach(visibleSegments) { seg in
                    bandView(seg)
                        .frame(width: colWidth * CGFloat(seg.endCol - seg.startCol + 1), height: bandRowHeight)
                        .offset(x: colWidth * CGFloat(seg.startCol), y: topInset + CGFloat(seg.slot) * bandStride)
                }
                .allowsHitTesting(false)

                ForEach(0..<7, id: \.self) { col in
                    if overflowCount(segments, col: col) > 0 {
                        overflowBadge
                            .frame(width: colWidth, height: bandRowHeight, alignment: .trailing)
                            .offset(x: colWidth * CGFloat(col), y: topInset + bandStride * CGFloat(maxVisibleSlots - 1))
                    }
                }
                .allowsHitTesting(false)

                // 秘密イベントのロックアイコン（帯の表示枠ぶんの下に固定表示）
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { date in
                        Group {
                            if hasSecretEvent(for: date) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.purple)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(width: colWidth)
                    }
                }
                .offset(y: topInset + bandStride * CGFloat(maxVisibleSlots) + 2)
                .allowsHitTesting(false)
            }
        }
        .frame(height: cellHeight)
    }

    // MARK: - 帯の見た目（1本の帯として週の複数列にまたがる場合はまとめて1つの角丸矩形にする）
    //   ★ 文字数の上限は帯が連続している日数分だけそのまま伸ばす（上限のキャップは設けない）。
    //     帯の実際の横幅ぶんだけ文字が入る余地があるので、続く日数が多いほど長いタイトルを表示できる
    private func bandView(_ seg: BandSegment) -> some View {
        let showsSilverRing = !(selectedCalendar?.isCommunity ?? true) && isCommunityEvent(seg.event)
        let spanDays = seg.endCol - seg.startCol + 1
        let limit = 6.0 * Double(spanDays)

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color(for: seg.event.type ?? .other))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: showsSilverRing ? 1.3 : 0
                    )
            )
            .overlay(
                adjustedTitle(truncatedTitle(seg.event.title, limit: limit))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 3)
            )
    }

    private var overflowBadge: some View {
        Image(systemName: "plus")
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 12, height: 12)
            .background(Circle().fill(Color.black.opacity(0.55)))
            .padding(.trailing, 1)
            .accessibilityHidden(true)
    }

    // MARK: - 日付セル（日付番号・選択状態・タップ/長押しのみを担当。帯は週の行側で重ねて描画する）
    private func dayNumberCell(_ date: Date, cellHeight: CGFloat) -> some View {

        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isInCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let weekday = calendar.component(.weekday, from: date)
        let isHoliday = isJapaneseHoliday(date)

        // ★ 平日の日付テキストがColor.black固定だったため、ダークモードでは
        //   暗い背景に暗い文字が重なりほぼ読めなくなっていた。.primaryにして
        //   ライト/ダークどちらでも自動的に読める濃さになるようにする
        let textColor: Color = {
            if !isInCurrentMonth { return Color.gray.opacity(0.25) }
            if weekday == 7 { return Color.blue.opacity(0.75) }
            if isHoliday || weekday == 1 { return Color.red.opacity(0.75) }
            return Color.primary.opacity(0.7)
        }()

        let isSelected = selectedDateForSheet.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        return ZStack(alignment: .top) {

            // ★ 以前は「今日」のセルだけ選択時のグレー背景が出なかったが、
            //   他の日と同じようにタップしたらグレーに変わるようにする
            //   （今日を示す丸自体は数字の背景として独立して重ねて表示されるので共存できる）
            if isSelected {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
            }

            VStack(spacing: 0) {
                ZStack {
                    if isToday {
                        // ★ 以前より一回り小さく、色も薄い半透明にして控えめにする
                        Circle()
                            .fill(Color.black.opacity(0.35))
                            .frame(width: 26, height: 26)
                    }

                    Text("\(day)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isToday ? .white : textColor)
                }
                .frame(height: topInset - 4)

                Spacer(minLength: 0)
            }
            .padding(.top, 4)
        }
        .frame(height: cellHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                showDayEvents = true
            } else {
                selectedDateForSheet = date
                selectedDate = date
            }
        }
        .contextMenu {
            Button {
                selectedDate = date
                onRequestAddEvent(date)
            } label: {
                Label("予定を追加", systemImage: "plus.circle")
            }

            Button {
                selectedDateForSheet = date
                selectedDate = date
                showDayEvents = true
            } label: {
                Label("この日の予定を見る", systemImage: "list.bullet")
            }

            Button {
                selectedDate = date
                onRequestDiary(date)
            } label: {
                Label("思い出日記をつける", systemImage: "book.closed")
            }
        }
    }

    // MARK: - カレンダー用の日付生成（前後月で7の倍数まで埋める＝月により5〜6行）
    private func generateCalendarDays(for date: Date) -> [Date] {

        var days: [Date] = []

        // ★ 通常のグレゴリオ暦であれば失敗しないはずだが、万一Calendar APIがnilを返した場合に
        //   クラッシュさせず空の月として表示する（強制アンラップの安全化）
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingCount = firstWeekday - 1

        if leadingCount > 0, let prevMonth = calendar.date(byAdding: .month, value: -1, to: date),
           let prevRange = calendar.range(of: .day, in: .month, for: prevMonth) {
            let prevLast = prevRange.count

            for i in stride(from: leadingCount - 1, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: prevLast - i - 1, to: prevMonth.startOfMonth) {
                    days.append(d)
                }
            }
        }

        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(d)
            }
        }

        // ★ 7の倍数（週の途中まで）になるよう翌月の日付で埋める
        //   月によって必要な行数が5行・6行と変わるため、常に35固定にはしない
        let remainder = days.count % 7
        if remainder != 0, let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) {
            let trailingCount = 7 - remainder
            for i in 0..<trailingCount {
                if let d = calendar.date(byAdding: .day, value: i, to: nextMonth.startOfMonth) {
                    days.append(d)
                }
            }
        }

        return days
    }

    // MARK: - 祝日判定
    private func isJapaneseHoliday(_ date: Date) -> Bool {
        if calendar.isDateInWeekend(date) { return true }
        let key = Self.holidayFormatter.string(from: date)
        return Self.holidaySet.contains(key)
    }
}

private extension Date {
    // ★ 通常は必ず成功するはずだが、Calendar APIがnilを返した場合に備えてselfへフォールバックする
    //   （強制アンラップを避ける。月初がずれるだけで、クラッシュにはしない）
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}
