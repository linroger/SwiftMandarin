//
//  WordIdentificationService.swift
//  SwiftMandarin
//
//  Uses the configured AI provider to identify the meaningful words and
//  phrases inside a passage — proper word boundaries, a reading, part of
//  speech, and a concise meaning in the learner's own language. This powers
//  the interactive "tap words for details" view in the AI-translate flow,
//  replacing Apple's NLTokenizer segmentation (which splits Chinese poorly)
//  with the model's understanding of where words actually begin and end.
//
//  Both directions are served by one contract. For a Chinese passage the
//  reading is Hanyu pinyin and the units are multi-character words; for an
//  English passage the reading is IPA and the units are the phrasal verbs and
//  idioms a learner's dictionary would list rather than bare tokens. The
//  meaning is always written in the learner's NATIVE language, so a Mandarin
//  speaker studying English reads 中文 glosses.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Identified Word Model

/// A single word or phrase the AI identified in a passage, with the learner
/// aids the ruby view needs. `meaning` is written in the learner's NATIVE
/// language, so the word-detail popover always glosses the studied word in a
/// language the reader already knows.
struct IdentifiedWord: Codable, Identifiable, Hashable {
    var id: String { word }
    let word: String          // the word/phrase exactly as it appears, in order
    /// The reading: Hanyu pinyin with tone marks for a Chinese word, IPA with
    /// primary stress for an English one. Empty for punctuation.
    let pinyin: String
    let partOfSpeech: String  // English part-of-speech label (a stable key, not display text)
    let meaning: String       // concise meaning in the learner's native language (empty for punctuation)

    init(word: String, pinyin: String, partOfSpeech: String, meaning: String) {
        self.word = word
        self.pinyin = pinyin
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
    }

    /// Tolerant decode: models routinely omit one of the optional fields, so a
    /// missing `pinyin`/`partOfSpeech`/`meaning` must not fail the whole parse.
    /// Only `word` is required.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        word = try c.decode(String.self, forKey: .word)
        pinyin = (try? c.decode(String.self, forKey: .pinyin)) ?? ""
        partOfSpeech = (try? c.decode(String.self, forKey: .partOfSpeech)) ?? ""
        meaning = (try? c.decode(String.self, forKey: .meaning)) ?? ""
    }
}

/// Wrapper matching the `{"words":[…]}` JSON shape the model returns.
struct IdentifiedWordsResponse: Codable {
    let words: [IdentifiedWord]
}

// MARK: - Direction

/// Which language is being segmented and which language the glosses are
/// written in. Kept Foundation-only so the exact prompts stay testable.
struct WordIdentificationContext: Equatable, Sendable {
    /// Whether the passage being segmented is Chinese.
    let textIsChinese: Bool
    /// Whether the learner's native language — the interface language — is
    /// Chinese, which is the language every gloss is written in.
    let explainInChinese: Bool

    @MainActor
    static func current(forText text: String) -> WordIdentificationContext {
        WordIdentificationContext(
            textIsChinese: text.containsCJK,
            explainInChinese: LocalizationManager.shared.nativeIsChinese
        )
    }

    /// Distinguishes cached segmentations per direction, so switching the
    /// interface language re-glosses the passage instead of serving the old
    /// language's meanings back.
    var cacheToken: String {
        "\(textIsChinese ? "zh" : "en")>\(explainInChinese ? "zh" : "en")"
    }
}

// MARK: - Service

@Observable
@MainActor
final class WordIdentificationService {

    static let shared = WordIdentificationService()

    /// Cache keyed by the exact source text *and* the learning direction, so
    /// re-rendering the same translation never re-calls the model but changing
    /// the interface language does not serve back glosses in the old language.
    private var cache: [String: [IdentifiedWord]] = [:]

    private init() {}

    private static func cacheKey(_ text: String, _ context: WordIdentificationContext) -> String {
        "\(context.cacheToken)|\(text)"
    }

