//
//  AIWordExplanationService.swift
//  SwiftMandarin
//
//  Service for generating detailed word explanations using Apple Intelligence
//  (Foundation Models framework) for on-device AI processing
//

import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Word Explanation Models

/// Structured response for a detailed Mandarin word explanation
/// Uses @Generable for type-safe structured generation from Apple Intelligence
#if canImport(FoundationModels)
@Generable
struct WordExplanation {
    @Guide(description: "A clear, concise definition of the word in English (1-2 sentences)")
    let definition: String
    
    @Guide(description: "The part of speech (noun, verb, adjective, adverb, etc.)")
    let partOfSpeech: String
    
    @Guide(description: "Explanation of cultural or contextual nuances, including formality level and when to use this word")
    let nuances: String
    
    @Guide(description: "Detailed grammatical explanation including sentence patterns and word order")
    let grammarUsage: String
    
    @Guide(description: "List of common contexts or situations where this word is typically used", .minimumCount(2), .maximumCount(5))
    let usageContexts: [String]
    
    @Guide(description: "Example sentences showing the word in use, with pinyin and English translation", .minimumCount(2), .maximumCount(4))
    let exampleSentences: [ExampleSentence]
    
    @Guide(description: "Words with similar meanings in Mandarin", .minimumCount(1), .maximumCount(4))
    let synonyms: [RelatedWord]
    
    @Guide(description: "Words with opposite meanings in Mandarin (if applicable)", .maximumCount(3))
    let antonyms: [RelatedWord]
    
    @Guide(description: "Common collocations or phrases that frequently appear with this word", .minimumCount(1), .maximumCount(4))
    let commonCollocations: [Collocation]
    
    @Guide(description: "Brief note on difficulty level and learning tips for this word")
    let learningTip: String
}

@Generable
struct ExampleSentence {
    @Guide(description: "The example sentence in Chinese characters")
    let chinese: String
    
    @Guide(description: "The pinyin romanization of the sentence")
    let pinyin: String
    
    @Guide(description: "The English translation of the sentence")
    let english: String
}

@Generable
struct RelatedWord {
    @Guide(description: "The related word in Chinese characters")
    let chinese: String
    
    @Guide(description: "The pinyin romanization")
    let pinyin: String
    
    @Guide(description: "Brief English meaning")
    let meaning: String
    
    @Guide(description: "How this word differs from the main word in usage or nuance")
    let difference: String
}

@Generable
struct Collocation {
    @Guide(description: "The collocation or phrase in Chinese characters")
    let chinese: String
    
    @Guide(description: "The pinyin romanization")
    let pinyin: String
    
    @Guide(description: "The English translation")
    let english: String
}
#endif

// MARK: - Fallback Models (for when FoundationModels is not available)

/// Fallback struct that mirrors WordExplanation for non-AI scenarios
struct WordExplanationResult: Equatable {
    let definition: String
    let partOfSpeech: String
    let nuances: String
    let grammarUsage: String
    let usageContexts: [String]
    let exampleSentences: [ExampleSentenceResult]
    let synonyms: [RelatedWordResult]
    let antonyms: [RelatedWordResult]
    let commonCollocations: [CollocationResult]
    let learningTip: String
    
    static func == (lhs: WordExplanationResult, rhs: WordExplanationResult) -> Bool {
        lhs.definition == rhs.definition && lhs.partOfSpeech == rhs.partOfSpeech
    }
}

struct ExampleSentenceResult: Identifiable, Equatable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let english: String
    
    static func == (lhs: ExampleSentenceResult, rhs: ExampleSentenceResult) -> Bool {
        lhs.chinese == rhs.chinese
    }
}

struct RelatedWordResult: Identifiable, Equatable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let meaning: String
    let difference: String
    
    static func == (lhs: RelatedWordResult, rhs: RelatedWordResult) -> Bool {
        lhs.chinese == rhs.chinese
    }
}

struct CollocationResult: Identifiable, Equatable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let english: String
    
    static func == (lhs: CollocationResult, rhs: CollocationResult) -> Bool {
        lhs.chinese == rhs.chinese
    }
}

// MARK: - AI Word Explanation Service

/// Service that uses Apple Intelligence (Foundation Models) to generate detailed
/// word explanations for Mandarin vocabulary learning
@Observable
@MainActor
final class AIWordExplanationService {
    
    static let shared = AIWordExplanationService()
    
