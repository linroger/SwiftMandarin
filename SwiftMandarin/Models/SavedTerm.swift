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
    ///
    /// A one-sided entry (saved before the learner switched direction, or
    /// captured with only a headword) has nothing in the studied language. It
    /// still has to render *something*, so the other side is promoted rather
    /// than leaving a blank row — and `glossText` then correctly returns "",
    /// because the promoted text is already on screen.
    @MainActor
    var headlineText: String {
        let context = LearningContext.current
        let primary = context.primary(chinese: chineseSide, english: englishSide)
        guard primary.isEmpty else { return primary }
        let fallback = context.secondary(chinese: chineseSide, english: englishSide)
        return fallback.isEmpty ? chinese : fallback
    }

    /// The small secondary text — the side in the user's native language.
    /// Empty when the entry has nothing beyond the headline.
    @MainActor
    var glossText: String {
        let secondary = LearningContext.current.secondary(chinese: chineseSide, english: englishSide)
        return secondary == headlineText ? "" : secondary
    }

    /// Pinyin is a learner aid for reading Chinese: shown only when the user
    /// is learning Chinese (English UI) and the entry has a Chinese side.
    ///
    /// The mirror aid — an English pronunciation for a Mandarin speaker — is
    /// `showsPhonetic`, since the two are never useful at the same time.
    @MainActor
    var showsPinyin: Bool {
        LearningContext.current.showsPinyinAffordances && !chineseSide.isEmpty && !pinyin.isEmpty
    }

    /// Whether the stored reading should be shown as an English pronunciation
    /// under an English headword.
    ///
    /// In reverse mode the AI fills the same `pinyin` slot with IPA (see
    /// `AIExplanationPromptBuilder`), so no new storage is needed — only a
    /// rule for when to read it that way. The `looksLikeIPA` guard matters:
    /// a term saved while learning Mandarin holds *pinyin* there, and showing
    /// "xuéxí" under the headword "study" would be worse than showing nothing.
    @MainActor
    var showsPhonetic: Bool {
        !LearningContext.current.showsPinyinAffordances
            && !englishSide.isEmpty
            && pinyin.looksLikeIPA
            && headlineText == englishSide
    }

    /// The stored reading, but only when it actually belongs to `headlineText`.
    ///
    /// One field holds the reading for both directions, so an entry saved
    /// while learning Mandarin carries pinyin for its Chinese side. Handing
    /// that to an explanation request for the English headword — where it is
    /// read as a sense hint — would be misleading noise, and pasting it into a
    /// copied English word would be nonsense. Empty when the two don't match.
    @MainActor
    var headwordReading: String {
        if showsPinyin, headlineText == chineseSide { return pinyin }
        if showsPhonetic { return pinyin }
        return ""
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
    ///
    /// Case is folded too. Han characters have no case, so this changes
    /// nothing for a Mandarin headword — but an English headword captured at
    /// the start of a sentence ("Charge") would otherwise be stored a second
    /// time alongside the same word met mid-sentence ("charge"). This mirrors
    /// `WordExplanationCacheStore`, which already folds case for the same
    /// reason.
    private static func normalizedKey(_ s: String) -> String {
        String(s.unicodeScalars.filter { ![0x200B, 0x200C, 0x200D, 0xFEFF].contains($0.value) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func add(_ term: SavedTerm) {
        let key = Self.normalizedKey(term.chinese)
        guard !terms.contains(where: { Self.normalizedKey($0.chinese) == key }) else { return }
        var newTerm = term
        newTerm.sortOrder = terms.count
        terms.append(newTerm)
        // Track activity with part of speech
        LearningActivityStore.shared.recordWordLearned(partOfSpeech: term.partOfSpeech)
        // Every capture surface (translate, photo, reader, Shortcuts, import)
        // funnels through here, so this one call is what makes "analyze new
        // words automatically" cover all of them. It is inert unless the user
        // has opted in.
        AutoAnalysisCoordinator.shared.noteTermAdded(newTerm)
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
        AutoAnalysisCoordinator.shared.noteTermAdded(newTerm)
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
