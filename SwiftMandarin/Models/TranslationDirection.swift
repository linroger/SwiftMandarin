//
//  TranslationDirection.swift
//  SwiftMandarin
//
//  Translation direction enum for English ↔ Chinese
//

import Foundation
import SwiftUI

enum TranslationDirection: String, CaseIterable, Identifiable, Codable {
    case englishToChinese
    case chineseToEnglish
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .englishToChinese: return "EN → 中"
        case .chineseToEnglish: return "中 → EN"
        }
    }
    
    var sourceLabel: String {
        switch self {
        case .englishToChinese: return "English"
        case .chineseToEnglish: return "中文"
        }
    }
    
    var targetLabel: String {
        switch self {
        case .englishToChinese: return "中文"
        case .chineseToEnglish: return "English"
        }
    }
    
    /// Input placeholder, resolved through the string catalog so it follows
    /// the in-app language toggle (e.g. 中文 UI shows 输入英文…/输入中文…).
    var placeholder: String {
        switch self {
        case .englishToChinese: return String(localized: "Enter English text...", bundle: .appLanguage)
        case .chineseToEnglish: return String(localized: "输入中文...", bundle: .appLanguage)
        }
    }
    
    var sourceLanguage: Locale.Language {
        switch self {
        case .englishToChinese: return Locale.Language(identifier: "en")
        case .chineseToEnglish: return Locale.Language(identifier: "zh-Hans")
        }
    }
    
    var targetLanguage: Locale.Language {
        switch self {
        case .englishToChinese: return Locale.Language(identifier: "zh-Hans")
        case .chineseToEnglish: return Locale.Language(identifier: "en")
        }
    }
    
    var sourceSpeechCode: String {
        switch self {
        case .englishToChinese: return "en-US"
        case .chineseToEnglish: return "zh-CN"
        }
    }
    
    var targetSpeechCode: String {
        switch self {
        case .englishToChinese: return "zh-CN"
        case .chineseToEnglish: return "en-US"
        }
    }
    
    var opposite: TranslationDirection {
        self == .englishToChinese ? .chineseToEnglish : .englishToChinese
    }
    
    /// Localized language names (resolve through the string catalog so the
    /// section headers built from them follow the in-app language toggle).
    var sourceLanguageName: String {
        switch self {
        case .englishToChinese: return String(localized: "English", bundle: .appLanguage)
        case .chineseToEnglish: return String(localized: "Chinese", bundle: .appLanguage)
        }
    }

    var targetLanguageName: String {
        switch self {
        case .englishToChinese: return String(localized: "Chinese", bundle: .appLanguage)
        case .chineseToEnglish: return String(localized: "English", bundle: .appLanguage)
        }
    }
    
    func toggled() -> TranslationDirection {
        opposite
    }

    /// The direction to start on when the user has expressed no preference.
    ///
    /// Every screen that reads the shared `defaultDirection` preference needs
    /// a fall-back for the moment before it is written. Hard-coding
    /// `.englishToChinese` there quietly made English-speaker orientation the
    /// app's universal default, so a Mandarin speaker learning English opened
    /// Translate pointing the wrong way. Deriving it from the persisted
    /// interface language — which is the user's native language — gives each
    /// audience the direction they actually want. Nonisolated so it can serve
    /// as an `@AppStorage` default and be read from a nonisolated `init`.
    static var persistedDefault: TranslationDirection {
        AppLanguage.persisted == .chinese ? .chineseToEnglish : .englishToChinese
    }
}
