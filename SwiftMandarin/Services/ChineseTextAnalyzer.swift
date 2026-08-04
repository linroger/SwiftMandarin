//
//  ChineseTextAnalyzer.swift
//  SwiftMandarin
//
//  Chinese text analysis using Apple's Natural Language framework
//

import Foundation
import NaturalLanguage
import SwiftUI

final class ChineseTextAnalyzer {
    
    static let shared = ChineseTextAnalyzer()
    private init() {}
    
    // MARK: - Word Segmentation
    
    func segmentWords(_ text: String) -> [SegmentedWord] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.simplifiedChinese)
        
        var words: [SegmentedWord] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            words.append(SegmentedWord(text: word, range: range))
            return true
        }
        
        return words
    }
    
    func segmentWithPartsOfSpeech(_ text: String) -> [AnalyzedWord] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.simplifiedChinese, range: text.startIndex..<text.endIndex)
        
        var words: [AnalyzedWord] = []
        
        // Don't omit punctuation - we want to preserve it in the output
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .lexicalClass,
                            options: [.omitWhitespace]) { tag, range in
            let word = String(text[range])
            let partOfSpeech = tag.map { PartOfSpeech(from: $0) } ?? .unknown
            
            // Include all tokens including punctuation
            words.append(AnalyzedWord(text: word, range: range, partOfSpeech: partOfSpeech))
            return true
        }
        
        return words
    }
    
    // MARK: - Language Detection

    func detectLanguage(_ text: String) -> DetectedLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else {
            return .unknown
        }

        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return .chinese
        case .english:
            return .english
        default:
            return .other(language.rawValue)
        }
    }

    /// Robust language detection that counts CJK ideographs first, falling back
    /// to `NLLanguageRecognizer` only when the script mix is ambiguous.
    ///
    /// This is the canonical detector used across the app. It fixes the photo
    /// pipeline's "stuck on English" symptom: even a handful of Chinese
    /// characters (which are information-dense) reliably route to Chinese,
    /// instead of `NLLanguageRecognizer` confidently misclassifying mixed or
    /// noisy OCR output as English.
    func detectLanguageRobust(_ text: String) -> DetectedLanguage {
        var cjk = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            if scalar.isCJKIdeograph {
                cjk += 1
            } else if (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value) {
                latin += 1
            }
        }

        // No Latin letters and no CJK — defer to NL for other scripts.
        if cjk == 0 && latin == 0 {
            return detectLanguage(text)
        }
        // Each Chinese character carries roughly a word of meaning, so weight
        // CJK heavily: presence of CJK at ~1 per 3 Latin letters → Chinese.
        if cjk > 0 && cjk * 3 >= latin {
            return .chinese
        }
        if latin > cjk * 3 {
            return .english
        }
        // Ambiguous middle ground — consult the statistical recognizer.
        return detectLanguage(text)
    }
    
    func detectLanguageWithConfidence(_ text: String) -> (language: DetectedLanguage, confidence: Double) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        
        guard let dominant = recognizer.dominantLanguage,
              let confidence = hypotheses[dominant] else {
            return (.unknown, 0.0)
        }
        
        let detectedLanguage: DetectedLanguage
        switch dominant {
        case .simplifiedChinese, .traditionalChinese:
            detectedLanguage = .chinese
        case .english:
            detectedLanguage = .english
        default:
            detectedLanguage = .other(dominant.rawValue)
        }
        
        return (detectedLanguage, confidence)
    }
}

// MARK: - Supporting Types

struct SegmentedWord: Identifiable {
    let id = UUID()
    let text: String
    let range: Range<String.Index>
}

struct AnalyzedWord: Identifiable {
    let id = UUID()
    let text: String
    let range: Range<String.Index>
    let partOfSpeech: PartOfSpeech
}

enum PartOfSpeech: String {
    case noun, verb, adjective, adverb, pronoun
    case preposition, conjunction, particle
    case number, classifier, interjection
    case punctuation
    case unknown
    
    init(from tag: NLTag) {
        switch tag {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        case .pronoun: self = .pronoun
        case .preposition: self = .preposition
        case .conjunction: self = .conjunction
        case .particle: self = .particle
        case .number: self = .number
        case .classifier: self = .classifier
        case .interjection: self = .interjection
        case .punctuation: self = .punctuation
        default: self = .unknown
        }
    }

