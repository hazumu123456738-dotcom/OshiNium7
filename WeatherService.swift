//
//  WeatherService.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/07/29.
//

import Foundation
import CoreLocation

// ★ Open-Meteo（https://open-meteo.com）。APIキー不要・無料の天気予報API。
//   予報は当日から概ね16日先まで対応（それ以降は取得できない）。

struct DailyWeather {
    let maxTemp: Double
    let minTemp: Double
    let weatherCode: Int
    let precipitationProbability: Int?
    /// 当日の平均気圧（hPa）。低気圧による頭痛・体調不良への配慮に使う
    let averagePressure: Double?
    /// 当日の平均湿度（%）。髪の広がり・乾燥への配慮に使う
    let averageHumidity: Double?
    /// 当日のUV指数の最大値。日焼け止め・日陰確保の目安に使う
    let uvIndexMax: Double?
    /// 当日の日照時間（時間）。屋外待機・遠征の服装選びの目安に使う
    let sunshineDurationHours: Double?
    /// 0時始まりの1時間ごとのUV指数（24件）。「何時〜何時に日焼け止めが必要か」の算出に使う
    let hourlyUVIndex: [Double]?
    /// 0時始まりの1時間ごとの降水確率（24件・%）。「何時〜何時に傘が要るか」の算出に使う
    let hourlyPrecipitationProbability: [Int]?
    /// 0時始まりの1時間ごとの気温（24件・℃）。天気詳細シートの気温グラフに使う
    let hourlyTemperature: [Double]?

    var symbolName: String { WeatherCodeMapper.symbol(for: weatherCode) }
    var description: String { WeatherCodeMapper.description(for: weatherCode) }

    // ★ 気圧の低下による頭痛・だるさなど、いわゆる「気象病」への配慮メッセージ
    //   （前日比までは取得していないため、絶対値ベースのおおまかな目安）
    var pressureAdvisory: String? {
        guard let averagePressure else { return nil }
        if averagePressure < 1000 {
            return "気圧がかなり低めです。頭痛・めまいなど体調の変化に注意しましょう"
        } else if averagePressure < 1008 {
            return "気圧がやや低めです。頭痛持ちの方は体調の変化に注意しましょう"
        }
        return nil
    }

    // ★ 湿度による髪・肌への影響についての配慮メッセージ
    var humidityAdvisory: String? {
        guard let averageHumidity else { return nil }
        if averageHumidity >= 75 {
            return "湿度が高めです。髪の広がり・うねりが出やすい日です"
        } else if averageHumidity <= 30 {
            return "空気が乾燥しています。髪や肌のパサつきに注意しましょう"
        }
        return nil
    }

    // ★ UV指数の目安（数値だけでは高いか低いか伝わらないため、段階を言葉で添える）
    var uvLevelLabel: String? {
        guard let uvIndexMax else { return nil }
        switch uvIndexMax {
        case ..<3: return "低い"
        case 3..<6: return "中程度"
        case 6..<8: return "高い"
        case 8..<11: return "非常に高い"
        default: return "極端に高い"
        }
    }

    // ★ 「屋外で列に並ぶ・遠征する」推し活シーンを想定し、UV指数3以上（中程度以上）になる
    //   時間帯を「日焼け止めが必要な時間」として一つの時間範囲にまとめて伝える
    var sunscreenAdvisory: String? {
        guard let uvIndexMax, uvIndexMax >= 3, let hourlyUVIndex, !hourlyUVIndex.isEmpty else { return nil }
        let riskyHours = hourlyUVIndex.enumerated().filter { $0.element >= 3 }.map { $0.offset }
        guard let first = riskyHours.first, let last = riskyHours.last else { return nil }
        let levelText = uvLevelLabel.map { "UV指数が\($0)（最大\(Int(uvIndexMax.rounded()))）" } ?? "UV指数が高め"
        return "\(levelText)になる日です。\(first)時〜\(last + 1)時は日焼け止めを塗り、こまめに塗り直しましょう"
    }

    // ★ 日照時間そのものも「長いか短いか」だけでは伝わらないため、屋外待機の観点で言い添える
    var sunshineAdvisory: String? {
        guard let sunshineDurationHours else { return nil }
        if sunshineDurationHours >= 8 {
            return "日照時間は\(String(format: "%.1f", sunshineDurationHours))時間と長めです。屋外で並ぶ時間が長い遠征では、帽子や日傘があると安心です"
        } else if sunshineDurationHours <= 3 {
            return "日照時間は\(String(format: "%.1f", sunshineDurationHours))時間と短めです。曇りがちで肌寒く感じやすいので、羽織るものがあると安心です"
        }
        return nil
    }

