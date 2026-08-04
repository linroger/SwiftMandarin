//
//  EnglishTextAnalyzer.swift
//  SwiftMandarin
//
//  English text analysis using Apple's Natural Language framework
//  Provides word segmentation, part-of-speech tagging, and sentence analysis
//

import Foundation
import NaturalLanguage
import SwiftUI

// MARK: - English Part of Speech

enum EnglishPartOfSpeech: String, CaseIterable, Codable {
    case noun = "名词"
    case verb = "动词"
    case adjective = "形容词"
    case adverb = "副词"
    case pronoun = "代词"
    case preposition = "介词"
    case conjunction = "连词"
    case determiner = "限定词"
    case interjection = "感叹词"
    case number = "数词"
    case particle = "助词"
    case punctuation = "标点"
    case unknown = "其他"
    
    init(from tag: NLTag) {
        switch tag {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        case .pronoun: self = .pronoun
        case .preposition: self = .preposition
        case .conjunction: self = .conjunction
        case .determiner: self = .determiner
        case .interjection: self = .interjection
        case .number: self = .number
        case .particle: self = .particle
        case .punctuation: self = .punctuation
        default: self = .unknown
        }
    }
    
    /// The grammar term in English. Deliberately fixed rather than localized:
    /// the word-detail sheet shows it beside the Chinese `rawValue` so the pair
    /// reads "Noun 名词", which teaches the term to whichever audience does not
    /// already know it. It is also what gets written into `SavedTerm`.
    var englishName: String {
        switch self {
        case .noun: return "Noun"
        case .verb: return "Verb"
        case .adjective: return "Adjective"
        case .adverb: return "Adverb"
        case .pronoun: return "Pronoun"
        case .preposition: return "Preposition"
        case .conjunction: return "Conjunction"
        case .determiner: return "Determiner"
        case .interjection: return "Interjection"
        case .number: return "Number"
        case .particle: return "Particle"
        case .punctuation: return "Punctuation"
        case .unknown: return "Other"
        }
    }
    
    var abbreviation: String {
        switch self {
        case .noun: return "n."
        case .verb: return "v."
        case .adjective: return "adj."
        case .adverb: return "adv."
        case .pronoun: return "pron."
        case .preposition: return "prep."
        case .conjunction: return "conj."
        case .determiner: return "det."
        case .interjection: return "interj."
        case .number: return "num."
        case .particle: return "part."
        case .punctuation: return ""
        case .unknown: return ""
        }
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
        case .determiner: return .gray
        case .interjection: return .yellow
        case .number: return .indigo
        case .particle: return .pink
        case .punctuation: return .clear
        case .unknown: return .secondary
        }
    }
    
    /// Whether this part of speech represents punctuation
    var isPunctuation: Bool {
        self == .punctuation
    }
    
    /// Example words for this part of speech (for teaching)
    var examples: [String] {
        switch self {
        case .noun: return ["apple", "book", "cat", "dog", "school"]
        case .verb: return ["run", "eat", "play", "read", "write"]
        case .adjective: return ["big", "small", "happy", "sad", "beautiful"]
        case .adverb: return ["quickly", "slowly", "very", "always", "never"]
        case .pronoun: return ["I", "you", "he", "she", "it", "we", "they"]
        case .preposition: return ["in", "on", "at", "under", "behind"]
        case .conjunction: return ["and", "but", "or", "because", "so"]
        case .determiner: return ["the", "a", "an", "this", "that"]
        case .interjection: return ["oh", "wow", "oops", "hey", "hi"]
        case .number: return ["one", "two", "three", "first", "second"]
        case .particle: return ["not", "up", "down", "off", "away"]
        case .punctuation: return [".", ",", "!", "?", ";"]
        case .unknown: return []
        }
    }
}

// MARK: - Analyzed English Word

struct AnalyzedEnglishWord: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let lemma: String           // Base form of the word
    let partOfSpeech: EnglishPartOfSpeech
    var translation: String?    // Chinese translation (to be filled later)
    
    /// Whether this word is punctuation (should be displayed inline without styling)
    var isPunctuation: Bool {
        partOfSpeech.isPunctuation || 
        (!text.contains(where: { $0.isLetter || $0.isNumber }))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AnalyzedEnglishWord, rhs: AnalyzedEnglishWord) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sentence Type

enum SentenceType: String, CaseIterable {
    case declarative = "陈述句"
    case question = "疑问句"
    case exclamation = "感叹句"
    case imperative = "祈使句"
    case negative = "否定句"
    
