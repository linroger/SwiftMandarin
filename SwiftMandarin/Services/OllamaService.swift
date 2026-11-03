//
//  OllamaService.swift
//  SwiftMandarin
//
//  Service for interacting with local Ollama models as an alternative to Apple Intelligence.
//  Provides model discovery, chat completion, and structured output generation.
//

import Foundation
import SwiftUI
import Ollama

// MARK: - Ollama Model Info

/// Represents an available Ollama model with its metadata
struct OllamaModelInfo: Identifiable, Hashable, Codable {
    var id: String { name }
    let name: String
    let size: Int64
    let parameterSize: String
    let family: String
    let supportsThinking: Bool
    let supportsTools: Bool
    
    /// Human-readable size string
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Ollama Service

/// Service that provides access to local Ollama models for AI-powered features
@Observable
@MainActor
final class OllamaService {
    
    static let shared = OllamaService()
    
    // MARK: - Properties
    
    /// The Ollama client instance
    private var client: Ollama.Client
    
    /// Available models discovered from Ollama
    private(set) var availableModels: [OllamaModelInfo] = []
    
    /// Whether Ollama server is reachable
    private(set) var isConnected: Bool = false
    
    /// Last connection error if any
    private(set) var connectionError: String?
    
    /// Whether we're currently loading models
    private(set) var isLoadingModels: Bool = false
    
    /// The Ollama server host URL
    var hostURL: URL {
        get { client.host }
        set { 
            client = Ollama.Client(session: Self.session, host: newValue)
            // Re-check connection when host changes
            Task { await checkConnection() }
        }
    }
    
    // MARK: - Configuration

    /// How a request is sampled: free-form chat keeps the creative defaults,
    /// schema-constrained output is sampled more deterministically.
    enum SamplingProfile {
        case balanced
        case structured
    }

    /// The smallest context window a request is ever sent with. The Settings
    /// picker offers 8K and up; this only guards against a corrupted or
    /// hand-edited preference asking for a zero-length context.
    private static let minimumContextLength = 2048

    /// Options for one request, sized to that request.
    ///
    /// Two of these used to be constants. `num_ctx` was a hard-coded 128k, so
    /// the context length chosen in Settings → AI did nothing and a model the
    /// user had deliberately limited to 8K was asked for a window it could not
    /// serve. `num_predict` was `-1`, which leaves the output limit to the
    /// server — and that is what cut long Reader paragraphs short. Every
    /// request now carries the configured window and an explicit output cap
    /// derived from the source it was asked about: the shared `AIOutputBudget`
    /// rule, and for a model that reasons before it answers, that budget
    /// doubled (floor 8192, ceiling 16384), because Ollama counts the reasoning
    /// tokens against the same cap. The context window stays the hard ceiling:
    /// `outputCap(_:)` never asks for more output than the window the user
    /// configured can hold, since the server cannot honor it anyway.
    ///
    /// - Parameters:
    ///   - sourceLength: Character count of the text the request is about —
    ///     the passage being translated, the prompt being answered.
    ///   - reasoning: Whether the model will think before answering; see
    ///     `willReason(model:enableThinking:)`.
    ///   - profile: The sampling profile for this kind of request.
    static func requestOptions(
        sourceLength: Int,
        reasoning: Bool,
        profile: SamplingProfile = .balanced
    ) -> [String: Ollama.Value] {
        var options: [String: Ollama.Value] = [
            "num_ctx": .int(configuredContextLength),
            "num_predict": .int(outputCap(outputBudget(forSourceLength: sourceLength, reasoning: reasoning))),
        ]
        switch profile {
        case .balanced:
            options["temperature"] = .double(0.7)      // Balanced creativity
            options["top_p"] = .double(0.9)            // Nucleus sampling
            options["repeat_penalty"] = .double(1.1)   // Reduce repetition
        case .structured:
            options["temperature"] = .double(0.3)      // More deterministic for JSON
            options["top_p"] = .double(0.95)
            options["repeat_penalty"] = .double(1.05)
        }
        return options
    }

    /// The context window the user configured for local models. There is no
    /// per-model override in `AIModelSettings`; the single setting applies to
    /// every Ollama request.
    private static var configuredContextLength: Int {
        max(AIModelSettings.shared.contextLength, minimumContextLength)
    }

