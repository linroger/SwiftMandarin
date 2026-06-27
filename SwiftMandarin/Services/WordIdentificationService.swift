//
//  WordIdentificationService.swift
//  SwiftMandarin
//
//  Uses the configured AI provider to identify the meaningful words and
//  phrases inside a passage of Chinese text — proper word boundaries, pinyin,
//  part of speech, and a concise English meaning. This powers the interactive
//  "tap words for details" view in the AI-translate flow, replacing Apple's
//  NLTokenizer segmentation (which splits Chinese poorly) with the model's
//  understanding of where words actually begin and end.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Identified Word Model

/// A single word or phrase the AI identified in a passage, with the learner
/// aids the ruby view needs. `meaning` is always an English gloss because the
/// word-detail popover surfaces the English definition for a Chinese word in
/// both interface languages.
struct IdentifiedWord: Codable, Identifiable, Hashable {
    var id: String { word }
    let word: String          // the word/phrase exactly as it appears, in order
    let pinyin: String        // Hanyu pinyin with tone marks (empty for punctuation)
    let partOfSpeech: String  // English part-of-speech label
    let meaning: String       // concise English meaning (empty for punctuation)

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

// MARK: - Service

@Observable
@MainActor
final class WordIdentificationService {

    static let shared = WordIdentificationService()

    /// Cache keyed by the exact source text so re-rendering the same
    /// translation never re-calls the model.
    private var cache: [String: [IdentifiedWord]] = [:]

    private init() {}

    /// Cached identification, if any, for an exact passage.
    func cachedWords(for chineseText: String) -> [IdentifiedWord]? {
        cache[chineseText.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    /// Identify the words/phrases in a passage of Chinese text using the
    /// configured AI provider. Returns an ordered list covering the passage.
    ///
    /// - Throws: `AIExplanationError` when no provider is usable or the model
    ///   call fails, so callers can fall back to local segmentation.
    func identifyWords(in chineseText: String) async throws -> [IdentifiedWord] {
        let trimmed = chineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let cached = cache[trimmed] { return cached }

        let settings = AIModelSettings.shared
        guard settings.isAnyProviderAvailable else {
            throw AIExplanationError.unavailable(
                reason: String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).")
            )
        }
        let provider = settings.effectiveProvider

        let system = Self.systemPrompt
        let user = "Chinese text:\n\n\(trimmed)"

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
        cache[trimmed] = result
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
    /// strict JSON object. Meanings are English (the word-detail popover shows
    /// the English gloss for a Chinese word in both interface languages).
    private static let systemPrompt = """
    You segment Chinese (中文) text into the meaningful words and phrases a learner's \
    dictionary would list, in reading order. Return ONLY a single valid JSON object \
    (no markdown, no commentary) of this exact shape:
    {"words":[{"word":"...","pinyin":"...","partOfSpeech":"...","meaning":"..."}]}
    - "word": one word or short phrase, preserving the original order. Together the \
    entries must cover the whole passage. Keep multi-character words intact \
    (e.g. "学习" stays together, never split into "学" + "习"). Keep each punctuation \
    mark as its own entry.
    - "pinyin": Hanyu pinyin with tone marks (ā á ǎ à) matching the word exactly; \
    use an empty string for punctuation.
    - "partOfSpeech": the English part of speech — one of noun, verb, adjective, \
    adverb, pronoun, preposition, conjunction, particle, number, classifier, \
    interjection, punctuation.
    - "meaning": a concise English definition of the word in this context; use an \
    empty string for punctuation.
    JSON only, no commentary.
    """
}
