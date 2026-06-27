//
//  SavedTerm.swift
//  SwiftMandarin
//
//  Model for saved vocabulary terms
//

import Foundation
import SwiftUI
import Observation

struct SavedTerm: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let chinese: String
    let pinyin: String
    let definition: String
    let partOfSpeech: String
    let dateAdded: Date
    var sortOrder: Int
    var isMastered: Bool
    
    init(
        id: UUID = UUID(),
        chinese: String,
        pinyin: String,
        definition: String,
        partOfSpeech: String = "",
        dateAdded: Date = Date(),
        sortOrder: Int = 0,
        isMastered: Bool = false
    ) {
        self.id = id
        self.chinese = chinese
        self.pinyin = pinyin
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.dateAdded = dateAdded
        self.sortOrder = sortOrder
        self.isMastered = isMastered
    }

    private enum CodingKeys: String, CodingKey {
        case id, chinese, pinyin, definition, partOfSpeech, dateAdded, sortOrder, isMastered
    }

    /// Tolerant decoder: a missing or malformed field falls back to a default
    /// rather than throwing and dropping the whole saved term.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        chinese = (try? c.decode(String.self, forKey: .chinese)) ?? ""
        pinyin = (try? c.decode(String.self, forKey: .pinyin)) ?? ""
        definition = (try? c.decode(String.self, forKey: .definition)) ?? ""
        partOfSpeech = (try? c.decode(String.self, forKey: .partOfSpeech)) ?? ""
        dateAdded = (try? c.decode(Date.self, forKey: .dateAdded)) ?? Date()
        sortOrder = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
        isMastered = (try? c.decode(Bool.self, forKey: .isMastered)) ?? false
    }
}

// MARK: - Interface-language-aware display

/// The `chinese` field is really a *headword*: photo-extraction and workbook
/// flows store English headwords there when the user is learning English. So
/// the two display sides are detected from content, and which side is the big
/// headline follows the interface language (= the user's native language):
/// 中文 UI → learning English → English is the headline, Mandarin the gloss;
/// English UI → learning Mandarin → Chinese headline + pinyin, English gloss.
extension SavedTerm {

    /// The Chinese side of the entry (headword preferred, else definition).
    var chineseSide: String {
        if chinese.containsCJK { return chinese }
        if definition.containsCJK { return definition }
        return ""
    }

    /// The English side of the entry (headword preferred, else definition).
    var englishSide: String {
        if !chinese.containsCJK, !chinese.isEmpty { return chinese }
        if !definition.containsCJK { return definition }
        return ""
    }

    /// The text shown big — the side in the language the user is learning.
    /// Falls back to the headword when the entry has no text in that language.
    @MainActor
    var headlineText: String {
        let primary = LocalizationManager.shared.learningIsChinese ? chineseSide : englishSide
        return primary.isEmpty ? chinese : primary
    }

    /// The small secondary text — the side in the user's native language.
    /// Empty when the entry has nothing beyond the headline.
    @MainActor
    var glossText: String {
        let secondary = LocalizationManager.shared.learningIsChinese ? englishSide : chineseSide
        return secondary == headlineText ? "" : secondary
    }

    /// Pinyin is a learner aid for reading Chinese: shown only when the user
    /// is learning Chinese (English UI) and the entry has a Chinese side.
    @MainActor
    var showsPinyin: Bool {
        LocalizationManager.shared.learningIsChinese && !chineseSide.isEmpty && !pinyin.isEmpty
    }

    /// Headword forms an AI explanation might be cached under. The analyzed word
    /// is `headlineText`, which is either side depending on the learning
    /// direction at generation time, so export gathers explanations matching any
    /// of these (deduplicated, non-empty). Non-isolated so it is usable off the
    /// main actor (it reads only content-derived sides, not the interface
    /// language).
    var aiCacheCandidateWords: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for candidate in [chinese, chineseSide, englishSide] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            out.append(trimmed)
        }
        return out
    }
}

// MARK: - Saved Terms Store

@Observable
@MainActor
final class SavedTermsStore {
    static let shared = SavedTermsStore()
    
    var terms: [SavedTerm] = [] {
        didSet { save() }
    }
    
    /// Public accessor for saved terms (alias for terms)
    var savedTerms: [SavedTerm] { terms }
    
    private let saveKey = "savedTerms"
    
    private init() {
        load()
    }
    
    // MARK: - Public Methods

