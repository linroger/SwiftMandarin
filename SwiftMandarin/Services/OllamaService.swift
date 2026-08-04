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
            client = Ollama.Client(host: newValue)
            // Re-check connection when host changes
            Task { await checkConnection() }
        }
    }
    
    // MARK: - Configuration
    
    /// Default options for gpt-oss 20b model with extended context and reasoning
    static let defaultOptions: [String: Ollama.Value] = [
        "num_ctx": .int(128000),           // 128k context window
        "temperature": .double(0.7),        // Balanced creativity
        "top_p": .double(0.9),              // Nucleus sampling
        "repeat_penalty": .double(1.1),     // Reduce repetition
        "num_predict": .int(-1),            // No limit on tokens
    ]
    
    /// Options optimized for reasoning tasks
    static let reasoningOptions: [String: Ollama.Value] = [
        "num_ctx": .int(128000),            // 128k context window
        "temperature": .double(0.3),         // More deterministic for reasoning
        "top_p": .double(0.95),
        "repeat_penalty": .double(1.05),
        "num_predict": .int(-1),
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Initialize with default localhost
        self.client = Ollama.Client.default
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
    ///   - options: Additional model options
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
            options: options ?? Self.defaultOptions,
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
            options: options ?? Self.defaultOptions,
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
    /// - Returns: The JSON string response
    func generateStructured(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        schema: Ollama.Value,
        enableThinking: Bool = true
    ) async throws -> String {
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
            options: Self.reasoningOptions,
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
    static func translationSchema(for context: AITranslationContext) -> Ollama.Value {
        let native: Ollama.Value = .string(context.explanationLanguageName)
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
                            + "wrong here and why this rendering is right, quoting the exact source words; empty when "
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
                                    "A word or phrase in \(context.sourceLanguageName), quoted exactly as it appears "
                                        + "in the source, that a learner would have to look up"
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
    /// - Returns: The translation and its study notes
    func translate(
        _ text: String,
        context: AITranslationContext,
        model: String
    ) async throws -> AITranslationResult {
        let systemPrompt = AITranslationPromptBuilder.instructions(for: context)
            + "\n\n"
            + AITranslationPromptBuilder.jsonOutputContract(for: context)
        let userPrompt = AITranslationPromptBuilder.request(text: text, context: context)

        let raw = try await generateStructured(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            schema: Self.translationSchema(for: context),
            enableThinking: false // Translation doesn't need reasoning
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
