//
//  EventHubWeatherDetailSheet.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import SwiftUI
import Charts

// ★ 2026/08/20（oshiスキル監査）：EventHubDetailView.swiftが2,592行まで肥大化していたため、
//   すでに独立したstructだった天気詳細シートをこのファイルへ切り出した。
//   EventHubDetailView本体からWeatherDetailSheet(...)として呼ばれるためprivateは外している

// MARK: - 天気カード詳細シート（気圧・湿度・体調アドバイスなどをまとめて見せる）

struct WeatherDetailSheet: View {
    let event: Event
    let weather: DailyWeather
    let accentColor: Color
    let gradientColors: [Color]

    @Environment(\.dismiss) private var dismiss

    private var formattedDate: String {
        return CachedFormatters.date(format: "M月d日(E)").string(from: event.date)
    }

    // ★ 今日からイベント当日までの日数。予報の精度が下がる目安をユーザーに伝えるために使う
    private var daysAhead: Int {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: event.date)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    hero
                    if daysAhead >= 3 {
                        forecastConfidenceNote
                    }
                    statsGrid
                    adviceCards
                    if hasHourlyChartData {
                        precipitationChartCard
                        temperatureChartCard
                    }
                    sourceFooter
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // ★ グラフだけを見ると「確定した数値」に見えてしまうため、先の予報であるほど変わりうることを
    //   グラフの直前・スクロールせず見える位置で必ず伝える(sourceFooterの詳しい注記だけでは
    //   一番下まで見ないと気づけないため、ここに要約を出す)
    private var forecastConfidenceNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(.orange)
            Text("あと\(daysAhead)日先の予報です。日が近づくと数値が変わることがあります")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))

            Image(systemName: weather.symbolName)
                .font(.system(size: 130))
                .foregroundColor(.white.opacity(0.16))
                .rotationEffect(.degrees(-6))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 24, y: 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(formattedDate)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("\(Int(weather.maxTemp.rounded()))°")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    Text("/\(Int(weather.minTemp.rounded()))°")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }

                Text(weather.description)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(22)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 8)
    }

    // MARK: - 時間ごとのグラフ（降水確率・気温）

    private struct HourlyPoint: Identifiable {
        let hour: Int
        let value: Double
        var id: Int { hour }
    }

    private var hasHourlyChartData: Bool {
        !(weather.hourlyPrecipitationProbability?.isEmpty ?? true)
            || !(weather.hourlyTemperature?.isEmpty ?? true)
    }

    private var precipitationPoints: [HourlyPoint] {
        (weather.hourlyPrecipitationProbability ?? []).enumerated().map {
            HourlyPoint(hour: $0.offset, value: Double($0.element))
        }
    }

    private var temperaturePoints: [HourlyPoint] {
        (weather.hourlyTemperature ?? []).enumerated().map {
            HourlyPoint(hour: $0.offset, value: $0.element)
        }
    }

    private var temperatureMinPoint: HourlyPoint? { temperaturePoints.min { $0.value < $1.value } }
    private var temperatureMaxPoint: HourlyPoint? { temperaturePoints.max { $0.value < $1.value } }

    // ★ 最高/最低の点がグラフの端（0時付近・23時付近）にあると、中央揃えのラベルが
    //   軸の目盛りとぶつかって重なって見えるため、端に近いときだけラベルを内側に寄せる
    private func annotationPosition(forHour hour: Int, isTop: Bool) -> AnnotationPosition {
        if hour >= 20 {
            return isTop ? .topLeading : .bottomLeading
        } else if hour <= 3 {
            return isTop ? .topTrailing : .bottomTrailing
        }
        return isTop ? .top : .bottom
    }

    @ViewBuilder
    private var precipitationChartCard: some View {
        if !precipitationPoints.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("降水確率")
                    .font(.system(size: 15, weight: .bold))
                if let precip = weather.precipitationProbability {
                    Text("\(formattedDate)の確率：\(precip)%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Chart(precipitationPoints) { point in
                    AreaMark(x: .value("時刻", point.hour), y: .value("降水確率", point.value))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.blue.opacity(0.32), Color.blue.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("時刻", point.hour), y: .value("降水確率", point.value))
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: -1...24)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour)時")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 20, 40, 60, 80, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
                            }
                        }
                    }
                }
                .frame(height: 160)

                Text("1時間ごとの降水確率です。日別の確率とは値が異なる場合があります。")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
    }

    @ViewBuilder
    private var temperatureChartCard: some View {
        if !temperaturePoints.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("気温")
                    .font(.system(size: 15, weight: .bold))
                Text("\(formattedDate)　最高\(Int(weather.maxTemp.rounded()))° / 最低\(Int(weather.minTemp.rounded()))°")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Chart(temperaturePoints) { point in
                    AreaMark(x: .value("時刻", point.hour), y: .value("気温", point.value))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.orange.opacity(0.32), Color.orange.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("時刻", point.hour), y: .value("気温", point.value))
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.catmullRom)

                    if let temperatureMaxPoint, point.hour == temperatureMaxPoint.hour {
                        PointMark(x: .value("時刻", point.hour), y: .value("気温", point.value))
                            .foregroundStyle(Color.orange)
                            .annotation(position: annotationPosition(forHour: point.hour, isTop: true)) {
                                Text("最高 \(Int(point.value.rounded()))°")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                    }
                    if let temperatureMinPoint, point.hour == temperatureMinPoint.hour {
                        PointMark(x: .value("時刻", point.hour), y: .value("気温", point.value))
                            .foregroundStyle(Color.orange)
                            .annotation(position: annotationPosition(forHour: point.hour, isTop: false)) {
                                Text("最低 \(Int(point.value.rounded()))°")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                    }
                }
                .chartXScale(domain: -1...24)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour)時")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v.rounded()))°")
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding(.top, 14)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
    }

    // ★ 数値だけでは「高いか低いか」が伝わらないため、各カードに一言レベル表示を添える
    private func pressureLevel(_ value: Double) -> String {
        if value < 1000 { return "低い" }
        if value < 1008 { return "やや低い" }
        return "平年並み"
    }

    private func humidityLevel(_ value: Double) -> String {
        if value >= 75 { return "高い" }
        if value <= 30 { return "低い" }
        return "ちょうど良い"
    }

    private func precipitationLevel(_ value: Int) -> String {
        if value >= 50 { return "高い" }
        if value >= 20 { return "やや注意" }
        return "低い"
    }

    private func sunshineLevel(_ hours: Double) -> String {
        if hours >= 8 { return "長い" }
        if hours <= 3 { return "短い" }
        return "平年並み"
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if let pressure = weather.averagePressure {
                statCard(icon: "gauge.medium", label: "平均気圧", value: "\(Int(pressure.rounded())) hPa", level: pressureLevel(pressure))
            }
            if let humidity = weather.averageHumidity {
                statCard(icon: "humidity.fill", label: "平均湿度", value: "\(Int(humidity.rounded())) %", level: humidityLevel(humidity))
            }
            if let precip = weather.precipitationProbability {
                statCard(icon: "umbrella.fill", label: "降水確率", value: "\(precip) %", level: precipitationLevel(precip))
            }
            if let uv = weather.uvIndexMax {
                statCard(icon: "sun.max.trianglebadge.exclamationmark.fill", label: "UV指数", value: String(format: "%.1f", uv), level: weather.uvLevelLabel)
            }
            if let sunshine = weather.sunshineDurationHours {
                statCard(icon: "sun.and.horizon.fill", label: "日照時間", value: "\(String(format: "%.1f", sunshine)) 時間", level: sunshineLevel(sunshine))
            }
        }
    }

    private func statCard(icon: String, label: String, value: String, level: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
                Spacer(minLength: 0)
                if let level {
                    Text(level)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    @ViewBuilder
    private var adviceCards: some View {
        let advisories = [
            weather.rainAdvisory,
            weather.sunscreenAdvisory,
            weather.pressureAdvisory,
            weather.humidityAdvisory,
            weather.sunshineAdvisory
        ].compactMap { $0 }
        if !advisories.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(advisories, id: \.self) { advisory in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                        Text(advisory)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accentColor.opacity(0.08))
                    )
                }
            }
        }
    }

    // ★ データの出所と精度の限界を明示する。3日以上先は予報が変わりやすいことも伝える
    private var sourceFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                Text("データ提供元")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.secondary)

            Link(destination: URL(string: "https://open-meteo.com")!) {
                HStack(spacing: 4) {
                    Text("Open-Meteo（open-meteo.com）")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10))
                }
                .foregroundColor(accentColor)
            }

            Text("気象庁など各国の公的な気象機関のモデルを基にした無料の気象データAPIです。気圧・湿度・UV指数は当日の時間帯別データから算出しています。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if daysAhead >= 3 {
                Text("イベントまであと\(daysAhead)日のため、予報は今後変わる可能性があります。日が近づくにつれて精度が上がるため、当日が近づいたら再度ご確認ください。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("気圧・湿度は当日の時間帯別データの平均値です。実際の体感とは差が出ることがあります。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}
