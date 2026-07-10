//
//  AIWordExplanationService.swift
//  SwiftMandarin
//
//  Service for generating detailed word explanations using Apple Intelligence
//  (Foundation Models framework) or Ollama for on-device AI processing
//

import Foundation
import SwiftUI
import Ollama

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Explanation Direction

/// Direction of one explanation request. The explanation is always written in
/// the learner's NATIVE language (= the interface language), and the word's
/// own language is detected from its content, since headwords can be either
/// language depending on the learning direction.
struct ExplanationDirection: Equatable {
    let wordIsChinese: Bool
    let explainInChinese: Bool

    @MainActor
    static func current(forWord word: String) -> ExplanationDirection {
        ExplanationDirection(
            wordIsChinese: word.containsCJK,
            explainInChinese: LocalizationManager.shared.nativeIsChinese
        )
    }

    /// Human-readable name of the word's language, for prompts.
    var wordLanguageName: String { wordIsChinese ? "Mandarin Chinese" : "English" }

    /// Human-readable name of the explanation language, for prompts.
    var explanationLanguageName: String { explainInChinese ? "Simplified Chinese (简体中文)" : "English" }

    /// Distinguishes cached explanations per direction so toggling the
    /// interface language regenerates rather than serving the old language.
    var cacheToken: String { "\(wordIsChinese ? "zh" : "en")>\(explainInChinese ? "zh" : "en")" }
}

// MARK: - Word Explanation Models

