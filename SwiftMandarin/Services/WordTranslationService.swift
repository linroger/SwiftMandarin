//
//  WordTranslationService.swift
//  SwiftMandarin
//
//  Service for translating individual words/phrases using Apple's Translation API
//  Provides per-word translations for word detail popovers
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
        
        // Create translation session for Chinese to English using installed languages
        let session = try await TranslationSession(
            installedSource: Locale.Language(identifier: "zh-Hans"),
            target: Locale.Language(identifier: "en")
        )
        
        let response = try await session.translate(word)
        
        // Cache the result
        translationCache[cacheKey] = response.targetText
        
        return response.targetText
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
        
        // Create translation session for English to Chinese using installed languages
        let session = try await TranslationSession(
            installedSource: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "zh-Hans")
        )
        
        let response = try await session.translate(word)
        
        // Cache the result
        translationCache[cacheKey] = response.targetText
        
        return response.targetText
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
        
        // Create translation session using installed languages
        let session = try await TranslationSession(
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
        
        return results
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
}
