//
//  ShortcutHelpers.swift
//  SwiftMandarin
//

import Foundation
import AppIntents
import Translation

/// Errors that can occur during shortcut translation
enum ShortcutTranslationError: LocalizedError {
    case translationFailed
    case languageNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .translationFailed:
            return "Unable to translate. Please try again."
        case .languageNotAvailable:
            return "Translation language pack not available. Please check Settings > General > Language & Region."
        }
    }
}

@MainActor
enum ShortcutHelpers {
    static func resolveDirection(for text: String, preferred: ShortcutTranslationDirection) -> TranslationDirection {
        switch preferred {
        case .englishToChinese:
            return .englishToChinese
        case .chineseToEnglish:
            return .chineseToEnglish
        case .auto:
            let detected = ChineseTextAnalyzer.shared.detectLanguage(text)
            if detected.isChinese {
                return .chineseToEnglish
            }
            return .englishToChinese
        }
    }

    static func translate(
        _ text: String,
        direction: TranslationDirection,
        useAI: Bool
    ) async throws -> (translation: String, usedAI: Bool) {
        // Try AI translation first if requested
        if useAI, aiIsAvailable() {
            do {
                let sourceIsChinese = direction == .chineseToEnglish
                let translation = try await aiTranslate(text, sourceIsChinese: sourceIsChinese)
                return (translation, true)
            } catch {
                // Fall through to standard translation if AI fails
            }
        }

        // Use standard Translation framework with retry logic
        return try await translateWithRetry(text, direction: direction, maxRetries: 2)
    }
    