/// Structured response for a detailed word explanation.
/// Uses @Generable for type-safe structured generation from Apple Intelligence.
/// Field semantics are direction-neutral: the example/collocation text is in
/// the word's own language and all explanatory text is in the learner's
/// native language, both of which are stated in the session instructions.
#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct WordExplanation {
    @Guide(description: "A clear, concise definition of the word (1-2 sentences), written in the learner's NATIVE language stated in the instructions")
    let definition: String

    @Guide(description: "The part of speech, written in the learner's native language (e.g. noun/verb or 名词/动词)")
    let partOfSpeech: String

    @Guide(description: "Explanation of cultural or contextual nuances, including formality level and when to use this word, in the learner's native language")
    let nuances: String

    @Guide(description: "Detailed grammatical explanation including sentence patterns and word order, in the learner's native language")
    let grammarUsage: String

    @Guide(description: "Common contexts where this word is used, in the learner's native language", .minimumCount(1), .maximumCount(3))
    let usageContexts: [String]

    @Guide(description: "Example sentences containing the EXACT word being explained", .minimumCount(1), .maximumCount(3))
    let exampleSentences: [ExampleSentence]

    @Guide(description: "Similar words in the SAME language as the word being explained", .minimumCount(1), .maximumCount(2))
    let synonyms: [RelatedWord]

    @Guide(description: "Opposite words if applicable, in the same language as the word", .maximumCount(2))
    let antonyms: [RelatedWord]

    @Guide(description: "Common phrases with this word, in the same language as the word", .minimumCount(1), .maximumCount(2))
    let commonCollocations: [Collocation]

    @Guide(description: "Brief note on difficulty level and learning tips for this word, in the learner's native language")
    let learningTip: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ExampleSentence {
    @Guide(description: "The example sentence, in the SAME language as the word being explained. CRITICAL: it MUST contain the exact word being explained, not a different word or synonym.")
    let sentence: String

    @Guide(description: "Hanyu pinyin with accurate tone marks (ā á ǎ à) exactly matching the sentence when the sentence is Chinese; an EMPTY string when the sentence is English")
    let pinyin: String

    @Guide(description: "Translation of the sentence into the learner's native language")
    let translation: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct RelatedWord {
    @Guide(description: "The related word, in the same language as the word being explained")
    let word: String

    @Guide(description: "Hanyu pinyin with accurate tone marks exactly matching the word when it is Chinese; an EMPTY string when it is English")
    let pinyin: String

    @Guide(description: "Brief meaning, in the learner's native language")
    let meaning: String

    @Guide(description: "How this word differs from the main word in usage or nuance, in the learner's native language")
    let difference: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct Collocation {
    @Guide(description: "The collocation or phrase, in the same language as the word being explained. Must contain the word being explained.")
    let phrase: String

    @Guide(description: "Hanyu pinyin with accurate tone marks exactly matching the phrase when it is Chinese; an EMPTY string when it is English")
    let pinyin: String

    @Guide(description: "Translation of the phrase into the learner's native language")
    let translation: String
}
#endif

// MARK: - Fallback Models (for when FoundationModels is not available)

/// Fallback struct that mirrors WordExplanation for non-AI scenarios.
/// `Codable` so generated explanations can be persisted in the explanation
/// cache and re-served without another AI round-trip.
struct WordExplanationResult: Equatable, Codable, Sendable {
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

/// An example sentence in the word's own language with a translation in the
/// learner's native language. `pinyin` is empty for English sentences.
/// The `id` is a transient view-identity value, regenerated on decode rather
/// than persisted, so it is omitted from the `Codable` keys.
struct ExampleSentenceResult: Identifiable, Equatable, Codable, Sendable {
    let id = UUID()
    let sentence: String
    let pinyin: String
    let translation: String

    private enum CodingKeys: String, CodingKey {
        case sentence, pinyin, translation
    }

    static func == (lhs: ExampleSentenceResult, rhs: ExampleSentenceResult) -> Bool {
        lhs.sentence == rhs.sentence
    }
}

/// A related word (synonym/antonym) in the word's own language with its
/// meaning and usage difference in the learner's native language.
struct RelatedWordResult: Identifiable, Equatable, Codable, Sendable {
    let id = UUID()
    let word: String
    let pinyin: String
    let meaning: String
    let difference: String

    private enum CodingKeys: String, CodingKey {
        case word, pinyin, meaning, difference
    }

    static func == (lhs: RelatedWordResult, rhs: RelatedWordResult) -> Bool {
        lhs.word == rhs.word
    }
}

/// A collocation in the word's own language with a native-language translation.
struct CollocationResult: Identifiable, Equatable, Codable, Sendable {
    let id = UUID()
    let phrase: String
    let pinyin: String
    let translation: String

    private enum CodingKeys: String, CodingKey {
        case phrase, pinyin, translation
    }

    static func == (lhs: CollocationResult, rhs: CollocationResult) -> Bool {
        lhs.phrase == rhs.phrase
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
        guard #available(iOS 26.0, macOS 26.0, *) else { return false }
        return checkAvailability()
        #else
        return false
        #endif
    }

    /// Reason why AI is unavailable (if applicable)
    var unavailabilityReason: String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            return "Apple Intelligence requires iOS 26 or later"
        }
        return getUnavailabilityReason()
        #else
        return "Apple Intelligence is not available on this device"
        #endif
    }

    private init() {}

    // MARK: - Availability Check

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
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
    
    @available(iOS 26.0, macOS 26.0, *)
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

    /// Concise, direction-aware system instructions: the word's language and
    /// the explanation language (= the learner's native/interface language)
    /// are both stated explicitly so every provider produces the same shape.
    private func explanationInstructions(for direction: ExplanationDirection) -> String {
        var rules = """
        You are a \(direction.wordLanguageName) teacher. Explain \(direction.wordLanguageName) words \
        for learners whose native language is \(direction.explanationLanguageName).
        Write ALL explanatory text — definition, partOfSpeech, nuances, grammarUsage, usageContexts, \
        meanings, differences, translations, and learningTip — in \(direction.explanationLanguageName).

        CRITICAL RULES:
        1. Example sentences, synonyms, antonyms, and collocations must be in \(direction.wordLanguageName), \
        and examples MUST contain the EXACT word being explained - never use synonyms
        """
        if direction.wordIsChinese {
            rules += """

            2. Pinyin must have correct tone marks (ā á ǎ à) matching each character exactly
            3. For multi-character words like "给予", use "给予" in examples, not just "给"
            """
        } else {
            rules += """

            2. All pinyin fields must be EMPTY strings (the word being explained is English)
            """
        }
        return rules
    }

    /// Generate a detailed explanation for a word or phrase using Apple
    /// Intelligence. The word may be Chinese or English; the explanation is
    /// written in the learner's native language (the interface language).
    /// - Parameters:
    ///   - word: The word or phrase to explain
    ///   - pinyin: Optional pinyin for the word (helps with disambiguation)
    ///   - context: Optional sentence context where the word was encountered
    ///   - bypassCache: When true, evicts and skips the in-memory cache so a
    ///     "Regenerate" request truly re-runs the model instead of instantly
    ///     echoing the previous result back
    /// - Returns: A structured WordExplanationResult with comprehensive information
    func generateExplanation(
        for word: String,
        pinyin: String? = nil,
        context: String? = nil,
        bypassCache: Bool = false
    ) async throws -> WordExplanationResult {
        let direction = ExplanationDirection.current(forWord: word)

        // Check cache first (per direction, so a language toggle regenerates).
        // A forced regeneration evicts the stale entry instead.
        let cacheKey = "\(direction.cacheToken)_\(word)_\(pinyin ?? "")_\(context ?? "")"
        if bypassCache {
            explanationCache.removeValue(forKey: cacheKey)
        } else if let cached = explanationCache[cacheKey] {
            return cached
        }

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw AIExplanationError.unavailable(reason: String(localized: "Apple Intelligence requires iOS 26 or later"))
        }
        guard isAvailable else {
            throw AIExplanationError.unavailable(reason: unavailabilityReason ?? "Unknown")
        }

        // Build a concise prompt to stay within context limits
        var prompt = "Explain the \(direction.wordLanguageName) word: \(word)"
        if let pinyin = pinyin, !pinyin.isEmpty, direction.wordIsChinese {
            prompt += " (\(pinyin))"
        }
        prompt += ". Use \"\(word)\" exactly in all examples."
        if let context = context, !context.isEmpty {
            prompt += " Context: \"\(context)\""
        }

        // Create session with instructions
        let session = LanguageModelSession(instructions: explanationInstructions(for: direction))

        // Generate structured response
        let response = try await session.respond(to: prompt, generating: WordExplanation.self)
        let explanation = response.content

        // Keep only examples/collocations that contain the exact word
        let validExamples = explanation.exampleSentences.filter { $0.sentence.contains(word) }
        let validCollocations = explanation.commonCollocations.filter { $0.phrase.contains(word) }

        // Convert to result type
        let result = WordExplanationResult(
            definition: explanation.definition,
            partOfSpeech: explanation.partOfSpeech,
            nuances: explanation.nuances,
            grammarUsage: explanation.grammarUsage,
            usageContexts: explanation.usageContexts,
            exampleSentences: validExamples.map {
                ExampleSentenceResult(sentence: $0.sentence, pinyin: $0.pinyin, translation: $0.translation)
            },
            synonyms: explanation.synonyms.map {
                RelatedWordResult(word: $0.word, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            antonyms: explanation.antonyms.map {
                RelatedWordResult(word: $0.word, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            commonCollocations: validCollocations.map {
                CollocationResult(phrase: $0.phrase, pinyin: $0.pinyin, translation: $0.translation)
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
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw AIExplanationError.unavailable(reason: String(localized: "Apple Intelligence requires iOS 26 or later"))
        }
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
    
    /// Get cached explanation if available (Apple Intelligence path; cached
    /// per direction so a language toggle never serves the old language)
    func getCachedExplanation(for word: String, pinyin: String? = nil, context: String? = nil) -> WordExplanationResult? {
        let direction = ExplanationDirection.current(forWord: word)
        let cacheKey = "\(direction.cacheToken)_\(word)_\(pinyin ?? "")_\(context ?? "")"
        return explanationCache[cacheKey]
    }
    
    // MARK: - Unified AI Methods (Auto-selects provider based on settings)
    
    /// Generate explanation using the configured AI provider (Apple Intelligence or Ollama)
    /// - Parameters:
    ///   - word: The Chinese word or phrase to explain
    ///   - pinyin: Optional pinyin for the word
    ///   - context: Optional sentence context
    ///   - bypassCache: When true, evicts the in-memory cache entry for this
    ///     request and regenerates (used by the "Regenerate" button, which must
    ///     never be answered from cache)
    /// - Returns: A structured WordExplanationResult
    func generateExplanationWithProvider(
        for word: String,
        pinyin: String? = nil,
        context: String? = nil,
        bypassCache: Bool = false
    ) async throws -> WordExplanationResult {
        let settings = AIModelSettings.shared
        let provider = settings.effectiveProvider

        switch provider {
        case .appleIntelligence:
            return try await generateExplanation(for: word, pinyin: pinyin, context: context, bypassCache: bypassCache)
        case .ollama:
            return try await generateExplanationWithOllama(for: word, pinyin: pinyin, context: context, bypassCache: bypassCache)
        default:
            return try await generateExplanationWithCloud(provider: provider, for: word, pinyin: pinyin, context: context, bypassCache: bypassCache)
        }
    }
    
    /// Translate text using the configured AI provider
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceIsChinese: Whether the source is Chinese
    /// - Returns: The translated text
    func translateWithProvider(_ text: String, sourceIsChinese: Bool) async throws -> String {
        let settings = AIModelSettings.shared
        // On systems without Apple's Translation API this is the only
        // translation backend, so fail with actionable guidance.
        guard settings.isAnyProviderAvailable else {
            throw AIExplanationError.unavailable(
                reason: String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).")
            )
        }
        let provider = settings.effectiveProvider

        switch provider {
        case .appleIntelligence:
            return try await translate(text, sourceIsChinese: sourceIsChinese)
        case .ollama:
            return try await translateWithOllama(text, sourceIsChinese: sourceIsChinese)
        default:
            let model = settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty else {
                throw AIExplanationError.unavailable(reason: "No API key for \(provider.displayName)")
            }
            return try await CloudAIService.shared.translate(
                text, sourceIsChinese: sourceIsChinese, provider: provider, model: model
            )
        }
    }
    
    // MARK: - Ollama-Specific Methods
    
    /// Generate a word explanation using Ollama
    private func generateExplanationWithOllama(
        for word: String,
        pinyin: String? = nil,
        context: String? = nil,
        bypassCache: Bool = false
    ) async throws -> WordExplanationResult {
        let settings = AIModelSettings.shared

        guard OllamaService.shared.isConnected else {
            throw AIExplanationError.ollamaNotConnected
        }

        guard !settings.ollamaModel.isEmpty else {
            throw AIExplanationError.ollamaNoModelSelected
        }

        let direction = ExplanationDirection.current(forWord: word)

        // Check cache first (per direction, so a language toggle regenerates).
        // A forced regeneration evicts the stale entry instead.
        let cacheKey = "ollama_\(direction.cacheToken)_\(word)_\(pinyin ?? "")_\(context ?? "")"
        if bypassCache {
            explanationCache.removeValue(forKey: cacheKey)
        } else if let cached = explanationCache[cacheKey] {
            return cached
        }

        // Build prompt
        var prompt = "Explain the \(direction.wordLanguageName) word: \(word)"
        if let pinyin = pinyin, !pinyin.isEmpty, direction.wordIsChinese {
            prompt += " (\(pinyin))"
        }
        prompt += ". Use \"\(word)\" exactly in all example sentences."
        if let context = context, !context.isEmpty {
            prompt += " Context: \"\(context)\""
        }

        let native = direction.explanationLanguageName
        let wordLang = direction.wordLanguageName
        let pinyinDesc: Ollama.Value = direction.wordIsChinese
            ? "Hanyu pinyin with tone marks (ā á ǎ à) exactly matching the text"
            : "Empty string (the text is English)"

        // JSON schema for structured output (direction-aware descriptions)
        let schema: Ollama.Value = [
            "type": "object",
            "properties": [
                "definition": ["type": "string", "description": "A clear, concise definition in \(native) (1-2 sentences)"],
                "partOfSpeech": ["type": "string", "description": "The part of speech, written in \(native)"],
                "nuances": ["type": "string", "description": "Cultural or contextual nuances and formality level, in \(native)"],
                "grammarUsage": ["type": "string", "description": "Grammatical explanation including sentence patterns, in \(native)"],
                "usageContexts": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "1-3 common contexts where this word is used, in \(native)"
                ],
                "exampleSentences": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "sentence": ["type": "string", "description": "Example sentence in \(wordLang) containing the EXACT word"],
                            "pinyin": ["type": "string", "description": pinyinDesc],
                            "translation": ["type": "string", "description": "Translation of the sentence into \(native)"]
                        ],
                        "required": ["sentence", "pinyin", "translation"]
                    ],
                    "description": "1-3 example sentences"
                ],
                "synonyms": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "word": ["type": "string", "description": "Similar word in \(wordLang)"],
                            "pinyin": ["type": "string", "description": pinyinDesc],
                            "meaning": ["type": "string", "description": "Meaning in \(native)"],
                            "difference": ["type": "string", "description": "How it differs from the main word, in \(native)"]
                        ],
                        "required": ["word", "pinyin", "meaning", "difference"]
                    ],
                    "description": "1-2 similar words"
                ],
                "antonyms": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "word": ["type": "string", "description": "Opposite word in \(wordLang)"],
                            "pinyin": ["type": "string", "description": pinyinDesc],
                            "meaning": ["type": "string", "description": "Meaning in \(native)"],
                            "difference": ["type": "string", "description": "Usage difference, in \(native)"]
                        ],
                        "required": ["word", "pinyin", "meaning", "difference"]
                    ],
                    "description": "0-2 opposite words if applicable"
                ],
                "commonCollocations": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "phrase": ["type": "string", "description": "Phrase in \(wordLang) containing the word"],
                            "pinyin": ["type": "string", "description": pinyinDesc],
                            "translation": ["type": "string", "description": "Translation into \(native)"]
                        ],
                        "required": ["phrase", "pinyin", "translation"]
                    ],
                    "description": "1-2 common phrases with this word"
                ],
                "learningTip": ["type": "string", "description": "Brief note on difficulty and learning tips, in \(native)"]
            ],
            "required": ["definition", "partOfSpeech", "nuances", "grammarUsage", "usageContexts", "exampleSentences", "synonyms", "commonCollocations", "learningTip"]
        ]

        let jsonString = try await OllamaService.shared.generateStructured(
            model: settings.ollamaModel,
            systemPrompt: explanationTeacherInstructions(for: direction),
            userPrompt: prompt,
            schema: schema,
            enableThinking: settings.enableThinking
        )
        
        // Parse JSON response
        guard let data = jsonString.data(using: .utf8) else {
            throw AIExplanationError.generationFailed("Invalid UTF-8 response")
        }
        
        let response = try JSONDecoder().decode(OllamaWordExplanationResponse.self, from: data)
        let result = response.toResult(filteringFor: word)
        
        // Cache the result
        explanationCache[cacheKey] = result
        
        return result
    }
    
    /// Translate text using Ollama
    private func translateWithOllama(_ text: String, sourceIsChinese: Bool) async throws -> String {
        let settings = AIModelSettings.shared
        
        guard OllamaService.shared.isConnected else {
            throw AIExplanationError.ollamaNotConnected
        }
        
        guard !settings.ollamaModel.isEmpty else {
            throw AIExplanationError.ollamaNoModelSelected
        }
        
        return try await OllamaService.shared.translate(
            text,
            sourceIsChinese: sourceIsChinese,
            model: settings.ollamaModel
        )
    }
    
    // MARK: - Cloud Provider Methods

    /// Generate a word explanation using a cloud provider (OpenAI/Claude/etc.).
    private func generateExplanationWithCloud(
        provider: AIProvider,
        for word: String,
        pinyin: String? = nil,
        context: String? = nil,
        bypassCache: Bool = false
    ) async throws -> WordExplanationResult {
        let settings = AIModelSettings.shared
        let model = settings.selectedModel(for: provider)

        guard !settings.apiKey(for: provider).isEmpty else {
            throw AIExplanationError.unavailable(reason: "No API key for \(provider.displayName)")
        }
        guard !model.isEmpty else {
            throw AIExplanationError.unavailable(reason: "No model selected for \(provider.displayName)")
        }

        let direction = ExplanationDirection.current(forWord: word)

        // A forced regeneration evicts the stale entry instead of serving it.
        let cacheKey = "cloud_\(provider.rawValue)_\(direction.cacheToken)_\(word)_\(pinyin ?? "")_\(context ?? "")"
        if bypassCache {
            explanationCache.removeValue(forKey: cacheKey)
        } else if let cached = explanationCache[cacheKey] {
            return cached
        }

        var prompt = "Explain the \(direction.wordLanguageName) word: \(word)"
        if let pinyin, !pinyin.isEmpty, direction.wordIsChinese { prompt += " (\(pinyin))" }
        prompt += ". Use \"\(word)\" exactly in all example sentences."
        if let context, !context.isEmpty { prompt += " Context: \"\(context)\"" }

        let system = explanationTeacherInstructions(for: direction) + "\n\n" + cloudJSONSchemaInstructions(for: direction)

        let content = try await CloudAIService.shared.chat(
            provider: provider,
            model: model,
            system: system,
            user: prompt,
            jsonMode: true,
            maxTokens: 4096
        )

        guard let data = Self.extractJSONObject(from: content) else {
            throw AIExplanationError.generationFailed("No JSON object found in response")
        }

        let response: OllamaWordExplanationResponse
        if let r = try? JSONDecoder().decode(OllamaWordExplanationResponse.self, from: data) {
            response = r
        } else if let repaired = Self.repairJSON(String(data: data, encoding: .utf8) ?? "").data(using: .utf8),
                  let r = try? JSONDecoder().decode(OllamaWordExplanationResponse.self, from: repaired) {
            response = r
        } else {
            throw AIExplanationError.generationFailed("Could not parse the explanation response.")
        }

        let result = response.toResult(filteringFor: word)
        explanationCache[cacheKey] = result
        return result
    }

    /// JSON schema description for cloud providers (which use prompt-driven
    /// JSON rather than the structured-output API Ollama/Apple expose).
    /// Direction-aware: explanatory fields in the learner's native language,
    /// example/synonym/collocation text in the word's own language.
    private func cloudJSONSchemaInstructions(for direction: ExplanationDirection) -> String {
        let native = direction.explanationLanguageName
        let wordLang = direction.wordLanguageName
        let pinyinDesc = direction.wordIsChinese
            ? "pinyin with tone marks ā á ǎ à"
            : "empty string (English text has no pinyin)"
        return """
        Respond with ONLY a single valid JSON object (no markdown, no commentary) matching this shape:
        {
          "definition": "string — clear definition in \(native) (1-2 sentences)",
          "partOfSpeech": "string — part of speech written in \(native)",
          "nuances": "string — cultural/contextual nuance and formality, in \(native)",
          "grammarUsage": "string — grammatical explanation and sentence patterns, in \(native)",
          "usageContexts": ["string in \(native)", "1-3 common contexts"],
          "exampleSentences": [{"sentence": "\(wordLang) sentence that MUST contain the EXACT word", "pinyin": "\(pinyinDesc)", "translation": "translation in \(native)"}],
          "synonyms": [{"word": "\(wordLang) word", "pinyin": "\(pinyinDesc)", "meaning": "in \(native)", "difference": "in \(native)"}],
          "antonyms": [{"word": "\(wordLang) word", "pinyin": "\(pinyinDesc)", "meaning": "in \(native)", "difference": "in \(native)"}],
          "commonCollocations": [{"phrase": "\(wordLang) phrase containing the word", "pinyin": "\(pinyinDesc)", "translation": "in \(native)"}],
          "learningTip": "string — difficulty and learning tips, in \(native)"
        }
        """
    }

    // MARK: - Photo OCR Cleanup (used by the photo translation pipeline)

    /// Clean up raw OCR text using the configured AI provider. For
    /// vision-capable cloud providers, the original image is also supplied so
    /// the model can correct OCR errors against the source.
    ///
    /// Returns `nil` when cleanup could not run (no usable provider), so
    /// callers can tell "cleaned" apart from "raw passthrough" and surface
    /// that to the user. Throws when a provider was reached but failed.
    func cleanupRecognizedText(
        _ raw: String,
        imageData: Data? = nil,
        hintedLanguage: DetectedLanguage? = nil
    ) async throws -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let settings = AIModelSettings.shared
        let provider = settings.effectiveProvider

        let languageNote: String
        switch hintedLanguage {
        case .some(.chinese): languageNote = " The source language is Chinese (中文); keep it Chinese."
        case .some(.english): languageNote = " The source language is English; keep it English."
        default: languageNote = ""
        }

        let system = """
        You are an OCR post-processor. You receive raw text extracted from a photo \
        (and may also receive the source image). Return ONLY the corrected text exactly \
        as it appears in the source. Preserve the original language — do NOT translate.\(languageNote) \
        Fix obvious OCR errors, merge lines that were wrongly split mid-sentence, remove \
        page noise and artifacts, and keep the original meaning and ordering. \
        Output plain text only, with no commentary, labels, or quotation marks.
        """
        let user = "Raw OCR text:\n\n\(raw)"

        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), isAvailable else { return nil }
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            #else
            return nil
            #endif
        case .ollama:
            guard OllamaService.shared.isConnected, !settings.ollamaModel.isEmpty else { return nil }
            let (content, _) = try await OllamaService.shared.chat(
                model: settings.ollamaModel,
                systemPrompt: system,
                userPrompt: user,
                enableThinking: false
            )
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            // Use a vision model when an image is supplied; text model otherwise.
            let model = imageData != nil
                ? (settings.visionModel(for: provider) ?? settings.selectedModel(for: provider))
                : settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else { return nil }
            let content = try await CloudAIService.shared.chat(
                provider: provider,
                model: model,
                system: system,
                user: user,
                imageData: imageData,
                jsonMode: false,
                maxTokens: 4096
            )
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Structured Vocabulary Extraction (from photo text)

    /// Extract key study vocabulary from a passage as structured items, routed
    /// through the configured AI provider. For vision-capable cloud providers
    /// the source image is also supplied. Returns typed items the app can
    /// render and save — a concrete example of model output linked up to the
    /// app through structured output.
    func extractVocabulary(
        fromPhotoText text: String,
        imageData: Data? = nil,
        sourceIsChinese: Bool
    ) async throws -> [ExtractedVocabItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let settings = AIModelSettings.shared
        let provider = settings.effectiveProvider

        let langDesc = sourceIsChinese ? "Chinese (中文)" : "English"
        let readingNote = sourceIsChinese
            ? "the Hanyu pinyin with tone marks (ā á ǎ à)"
            : "a short pronunciation hint (may be an empty string)"
        // Meanings are written in the learner's NATIVE language (= the
        // interface language) so the study list reads naturally for them.
        let nativeDesc = LocalizationManager.shared.nativeIsChinese
            ? "Simplified Chinese (简体中文)"
            : "English"

        let system = """
        You extract the most important vocabulary a language learner should study from a passage.
        The passage is in \(langDesc). Return ONLY a JSON object of this exact shape:
        {"items":[{"term":"...","reading":"...","meaning":"..."}]}
        - "term": the word or short phrase in the source language (\(langDesc)).
        - "reading": \(readingNote).
        - "meaning": a concise translation/definition in \(nativeDesc), the learner's native language.
        Include 5–20 of the most useful items, most important first. JSON only, no commentary.
        """
        let user = "Passage:\n\n\(text)"

        let json: String
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), isAvailable else {
                throw AIExplanationError.unavailable(reason: unavailabilityReason ?? "Unknown")
            }
            let session = LanguageModelSession(instructions: system)
            json = try await session.respond(to: user).content
            #else
            throw AIExplanationError.unavailable(reason: "FoundationModels framework not available")
            #endif
        case .ollama:
            guard OllamaService.shared.isConnected, !settings.ollamaModel.isEmpty else {
                throw AIExplanationError.ollamaNotConnected
            }
            let (content, _) = try await OllamaService.shared.chat(
                model: settings.ollamaModel, systemPrompt: system, userPrompt: user, enableThinking: false
            )
            json = content
        default:
            // Use a vision model when an image is supplied; text model otherwise.
            let model = imageData != nil
                ? (settings.visionModel(for: provider) ?? settings.selectedModel(for: provider))
                : settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else {
                throw AIExplanationError.unavailable(reason: "No API key/model for \(provider.displayName)")
            }
            json = try await CloudAIService.shared.chat(
                provider: provider, model: model, system: system, user: user,
                imageData: imageData, jsonMode: true, maxTokens: 2048
            )
        }

        guard let data = Self.extractJSONObject(from: json) else {
            throw AIExplanationError.generationFailed("No JSON object found in response")
        }
        let decoded = try JSONDecoder().decode(ExtractedVocabResponse.self, from: data)
        return decoded.items.filter { !$0.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Workbook Grading

    /// The vision-capable, available provider that will be used for grading
    /// (the effective provider if suitable, otherwise the first available one).
    static func gradingProvider() -> AIProvider? {
        let settings = AIModelSettings.shared
        let effective = settings.effectiveProvider
        if effective.isCloud, effective.supportsVision, settings.isAvailable(effective) {
            return effective
        }
        return AIProvider.allCases.first { $0.isCloud && $0.supportsVision && settings.isAvailable($0) }
    }

    /// Grade a student's workbook: send the workbook page images and the
    /// written-answer images to a vision-capable provider with a grading
    /// system prompt (plus optional custom instructions) and return a
    /// structured `GradingResult`.
    func gradeWorkbook(
        workbookImages: [Data],
        answerImages: [Data],
        customInstructions: String?
    ) async throws -> GradingResult {
        guard !workbookImages.isEmpty || !answerImages.isEmpty else {
            throw AIExplanationError.generationFailed(String(localized: "Add at least one workbook image."))
        }

        guard let provider = Self.gradingProvider() else {
            throw AIExplanationError.unavailable(reason: String(localized: "Workbook grading needs a vision-capable provider with an API key (OpenAI, Claude, Qwen, Doubao, Zhipu, or Kimi). Configure one in Settings → AI."))
        }

        let settings = AIModelSettings.shared
        // Grading needs a VISION model — the user's selected model may be
        // text-only (e.g. qwen-plus), which would "see" no pages.
        guard let model = settings.visionModel(for: provider), !model.isEmpty else {
            throw AIExplanationError.unavailable(reason: String(localized: "No vision-capable model available for \(provider.displayName). Choose a vision model (e.g. qwen-vl-max, gpt-4o) in Settings → AI."))
        }

        // The student's native language is the interface language; the
        // workbook drills the LEARNING language (the opposite one). Feedback
        // reads naturally in the native language; the read-aloud sentence is
        // pronunciation practice, so it stays in the learning language.
        let nativeName = LocalizationManager.shared.nativeIsChinese
            ? "Simplified Chinese (简体中文)"
            : "English"
        let learningName = LocalizationManager.shared.learningIsChinese
            ? "Mandarin Chinese"
            : "English"
        let readingNote = LocalizationManager.shared.learningIsChinese
            ? "pinyin with tone marks (the studied terms are Chinese)"
            : "pinyin with tone marks if the term is Chinese (otherwise a short pronunciation hint or empty string)"

        var system = """
        You are a meticulous, encouraging teacher grading a student's workbook from photos. \
        The student is studying \(learningName); their native language is \(nativeName).
        You are given workbook photos. The student's answers may be written/printed DIRECTLY on \
        the same pages as the questions, OR supplied as SEPARATE answer images that follow the \
        question pages — automatically determine which layout applies from the images themselves.
        For every question you can read:
        - Identify the question number and the question text.
        - Read the student's handwritten answer.
        - Determine the correct answer.
        - Decide whether the student's answer is correct (accept minor spelling/handwriting variation).
        - Briefly explain why it is right or wrong. Write the explanation in \(nativeName) so the student \
        can read it natively.
        - Provide "fullSentence": the COMPLETE sentence in \(learningName). For a fill-in-the-blank, write the \
        whole sentence with the correct word filled in. For other question types, write the full correct \
        answer as a natural, complete \(learningName) sentence. This is read aloud for pronunciation practice, so \
        make it a clean, speakable \(learningName) sentence (no question numbers or blanks).
        For each WRONG answer, also provide a "vocab" study item with the key term the student should review: \
        "term" = the word/phrase in \(learningName) (the language being studied), "reading" = \(readingNote), \
        "meaning" = a concise translation in \(nativeName).
        Respond with ONLY a JSON object of this exact shape:
        {"score":"<correct>/<total>","summary":"one or two sentences of overall feedback, written in \(nativeName)","questions":[{"questionNumber":"1","question":"...","studentAnswer":"...","correctAnswer":"...","isCorrect":true,"fullSentence":"The complete \(learningName) sentence.","explanation":"...","vocab":{"term":"...","reading":"...","meaning":"..."}}]}
        Use null for "vocab" on correct answers. JSON only — no commentary, labels, or markdown fences.
        """
        if let custom = customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            system += "\n\nAdditional instructions from the user:\n\(custom)"
        }

        let user: String
        if answerImages.isEmpty {
            user = "There \(workbookImages.count == 1 ? "is" : "are") \(workbookImages.count) workbook page image(s); " +
                "the student's answers are written directly on these pages. Read and grade every answer you can see."
        } else if workbookImages.isEmpty {
            user = "There \(answerImages.count == 1 ? "is" : "are") \(answerImages.count) image(s) containing the questions and the student's answers. " +
                "Read and grade every answer you can see."
        } else {
            user = "Images 1–\(workbookImages.count) are the workbook (questions). " +
                "Images \(workbookImages.count + 1)–\(workbookImages.count + answerImages.count) are the student's answers. " +
                "Grade the answers against the workbook."
        }

        let allImages = workbookImages + answerImages

        // Some vision models (e.g. qwen-vl-plus) occasionally emit malformed
        // JSON or fail to read the images. Try up to twice, repairing common
        // JSON mistakes and preferring a non-empty result.
        var lastRaw = ""
        var lastDecoded: GradingResult?
        for _ in 0..<2 {
            let json = try await CloudAIService.shared.chat(
                provider: provider,
                model: model,
                system: system,
                user: user,
                images: allImages,
                jsonMode: true,
                maxTokens: 8192
            )
            lastRaw = json
            if let result = Self.decodeGrading(json) {
                if !result.questions.isEmpty { return result }
                lastDecoded = result  // valid but empty — retry once before accepting
            }
        }
        if let lastDecoded, !lastDecoded.questions.isEmpty { return lastDecoded }
        // A decoded-but-empty result means the model could not read any
        // questions — surface that instead of silently reporting "0/0".
        if lastDecoded != nil {
            throw AIExplanationError.generationFailed(
                String(localized: "The model could not find any questions in the images — the pages may be blank or unreadable, or the model may lack vision capability. Try clearer photos or a stronger vision model (e.g. qwen-vl-max, gpt-4o) in Settings → AI.")
            )
        }
        throw AIExplanationError.generationFailed(
            lastRaw.isEmpty
                ? String(localized: "The model returned an empty response. Try again or pick a different vision model.")
                : String(localized: "The model's response couldn't be read as grading data. Try a more capable vision model (e.g. qwen-vl-max or qwen-vl-plus) in Settings → AI.")
        )
    }

    // MARK: - Review Question Generation

    /// Generate fresh practice questions modeled on the learner's saved
    /// review-bank questions. Uses the effective provider's text model (no
    /// image needed); the new questions drill the same vocabulary/grammar so
    /// the learner can practice their weak spots. Throws when no provider is
    /// configured or the response can't be parsed.
    func generateReviewQuestions(
        from bank: [WorkbookQuestion],
        count: Int = 8,
        customInstructions: String? = nil
    ) async throws -> [GeneratedReviewQuestion] {
        guard !bank.isEmpty else { return [] }

        let settings = AIModelSettings.shared
        let provider = settings.effectiveProvider
        let wanted = max(1, min(count, 30))

        // The student's native language is the interface language; questions
        // drill the LEARNING language (the opposite one).
        let nativeName = LocalizationManager.shared.nativeIsChinese
            ? "Simplified Chinese (简体中文)"
            : "English"
        let learningName = LocalizationManager.shared.learningIsChinese
            ? "Mandarin Chinese"
            : "English"
        let readingNote = LocalizationManager.shared.learningIsChinese
            ? "pinyin with tone marks (the studied terms are Chinese)"
            : "a short pronunciation hint if helpful, otherwise an empty string"

        // Prioritize questions the student got wrong or that carry vocab — those
        // are the weak spots worth re-drilling — and cap the prompt size.
        let prioritized = bank.sorted { lhs, rhs in
            // Inline the weighting: a nested func would be nonisolated and so
            // couldn't read these main-actor-isolated properties.
            let lw = (lhs.hasVocab ? 2 : 0) + (lhs.wasCorrect ? 0 : 1)
            let rw = (rhs.hasVocab ? 2 : 0) + (rhs.wasCorrect ? 0 : 1)
            return lw > rw
        }.prefix(40)

        let source = prioritized.enumerated().map { index, q -> String in
            var line = "\(index + 1). Q: \(q.question.isEmpty ? q.correctAnswer : q.question)"
            if !q.correctAnswer.isEmpty { line += " | answer: \(q.correctAnswer)" }
            if q.hasVocab {
                line += " | vocab: \(q.vocabTerm)"
                if !q.vocabMeaning.isEmpty { line += " = \(q.vocabMeaning)" }
            }
            return line
        }.joined(separator: "\n")

        var system = """
        You are an expert \(learningName) teacher creating fresh practice questions for a student whose \
        native language is \(nativeName). You will receive a list of questions the student has already \
        studied. Create \(wanted) NEW practice questions that drill the SAME vocabulary, grammar, and topics \
        — especially the items the student got wrong — but do NOT copy the originals. Vary phrasing and context. \
        Each question must be answerable on its own.
        For each new question provide:
        - "prompt": the question in \(learningName). Fill-in-the-blank style (use "____" for the blank) works well.
        - "answer": the correct answer (the word/phrase or full response).
        - "explanation": a concise explanation in \(nativeName) of why the answer is correct.
        - "fullSentence": the complete, natural \(learningName) sentence with the answer filled in, suitable for \
        reading aloud (no blanks or question numbers). Include \(readingNote) only inside the explanation if useful.
        Respond with ONLY a JSON object of this exact shape:
        {"questions":[{"prompt":"...","answer":"...","explanation":"...","fullSentence":"..."}]}
        JSON only — no commentary, labels, or markdown fences.
        """
        if let custom = customInstructions?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            system += "\n\nAdditional instructions from the user:\n\(custom)"
        }
        let user = "Questions the student has studied:\n\n\(source)\n\nGenerate \(wanted) new practice questions now."

        let json: String
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), isAvailable else {
                throw AIExplanationError.unavailable(reason: unavailabilityReason ?? "Unknown")
            }
            let session = LanguageModelSession(instructions: system)
            json = try await session.respond(to: user).content
            #else
            throw AIExplanationError.unavailable(reason: "FoundationModels framework not available")
            #endif
        case .ollama:
            guard OllamaService.shared.isConnected, !settings.ollamaModel.isEmpty else {
                throw AIExplanationError.ollamaNotConnected
            }
            let (content, _) = try await OllamaService.shared.chat(
                model: settings.ollamaModel, systemPrompt: system, userPrompt: user, enableThinking: false
            )
            json = content
        default:
            let model = settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else {
                throw AIExplanationError.unavailable(reason: String(localized: "No API key/model for \(provider.displayName). Configure one in Settings → AI."))
            }
            json = try await CloudAIService.shared.chat(
                provider: provider, model: model, system: system, user: user,
                imageData: nil, jsonMode: true, maxTokens: 4096
            )
        }

        guard let data = Self.extractJSONObject(from: json) else {
            throw AIExplanationError.generationFailed(String(localized: "The model's response couldn't be read as questions. Try again or pick a different model."))
        }
        if let decoded = try? JSONDecoder().decode(GeneratedReviewResponse.self, from: data) {
            return decoded.questions.filter { !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        // Retry after a JSON repair pass before giving up.
        let repaired = Self.repairJSON(String(data: data, encoding: .utf8) ?? "")
        if let rdata = repaired.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(GeneratedReviewResponse.self, from: rdata) {
            return decoded.questions.filter { !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        throw AIExplanationError.generationFailed(String(localized: "Couldn't parse generated questions. Try again or pick a different model."))
    }

    /// Decode a grading response, repairing common LLM JSON mistakes if needed.
    private static func decodeGrading(_ json: String) -> GradingResult? {
        guard let data = extractJSONObject(from: json) else { return nil }
        if let result = try? JSONDecoder().decode(GradingResult.self, from: data) { return result }
        // Retry after a string-aware repair (inserts missing commas, drops trailing ones).
        let repaired = repairJSON(String(data: data, encoding: .utf8) ?? "")
        if let rdata = repaired.data(using: .utf8),
           let result = try? JSONDecoder().decode(GradingResult.self, from: rdata) {
            return result
        }
        return nil
    }

    /// Repair the most common LLM JSON errors without corrupting string values:
    /// insert missing commas between adjacent values and remove trailing commas.
    /// Tracks string/escape state so braces inside text are left untouched.
    static func repairJSON(_ s: String) -> String {
        let chars = Array(s)
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        var inString = false
        var escaped = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            out.append(c)

            var valueJustClosed = false
            if inString {
                if escaped { escaped = false }
                else if c == "\\" { escaped = true }
                else if c == "\"" { inString = false; valueJustClosed = true }
            } else if c == "\"" {
                inString = true
            } else if c == "}" || c == "]" {
                valueJustClosed = true
            }

            // A value just ended outside a string. If the next significant char
            // begins a new value/key with no comma between, insert one. (A key's
            // closing quote is followed by ':', so it never triggers this.)
            if valueJustClosed, !inString {
                var j = i + 1
                while j < chars.count, chars[j] == " " || chars[j] == "\n" || chars[j] == "\t" || chars[j] == "\r" {
                    j += 1
                }
                if j < chars.count {
                    let next = chars[j]
                    if next == "{" || next == "[" || next == "\"" {
                        out.append(",")
                    }
                }
            }
            i += 1
        }
        var result = String(out)
        // Remove any trailing commas before a closing brace/bracket.
        result = result.replacingOccurrences(of: ",\\s*}", with: "}", options: .regularExpression)
        result = result.replacingOccurrences(of: ",\\s*]", with: "]", options: .regularExpression)
        return result
    }

    /// Extract the first balanced JSON object from a model response, tolerating
    /// markdown code fences and surrounding prose.
    static func extractJSONObject(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else {
            return nil
        }
        return String(text[start...end]).data(using: .utf8)
    }

    /// Direction-aware teacher instructions shared by the Ollama and cloud
    /// explanation paths. The explanation language is always the learner's
    /// native language (= the interface language).
    private func explanationTeacherInstructions(for direction: ExplanationDirection) -> String {
        var rules = ["Example sentences MUST contain the EXACT word being explained - never use synonyms or variations"]
        if direction.wordIsChinese {
            rules.append("Pinyin must have correct tone marks (ā á ǎ à ē é ě è ī í ǐ ì ō ó ǒ ò ū ú ǔ ù ǖ ǘ ǚ ǜ) matching each character exactly")
            rules.append("For multi-character words like \"给予\", use \"给予\" in examples, not just \"给\"")
        } else {
            rules.append("All pinyin fields must be EMPTY strings (the word being explained is English)")
        }
        rules.append("Provide thoughtful, educational explanations that help learners understand usage patterns")
        rules.append("Consider register (formal/informal), regional variations, and common learner mistakes")

        let numbered = rules.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        return """
        You are an expert \(direction.wordLanguageName) teacher helping learners whose native language is \
        \(direction.explanationLanguageName) understand \(direction.wordLanguageName) vocabulary.
        Write ALL explanatory text — definitions, nuances, grammar notes, usage contexts, meanings, \
        differences, translations, and learning tips — in \(direction.explanationLanguageName).

        CRITICAL RULES:
        \(numbered)

        Take your time to think through each aspect carefully to provide accurate, helpful information.
        """
    }
}

// MARK: - Errors

enum AIExplanationError: LocalizedError {
    case unavailable(reason: String)
    case generationFailed(String)
    case ollamaNotConnected
    case ollamaNoModelSelected
    
    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "AI unavailable: \(reason)"
        case .generationFailed(let message):
            return "Failed to generate explanation: \(message)"
        case .ollamaNotConnected:
            return "Ollama server is not connected. Please check that Ollama is running."
        case .ollamaNoModelSelected:
            return "No Ollama model selected. Please select a model in Settings."
        }
    }
}