    /// Localized sentence-type label — the property the UI should render.
    /// The raw value is Chinese and is the case's stable identifier, so it
    /// cannot be translated in place; rendering it leaves the badge on a
    /// sentence card reading 陈述句 to an English speaker. This mirror resolves
    /// the term through the string catalog so it follows the UI language.
    var displayName: String {
        switch self {
        case .declarative: return String(localized: "Declarative", bundle: .appLanguage)
        case .question: return String(localized: "Question", bundle: .appLanguage)
        case .exclamation: return String(localized: "Exclamation", bundle: .appLanguage)
        case .imperative: return String(localized: "Imperative", bundle: .appLanguage)
        case .negative: return String(localized: "Negative", bundle: .appLanguage)
        }
    }

    var englishName: String {
        switch self {
        case .declarative: return "Declarative"
        case .question: return "Question"
        case .exclamation: return "Exclamation"
        case .imperative: return "Imperative"
        case .negative: return "Negative"
        }
    }
    
    var icon: String {
        switch self {
        case .declarative: return "text.alignleft"
        case .question: return "questionmark.circle"
        case .exclamation: return "exclamationmark.circle"
        case .imperative: return "hand.point.right"
        case .negative: return "xmark.circle"
        }
    }
    
    var explanation: String {
        switch self {
        case .declarative: return "用于陈述事实或表达观点的句子"
        case .question: return "用于提问的句子，通常以问号结尾"
        case .exclamation: return "用于表达强烈情感的句子，以感叹号结尾"
        case .imperative: return "用于发出命令、请求或建议的句子"
        case .negative: return "包含否定词(not, no等)的句子"
        }
    }
}

// MARK: - Analyzed Sentence

struct AnalyzedSentence: Identifiable {
    let id = UUID()
    let text: String
    let type: SentenceType
    var words: [AnalyzedEnglishWord]
    var translation: String?    // Full sentence translation
    var grammarPoints: [String] // Grammar points identified
    
    init(text: String, type: SentenceType, words: [AnalyzedEnglishWord]) {
        self.text = text
        self.type = type
        self.words = words
        self.translation = nil
        self.grammarPoints = []
    }
}

// MARK: - English Text Analyzer

final class EnglishTextAnalyzer {
    
    static let shared = EnglishTextAnalyzer()
    private init() {}
    
    // MARK: - Word Analysis
    
    /// Analyze English text and return words with part-of-speech tags
    /// Preserves punctuation in the output for proper sentence display
    func analyzeWords(_ text: String) -> [AnalyzedEnglishWord] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        
        var words: [AnalyzedEnglishWord] = []
        
        // Don't omit punctuation - we want to preserve it in the output
        let options: NLTagger.Options = [.omitWhitespace]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, tokenRange in
            let word = String(text[tokenRange])
            
