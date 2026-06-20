//
//  AIModelSettings.swift
//  SwiftMandarin
//
//  Manages AI provider settings and preferences. Supports Apple Intelligence
//  (Foundation Models), local Ollama, and a family of cloud providers
//  (OpenAI, Anthropic/Claude, Deepseek, Doubao, Qwen, Kimi, Zhipu, Minimax)
//  reached over their REST APIs. API keys are stored in the Keychain.
//

import Foundation
import SwiftUI

// MARK: - Provider API Style

/// The request/response convention a cloud provider uses.
enum AIProviderAPIStyle {
    /// OpenAI `/chat/completions` + `/models`, `Authorization: Bearer` auth.
    case openAICompatible
    /// Anthropic `/v1/messages` + `/v1/models`, `x-api-key` + `anthropic-version`.
    case anthropic
}

// MARK: - AI Provider

/// The AI provider to use for AI-powered features.
enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case appleIntelligence = "apple"
    case ollama = "ollama"
    case openAI = "openai"
    case anthropic = "anthropic"
    case deepseek = "deepseek"
    case doubao = "doubao"
    case qwen = "qwen"
    case kimi = "kimi"
    case zhipu = "zhipu"
    case minimax = "minimax"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .ollama: return "Ollama (Local)"
        case .openAI: return "OpenAI"
        case .anthropic: return "Claude (Anthropic)"
        case .deepseek: return "DeepSeek"
        case .doubao: return "Doubao 豆包"
        case .qwen: return "Qwen 通义千问"
        case .kimi: return "Kimi 月之暗面"
        case .zhipu: return "Zhipu GLM 智谱"
        case .minimax: return "MiniMax"
        }
    }

    var description: String {
        switch self {
        case .appleIntelligence: return "On-device AI powered by Apple's Foundation Models"
        case .ollama: return "Local AI models running via Ollama server"
        case .openAI: return "GPT models via the OpenAI API"
        case .anthropic: return "Claude models via the Anthropic API"
        case .deepseek: return "DeepSeek chat & reasoning models"
        case .doubao: return "ByteDance Doubao models via Volcengine Ark"
        case .qwen: return "Alibaba Qwen models via DashScope"
        case .kimi: return "Moonshot Kimi models"
        case .zhipu: return "Zhipu GLM models"
        case .minimax: return "MiniMax abab models"
        }
    }

    /// SF Symbol fallback, used only if the brand asset is unavailable.
    var iconName: String {
        switch self {
        case .appleIntelligence: return "apple.logo"
        case .ollama: return "server.rack"
        case .openAI: return "sparkles"
        case .anthropic: return "a.circle"
        case .deepseek: return "magnifyingglass.circle"
        case .doubao: return "cloud"
        case .qwen: return "cloud.sun"
        case .kimi: return "moon.stars"
        case .zhipu: return "brain"
        case .minimax: return "bolt.horizontal.circle"
        }
    }

    /// Name of the brand image in `Assets.xcassets` (vector SVG). Render via
    /// the shared `ProviderIcon` view, which falls back to `iconName` when the
    /// asset is missing.
    var brandAssetName: String { "brand-\(rawValue)" }

    /// Whether the brand asset is a single-color glyph that should be tinted to
    /// the surrounding foreground color (so it adapts to light/dark mode).
    /// Full-color brand marks render in their original colors instead.
    var brandAssetIsMonochrome: Bool {
        switch self {
        case .appleIntelligence, .openAI, .ollama: return true
        default: return false
        }
    }

    /// Whether this provider is a remote cloud API requiring an API key.
    var isCloud: Bool {
        switch self {
        case .appleIntelligence, .ollama: return false
        default: return true
        }
    }

    /// Whether this provider can accept image input for vision-based tasks.
    var supportsVision: Bool {
        switch self {
        case .openAI, .anthropic, .doubao, .qwen, .kimi, .zhipu: return true
        case .appleIntelligence, .ollama, .deepseek, .minimax: return false
        }
    }

    /// Whether the OpenAI-style `response_format: {type: json_object}` is
    /// supported. Providers without it still receive the JSON schema in the
    /// prompt and are parsed with tolerant extraction.
    var supportsJSONResponseFormat: Bool {
        switch self {
        case .openAI, .deepseek, .qwen: return true
        // Kimi's coding-plan endpoint rejects the `response_format` field
        // (returns 401), so JSON is requested via the prompt + tolerant parsing.
        case .anthropic, .doubao, .zhipu, .minimax, .kimi, .appleIntelligence, .ollama: return false
        }
    }

    // MARK: Cloud REST metadata (only meaningful when `isCloud`)

    var apiStyle: AIProviderAPIStyle {
        switch self {
        case .anthropic: return .anthropic
        default: return .openAICompatible
        }
    }

    /// Default base URL (without a trailing slash). Paths below are appended.
    ///
    /// Cloud providers default to their mainland-China (domestic) endpoints;
    /// users outside China can override with the international host in Settings
    /// (e.g. Qwen → dashscope-intl…, MiniMax → api.minimax.io, GLM → api.z.ai).
    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .doubao: return "https://ark.cn-beijing.volces.com/api/v3"
        // Mainland-China DashScope (百炼). International users override with
        // https://dashscope-intl.aliyuncs.com/compatible-mode/v1
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        // Kimi coding-plan endpoint (OpenAI-compatible). For the Anthropic
        // format set the base to https://api.kimi.com/coding and API Format
        // to Anthropic (path becomes …/coding/v1/messages).
        case .kimi: return "https://api.kimi.com/coding/v1"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4"
        // MiniMax mainland-China host. International users override with
        // https://api.minimax.io/v1
        case .minimax: return "https://api.minimaxi.com/v1"
        case .appleIntelligence, .ollama: return ""
        }
    }

    /// Chat-completion path appended to the base URL.
    var chatPath: String {
        switch self {
        case .anthropic: return "/v1/messages"
        default: return "/chat/completions"
        }
    }

    /// Model-list path appended to the base URL, or `nil` when the provider
    /// has no standard listing endpoint (defaults are used instead).
    /// Every cloud provider here exposes an OpenAI-style `GET /models` (or the
    /// Anthropic `/v1/models`), so model lists are pulled live rather than
    /// relying on the curated `defaultModels` fallbacks.
    var modelsPath: String? {
        switch self {
        case .anthropic: return "/v1/models"
        case .openAI, .deepseek, .qwen, .doubao, .zhipu, .minimax: return "/models"
        // The Kimi coding-plan proxy exposes only the fixed `kimi-for-coding`
        // model and has no `GET /models` route — listing it returns 401, so we
        // skip live listing and use the curated default instead.
        case .kimi: return nil
        case .appleIntelligence, .ollama: return nil
        }
    }

    /// Curated fallback model IDs shown when live listing is unavailable.
    /// These are only a starting hint — use "Refresh Models" to pull the
    /// provider's current list from its API.
    var defaultModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o", "gpt-4.1", "gpt-4.1-mini", "o4-mini", "o3", "gpt-4o-mini"]
        case .anthropic:
            // Newest first — the first entry doubles as the default selection.
            return ["claude-sonnet-4-6", "claude-opus-4-8", "claude-haiku-4-5", "claude-sonnet-4-5", "claude-opus-4-1"]
        case .deepseek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .doubao:
            // Ark model IDs use dashes + a date suffix (NOT dots), and must be
            // activated in the Ark Console (or use an inference endpoint ID, ep-…).
            return ["doubao-seed-1-6-250615", "doubao-1-5-pro-32k-250115", "doubao-1-5-vision-pro-32k-250115", "doubao-seed-1-6-flash-250828", "doubao-1-5-lite-32k-250115"]
        case .qwen:
            return ["qwen-plus", "qwen-max", "qwen-turbo", "qwen-vl-max", "qwen-vl-plus", "qwen-max-latest"]
        case .kimi:
            // The coding-plan endpoint (api.kimi.com/coding/v1) serves a single
            // unified model id. Users on the Moonshot Open Platform can override
            // the Base URL and type a kimi-k2.x / kimi-latest model id instead.
            return ["kimi-for-coding"]
        case .zhipu:
            return ["glm-4.6", "glm-4.5", "glm-4-plus", "glm-4.5v", "glm-4v-plus", "glm-4-flash"]
        case .minimax:
            return ["MiniMax-M2.5", "MiniMax-M2.7", "MiniMax-M3", "MiniMax-Text-01"]
        case .appleIntelligence, .ollama:
            return []
        }
    }

    /// A known vision-capable model id for this provider, used when an image
    /// task (grading, photo cleanup) needs vision but the user's selected model
    /// is text-only.
    var defaultVisionModel: String? {
        switch self {
        case .openAI: return "gpt-4o"
        case .anthropic: return "claude-sonnet-4-6"
        case .qwen: return "qwen-vl-max"
        case .doubao: return "doubao-1-5-vision-pro-32k-250115"
        case .zhipu: return "glm-4.5v"
        case .kimi: return "kimi-for-coding"
        case .deepseek, .minimax, .appleIntelligence, .ollama: return nil
        }
    }

    /// Keychain account name for this provider's API key.
    var keychainAccount: String { "apikey.\(rawValue)" }

    /// URL to obtain an API key, for the settings help link.
    var apiKeyURL: String? {
        switch self {
        case .openAI: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        case .doubao: return "https://console.volcengine.com/ark"
        case .qwen: return "https://dashscope.console.aliyun.com/apiKey"
        // Kimi *Code* console — the coding-plan key. NOT the Moonshot Open
        // Platform (platform.kimi.ai); their keys are not interchangeable.
        case .kimi: return "https://www.kimi.com/code/console"
        case .zhipu: return "https://open.bigmodel.cn/usercenter/apikeys"
        case .minimax: return "https://platform.minimaxi.com/user-center/basic-information/interface-key"
        case .appleIntelligence, .ollama: return nil
        }
    }
}

