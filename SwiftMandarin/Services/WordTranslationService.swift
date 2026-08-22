//
//  WordTranslationService.swift
//  SwiftMandarin
//
//  Service for translating individual words/phrases using Apple's Translation
//  API (iOS 18+/macOS 15+). On older systems it falls back to the configured
//  AI provider, so word lookups keep working on iOS 17.
//

import Foundation
import Translation

/// Service for translating individual words using Apple's Translation API
@Observable
final class WordTranslationService {

    static let shared = WordTranslationService()

    /// Cache for translated words to avoid repeated API calls
    private var translationCache: [String: String] = [:]

    private init() {}

    // MARK: - Public Methods

    /// Translate a single word or phrase from Chinese to English
    /// Uses installed language packs (requires languages to be pre-downloaded)
    /// - Parameter word: The Chinese word/phrase to translate
    /// - Returns: The English translation
    func translateToEnglish(_ word: String) async throws -> String {
        // Check cache first
        let cacheKey = "zh-en:\(word)"
        if let cached = translationCache[cacheKey] {
            return cached
        }

        let translation = try await systemOrAITranslate(word, sourceIsChinese: true)
        translationCache[cacheKey] = translation
        return translation
    }

    /// Translate a single word or phrase from English to Chinese
    /// Uses installed language packs (requires languages to be pre-downloaded)
    /// - Parameter word: The English word/phrase to translate
    /// - Returns: The Chinese translation
    func translateToChinese(_ word: String) async throws -> String {
        // Check cache first
        let cacheKey = "en-zh:\(word)"
        if let cached = translationCache[cacheKey] {
            return cached
        }

        let translation = try await systemOrAITranslate(word, sourceIsChinese: false)
        translationCache[cacheKey] = translation
        return translation
    }

    /// Translate a word with automatic language detection
    /// - Parameters:
    ///   - word: The word to translate
    ///   - sourceIsChinese: Whether the source word is Chinese
    /// - Returns: The translated word in the opposite language
    func translate(_ word: String, sourceIsChinese: Bool) async throws -> String {
        if sourceIsChinese {
            return try await translateToEnglish(word)
        } else {
            return try await translateToChinese(word)
        }
    }

    /// Batch translate multiple words (more efficient for multiple lookups)
    /// - Parameters:
    ///   - words: Array of words to translate
    ///   - sourceIsChinese: Whether source words are Chinese
    /// - Returns: Dictionary mapping original words to translations
    func translateBatch(_ words: [String], sourceIsChinese: Bool) async throws -> [String: String] {
        var results: [String: String] = [:]
        var wordsToTranslate: [String] = []

        // Check cache first
        let cachePrefix = sourceIsChinese ? "zh-en:" : "en-zh:"
        for word in words {
            let cacheKey = "\(cachePrefix)\(word)"
            if let cached = translationCache[cacheKey] {
                results[word] = cached
            } else {
                wordsToTranslate.append(word)
            }
        }

        // Return early if all words were cached
        if wordsToTranslate.isEmpty {
            return results
        }

        if #available(iOS 26.0, macOS 26.0, *) {
            do {
                // Create translation session using installed languages
                let session = TranslationSession(
                    installedSource: sourceIsChinese ? Locale.Language(identifier: "zh-Hans") : Locale.Language(identifier: "en"),
                    target: sourceIsChinese ? Locale.Language(identifier: "en") : Locale.Language(identifier: "zh-Hans")
                )

                // Create batch requests with client identifiers for matching
                var requests: [TranslationSession.Request] = []
                for (index, word) in wordsToTranslate.enumerated() {
                    requests.append(TranslationSession.Request(
                        sourceText: word,
                        clientIdentifier: "\(index)"
                    ))
                }

                // Perform batch translation
                let responses = try await session.translations(from: requests)

                // Process responses and update cache
                for response in responses {
                    if let clientId = response.clientIdentifier,
                       let index = Int(clientId),
                       index < wordsToTranslate.count {
                        let originalWord = wordsToTranslate[index]
                        let translation = response.targetText

                        results[originalWord] = translation
                        translationCache["\(cachePrefix)\(originalWord)"] = translation
                    }
                }
            } catch {
                // Same missing-language-pack condition as the single-word
                // path: fall back to the AI provider rather than failing the
                // whole batch, when one is configured.
                guard AIModelSettings.shared.isAnyProviderAvailable else { throw error }
                try await mergeAITranslations(of: wordsToTranslate, sourceIsChinese: sourceIsChinese, into: &results)
            }
        } else {
            try await mergeAITranslations(of: wordsToTranslate, sourceIsChinese: sourceIsChinese, into: &results)
        }

        return results
    }

    /// Translate sequentially through the configured AI provider (each result
    /// is cached, so repeat lookups are free), merging into `results`.
    private func mergeAITranslations(
        of words: [String],
        sourceIsChinese: Bool,
        into results: inout [String: String]
    ) async throws {
        let cachePrefix = sourceIsChinese ? "zh-en:" : "en-zh:"
        for word in words {
            let translation = try await aiTranslate(word, sourceIsChinese: sourceIsChinese)
            guard !translation.isEmpty else { continue }
            results[word] = translation
            translationCache["\(cachePrefix)\(word)"] = translation
        }
    }

    /// Clear the translation cache
    func clearCache() {
        translationCache.removeAll()
    }

    /// Get cached translation if available
    func getCachedTranslation(for word: String, sourceIsChinese: Bool) -> String? {
        let cacheKey = sourceIsChinese ? "zh-en:\(word)" : "en-zh:\(word)"
        return translationCache[cacheKey]
    }

    // MARK: - Backend Selection

    /// Apple's on-device Translation API where available (iOS 26+/macOS 26+;
    /// the standalone session initializer is newer than the SwiftUI task API),
    /// otherwise the user's configured AI provider.
    private func systemOrAITranslate(_ text: String, sourceIsChinese: Bool) async throws -> String {
        if #available(iOS 26.0, macOS 26.0, *) {
            do {
                let session = TranslationSession(
                    installedSource: Locale.Language(identifier: sourceIsChinese ? "zh-Hans" : "en"),
                    target: Locale.Language(identifier: sourceIsChinese ? "en" : "zh-Hans")
                )
                let response = try await session.translate(text)
                return response.targetText
            } catch {
                // The installed-languages session throws whenever the language
                // pack isn't downloaded. That's a device-setup condition, not a
                // reason to fail the lookup — route through the configured AI
                // provider like pre-iOS 26 does. Only rethrow when no provider
                // exists to fall back to.
                guard AIModelSettings.shared.isAnyProviderAvailable else { throw error }
                return try await aiTranslate(text, sourceIsChinese: sourceIsChinese)
            }
        } else {
            return try await aiTranslate(text, sourceIsChinese: sourceIsChinese)
        }
    }

    /// Word translation via the user's configured AI provider.
    private func aiTranslate(_ text: String, sourceIsChinese: Bool) async throws -> String {
        try await AIWordExplanationService.shared
            .translateWithProvider(text, sourceIsChinese: sourceIsChinese)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