    /// Translate with retry logic to handle intermittent TranslationSession failures.
    /// Before iOS 26 (no standalone `TranslationSession` API) the configured
    /// AI provider is used instead, so the shortcut still works.
    private static func translateWithRetry(
        _ text: String,
        direction: TranslationDirection,
        maxRetries: Int
    ) async throws -> (translation: String, usedAI: Bool) {
        guard #available(iOS 26.0, macOS 26.0, *) else {
            guard aiIsAvailable() else { throw ShortcutTranslationError.translationFailed }
            let translation = try await aiTranslate(text, sourceIsChinese: direction == .chineseToEnglish)
            return (translation, true)
        }

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                // Create a fresh session for each attempt
                let session = TranslationSession(
                    installedSource: direction.sourceLanguage,
                    target: direction.targetLanguage
                )
                let response = try await session.translate(text)
                return (response.targetText, false)
            } catch {
                lastError = error

                // If not the last attempt, wait briefly before retrying
                if attempt < maxRetries {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        }

        // All retries failed
        throw lastError ?? ShortcutTranslationError.translationFailed
    }

    private static func aiIsAvailable() -> Bool {
        // Any configured provider: Apple Intelligence, Ollama, or a cloud provider with a key.
        AIModelSettings.shared.isAnyProviderAvailable
    }

    private static func aiTranslate(_ text: String, sourceIsChinese: Bool) async throws -> String {
        // Use the unified provider method that routes to Apple Intelligence or Ollama
        try await AIWordExplanationService.shared.translateWithProvider(text, sourceIsChinese: sourceIsChinese)
    }

    /// Save a single term to vocabulary (legacy method for compatibility)
    static func saveToVocabularyIfNeeded(
        chinese: String,
        english: String,
        partOfSpeech: String,
        saveAsPhrase: Bool
    ) {
        let trimmedChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChinese.isEmpty, !trimmedEnglish.isEmpty else { return }

        var resolvedPartOfSpeech = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedPartOfSpeech.isEmpty && saveAsPhrase {
            resolvedPartOfSpeech = "phrase"
        }

        let term = SavedTerm(
            chinese: trimmedChinese,
            pinyin: PinyinConverter.convert(trimmedChinese),
            definition: trimmedEnglish,
            partOfSpeech: resolvedPartOfSpeech
        )
        SavedTermsStore.shared.add(term)
    }
    
    /// Segment the passage in the language the user is STUDYING, auto-detect
    /// part of speech, translate each item into their native language, and
    /// save the results to vocabulary (skipping duplicates).
    ///
    /// Both sides of the translation are passed in because which one is worth
    /// capturing depends on the learner, not on the text: an English speaker
    /// studying Mandarin wants the Chinese words, and a Mandarin speaker
    /// studying English wants the English ones. Capturing the wrong side files
    /// away words the user already knows — and, when the Chinese-only
    /// two-character filter met English text, captured nothing at all.
    static func saveStudiedPhrasesToVocabulary(
        chineseText: String,
        englishTranslation: String
    ) {
        if LocalizationManager.shared.learningIsChinese {
            saveChinesePhrases(chineseText: chineseText, englishTranslation: englishTranslation)
        } else {
            saveEnglishPhrases(englishText: englishTranslation, chineseTranslation: chineseText)
        }
    }

    /// English speaker studying Mandarin: capture the Chinese words.
    private static func saveChinesePhrases(
        chineseText: String,
        englishTranslation: String
    ) {
        let trimmedChinese = chineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnglish = englishTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChinese.isEmpty else { return }

        // Segment the Chinese text and get part of speech for each word
        let analyzedWords = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(trimmedChinese)

        // Filter to words with 2+ Chinese characters that aren't already in vocabulary
        let meaningfulWords = analyzedWords.filter { word in
            let chineseCharCount = word.text.filter { $0.isChineseCharacter }.count
            return chineseCharCount >= 2 && !SavedTermsStore.shared.contains(chinese: word.text)
        }

        // If we have meaningful words, translate and save each one
        if !meaningfulWords.isEmpty {
            // Launch async task to translate each word individually
            Task {
                await translateAndSaveWords(meaningfulWords)
            }
        } else {
            // If no segmented words with 2+ chars, save the whole text if it has 2+ Chinese chars
            let chineseCharCount = trimmedChinese.filter { $0.isChineseCharacter }.count
            if chineseCharCount >= 2 && !SavedTermsStore.shared.contains(chinese: trimmedChinese) {
                // Get part of speech for the whole phrase
                let analyzedFull = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(trimmedChinese)
                let pos = analyzedFull.first?.partOfSpeech.displayName.lowercased() ?? "phrase"

                // Use the provided English translation for the full phrase
                let term = SavedTerm(
                    chinese: trimmedChinese,
                    pinyin: PinyinConverter.convert(trimmedChinese),
                    definition: trimmedEnglish,
                    partOfSpeech: pos
                )
                SavedTermsStore.shared.add(term)
            }
        }
    }

    /// Mandarin speaker studying English: capture the English words.
    ///
    /// The mirror of `saveChinesePhrases`, with the two language-specific
    /// details swapped. Chinese needs a length filter because segmentation
    /// yields single characters that are rarely worth saving; English instead
    /// needs a part-of-speech filter, because its tokens are already words and
    /// the noise is function words ("the", "of") rather than fragments.
    /// `SavedTerm.chinese` is the headword slot for whichever language is being
    /// studied, so the English word goes there and 中文 becomes the definition.
    private static func saveEnglishPhrases(
        englishText: String,
        chineseTranslation: String
    ) {
        let trimmedEnglish = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChinese = chineseTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEnglish.isEmpty else { return }

        let contentClasses: Set<EnglishPartOfSpeech> = [.noun, .verb, .adjective, .adverb]
        var seen = Set<String>()
        let meaningfulWords = EnglishTextAnalyzer.shared.analyzeWords(trimmedEnglish).filter { word in
            guard contentClasses.contains(word.partOfSpeech) else { return false }
            let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 3, !SavedTermsStore.shared.contains(chinese: text) else { return false }
            return seen.insert(text.lowercased()).inserted
        }

        if !meaningfulWords.isEmpty {
            Task {
                await translateAndSaveEnglishWords(meaningfulWords)
            }
        } else if !trimmedChinese.isEmpty, !SavedTermsStore.shared.contains(chinese: trimmedEnglish) {
            // Nothing worth isolating — keep the whole phrase with the
            // translation the caller already has, so the action is never a no-op.
            SavedTermsStore.shared.add(
                SavedTerm(
                    chinese: trimmedEnglish,
                    pinyin: "",
                    definition: trimmedChinese,
                    partOfSpeech: "phrase"
                )
            )
        }
    }

    /// Translate each word individually and save to vocabulary
    private static func translateAndSaveWords(_ words: [AnalyzedWord]) async {
        // Extract just the word texts for batch translation
        let wordTexts = words.map { $0.text }

        do {
            // Use batch translation for efficiency
            let translations = try await WordTranslationService.shared.translateBatch(wordTexts, sourceIsChinese: true)

            // Save each word with its individual translation
            for word in words {
                // Skip if already in vocabulary (double-check in case of race condition)
                guard !SavedTermsStore.shared.contains(chinese: word.text) else { continue }

                let definition = translations[word.text] ?? word.text // Fallback to original if translation fails

                let term = SavedTerm(
                    chinese: word.text,
                    pinyin: PinyinConverter.convert(word.text),
                    definition: definition,
                    partOfSpeech: word.partOfSpeech.displayName.lowercased()
                )
                SavedTermsStore.shared.add(term)
            }
        } catch {
            // If batch translation fails, try translating one by one
            for word in words {
                guard !SavedTermsStore.shared.contains(chinese: word.text) else { continue }

                do {
                    let definition = try await WordTranslationService.shared.translateToEnglish(word.text)

                    let term = SavedTerm(
                        chinese: word.text,
                        pinyin: PinyinConverter.convert(word.text),
                        definition: definition,
                        partOfSpeech: word.partOfSpeech.displayName.lowercased()
                    )
                    SavedTermsStore.shared.add(term)
                } catch {
                    // Skip this word if translation fails
                    continue
                }
            }
        }
    }

    /// The mirror of `translateAndSaveWords`: English headwords glossed into
    /// Mandarin. No pinyin is stored — the headword is English, and the
    /// pronunciation slot is filled by an AI explanation (as IPA) if the user
    /// asks for one.
    private static func translateAndSaveEnglishWords(_ words: [AnalyzedEnglishWord]) async {
        let wordTexts = words.map(\.text)

        let translations: [String: String]
        do {
            translations = try await WordTranslationService.shared.translateBatch(
                wordTexts,
                sourceIsChinese: false
            )
        } catch {
            translations = [:]
        }

        for word in words {
            guard !SavedTermsStore.shared.contains(chinese: word.text) else { continue }

            var definition = translations[word.text] ?? ""
            if definition.isEmpty {
                definition = (try? await WordTranslationService.shared.translateToChinese(word.text)) ?? ""
            }
            // A headword with no gloss is not a vocabulary entry, so drop it
            // rather than saving a half-empty row the learner must fix by hand.
            guard !definition.isEmpty else { continue }

            SavedTermsStore.shared.add(
                SavedTerm(
                    chinese: word.text,
                    pinyin: "",
                    definition: definition,
                    partOfSpeech: word.partOfSpeech.rawValue
                )
            )
        }
    }
}