// MARK: - Extracted Vocabulary (structured photo output)

/// A single vocabulary item extracted by an AI provider from a passage.
struct ExtractedVocabItem: Codable, Identifiable, Hashable {
    var id: String { term }
    let term: String       // word/phrase in the source language
    let reading: String    // pinyin / pronunciation hint
    let meaning: String    // translation/definition in the other language

    init(term: String, reading: String, meaning: String) {
        self.term = term; self.reading = reading; self.meaning = meaning
    }

    // Tolerate models that omit `reading`/`meaning`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term)
        reading = (try? c.decode(String.self, forKey: .reading)) ?? ""
        meaning = (try? c.decode(String.self, forKey: .meaning)) ?? ""
    }
}

/// Wrapper matching the `{"items":[…]}` JSON shape models return.
struct ExtractedVocabResponse: Codable {
    let items: [ExtractedVocabItem]
}

// MARK: - Workbook Grading (structured output)

/// One graded question returned by the grading model.
struct GradedQuestion: Identifiable, Decodable {
    let id = UUID()
    let questionNumber: String
    let question: String
    let studentAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
    let explanation: String
    /// The complete sentence in the LEARNING language (e.g. a fill-in-the-blank
    /// with the correct word filled in), for read-aloud pronunciation practice.
    let fullSentence: String
    /// Study item for a wrong answer (optional).
    let vocab: ExtractedVocabItem?

