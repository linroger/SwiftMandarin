//
//  TranslateClipboardIntent.swift
//  SwiftMandarin

import Foundation
import AppIntents

struct TranslateClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Clipboard"
    static var description = IntentDescription("Translate the text on the clipboard. Optionally save the words in the language you are learning to your vocabulary, with the part of speech detected automatically.")

    @Parameter(title: "Direction", default: .auto)
    var direction: ShortcutTranslationDirection

    @Parameter(
        title: "Use AI Provider",
        description: "Translate with the AI provider selected in SwiftMandarin's AI settings instead of Apple's on-device translation. The text is sent to that provider.",
        default: false
    )
    var useAI: Bool

    @Parameter(title: "Copy Result to Clipboard", default: true)
    var copyResultToClipboard: Bool

    @Parameter(title: "Save to Vocabulary", default: false)
    var saveToVocabulary: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Translate clipboard with \(\.$direction)") {
            \.$useAI
            \.$copyResultToClipboard
            \.$saveToVocabulary
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let clipboardText = ClipboardService.paste()
        guard let clipboardText, !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationIntentError.emptyText
        }

        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDirection = ShortcutHelpers.resolveDirection(for: trimmed, preferred: direction)

        let result = try await ShortcutHelpers.translate(trimmed, direction: resolvedDirection, useAI: useAI)

        // Save to translation history
        TranslationHistoryStore.shared.add(
            source: trimmed,
            target: result.translation,
            direction: resolvedDirection
        )

        if copyResultToClipboard {
            ClipboardService.copy(result.translation)
        }

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