    /// Cache for generated explanations to avoid repeated API calls
    private var explanationCache: [String: WordExplanationResult] = [:]
    
    /// Whether the device supports Apple Intelligence
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        return checkAvailability()
        #else
        return false
        #endif
    }
    
    /// Reason why AI is unavailable (if applicable)
    var unavailabilityReason: String? {
        #if canImport(FoundationModels)
        return getUnavailabilityReason()
        #else
        return "Apple Intelligence is not available on this device"
        #endif
    }
    
    private init() {}
    
    // MARK: - Availability Check
    
    #if canImport(FoundationModels)
    private func checkAvailability() -> Bool {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return true
        case .unavailable:
            return false
        @unknown default:
            return false
        }
    }
    
    private func getUnavailabilityReason() -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This device does not support Apple Intelligence"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled. Enable it in Settings > Apple Intelligence & Siri"
            case .modelNotReady:
                return "The AI model is still downloading. Please try again later"
            @unknown default:
                return "Apple Intelligence is currently unavailable"
            }
        @unknown default:
            return "Apple Intelligence is currently unavailable"
        }
    }
    #endif
    
    // MARK: - Generate Explanation
    
    /// The detailed system instructions for the AI model to generate high-quality
    /// Mandarin word explanations tailored for language learners
    private var systemInstructions: String {
        """
        You are an expert Mandarin Chinese language teacher and linguist with deep knowledge of:
        - Modern Standard Mandarin (普通话) grammar, vocabulary, and usage
        - Classical and contemporary Chinese literature and idioms
        - Cross-cultural communication between English and Chinese speakers
        - Second language acquisition pedagogy for adult learners
        
        Your role is to provide comprehensive, accurate, and pedagogically useful explanations 
        of Mandarin Chinese words and phrases for English-speaking learners.
        
        Guidelines for your explanations:
        
        1. DEFINITION: Provide a clear, learner-friendly definition that captures the core meaning.
           Include any important distinctions from similar English words.
        
        2. PART OF SPEECH: Identify the grammatical category accurately. Note that Chinese words 
           can often function as multiple parts of speech depending on context.
        
        3. NUANCES: Explain:
           - Formality level (formal 正式, neutral 中性, informal 非正式, colloquial 口语)
           - Register (written 书面语 vs spoken 口语)
           - Emotional connotations (positive, negative, neutral)
           - Regional variations if significant (mainland vs Taiwan vs overseas Chinese)
           - Any cultural implications or associations
        
        4. GRAMMAR USAGE: Explain:
           - Common sentence patterns using this word
           - Position in sentences (e.g., verbs before objects, adjectives before nouns)
           - Required particles or complements (了, 过, 得, etc.)
           - Measure words if applicable
           - Any special grammatical behaviors
        
        5. USAGE CONTEXTS: List specific situations where this word is commonly used:
           - Daily conversations
           - Business/professional settings
           - Academic/formal writing
           - Social media/texting
           - Specific domains (food, travel, technology, etc.)
        
        6. EXAMPLE SENTENCES: Provide natural, commonly-used sentences that:
           - Demonstrate typical usage patterns
           - Progress from simple to more complex
           - Include accurate pinyin with tone marks (ā, á, ǎ, à)
           - Have natural English translations (not word-for-word)
        
        7. SYNONYMS: List similar words with:
           - Clear explanation of how they differ in meaning or usage
           - When to use each one
           - Any overlap or interchangeability
        
        8. ANTONYMS: List opposite words when applicable, with brief context.
        
        9. COLLOCATIONS: Provide common word combinations that native speakers use.
           These are crucial for sounding natural.
        
        10. LEARNING TIP: Offer a memorable tip, mnemonic, or insight to help learners 
            remember and correctly use this word.
        
        Always use accurate pinyin with proper tone marks: ā (1st), á (2nd), ǎ (3rd), à (4th).
        Be concise but thorough. Prioritize practical, high-frequency usage over rare cases.
        """
    }
    
    /// Generate a detailed explanation for a Mandarin word or phrase
    /// - Parameters:
    ///   - word: The Chinese word or phrase to explain
    ///   - pinyin: Optional pinyin for the word (helps with disambiguation)
    ///   - context: Optional sentence context where the word was encountered
    /// - Returns: A structured WordExplanationResult with comprehensive information
    func generateExplanation(
        for word: String,
        pinyin: String? = nil,
        context: String? = nil
    ) async throws -> WordExplanationResult {
        // Check cache first
        let cacheKey = "\(word)_\(pinyin ?? "")_\(context ?? "")"
        if let cached = explanationCache[cacheKey] {
            return cached
        }
        
        #if canImport(FoundationModels)
        guard isAvailable else {
            throw AIExplanationError.unavailable(reason: unavailabilityReason ?? "Unknown")
        }
        
        // Build the prompt
        var prompt = "Explain this Mandarin Chinese word or phrase: \(word)"
        if let pinyin = pinyin, !pinyin.isEmpty {
            prompt += " (pinyin: \(pinyin))"
        }
        if let context = context, !context.isEmpty {
            prompt += "\n\nThis word was encountered in the following context: \"\(context)\""
        }
        
        // Create session with instructions
        let session = LanguageModelSession(instructions: systemInstructions)
        
        // Generate structured response
        let response = try await session.respond(to: prompt, generating: WordExplanation.self)
        let explanation = response.content
        
        // Convert to result type
        let result = WordExplanationResult(
            definition: explanation.definition,
            partOfSpeech: explanation.partOfSpeech,
            nuances: explanation.nuances,
            grammarUsage: explanation.grammarUsage,
            usageContexts: explanation.usageContexts,
            exampleSentences: explanation.exampleSentences.map {
                ExampleSentenceResult(chinese: $0.chinese, pinyin: $0.pinyin, english: $0.english)
            },
            synonyms: explanation.synonyms.map {
                RelatedWordResult(chinese: $0.chinese, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            antonyms: explanation.antonyms.map {
                RelatedWordResult(chinese: $0.chinese, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            commonCollocations: explanation.commonCollocations.map {
                CollocationResult(chinese: $0.chinese, pinyin: $0.pinyin, english: $0.english)
            },
            learningTip: explanation.learningTip
        )
        
        // Cache the result
        explanationCache[cacheKey] = result
        
        return result
        #else
        throw AIExplanationError.unavailable(reason: "FoundationModels framework not available")
        #endif
    }
    
    // MARK: - AI Translation
    
    /// System instructions for high-quality translation
    private var translationInstructions: String {
        """
        You are an expert translator specializing in English and Mandarin Chinese (Simplified).
        
        Your translations should be:
        1. ACCURATE: Preserve the exact meaning and intent of the source text
        2. NATURAL: Use idiomatic expressions appropriate for the target language
        3. CONTEXTUAL: Consider the context and register (formal/informal)
        4. CULTURAL: Adapt cultural references when necessary for clarity
        
        For English to Chinese translations:
        - Use Simplified Chinese characters (简体中文)
        - Choose vocabulary appropriate for modern standard Mandarin (普通话)
        - Maintain the tone and style of the original
        
        For Chinese to English translations:
        - Use natural, fluent English
        - Preserve nuances and connotations where possible
        - Clarify ambiguous cultural references if needed
        
        Respond with ONLY the translation, no explanations or additional text.
        """
    }
    
    /// Translate text using Apple Intelligence
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceIsChinese: Whether the source text is Chinese (true) or English (false)
    /// - Returns: The translated text
    func translate(_ text: String, sourceIsChinese: Bool) async throws -> String {
        #if canImport(FoundationModels)
        guard isAvailable else {
            throw AIExplanationError.unavailable(reason: unavailabilityReason ?? "Unknown")
        }
        
        let direction = sourceIsChinese ? "Chinese to English" : "English to Chinese"
        let prompt = """
        Translate the following text from \(direction):
        
        \(text)
        """
        
        // Create session with translation instructions
        let session = LanguageModelSession(instructions: translationInstructions)
        
        // Generate translation
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw AIExplanationError.unavailable(reason: "FoundationModels framework not available")
        #endif
    }
    
    /// Clear the explanation cache
    func clearCache() {
        explanationCache.removeAll()
    }
    
    /// Get cached explanation if available
    func getCachedExplanation(for word: String, pinyin: String? = nil, context: String? = nil) -> WordExplanationResult? {
        let cacheKey = "\(word)_\(pinyin ?? "")_\(context ?? "")"
        return explanationCache[cacheKey]
    }
}

// MARK: - Errors

enum AIExplanationError: LocalizedError {
    case unavailable(reason: String)
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "Apple Intelligence unavailable: \(reason)"
        case .generationFailed(let message):
            return "Failed to generate explanation: \(message)"
        }
    }
}
