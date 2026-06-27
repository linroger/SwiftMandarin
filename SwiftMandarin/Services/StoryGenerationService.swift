//
//  StoryGenerationService.swift
//  SwiftMandarin
//
//  Uses the configured AI provider to write a short graded story in the
//  learner's LEARNING language, preferentially built from words the learner
//  has already saved — so Reader material is comprehensible input rather than
//  a wall of unknowns. Provider dispatch mirrors WordIdentificationService.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Story Level

/// Difficulty of the generated story, controlling vocabulary, sentence
/// complexity, and length.
enum StoryLevel: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    /// Localized display name for pickers.
    @MainActor
    var displayName: String {
        switch self {
        case .beginner: return L("Beginner")
        case .intermediate: return L("Intermediate")
        case .advanced: return L("Advanced")
        }
    }

    /// Prompt guidance: sentence complexity and target length. Chinese length
    /// is stated in characters (the natural unit for 中文 graded readers).
    fileprivate func guidance(inChinese: Bool) -> String {
        let unit = inChinese ? "Chinese characters" : "words"
        switch self {
        case .beginner:
            return "Use very simple, short sentences (one clause each) and only high-frequency everyday vocabulary. Length: about 150–200 \(unit)."
        case .intermediate:
            return "Use everyday vocabulary with some common idioms and moderately complex sentences. Length: about 250–300 \(unit)."
        case .advanced:
            return "Use rich vocabulary and varied, natural sentence structures. Length: about 350–400 \(unit)."
        }
    }
}

// MARK: - Errors

enum StoryGenerationError: LocalizedError {
    case unavailable(reason: String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .generationFailed(let message):
            return String(localized: "Story generation failed: \(message)")
        }
    }
}

// MARK: - Service

@MainActor
final class StoryGenerationService {

    static let shared = StoryGenerationService()

    private init() {}

    /// Write a graded story in the learning language at the requested level.
    ///
    /// - Parameters:
    ///   - level: Difficulty (vocabulary, sentence complexity, length).
    ///   - topic: Optional topic; the model picks an everyday one when nil.
    ///   - learningIsChinese: Whether the learner studies Chinese (English UI)
    ///     or English (中文 UI) — determines the story's language and which
    ///     side of the saved terms seeds the known-word list.
    /// - Returns: The story title and body (paragraphs separated by blank lines).
    func generateStory(
        level: StoryLevel,
        topic: String?,
        learningIsChinese: Bool
    ) async throws -> (title: String, body: String) {
        let settings = AIModelSettings.shared
        guard settings.isAnyProviderAvailable else {
            throw StoryGenerationError.unavailable(
                reason: String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).")
            )
        }
        let provider = settings.effectiveProvider

        let system = Self.systemPrompt(level: level, learningIsChinese: learningIsChinese)
        let user = Self.userPrompt(topic: topic, learningIsChinese: learningIsChinese)

        let json: String
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), AIWordExplanationService.shared.isAvailable else {
                throw StoryGenerationError.unavailable(
                    reason: AIWordExplanationService.shared.unavailabilityReason ?? "Apple Intelligence unavailable"
                )
            }
            let session = LanguageModelSession(instructions: system)
            json = try await session.respond(to: user).content
            #else
            throw StoryGenerationError.unavailable(reason: "FoundationModels framework not available")
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
                throw StoryGenerationError.unavailable(reason: "No API key/model for \(provider.displayName)")
            }
            json = try await CloudAIService.shared.chat(
                provider: provider,
                model: model,
                system: system,
                user: user,
                jsonMode: true,
                maxTokens: 4096
            )
        }

        guard let data = AIWordExplanationService.extractJSONObject(from: json) else {
            throw StoryGenerationError.generationFailed(String(localized: "No JSON object found in the response."))
        }
        let decoded: StoryResponse
        do {
            decoded = try JSONDecoder().decode(StoryResponse.self, from: data)
        } catch {
            throw StoryGenerationError.generationFailed(String(localized: "The response could not be read."))
        }

        let body = decoded.story.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            throw StoryGenerationError.generationFailed(String(localized: "The model returned an empty story."))
        }
        var title = decoded.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if title.isEmpty {
            title = String(localized: "Generated Story")
        }
        return (title: title, body: body)
    }

    // MARK: - Prompts

    /// Provider-agnostic instructions: story language, graded-reader rules,
    /// and the strict JSON output shape.
    private static func systemPrompt(level: StoryLevel, learningIsChinese: Bool) -> String {
        let language = learningIsChinese ? "Simplified Chinese (简体中文)" : "English"
        return """
        You write short graded stories for language learners. Write the ENTIRE story \
        (title and body) in \(language) — no translations, no annotations\(learningIsChinese ? ", no pinyin" : ""). \
        \(level.guidance(inChinese: learningIsChinese)) \
        Separate paragraphs with a blank line (two newline characters). \
        The story must be coherent, engaging, and end with a satisfying final line.
        Return ONLY a single valid JSON object (no markdown, no commentary) of this exact shape:
        {"title": "...", "story": "..."}
        - "title": a short story title in \(language).
        - "story": the full story body in \(language), paragraphs separated by blank lines.
        JSON only, no commentary.
        """
    }

    /// Per-request prompt: the topic plus a sample of the learner's saved
    /// vocabulary in the learning language, so the story reuses known words.
    private static func userPrompt(topic: String?, learningIsChinese: Bool) -> String {
        var parts: [String] = []

        let trimmedTopic = topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedTopic.isEmpty {
            parts.append("Write the story about an engaging everyday topic of your choice.")
        } else {
            parts.append("Write the story about this topic: \(trimmedTopic)")
        }

        let knownWords = sampleKnownWords(learningIsChinese: learningIsChinese)
        if !knownWords.isEmpty {
            parts.append(
                "The learner already knows these words — preferentially build the story from them "
                + "(introduce only a few new words beyond this list): "
                + knownWords.joined(separator: ", ")
            )
        }

        return parts.joined(separator: "\n\n")
    }

    /// Up to 80 saved-term headwords in the learning language. Shuffled so
    /// repeated generations draw on different slices of a large vocabulary.
    private static func sampleKnownWords(learningIsChinese: Bool) -> [String] {
        var seen = Set<String>()
        var words: [String] = []
        for term in SavedTermsStore.shared.terms {
            let side = learningIsChinese ? term.chineseSide : term.englishSide
            let word = side.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip empties and long glosses — a "word" list should stay lexical.
            guard !word.isEmpty, word.count <= 20, seen.insert(word).inserted else { continue }
            words.append(word)
        }
        return Array(words.shuffled().prefix(80))
    }
}

// MARK: - Response Shape

/// Matches the `{"title": "...", "story": "..."}` JSON the model returns.
/// Tolerant decode: a missing title is recoverable (a fallback is derived);
/// only `story` is essential.
private struct StoryResponse: Decodable {
    let title: String
    let story: String

    private enum CodingKeys: String, CodingKey {
        case title, story
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        story = try c.decode(String.self, forKey: .story)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
    }
}
