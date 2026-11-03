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
    /// iOS 26 or later, but the language pack is not installed.
    case languageNotAvailable
    /// Before iOS 26 there is no standalone `TranslationSession` at all.
    case systemTranslationRequiresNewerOS

    // Both on-device messages surface only when no AI provider is configured
    // (with one, `translate` falls back to it), so they point at adding one
    // rather than at the shortcut's Use AI Provider switch.
    var errorDescription: String? {
        switch self {
        case .translationFailed:
            return String(localized: "Unable to translate. Please try again.", bundle: .appLanguage)
        case .languageNotAvailable:
            return String(localized: "Apple's on-device translation isn't available for this language pair on this device. Download the languages in the Translate settings, or add an AI provider in SwiftMandarin's settings to translate with Shortcuts.", bundle: .appLanguage)
        case .systemTranslationRequiresNewerOS:
            return String(localized: "This version of iOS can't translate on-device. Add an AI provider in SwiftMandarin's settings to translate with Shortcuts.", bundle: .appLanguage)
        }
    }
}

@MainActor
enum ShortcutHelpers {
    /// The direction Siri should translate in.
    ///
    /// Auto uses the detector the app itself trusts: a plain
    /// `NLLanguageRecognizer` reads short Chinese as Japanese and pinyin as
    /// English. When even that cannot tell, the learner's default direction
    /// wins — the old rule assumed English input, which is backwards for a
    /// Mandarin speaker studying English.
    static func resolveDirection(for text: String, preferred: ShortcutTranslationDirection) -> TranslationDirection {
        switch preferred {
        case .englishToChinese:
            return .englishToChinese
        case .chineseToEnglish:
            return .chineseToEnglish
        case .auto:
            switch ChineseTextAnalyzer.shared.detectLanguageRobust(text) {
            case .chinese: return .chineseToEnglish
            case .english: return .englishToChinese
            default: return TranslationDirection.persistedDefault
            }
        }
    }

    /// Translate for a Shortcut.
    ///
    /// With `useAI` on, the configured provider is tried first and Apple's
    /// on-device translation is the fallback. With it off, on-device
    /// translation goes first, and when it cannot run here — before iOS 26,
    /// a missing language pack, or a failing session — a configured provider
    /// translates instead, with `usedAI` set so the dialog says so. Voice
    /// phrases cannot turn `useAI` on, so without this fallback every spoken
    /// translate request failed on iOS 17–25. Only when no provider is
    /// configured does the on-device failure reach the learner.
    static func translate(
        _ text: String,
        direction: TranslationDirection,
        useAI: Bool
    ) async throws -> (translation: String, usedAI: Bool) {
        let sourceIsChinese = direction == .chineseToEnglish
        let providerConfigured = aiIsAvailable()

        // Kept so that when both routes fail, the learner hears why the
        // provider they asked for failed, not advice about on-device packs.
        var providerError: Error?
        if useAI, providerConfigured {
            do {
                let translation = try await aiTranslate(text, sourceIsChinese: sourceIsChinese)
                return (translation, true)
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                providerError = error
            }
        }

        do {
            let translation = try await translateWithSystem(text, direction: direction, maxRetries: 2)
            return (translation, false)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            if let providerError { throw providerError }
            guard providerConfigured else { throw error }
            let translation = try await aiTranslate(text, sourceIsChinese: sourceIsChinese)
            return (translation, true)
        }
    }

