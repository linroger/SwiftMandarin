//
//  TranslationHistory.swift
//  SwiftMandarin
//
//  Model and store for translation history
//

import Foundation
import SwiftUI
import Observation

struct TranslationHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let source: String
    let target: String
    let direction: TranslationDirection
    let date: Date
    
    init(source: String, target: String, direction: TranslationDirection, date: Date = Date()) {
        self.id = UUID()
        self.source = source
        self.target = target
        self.direction = direction
        self.date = date
    }

    private enum CodingKeys: String, CodingKey {
        case id, source, target, direction, date
    }

    /// Tolerant decoder: a missing or malformed field falls back to a default
    /// rather than throwing and dropping the whole row.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        source = (try? c.decode(String.self, forKey: .source)) ?? ""
        target = (try? c.decode(String.self, forKey: .target)) ?? ""
        direction = (try? c.decode(TranslationDirection.self, forKey: .direction)) ?? .englishToChinese
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
    }

    var chineseText: String {
        direction == .englishToChinese ? target : source
    }
    
    var englishText: String {
        direction == .englishToChinese ? source : target
    }
}

// MARK: - Translation History Store

@Observable
@MainActor
final class TranslationHistoryStore {
    static let shared = TranslationHistoryStore()
    
    private(set) var entries: [TranslationHistoryEntry] = []
    var selectedEntry: TranslationHistoryEntry?

    private let storageKey = "translationHistory"

    private var maxEntries: Int {
        if let doubleValue = UserDefaults.standard.object(forKey: "maxHistoryEntries") as? Double {
            return max(1, Int(doubleValue))
        }
        let intValue = UserDefaults.standard.integer(forKey: "maxHistoryEntries")
        return intValue > 0 ? intValue : 100
    }
    
    private init() {
        load()
    }
    
    func add(source: String, target: String, direction: TranslationDirection) {
        let entry = TranslationHistoryEntry(source: source, target: target, direction: direction)
        
        // Remove duplicates
        entries.removeAll { $0.source == source && $0.target == target }
        
        // Insert at the beginning
        entries.insert(entry, at: 0)
        
        // Trim to max entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        save()
        // Track activity
        LearningActivityStore.shared.recordTranslationMade()
    }
    
    func remove(_ entry: TranslationHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
        }
        save()
    }
    
    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func clear() {
        entries.removeAll()
        selectedEntry = nil
        save()
    }
    
    func select(_ entry: TranslationHistoryEntry) {
        selectedEntry = entry
    }
    
    private func load() {
        if let decoded = PersistentCodableStore.load([TranslationHistoryEntry].self, key: storageKey) {
            entries = decoded
        }
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    private func save() {
        PersistentCodableStore.save(entries, key: storageKey)
    }
}
