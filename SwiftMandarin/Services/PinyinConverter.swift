//
//  PinyinConverter.swift
//  SwiftMandarin
//
//  Converts Chinese text to Pinyin with tone marks and colors
//

import Foundation
import SwiftUI

enum PinyinConverter {
    
    // MARK: - Basic Conversion
    
    static func convert(_ text: String, includeToneMarks: Bool = true) -> String {
        guard !text.isEmpty else { return "" }
        // Pinyin only applies to Chinese. For non-CJK input (e.g. an English
        // vocabulary term saved from workbook grading) return empty rather
        // than echoing the input back as a fake "pinyin" reading.
        guard text.contains(where: { $0.isChineseCharacter }) else { return "" }
        let transformed = text.applyingTransform(.mandarinToLatin, reverse: false) ?? text
        guard !includeToneMarks else { return transformed }
        return transformed.applyingTransform(.stripDiacritics, reverse: false) ?? transformed
    }
    
    // MARK: - Tone Detection
    
    enum Tone: Int, CaseIterable {
        case first = 1   // High level: ā, ē, ī, ō, ū, ǖ
        case second = 2  // Rising: á, é, í, ó, ú, ǘ
        case third = 3   // Dipping: ǎ, ě, ǐ, ǒ, ǔ, ǚ
        case fourth = 4  // Falling: à, è, ì, ò, ù, ǜ
        case neutral = 5 // Neutral tone
        
        var color: Color {
            switch self {
            case .first: return Color(red: 0.9, green: 0.2, blue: 0.2)   // Red
            case .second: return Color(red: 0.9, green: 0.6, blue: 0.1)  // Orange
            case .third: return Color(red: 0.2, green: 0.7, blue: 0.3)   // Green
            case .fourth: return Color(red: 0.2, green: 0.5, blue: 0.9)  // Blue
            case .neutral: return Color.secondary                         // Gray
            }
        }
        
        var displayName: String {
            switch self {
            case .first: return "1st (High)"
            case .second: return "2nd (Rising)"
            case .third: return "3rd (Dipping)"
            case .fourth: return "4th (Falling)"
            case .neutral: return "Neutral"
            }
        }
    }
    
    private static let firstToneChars: Set<Character> = ["ā", "ē", "ī", "ō", "ū", "ǖ", "Ā", "Ē", "Ī", "Ō", "Ū", "Ǖ"]
    private static let secondToneChars: Set<Character> = ["á", "é", "í", "ó", "ú", "ǘ", "Á", "É", "Í", "Ó", "Ú", "Ǘ"]
    private static let thirdToneChars: Set<Character> = ["ǎ", "ě", "ǐ", "ǒ", "ǔ", "ǚ", "Ǎ", "Ě", "Ǐ", "Ǒ", "Ǔ", "Ǚ"]
    private static let fourthToneChars: Set<Character> = ["à", "è", "ì", "ò", "ù", "ǜ", "À", "È", "Ì", "Ò", "Ù", "Ǜ"]
    
    static func detectTone(_ pinyin: String) -> Tone {
        for char in pinyin {
            if firstToneChars.contains(char) { return .first }
            if secondToneChars.contains(char) { return .second }
            if thirdToneChars.contains(char) { return .third }
            if fourthToneChars.contains(char) { return .fourth }
        }
        return .neutral
    }
    
    static func toneColor(for pinyin: String) -> Color {
        detectTone(pinyin).color
    }
    
    // MARK: - Syllable Segmentation
    
    struct PinyinSyllable: Identifiable {
        let id = UUID()
        let text: String
        let tone: Tone
        
        var color: Color { tone.color }
    }
    
    static func segment(_ pinyin: String) -> [PinyinSyllable] {
        var syllables: [PinyinSyllable] = []
        var current = ""
        
        for char in pinyin {
            if char.isWhitespace || char == "'" {
                if !current.isEmpty {
                    syllables.append(PinyinSyllable(text: current, tone: detectTone(current)))
                    current = ""
                }
                if char.isWhitespace {
                    syllables.append(PinyinSyllable(text: String(char), tone: .neutral))
                }
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            syllables.append(PinyinSyllable(text: current, tone: detectTone(current)))
        }
        
        return syllables
    }
    
    // MARK: - Attributed String with Tone Colors
    
    static func coloredPinyin(_ text: String, includeToneMarks: Bool = true) -> AttributedString {
        let pinyin = convert(text, includeToneMarks: includeToneMarks)
        return coloredPinyin(fromPinyin: pinyin)
    }

    static func coloredPinyin(fromPinyin pinyin: String) -> AttributedString {
        let syllables = segment(pinyin)
        
        var attributed = AttributedString()
        
        for syllable in syllables {
            var syllableStr = AttributedString(syllable.text)
            if !syllable.text.trimmingCharacters(in: .whitespaces).isEmpty {
                syllableStr.foregroundColor = syllable.color
            }
            attributed.append(syllableStr)
        }
        
        return attributed
    }

    static func coloredPinyin(preferred preferredPinyin: String?, fallbackText text: String, includeToneMarks: Bool = true) -> AttributedString {
        let trimmedPinyin = preferredPinyin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedPinyin.isEmpty {
            return coloredPinyin(text, includeToneMarks: includeToneMarks)
        }
        return coloredPinyin(fromPinyin: trimmedPinyin)
    }
}

// MARK: - Color Extension for Tone Colors

extension Color {
    static let tone1 = PinyinConverter.Tone.first.color
    static let tone2 = PinyinConverter.Tone.second.color
    static let tone3 = PinyinConverter.Tone.third.color
    static let tone4 = PinyinConverter.Tone.fourth.color
    static let tone5 = PinyinConverter.Tone.neutral.color
}
