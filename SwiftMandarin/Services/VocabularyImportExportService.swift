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
    /// AI word-analyses restored into the explanation cache during this import.
    var explanationsRestored: Int = 0

    /// One-line result shown in the "Import Complete" alert.
    ///
    /// Every clause is a format string resolved through the string catalog
    /// instead of hand-concatenated English, because the assembled sentence was
    /// invisible to localization and reached a 中文 interface as English with
    /// English word order. `String.localizedStringWithFormat` is required for
    /// the counts because it is the only formatter that expands the plural
    /// variations a translator can later attach to these keys; it also formats
    /// the number for the active locale, so a four-digit count now reads
    /// "1,000" rather than "1000". The singular and plural wordings stay
    /// separate keys so English keeps its exact current phrasing until those
    /// plural rules exist.
    var summary: String {
        var parts: [String] = []
        if imported > 0 {
            parts.append(String.localizedStringWithFormat(
                imported == 1
                    ? String(localized: "%lld word imported", bundle: .appLanguage)
                    : String(localized: "%lld words imported", bundle: .appLanguage),
                imported
            ))
        }
        if skipped > 0 {
            parts.append(String.localizedStringWithFormat(
                skipped == 1
                    ? String(localized: "%lld duplicate skipped", bundle: .appLanguage)
                    : String(localized: "%lld duplicates skipped", bundle: .appLanguage),
                skipped
            ))
        }
        if explanationsRestored > 0 {
            parts.append(String.localizedStringWithFormat(
                explanationsRestored == 1
                    ? String(localized: "%lld AI analysis restored", bundle: .appLanguage)
                    : String(localized: "%lld AI analyses restored", bundle: .appLanguage),
                explanationsRestored
            ))
        }
        // Chinese uses a full-width comma between clauses, so even the joiner
        // has to come from the catalog rather than being a hard-coded ", ".
        var summary = parts.joined(separator: String(
            localized: ", ",
            comment: "Separator between the clauses of the vocabulary import summary."
        ))
        if summary.isEmpty { summary = String(localized: "Nothing to import", bundle: .appLanguage) }
        if !errors.isEmpty {
            summary = String.localizedStringWithFormat(
                String(localized: "%1$@. Errors: %2$lld", bundle: .appLanguage),
                summary,
                errors.count
            )
        }
        return summary
    }
}

// MARK: - Import Payload

/// Parsed contents of an import file: the vocabulary terms plus any AI
/// word-analyses bundled with them (empty for legacy files without AI data).
struct ImportedVocabulary {
    let terms: [SavedTerm]
    let explanations: [CachedWordExplanation]
}

// MARK: - Export Envelope (schema v2 — carries AI analysis)

/// Versioned JSON export that bundles each term with its cached AI analyses, so
/// the analysis round-trips losslessly. Legacy exports (a bare `[SavedTerm]`
/// array) remain importable; this richer object is tried first on import.
private struct ExportEnvelope: Codable {
    var schemaVersion: Int = 2
    var exportedAt: Date = Date()
    var terms: [ExportedTerm]
}

/// One term in the envelope: every `SavedTerm` field, plus the AI analyses
/// cached for it (across learning directions).
private struct ExportedTerm: Codable {
    let id: UUID
    let chinese: String
    let pinyin: String
    let definition: String
    let partOfSpeech: String
    let dateAdded: Date
    let sortOrder: Int
    let isMastered: Bool
    var aiExplanations: [CachedWordExplanation]?

    init(term: SavedTerm, explanations: [CachedWordExplanation]) {
        self.id = term.id
        self.chinese = term.chinese
        self.pinyin = term.pinyin
        self.definition = term.definition
        self.partOfSpeech = term.partOfSpeech
        self.dateAdded = term.dateAdded
        self.sortOrder = term.sortOrder
        self.isMastered = term.isMastered
        self.aiExplanations = explanations.isEmpty ? nil : explanations
    }

    var savedTerm: SavedTerm {
        SavedTerm(
            id: id,
            chinese: chinese,
            pinyin: pinyin,
            definition: definition,
            partOfSpeech: partOfSpeech,
            dateAdded: dateAdded,
            sortOrder: sortOrder,
            isMastered: isMastered
        )
    }
}

// MARK: - Vocabulary Import/Export Service

@MainActor
final class VocabularyImportExportService {
    static let shared = VocabularyImportExportService()
    
    private init() {}
    
    // MARK: - Export

