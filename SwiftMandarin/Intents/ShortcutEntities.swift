//
//  ShortcutEntities.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct SavedTermEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Saved Term")
    }

    static var defaultQuery = SavedTermEntityQuery()

    let id: UUID
    let chinese: String
    let pinyin: String
    let definition: String
    let partOfSpeech: String
    let isMastered: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: chinese),
            subtitle: LocalizedStringResource(stringLiteral: definition)
        )
    }

    init(term: SavedTerm) {
        self.id = term.id
        self.chinese = term.chinese
        self.pinyin = term.pinyin
        self.definition = term.definition
        self.partOfSpeech = term.partOfSpeech
        self.isMastered = term.isMastered
    }
}

struct SavedTermEntityQuery: EntityQuery {
    func entities(for identifiers: [SavedTermEntity.ID]) async throws -> [SavedTermEntity] {
        await MainActor.run {
            SavedTermsStore.shared.terms
                .filter { identifiers.contains($0.id) }
                .map(SavedTermEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SavedTermEntity] {
        await MainActor.run {
            Array(SavedTermsStore.shared.terms.prefix(20)).map(SavedTermEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SavedTermEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        return await MainActor.run {
            SavedTermsStore.shared.terms
                .filter { term in
                    term.chinese.localizedCaseInsensitiveContains(trimmed) ||
                    term.pinyin.localizedCaseInsensitiveContains(trimmed) ||
                    term.definition.localizedCaseInsensitiveContains(trimmed)
                }
                .map(SavedTermEntity.init)
        }
    }
}

struct PhraseEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Phrase")
    }

    static var defaultQuery = PhraseEntityQuery()

    let id: UUID
    let chinese: String
    let pinyin: String
    let english: String
    let category: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: chinese),
            subtitle: LocalizedStringResource(stringLiteral: english)
        )
    }

    init(phrase: Phrase, category: String) {
        self.id = phrase.id
        self.chinese = phrase.chinese
        self.pinyin = phrase.pinyin
        self.english = phrase.english
        self.category = category
    }
}

struct PhraseEntityQuery: EntityQuery {
    func entities(for identifiers: [PhraseEntity.ID]) async throws -> [PhraseEntity] {
        await MainActor.run {
            let all = PhraseCategory.allCategories.flatMap { category in
                category.phrases.map { PhraseEntity(phrase: $0, category: category.name) }
            }
            return all.filter { identifiers.contains($0.id) }
        }
    }

    func suggestedEntities() async throws -> [PhraseEntity] {
        await MainActor.run {
            PhraseCategory.allCategories
                .prefix(4)
                .flatMap { category in
                    category.phrases.prefix(5).map { PhraseEntity(phrase: $0, category: category.name) }
                }
        }
    }

    func entities(matching string: String) async throws -> [PhraseEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        return await MainActor.run {
            PhraseCategory.allCategories.flatMap { category in
                category.phrases
                    .filter { phrase in
                        phrase.chinese.localizedCaseInsensitiveContains(trimmed) ||
                        phrase.pinyin.localizedCaseInsensitiveContains(trimmed) ||
                        phrase.english.localizedCaseInsensitiveContains(trimmed)
                    }
                    .map { PhraseEntity(phrase: $0, category: category.name) }
            }
        }
    }
}