    /// `tokens`, clamped to the configured context window. Every `num_predict`
    /// this client sends passes through here, explicit overrides included, so
    /// a 16k reasoning budget on a model limited to 8K asks for 8K.
    static func outputCap(_ tokens: Int) -> Int {
        min(tokens, configuredContextLength)
    }

    /// Output-token cap for a request about `length` characters of source:
    /// `AIOutputBudget.tokens(forSourceLength:)`, doubled with an 8192 floor
    /// and a 16384 ceiling when the model reasons first. Mirrors the cloud
    /// client's thinking-model rule so the same passage gets the same room on
    /// either provider; the floor matters because a short prompt says nothing
    /// about how long the model will think before it answers.
    static func outputBudget(forSourceLength length: Int, reasoning: Bool) -> Int {
        let budget = AIOutputBudget.tokens(forSourceLength: length)
        guard reasoning else { return budget }
        return min(max(budget * 2, 8192), 16384)
    }

    /// Whether a request will spend output tokens on reasoning before the
    /// answer. An explicit `think` request counts — Ollama rejects it outright
    /// for a model that cannot think, so when it goes through the model does
    /// think — and so does a family that reasons whether asked to or not:
    /// gpt-oss (the default model) has no off switch, nor do QwQ and Magistral.
    /// This mirrors `CloudAIService.isThinkingModel`, which likewise treats
    /// always-on reasoners as thinking models regardless of the request.
    static func willReason(model: String, enableThinking: Bool) -> Bool {
        if enableThinking { return true }
        let name = model.lowercased()
        return ["gpt-oss", "qwq", "magistral", "reasoner", "reasoning"].contains { name.contains($0) }
    }

    // MARK: - Initialization

    /// A local model answers a non-streaming request only once it has written
    /// the whole reply, and on a laptop that routinely takes more than the
    /// default 60-second idle timeout — a chunked AI Chat answer or a Reader
    /// paragraph failed with "The request timed out." while the model was
    /// still working. The generous limits only matter while the server is busy;
    /// an unreachable server still fails at connect time.
    nonisolated private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 900
        return URLSession(configuration: configuration)
    }()
    
    private init() {
        // Initialize with default localhost
        self.client = Ollama.Client(session: Self.session, host: Ollama.Client.defaultHost)
    }
    
    // MARK: - Connection Management
    
    /// Check if Ollama server is reachable
    func checkConnection() async {
        do {
            _ = try await client.version()
            isConnected = true
            connectionError = nil
        } catch {
            isConnected = false
            connectionError = error.localizedDescription
        }
    }
    
    /// Refresh the list of available models from Ollama
    func refreshModels() async {
        isLoadingModels = true
        defer { isLoadingModels = false }
        
        do {
            let response = try await client.listModels()
            
            // Get detailed info for each model to check capabilities
            var models: [OllamaModelInfo] = []
            for model in response.models {
                // Skip any discovered model whose name isn't a valid Ollama model ID
                // rather than force-unwrapping (which would crash the whole refresh).
                guard let modelID = Ollama.Model.ID(rawValue: model.name) else {
                    continue
                }

                // Try to get capabilities for each model
                var supportsThinking = false
                var supportsTools = false

                do {
                    let details = try await client.showModel(modelID)
                    supportsThinking = details.capabilities.contains(.thinking)
                    supportsTools = details.capabilities.contains(.tools)
                } catch {
                    // Ignore errors fetching details, use defaults
                }
                
                let info = OllamaModelInfo(
                    name: model.name,
                    size: model.size,
                    parameterSize: model.details.parameterSize,
                    family: model.details.family,
                    supportsThinking: supportsThinking,
                    supportsTools: supportsTools
                )
                models.append(info)
            }
            
            availableModels = models.sorted { $0.name < $1.name }
            isConnected = true
            connectionError = nil
        } catch {
            availableModels = []
            isConnected = false
            connectionError = error.localizedDescription
        }
    }
    
    // MARK: - Chat Completion
    
