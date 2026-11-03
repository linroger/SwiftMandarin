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

    // `@Property` is what exposes a field to Shortcuts actions ("Get Details
    // of Saved Term", text substitution); plain stored values were invisible.
    @Property(title: "Headword")
    var chinese: String

    @Property(title: "Pinyin")
    var pinyin: String

    @Property(title: "Meaning")
    var definition: String

    @Property(title: "Part of Speech")
    var partOfSpeech: String

    @Property(title: "Mastered")
    var isMastered: Bool

    /// The Chinese side of the entry, detected by content because the headword
    /// field can hold either language.
    var chineseSide: String {
        chinese.containsCJK ? chinese : (definition.containsCJK ? definition : "")
    }

    /// The English side of the entry.
    var englishSide: String {
        (!chinese.containsCJK && !chinese.isEmpty) ? chinese : (!definition.containsCJK ? definition : "")
    }

    /// The side in the language being learned (中文 UI → English, English UI → Chinese).
    var headline: String {
        let learningEnglish = AppLanguage.persisted == .chinese
        let preferred = learningEnglish ? englishSide : chineseSide
        return preferred.isEmpty ? chinese : preferred
    }

    /// The side in the learner's own language.
    var gloss: String {
        let learningEnglish = AppLanguage.persisted == .chinese
        let secondary = learningEnglish ? chineseSide : englishSide
        return secondary == headline ? "" : secondary
    }

    var displayRepresentation: DisplayRepresentation {
        // Pinyin is a learner aid for reading Chinese, so it joins the
        // subtitle only when the learner studies Chinese and the entry has it.
        let learningChinese = AppLanguage.persisted != .chinese
        var subtitle = gloss
        if learningChinese, !chineseSide.isEmpty, !pinyin.isEmpty, !pinyin.looksLikeIPA {
            subtitle = subtitle.isEmpty ? pinyin : "\(pinyin) · \(subtitle)"
        }
        if subtitle.isEmpty {
            return DisplayRepresentation(title: LocalizedStringResource(stringLiteral: headline))
        }
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: headline),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
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

/// `EntityStringQuery` is what makes `entities(matching:)` reachable from the
/// Shortcuts picker; as a plain `EntityQuery` the search was never called.
struct SavedTermEntityQuery: EntityStringQuery {
    /// Upper bound on results handed to Shortcuts, so a large vocabulary does
    /// not come back wholesale.
    static let resultLimit = 50

    // Entity queries run off the main actor; the store lives on it.
    func entities(for identifiers: [SavedTermEntity.ID]) async throws -> [SavedTermEntity] {
        let wanted = Set(identifiers)
        return await MainActor.run {
            SavedTermsStore.shared.terms
                .filter { wanted.contains($0.id) }
                .map(SavedTermEntity.init)
        }
    }

    func suggestedEntities() async throws -> [SavedTermEntity] {
        // Newest first — the words the learner saved most recently are the
        // ones they are most likely to reach for.
        await MainActor.run {
            Array(
                SavedTermsStore.shared.terms
                    .sorted { $0.dateAdded > $1.dateAdded }
                    .prefix(20)
            ).map(SavedTermEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [SavedTermEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return await MainActor.run {
            Array(
                SavedTermsStore.shared.terms
                    .filter { Self.matches($0, query: trimmed) }
                    .prefix(Self.resultLimit)
            ).map(SavedTermEntity.init)
        }
    }

    /// Whether a term matches a typed or dictated query. Pinyin is compared
    /// without tone marks and spaces, because neither dictation nor an
    /// ordinary keyboard produces "nǐ hǎo" — they produce "ni hao" or
    /// "nihao".
    static func matches(_ term: SavedTerm, query: String) -> Bool {
        if term.chinese.localizedCaseInsensitiveContains(query)
            || term.definition.localizedCaseInsensitiveContains(query) {
            return true
        }
        guard !term.pinyin.isEmpty else { return false }
        let needle = Self.foldedPinyin(query)
        guard !needle.isEmpty else { return false }
        return Self.foldedPinyin(term.pinyin).contains(needle)
    }

    /// Tone marks, spaces, and case removed, so "nǐ hǎo", "ni hao", and
    /// "nihao" compare equal. Shared with the in-app global search.
    static func foldedPinyin(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

struct PhraseEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Phrase")
    }

    static var defaultQuery = PhraseEntityQuery()

    /// Stable across launches (see `Phrase.id`), so a phrase stored in a
    /// Shortcut resolves again tomorrow.
    let id: String

    @Property(title: "Chinese")
    var chinese: String

    @Property(title: "Pinyin")
    var pinyin: String

    @Property(title: "English")
    var english: String

    @Property(title: "Category")
    var category: String

    var displayRepresentation: DisplayRepresentation {
        // The learning-language side is the title (see SavedTermEntity).
        let learningEnglish = AppLanguage.persisted == .chinese
        let subtitle = learningEnglish ? chinese : "\(pinyin) · \(english)"
        return DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: learningEnglish ? english : chinese),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }

    /// `category` is the catalog name (`PhraseCategory.name`); the exposed
    /// property is its display name in the app's language, as the Phrases
    /// screen shows it. Matching never reads it back, so nothing depends on
    /// the English value.
    init(phrase: Phrase, category: String) {
        self.id = phrase.id
        self.chinese = phrase.chinese
        self.pinyin = phrase.pinyin
        self.english = phrase.english
        self.category = String(localized: String.LocalizationValue(category), bundle: .appLanguage)
    }
}

struct PhraseEntityQuery: EntityStringQuery {
    func entities(for identifiers: [PhraseEntity.ID]) async throws -> [PhraseEntity] {
        let wanted = Set(identifiers)
        return await MainActor.run {
            PhraseCategory.allCategories.flatMap { category in
                category.phrases
                    .filter { wanted.contains($0.id) }
                    .map { PhraseEntity(phrase: $0, category: category.name) }
            }
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
        guard !trimmed.isEmpty else { return [] }
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