    enum CodingKeys: String, CodingKey {
        case questionNumber, question, studentAnswer, correctAnswer, isCorrect, explanation, fullSentence, vocab
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        questionNumber = (try? c.decode(String.self, forKey: .questionNumber)) ?? ""
        question = (try? c.decode(String.self, forKey: .question)) ?? ""
        studentAnswer = (try? c.decode(String.self, forKey: .studentAnswer)) ?? ""
        correctAnswer = (try? c.decode(String.self, forKey: .correctAnswer)) ?? ""
        isCorrect = (try? c.decode(Bool.self, forKey: .isCorrect)) ?? false
        explanation = (try? c.decode(String.self, forKey: .explanation)) ?? ""
        fullSentence = (try? c.decode(String.self, forKey: .fullSentence)) ?? ""
        vocab = try? c.decode(ExtractedVocabItem.self, forKey: .vocab)
    }

    /// The text to read aloud for this question (in the learning language):
    /// the full sentence when the model supplied one, otherwise the question
    /// with the correct answer appended (or whichever of the two is available).
    var spokenSentence: String {
        let sentence = fullSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sentence.isEmpty { return sentence }
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (q.isEmpty, a.isEmpty) {
        case (false, false): return "\(q) \(a)"
        case (true, false): return a
        case (false, true): return q
        case (true, true): return ""
        }
    }
}

