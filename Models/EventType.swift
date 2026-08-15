//
//  EventType.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/01.
//

import Foundation
import SwiftUI

// MARK: - 大分類
enum EventType: String, Codable, CaseIterable {
    case live
    case tv
    case event
    case release
    case sns
    case anniversary
    case other

    // MARK: - 表示名（UI用）
    var displayName: String {
        switch self {
        case .live: return "ライブ"
        case .tv: return "テレビ"
        case .event: return "イベント"
        case .release: return "リリース"
        case .sns: return "SNS"
        case .anniversary: return "記念日"
        case .other: return "その他"
        }
    }

    // MARK: - 絵文字
    var emoji: String {
        switch self {
        case .live: return "🎤"
        case .tv: return "📺"
        case .event: return "🎪"
        case .release: return "💿"
        case .sns: return "📱"
        case .anniversary: return "🎉"
        case .other: return "⭐️"
        }
    }

    // MARK: - アイコン
    var iconName: String {
        switch self {
        case .live: return "music.mic"
        case .tv: return "tv"
        case .event: return "person.2"
        case .release: return "music.note"
        case .sns: return "play.circle"
        case .anniversary: return "heart.fill"
        case .other: return "circle.fill"
        }
    }

    // MARK: - アイコンカラー
    // ★ 2026/08/16修正：色の割り当て（赤=ライブ/イベント、緑=テレビ、青=リリース、
    //   オレンジ=SNS、紫=記念日、グレー=その他）という「種族」そのものは元のまま維持しつつ、
    //   トーンだけをオリジナルタブ「ツール」セクション（EventHubPickerView.toolItems）と
    //   同じ柔らかい色味に合わせる。ツールに無い赤・グレーは、ツール内の実在する色
    //   （今日の推し活占いグラデーションの終点の珊瑚色、ツール全体のソフトな彩度感）に
    //   合わせて同じ系統で作った
    var iconColor: Color {
        switch self {
        case .live, .event: return Color(red: 0.98, green: 0.38, blue: 0.42)
        case .tv: return Color(red: 0.28, green: 0.82, blue: 0.52)
        case .release: return Color(red: 0.22, green: 0.52, blue: 0.98)
        case .sns: return Color(red: 0.98, green: 0.66, blue: 0.18)
        case .anniversary: return Color(red: 0.62, green: 0.40, blue: 0.98)
        case .other: return Color(red: 0.68, green: 0.68, blue: 0.74)
        }
    }

    // MARK: - UIKitカラー（iconColorと同じ色味をUIColorでも使えるようにする）
    var color: UIColor {
        switch self {
        case .live, .event: return UIColor(red: 0.98, green: 0.38, blue: 0.42, alpha: 1.0)
        case .tv: return UIColor(red: 0.28, green: 0.82, blue: 0.52, alpha: 1.0)
        case .release: return UIColor(red: 0.22, green: 0.52, blue: 0.98, alpha: 1.0)
        case .sns: return UIColor(red: 0.98, green: 0.66, blue: 0.18, alpha: 1.0)
        case .anniversary: return UIColor(red: 0.62, green: 0.40, blue: 0.98, alpha: 1.0)
        case .other: return UIColor(red: 0.68, green: 0.68, blue: 0.74, alpha: 1.0)
        }
    }

    // MARK: - 小分類（完全拡張版 + .other 復活）
    func subTypes() -> [EventSubType] {
        switch self {

        case .live:
            return [
                .oneman, .festival, .freeLive, .streamingLive,
                .tourLive, .showcase, .publicRecording, .fanMeetingLive,
                .collabLive, .schoolFestivalLive, .overseasLive,
                .hostedEventLive, .releaseEventLive, .birthdayLive, .guestStage
            ]

        case .tv:
            return [
                .musicShow, .variety, .drama, .special,
                .liveBroadcast, .infoShow, .newsShow,
                .documentary, .radioAppearance
            ]

        case .event:
            return [
                .handshake, .sign, .tokuten, .meetAndGreet, .onlinetalk,
                .talkShow, .fanMeetingEvent, .releaseEvent, .photoSession,
                .publicEventRecording, .collabEvent, .storeEvent,
                .schoolFestivalEvent, .offlineEvent, .fanExchange
            ]

        case .release:
            return [
                .cdRelease, .mvRelease, .magazine, .digitalRelease,
                .goodsRelease, .albumRelease, .epRelease, .singleRelease,
                .collabRelease, .teaserRelease, .jacketReveal
            ]

        case .sns:
            return [
                .instagram, .youtube, .tiktok, .space,
                .storyPost, .xPost, .reelPost, .shortVideo,
                .snsCampaign, .snsNotice, .snsCollab
            ]

        case .anniversary:
            return [
                .birthday, .seitansai, .debutDay, .formationDay,
                .anniversaryEvent, .graduationAnniversary, .joinAnniversary
            ]

        case .other:
            return [
                .other,              // ← inferType() が使う
                .unknown,
                .outOfCategory,
                .specialEvent,
                .privateEvent,
                .surprise,
                .unclassified
            ]
        }
    }
}

