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
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .lexicalClass,
                            options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range])
            let partOfSpeech = tag.map { PartOfSpeech(from: $0) } ?? .unknown
            
            // Skip punctuation that may slip through (check if word is only punctuation/symbols)
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters.union(.symbols).union(.whitespaces))
            guard !trimmed.isEmpty else { return true }
            
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
        default: self = .unknown
        }
    }
    
    var displayName: String {
        rawValue.capitalized
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
        case .unknown: return .secondary
        }
    }
}

enum DetectedLanguage: Equatable {
    case chinese
    case english
    case other(String)
    case unknown
    
    var isChinese: Bool { self == .chinese }
    var isEnglish: Bool { self == .english }
}

// MARK: - Character Extension

extension Character {
    var isChineseCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        // CJK Unified Ideographs and Extension A
        return (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||
               (0x20000...0x2A6DF).contains(scalar.value)
    }
}
