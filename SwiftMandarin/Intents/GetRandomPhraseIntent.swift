//
//  GetRandomPhraseIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

/// `AudioPlaybackIntent` so "Speak Phrase" can play from Siri or the Lock
/// Screen without the app in front.
struct GetRandomPhraseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Get Random Phrase"
    static var description = IntentDescription("Pick a random phrase, optionally speak it, copy it, or save it to vocabulary.")

    @Parameter(title: "Category", default: .any)
    var category: ShortcutPhraseCategory

    @Parameter(title: "Speak Phrase", default: false)
    var speakPhrase: Bool

    @Parameter(title: "Copy to Clipboard", default: false)
    var copyToClipboard: Bool

    @Parameter(title: "Save to Vocabulary", default: false)
    var saveToVocabulary: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Get a random \(\.$category) phrase") {
            \.$speakPhrase
            \.$copyToClipboard
            \.$saveToVocabulary
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PhraseEntity> {
        let phrase = pickPhrase()

        // Speak/copy the side in the language the user is LEARNING (the
        // opposite of the interface language).
        let learningEnglish = LocalizationManager.shared.nativeIsChinese
        let studied = learningEnglish ? phrase.english : phrase.chinese
        let gloss = learningEnglish ? phrase.chinese : phrase.english

        if speakPhrase {
            try await SpeechService.speakAndWait(studied, languageCode: learningEnglish ? "en-US" : "zh-CN")
        }

        if copyToClipboard {
            ClipboardService.copy(studied)
        }

        var dialogText = "\(studied) — \(gloss)"
        if saveToVocabulary {
            let saved = ShortcutHelpers.saveTermIfNeeded(
                chineseSide: phrase.chinese,
                englishSide: phrase.english,
                partOfSpeech: "phrase"
            )
            if saved {
                ShortcutHelpers.persistIntentChanges()
            }
            dialogText += " " + (saved
                ? String(localized: "Saved to vocabulary.", bundle: .appLanguage)
                : String(localized: "Already in your vocabulary.", bundle: .appLanguage))
        }

        // Siri reads the dialog, so the phrase itself goes there — a bare
        // entity value gave voice users nothing to hear.
        return .result(value: phrase, dialog: IntentDialog(stringLiteral: dialogText))
    }

    private func pickPhrase() -> PhraseEntity {
        let categories = PhraseCategory.allCategories

        let resolvedCategories: [PhraseCategory]
        switch category {
        case .greetings:
            resolvedCategories = categories.filter { $0.name == "Greetings" }
        case .commonExpressions:
            resolvedCategories = categories.filter { $0.name == "Common Expressions" }
        case .questions:
            resolvedCategories = categories.filter { $0.name == "Questions" }
        case .dining:
            resolvedCategories = categories.filter { $0.name == "Dining" }
        case .travel:
            resolvedCategories = categories.filter { $0.name == "Travel" }
        case .numbers:
            resolvedCategories = categories.filter { $0.name == "Numbers" }
        case .time:
            resolvedCategories = categories.filter { $0.name == "Time" }
        case .any:
            resolvedCategories = categories
        }

        guard let category = resolvedCategories.randomElement() else {
            let fallbackCategory = categories.first ?? PhraseCategory(name: "Phrases", icon: "quote.bubble", phrases: [])
            let fallbackPhrase = fallbackCategory.phrases.first ?? Phrase(chinese: "你好", english: "Hello")
            return PhraseEntity(phrase: fallbackPhrase, category: fallbackCategory.name)
        }

        let phrase = category.phrases.randomElement() ?? Phrase(chinese: "你好", english: "Hello")
        return PhraseEntity(phrase: phrase, category: category.name)
    }
}
