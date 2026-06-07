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
    
    @Guide(description: "Common contexts where this word is used", .minimumCount(1), .maximumCount(3))
    let usageContexts: [String]
    
    @Guide(description: "Example sentences containing the EXACT word being explained", .minimumCount(1), .maximumCount(3))
    let exampleSentences: [ExampleSentence]
    
    @Guide(description: "Similar words in Mandarin", .minimumCount(1), .maximumCount(2))
    let synonyms: [RelatedWord]
    
    @Guide(description: "Opposite words if applicable", .maximumCount(2))
    let antonyms: [RelatedWord]
    
    @Guide(description: "Common phrases with this word", .minimumCount(1), .maximumCount(2))
    let commonCollocations: [Collocation]
    
    @Guide(description: "Brief note on difficulty level and learning tips for this word")
    let learningTip: String
}

@Generable
struct ExampleSentence {
    @Guide(description: "The example sentence in Chinese characters. CRITICAL: This sentence MUST contain the exact word being explained, not a different word or synonym.")
    let chinese: String
    
    @Guide(description: "The pinyin romanization of the sentence with accurate tone marks (ā á ǎ à). CRITICAL: The pinyin MUST exactly match the Chinese characters in the sentence.")
    let pinyin: String
    
    @Guide(description: "The English translation of the sentence")
    let english: String
}

@Generable
struct RelatedWord {
    @Guide(description: "The related word in Chinese characters")
    let chinese: String
    
    @Guide(description: "The pinyin romanization with accurate tone marks (ā á ǎ à). Must exactly match the Chinese characters.")
    let pinyin: String
    
    @Guide(description: "Brief English meaning")
    let meaning: String
    
    @Guide(description: "How this word differs from the main word in usage or nuance")
    let difference: String
}

@Generable
struct Collocation {
    @Guide(description: "The collocation or phrase in Chinese characters. Must contain the word being explained.")
    let chinese: String
    
    @Guide(description: "The pinyin romanization with accurate tone marks (ā á ǎ à). Must exactly match the Chinese characters.")
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
    
