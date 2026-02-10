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
    
    var placeholder: String {
        switch self {
        case .englishToChinese: return "Enter English text..."
        case .chineseToEnglish: return "输入中文..."
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
    
    var sourceLanguageName: String {
        switch self {
        case .englishToChinese: return "English"
        case .chineseToEnglish: return "Chinese"
        }
    }
    
    var targetLanguageName: String {
        switch self {
        case .englishToChinese: return "Chinese"
        case .chineseToEnglish: return "English"
        }
    }
    
    func toggled() -> TranslationDirection {
        opposite
    }
}
