//
//  TranslateTextIntent.swift
//  SwiftMandarin

import Foundation
import AppIntents

struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Text"
    static var description = IntentDescription("Translate text between English and Chinese. Optionally save the words in the language you are learning to your vocabulary, with the part of speech detected automatically.")

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

    @Parameter(title: "Save to Vocabulary", default: false)
    var saveToVocabulary: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Translate \(\.$text) with \(\.$direction)") {
            \.$useAI
            \.$saveToVocabulary
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationIntentError.emptyText
        }

        let resolvedDirection = ShortcutHelpers.resolveDirection(for: trimmed, preferred: direction)

        let result = try await ShortcutHelpers.translate(trimmed, direction: resolvedDirection, useAI: useAI)

        // Save to translation history
        TranslationHistoryStore.shared.add(
            source: trimmed,
            target: result.translation,
            direction: resolvedDirection
        )

        // Save the studied language's phrases to vocabulary if enabled —
        // awaited, so the save finishes before the intent returns.
        var saveOutcome: ShortcutHelpers.VocabularySaveOutcome?
        if saveToVocabulary {
            let chinese = resolvedDirection == .englishToChinese ? result.translation : trimmed
            let english = resolvedDirection == .englishToChinese ? trimmed : result.translation
            saveOutcome = await ShortcutHelpers.saveStudiedPhrasesToVocabulary(
                chineseText: chinese,
                englishTranslation: english
            )
        }

        // The history entry and any saved words are on disk before Shortcuts
        // reports success, even if the process is suspended right after.
        ShortcutHelpers.persistIntentChanges()

        return .result(
            value: result.translation,
            dialog: ShortcutHelpers.translationDialog(
                translation: result.translation,
                requestedAI: useAI,
                usedAI: result.usedAI,
                saveOutcome: saveOutcome
            )
        )
    }
}

enum TranslationIntentError: LocalizedError {
    case emptyText
    case translationFailed(String)
    case noImages
    case invalidImages

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return String(localized: "Please provide text to translate.", bundle: .appLanguage)
        case .translationFailed(let message):
            return message
        case .noImages:
            return String(localized: "No images provided.", bundle: .appLanguage)
        case .invalidImages:
            return String(localized: "Could not load the provided images.", bundle: .appLanguage)
        }
    }
}