    /// Map a free-form part-of-speech label from an AI provider (English or
    /// Chinese, e.g. "verb" or "动词") to the enum. Matches on substrings so
    /// minor wording differences ("proper noun", "measure word") still land on
    /// a sensible case; unrecognized labels become `.unknown`.
    init(aiLabel: String) {
        let s = aiLabel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { self = .unknown; return }
        switch true {
        case s.contains("noun"), s.contains("名词"), s.contains("名詞"):
            self = .noun
        case s.contains("verb"), s.contains("动词"), s.contains("動詞"):
            self = .verb
        case s.contains("adjective"), s.contains("形容词"), s.contains("形容詞"):
            self = .adjective
        case s.contains("adverb"), s.contains("副词"), s.contains("副詞"):
            self = .adverb
        case s.contains("pronoun"), s.contains("代词"), s.contains("代詞"):
            self = .pronoun
        case s.contains("preposition"), s.contains("介词"), s.contains("介詞"):
            self = .preposition
        case s.contains("conjunction"), s.contains("连词"), s.contains("連詞"):
            self = .conjunction
        case s.contains("particle"), s.contains("助词"), s.contains("助詞"), s.contains("语气"), s.contains("語氣"):
            self = .particle
        case s.contains("number"), s.contains("numeral"), s.contains("数词"), s.contains("數詞"):
            self = .number
        case s.contains("classifier"), s.contains("measure"), s.contains("量词"), s.contains("量詞"):
            self = .classifier
        case s.contains("interjection"), s.contains("exclamation"), s.contains("叹词"), s.contains("嘆詞"), s.contains("感叹"), s.contains("感嘆"):
            self = .interjection
        case s.contains("punctuation"), s.contains("标点"), s.contains("標點"):
            self = .punctuation
        default:
            self = .unknown
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Whether this part of speech represents punctuation
    var isPunctuation: Bool {
        self == .punctuation
    }
    
    var color: Color {
        switch self {
        case .noun: return .blue
        case .verb: return .red
        case .adjective: return .green
        case .adverb: return .orange
        case .pronoun: return .purple
        case .preposition: return .cyan
        case .conjunction: return .mint
        case .particle: return .gray
        case .number: return .indigo
        case .classifier: return .pink
        case .interjection: return .yellow
        case .punctuation: return .clear
        case .unknown: return .secondary
        }
    }
}

enum DetectedLanguage: Equatable, Sendable {
    case chinese
    case english
    case other(String)
    case unknown
    
    var isChinese: Bool { self == .chinese }
    var isEnglish: Bool { self == .english }
}

// MARK: - CJK Scalar / Character Extensions

extension Unicode.Scalar {
    /// Whether this scalar is a CJK (Han) ideograph across the common ranges.
    /// Pure Unicode math — explicitly `nonisolated` so it is callable from any
    /// context (this file defaults to `MainActor` isolation).
    nonisolated var isCJKIdeograph: Bool {
        (0x4E00...0x9FFF).contains(value) ||   // CJK Unified Ideographs
        (0x3400...0x4DBF).contains(value) ||   // CJK Extension A
        (0xF900...0xFAFF).contains(value) ||   // CJK Compatibility Ideographs
        (0x20000...0x2A6DF).contains(value) || // CJK Extension B
        (0x2A700...0x2EBEF).contains(value)    // CJK Extensions C–F
    }
}

extension Character {
    var isChineseCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.isCJKIdeograph
    }
}

extension String {
    /// Whether the string contains any CJK ideograph. Used to tell which side
    /// of a saved term / extracted pair is the Chinese one, since headword
    /// fields can hold either language depending on the learning direction.
    var containsCJK: Bool {
        unicodeScalars.contains { $0.isCJKIdeograph }
    }

    /// Whether this reading is an English IPA transcription rather than Hanyu
    /// pinyin.
    ///
    /// One stored field carries the reading for both directions, so a term
    /// saved while learning Mandarin holds pinyin ("xuéxí") and one saved
    /// while learning English holds IPA ("/ˈstʌdi/"). Tone-marked pinyin is
    /// plain Latin-with-diacritics, so it cannot be told apart by script
    /// alone — but every IPA reading the app requests is delimited by slashes
    /// (see `AIExplanationPromptBuilder`), and IPA additionally uses stress
    /// marks and phonetic letters that never appear in pinyin. Requiring one
    /// of those keeps a pinyin reading from being mislabeled when the learner
    /// switches direction.
    var looksLikeIPA: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.containsCJK else { return false }
        if trimmed.hasPrefix("/") && trimmed.hasSuffix("/") && trimmed.count > 2 { return true }
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && trimmed.count > 2 { return true }
        // Stress marks and phonetic letters with no pinyin counterpart.
        let ipaOnly: Set<Character> = [
            "ˈ", "ˌ", "ə", "ɪ", "ʊ", "ɛ", "æ", "ʌ", "ɔ", "ɑ", "ɒ", "ɜ", "ɝ", "ɚ",
            "ŋ", "ʃ", "ʒ", "θ", "ð", "ʧ", "ʤ", "ɹ", "ɡ", "ː"
        ]
        return trimmed.contains { ipaOnly.contains($0) }
    }
}
