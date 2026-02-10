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
    
    init(
        id: UUID = UUID(),
        chinese: String,
        pinyin: String,
        definition: String,
        partOfSpeech: String = "",
        dateAdded: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.chinese = chinese
        self.pinyin = pinyin
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.dateAdded = dateAdded
        self.sortOrder = sortOrder
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
    
    private let saveKey = "savedTerms"
    
    private init() {
        load()
    }
    
    // MARK: - Public Methods
    
    func add(_ term: SavedTerm) {
        guard !terms.contains(where: { $0.chinese == term.chinese }) else { return }
        var newTerm = term
        newTerm.sortOrder = terms.count
        terms.append(newTerm)
    }
    
    func add(chinese: String, pinyin: String, definition: String, partOfSpeech: String = "") {
        guard !terms.contains(where: { $0.chinese == chinese }) else { return }
        
        let newTerm = SavedTerm(
            chinese: chinese,
            pinyin: pinyin,
            definition: definition,
            partOfSpeech: partOfSpeech,
            sortOrder: terms.count
        )
        terms.append(newTerm)
    }
    
    func remove(at offsets: IndexSet) {
        terms.remove(atOffsets: offsets)
        updateSortOrders()
    }
    
    func remove(_ term: SavedTerm) {
        terms.removeAll { $0.id == term.id }
        updateSortOrders()
    }
    
    func move(from source: Int, to destination: Int) {
        terms.move(fromOffsets: IndexSet(integer: source), toOffset: destination)
        updateSortOrders()
    }
    
    func contains(chinese: String) -> Bool {
        terms.contains { $0.chinese == chinese }
    }
    
    func clear() {
        terms.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func updateSortOrders() {
        for (index, _) in terms.enumerated() {
            terms[index].sortOrder = index
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(terms) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([SavedTerm].self, from: data) {
            terms = decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
}
