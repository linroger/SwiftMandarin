//
//  LookupVocabularyIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct LookupVocabularyIntent: AppIntent {
    static var title: LocalizedStringResource = "Look Up Vocabulary"
    static var description = IntentDescription("Search your saved vocabulary by headword, meaning, or pinyin — with or without tone marks — and return the matching terms.")

    @Parameter(title: "Query")
    var query: String

    @Parameter(title: "Include Mastered", default: true)
    var includeMastered: Bool

    @Parameter(title: "Limit", default: 10)
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Find vocabulary matching \(\.$query)") {
            \.$includeMastered
            \.$limit
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SavedTermEntity]> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(value: [], dialog: IntentDialog(stringLiteral: String(localized: "Nothing to search for.", bundle: .appLanguage)))
        }

        let matched = SavedTermsStore.shared.terms.filter { SavedTermEntityQuery.matches($0, query: trimmed) }
        let filtered = includeMastered ? matched : matched.filter { !$0.isMastered }
        let results = filtered.prefix(max(1, limit)).map(SavedTermEntity.init)

        // Siri speaks the dialog; the first match is the useful part. The
        // count is every match, not the `limit` returned — "10 matches" for
        // 37 understated a broad pinyin query.
        let dialog: String
        if let first = results.first {
            dialog = filtered.count == 1
                ? "\(first.headline) — \(first.gloss)"
                : String(format: String(localized: "%lld matches. First: %@ — %@", bundle: .appLanguage), Int64(filtered.count), first.headline, first.gloss)
        } else {
            dialog = String(format: String(localized: "No saved words match “%@”.", bundle: .appLanguage), trimmed)
        }
        return .result(value: Array(results), dialog: IntentDialog(stringLiteral: dialog))
    }
}
