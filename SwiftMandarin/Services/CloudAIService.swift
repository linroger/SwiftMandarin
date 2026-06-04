//
//  CloudAIService.swift
//  SwiftMandarin
//
//  URLSession-based client for cloud AI providers. Supports the OpenAI
//  chat-completions convention (OpenAI, DeepSeek, Doubao, Qwen/DashScope,
//  Kimi/Moonshot, Zhipu, MiniMax) and the Anthropic Messages convention
//  (Claude). Provides model listing, text chat, vision chat, and translation.
//
//  No third-party dependency — built directly on Foundation so any
//  OpenAI-compatible endpoint can be reached by configuring base URL + key.
//

import Foundation
import SwiftUI

// MARK: - Model Info

/// A provider-neutral model descriptor for the settings model picker.
struct CloudModelInfo: Identifiable, Hashable, Codable {
    let id: String
    var displayName: String { id }
}

// MARK: - Errors

enum CloudAIError: LocalizedError {
    case notCloudProvider
    case missingAPIKey(String)
    case invalidURL
    case requestEncodingFailed
    case httpError(Int, String)
    case emptyResponse
    case unexpectedResponse(String)

    var errorDescription: String? {
        switch self {
        case .notCloudProvider:
            return "Selected provider is not a cloud provider."
        case .missingAPIKey(let name):
            return "No API key configured for \(name). Add it in Settings → AI."
        case .invalidURL:
            return "The provider base URL is invalid."
        case .requestEncodingFailed:
            return "Failed to encode the request."
        case .httpError(let code, let body):
            let trimmed = body.count > 300 ? String(body.prefix(300)) + "…" : body
            return "Provider returned HTTP \(code): \(trimmed)"
        case .emptyResponse:
            return "The provider returned an empty response."
        case .unexpectedResponse(let detail):
            return "Unexpected response from provider: \(detail)"
        }
    }
}

// MARK: - Cloud AI Service

@Observable
@MainActor
final class CloudAIService {

    static let shared = CloudAIService()

    /// Per-provider live model lists (keyed by `AIProvider.rawValue`).
    private(set) var availableModels: [String: [CloudModelInfo]] = [:]

    /// Providers currently fetching their model list.
    private(set) var loadingProviders: Set<String> = []

    /// Last error message per provider (keyed by `AIProvider.rawValue`).
    private(set) var lastError: [String: String] = [:]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Public State Accessors

    /// Models to show for a provider: live list if available, else curated defaults.
    func models(for provider: AIProvider) -> [CloudModelInfo] {
        if let live = availableModels[provider.rawValue], !live.isEmpty {
            return live
        }
        return provider.defaultModels.map { CloudModelInfo(id: $0) }
    }

    func isLoading(_ provider: AIProvider) -> Bool {
        loadingProviders.contains(provider.rawValue)
    }

    func error(for provider: AIProvider) -> String? {
        lastError[provider.rawValue]
    }

    // MARK: - Model Listing