    /// Normalize a term for duplicate comparison: AI/OCR sources can attach
    /// invisible characters (zero-width space/joiners, BOM) or stray
    /// whitespace, which would defeat plain string equality.
    private static func normalizedKey(_ s: String) -> String {
        String(s.unicodeScalars.filter { ![0x200B, 0x200C, 0x200D, 0xFEFF].contains($0.value) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func add(_ term: SavedTerm) {
        let key = Self.normalizedKey(term.chinese)
        guard !terms.contains(where: { Self.normalizedKey($0.chinese) == key }) else { return }
        var newTerm = term
        newTerm.sortOrder = terms.count
        terms.append(newTerm)
        // Track activity with part of speech
        LearningActivityStore.shared.recordWordLearned(partOfSpeech: term.partOfSpeech)
    }

    func add(chinese: String, pinyin: String, definition: String, partOfSpeech: String = "") {
        let key = Self.normalizedKey(chinese)
        guard !terms.contains(where: { Self.normalizedKey($0.chinese) == key }) else { return }

        let newTerm = SavedTerm(
            chinese: chinese,
            pinyin: pinyin,
            definition: definition,
            partOfSpeech: partOfSpeech,
            sortOrder: terms.count
        )
        terms.append(newTerm)
        // Track activity with part of speech
        LearningActivityStore.shared.recordWordLearned(partOfSpeech: partOfSpeech)
    }
    
    func remove(at offsets: IndexSet) {
        var updated = terms
        let removed = offsets.compactMap { terms.indices.contains($0) ? terms[$0] : nil }
        updated.remove(atOffsets: offsets)
        terms = reindexed(updated)
        purgeProgress(for: removed)
    }

    func remove(_ term: SavedTerm) {
        terms = reindexed(terms.filter { $0.id != term.id })
        purgeProgress(for: [term])
    }

    func remove(chinese: String) {
        let key = Self.normalizedKey(chinese)
        let removed = terms.filter { Self.normalizedKey($0.chinese) == key }
        terms = reindexed(terms.filter { Self.normalizedKey($0.chinese) != key })
        purgeProgress(for: removed)
    }

    func term(withID id: UUID) -> SavedTerm? {
        terms.first { $0.id == id }
    }

    /// Replace a stored term. Returns `false` when the term no longer exists
    /// (e.g. it was deleted while a detail view held a stale copy), so callers
    /// can surface the failure instead of silently dropping the edit.
    @discardableResult
    func update(_ updatedTerm: SavedTerm) -> Bool {
        guard let index = terms.firstIndex(where: { $0.id == updatedTerm.id }) else { return false }

        var replacement = updatedTerm
        replacement.sortOrder = terms[index].sortOrder
        terms[index] = replacement
        return true
    }
    
    func move(from source: Int, to destination: Int) {
        var updated = terms
        updated.move(fromOffsets: IndexSet(integer: source), toOffset: destination)
        terms = reindexed(updated)
    }
    
    func contains(chinese: String) -> Bool {
        let key = Self.normalizedKey(chinese)
        return terms.contains { Self.normalizedKey($0.chinese) == key }
    }
    
    func clear() {
        let removed = terms
        terms.removeAll()
        purgeProgress(for: removed)
    }
    
    /// Toggle the mastered status of a term
    func toggleMastered(_ term: SavedTerm) {
        guard let index = terms.firstIndex(where: { $0.id == term.id }) else { return }
        terms[index].isMastered.toggle()
    }
    
    /// Set the mastered status of a term
    func setMastered(_ term: SavedTerm, isMastered: Bool) {
        guard let index = terms.firstIndex(where: { $0.id == term.id }) else { return }
        terms[index].isMastered = isMastered
    }
    
    /// Count of mastered terms
    var masteredCount: Int {
        terms.filter { $0.isMastered }.count
    }
    
    // MARK: - Private Methods

    /// Purge the SRS review progress of removed terms. Vocabulary cards are
    /// keyed "vocab:<uuid>" in `LearningProgressStore`, so without this a
    /// deleted word would leave an orphaned card that keeps resurfacing in
    /// due/review queues forever.
    private func purgeProgress(for removed: [SavedTerm]) {
        for term in removed {
            LearningProgressStore.shared.removeProgress(forCardId: "vocab:\(term.id.uuidString)")
        }
    }

    /// Return a copy of `terms` with `sortOrder` renumbered to match array
    /// position. Callers assign the result to `terms` in a single statement so
    /// the `didSet` persistence hook fires exactly once. Renumbering in place
    /// (`terms[i].sortOrder = i` in a loop) instead triggers `save()` for every
    /// row, turning one delete into an O(n²) synchronous JSON-encode +
    /// UserDefaults write storm that freezes the UI on large lists.
    private func reindexed(_ source: [SavedTerm]) -> [SavedTerm] {
        var result = source
        for index in result.indices {
            result[index].sortOrder = index
        }
        return result
    }
    
    private func save() {
        PersistentCodableStore.save(terms, key: saveKey)
    }

    private func load() {
        if let decoded = PersistentCodableStore.load([SavedTerm].self, key: saveKey) {
            terms = decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
}
