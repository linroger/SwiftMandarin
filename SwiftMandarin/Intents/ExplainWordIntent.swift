//
//  ExplainWordIntent.swift
//  SwiftMandarin
//
//  "Explain 洗澡 with SwiftMandarin": the AI word explanation the app shows
//  in Word Details, from Siri or a Shortcut, spoken back as the definition.
//

import Foundation
import AppIntents

struct ExplainWordIntent: AppIntent {
    static var title: LocalizedStringResource = "Explain Word"
    static var description = IntentDescription("Ask the AI provider selected in SwiftMandarin for a learner's explanation of a word or phrase — its meaning, part of speech, and an example — written in your own language.")

    @Parameter(title: "Word or Phrase", inputOptions: .init(capitalizationType: .none))
    var word: String

    static var parameterSummary: some ParameterSummary {
        Summary("Explain \(\.$word)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationIntentError.emptyText
        }
        guard AIModelSettings.shared.isAnyProviderAvailable else {
            throw ExplainWordIntentError.noProvider
        }

        // The same cache Word Details reads, so an explanation the learner
        // already paid for is reused, and one fetched here is waiting in the
        // app afterwards.
        let direction = ExplanationDirection.current(forWord: trimmed)
        let cache = WordExplanationCacheStore.shared
        let result: WordExplanationResult
        if let cached = cache.explanation(forWord: trimmed, directionToken: direction.cacheToken) {
            result = cached.result
        } else {
            result = try await AIWordExplanationService.shared.generateExplanationWithProvider(for: trimmed)
            cache.store(
                word: trimmed,
                pinyin: "",
                directionToken: direction.cacheToken,
                providerName: AIModelSettings.shared.effectiveProvider.displayName,
                result: result
            )
        }

        let definition = result.definition.trimmingCharacters(in: .whitespacesAndNewlines)
        var summary = definition
        let partOfSpeech = result.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        if !partOfSpeech.isEmpty {
            summary = "\(partOfSpeech) · \(summary)"
        }
        if let example = result.exampleSentences.first {
            let sentence = example.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let translation = example.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                summary += "\n\(sentence)"
                if !translation.isEmpty { summary += "\n\(translation)" }
            }
        }

        return .result(
            value: summary,
            dialog: IntentDialog(stringLiteral: "\(trimmed): \(definition)")
        )
    }
}

enum ExplainWordIntentError: LocalizedError {
    case noProvider

    var errorDescription: String? {
        switch self {
        case .noProvider:
            return String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).", bundle: .appLanguage)
        }
    }
}