    /// Generate a chat completion with the specified model
    /// - Parameters:
    ///   - model: The model name to use
    ///   - systemPrompt: System instructions for the model
    ///   - userPrompt: The user's message
    ///   - enableThinking: Whether to enable thinking/reasoning mode
    ///   - options: Model options; when nil they are sized to this request
    ///     from the user prompt's length (see `requestOptions`)
    /// - Returns: The model's response content
    func chat(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        enableThinking: Bool = true,
        options: [String: Ollama.Value]? = nil
    ) async throws -> (content: String, thinking: String?) {
        guard let modelID = Ollama.Model.ID(rawValue: model) else {
            throw OllamaServiceError.modelNotFound(model)
        }

        let messages: [Ollama.Chat.Message] = [
            .system(systemPrompt),
            .user(userPrompt)
        ]

        let response = try await client.chat(
            model: modelID,
            messages: messages,
            options: options ?? Self.requestOptions(
                sourceLength: userPrompt.count,
                reasoning: Self.willReason(model: model, enableThinking: enableThinking)
            ),
            think: enableThinking,
            keepAlive: .minutes(10)
        )

        // Ollama reports a model's reasoning in `thinking`, but models that
        // were trained to emit `<think>` tags still write them into `content`
        // when the server does not split them out. Strip them here so no caller
        // has to, and so the shared JSON extraction never trips over a brace
        // inside a chain of thought.
        return (
            content: AIResponseSanitizer.strippingReasoning(response.message.content),
            thinking: response.message.thinking
        )
    }
    
    /// Generate a streaming chat completion
    func chatStream(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        enableThinking: Bool = true,
        options: [String: Ollama.Value]? = nil
    ) throws -> AsyncThrowingStream<Ollama.Client.ChatResponse, Error> {
        guard let modelID = Ollama.Model.ID(rawValue: model) else {
            throw OllamaServiceError.modelNotFound(model)
        }

        let messages: [Ollama.Chat.Message] = [
            .system(systemPrompt),
            .user(userPrompt)
        ]

        return try client.chatStream(
            model: modelID,
            messages: messages,
            options: options ?? Self.requestOptions(
                sourceLength: userPrompt.count,
                reasoning: Self.willReason(model: model, enableThinking: enableThinking)
            ),
            think: enableThinking,
            keepAlive: .minutes(10)
        )
    }
    
    // MARK: - Structured Output Generation
    
    /// Generate a structured JSON response matching a schema
    /// - Parameters:
    ///   - model: The model name to use
    ///   - systemPrompt: System instructions
    ///   - userPrompt: User message
    ///   - schema: JSON schema for the expected output
    ///   - enableThinking: Whether to enable thinking mode
    ///   - sourceLength: Character count of the text the request is about,
    ///     which sizes the output cap; defaults to the user prompt's length
    ///   - maxOutputTokens: An explicit output cap, for a request whose answer
    ///     length does not track any input — a word explanation's rich object
    ///     is long however short the word. Overrides `sourceLength` sizing,
    ///     but is still clamped to the configured context window.
    /// - Returns: The JSON string response
    func generateStructured(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        schema: Ollama.Value,
        enableThinking: Bool = true,
        sourceLength: Int? = nil,
        maxOutputTokens: Int? = nil
    ) async throws -> String {
        guard let modelID = Ollama.Model.ID(rawValue: model) else {
            throw OllamaServiceError.modelNotFound(model)
        }

        let messages: [Ollama.Chat.Message] = [
            .system(systemPrompt),
            .user(userPrompt)
        ]

        var options = Self.requestOptions(
            sourceLength: sourceLength ?? userPrompt.count,
            reasoning: Self.willReason(model: model, enableThinking: enableThinking),
            profile: .structured
        )
        if let maxOutputTokens {
            options["num_predict"] = .int(Self.outputCap(maxOutputTokens))
        }

        let response = try await client.chat(
            model: modelID,
            messages: messages,
            options: options,
            format: schema,
            think: enableThinking,
            keepAlive: .minutes(10)
        )

        return AIResponseSanitizer.strippingReasoning(response.message.content)
    }
    
