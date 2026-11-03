//
//  SaveVocabularyTermIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct SaveVocabularyTermIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Vocabulary Term"
    static var description = IntentDescription("Save a word or phrase in the language you are learning, with its meaning in your own language, to your vocabulary list.")

    // The stored property names are part of existing Shortcuts, so they keep
    // their names; only the titles changed. `chinese` is the headword slot —
    // for a Mandarin speaker studying English it holds the English word, just
    // as it does for every in-app save.
    @Parameter(title: "Word or Phrase", description: "The word in the language you are learning.")
    var chinese: String

    @Parameter(title: "Meaning", description: "Its meaning in your own language.")
    var definition: String

    @Parameter(title: "Pinyin", description: "Reading of a Chinese word; derived automatically when left empty.", default: "")
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

    @MainActor
    func perform() async throws -> some IntentResult {
        let headword = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !headword.isEmpty, !meaning.isEmpty else {
            throw TranslationIntentError.emptyText
        }

        var resolvedPartOfSpeech = partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedPartOfSpeech.isEmpty && saveAsPhrase {
            resolvedPartOfSpeech = "phrase"
        }

        let store = SavedTermsStore.shared
        // Duplicate on either side: "Hello / 你好" already saved must stop
        // "你好 / Hello", and the old "Saved." after a silent skip told the
        // learner something that had not happened.
        guard !store.contains(chinese: headword), !store.contains(chinese: meaning) else {
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "Already in your vocabulary.", bundle: .appLanguage)))
        }

        // Pinyin is a reading for a Chinese headword only; an English headword
        // gets its IPA from an AI explanation later, never a converted blank.
        let suppliedPinyin = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPinyin: String
        if !suppliedPinyin.isEmpty {
            resolvedPinyin = suppliedPinyin
        } else if headword.containsCJK {
            resolvedPinyin = PinyinConverter.convert(headword)
        } else {
            resolvedPinyin = ""
        }

        store.add(
            SavedTerm(
                chinese: headword,
                pinyin: resolvedPinyin,
                definition: meaning,
                partOfSpeech: resolvedPartOfSpeech
            )
        )
        // Written now, not 250 ms later: a background run can be suspended
        // the moment it returns, after the dialog already said "Saved".
        ShortcutHelpers.persistIntentChanges()

        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Saved to vocabulary.", bundle: .appLanguage)))
    }
}
