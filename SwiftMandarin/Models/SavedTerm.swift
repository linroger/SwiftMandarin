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
        terms.remove(atOffsets: offsets)
        updateSortOrders()
    }
    
    func remove(_ term: SavedTerm) {
        terms.removeAll { $0.id == term.id }
        updateSortOrders()
    }

    func remove(chinese: String) {
        let key = Self.normalizedKey(chinese)
        terms.removeAll { Self.normalizedKey($0.chinese) == key }
        updateSortOrders()
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
        terms.move(fromOffsets: IndexSet(integer: source), toOffset: destination)
        updateSortOrders()
    }
    
    func contains(chinese: String) -> Bool {
        let key = Self.normalizedKey(chinese)
        return terms.contains { Self.normalizedKey($0.chinese) == key }
    }
    
    func clear() {
        terms.removeAll()
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
    
    private func updateSortOrders() {
        for (index, _) in terms.enumerated() {
            terms[index].sortOrder = index
        }
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
