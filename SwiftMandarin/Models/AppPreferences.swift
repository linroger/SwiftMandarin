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
    }

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
    }
}