    /// Generates export data in the specified format.
    /// - Parameter includeAIAnalysis: when true, each term's cached AI
    ///   word-analyses are bundled in (JSON: a versioned envelope; CSV: extra
    ///   columns including a lossless base64 payload). When false the legacy
    ///   shape (bare `[SavedTerm]` JSON / 6-column CSV) is produced, keeping old
    ///   importers happy.
    func generateExportData(
        terms: [SavedTerm],
        format: VocabularyExportFormat,
        includeAIAnalysis: Bool = false
    ) -> Data? {
        switch format {
        case .json:
            return generateJSONExport(terms: terms, includeAIAnalysis: includeAIAnalysis)
        case .csv:
            return generateCSVExport(terms: terms, includeAIAnalysis: includeAIAnalysis)
        }
    }

    /// Encoder/decoder used for the embedded AI payloads so dates round-trip
    /// consistently with the rest of the export.
    private static func aiEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func aiDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// All AI analyses cached for a term, across learning directions.
    private func explanations(for term: SavedTerm) -> [CachedWordExplanation] {
        WordExplanationCacheStore.shared.explanations(forWords: term.aiCacheCandidateWords)
    }

    private func generateJSONExport(terms: [SavedTerm], includeAIAnalysis: Bool) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard includeAIAnalysis else {
            // Legacy shape: a bare array of terms (back-compatible on import).
            return try? encoder.encode(terms)
        }

