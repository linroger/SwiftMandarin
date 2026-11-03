//
//  ChatbotService.swift
//  SwiftMandarin
//
//  Sends an AI Chat turn to the provider selected in Settings → AI and turns
//  the answer into a chunked reply (see ChatbotPrompt.swift for the contract).
//

import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class ChatbotService {

    static let shared = ChatbotService()

    nonisolated private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "ChatbotService")

    private init() {}

    /// Output budget for one reply. The chunk list roughly triples the size of
    /// the answer, and a cut-off envelope loses the chunks entirely.
    private static let maxReplyTokens = 6144

    /// The history sent with each turn. Older turns add cost without changing
    /// the answer to the newest message.
    private static let historyLimit = 12

    /// Generate the assistant's reply to the last learner message in `history`.
    ///
    /// - Throws: `AIExplanationError` when no provider is usable, the provider's
    ///   own error when the call fails, or `ChatbotResponseError.noReply` when
    ///   the answer cannot be read.
    func reply(to history: [ChatbotMessage], learningIsChinese: Bool) async throws -> ChatbotMessage {
        let settings = AIModelSettings.shared
        guard settings.isAnyProviderAvailable else {
            throw AIExplanationError.unavailable(
                reason: String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).", bundle: .appLanguage)
            )
        }
        let context = ChatbotContext(learningIsChinese: learningIsChinese)
        let system = ChatbotPromptBuilder.systemPrompt(for: context)
        let recent = Array(history.suffix(Self.historyLimit))
        let provider = settings.effectiveProvider

        let parsed: ChatbotReply
        switch provider {
        case .appleIntelligence:
            parsed = try await replyWithAppleIntelligence(system: system, history: recent, context: context)
        case .ollama:
            guard OllamaService.shared.isConnected else {
                throw AIExplanationError.ollamaNotConnected
            }
            guard !settings.ollamaModel.isEmpty else {
                throw AIExplanationError.ollamaNoModelSelected
            }
            let (content, _) = try await OllamaService.shared.chat(
                model: settings.ollamaModel,
                systemPrompt: system,
                userPrompt: ChatbotPromptBuilder.transcriptPrompt(history: recent.map { ($0.isUser, $0.text) }, context: context),
                enableThinking: false
            )
            parsed = try ChatbotResponseParser.parse(content)
        default:
            let model = settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else {
                throw AIExplanationError.unavailable(
                    reason: String(format: String(localized: "No API key/model for %@. Configure one in Settings → AI.", bundle: .appLanguage), provider.displayName)
                )
            }
            let raw = try await CloudAIService.shared.chatTurns(
                provider: provider,
                model: model,
                system: system,
                turns: Self.turns(from: recent, context: context),
                jsonMode: true,
                maxTokens: Self.maxReplyTokens,
                // A reply cut off at the budget still has a readable answer up
                // to the cut; the parser salvages it and the chunks are rebuilt
                // locally, which beats an error bubble.
                failOnTruncation: false
            )
            parsed = try ChatbotResponseParser.parse(raw)
        }

        // Keep every model chunk that lines up with the reply; segment only
        // what the model's chunks did not cover.
        var chunks: [ChatbotChunk] = []
        var fromModel = false
        for piece in ChatbotResponseParser.layout(parsed.chunks, over: parsed.reply) {
            switch piece {
            case .chunk(let chunk):
                chunks.append(chunk)
                fromModel = true
            case .gap(let text):
                chunks += Self.localChunks(forGap: text, chinese: learningIsChinese)
            }
        }
        if chunks.isEmpty {
            chunks = Self.localChunks(for: parsed.reply, chinese: learningIsChinese)
        }
        let translation = Self.isInNativeLanguage(parsed.translation, learningIsChinese: learningIsChinese)
            ? parsed.translation : ""
        chunks = await fillingMissingMeanings(
            chunks,
            reply: parsed.reply,
            translation: translation,
            context: context,
            provider: provider
        )
        if learningIsChinese {
            chunks = chunks.map(Self.withoutForeignReading)
        }
        return ChatbotMessage(
            isUser: false,
            text: parsed.reply,
            translation: translation.isEmpty ? nil : translation,
            chunks: chunks,
            chunksFromModel: fromModel,
            replyIsChinese: learningIsChinese
        )
    }

    // MARK: - Providers

    private func replyWithAppleIntelligence(system: String, history: [ChatbotMessage], context: ChatbotContext) async throws -> ChatbotReply {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), AIWordExplanationService.shared.isAvailable else {
            throw AIExplanationError.unavailable(
                reason: AIWordExplanationService.shared.unavailabilityReason
                    ?? String(localized: "Apple Intelligence is not available on this device.", bundle: .appLanguage)
            )
        }
        // Guided generation enforces the shape, so the on-device model never
        // has to produce JSON text it might break.
        let session = LanguageModelSession(instructions: system)
        let output = try await session.respond(
            to: ChatbotPromptBuilder.transcriptPrompt(history: history.map { ($0.isUser, $0.text) }, context: context),
            generating: ChatbotGeneratedReply.self
        ).content
        let reply = output.reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { throw ChatbotResponseError.noReply }
        let chunks = output.chunks.map {
            ChatbotChunk(
                text: $0.text,
                reading: $0.reading.trimmingCharacters(in: .whitespacesAndNewlines),
                meaning: $0.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return ChatbotReply(
            reply: reply,
            translation: output.translation.trimmingCharacters(in: .whitespacesAndNewlines),
            chunks: chunks
        )
        #else
        throw AIExplanationError.unavailable(
            reason: String(localized: "Apple Intelligence is not available on this device.", bundle: .appLanguage)
        )
        #endif
    }

    /// Multi-turn history for cloud chat APIs. Anthropic-style APIs need the
    /// first turn to come from the user and every request to end on one; the
    /// learner always sends last here, so only the start needs a guard.
    ///
    /// Earlier assistant turns are sent in the full JSON shape the
    /// instructions demand, chunk list included, and the learner's newest
    /// message carries the format reminder: models copy the shape of the
    /// conversation, and history without chunks made later replies drop them.
    private static func turns(from history: [ChatbotMessage], context: ChatbotContext) -> [(role: String, content: String)] {
        var turns = history.map { message -> (role: String, content: String) in
            guard !message.isUser else { return (role: "user", content: message.text) }
            return (
                role: "assistant",
                content: ChatbotPromptBuilder.assistantEnvelope(
                    reply: message.text,
                    chunks: message.chunks ?? [],
                    translation: message.translation ?? ""
                )
            )
        }
        while turns.first?.role == "assistant" {
            turns.removeFirst()
        }
        if let last = turns.indices.last, turns[last].role == "user" {
            turns[last].content += "\n\n(" + ChatbotPromptBuilder.formatReminder(for: context) + ")"
        }
        return turns
    }

    // MARK: - Missing meanings

    /// The most chunks glossed in one follow-up request.
    private static let maxGlossChunks = 80

    /// Fill in the meanings a reply's chunks are missing — chunks the model
    /// left empty, or the whole reply when its chunks had to be rebuilt on
    /// the device — with one short follow-up request to the same provider.
    ///
    /// Best effort: the reply is already complete, so any failure here keeps
    /// the chunks as they were instead of failing the turn.
    private func fillingMissingMeanings(
        _ chunks: [ChatbotChunk],
        reply: String,
        translation: String,
        context: ChatbotContext,
        provider: AIProvider
    ) async -> [ChatbotChunk] {
        let indices = Array(ChatbotResponseParser.indicesNeedingGloss(chunks).prefix(Self.maxGlossChunks))
        guard !indices.isEmpty else { return chunks }
        let needing = indices.map { chunks[$0] }
        let system = ChatbotPromptBuilder.glossSystemPrompt(for: context)
        let user = ChatbotPromptBuilder.glossUserPrompt(chunks: needing, reply: reply, translation: translation)
        do {
            let glosses = try await glosses(system: system, user: user, provider: provider)
            return ChatbotResponseParser.filling(chunks, at: indices, with: glosses)
        } catch {
            Self.log.notice("Gloss fill failed: \(error.localizedDescription, privacy: .public)")
            return chunks
        }
    }

    private func glosses(system: String, user: String, provider: AIProvider) async throws -> [ChatbotChunk] {
        let settings = AIModelSettings.shared
        switch provider {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            guard #available(iOS 26.0, macOS 26.0, *), AIWordExplanationService.shared.isAvailable else { return [] }
            let session = LanguageModelSession(instructions: system)
            let output = try await session.respond(to: user, generating: ChatbotGeneratedGlossList.self).content
            return output.glosses.map {
                ChatbotChunk(
                    text: $0.text,
                    reading: $0.reading.trimmingCharacters(in: .whitespacesAndNewlines),
                    meaning: $0.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            #else
            return []
            #endif
        case .ollama:
            guard OllamaService.shared.isConnected, !settings.ollamaModel.isEmpty else { return [] }
            let (content, _) = try await OllamaService.shared.chat(
                model: settings.ollamaModel,
                systemPrompt: system,
                userPrompt: user,
                enableThinking: false
            )
            return ChatbotResponseParser.glosses(in: content)
        default:
            let model = settings.selectedModel(for: provider)
            guard !settings.apiKey(for: provider).isEmpty, !model.isEmpty else { return [] }
            let raw = try await CloudAIService.shared.chat(
                provider: provider,
                model: model,
                system: system,
                user: user,
                jsonMode: true,
                maxTokens: 4096,
                failOnTruncation: false
            )
            return ChatbotResponseParser.glosses(in: raw)
        }
    }

    // MARK: - Sanity checks

    /// A Chinese reply can quote English ("想 means 'want'"); pinyin belongs
    /// only on Han chunks, and models put the word itself in that slot.
    private static func withoutForeignReading(_ chunk: ChatbotChunk) -> ChatbotChunk {
        guard !chunk.reading.isEmpty, !chunk.text.contains(where: { $0.isChineseCharacter }) else { return chunk }
        return ChatbotChunk(text: chunk.text, reading: "", meaning: chunk.meaning)
    }

    /// Whether a translation is in the learner's own language. Small models
    /// sometimes repeat the reply in the learning language as its
    /// "translation"; showing that under the reply would teach nothing.
    static func isInNativeLanguage(_ text: String, learningIsChinese: Bool) -> Bool {
        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let han = letters.filter { $0.isChineseCharacter }.count
        let hanShare = Double(han) / Double(letters.count)
        // Chinese learners read English translations (a few quoted characters
        // are fine); English learners read Chinese ones.
        return learningIsChinese ? hanShare < 0.5 : hanShare >= 0.5
    }

    // MARK: - Local fallback

    /// Local chunks for a stretch of the reply the model's chunks missed,
    /// keeping its paragraph breaks as line-break chunks.
    static func localChunks(forGap text: String, chinese: Bool) -> [ChatbotChunk] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var chunks: [ChatbotChunk] = []
        for (index, line) in lines.enumerated() {
            if index > 0, chunks.last?.isLineBreak != true {
                chunks.append(.lineBreak)
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                chunks += localChunks(for: trimmed, chinese: chinese)
            }
        }
        return chunks
    }

    /// Chunks built on the device when the model's were missing or did not
    /// spell out its reply: real readings, no meanings (the detail sheet can
    /// still speak and save a chunk). Never empty for a non-empty reply.
    static func localChunks(for reply: String, chinese: Bool) -> [ChatbotChunk] {
        if chinese {
            let words = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(reply)
            let chunks = words.map { word -> ChatbotChunk in
                let hasHan = word.text.contains { $0.isChineseCharacter }
                return ChatbotChunk(text: word.text, reading: hasHan ? PinyinConverter.convert(word.text) : "")
            }
            if ChatbotResponseParser.reconstructs(chunks, reply: reply) {
                return chunks
            }
        }
        if chinese {
            // Segmentation that dropped characters: one chip per character, so
            // every Han character still gets its pinyin.
            var chunks: [ChatbotChunk] = []
            var run = ""
            for character in reply where !character.isWhitespace {
                if character.isChineseCharacter {
                    if !run.isEmpty { chunks.append(ChatbotChunk(text: run)); run = "" }
                    let text = String(character)
                    chunks.append(ChatbotChunk(text: text, reading: PinyinConverter.convert(text)))
                } else {
                    run.append(character)
                }
            }
            if !run.isEmpty { chunks.append(ChatbotChunk(text: run)) }
            return chunks
        }
        // English: split on whitespace so the chips always reproduce the reply.
        return reply
            .split(omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
            .map { ChatbotChunk(text: String($0)) }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ChatbotGeneratedReply {
    @Guide(description: "Your whole reply to the learner, in the language they are learning")
    let reply: String

    @Guide(description: "The reply split into semantic chunks in order, covering every word of the reply without skipping or rewording any; joining every chunk's text must reproduce the reply exactly apart from spaces, and each punctuation mark is its own chunk")
    let chunks: [ChatbotGeneratedChunk]

    @Guide(description: "A natural, complete translation of the reply into the learner's own language")
    let translation: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ChatbotGeneratedGlossList {
    @Guide(description: "One entry per numbered chunk, in the same order, each repeating its chunk exactly with its reading and a short meaning in the learner's own language, never empty")
    let glosses: [ChatbotGeneratedChunk]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ChatbotGeneratedChunk {
    @Guide(description: "The chunk exactly as it appears in the reply: a word, set phrase, chengyu, measure-word phrase, or punctuation mark")
    let text: String

    @Guide(description: "Hanyu pinyin with tone marks for a Chinese chunk, IPA between slashes for an English chunk, empty for punctuation")
    let reading: String

    @Guide(description: "A short gloss in the learner's own language for the sense used here, empty for punctuation")
    let meaning: String
}
#endif
