//
//  AppPreferences.swift
//  SwiftMandarin
//
//  App-wide, cross-cutting user preferences that make the app bilingual:
//  - LearnerMode flips the app between English-centric and Mandarin-centric.
//  - PhotoScanLanguage controls OCR recognition language (fixes the
//    "stuck on English / can't read Mandarin" photo bug).
//  - dualNarration enables speaking both the word and its translation.
//

import Foundation
import SwiftUI

// MARK: - Learner Mode

/// Who the app is centered on. Drives default translation direction,
/// default OCR scan language, and which language is emphasized in narration.
enum LearnerMode: String, CaseIterable, Identifiable, Codable {
    /// English speaker learning Mandarin (the original app audience).
    case englishToMandarin
    /// Mandarin speaker learning English.
    case mandarinToEnglish
    /// Learning both languages at once.
    case bilingual

    var id: String { rawValue }

    /// Short label shown in the user's own language emphasis.
    var displayName: String {
        switch self {
        case .englishToMandarin: return "English speaker learning 中文"
        case .mandarinToEnglish: return "中文母语者学英语"
        case .bilingual: return "Bilingual · 双语学习"
        }
    }

    var shortLabel: String {
        switch self {
        case .englishToMandarin: return "EN → 中"
        case .mandarinToEnglish: return "中 → EN"
        case .bilingual: return "EN ⇄ 中"
        }
    }

    var iconName: String {
        switch self {
        case .englishToMandarin: return "character.book.closed"
        case .mandarinToEnglish: return "a.book.closed"
        case .bilingual: return "arrow.left.arrow.right.circle"
        }
    }

    var detail: String {
        switch self {
        case .englishToMandarin:
            return "Interface and defaults favor translating into Chinese; narration leads with Mandarin."
        case .mandarinToEnglish:
            return "界面与默认方向偏向译成英文；朗读以英文为主。"
        case .bilingual:
            return "Balanced defaults for studying both languages; both narrations are always offered."
        }
    }

    /// The default translation direction this mode implies.
    var defaultDirection: TranslationDirection {
        switch self {
        case .englishToMandarin, .bilingual: return .englishToChinese
        case .mandarinToEnglish: return .chineseToEnglish
        }
    }

    /// Whether this mode treats Mandarin as the language the user is learning
    /// (so explanations/definitions should be richer in Mandarin) vs. English.
    var learningLanguageIsChinese: Bool {
        switch self {
        case .englishToMandarin: return true
        case .mandarinToEnglish: return false
        case .bilingual: return true
        }
    }
}

// MARK: - Photo Scan Language

/// Controls the OCR recognition language for the photo / camera / screenshot
/// pipeline. This is the user-facing fix for "cannot switch languages".
enum PhotoScanLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case chinese
    case english
    case bilingual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动 · Auto"
        case .chinese: return "中文"
        case .english: return "English"
        case .bilingual: return "双语 · Both"
        }
    }

    var iconName: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .chinese: return "character.textbox"
        case .english: return "textformat.abc"
        case .bilingual: return "globe.asia.australia"
        }
    }

    /// Vision `recognitionLanguages`, ordered by priority. Chinese is listed
    /// first in mixed modes so Chinese glyphs are never mangled into Latin.
    var recognitionLanguages: [String] {
        switch self {
        case .auto, .bilingual: return ["zh-Hans", "zh-Hant", "en-US", "en-GB"]
        case .chinese: return ["zh-Hans", "zh-Hant"]
        case .english: return ["en-US", "en-GB"]
        }
    }

    /// Language correction is an English-language model that corrupts Chinese
    /// OCR output, so it is disabled when recognizing Chinese only.
    var usesLanguageCorrection: Bool {
        switch self {
        case .chinese: return false
        case .auto, .english, .bilingual: return true
        }
    }
}

// MARK: - App Preferences

/// Observable, app-wide preferences singleton (persisted to UserDefaults).
@Observable
@MainActor
final class AppPreferences {

    static let shared = AppPreferences()

    private enum Keys {
        static let learnerMode = "learner_mode"
        static let photoScanLanguage = "photo_scan_language"
        static let dualNarration = "dual_narration"
        static let ttsRate = "tts_rate"
        static let aiAudioEnabled = "ai_audio_enabled"
        static let aiAudioRegion = "ai_audio_region"
        static let aiAudioModel = "ai_audio_model"
        static let aiAudioChineseVoice = "ai_audio_chinese_voice"
        static let aiAudioEnglishVoice = "ai_audio_english_voice"
        static let aiAudioSpeed = "ai_audio_speed"
        static let aiAudioFallbackToSystemSpeech = "ai_audio_fallback_to_system_speech"
    }