// MARK: - 小分類（完全拡張版 + .other 復活）
enum EventSubType: String, Codable, CaseIterable {

    // LIVE
    case oneman, festival, freeLive, streamingLive
    case tourLive, showcase, publicRecording, fanMeetingLive
    case collabLive, schoolFestivalLive, overseasLive
    case hostedEventLive, releaseEventLive, birthdayLive, guestStage

    // TV
    case musicShow, variety, drama, special
    case liveBroadcast, infoShow, newsShow
    case documentary, radioAppearance

    // EVENT
    case handshake, sign, tokuten, meetAndGreet, onlinetalk
    case talkShow, fanMeetingEvent, releaseEvent
    case photoSession, publicEventRecording, collabEvent
    case storeEvent, schoolFestivalEvent, offlineEvent, fanExchange

    // RELEASE
    case cdRelease, mvRelease, magazine
    case digitalRelease, goodsRelease, albumRelease
    case epRelease, singleRelease, collabRelease
    case teaserRelease, jacketReveal

    // SNS
    case instagram, youtube, tiktok, space
    case storyPost, xPost, reelPost, shortVideo
    case snsCampaign, snsNotice, snsCollab

    // ANNIVERSARY
    case birthday, seitansai, debutDay, formationDay
    case anniversaryEvent, graduationAnniversary, joinAnniversary

    // OTHER（← .other を復活）
    case other
    case unknown, outOfCategory, specialEvent
    case privateEvent, surprise, unclassified

    // MARK: - 表示名
    var displayName: String {
        switch self {

        // LIVE
        case .oneman: return "ワンマン"
        case .festival: return "フェス"
        case .freeLive: return "無料ライブ"
        case .streamingLive: return "配信ライブ"
        case .tourLive: return "ツアーライブ"
        case .showcase: return "ショーケース"
        case .publicRecording: return "公開収録"
        case .fanMeetingLive: return "ファンミーティング"
        case .collabLive: return "コラボライブ"
        case .schoolFestivalLive: return "学園祭ライブ"
        case .overseasLive: return "海外公演"
        case .hostedEventLive: return "主催イベント"
        case .releaseEventLive: return "リリースイベント"
        case .birthdayLive: return "バースデーライブ"
        case .guestStage: return "ゲスト出演"

        // TV
        case .musicShow: return "音楽番組"
        case .variety: return "バラエティ"
        case .drama: return "ドラマ"
        case .special: return "特番"
        case .liveBroadcast: return "生放送"
        case .infoShow: return "情報番組"
        case .newsShow: return "ニュース"
        case .documentary: return "ドキュメンタリー"
        case .radioAppearance: return "ラジオ出演"

        // EVENT
        case .handshake: return "握手会"
        case .sign: return "サイン会"
        case .tokuten: return "特典会"
        case .meetAndGreet: return "ミーグリ"
        case .onlinetalk: return "オンライン通話"
        case .talkShow: return "トークショー"
        case .fanMeetingEvent: return "ファンミーティング"
        case .releaseEvent: return "リリースイベント"
        case .photoSession: return "撮影会"
        case .publicEventRecording: return "公開収録"
        case .collabEvent: return "コラボイベント"
        case .storeEvent: return "店舗イベント"
        case .schoolFestivalEvent: return "学園祭出演"
        case .offlineEvent: return "オフ会"
        case .fanExchange: return "ファン交流会"

        // RELEASE
        case .cdRelease: return "CD発売"
        case .mvRelease: return "MV公開"
        case .magazine: return "雑誌発売"
        case .digitalRelease: return "デジタル配信"
        case .goodsRelease: return "グッズ発売"
        case .albumRelease: return "アルバム発売"
        case .epRelease: return "EP発売"
        case .singleRelease: return "シングル発売"
        case .collabRelease: return "コラボ曲リリース"
        case .teaserRelease: return "ティザー公開"
        case .jacketReveal: return "ジャケット公開"

        // SNS
        case .instagram: return "インスタライブ"
        case .youtube: return "YouTube配信"
        case .tiktok: return "TikTok投稿"
        case .space: return "スペース"
        case .storyPost: return "ストーリー投稿"
        case .xPost: return "X投稿"
        case .reelPost: return "リール投稿"
        case .shortVideo: return "ショート動画"
        case .snsCampaign: return "SNSキャンペーン"
        case .snsNotice: return "SNS告知"
        case .snsCollab: return "SNSコラボ投稿"

        // ANNIVERSARY
        case .birthday: return "誕生日"
        case .seitansai: return "生誕祭"
        case .debutDay: return "デビュー日"
        case .formationDay: return "結成日"
        case .anniversaryEvent: return "周年イベント"
        case .graduationAnniversary: return "卒業記念"
        case .joinAnniversary: return "加入記念"

        // OTHER
        case .other: return "その他"
        case .unknown: return "不明"
        case .outOfCategory: return "カテゴリ外"
        case .specialEvent: return "特殊イベント"
        case .privateEvent: return "プライベート"
        case .surprise: return "サプライズ"
        case .unclassified: return "未分類"
        }
    }
}
