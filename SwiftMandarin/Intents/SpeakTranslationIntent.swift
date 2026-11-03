//
//  SpeakTranslationIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

/// `AudioPlaybackIntent` tells the system this intent produces audio, so a
/// run from Siri or the Lock Screen is allowed to play it in the background
/// instead of starting and immediately losing the audio session.
struct SpeakTranslationIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Speak Translation"
    static var description = IntentDescription("Translate and speak text in the target language, or speak the original text.")

    @Parameter(title: "Text", inputOptions: .init(capitalizationType: .sentences))
    var text: String

    @Parameter(title: "Direction", default: .auto)
    var direction: ShortcutTranslationDirection

    @Parameter(
        title: "Use AI Provider",
        description: "Translate with the AI provider selected in SwiftMandarin's AI settings instead of Apple's on-device translation. The text is sent to that provider.",
        default: false
    )
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