    /// Concise system instructions to fit within on-device model context limits
    private var systemInstructions: String {
        """
        You are a Mandarin Chinese teacher. Explain Chinese words for English-speaking learners.
        
        CRITICAL RULES:
        1. Example sentences MUST contain the EXACT word being explained - never use synonyms
        2. Pinyin must have correct tone marks (ā á ǎ à) matching each character exactly
        3. For multi-character words like "给予", use "给予" in examples, not just "给"
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
        
        // Build a concise prompt to stay within context limits
        var prompt = "Explain: \(word)"
        if let pinyin = pinyin, !pinyin.isEmpty {
            prompt += " (\(pinyin))"
        }
        prompt += ". Use \"\(word)\" exactly in all examples."
        if let context = context, !context.isEmpty {
            prompt += " Context: \"\(context)\""
        }
        
        // Create session with instructions
        let session = LanguageModelSession(instructions: systemInstructions)
        
        // Generate structured response
        let response = try await session.respond(to: prompt, generating: WordExplanation.self)
        let explanation = response.content
        
        // Filter example sentences to only include those that contain the exact word
        let validExamples = explanation.exampleSentences.filter { sentence in
            sentence.chinese.contains(word)
        }
        
        // Filter collocations to only include those that contain the word
        let validCollocations = explanation.commonCollocations.filter { collocation in
            collocation.chinese.contains(word)
        }
        
        // Convert to result type
        let result = WordExplanationResult(
            definition: explanation.definition,
            partOfSpeech: explanation.partOfSpeech,
            nuances: explanation.nuances,
            grammarUsage: explanation.grammarUsage,
            usageContexts: explanation.usageContexts,
            exampleSentences: validExamples.map {
                ExampleSentenceResult(chinese: $0.chinese, pinyin: $0.pinyin, english: $0.english)
            },
            synonyms: explanation.synonyms.map {
                RelatedWordResult(chinese: $0.chinese, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            antonyms: explanation.antonyms.map {
                RelatedWordResult(chinese: $0.chinese, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            commonCollocations: validCollocations.map {
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
    
    // MARK: - Unified AI Methods (Auto-selects provider based on settings)
    
    /// Generate explanation using the configured AI provider (Apple Intelligence or Ollama)
    /// - Parameters:
    ///   - word: The Chinese word or phrase to explain
    ///   - pinyin: Optional pinyin for the word
    ///   - context: Optional sentence context
    /// - Returns: A structured WordExplanationResult
    func generateExplanationWithProvider(
        for word: String,
        pinyin: String? = nil,
        context: String? = nil
    ) async throws -> WordExplanationResult {
        let settings = AIModelSettings.shared
        let provider = settings.effectiveProvider

        switch provider {
        case .appleIntelligence:
            return try await generateExplanation(for: word, pinyin: pinyin, context: context)
        case .ollama:
            return try await generateExplanationWithOllama(for: word, pinyin: pinyin, context: context)
        default:
            return try await generateExplanationWithCloud(provider: provider, for: word, pinyin: pinyin, context: context)
        }
    }
    
    /// Translate text using the configured AI provider
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceIsChinese: Whether the source is Chinese
    /// - Returns: The translated text
    func translateWithProvider(_ text: String, sourceIsChinese: Bool) async throws -> String {
        let settings = AIModelSettings.shared
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
        context: String? = nil
    ) async throws -> WordExplanationResult {
        let settings = AIModelSettings.shared
        
        guard OllamaService.shared.isConnected else {
            throw AIExplanationError.ollamaNotConnected
        }
        
        guard !settings.ollamaModel.isEmpty else {
            throw AIExplanationError.ollamaNoModelSelected
        }
        
        // Check cache first
        let cacheKey = "ollama_\(word)_\(pinyin ?? "")_\(context ?? "")"
        if let cached = explanationCache[cacheKey] {
            return cached
        }
        
        // Build prompt
        var prompt = "Explain the Chinese word: \(word)"
        if let pinyin = pinyin, !pinyin.isEmpty {
            prompt += " (\(pinyin))"
        }
        prompt += ". Use \"\(word)\" exactly in all example sentences."
        if let context = context, !context.isEmpty {
            prompt += " Context: \"\(context)\""
        }
        
        // JSON schema for structured output
        let schema: Ollama.Value = [
            "type": "object",
            "properties": [
                "definition": ["type": "string", "description": "A clear, concise definition in English (1-2 sentences)"],
                "partOfSpeech": ["type": "string", "description": "The part of speech (noun, verb, adjective, etc.)"],
                "nuances": ["type": "string", "description": "Cultural or contextual nuances, formality level"],
                "grammarUsage": ["type": "string", "description": "Grammatical explanation including sentence patterns"],
                "usageContexts": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "1-3 common contexts where this word is used"
                ],
                "exampleSentences": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "chinese": ["type": "string", "description": "Example sentence containing the EXACT word"],
                            "pinyin": ["type": "string", "description": "Pinyin with tone marks (ā á ǎ à)"],
                            "english": ["type": "string", "description": "English translation"]
                        ],
                        "required": ["chinese", "pinyin", "english"]
                    ],
                    "description": "1-3 example sentences"
                ],
                "synonyms": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "chinese": ["type": "string"],
                            "pinyin": ["type": "string"],
                            "meaning": ["type": "string"],
                            "difference": ["type": "string", "description": "How it differs from the main word"]
                        ],
                        "required": ["chinese", "pinyin", "meaning", "difference"]
                    ],
                    "description": "1-2 similar words"
                ],
                "antonyms": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "chinese": ["type": "string"],
                            "pinyin": ["type": "string"],
                            "meaning": ["type": "string"],
                            "difference": ["type": "string"]
                        ],
                        "required": ["chinese", "pinyin", "meaning", "difference"]
                    ],
                    "description": "0-2 opposite words if applicable"
                ],
                "commonCollocations": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "chinese": ["type": "string", "description": "Phrase containing the word"],
                            "pinyin": ["type": "string"],
                            "english": ["type": "string"]
                        ],
                        "required": ["chinese", "pinyin", "english"]
                    ],
                    "description": "1-2 common phrases with this word"
                ],
                "learningTip": ["type": "string", "description": "Brief note on difficulty and learning tips"]
            ],
            "required": ["definition", "partOfSpeech", "nuances", "grammarUsage", "usageContexts", "exampleSentences", "synonyms", "commonCollocations", "learningTip"]
        ]
        
        let jsonString = try await OllamaService.shared.generateStructured(
            model: settings.ollamaModel,
            systemPrompt: ollamaSystemInstructions,
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
        context: String? = nil
    ) async throws -> WordExplanationResult {
        let settings = AIModelSettings.shared
        let model = settings.selectedModel(for: provider)

        guard !settings.apiKey(for: provider).isEmpty else {
            throw AIExplanationError.unavailable(reason: "No API key for \(provider.displayName)")
        }
        guard !model.isEmpty else {
            throw AIExplanationError.unavailable(reason: "No model selected for \(provider.displayName)")
        }

        let cacheKey = "cloud_\(provider.rawValue)_\(word)_\(pinyin ?? "")_\(context ?? "")"
        if let cached = explanationCache[cacheKey] { return cached }

        var prompt = "Explain the Chinese word: \(word)"
        if let pinyin, !pinyin.isEmpty { prompt += " (\(pinyin))" }
        prompt += ". Use \"\(word)\" exactly in all example sentences."
        if let context, !context.isEmpty { prompt += " Context: \"\(context)\"" }

        let system = ollamaSystemInstructions + "\n\n" + cloudJSONSchemaInstructions

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
    private var cloudJSONSchemaInstructions: String {
        """
        Respond with ONLY a single valid JSON object (no markdown, no commentary) matching this shape:
        {
          "definition": "string — clear English definition (1-2 sentences)",
          "partOfSpeech": "string — noun/verb/adjective/etc.",
          "nuances": "string — cultural/contextual nuance and formality",
          "grammarUsage": "string — grammatical explanation and sentence patterns",
          "usageContexts": ["string", "1-3 common contexts"],
          "exampleSentences": [{"chinese": "must contain the EXACT word", "pinyin": "tone marks ā á ǎ à", "english": "translation"}],
          "synonyms": [{"chinese": "", "pinyin": "", "meaning": "", "difference": ""}],
          "antonyms": [{"chinese": "", "pinyin": "", "meaning": "", "difference": ""}],
          "commonCollocations": [{"chinese": "phrase containing the word", "pinyin": "", "english": ""}],
          "learningTip": "string — difficulty and learning tips"
        }
        """
    }

    // MARK: - Photo OCR Cleanup (used by the photo translation pipeline)

    /// Clean up raw OCR text using the configured AI provider. For
    /// vision-capable cloud providers, the original image is also supplied so
    /// the model can correct OCR errors against the source. Returns the raw
    /// text unchanged if no provider is available (safe fallback).
    func cleanupRecognizedText(
        _ raw: String,
        imageData: Data? = nil,
        hintedLanguage: DetectedLanguage? = nil
    ) async throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

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
            guard isAvailable else { return raw }
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            #else
            return raw
            #endif
        case .ollama:
            guard OllamaService.shared.isConnected, !settings.ollamaModel.isEmpty else { return raw }
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
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else { return raw }
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

        let system = """
        You extract the most important vocabulary a language learner should study from a passage.
        The passage is in \(langDesc). Return ONLY a JSON object of this exact shape:
        {"items":[{"term":"...","reading":"...","meaning":"..."}]}
        - "term": the word or short phrase in the source language (\(langDesc)).
        - "reading": \(readingNote).
        - "meaning": a concise translation/definition in the OTHER language.
        Include 5–20 of the most useful items, most important first. JSON only, no commentary.
        """
        let user = "Passage:\n\n\(text)"

        let json: String
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard isAvailable else { throw AIExplanationError.unavailable(reason: unavailabilityReason ?? "Unknown") }
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
            throw AIExplanationError.generationFailed("Add at least one workbook image.")
        }

        guard let provider = Self.gradingProvider() else {
            throw AIExplanationError.unavailable(reason: "Workbook grading needs a vision-capable provider with an API key (OpenAI, Claude, Qwen, Doubao, Zhipu, or Kimi). Configure one in Settings → AI.")
        }

        let settings = AIModelSettings.shared
        // Grading needs a VISION model — the user's selected model may be
        // text-only (e.g. qwen-plus), which would "see" no pages.
        guard let model = settings.visionModel(for: provider), !model.isEmpty else {
            throw AIExplanationError.unavailable(reason: "No vision-capable model available for \(provider.displayName). Choose a vision model (e.g. qwen-vl-max, gpt-4o, claude-sonnet-4-5) in Settings → AI.")
        }

        var system = """
        You are a meticulous, encouraging teacher grading a student's workbook from photos.
        You are given workbook photos. The student's answers may be written/printed DIRECTLY on \
        the same pages as the questions, OR supplied as SEPARATE answer images that follow the \
        question pages — automatically determine which layout applies from the images themselves.
        For every question you can read:
        - Identify the question number and the question text.
        - Read the student's handwritten answer.
        - Determine the correct answer.
        - Decide whether the student's answer is correct (accept minor spelling/handwriting variation).
        - Briefly explain why it is right or wrong.
        - Provide "fullSentence": the COMPLETE sentence in English. For a fill-in-the-blank, write the \
        whole sentence with the correct word filled in. For other question types, write the full correct \
        answer as a natural, complete English sentence. This is read aloud for pronunciation practice, so \
        make it a clean, speakable English sentence (no question numbers or blanks).
        For each WRONG answer, also provide a "vocab" study item with the key term the student should review: \
        "term" = the word/phrase in the language being studied, "reading" = pinyin with tone marks if the term \
        is Chinese (otherwise a short pronunciation hint or empty string), "meaning" = a concise translation.
        Respond with ONLY a JSON object of this exact shape:
        {"score":"<correct>/<total>","summary":"one or two sentences of overall feedback","questions":[{"questionNumber":"1","question":"...","studentAnswer":"...","correctAnswer":"...","isCorrect":true,"fullSentence":"The complete English sentence.","explanation":"...","vocab":{"term":"...","reading":"...","meaning":"..."}}]}
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
        if let lastDecoded { return lastDecoded }
        throw AIExplanationError.generationFailed(
            lastRaw.isEmpty
                ? "The model returned an empty response. Try again or pick a different vision model."
                : "The model's response couldn't be read as grading data. Try a more capable vision model (e.g. qwen-vl-max or qwen3-vl-plus) in Settings → AI."
        )
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

    /// System instructions for Ollama word explanation
    private var ollamaSystemInstructions: String {
        """
        You are an expert Mandarin Chinese teacher helping English-speaking learners understand Chinese vocabulary.
        
        CRITICAL RULES:
        1. Example sentences MUST contain the EXACT word being explained - never use synonyms or variations
        2. Pinyin must have correct tone marks (ā á ǎ à ē é ě è ī í ǐ ì ō ó ǒ ò ū ú ǔ ù ǖ ǘ ǚ ǜ) matching each character exactly
        3. For multi-character words like "给予", use "给予" in examples, not just "给"
        4. Provide thoughtful, educational explanations that help learners understand usage patterns
        5. Consider register (formal/informal), regional variations, and common learner mistakes
        
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
    /// The complete sentence in English (e.g. a fill-in-the-blank with the
    /// correct word filled in), for read-aloud pronunciation practice.
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

    /// The text to read aloud in English for this question: the full sentence
    /// when the model supplied one, otherwise the question with the correct
    /// answer appended (or whichever of the two is available).
    var spokenEnglish: String {
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

// MARK: - Ollama Word Explanation Response (for JSON decoding)

/// Codable struct for parsing Ollama JSON responses for word explanations
struct OllamaWordExplanationResponse: Codable {
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

    struct OllamaExampleSentence: Codable {
        let chinese: String
        let pinyin: String
        let english: String
    }
    
    struct OllamaRelatedWord: Codable {
        let chinese: String
        let pinyin: String
        let meaning: String
        let difference: String
    }
    
    struct OllamaCollocation: Codable {
        let chinese: String
        let pinyin: String
        let english: String
    }
    
    /// Convert to WordExplanationResult
    func toResult(filteringFor word: String) -> WordExplanationResult {
        // Filter example sentences to only include those that contain the exact word
        let validExamples = exampleSentences.filter { sentence in
            sentence.chinese.contains(word)
        }
        
        // Filter collocations to only include those that contain the word
        let validCollocations = commonCollocations.filter { collocation in
            collocation.chinese.contains(word)
        }
        
        return WordExplanationResult(
            definition: definition,
            partOfSpeech: partOfSpeech,
            nuances: nuances,
            grammarUsage: grammarUsage,
            usageContexts: usageContexts,
            exampleSentences: validExamples.map {
                ExampleSentenceResult(chinese: $0.chinese, pinyin: $0.pinyin, english: $0.english)
            },
            synonyms: synonyms.map {
                RelatedWordResult(chinese: $0.chinese, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            antonyms: (antonyms ?? []).map {
                RelatedWordResult(chinese: $0.chinese, pinyin: $0.pinyin, meaning: $0.meaning, difference: $0.difference)
            },
            commonCollocations: validCollocations.map {
                CollocationResult(chinese: $0.chinese, pinyin: $0.pinyin, english: $0.english)
            },
            learningTip: learningTip
        )
    }
}