    /// Fetch the available model list for a cloud provider via its API.
    /// Falls back to curated defaults when no listing endpoint exists or the
    /// request fails; never throws (errors are stored in `lastError`).
    func refreshModels(for provider: AIProvider) async {
        guard provider.isCloud else { return }
        let settings = AIModelSettings.shared
        let key = settings.apiKey(for: provider)

        lastError[provider.rawValue] = nil

        guard !key.isEmpty else {
            lastError[provider.rawValue] = CloudAIError.missingAPIKey(provider.displayName).localizedDescription
            return
        }

        // Providers without a standard listing endpoint use curated defaults.
        guard let modelsPath = settings.effectiveModelsPath(for: provider) else {
            availableModels[provider.rawValue] = provider.defaultModels.map { CloudModelInfo(id: $0) }
            return
        }

        guard let url = URL(string: settings.baseURL(for: provider) + modelsPath) else {
            lastError[provider.rawValue] = CloudAIError.invalidURL.localizedDescription
            return
        }

        loadingProviders.insert(provider.rawValue)
        defer { loadingProviders.remove(provider.rawValue) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(&request, provider: provider, key: key)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CloudAIError.unexpectedResponse("No HTTP response")
            }
            guard (200...299).contains(http.statusCode) else {
                throw CloudAIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }
            let ids = Self.parseModelIDs(from: data)
            if ids.isEmpty {
                // Keep defaults visible if the endpoint returned nothing useful.
                availableModels[provider.rawValue] = provider.defaultModels.map { CloudModelInfo(id: $0) }
            } else {
                availableModels[provider.rawValue] = ids.map { CloudModelInfo(id: $0) }
            }
        } catch {
            lastError[provider.rawValue] = error.localizedDescription
            // Surface curated defaults so the picker remains usable.
            if availableModels[provider.rawValue] == nil {
                availableModels[provider.rawValue] = provider.defaultModels.map { CloudModelInfo(id: $0) }
            }
        }
    }

    /// Parse model IDs from common listing-response shapes.
    private static func parseModelIDs(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let container: [Any]?
        if let dict = json as? [String: Any] {
            container = (dict["data"] as? [Any]) ?? (dict["models"] as? [Any])
        } else {
            container = json as? [Any]
        }
        guard let items = container else { return [] }
        var ids: [String] = []
        for item in items {
            if let s = item as? String {
                ids.append(s)
            } else if let obj = item as? [String: Any] {
                // Skip retired models (e.g. Volcengine Ark marks them "Shutdown").
                if (obj["status"] as? String) == "Shutdown" { continue }
                if let id = obj["id"] as? String { ids.append(id) }
                else if let name = obj["name"] as? String { ids.append(name) }
            }
        }
        return ids.sorted()
    }

    // MARK: - Chat

    /// Send a chat request and return the assistant's text content.
    /// - Parameters:
    ///   - imageData: optional single image for vision-capable providers.
    ///   - images: optional multiple images (combined with `imageData`).
    ///   - jsonMode: request a JSON object response where supported.
    func chat(
        provider: AIProvider,
        model: String,
        system: String,
        user: String,
        imageData: Data? = nil,
        images: [Data] = [],
        jsonMode: Bool = false,
        maxTokens: Int = 4096
    ) async throws -> String {
        guard provider.isCloud else { throw CloudAIError.notCloudProvider }
        let settings = AIModelSettings.shared
        let key = settings.apiKey(for: provider)
        guard !key.isEmpty else { throw CloudAIError.missingAPIKey(provider.displayName) }

        let base = settings.baseURL(for: provider)
        let style = settings.effectiveAPIStyle(for: provider)
        guard let url = URL(string: base + settings.effectiveChatPath(for: provider)) else { throw CloudAIError.invalidURL }

        // Combine the convenience single image with the multi-image array;
        // only send images at all for vision-capable providers.
        let combinedImages = (imageData.map { [$0] } ?? []) + images
        let imagesToSend = provider.supportsVision ? combinedImages : []

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(&request, provider: provider, key: key)

        // Only request the strict JSON response_format where the provider
        // supports it; others still get JSON via the prompt + tolerant parsing.
        let useResponseFormat = jsonMode && provider.supportsJSONResponseFormat

        let body: [String: Any]
        switch style {
        case .openAICompatible:
            body = Self.openAIBody(
                model: model, system: system, user: user,
                images: imagesToSend,
                jsonMode: jsonMode, useResponseFormat: useResponseFormat, maxTokens: maxTokens
            )
        case .anthropic:
            body = Self.anthropicBody(
                model: model, system: system, user: user,
                images: imagesToSend, maxTokens: maxTokens
            )
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw CloudAIError.requestEncodingFailed
        }
        request.httpBody = httpBody

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudAIError.unexpectedResponse("No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw CloudAIError.httpError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let content: String?
        switch style {
        case .openAICompatible: content = Self.parseOpenAIContent(from: data)
        case .anthropic: content = Self.parseAnthropicContent(from: data)
        }

        guard let text = content, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudAIError.emptyResponse
        }
        return text
    }

    /// Translate text using a cloud provider.
    func translate(_ text: String, sourceIsChinese: Bool, provider: AIProvider, model: String) async throws -> String {
        let system = """
        You are an expert translator between English and Mandarin Chinese (Simplified).
        Translate accurately and naturally, preserving meaning, tone and register.
        For English→Chinese use 简体中文. Respond with ONLY the translation, no commentary.
        """
        let direction = sourceIsChinese ? "Chinese to English" : "English to Chinese"
        let user = "Translate the following from \(direction):\n\n\(text)"
        let result = try await chat(provider: provider, model: model, system: system, user: user, maxTokens: 2048)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Request Building

    private func applyAuthHeaders(_ request: inout URLRequest, provider: AIProvider, key: String) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch AIModelSettings.shared.effectiveAPIStyle(for: provider) {
        case .openAICompatible:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            // Anthropic-style gateways accept x-api-key; also send Bearer so
            // proxies that expect either header authenticate.
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        }
    }

    private static func openAIBody(
        model: String, system: String, user: String,
        images: [Data], jsonMode: Bool, useResponseFormat: Bool, maxTokens: Int
    ) -> [String: Any] {
        var systemPrompt = system
        var userContent: Any = user

        if jsonMode, !systemPrompt.lowercased().contains("json") {
            systemPrompt += "\n\nRespond with a single valid JSON object."
        }

        if !images.isEmpty {
            var parts: [[String: Any]] = [["type": "text", "text": user]]
            for image in images {
                let dataURL = "data:\(mediaType(for: image));base64,\(image.base64EncodedString())"
                parts.append(["type": "image_url", "image_url": ["url": dataURL]])
            }
            userContent = parts
        }

        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
            "temperature": 0.3,
            "stream": false,
            "max_tokens": maxTokens,
        ]
        if useResponseFormat {
            body["response_format"] = ["type": "json_object"]
        }
        return body
    }

    private static func anthropicBody(
        model: String, system: String, user: String,
        images: [Data], maxTokens: Int
    ) -> [String: Any] {
        var userContent: [[String: Any]] = [["type": "text", "text": user]]
        for image in images {
            userContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": mediaType(for: image),
                    "data": image.base64EncodedString(),
                ],
            ])
        }
        return [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": userContent]],
        ]
    }

    // MARK: - Response Parsing

    private static func parseOpenAIContent(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let choices = json["choices"] as? [[String: Any]], let first = choices.first else { return nil }
        if let message = first["message"] as? [String: Any] {
            // content may be a string or an array of content parts.
            if let content = message["content"] as? String { return content }
            if let parts = message["content"] as? [[String: Any]] {
                return parts.compactMap { $0["text"] as? String }.joined()
            }
        }
        if let text = first["text"] as? String { return text }
        return nil
    }

    private static func parseAnthropicContent(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let content = json["content"] as? [[String: Any]] else { return nil }
        let texts = content.compactMap { block -> String? in
            (block["type"] as? String) == "text" ? block["text"] as? String : nil
        }
        return texts.isEmpty ? nil : texts.joined()
    }

    // MARK: - Media Type Detection

    private static func mediaType(for data: Data) -> String {
        guard let first = data.first else { return "image/jpeg" }
        switch first {
        case 0x89: return "image/png"
        case 0xFF: return "image/jpeg"
        case 0x47: return "image/gif"
        case 0x52: return "image/webp"
        default: return "image/jpeg"
        }
    }
}