/// Full grading result for an uploaded workbook + answers.
struct GradingResult: Decodable {
    let score: String
    let summary: String
    let questions: [GradedQuestion]

    enum CodingKeys: String, CodingKey { case score, summary, questions }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = (try? c.decode(String.self, forKey: .score)) ?? ""
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        questions = (try? c.decode([GradedQuestion].self, forKey: .questions)) ?? []
    }

    var correctCount: Int { questions.filter { $0.isCorrect }.count }
    var wrongQuestions: [GradedQuestion] { questions.filter { !$0.isCorrect } }
}

// MARK: - Generated Review Questions (structured output)

/// A fresh practice question generated by the AI from the learner's saved
/// review-bank questions.
struct GeneratedReviewQuestion: Identifiable, Decodable {
    let id = UUID()
    let prompt: String
    let answer: String
    let explanation: String
    /// Complete sentence in the learning language for read-aloud practice.
    let fullSentence: String

    enum CodingKeys: String, CodingKey { case prompt, answer, explanation, fullSentence }

    init(prompt: String, answer: String, explanation: String = "", fullSentence: String = "") {
        self.prompt = prompt
        self.answer = answer
        self.explanation = explanation
        self.fullSentence = fullSentence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt = (try? c.decode(String.self, forKey: .prompt)) ?? ""
        answer = (try? c.decode(String.self, forKey: .answer)) ?? ""
        explanation = (try? c.decode(String.self, forKey: .explanation)) ?? ""
        fullSentence = (try? c.decode(String.self, forKey: .fullSentence)) ?? ""
    }