    /// Generate structured output and decode it to a Codable type
    func generateAndDecode<T: Codable>(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        type: T.Type,
        enableThinking: Bool = true
    ) async throws -> T {
        // Build JSON schema from type (simplified approach)
        let jsonString = try await generateStructured(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            schema: "json",
            enableThinking: enableThinking
        )
        
        guard let data = jsonString.data(using: .utf8) else {
            throw OllamaServiceError.invalidResponse("Response is not valid UTF-8")
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OllamaServiceError.decodingFailed("Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Translation
    
    /// JSON schema for the shared translation envelope: the answer plus the
    /// optional study notes that explain it.
    static func translationSchema(for context: AITranslationContext, includeStudyNotes: Bool = true) -> Ollama.Value {
        let native: Ollama.Value = .string(context.explanationLanguageName)
        guard includeStudyNotes else {
            return [
                "type": "object",
                "properties": [
                    "translation": [
                        "type": "string",
                        "description": "The complete translation of the source text into the target language, and nothing else",
                    ],
                ],
                "required": ["translation"],
            ]
        }
        return [
            "type": "object",
            "properties": [
                "translation": [
                    "type": "string",
                    "description": "The complete translation of the source text into the target language, and nothing else",
                ],
                "explanation": [
                    "type": "string",
                    "description": .string(
                        "At most three sentences in \(context.explanationLanguageName) on what a learner would get "
                            + "wrong here and why this rendering is right, quoting the exact words involved; empty when "
                            + "the source is straightforward"
                    ),
                ],
                "keyTerms": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "term": [
                                "type": "string",
                                "description": .string(
                                    "A word or phrase in \(context.learningLanguageName), quoted exactly as it appears "
                                        + "in \(context.studiedSideDescription), that a learner would have to look up"
                                ),
                            ],
                            "reading": [
                                "type": "string",
                                "description": .string(context.readingDescription),
                            ],
                            "meaning": ["type": "string", "description": .string("Short gloss in \(context.explanationLanguageName) for the sense used here")],
                            "note": ["type": "string", "description": .string("At most one sentence in \(context.explanationLanguageName) on the nuance or trap; empty when unnecessary")],
                        ],
                        "required": ["term", "reading", "meaning", "note"],
                    ],
                    "description": .string(
                        "0 items for an easy source, 2-4 for a sentence or short paragraph, at most 8 for a long "
                            + "passage; skip beginner vocabulary and never pad. Notes in \(native)."
                    ),
                ],
            ],
            "required": ["translation", "explanation", "keyTerms"],
        ]
    }

    /// Translate text using Ollama
    ///
    /// Uses schema-constrained generation rather than a free-form completion:
    /// a local model asked for a bare string readily prefixes a label, appends
    /// a note, or describes the passage instead of translating it, and all of
    /// that used to reach the learner as the translation.
    /// - Parameters:
    ///   - text: The text to translate
    ///   - context: Translation direction plus the learner's note language
    ///   - model: The model to use
    ///   - existingTranslation: The translation already on screen, which the
    ///     study notes must explain rather than a rendering of the model's own
    /// - Returns: The translation and its study notes
    func translate(
        _ text: String,
        context: AITranslationContext,
        model: String,
        includeStudyNotes: Bool = true,
        existingTranslation: String? = nil
    ) async throws -> AITranslationResult {
        let systemPrompt = AITranslationPromptBuilder.instructions(for: context, includeStudyNotes: includeStudyNotes)
            + "\n\n"
            + AITranslationPromptBuilder.jsonOutputContract(for: context, includeStudyNotes: includeStudyNotes)
        let userPrompt = AITranslationPromptBuilder.request(
            text: text,
            context: context,
            includeStudyNotes: includeStudyNotes,
            existingTranslation: existingTranslation
        )

        // The output cap is sized to the passage itself, not to the prompt
        // that wraps it: the wrapper is instructions, and its length says
        // nothing about how long the translation will be.
        let raw = try await generateStructured(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            schema: Self.translationSchema(for: context, includeStudyNotes: includeStudyNotes),
            enableThinking: false, // Translation doesn't need reasoning
            sourceLength: text.count
        )

        return try AITranslationResponseParser.result(from: raw)
    }
}

// MARK: - Errors

enum OllamaServiceError: LocalizedError {
    case notConnected
    case modelNotFound(String)
    case invalidResponse(String)
    case decodingFailed(String)
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Ollama server is not connected. Please ensure Ollama is running."
        case .modelNotFound(let name):
            return "Model '\(name)' not found. Please pull the model first."
        case .invalidResponse(let detail):
            return "Invalid response from Ollama: \(detail)"
        case .decodingFailed(let detail):
            return "Failed to decode response: \(detail)"
        case .generationFailed(let detail):
            return "Generation failed: \(detail)"
        }
    }
}
