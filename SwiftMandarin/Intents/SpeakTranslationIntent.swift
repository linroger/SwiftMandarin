//
//  SpeakTranslationIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct SpeakTranslationIntent: AppIntent {
    static var title: LocalizedStringResource = "Speak Translation"
    static var description = IntentDescription("Translate and speak text in the target language, or speak the original text.")

    @Parameter(title: "Text", inputOptions: .init(capitalizationType: .sentences))
    var text: String

    @Parameter(title: "Direction", default: .auto)
    var direction: ShortcutTranslationDirection

    @Parameter(title: "Use Apple Intelligence", default: false)
    var useAI: Bool

    @Parameter(title: "Speak", default: .translated)
    var speakTarget: ShortcutSpeakTarget

    static var parameterSummary: some ParameterSummary {
        Summary("Speak \(\.$text)") {
            \.$direction
            \.$useAI
            \.$speakTarget
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationIntentError.emptyText
        }

        let resolvedDirection = ShortcutHelpers.resolveDirection(for: trimmed, preferred: direction)

        switch speakTarget {
        case .source:
            if resolvedDirection == .chineseToEnglish {
                try await SpeechService.speakAndWait(trimmed, languageCode: "zh-CN")
            } else {
                try await SpeechService.speakAndWait(trimmed, languageCode: "en-US")
            }
            return .result()
        case .translated:
            let result = try await ShortcutHelpers.translate(trimmed, direction: resolvedDirection, useAI: useAI)
            if resolvedDirection == .chineseToEnglish {
                try await SpeechService.speakAndWait(result.translation, languageCode: "en-US")
            } else {
                try await SpeechService.speakAndWait(result.translation, languageCode: "zh-CN")
            }
            return .result()
        }
    }
}