    /// The text to read aloud (learning language): full sentence if present,
    /// otherwise the answer, otherwise the prompt.
    var spokenSentence: String {
        let sentence = fullSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sentence.isEmpty { return sentence }
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? prompt : a
    }
}

/// Wrapper matching the `{"questions":[…]}` JSON shape the model returns.
struct GeneratedReviewResponse: Decodable {
    let questions: [GeneratedReviewQuestion]
}

// MARK: - Ollama Word Explanation Response (for JSON decoding)

/// Decodable struct for parsing Ollama/cloud JSON responses for word
/// explanations. Primary keys are the direction-neutral ones the prompts now
/// request (sentence/translation/word/phrase); the legacy Chinese-centric
/// keys (chinese/english) are accepted as fallbacks since models sometimes
/// echo familiar shapes from training. Decode-only: the extra fallback keys
/// have no stored properties, so Encodable can't be (and needn't be) synthesized.
struct OllamaWordExplanationResponse: Decodable {
    let definition: String
    let partOfSpeech: String
    let nuances: String
    let grammarUsage: String
    let usageContexts: [String]
    let exampleSentences: [OllamaExampleSentence]
    let synonyms: [OllamaRelatedWord]
    let antonyms: [OllamaRelatedWord]?
    let commonCollocations: [OllamaCollocation]
    let learningTip: String