    /// Apple's on-device translation, retried for intermittent session
    /// failures.
    ///
    /// Throws `.systemTranslationRequiresNewerOS` before iOS 26 (there is no
    /// standalone `TranslationSession`), `.languageNotAvailable` when the
    /// language pack is missing, `CancellationError` when the shortcut is
    /// cancelled, and otherwise the session's own error — so a cancellation or
    /// an internal failure is never reported as a pack to download.
    /// `translate` decides whether a configured provider takes over.
    private static func translateWithSystem(
        _ text: String,
        direction: TranslationDirection,
        maxRetries: Int
    ) async throws -> String {
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw ShortcutTranslationError.systemTranslationRequiresNewerOS
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
                return response.targetText
            } catch {
                if error is CancellationError || Task.isCancelled {
                    throw CancellationError()
                }
                // A missing pack fails identically on every attempt, so
                // retrying would only delay the message.
                if isMissingLanguagePack(error) {
                    throw ShortcutTranslationError.languageNotAvailable
                }
                lastError = error
                if attempt < maxRetries {
                    // Throwing sleep: a cancellation here ends the retries.
                    try await Task.sleep(for: .milliseconds(200))
                }
            }
        }

        throw lastError ?? ShortcutTranslationError.translationFailed
    }

    /// The session errors that mean the zh/en pack is not on this device — a
    /// setup condition the learner can fix, unlike an internal failure.
    @available(iOS 26.0, macOS 26.0, *)
    private static func isMissingLanguagePack(_ error: Error) -> Bool {
        switch error {
        case TranslationError.notInstalled,
             TranslationError.unsupportedSourceLanguage,
             TranslationError.unsupportedTargetLanguage,
             TranslationError.unsupportedLanguagePairing:
            return true
        default:
            return false
        }
    }

    private static func aiIsAvailable() -> Bool {
        // Any configured provider: Apple Intelligence, Ollama, or a cloud provider with a key.
        AIModelSettings.shared.isAnyProviderAvailable
    }

    private static func aiTranslate(_ text: String, sourceIsChinese: Bool) async throws -> String {
        // Use the unified provider method that routes to Apple Intelligence or Ollama
        try await AIWordExplanationService.shared.translateWithProvider(text, sourceIsChinese: sourceIsChinese)
    }

    /// Write what an intent just changed before it returns. Store saves are
    /// deferred by 250 ms, and an intent run in the background gets no
    /// scene-phase change to flush them, while its process can be suspended
    /// the moment `perform()` returns — so a term the dialog called saved
    /// could be gone on the next launch.
    static func persistIntentChanges() {
        PersistentCodableStore.flushPendingWritesNow()
    }

    /// Save one Chinese/English pair as a vocabulary entry, with the side in
    /// the language being learned as the headword — the same rule every
    /// in-app save follows. Returns `false` when a side is missing or the
    /// entry already exists under either side, so a caller can say "already
    /// saved" instead of "saved".
    @discardableResult
    static func saveTermIfNeeded(
        chineseSide: String,
        englishSide: String,
        partOfSpeech: String
    ) -> Bool {
        let chinese = chineseSide.trimmingCharacters(in: .whitespacesAndNewlines)
        let english = englishSide.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chinese.isEmpty, !english.isEmpty else { return false }

        let learningChinese = LocalizationManager.shared.learningIsChinese
        let headword = learningChinese ? chinese : english
        let gloss = learningChinese ? english : chinese
        let store = SavedTermsStore.shared
        // The headword slot holds either language, so an entry saved from the
        // other direction has the gloss where this one has the headword.
        guard !store.contains(chinese: headword), !store.contains(chinese: gloss) else { return false }

        store.add(
            SavedTerm(
                chinese: headword,
                pinyin: learningChinese ? PinyinConverter.convert(chinese) : "",
                definition: gloss,
                partOfSpeech: partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        return true
    }

    /// What one Save to Vocabulary run did. `skipped` counts the new words it
    /// found but did not save — past the per-run cap or with no translation —
    /// so the dialog does not imply the whole passage was captured.
    struct VocabularySaveOutcome {
        var saved = 0
        var skipped = 0
    }

    /// How many words one run translates while the intent waits. Each word can
    /// cost an AI round trip (the batch is sequential when the provider does
    /// the work), and Siri gives up on an intent long before a 30-word
    /// paragraph finishes — the learner then never hears the translation they
    /// asked for. The first words in reading order are kept, which is also the
    /// order the learner met them in.
    private static let maxWordsSavedPerRun = 12

    /// Segment the passage in the language the user is STUDYING, auto-detect
    /// part of speech, translate each item into their native language, and
    /// save the results to vocabulary (skipping duplicates), at most
    /// `maxWordsSavedPerRun` words per run.
    ///
    /// Awaited by the intent rather than fired off: an App Intent's process
    /// can be suspended the moment `perform()` returns, and a detached save
    /// used to be cut off there while the dialog still said "complete".
    ///
    /// Both sides of the translation are passed in because which one is worth
    /// capturing depends on the learner, not on the text: an English speaker
    /// studying Mandarin wants the Chinese words, and a Mandarin speaker
    /// studying English wants the English ones.
    static func saveStudiedPhrasesToVocabulary(
        chineseText: String,
        englishTranslation: String
    ) async -> VocabularySaveOutcome {
        if LocalizationManager.shared.learningIsChinese {
            return await saveChinesePhrases(chineseText: chineseText, englishTranslation: englishTranslation)
        } else {
            return await saveEnglishPhrases(englishText: englishTranslation, chineseTranslation: chineseText)
        }
    }

    /// English speaker studying Mandarin: capture the Chinese words.
    private static func saveChinesePhrases(
        chineseText: String,
        englishTranslation: String
    ) async -> VocabularySaveOutcome {
        let trimmedChinese = chineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnglish = englishTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChinese.isEmpty else { return VocabularySaveOutcome() }

        // Segment the Chinese text and get part of speech for each word
        let analyzedWords = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(trimmedChinese)

        // Words with 2+ Chinese characters that aren't already in vocabulary,
        // each once — a repeat would spend one of the capped slots on a word
        // the first occurrence already saves.
        var seen = Set<String>()
        let meaningfulWords = analyzedWords.filter { word in
            let chineseCharCount = word.text.filter { $0.isChineseCharacter }.count
            guard chineseCharCount >= 2, !SavedTermsStore.shared.contains(chinese: word.text) else { return false }
            return seen.insert(word.text).inserted
        }

        if !meaningfulWords.isEmpty {
            let attempted = Array(meaningfulWords.prefix(maxWordsSavedPerRun))
            var outcome = await translateAndSaveWords(attempted)
            outcome.skipped += meaningfulWords.count - attempted.count
            return outcome
        }

        // No segmented words with 2+ chars: save the whole text if it has 2+
        // Chinese chars, with the translation the caller already has.
        let chineseCharCount = trimmedChinese.filter { $0.isChineseCharacter }.count
        guard chineseCharCount >= 2,
              !trimmedEnglish.isEmpty,
              !SavedTermsStore.shared.contains(chinese: trimmedChinese) else { return VocabularySaveOutcome() }
        let pos = analyzedWords.first?.partOfSpeech.displayName.lowercased() ?? "phrase"
        SavedTermsStore.shared.add(
            SavedTerm(
                chinese: trimmedChinese,
                pinyin: PinyinConverter.convert(trimmedChinese),
                definition: trimmedEnglish,
                partOfSpeech: pos
            )
        )
        return VocabularySaveOutcome(saved: 1)
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
    ) async -> VocabularySaveOutcome {
        let trimmedEnglish = englishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChinese = chineseTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEnglish.isEmpty else { return VocabularySaveOutcome() }

        let contentClasses: Set<EnglishPartOfSpeech> = [.noun, .verb, .adjective, .adverb]
        var seen = Set<String>()
        let meaningfulWords = EnglishTextAnalyzer.shared.analyzeWords(trimmedEnglish).filter { word in
            guard contentClasses.contains(word.partOfSpeech) else { return false }
            let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 3, !SavedTermsStore.shared.contains(chinese: text) else { return false }
            return seen.insert(text.lowercased()).inserted
        }

        if !meaningfulWords.isEmpty {
            let attempted = Array(meaningfulWords.prefix(maxWordsSavedPerRun))
            var outcome = await translateAndSaveEnglishWords(attempted)
            outcome.skipped += meaningfulWords.count - attempted.count
            return outcome
        }

        // Nothing worth isolating — keep the whole phrase with the
        // translation the caller already has, so the action is never a no-op.
        guard !trimmedChinese.isEmpty, !SavedTermsStore.shared.contains(chinese: trimmedEnglish) else { return VocabularySaveOutcome() }
        SavedTermsStore.shared.add(
            SavedTerm(
                chinese: trimmedEnglish,
                pinyin: "",
                definition: trimmedChinese,
                partOfSpeech: "phrase"
            )
        )
        return VocabularySaveOutcome(saved: 1)
    }

    /// Translate each word individually and save to vocabulary. A word whose
    /// translation fails is skipped: storing a word as its own definition
    /// made entries the learner had to fix by hand.
    ///
    /// Only a word missing from a batch that succeeded gets its own request.
    /// When the batch itself throws (provider down, no pack), the per-word
    /// requests would fail the same way one slow round trip at a time, while
    /// the intent — and Siri — waits.
    private static func translateAndSaveWords(_ words: [AnalyzedWord]) async -> VocabularySaveOutcome {
        let wordTexts = words.map { $0.text }
        let batch = try? await WordTranslationService.shared.translateBatch(wordTexts, sourceIsChinese: true)

        var outcome = VocabularySaveOutcome()
        for word in words {
            // Skip if already in vocabulary (double-check in case of race condition)
            guard !SavedTermsStore.shared.contains(chinese: word.text) else { continue }

            var definition = batch?[word.text] ?? ""
            if definition.isEmpty, batch != nil {
                definition = (try? await WordTranslationService.shared.translateToEnglish(word.text)) ?? ""
            }
            guard !definition.isEmpty else {
                outcome.skipped += 1
                continue
            }

            SavedTermsStore.shared.add(
                SavedTerm(
                    chinese: word.text,
                    pinyin: PinyinConverter.convert(word.text),
                    definition: definition,
                    partOfSpeech: word.partOfSpeech.displayName.lowercased()
                )
            )
            outcome.saved += 1
        }
        return outcome
    }

    /// The mirror of `translateAndSaveWords`: English headwords glossed into
    /// Mandarin. No pinyin is stored — the headword is English, and the
    /// pronunciation slot is filled by an AI explanation (as IPA) if the user
    /// asks for one. A failed batch is not retried word by word, for the same
    /// reason.
    private static func translateAndSaveEnglishWords(_ words: [AnalyzedEnglishWord]) async -> VocabularySaveOutcome {
        let wordTexts = words.map(\.text)
        let batch = try? await WordTranslationService.shared.translateBatch(wordTexts, sourceIsChinese: false)

        var outcome = VocabularySaveOutcome()
        for word in words {
            guard !SavedTermsStore.shared.contains(chinese: word.text) else { continue }

            var definition = batch?[word.text] ?? ""
            if definition.isEmpty, batch != nil {
                definition = (try? await WordTranslationService.shared.translateToChinese(word.text)) ?? ""
            }
            // A headword with no gloss is not a vocabulary entry, so drop it
            // rather than saving a half-empty row the learner must fix by hand.
            guard !definition.isEmpty else {
                outcome.skipped += 1
                continue
            }

            SavedTermsStore.shared.add(
                SavedTerm(
                    chinese: word.text,
                    pinyin: "",
                    definition: definition,
                    partOfSpeech: word.partOfSpeech.rawValue
                )
            )
            outcome.saved += 1
        }
        return outcome
    }

    /// The dialog Siri speaks after a translation — the translation itself,
    /// not a status line, plus a notice when the route differs from the one
    /// the shortcut asked for, and the save count when it applies. Siri reads
    /// only the dialog, so a result value alone left voice users hearing
    /// "Translation complete." and nothing else. The provider notice matters
    /// most: text the learner did not choose to send left the device.
    static func translationDialog(
        translation: String,
        requestedAI: Bool,
        usedAI: Bool,
        saveOutcome: VocabularySaveOutcome?
    ) -> IntentDialog {
        var parts: [String] = []
        if requestedAI, !usedAI {
            parts.append(String(localized: "The AI provider wasn't available, so SwiftMandarin used standard translation.", bundle: .appLanguage))
        } else if !requestedAI, usedAI {
            parts.append(String(localized: "On-device translation isn't available here, so SwiftMandarin used your AI provider.", bundle: .appLanguage))
        }
        parts.append(translation)
        if let saveOutcome {
            parts.append(
                saveOutcome.saved == 1
                    ? String(localized: "Saved 1 word to vocabulary.", bundle: .appLanguage)
                    : String(format: String(localized: "Saved %lld words to vocabulary.", bundle: .appLanguage), Int64(saveOutcome.saved))
            )
            if saveOutcome.skipped > 0 {
                parts.append(
                    saveOutcome.skipped == 1
                        ? String(localized: "1 other word wasn't saved.", bundle: .appLanguage)
                        : String(format: String(localized: "%lld other words weren't saved.", bundle: .appLanguage), Int64(saveOutcome.skipped))
                )
            }
        }
        return IntentDialog(stringLiteral: parts.joined(separator: " "))
    }
}