            // Get lemma (base form)
            let lemmaTag = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma)
            let lemma = lemmaTag.0?.rawValue ?? word.lowercased()
            
            // Get part of speech
            let partOfSpeech = tag.map { EnglishPartOfSpeech(from: $0) } ?? .unknown
            
            words.append(AnalyzedEnglishWord(
                text: word,
                lemma: lemma,
                partOfSpeech: partOfSpeech,
                translation: nil
            ))
            return true
        }
        
        return words
    }
    
    // MARK: - Sentence Analysis
    
    /// Analyze text and split into sentences with analysis
    func analyzeSentences(_ text: String) -> [AnalyzedSentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [AnalyzedSentence] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentenceText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !sentenceText.isEmpty else { return true }
            
            let type = detectSentenceType(sentenceText)
            let words = analyzeWords(sentenceText)
            
            var sentence = AnalyzedSentence(
                text: sentenceText,
                type: type,
                words: words
            )
            
            // Detect grammar points
            sentence.grammarPoints = detectGrammarPoints(in: sentenceText, words: words)
            
            sentences.append(sentence)
            return true
        }
        
        return sentences
    }
    
    // MARK: - Sentence Type Detection
    
    private func detectSentenceType(_ sentence: String) -> SentenceType {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        // Check punctuation first
        if trimmed.hasSuffix("?") {
            return .question
        } else if trimmed.hasSuffix("!") {
            return .exclamation
        }
        
        // Check for question words at the beginning
        let questionStarters = ["what", "where", "when", "why", "who", "how", "which", "whose",
                                "do ", "does ", "did ", "is ", "are ", "was ", "were ",
                                "can ", "could ", "will ", "would ", "shall ", "should ",
                                "have ", "has ", "had "]
        if questionStarters.contains(where: { lowercased.hasPrefix($0) }) {
            return .question
        }
        
        // Check for negative patterns
        let negativePatterns = ["don't", "doesn't", "didn't", "won't", "can't", "cannot",
                                "couldn't", "wouldn't", "shouldn't", "isn't", "aren't",
                                "wasn't", "weren't", "haven't", "hasn't", "hadn't",
                                " not ", " no ", "never", "nothing", "nobody", "nowhere"]
        if negativePatterns.contains(where: { lowercased.contains($0) }) {
            return .negative
        }
        
        // Check for imperative (starts with verb, no subject)
        let imperativeStarters = ["please", "let's", "let us", "do ", "don't"]
        if imperativeStarters.contains(where: { lowercased.hasPrefix($0) }) {
            return .imperative
        }
        
        // Check if starts with a verb (potential imperative)
        let words = analyzeWords(sentence)
        if let firstWord = words.first, firstWord.partOfSpeech == .verb {
            // Simple heuristic: if first word is verb and sentence is short
            if words.count <= 5 {
                return .imperative
            }
        }
        
        return .declarative
    }
    
    // MARK: - Grammar Point Detection
    
    /// Grammar point labels resolve through the string catalog so they follow
    /// the in-app language toggle (Chinese learners see 中文 explanations,
    /// English mode shows English ones).
    private func detectGrammarPoints(in sentence: String, words: [AnalyzedEnglishWord]) -> [String] {
        var points: [String] = []
        let lowercased = sentence.lowercased()

        // Detect tenses
        if lowercased.contains("ing") && (lowercased.contains("is ") || lowercased.contains("are ") || lowercased.contains("am ")) {
            points.append(String(localized: "Present continuous: be + verb-ing", bundle: .appLanguage))
        }

        if lowercased.contains("ed") || lowercased.contains("went") || lowercased.contains("was") || lowercased.contains("were") {
            points.append(String(localized: "Simple past: verb in past form", bundle: .appLanguage))
        }

        if lowercased.contains("will ") || lowercased.contains("going to") {
            points.append(String(localized: "Simple future: will / be going to + base verb", bundle: .appLanguage))
        }

        // Detect common structures
        if lowercased.contains("there is") || lowercased.contains("there are") {
            points.append(String(localized: "'There be' pattern: expresses existence", bundle: .appLanguage))
        }

        if lowercased.contains("have to") || lowercased.contains("has to") {
            points.append(String(localized: "have to: must, to be obliged to", bundle: .appLanguage))
        }

        if lowercased.contains("would like") || lowercased.contains("want to") {
            points.append(String(localized: "Expressing wants: would like to / want to", bundle: .appLanguage))
        }

        // Detect question patterns
        if lowercased.hasPrefix("what") {
            points.append(String(localized: "'What' question: asking about a thing", bundle: .appLanguage))
        } else if lowercased.hasPrefix("where") {
            points.append(String(localized: "'Where' question: asking about a place", bundle: .appLanguage))
        } else if lowercased.hasPrefix("when") {
            points.append(String(localized: "'When' question: asking about a time", bundle: .appLanguage))
        } else if lowercased.hasPrefix("how") {
            if lowercased.hasPrefix("how many") {
                points.append(String(localized: "How many: asking about countable quantity", bundle: .appLanguage))
            } else if lowercased.hasPrefix("how much") {
                points.append(String(localized: "How much: asking about uncountable quantity or price", bundle: .appLanguage))
            } else if lowercased.hasPrefix("how old") {
                points.append(String(localized: "How old: asking about age", bundle: .appLanguage))
            } else {
                points.append(String(localized: "'How' question: asking about manner", bundle: .appLanguage))
            }
        }

        // Detect comparatives and superlatives
        if lowercased.contains("er than") || lowercased.contains("more ") && lowercased.contains(" than") {
            points.append(String(localized: "Comparative: adjective + -er / more + adjective", bundle: .appLanguage))
        }

        if lowercased.contains("the most") || lowercased.contains("est ") {
            points.append(String(localized: "Superlative: the + adjective-est / the most + adjective", bundle: .appLanguage))
        }

        return points
    }
    
    // MARK: - Language Detection
    
    /// Detect if text is primarily English
    func isEnglish(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage == .english
    }
    
    /// Detect language with confidence
    func detectLanguage(_ text: String) -> (language: NLLanguage?, confidence: Double) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let dominant = recognizer.dominantLanguage,
              let confidence = hypotheses[dominant] else {
            return (nil, 0.0)
        }
        
        return (dominant, confidence)
    }
    
    // MARK: - Unique Words
    
    /// Extract unique words from analyzed words
    func uniqueWords(from words: [AnalyzedEnglishWord]) -> [AnalyzedEnglishWord] {
        var seen = Set<String>()
        return words.filter { word in
            let lemma = word.lemma.lowercased()
            if seen.contains(lemma) {
                return false
            }
            seen.insert(lemma)
            return true
        }
    }
}