// MARK: - AI Model Settings

/// Observable settings for AI model configuration.
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
        static let cloudModels = "cloud_model_selections"   // [providerRaw: modelID]
        static let cloudBaseURLs = "cloud_base_overrides"   // [providerRaw: baseURL]
        static let cloudAPIStyles = "cloud_api_style_overrides" // [providerRaw: "openai"|"anthropic"]
        static let aiPhotoCleanup = "ai_photo_cleanup_enabled"
        static let batchConcurrency = "ai_batch_concurrency"
    }

    /// Allowed range for batch-analysis parallelism. Capped low enough that a
    /// cloud provider's rate limits aren't trivially tripped, but high enough
    /// to meaningfully speed up large lists.
    static let batchConcurrencyRange = 1...10

    // MARK: - Properties

    /// The currently selected AI provider.
    var provider: AIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider) }
    }

    /// The selected Ollama model name.
    var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: Keys.ollamaModel) }
    }

    /// The Ollama server host URL.
    var ollamaHost: String {
        didSet {
            UserDefaults.standard.set(ollamaHost, forKey: Keys.ollamaHost)
            updateOllamaServiceHost()
        }
    }

    /// Whether to enable thinking/reasoning mode for Ollama models.
    var enableThinking: Bool {
        didSet { UserDefaults.standard.set(enableThinking, forKey: Keys.enableThinking) }
    }

    /// Context length for Ollama models (in tokens).
    var contextLength: Int {
        didSet { UserDefaults.standard.set(contextLength, forKey: Keys.contextLength) }
    }

    /// When enabled, uploaded photos are passed through the selected AI
    /// provider for OCR cleanup/structuring before downstream processing.
    var aiPhotoCleanupEnabled: Bool {
        didSet { UserDefaults.standard.set(aiPhotoCleanupEnabled, forKey: Keys.aiPhotoCleanup) }
    }

    /// How many words the batch AI word-analysis processes in parallel. Clamped
    /// to `batchConcurrencyRange` on write so a corrupted/out-of-range value can
    /// never reach the task group.
    var batchConcurrency: Int {
        didSet {
            let clamped = min(max(batchConcurrency, Self.batchConcurrencyRange.lowerBound),
                              Self.batchConcurrencyRange.upperBound)
            if clamped != batchConcurrency {
                batchConcurrency = clamped
                return  // the re-assignment re-enters didSet and persists the clamped value
            }
            UserDefaults.standard.set(batchConcurrency, forKey: Keys.batchConcurrency)
        }
    }

    /// Per-provider selected cloud model IDs.
    private(set) var cloudModelSelections: [String: String] {
        didSet { persistDictionary(cloudModelSelections, key: Keys.cloudModels) }
    }

    /// Per-provider base URL overrides (empty entry → use provider default).
    private(set) var cloudBaseURLOverrides: [String: String] {
        didSet { persistDictionary(cloudBaseURLOverrides, key: Keys.cloudBaseURLs) }
    }

    /// Per-provider API-format overrides ("openai" / "anthropic"). When absent,
    /// the provider's built-in style is used. Lets users point a provider at an
    /// Anthropic-compatible gateway (e.g. a Kimi "coding" endpoint).
    private(set) var apiStyleOverrides: [String: String] {
        didSet { persistDictionary(apiStyleOverrides, key: Keys.cloudAPIStyles) }
    }

    /// In-memory mirror of Keychain API keys so SwiftUI reacts to changes.
    /// Loaded from the Keychain at init; writes go through to the Keychain.
    private(set) var apiKeys: [String: String] = [:]

    // MARK: - Initialization

    private init() {
        let savedProvider = UserDefaults.standard.string(forKey: Keys.provider) ?? AIProvider.appleIntelligence.rawValue
        self.provider = AIProvider(rawValue: savedProvider) ?? .appleIntelligence

        self.ollamaModel = UserDefaults.standard.string(forKey: Keys.ollamaModel) ?? "gpt-oss:20b"
        self.ollamaHost = UserDefaults.standard.string(forKey: Keys.ollamaHost) ?? "http://localhost:11434"
        self.enableThinking = UserDefaults.standard.object(forKey: Keys.enableThinking) as? Bool ?? true
        self.contextLength = UserDefaults.standard.object(forKey: Keys.contextLength) as? Int ?? 128000
        self.aiPhotoCleanupEnabled = UserDefaults.standard.object(forKey: Keys.aiPhotoCleanup) as? Bool ?? false

        // Default 3 — a safe parallelism that speeds up large lists without
        // tripping typical cloud rate limits. Clamp the persisted value in case
        // it was written by a future build with a wider range. (didSet does not
        // fire for this in-init assignment, so clamp here explicitly.)
        let savedConcurrency = UserDefaults.standard.object(forKey: Keys.batchConcurrency) as? Int ?? 3
        self.batchConcurrency = min(max(savedConcurrency, AIModelSettings.batchConcurrencyRange.lowerBound),
                                    AIModelSettings.batchConcurrencyRange.upperBound)

        self.cloudModelSelections = AIModelSettings.loadDictionary(key: Keys.cloudModels)
        self.cloudBaseURLOverrides = AIModelSettings.loadDictionary(key: Keys.cloudBaseURLs)
        self.apiStyleOverrides = AIModelSettings.loadDictionary(key: Keys.cloudAPIStyles)

        // Load API keys from Keychain into the observable mirror.
        var keys: [String: String] = [:]
        for p in AIProvider.allCases where p.isCloud {
            if let value = KeychainHelper.get(account: p.keychainAccount), !value.isEmpty {
                keys[p.rawValue] = value
            }
        }
        self.apiKeys = keys

        updateOllamaServiceHost()
    }

    // MARK: - Per-Provider Accessors

    /// The API key for a cloud provider (empty string when none).
    func apiKey(for provider: AIProvider) -> String {
        apiKeys[provider.rawValue] ?? ""
    }

    /// Store or clear a cloud provider's API key (Keychain + observable mirror).
    func setAPIKey(_ value: String, for provider: AIProvider) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.set(trimmed, account: provider.keychainAccount)
        if trimmed.isEmpty {
            apiKeys.removeValue(forKey: provider.rawValue)
        } else {
            apiKeys[provider.rawValue] = trimmed
        }
    }

    /// The effective base URL for a cloud provider (override or default).
    func baseURL(for provider: AIProvider) -> String {
        let override = cloudBaseURLOverrides[provider.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty { return override }
        return provider.defaultBaseURL
    }

    func setBaseURLOverride(_ value: String, for provider: AIProvider) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == provider.defaultBaseURL {
            cloudBaseURLOverrides.removeValue(forKey: provider.rawValue)
        } else {
            cloudBaseURLOverrides[provider.rawValue] = trimmed
        }
    }

    /// The API-format override for a provider, or nil when using its default.
    func apiStyleOverride(for provider: AIProvider) -> AIProviderAPIStyle? {
        switch apiStyleOverrides[provider.rawValue] {
        case "anthropic": return .anthropic
        case "openai": return .openAICompatible
        default: return nil
        }
    }

    func setAPIStyleOverride(_ style: AIProviderAPIStyle?, for provider: AIProvider) {
        switch style {
        case .anthropic: apiStyleOverrides[provider.rawValue] = "anthropic"
        case .openAICompatible: apiStyleOverrides[provider.rawValue] = "openai"
        case nil: apiStyleOverrides.removeValue(forKey: provider.rawValue)
        }
    }

    /// The effective API style for a provider (override or built-in default).
    func effectiveAPIStyle(for provider: AIProvider) -> AIProviderAPIStyle {
        apiStyleOverride(for: provider) ?? provider.apiStyle
    }

    /// Chat path derived from the effective API style.
    func effectiveChatPath(for provider: AIProvider) -> String {
        switch effectiveAPIStyle(for: provider) {
        case .anthropic: return "/v1/messages"
        case .openAICompatible: return "/chat/completions"
        }
    }

    /// Models-list path derived from the effective API style.
    func effectiveModelsPath(for provider: AIProvider) -> String? {
        switch effectiveAPIStyle(for: provider) {
        case .anthropic: return "/v1/models"
        case .openAICompatible: return provider.modelsPath
        }
    }

    /// Heuristic: does this model id look vision-capable (accepts images)?
    static func isLikelyVisionModel(_ id: String) -> Bool {
        let l = id.lowercased()
        if ["vl", "vision", "omni", "qvq", "4v", "glm-4.5v", "pixtral", "llava", "internvl", "minicpm-v", "gemini"]
            .contains(where: { l.contains($0) }) { return true }
        // Providers whose flagship chat models are multimodal.
        if l.hasPrefix("claude-") || l.contains("gpt-4o") || l.contains("gpt-4.1") || l.hasPrefix("o4") || l.hasPrefix("o3") { return true }
        // Doubao multimodal "seed"/vision families.
        if l.contains("seed-1-6") || l.contains("seed-1-8") || l.contains("seed-2-") || l.contains("1-5-vision") { return true }
        return false
    }

    /// Resolve a vision-capable model for image tasks: the user's selected model
    /// if it's vision-capable, otherwise a vision model from the live list, then
    /// the provider's curated default vision model.
    func visionModel(for provider: AIProvider) -> String? {
        let selected = selectedModel(for: provider)
        // Respect the user's selection if it's already a vision model.
        if Self.isLikelyVisionModel(selected) { return selected }
        // Otherwise prefer the provider's known-good vision model.
        if let curated = provider.defaultVisionModel { return curated }
        // Last resort: any vision-looking model from the live list.
        return CloudAIService.shared.models(for: provider).map(\.id).first(where: Self.isLikelyVisionModel)
    }

    /// The selected model for a provider. Ollama maps to `ollamaModel`;
    /// cloud providers use their per-provider selection (or first default).
    func selectedModel(for provider: AIProvider) -> String {
        switch provider {
        case .ollama:
            return ollamaModel
        case .appleIntelligence:
            return ""
        default:
            if let chosen = cloudModelSelections[provider.rawValue], !chosen.isEmpty {
                return chosen
            }
            return provider.defaultModels.first ?? ""
        }
    }

    func setSelectedModel(_ model: String, for provider: AIProvider) {
        switch provider {
        case .ollama:
            ollamaModel = model
        case .appleIntelligence:
            break
        default:
            cloudModelSelections[provider.rawValue] = model
        }
    }

    // MARK: - Availability

    /// Whether Apple Intelligence is available.
    var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        return AIWordExplanationService.shared.isAvailable
        #else
        return false
        #endif
    }

    /// Whether a given provider is usable right now.
    func isAvailable(_ provider: AIProvider) -> Bool {
        switch provider {
        case .appleIntelligence:
            return isAppleIntelligenceAvailable
        case .ollama:
            return OllamaService.shared.isConnected
        default:
            return !apiKey(for: provider).isEmpty
        }
    }

    /// Whether any provider is available for AI features.
    var isAnyProviderAvailable: Bool {
        AIProvider.allCases.contains { isAvailable($0) }
    }

    /// Current effective provider — the selected one if usable, otherwise the
    /// first available provider, otherwise the selected one (so errors surface).
    var effectiveProvider: AIProvider {
        if isAvailable(provider) { return provider }
        return AIProvider.allCases.first { isAvailable($0) } ?? provider
    }

    /// Whether Ollama is selected and available.
    var isOllamaActive: Bool {
        provider == .ollama && OllamaService.shared.isConnected
    }

    /// Status message for the current configuration.
    var statusMessage: String {
        switch provider {
        case .appleIntelligence:
            return isAppleIntelligenceAvailable
                ? "Apple Intelligence is ready"
                : (AIWordExplanationService.shared.unavailabilityReason ?? "Apple Intelligence is not available")
        case .ollama:
            if OllamaService.shared.isConnected {
                return ollamaModel.isEmpty ? "Connected — select a model" : "Connected to \(ollamaModel)"
            }
            return OllamaService.shared.connectionError ?? "Not connected to Ollama"
        default:
            if apiKey(for: provider).isEmpty {
                return "Add your \(provider.displayName) API key"
            }
            let model = selectedModel(for: provider)
            return model.isEmpty ? "Ready — select a model" : "Using \(model)"
        }
    }

    /// Options dictionary for Ollama requests based on current settings.
    var ollamaOptions: [String: Ollama.Value] {
        [
            "num_ctx": .int(contextLength),
            "temperature": .double(0.7),
            "top_p": .double(0.9),
            "repeat_penalty": .double(1.1),
            "num_predict": .int(-1),
        ]
    }

    // MARK: - Methods

    private func updateOllamaServiceHost() {
        if let url = URL(string: ollamaHost) {
            OllamaService.shared.hostURL = url
        }
    }

    /// Refresh connection and available models for the active provider.
    func refreshConnection() async {
        switch provider {
        case .ollama:
            await OllamaService.shared.checkConnection()
            if OllamaService.shared.isConnected {
                await OllamaService.shared.refreshModels()
            }
        default:
            if provider.isCloud {
                await CloudAIService.shared.refreshModels(for: provider)
            }
        }
    }

    /// Select the first available Ollama model if none is selected.
    func selectDefaultModelIfNeeded() {
        if ollamaModel.isEmpty, let firstModel = OllamaService.shared.availableModels.first {
            ollamaModel = firstModel.name
        }
    }

    /// Reset to default settings.
    func resetToDefaults() {
        provider = .appleIntelligence
        ollamaModel = "gpt-oss:20b"
        ollamaHost = "http://localhost:11434"
        enableThinking = true
        contextLength = 128000
        aiPhotoCleanupEnabled = false
    }

    // MARK: - Persistence Helpers

    private func persistDictionary(_ dict: [String: String], key: String) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadDictionary(key: String) -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }
}

// MARK: - Ollama Import

import Ollama
