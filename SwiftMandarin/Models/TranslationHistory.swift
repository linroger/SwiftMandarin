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
    private let maxEntries = 100
    
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
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([TranslationHistoryEntry].self, from: data) {
            entries = decoded
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