    // ★ 降水確率のピークだけを見せる（1日中の平均ではなく「何時が危ないか」が推し活では重要）。
    //   50%以上になる時間帯がある場合だけ、傘を持ち歩くべき時間として一つの範囲にまとめる
    var rainAdvisory: String? {
        guard let hourlyPrecipitationProbability, !hourlyPrecipitationProbability.isEmpty else { return nil }
        let rainyHours = hourlyPrecipitationProbability.enumerated().filter { $0.element >= 50 }
        guard let first = rainyHours.first?.offset, let last = rainyHours.last?.offset else { return nil }
        let peak = rainyHours.map(\.element).max() ?? 0
        return "\(first)時〜\(last + 1)時は雨の確率が\(peak)%と高めです。傘を持ち歩くことをおすすめします"
    }
}

enum WeatherCodeMapper {
    // WMO Weather interpretation codes（Open-Meteoが準拠）
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "快晴"
        case 1: return "ほぼ晴れ"
        case 2: return "晴れ時々くもり"
        case 3: return "くもり"
        case 45, 48: return "霧"
        case 51, 53, 55: return "小雨"
        case 56, 57: return "着氷性の霧雨"
        case 61, 63, 65: return "雨"
        case 66, 67: return "着氷性の雨"
        case 71, 73, 75, 77: return "雪"
        case 80, 81, 82: return "にわか雨"
        case 85, 86: return "にわか雪"
        case 95: return "雷雨"
        case 96, 99: return "雷雨（ひょう）"
        default: return "不明"
        }
    }
}

enum WeatherService {
    static func fetchDailyForecast(coordinate: CLLocationCoordinate2D, date: Date) async -> DailyWeather? {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)

        guard let daysAhead = calendar.dateComponents([.day], from: today, to: targetDay).day,
              daysAhead >= 0, daysAhead <= 15 else {
            // Open-Meteoの無料予報範囲（当日〜16日先）の対象外
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")

        let dateString = formatter.string(from: date)

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            // ★ uv_index_max・sunshine_duration（UV指数・日照時間）を追加
            URLQueryItem(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,sunshine_duration"),
            // ★ 気圧・湿度に加え、「何時に日焼け止め／傘が要るか」を出すためuv_index・
            //   precipitation_probability、時間ごとの気温グラフ用にtemperature_2mも時間別で取得する
            URLQueryItem(name: "hourly", value: "surface_pressure,relative_humidity_2m,uv_index,precipitation_probability,temperature_2m"),
            URLQueryItem(name: "timezone", value: "Asia/Tokyo"),
            URLQueryItem(name: "start_date", value: dateString),
            URLQueryItem(name: "end_date", value: dateString)
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            guard let code = decoded.daily.weathercode.first,
                  let maxT = decoded.daily.temperature_2m_max.first,
                  let minT = decoded.daily.temperature_2m_min.first else {
                return nil
            }

            let pressures = decoded.hourly?.surface_pressure ?? []
            let avgPressure = pressures.isEmpty ? nil : pressures.reduce(0, +) / Double(pressures.count)

            let humidities = decoded.hourly?.relative_humidity_2m ?? []
            let avgHumidity = humidities.isEmpty ? nil : Double(humidities.reduce(0, +)) / Double(humidities.count)

            let sunshineSeconds = decoded.daily.sunshine_duration?.first

            return DailyWeather(
                maxTemp: maxT,
                minTemp: minT,
                weatherCode: code,
                precipitationProbability: decoded.daily.precipitation_probability_max?.first,
                averagePressure: avgPressure,
                averageHumidity: avgHumidity,
                uvIndexMax: decoded.daily.uv_index_max?.first,
                sunshineDurationHours: sunshineSeconds.map { $0 / 3600 },
                hourlyUVIndex: decoded.hourly?.uv_index,
                hourlyPrecipitationProbability: decoded.hourly?.precipitation_probability,
                hourlyTemperature: decoded.hourly?.temperature_2m
            )
        } catch {
            print("🔥 WeatherService fetch error:", error)
            return nil
        }
    }

    private struct OpenMeteoResponse: Decodable {
        struct Daily: Decodable {
            let weathercode: [Int]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_probability_max: [Int]?
            let uv_index_max: [Double]?
            /// 秒単位で返る（時間に変換して使う）
            let sunshine_duration: [Double]?
        }
        struct Hourly: Decodable {
            let surface_pressure: [Double]?
            let relative_humidity_2m: [Int]?
            let uv_index: [Double]?
            let precipitation_probability: [Int]?
            let temperature_2m: [Double]?
        }
        let daily: Daily
        let hourly: Hourly?
    }
}