    enum CodingKeys: String, CodingKey {
        case definition, partOfSpeech, nuances, grammarUsage, usageContexts,
             exampleSentences, synonyms, antonyms, commonCollocations, learningTip
    }

    // Tolerant decoding: cloud models occasionally omit optional sections, so
    // missing fields default to empty rather than failing the whole response.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        definition = (try? c.decode(String.self, forKey: .definition)) ?? ""
        partOfSpeech = (try? c.decode(String.self, forKey: .partOfSpeech)) ?? ""
        nuances = (try? c.decode(String.self, forKey: .nuances)) ?? ""
        grammarUsage = (try? c.decode(String.self, forKey: .grammarUsage)) ?? ""
        usageContexts = (try? c.decode([String].self, forKey: .usageContexts)) ?? []
        exampleSentences = (try? c.decode([OllamaExampleSentence].self, forKey: .exampleSentences)) ?? []
        synonyms = (try? c.decode([OllamaRelatedWord].self, forKey: .synonyms)) ?? []
        antonyms = try? c.decode([OllamaRelatedWord].self, forKey: .antonyms)
        commonCollocations = (try? c.decode([OllamaCollocation].self, forKey: .commonCollocations)) ?? []
        learningTip = (try? c.decode(String.self, forKey: .learningTip)) ?? ""
    }

    struct OllamaExampleSentence: Decodable {
        let sentence: String
        let pinyin: String
        let translation: String

        enum CodingKeys: String, CodingKey {
            case sentence, pinyin, translation, chinese, english
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            sentence = (try? c.decode(String.self, forKey: .sentence))
                ?? (try? c.decode(String.self, forKey: .chinese)) ?? ""
            pinyin = (try? c.decode(String.self, forKey: .pinyin)) ?? ""
            translation = (try? c.decode(String.self, forKey: .translation))
                ?? (try? c.decode(String.self, forKey: .english)) ?? ""
        }
    }

    struct OllamaRelatedWord: Decodable {
        let word: String
        let pinyin: String
        let meaning: String
        let difference: String

        enum CodingKeys: String, CodingKey {
            case word, pinyin, meaning, difference, chinese
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            word = (try? c.decode(String.self, forKey: .word))
                ?? (try? c.decode(String.self, forKey: .chinese)) ?? ""
            pinyin = (try? c.decode(String.self, forKey: .pinyin)) ?? ""
            meaning = (try? c.decode(String.self, forKey: .meaning)) ?? ""
            difference = (try? c.decode(String.self, forKey: .difference)) ?? ""
        }
    }

    struct OllamaCollocation: Decodable {
        let phrase: String
        let pinyin: String
        let translation: String

        enum CodingKeys: String, CodingKey {
            case phrase, pinyin, translation, chinese, english
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            phrase = (try? c.decode(String.self, forKey: .phrase))
                ?? (try? c.decode(String.self, forKey: .chinese)) ?? ""
            pinyin = (try? c.decode(String.self, forKey: .pinyin)) ?? ""
            translation = (try? c.decode(String.self, forKey: .translation))
                ?? (try? c.decode(String.self, forKey: .english)) ?? ""
        }
    }

    /// Convert to WordExplanationResult, keeping only examples/collocations
    /// that contain the exact word being explained.
    func toResult(filteringFor word: String) -> WordExplanationResult {
        let validExamples = exampleSentences.filter { $0.sentence.contains(word) }
        let validCollocations = commonCollocations.filter { $0.phrase.contains(word) }

        return WordExplanationResult(
            definition: definition,
            partOfSpeech: partOfSpeech,
            nuances: nuances,
            grammarUsage: grammarUsage,
            usageContexts: usageContexts,
            exampleSentences: validExamples.map {
                ExampleSentenceResult(sentence: $0.sentence, pinyin: $0.pinyin, translation: $0.translation)
            },
            synonyms: synonyms.map {
                RelatedWordResult(word: $0.word, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            antonyms: (antonyms ?? []).map {
                RelatedWordResult(word: $0.word, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            commonCollocations: validCollocations.map {
                CollocationResult(phrase: $0.phrase, pinyin: $0.pinyin, translation: $0.translation)
            },
            learningTip: learningTip
        )
    }
}
