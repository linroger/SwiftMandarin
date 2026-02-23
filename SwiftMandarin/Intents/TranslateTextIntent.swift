//
//  TranslateTextIntent.swift
//  SwiftMandarin

import Foundation
import AppIntents

struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Text"
    static var description = IntentDescription("Translate text between English and Chinese. Optionally save Chinese phrases (2+ characters) to vocabulary with auto-detected part of speech.")

    @Parameter(title: "Text", inputOptions: .init(capitalizationType: .sentences))
    var text: String

    @Parameter(title: "Direction", default: .auto)
    var direction: ShortcutTranslationDirection

    @Parameter(title: "Use Apple Intelligence", default: false)
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

        // Save Chinese phrases to vocabulary if enabled
        if saveToVocabulary {
            let chinese = resolvedDirection == .englishToChinese ? result.translation : trimmed
            let english = resolvedDirection == .englishToChinese ? trimmed : result.translation
            
            ShortcutHelpers.saveChinesePhrasesToVocabulary(
                chineseText: chinese,
                englishTranslation: english
            )
        }

        let dialog = useAI && !result.usedAI
            ? IntentDialog("Apple Intelligence wasn't available, so SwiftMandarin used standard translation.")
            : IntentDialog("Translation complete.")

        return .result(value: result.translation, dialog: dialog)
    }
}

enum TranslationIntentError: LocalizedError {
    case emptyText

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Please provide text to translate."
        }
    }
}
