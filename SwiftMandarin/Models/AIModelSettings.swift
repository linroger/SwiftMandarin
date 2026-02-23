//
//  AIModelSettings.swift
//  SwiftMandarin
//
//  Manages AI provider settings and preferences for using either
//  Apple Intelligence (Foundation Models) or local Ollama models.
//

import Foundation
import SwiftUI

// MARK: - AI Provider

/// The AI provider to use for AI-powered features
enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case appleIntelligence = "apple"
    case ollama = "ollama"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .appleIntelligence:
            return "Apple Intelligence"
        case .ollama:
            return "Ollama (Local)"
        }
    }
    
    var description: String {
        switch self {
        case .appleIntelligence:
            return "On-device AI powered by Apple's Foundation Models"
        case .ollama:
            return "Local AI models running via Ollama server"
        }
    }
    
    var iconName: String {
        switch self {
        case .appleIntelligence:
            return "apple.logo"
        case .ollama:
            return "server.rack"
        }
    }
}

// MARK: - AI Model Settings

/// Observable settings for AI model configuration
@Observable
@MainActor
final class AIModelSettings {
    
    static let shared = AIModelSettings()
    
    // MARK: - UserDefaults Keys
    
    private enum Keys {
        static let provider = "ai_provider"
        static let ollamaModel = "ollama_model"
        static let ollamaHost = "ollama_host"
        static let enableThinking = "ollama_enable_thinking"
        static let contextLength = "ollama_context_length"
    }
    
    // MARK: - Properties
    
    /// The currently selected AI provider
    var provider: AIProvider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
        }
    }
    
    /// The selected Ollama model name
    var ollamaModel: String {
        didSet {
            UserDefaults.standard.set(ollamaModel, forKey: Keys.ollamaModel)
        }
    }
    
    /// The Ollama server host URL
    var ollamaHost: String {
        didSet {
            UserDefaults.standard.set(ollamaHost, forKey: Keys.ollamaHost)
            updateOllamaServiceHost()
        }
    }
    
    /// Whether to enable thinking/reasoning mode for Ollama models
    var enableThinking: Bool {
        didSet {
            UserDefaults.standard.set(enableThinking, forKey: Keys.enableThinking)
        }
    }
    
    /// Context length for Ollama models (in tokens)
    var contextLength: Int {
        didSet {
            UserDefaults.standard.set(contextLength, forKey: Keys.contextLength)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether Ollama is selected and available
    var isOllamaActive: Bool {
        provider == .ollama && OllamaService.shared.isConnected
    }
    
    /// Whether Apple Intelligence is available
    var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        return AIWordExplanationService.shared.isAvailable
        #else
        return false
        #endif
    }
    
    /// Current effective provider (falls back to available option)
    var effectiveProvider: AIProvider {
        switch provider {
        case .appleIntelligence:
            return isAppleIntelligenceAvailable ? .appleIntelligence : (OllamaService.shared.isConnected ? .ollama : .appleIntelligence)
        case .ollama:
            return OllamaService.shared.isConnected ? .ollama : (isAppleIntelligenceAvailable ? .appleIntelligence : .ollama)
        }
    }
    
    /// Status message for the current configuration
    var statusMessage: String {
        switch provider {
        case .appleIntelligence:
            if isAppleIntelligenceAvailable {
                return "Apple Intelligence is ready"
            } else {
                return AIWordExplanationService.shared.unavailabilityReason ?? "Apple Intelligence is not available"
            }
        case .ollama:
            if OllamaService.shared.isConnected {
                if ollamaModel.isEmpty {
                    return "Connected - Select a model"
                } else {
                    return "Connected to \(ollamaModel)"
                }
            } else {
                return OllamaService.shared.connectionError ?? "Not connected to Ollama"
            }
        }
    }
    
    /// Options dictionary for Ollama requests based on current settings
    var ollamaOptions: [String: Ollama.Value] {
        [
            "num_ctx": .int(contextLength),
            "temperature": .double(0.7),
            "top_p": .double(0.9),
            "repeat_penalty": .double(1.1),
            "num_predict": .int(-1),
        ]
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved settings
        let savedProvider = UserDefaults.standard.string(forKey: Keys.provider) ?? AIProvider.appleIntelligence.rawValue
        self.provider = AIProvider(rawValue: savedProvider) ?? .appleIntelligence
        
        self.ollamaModel = UserDefaults.standard.string(forKey: Keys.ollamaModel) ?? "gpt-oss:20b"
        self.ollamaHost = UserDefaults.standard.string(forKey: Keys.ollamaHost) ?? "http://localhost:11434"
        self.enableThinking = UserDefaults.standard.object(forKey: Keys.enableThinking) as? Bool ?? true
        self.contextLength = UserDefaults.standard.object(forKey: Keys.contextLength) as? Int ?? 128000
        
        // Initialize Ollama service host
        updateOllamaServiceHost()
    }
    
    // MARK: - Methods
    
    /// Update the Ollama service host URL
    private func updateOllamaServiceHost() {
        if let url = URL(string: ollamaHost) {
            OllamaService.shared.hostURL = url
        }
    }
    
    /// Refresh connection and available models
    func refreshConnection() async {
        await OllamaService.shared.checkConnection()
        if OllamaService.shared.isConnected {
            await OllamaService.shared.refreshModels()
        }
    }
    
    /// Select the first available model if none is selected
    func selectDefaultModelIfNeeded() {
        if ollamaModel.isEmpty, let firstModel = OllamaService.shared.availableModels.first {
            ollamaModel = firstModel.name
        }
    }
    
    /// Reset to default settings
    func resetToDefaults() {
        provider = .appleIntelligence
        ollamaModel = "gpt-oss:20b"
        ollamaHost = "http://localhost:11434"
        enableThinking = true
        contextLength = 128000
    }
}

// MARK: - Ollama Import

import Ollama
