//
//  ConversationService.swift
//  SwiftMandarin
//
//  AI conversation partner: turns the configured AI provider into a friendly
//  native speaker roleplaying everyday scenarios (café, directions, travel…)
//  in the language the user is learning. Every partner turn arrives as
//  structured JSON — reply text, pinyin (Chinese only), a native-language
//  translation, and optional gentle feedback on the learner's last message —
//  so the chat UI can offer learner aids without extra model calls.
//
//  Cloud providers receive the real multi-turn message history via
//  `CloudAIService.chatTurns`; Apple Intelligence and Ollama expose only
//  single-prompt APIs here, so for them the recent history is embedded in the
//  prompt as a transcript.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Scenario

/// The roleplay scenes the conversation partner can act out. Raw values are
/// stable identifiers used for persistence (see `Conversation`).
enum ConversationScenario: String, CaseIterable, Codable, Identifiable, Sendable {
    case freeChat
    case cafe
    case directions
    case shopping
    case introductions
    case travel
    case doctor

    var id: String { rawValue }

    /// SF Symbol for the scenario card (iOS-17-safe set only).
    var symbolName: String {
        switch self {
        case .freeChat: return "bubble.left.and.bubble.right.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .directions: return "map.fill"
        case .shopping: return "cart.fill"
        case .introductions: return "person.2.fill"
        case .travel: return "airplane"
        case .doctor: return "cross.case.fill"
        }
    }

    /// Localization key for the scenario title (resolve with `L(_:)`).
    var titleKey: String {
        switch self {
        case .freeChat: return "Free chat"
        case .cafe: return "At the café"
        case .directions: return "Directions"
        case .shopping: return "Shopping"
        case .introductions: return "Introductions"
        case .travel: return "Travel"
        case .doctor: return "At the doctor"
        }
    }

    /// Localization key for the one-line scenario description (resolve with `L(_:)`).
    var descriptionKey: String {
        switch self {
        case .freeChat: return "Chat about anything"
        case .cafe: return "Order drinks and snacks"
        case .directions: return "Find your way around town"
        case .shopping: return "Ask prices and haggle"
        case .introductions: return "Meet someone new"
        case .travel: return "Airports, hotels, and tickets"
        case .doctor: return "Describe how you feel"
        }
    }

    /// English scene description seeded into the system prompt. Always English:
    /// this is model-facing instruction text, never shown to the user.
    var sceneSeed: String {
        switch self {
        case .freeChat:
            return "a relaxed, free-form chat between two friends about everyday life — hobbies, food, weather, plans"
        case .cafe:
            return "a cozy café where you are the barista taking the learner's order — drinks, snacks, sizes, paying"
        case .directions:
            return "a city street where you are a friendly local the learner stops to ask for directions — landmarks, turns, distances, transit"
        case .shopping:
            return "a shop or market stall where you are the shopkeeper — browsing, sizes and colors, asking prices, light bargaining"
        case .introductions:
            return "a friendly gathering where you and the learner are meeting for the first time — names, hometowns, work or study, hobbies"
        case .travel:
            return "a trip where you are the staff member the learner deals with — airport check-in, hotel front desk, buying tickets"
        case .doctor:
            return "a clinic where you are the doctor — asking about symptoms, giving simple, reassuring advice"
        }
    }
}

// MARK: - Partner Reply

/// One structured turn from the AI conversation partner.
struct PartnerReply: Codable, Sendable {
    /// The partner's next line, in the learning language only.
    var reply: String
    /// Hanyu pinyin for `reply` — only when the learning language is Chinese.
    var pinyin: String?
    /// Natural translation of `reply` into the learner's native language.
    /// Empty when the model response could not be parsed as JSON.
    var translation: String
    /// Gentle correction of the learner's last message, written in the
    /// learner's native language; `nil` when there was nothing to correct.
    var feedback: String?

    init(reply: String, pinyin: String?, translation: String, feedback: String?) {
        self.reply = reply
        self.pinyin = pinyin
        self.translation = translation
        self.feedback = feedback
    }

    private enum CodingKeys: String, CodingKey {
        case reply, pinyin, translation, feedback
    }

    /// Tolerant decode: only `reply` is required — models routinely omit or
    /// null the aid fields, and that must not fail the whole turn.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reply = try c.decode(String.self, forKey: .reply)
        pinyin = try? c.decode(String.self, forKey: .pinyin)
        translation = (try? c.decode(String.self, forKey: .translation)) ?? ""
        feedback = try? c.decode(String.self, forKey: .feedback)
    }
}

// MARK: - Service

@MainActor
final class ConversationService {

    static let shared = ConversationService()

    private init() {}

    /// Generate the partner's next turn for a conversation.
    ///
    /// Pass the full message history (the latest learner message last). An
    /// empty history asks the partner to open the scene with a greeting.
    ///
    /// - Throws: `AIExplanationError` when no provider is usable, or the
    ///   underlying provider error when the call itself fails.
    func reply(
        scenario: ConversationScenario,
        history: [ConversationMessage],
        learningIsChinese: Bool
    ) async throws -> PartnerReply {
        let settings = AIModelSettings.shared
        guard settings.isAnyProviderAvailable else {
            throw AIExplanationError.unavailable(
                reason: String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).")
            )
        }
        let provider = settings.effectiveProvider
        let system = Self.systemPrompt(scenario: scenario, learningIsChinese: learningIsChinese)