    /// Cached identification, if any, for an exact passage in the current
    /// learning direction.
    func cachedWords(for text: String) -> [IdentifiedWord]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cache[Self.cacheKey(trimmed, .current(forText: trimmed))]
    }

    /// Identify the words/phrases in a passage using the configured AI
    /// provider. Returns an ordered list covering the passage, segmented for
    /// whichever language the passage is in and glossed in the learner's own
    /// language.
    ///
    /// - Throws: `AIExplanationError` when no provider is usable or the model
    ///   call fails, so callers can fall back to local segmentation.
    func identifyWords(in text: String) async throws -> [IdentifiedWord] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let context = WordIdentificationContext.current(forText: trimmed)
        let key = Self.cacheKey(trimmed, context)
        if let cached = cache[key] { return cached }

        let settings = AIModelSettings.shared
        guard settings.isAnyProviderAvailable else {
            throw AIExplanationError.unavailable(
                reason: String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).", bundle: .appLanguage)
            )
        }
        let provider = settings.effectiveProvider

        let system = Self.systemPrompt(for: context)
        let user = "\(context.textIsChinese ? "Chinese" : "English") text:\n\n\(trimmed)"

        let json: String
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), AIWordExplanationService.shared.isAvailable else {
                throw AIExplanationError.unavailable(
                    reason: AIWordExplanationService.shared.unavailabilityReason ?? "Apple Intelligence unavailable"
                )
            }
            let session = LanguageModelSession(instructions: system)
            json = try await session.respond(to: user).content
            #else
            throw AIExplanationError.unavailable(reason: "FoundationModels framework not available")
            #endif
        case .ollama:
            guard OllamaService.shared.isConnected, !settings.ollamaModel.isEmpty else {
                throw AIExplanationError.ollamaNotConnected
            }
            let (content, _) = try await OllamaService.shared.chat(
                model: settings.ollamaModel,
                systemPrompt: system,
                userPrompt: user,
                enableThinking: false
            )
            json = content
        default:
            let model = settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else {
                throw AIExplanationError.unavailable(reason: "No API key/model for \(provider.displayName)")
            }
            json = try await CloudAIService.shared.chat(
                provider: provider,
                model: model,
                system: system,
                user: user,
                jsonMode: true,
                maxTokens: 2048
            )
        }

        guard let data = AIWordExplanationService.extractJSONObject(from: json) else {
            throw AIExplanationError.generationFailed("No JSON object found in response")
        }
        let decoded = try JSONDecoder().decode(IdentifiedWordsResponse.self, from: data)
        let words = decoded.words.filter {
            !$0.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Coverage guard: the identified words, concatenated, must reconstruct
        // the source text (ignoring whitespace). If the model dropped, added, or
        // paraphrased characters, the segments would render Chinese that differs
        // from the actual translation — so discard them and let the caller fall
        // back to local segmentation. The empty result is still cached, so we
        // don't re-call the model for the same text.
        let result = Self.reconstructs(words, source: trimmed) ? words : []
        cache[key] = result
        return result
    }

    /// Whether the concatenated identified words equal the source text once all
    /// whitespace is removed from both sides.
    private static func reconstructs(_ words: [IdentifiedWord], source: String) -> Bool {
        guard !words.isEmpty else { return false }
        let strip: (String) -> String = { s in
            s.components(separatedBy: .whitespacesAndNewlines).joined()
        }
        return strip(words.map(\.word).joined()) == strip(source)
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Prompt

    /// Provider-agnostic instruction asking for ordered word segmentation as a
    /// strict JSON object, in whichever direction the learner is going.
    ///
    /// The two branches differ in exactly the ways the languages differ: what
    /// counts as one dictionary entry (a multi-character Chinese word vs. an
    /// English phrasal verb or idiom), which reading system to use (pinyin vs.
    /// IPA), and which part-of-speech inventory applies. Everything else —
    /// order, full coverage, punctuation as its own entry, and glosses in the
    /// learner's native language — is shared, so the interactive reader
    /// behaves identically for both audiences.
    static func systemPrompt(for context: WordIdentificationContext) -> String {
        let glossLanguage = context.explainInChinese ? "Simplified Chinese (简体中文)" : "English"

        let sourceLanguage: String
        let unitRule: String
        let readingRule: String
        let partOfSpeechRule: String

        if context.textIsChinese {
            sourceLanguage = "Chinese (中文)"
            unitRule = """
            Keep multi-character words intact (e.g. "学习" stays together, never split into \
            "学" + "习"), and keep a set phrase or chengyu as one entry.
            """
            readingRule = """
            Hanyu pinyin with tone marks (ā á ǎ à) matching the word exactly; use an empty \
            string for punctuation.
            """
            partOfSpeechRule = """
            one of noun, verb, adjective, adverb, pronoun, preposition, conjunction, \
            particle, number, classifier, interjection, punctuation.
            """
        } else {
            sourceLanguage = "English"
            unitRule = """
            Keep a phrasal verb, idiom, or fixed collocation together as ONE entry \
            (e.g. "give up" stays together, never split into "give" + "up"), because that \
            is what a learner's dictionary lists. Keep a contraction as written.
            """
            readingRule = """
            IPA between slashes with the primary stress marked, e.g. /kəˈmɪt/, matching the \
            word exactly; use an empty string for punctuation.
            """
            partOfSpeechRule = """
            one of noun, verb, adjective, adverb, pronoun, preposition, conjunction, \
            determiner, number, interjection, punctuation.
            """
        }

        return """
        You segment \(sourceLanguage) text into the meaningful words and phrases a learner's \
        dictionary would list, in reading order. Return ONLY a single valid JSON object \
        (no markdown, no commentary) of this exact shape:
        {"words":[{"word":"...","pinyin":"...","partOfSpeech":"...","meaning":"..."}]}
        - "word": one word or short phrase, preserving the original order and the original \
        spelling exactly. Together the entries must cover the whole passage with nothing \
        added, dropped, or reworded. \(unitRule) Keep each punctuation mark as its own entry.
        - "pinyin": \(readingRule)
        - "partOfSpeech": the English part-of-speech label — \(partOfSpeechRule)
        - "meaning": a concise definition of the word in this context, written in \
        \(glossLanguage) — the learner's own language; use an empty string for punctuation.
        JSON only, no commentary.
        """
    }
}