        let envelope = ExportEnvelope(
            terms: terms.map { ExportedTerm(term: $0, explanations: explanations(for: $0)) }
        )
        return try? encoder.encode(envelope)
    }

    private func generateCSVExport(terms: [SavedTerm], includeAIAnalysis: Bool) -> Data? {
        var csv = includeAIAnalysis
            ? "Chinese,Pinyin,Definition,Part of Speech,Date Added,Mastered,AI Definition,AI Examples,AI Data\n"
            : "Chinese,Pinyin,Definition,Part of Speech,Date Added,Mastered\n"

        for term in terms {
            let chinese = escapeCSV(term.chinese)
            let pinyin = escapeCSV(term.pinyin)
            let definition = escapeCSV(term.definition)
            let pos = escapeCSV(term.partOfSpeech)
            let date = ISO8601DateFormatter().string(from: term.dateAdded)
            let mastered = term.isMastered ? "true" : "false"
            var row = "\(chinese),\(pinyin),\(definition),\(pos),\(date),\(mastered)"

            if includeAIAnalysis {
                let analyses = explanations(for: term)
                // Human-readable columns from the first analysis, plus a lossless
                // base64 payload of all analyses for round-tripping on import.
                let first = analyses.first?.result
                let aiDef = escapeCSV(Self.singleLine(first?.definition ?? ""))
                let aiExamples = escapeCSV(Self.singleLine(
                    (first?.exampleSentences.prefix(2).map { $0.sentence }.joined(separator: " | ")) ?? ""
                ))
                let aiData: String
                if !analyses.isEmpty, let encoded = try? Self.aiEncoder().encode(analyses) {
                    aiData = encoded.base64EncodedString()
                } else {
                    aiData = ""
                }
                row += ",\(aiDef),\(aiExamples),\(escapeCSV(aiData))"
            }

            csv += row + "\n"
        }
        return csv.data(using: .utf8)
    }

    /// Collapse newlines/tabs to spaces so a value stays on one CSV line (the
    /// importer splits on newlines before parsing quotes).
    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
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
    func exportToFile(terms: [SavedTerm], format: VocabularyExportFormat, includeAIAnalysis: Bool = false) {
        guard let data = generateExportData(terms: terms, format: format, includeAIAnalysis: includeAIAnalysis) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: format.fileExtension)!]
        savePanel.nameFieldStringValue = "SwiftMandarin_Vocabulary.\(format.fileExtension)"
        // The panel chrome is app-supplied text, so it stays English unless it
        // is routed through the catalog (the file name is data, not UI).
        savePanel.title = String(localized: "Export Vocabulary", bundle: .appLanguage)
        savePanel.message = String(localized: "Choose where to save your vocabulary export", bundle: .appLanguage)
        
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

    /// Parse import data, detecting format automatically. Returns the terms plus
    /// any bundled AI analyses (empty for legacy files).
    func parseImportData(_ data: Data) -> ImportedVocabulary? {
        if let parsed = parseJSONImport(data) {
            return parsed
        }
        if let parsed = parseCSVImport(data) {
            return parsed
        }
        return nil
    }

    private func parseJSONImport(_ data: Data) -> ImportedVocabulary? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Prefer the v2 envelope (object with `terms`), which carries AI
        // analysis; fall back to the legacy bare `[SavedTerm]` array.
        if let envelope = try? decoder.decode(ExportEnvelope.self, from: data) {
            return ImportedVocabulary(
                terms: envelope.terms.map { $0.savedTerm },
                explanations: envelope.terms.flatMap { $0.aiExplanations ?? [] }
            )
        }
        if let terms = try? decoder.decode([SavedTerm].self, from: data) {
            return ImportedVocabulary(terms: terms, explanations: [])
        }
        return nil
    }

    private func parseCSVImport(_ data: Data) -> ImportedVocabulary? {
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        var terms: [SavedTerm] = []
        var explanations: [CachedWordExplanation] = []
        // Split into records respecting quoted fields, so a newline inside a
        // quoted value (e.g. a multi-line definition) does not break the record.
        let lines = Self.splitCSVRecords(content)

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

            let isMastered = columns.count > 5 ? parseBoolean(columns[5]) : false

            let term = SavedTerm(
                chinese: chinese,
                pinyin: pinyin,
                definition: definition,
                partOfSpeech: partOfSpeech,
                dateAdded: dateAdded,
                isMastered: isMastered
            )
            terms.append(term)

            // Optional "AI Data" column (index 8): base64 of a compact JSON
            // [CachedWordExplanation]. Columns 6/7 are human-readable only.
            if columns.count > 8 {
                let aiData = columns[8].trimmingCharacters(in: .whitespacesAndNewlines)
                if !aiData.isEmpty,
                   let decoded = Data(base64Encoded: aiData),
                   let parsed = try? Self.aiDecoder().decode([CachedWordExplanation].self, from: decoded) {
                    explanations.append(contentsOf: parsed)
                }
            }
        }

        return terms.isEmpty ? nil : ImportedVocabulary(terms: terms, explanations: explanations)
    }
    
    /// Split raw CSV text into records, treating newlines inside quoted fields
    /// as part of the field (RFC 4180). This is done before per-record column
    /// parsing so an exported value containing a newline (wrapped in quotes by
    /// `escapeCSV`) round-trips instead of being split across two records.
    static func splitCSVRecords(_ content: String) -> [String] {
        var records: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(content)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                // Keep an escaped quote ("") intact for the column parser.
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    current.append("\"")
                    i += 2
                    continue
                }
                inQuotes.toggle()
                current.append(c)
            } else if c.isNewline, !inQuotes {
                // Record boundary outside quotes. `isNewline` matches \n, \r,
                // and — crucially — the \r\n grapheme, which Swift treats as a
                // SINGLE Character (so a literal \r/\n comparison would miss it).
                records.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        if !current.isEmpty { records.append(current) }
        return records
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
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

    private func parseBoolean(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "true" || normalized == "1" || normalized == "yes" || normalized == "y"
    }
    
    /// Import parsed vocabulary with duplicate detection, and restore any
    /// bundled AI analyses into the explanation cache. Explanations are merged
    /// even for duplicate (skipped) terms, since they enrich words already saved.
    @discardableResult
    func importVocabulary(_ imported: ImportedVocabulary, into store: SavedTermsStore) -> ImportResult {
        var importedCount = 0
        var skipped = 0

        for term in imported.terms {
            // Check for duplicates based on Chinese text
            if store.contains(chinese: term.chinese) {
                skipped += 1
            } else {
                store.add(term)
                importedCount += 1
            }
        }

        var restored = 0
        if !imported.explanations.isEmpty {
            WordExplanationCacheStore.shared.merge(imported.explanations)
            restored = imported.explanations.count
        }

        return ImportResult(imported: importedCount, skipped: skipped, errors: [], explanationsRestored: restored)
    }

    /// Back-compatible wrapper: import bare terms with no AI analysis.
    @discardableResult
    func importTerms(_ newTerms: [SavedTerm], into store: SavedTermsStore) -> ImportResult {
        importVocabulary(ImportedVocabulary(terms: newTerms, explanations: []), into: store)
    }

    /// Import from a file URL (iOS/iPadOS/macOS). Handles security-scoped access when needed.
    func importFromFileURL(_ url: URL, into store: SavedTermsStore) -> ImportResult {
        var didAccessSecurityScope = false
        if url.startAccessingSecurityScopedResource() {
            didAccessSecurityScope = true
        }
        defer {
            if didAccessSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            if let parsed = parseImportData(data) {
                return importVocabulary(parsed, into: store)
            }
            return ImportResult(imported: 0, skipped: 0, errors: ["Could not parse file"])
        } catch {
            return ImportResult(imported: 0, skipped: 0, errors: [error.localizedDescription])
        }
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
        // Same reason as the export panel: this chrome is ours to localize.
        openPanel.title = String(localized: "Import Vocabulary", bundle: .appLanguage)
        openPanel.message = String(localized: "Select a vocabulary file to import", bundle: .appLanguage)
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    if let parsed = self.parseImportData(data) {
                        let result = self.importVocabulary(parsed, into: store)
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
