//
//  TranslateClipboardIntent.swift
//  SwiftMandarin

import Foundation
import AppIntents

struct TranslateClipboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Clipboard"
    static var description = IntentDescription("Translate text from the clipboard. Optionally save Chinese phrases (2+ characters) to vocabulary with auto-detected part of speech.")

    @Parameter(title: "Direction", default: .auto)
    var direction: ShortcutTranslationDirection

    @Parameter(title: "Use Apple Intelligence", default: false)
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