    /// The allowed text-to-speech rate range. 0.5 is
    /// `AVSpeechUtteranceDefaultSpeechRate`; below ~0.35 speech sounds broken
    /// and above 0.6 it is too fast to shadow.
    static let ttsRateRange: ClosedRange<Double> = 0.35...0.6

    /// MiniMax accepts speech speeds from 0.5× through 2×.
    static let aiAudioSpeedRange: ClosedRange<Double> = 0.5...2.0

    /// The app's learner-centric mode. Changing it updates the default
    /// translation direction used across the app.
    var learnerMode: LearnerMode {
        didSet {
            guard oldValue != learnerMode else { return }
            UserDefaults.standard.set(learnerMode.rawValue, forKey: Keys.learnerMode)
            // Adapt the shared default translation direction so all features follow.
            UserDefaults.standard.set(learnerMode.defaultDirection.rawValue, forKey: "defaultDirection")
            // Bidirectional sync: a single-direction mode also re-orients the
            // interface (= native) language, so the many views that key off
            // `LocalizationManager.learningIsChinese` actually follow the picker
            // instead of diverging from it. `.bilingual` keeps whatever
            // interface language is currently active (treated explicitly).
            // `LocalizationManager.language`'s own `didSet` is guarded against
            // no-op assignments, so this cannot loop.
            switch learnerMode {
            case .englishToMandarin:
                LocalizationManager.shared.language = .english
            case .mandarinToEnglish:
                LocalizationManager.shared.language = .chinese
            case .bilingual:
                break
            }
        }
    }

    /// OCR recognition language preference for the photo pipeline.
    var photoScanLanguage: PhotoScanLanguage {
        didSet {
            UserDefaults.standard.set(photoScanLanguage.rawValue, forKey: Keys.photoScanLanguage)
        }
    }

    /// When enabled, word-detail views offer narration in BOTH languages.
    var dualNarration: Bool {
        didSet {
            UserDefaults.standard.set(dualNarration, forKey: Keys.dualNarration)
        }
    }

    /// Text-to-speech rate applied to every utterance (see `SpeechService`).
    /// Clamped to `ttsRateRange`; 0.5 matches the system default rate.
    var ttsRate: Double {
        didSet {
            let clamped = min(max(ttsRate, Self.ttsRateRange.lowerBound), Self.ttsRateRange.upperBound)
            if clamped != ttsRate {
                ttsRate = clamped  // re-enters didSet once with a valid value
                return
            }
            UserDefaults.standard.set(ttsRate, forKey: Keys.ttsRate)
        }
    }

    /// Routes read-aloud actions through MiniMax when a Keychain credential is
    /// available. This is deliberately opt-in because it sends the spoken text
    /// to a network service and may incur API usage charges.
    var aiAudioEnabled: Bool {
        didSet { UserDefaults.standard.set(aiAudioEnabled, forKey: Keys.aiAudioEnabled) }
    }

    /// Selects MiniMax's regional API host independently of the text-model
    /// provider configuration.
    var aiAudioRegion: MiniMaxAPIRegion {
        didSet { UserDefaults.standard.set(aiAudioRegion.rawValue, forKey: Keys.aiAudioRegion) }
    }

    /// T2A model identifier. Settings may expose this as editable so a newer
    /// compatible speech model can be adopted without an app release.
    var aiAudioModel: String {
        didSet {
            let trimmed = aiAudioModel.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != aiAudioModel {
                aiAudioModel = trimmed
                return
            }
            UserDefaults.standard.set(aiAudioModel, forKey: Keys.aiAudioModel)
        }
    }

    var aiAudioChineseVoice: String {
        didSet {
            let trimmed = aiAudioChineseVoice.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != aiAudioChineseVoice {
                aiAudioChineseVoice = trimmed
                return
            }
            UserDefaults.standard.set(aiAudioChineseVoice, forKey: Keys.aiAudioChineseVoice)
        }
    }

    var aiAudioEnglishVoice: String {
        didSet {
            let trimmed = aiAudioEnglishVoice.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != aiAudioEnglishVoice {
                aiAudioEnglishVoice = trimmed
                return
            }
            UserDefaults.standard.set(aiAudioEnglishVoice, forKey: Keys.aiAudioEnglishVoice)
        }
    }

