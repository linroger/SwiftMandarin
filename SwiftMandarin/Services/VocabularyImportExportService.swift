//
//  VocabularyImportExportService.swift
//  SwiftMandarin
//
//  Service for importing and exporting vocabulary data with duplicate detection
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Export Format

enum VocabularyExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case csv = "CSV"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }
    
    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}

// MARK: - Import Result

struct ImportResult {
    let imported: Int
    let skipped: Int
    let errors: [String]
    
    var summary: String {
        var parts: [String] = []
        if imported > 0 {
            parts.append("\(imported) word\(imported == 1 ? "" : "s") imported")
        }
        if skipped > 0 {
            parts.append("\(skipped) duplicate\(skipped == 1 ? "" : "s") skipped")
        }
        if errors.isEmpty {
            return parts.joined(separator: ", ")
        } else {
            return parts.joined(separator: ", ") + ". Errors: \(errors.count)"
        }
    }
}

// MARK: - Vocabulary Import/Export Service

@MainActor
final class VocabularyImportExportService {
    static let shared = VocabularyImportExportService()
    
    private init() {}
    
    // MARK: - Export
    
    /// Generates export data in the specified format
    func generateExportData(terms: [SavedTerm], format: VocabularyExportFormat) -> Data? {
        switch format {
        case .json:
            return generateJSONExport(terms: terms)
        case .csv:
            return generateCSVExport(terms: terms)
        }
    }
    
    private func generateJSONExport(terms: [SavedTerm]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(terms)
    }
    
    private func generateCSVExport(terms: [SavedTerm]) -> Data? {
        var csv = "Chinese,Pinyin,Definition,Part of Speech,Date Added\n"
        for term in terms {
            let chinese = escapeCSV(term.chinese)
            let pinyin = escapeCSV(term.pinyin)
            let definition = escapeCSV(term.definition)
            let pos = escapeCSV(term.partOfSpeech)
            let date = ISO8601DateFormatter().string(from: term.dateAdded)
            csv += "\(chinese),\(pinyin),\(definition),\(pos),\(date)\n"
        }
        return csv.data(using: .utf8)
    }
    
    private func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
    
    /// Export to file using system file dialog
    #if os(macOS)
    func exportToFile(terms: [SavedTerm], format: VocabularyExportFormat) {
        guard let data = generateExportData(terms: terms, format: format) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: format.fileExtension)!]
        savePanel.nameFieldStringValue = "SwiftMandarin_Vocabulary.\(format.fileExtension)"
        savePanel.title = "Export Vocabulary"
        savePanel.message = "Choose where to save your vocabulary export"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                } catch {
                    print("Export failed: \(error)")
                }
            }
        }
    }
    #endif
    
    // MARK: - Import
    
    /// Parse import data and return terms, detecting format automatically
    func parseImportData(_ data: Data) -> [SavedTerm]? {
        // Try JSON first
        if let terms = parseJSONImport(data) {
            return terms
        }
        // Try CSV
        if let terms = parseCSVImport(data) {
            return terms
        }
        return nil
    }
    
    private func parseJSONImport(_ data: Data) -> [SavedTerm]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([SavedTerm].self, from: data)
    }
    
    private func parseCSVImport(_ data: Data) -> [SavedTerm]? {
        guard let content = String(data: data, encoding: .utf8) else { return nil }
        
        var terms: [SavedTerm] = []
        let lines = content.components(separatedBy: .newlines)
        
        // Skip header row
        for (index, line) in lines.enumerated() {
            guard index > 0, !line.isEmpty else { continue }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 3 else { continue }
            
            let chinese = columns[0]
            let pinyin = columns.count > 1 ? columns[1] : ""
            let definition = columns.count > 2 ? columns[2] : ""
            let partOfSpeech = columns.count > 3 ? columns[3] : ""
            
            var dateAdded = Date()
            if columns.count > 4, let parsedDate = ISO8601DateFormatter().date(from: columns[4]) {
                dateAdded = parsedDate
            }
            
            let term = SavedTerm(
                chinese: chinese,
                pinyin: pinyin,
                definition: definition,
                partOfSpeech: partOfSpeech,
                dateAdded: dateAdded
            )
            terms.append(term)
        }
        
        return terms.isEmpty ? nil : terms
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    // Escaped quote
                    current.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
            i += 1
        }
        columns.append(current)
        
        return columns
    }
    
    /// Import terms with duplicate detection
    /// Returns ImportResult with count of imported, skipped, and any errors
    func importTerms(_ newTerms: [SavedTerm], into store: SavedTermsStore) -> ImportResult {
        var imported = 0
        var skipped = 0
        var errors: [String] = []
        
        for term in newTerms {
            // Check for duplicates based on Chinese text
            if store.contains(chinese: term.chinese) {
                skipped += 1
            } else {
                store.add(term)
                imported += 1
            }
        }
        
        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }
    
    #if os(macOS)
    /// Import from file using system file dialog
    func importFromFile(into store: SavedTermsStore, completion: @escaping (ImportResult?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [
            .init(filenameExtension: "json")!,
            .init(filenameExtension: "csv")!
        ]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Vocabulary"
        openPanel.message = "Select a vocabulary file to import"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    if let terms = self.parseImportData(data) {
                        let result = self.importTerms(terms, into: store)
                        completion(result)
                    } else {
                        completion(ImportResult(imported: 0, skipped: 0, errors: ["Could not parse file"]))
                    }
                } catch {
                    completion(ImportResult(imported: 0, skipped: 0, errors: [error.localizedDescription]))
                }
            } else {
                completion(nil)
            }
        }
    }
    #endif
}

// MARK: - Transferable for ShareLink/Drag-Drop

struct VocabularyExportDocument: Transferable {
    let terms: [SavedTerm]
    let format: VocabularyExportFormat
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { document in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return (try? encoder.encode(document.terms)) ?? Data()
        }
    }
}
