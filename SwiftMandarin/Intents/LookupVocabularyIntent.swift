//
//  LookupVocabularyIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct LookupVocabularyIntent: AppIntent {
    static var title: LocalizedStringResource = "Lookup Vocabulary"
    static var description = IntentDescription("Search your saved vocabulary and return matching terms.")

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

    func perform() async throws -> some IntentResult & ReturnsValue<[SavedTermEntity]> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(value: [])
        }

        let results = await MainActor.run { () -> [SavedTermEntity] in
            let matched = SavedTermsStore.shared.terms.filter { term in
                term.chinese.localizedCaseInsensitiveContains(trimmed) ||
                term.pinyin.localizedCaseInsensitiveContains(trimmed) ||
                term.definition.localizedCaseInsensitiveContains(trimmed)
            }

            let filtered = includeMastered ? matched : matched.filter { !$0.isMastered }
            return filtered.prefix(max(1, limit)).map(SavedTermEntity.init)
        }

        return .result(value: results)
    }
}