    var aiAudioSpeed: Double {
        didSet {
            let clamped = min(max(aiAudioSpeed, Self.aiAudioSpeedRange.lowerBound),
                              Self.aiAudioSpeedRange.upperBound)
            if clamped != aiAudioSpeed {
                aiAudioSpeed = clamped
                return
            }
            UserDefaults.standard.set(aiAudioSpeed, forKey: Keys.aiAudioSpeed)
        }
    }

    /// Keeps read-aloud useful when the network, API key, or MiniMax service is
    /// unavailable. Users can disable this when they prefer failures to be
    /// explicit instead of switching voices.
    var aiAudioFallbackToSystemSpeech: Bool {
        didSet {
            UserDefaults.standard.set(aiAudioFallbackToSystemSpeech,
                                      forKey: Keys.aiAudioFallbackToSystemSpeech)
        }
    }

    /// Align the learner mode with the interface language (the interface
    /// language is the user's native language, so the learning direction
    /// follows from it). Called by `LocalizationManager` whenever the in-app
    /// language toggle changes, so one gesture re-orients the whole app.
    func syncLearnerMode(toInterfaceLanguage language: AppLanguage) {
        // Preserve an explicit bilingual choice: toggling the interface language
        // must not silently collapse `.bilingual` into a single direction.
        guard learnerMode != .bilingual else { return }
        let target: LearnerMode = (language == .chinese) ? .mandarinToEnglish : .englishToMandarin
        if learnerMode != target {
            learnerMode = target
        }
    }

    private init() {
        let savedMode = UserDefaults.standard.string(forKey: Keys.learnerMode)
        // First launch: derive the learning direction from the interface
        // language (中文 UI → native Mandarin speaker learning English).
        let derivedDefault: LearnerMode =
            LocalizationManager.shared.language == .chinese ? .mandarinToEnglish : .englishToMandarin
        self.learnerMode = savedMode.flatMap(LearnerMode.init(rawValue:)) ?? derivedDefault

        let savedScan = UserDefaults.standard.string(forKey: Keys.photoScanLanguage)
        self.photoScanLanguage = savedScan.flatMap(PhotoScanLanguage.init(rawValue:)) ?? .auto

        // Default ON: dual narration is purely additive and useful for both audiences.
        self.dualNarration = UserDefaults.standard.object(forKey: Keys.dualNarration) as? Bool ?? true

        // Speech rate: default matches AVSpeechUtteranceDefaultSpeechRate (0.5),
        // clamped in case a stale/out-of-range value was persisted.
        let savedRate = UserDefaults.standard.object(forKey: Keys.ttsRate) as? Double ?? 0.5
        self.ttsRate = min(max(savedRate, Self.ttsRateRange.lowerBound), Self.ttsRateRange.upperBound)

        self.aiAudioEnabled = UserDefaults.standard.object(forKey: Keys.aiAudioEnabled) as? Bool ?? false

        let savedRegion = UserDefaults.standard.string(forKey: Keys.aiAudioRegion)
        self.aiAudioRegion = savedRegion.flatMap(MiniMaxAPIRegion.init(rawValue:)) ?? .mainlandChina

        let savedModel = UserDefaults.standard.string(forKey: Keys.aiAudioModel)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.aiAudioModel = savedModel.flatMap { $0.isEmpty ? nil : $0 }
            ?? MiniMaxSpeechConfiguration.defaultModel

        let savedChineseVoice = UserDefaults.standard.string(forKey: Keys.aiAudioChineseVoice)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.aiAudioChineseVoice = savedChineseVoice.flatMap { $0.isEmpty ? nil : $0 }
            ?? MiniMaxSpeechConfiguration.defaultChineseVoice

        let savedEnglishVoice = UserDefaults.standard.string(forKey: Keys.aiAudioEnglishVoice)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.aiAudioEnglishVoice = savedEnglishVoice.flatMap { $0.isEmpty ? nil : $0 }
            ?? MiniMaxSpeechConfiguration.defaultEnglishVoice

        let savedAISpeed = UserDefaults.standard.object(forKey: Keys.aiAudioSpeed) as? Double ?? 1.0
        self.aiAudioSpeed = min(max(savedAISpeed, Self.aiAudioSpeedRange.lowerBound),
                                Self.aiAudioSpeedRange.upperBound)

        self.aiAudioFallbackToSystemSpeech =
            UserDefaults.standard.object(forKey: Keys.aiAudioFallbackToSystemSpeech) as? Bool ?? true
    }
}