        let raw: String
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), AIWordExplanationService.shared.isAvailable else {
                throw AIExplanationError.unavailable(
                    reason: AIWordExplanationService.shared.unavailabilityReason ?? "Apple Intelligence unavailable"
                )
            }
            let session = LanguageModelSession(instructions: system)
            raw = try await session.respond(to: Self.transcriptPrompt(history: history)).content
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
                userPrompt: Self.transcriptPrompt(history: history),
                enableThinking: false
            )
            raw = content
        default:
            let model = settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else {
                throw AIExplanationError.unavailable(reason: "No API key/model for \(provider.displayName)")
            }
            raw = try await CloudAIService.shared.chatTurns(
                provider: provider,
                model: model,
                system: system,
                turns: Self.turns(from: history),
                jsonMode: true
            )
        }

        return Self.parseReply(from: raw, learningIsChinese: learningIsChinese)
    }

    // MARK: - Prompt Building

    /// Roleplay instructions demanding a strict JSON turn. The learning
    /// language is what the partner speaks; the native language carries the
    /// translation and feedback so the learner always understands the aids.
    private static func systemPrompt(scenario: ConversationScenario, learningIsChinese: Bool) -> String {
        let learningLanguage = learningIsChinese ? "Mandarin Chinese (Simplified, 简体中文)" : "English"
        let nativeLanguage = learningIsChinese ? "English" : "Simplified Chinese (简体中文)"
        let pinyinRule = learningIsChinese
            ? "\"pinyin\": Hanyu pinyin with tone marks (ā á ǎ à) for the whole reply."
            : "\"pinyin\": omit this field or use null — the reply is English, so there is no pinyin."
        return """
        You are a friendly native \(learningLanguage) speaker roleplaying this scene with a \
        language learner: \(scenario.sceneSeed).
        Stay in character, be warm and encouraging, and keep the conversation moving with \
        small questions. Speak ONLY \(learningLanguage) in your reply. Keep every turn to \
        1–3 short sentences, matched to a learner's level: simple common vocabulary, \
        natural everyday phrasing.
        ALWAYS respond with a single valid JSON object of exactly this shape (no markdown, \
        no commentary):
        {"reply":"...","pinyin":"...","translation":"...","feedback":"..."}
        - "reply": your next turn, in \(learningLanguage) only.
        - \(pinyinRule)
        - "translation": a natural \(nativeLanguage) translation of "reply".
        - "feedback": if the learner's LAST message contained a mistake (grammar, word \
        choice, unnatural phrasing), ONE gentle, encouraging correction written in \
        \(nativeLanguage); otherwise null. Never nitpick punctuation or capitalization.
        JSON only, no commentary.
        """
    }

    /// Map the stored history onto API message turns. Anthropic-style APIs
    /// require the first message to come from the user, and every request must
    /// end on a user turn so the model knows to produce the next partner line
    /// (the opening-greeting call has no learner message yet) — synthetic cue
    /// turns cover both, and are harmless for OpenAI-style providers.
    private static func turns(from history: [ConversationMessage]) -> [(role: String, content: String)] {
        var result = history.map { (role: $0.isUser ? "user" : "assistant", content: $0.text) }
        if result.first?.role != "user" {
            result.insert((role: "user", content: "(Let's begin the roleplay. Open the scene by greeting me.)"), at: 0)
        }
        if result.last?.role != "user" {
            result.append((role: "user", content: "(Please continue with your next turn.)"))
        }
        return result
    }

    /// Single-prompt fallback for providers without a multi-turn API here
    /// (Apple Intelligence, Ollama): embed the recent history as a transcript.
    private static func transcriptPrompt(history: [ConversationMessage]) -> String {
        guard !history.isEmpty else {
            return "The conversation is just starting. Open the scene by greeting the learner. Respond with the JSON object."
        }
        let lines = history.suffix(12)
            .map { "\($0.isUser ? "Learner" : "You"): \($0.text)" }
            .joined(separator: "\n")
        return """
        Conversation so far (most recent last):
        \(lines)

        Write your next turn. Respond with the JSON object.
        """
    }

    // MARK: - Response Parsing

    /// Parse a model response into a `PartnerReply`, degrading gracefully: a
    /// malformed JSON response becomes a bare reply (no translation/feedback),
    /// and a missing pinyin for a Chinese reply is derived locally so the
    /// learner aid never silently disappears.
    private static func parseReply(from raw: String, learningIsChinese: Bool) -> PartnerReply {
        var result: PartnerReply
        if let data = AIWordExplanationService.extractJSONObject(from: raw),
           let decoded = try? JSONDecoder().decode(PartnerReply.self, from: data),
           !decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = decoded
        } else {
            result = PartnerReply(reply: stripFences(raw), pinyin: nil, translation: "", feedback: nil)
        }

        result.reply = result.reply.trimmingCharacters(in: .whitespacesAndNewlines)
        result.translation = result.translation.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize blank aid fields to nil so the UI can key off presence.
        if let feedback = result.feedback,
           feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.feedback = nil
        }

        if learningIsChinese {
            if (result.pinyin ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               result.reply.containsCJK {
                result.pinyin = PinyinConverter.convert(result.reply)
            }
        } else {
            // English replies never carry pinyin, whatever the model returned.
            result.pinyin = nil
        }
        return result
    }

    /// Strip a surrounding markdown code fence from a raw (non-JSON) response
    /// so the graceful-degradation path shows clean text.
    private static func stripFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if t.hasSuffix("```") {
                t = String(t.dropLast(3))
            }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }
}
