//
//  MiniMaxAudioModels.swift
//  SwiftMandarin
//
//  Stable settings, cache identity, and observable state for MiniMax speech.
//

import CryptoKit
import Foundation
import SwiftUI

nonisolated enum MiniMaxAPIRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case international
    case mainlandChina

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .international: return "International"
        case .mainlandChina: return "Mainland China"
        }
    }

    var baseURLString: String {
        switch self {
        case .international: return "https://api.minimax.io/v1"
        case .mainlandChina: return "https://api.minimaxi.com/v1"
        }
    }

    var t2aEndpoint: URL? {
        URL(string: baseURLString + "/t2a_v2")
    }
}

nonisolated struct MiniMaxSpeechConfiguration: Hashable, Sendable {
    static let defaultModel = "speech-2.8-turbo"
    static let defaultChineseVoice = "Chinese (Mandarin)_News_Anchor"
    static let defaultEnglishVoice = "English_Graceful_Lady"

    let region: MiniMaxAPIRegion
    let model: String
    let voiceID: String
    let speed: Double
    let volume: Double
    let pitch: Int
    let sampleRate: Int
    let bitrate: Int
    let format: String
    let channelCount: Int

    init(
        region: MiniMaxAPIRegion,
        model: String,
        voiceID: String,
        speed: Double,
        volume: Double = 1,
        pitch: Int = 0,
        sampleRate: Int = 32_000,
        bitrate: Int = 128_000,
        format: String = "mp3",
        channelCount: Int = 1
    ) {
        self.region = region
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.voiceID = voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speed = speed
        self.volume = volume
        self.pitch = pitch
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.format = format.lowercased()
        self.channelCount = channelCount
    }
}

extension AppPreferences {
    /// Captures one immutable settings snapshot before work moves off the main
    /// actor. A slow learner replay remains within MiniMax's supported range.
    func miniMaxSpeechConfiguration(
        languageCode: String,
        speedScale: Double = 1
    ) -> MiniMaxSpeechConfiguration {
        let isChinese = languageCode.lowercased().hasPrefix("zh")
        let speed = min(max(aiAudioSpeed * speedScale, Self.aiAudioSpeedRange.lowerBound),
                        Self.aiAudioSpeedRange.upperBound)
        return MiniMaxSpeechConfiguration(
            region: aiAudioRegion,
            model: aiAudioModel,
            voiceID: isChinese ? aiAudioChineseVoice : aiAudioEnglishVoice,
            speed: speed
        )
    }
}

nonisolated struct MiniMaxSpeechCacheIdentity: Hashable, Sendable {
    static let schemaVersion = 1

    let cacheKey: String
    let normalizedText: String
    let languageCode: String
    let configuration: MiniMaxSpeechConfiguration

    init(text: String, languageCode: String, configuration: MiniMaxSpeechConfiguration) {
        let normalizedText = Self.normalize(text)
        let normalizedLanguage = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        self.normalizedText = normalizedText
        self.languageCode = normalizedLanguage
        self.configuration = configuration

        // A length-prefixed canonical representation prevents delimiter
        // ambiguity. Fixed-width decimal rendering keeps the digest stable
        // across locales, launches, and platforms.
        let fields = [
            String(Self.schemaVersion),
            normalizedText,
            normalizedLanguage,
            configuration.region.rawValue,
            configuration.model,
            configuration.voiceID,
            Self.fixed(configuration.speed),
            Self.fixed(configuration.volume),
            String(configuration.pitch),
            String(configuration.sampleRate),
            String(configuration.bitrate),
            configuration.format,
            String(configuration.channelCount),
        ]
        let canonical = fields.map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        self.cacheKey = digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fixed(_ value: Double) -> String {
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

nonisolated struct GeneratedSpeechRecord: Codable, Hashable, Identifiable, Sendable {
    var id: String { cacheKey }

    let cacheKey: String
    let text: String
    let languageCode: String
    let model: String
    let voiceID: String
    let region: MiniMaxAPIRegion
    let createdAt: Date
    let durationMilliseconds: Int?
    let byteCount: Int
    let fileName: String
    let sampleRate: Int
    let bitrate: Int
    let format: String
}

nonisolated struct CachedGeneratedSpeech: Sendable {
    let record: GeneratedSpeechRecord
    let fileURL: URL
    let wasCached: Bool
}

nonisolated enum AIAudioPhase: String, Sendable {
    case idle
    case generating
    case cacheHit
    case playing
    case localFallback
    case failed
}

@Observable
@MainActor
final class AIAudioRuntimeState {
    static let shared = AIAudioRuntimeState()

    private(set) var phase: AIAudioPhase = .idle
    private(set) var message: String?
    private(set) var currentRecordID: String?
    private(set) var lastPlaybackUsedCache = false
    private(set) var noticeMessage: String?
    private(set) var noticeIsError = false

    var isBusy: Bool { phase == .generating || phase == .playing || phase == .cacheHit }

    func update(
        phase: AIAudioPhase,
        message: String? = nil,
        currentRecordID: String? = nil,
        usedCache: Bool = false
    ) {
        self.phase = phase
        self.message = message
        self.currentRecordID = currentRecordID
        self.lastPlaybackUsedCache = usedCache
    }

    func publishNotice(_ message: String, isError: Bool) {
        noticeMessage = message
        noticeIsError = isError
    }

    func clearNotice() {
        noticeMessage = nil
        noticeIsError = false
    }

    func dismissNotice() {
        clearNotice()
    }

    private init() {}
}
