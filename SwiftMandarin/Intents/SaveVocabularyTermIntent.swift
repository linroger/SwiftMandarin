//
//  SaveVocabularyTermIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct SaveVocabularyTermIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Vocabulary Term"
    static var description = IntentDescription("Save a Chinese word or phrase to your vocabulary list.")

    @Parameter(title: "Chinese Text")
    var chinese: String

    @Parameter(title: "English Definition")
    var definition: String

    @Parameter(title: "Pinyin", default: "")
    var pinyin: String

    @Parameter(title: "Part of Speech", default: "")
    var partOfSpeech: String

    @Parameter(title: "Save as Phrase", default: false)
    var saveAsPhrase: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$chinese) to vocabulary") {
            \.$definition
            \.$pinyin
            \.$partOfSpeech
            \.$saveAsPhrase
        }
    }

    func perform() async throws -> some IntentResult {
        let trimmedChinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChinese.isEmpty, !trimmedDefinition.isEmpty else {
            throw TranslationIntentError.emptyText
        }

        var resolvedPartOfSpeech = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedPartOfSpeech.isEmpty && saveAsPhrase {
            resolvedPartOfSpeech = "phrase"
        }

        let resolvedPinyin = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPinyin = await MainActor.run {
            resolvedPinyin.isEmpty ? PinyinConverter.convert(trimmedChinese) : resolvedPinyin
        }

        let finalPartOfSpeech = resolvedPartOfSpeech

        await MainActor.run {
            let term = SavedTerm(
                chinese: trimmedChinese,
                pinyin: finalPinyin,
                definition: trimmedDefinition,
                partOfSpeech: finalPartOfSpeech
            )
            SavedTermsStore.shared.add(term)
        }

        return .result(dialog: "Saved to vocabulary.")
    }
}
