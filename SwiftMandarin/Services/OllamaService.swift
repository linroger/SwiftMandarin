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
        
        return (content: response.message.content, thinking: response.message.thinking)
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
        
        return response.message.content
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
    
    /// Translate text using Ollama
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceIsChinese: Whether the source is Chinese (true) or English (false)
    ///   - model: The model to use
    /// - Returns: The translated text
    func translate(
        _ text: String,
        sourceIsChinese: Bool,
        model: String
    ) async throws -> String {
        let systemPrompt = AITranslationPromptBuilder.instructions
        let userPrompt = AITranslationPromptBuilder.request(
            text: text,
            sourceIsChinese: sourceIsChinese
        )
        
        let (content, _) = try await chat(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            enableThinking: false, // Translation doesn't need reasoning
            options: Self.defaultOptions
        )
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
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
