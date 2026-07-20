//
//  GetRandomPhraseIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct GetRandomPhraseIntent: AppIntent {
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

        if speakPhrase {
            if learningEnglish {
                try await SpeechService.speakAndWait(phrase.english, languageCode: "en-US")
            } else {
                try await SpeechService.speakAndWait(phrase.chinese, languageCode: "zh-CN")
            }
        }

        if copyToClipboard {
            ClipboardService.copy(learningEnglish ? phrase.english : phrase.chinese)
        }

        if saveToVocabulary {
            ShortcutHelpers.saveToVocabularyIfNeeded(
                chinese: phrase.chinese,
                english: phrase.english,
                partOfSpeech: "phrase",
                saveAsPhrase: true
            )
        }

        return .result(value: phrase)
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
