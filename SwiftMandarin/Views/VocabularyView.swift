//
//  VocabularyView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI

/// Saved vocabulary terms view with search, sorting, and export
struct VocabularyView: View {
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var showingExportSheet: Bool = false
    @State private var selectedTerm: SavedTerm?
    
    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case alphabetical = "Alphabetical"
        case pinyin = "Pinyin"
    }
    
    private var filteredTerms: [SavedTerm] {
        var terms = savedTermsStore.terms
        
        // Apply search filter
        if !searchText.isEmpty {
            terms = terms.filter { term in
                term.chinese.localizedCaseInsensitiveContains(searchText) ||
                term.pinyin.localizedCaseInsensitiveContains(searchText) ||
                term.definition.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sort
        switch sortOrder {
        case .dateAdded:
            return terms.sorted { $0.dateAdded > $1.dateAdded }
        case .alphabetical:
            return terms.sorted { $0.chinese < $1.chinese }
        case .pinyin:
            return terms.sorted { $0.pinyin < $1.pinyin }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if savedTermsStore.terms.isEmpty {
                    emptyState
                } else {
                    vocabularyList
                }
            }
            .navigationTitle("Vocabulary")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .searchable(text: $searchText, prompt: "Search vocabulary")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(savedTermsStore.terms.isEmpty)
                        
                        Button(role: .destructive) {
                            savedTermsStore.clear()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                        .disabled(savedTermsStore.terms.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedTerm) { term in
                TermDetailSheet(term: term)
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(terms: savedTermsStore.terms)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Saved Words", systemImage: "text.book.closed")
        } description: {
            Text("Words you save while translating will appear here")
        } actions: {
            Button {
                // Navigate to translate tab - would need tab binding
            } label: {
                Text("Start Translating")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Vocabulary List
    
    private var vocabularyList: some View {
        List {
            ForEach(filteredTerms) { term in
                VocabularyRow(term: term)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTerm = term
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            savedTermsStore.remove(term)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            SpeechService.speakChinese(term.chinese)
                        } label: {
                            Label("Speak", systemImage: "speaker.wave.2")
                        }
                        .tint(.blue)
                    }
            }
            .onMove { from, to in
                // Handle reordering
                guard let fromIndex = from.first else { return }
                savedTermsStore.move(from: fromIndex, to: to)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
}

// MARK: - Vocabulary Row

struct VocabularyRow: View {
    let term: SavedTerm
    
    var body: some View {
        HStack(spacing: 12) {
            // Chinese character
            Text(term.chinese)
                .font(.title2)
                .fontWeight(.medium)
                .frame(minWidth: 60, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                // Pinyin with tone colors
                Text(PinyinConverter.coloredPinyin(term.chinese))
                    .font(.subheadline)
                
                // Definition
                Text(term.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Part of speech badge
            if !term.partOfSpeech.isEmpty {
                Text(term.partOfSpeech)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(.quaternary)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Term Detail Sheet

struct TermDetailSheet: View {
    let term: SavedTerm
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large character display
                    VStack(spacing: 12) {
                        Text(term.chinese)
                            .font(.system(size: 80, weight: .medium))
                        
                        Text(PinyinConverter.coloredPinyin(term.chinese))
                            .font(.title)
                        
                        if !term.partOfSpeech.isEmpty {
                            Text(term.partOfSpeech)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.blue))
                        }
                    }
                    .padding(.top, 20)
                    
                    Divider()
                    
                    // Definition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Definition")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Text(term.definition)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    HStack(spacing: 24) {
                        Button {
                            SpeechService.speakChinese(term.chinese)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.title2)
                                Text("Speak")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            ClipboardService.copy(term.chinese)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.title2)
                                Text("Copy")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            ClipboardService.copy("\(term.chinese)\n\(term.pinyin)\n\(term.definition)")
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.title2)
                                Text("Copy All")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Added \(term.dateAdded.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Word Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    let terms: [SavedTerm]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .csv
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case json = "JSON"
        case text = "Plain Text"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Preview") {
                    Text(generateExport().prefix(500))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Button {
                        ClipboardService.copy(generateExport())
                        dismiss()
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }
                    
                    ShareLink(item: generateExport()) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Export Vocabulary")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func generateExport() -> String {
        switch exportFormat {
        case .csv:
            var csv = "Chinese,Pinyin,Definition,Part of Speech,Date Added\n"
            for term in terms {
                csv += "\"\(term.chinese)\",\"\(term.pinyin)\",\"\(term.definition)\",\"\(term.partOfSpeech)\",\"\(term.dateAdded.ISO8601Format())\"\n"
            }
            return csv
            
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(terms),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return "[]"
            
        case .text:
            return terms.map { "\($0.chinese) (\($0.pinyin)) - \($0.definition)" }.joined(separator: "\n")
        }
    }
}

// MARK: - Preview

#Preview {
    VocabularyView()
        .environment(SavedTermsStore.shared)
}
