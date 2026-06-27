//
//  VocabularyView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Saved vocabulary terms view with search, sorting, and export
struct VocabularyView: View {
    @Environment(AppRouteStore.self) private var routeStore
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var sortAscending: Bool = false  // false = newest first (default), true = oldest first
    @State private var showingExportSheet: Bool = false
    @State private var showingImportResult: Bool = false
    @State private var importResult: ImportResult?
    @State private var selectedTerm: SavedTerm?
    @FocusState private var isVocabularyFocused: Bool
    @State private var showingImportPicker: Bool = false
    @State private var importFileURL: URL?
    @State private var importFileErrorMessage: String?
    
    /// Term selected for AI explanation
    @State private var aiExplanationTerm: SavedTerm?

    /// Font size for Chinese characters in the vocabulary list (persisted).
    /// Also driven by the "Text Size" slider in Settings.
    @AppStorage("vocabularyChineseFontSize") private var chineseFontSize: Double = 20
    @AppStorage("vocabularyDetailUsesInspector") private var vocabularyDetailUsesInspector: Bool = true
    
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
        
        // Apply sort with direction (alphabetical sorts the visible headword,
        // which is the learning-language side)
        switch sortOrder {
        case .dateAdded:
            return terms.sorted { sortAscending ? $0.dateAdded < $1.dateAdded : $0.dateAdded > $1.dateAdded }
        case .alphabetical:
            return terms.sorted { sortAscending ? $0.headlineText < $1.headlineText : $0.headlineText > $1.headlineText }
        case .pinyin:
            return terms.sorted { sortAscending ? $0.pinyin < $1.pinyin : $0.pinyin > $1.pinyin }
        }
    }

    private func syncSelectedTerm() {
        guard let currentID = selectedTerm?.id else { return }
        selectedTerm = savedTermsStore.term(withID: currentID)
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
            .onChange(of: savedTermsStore.terms) { _, _ in
                syncSelectedTerm()
            }
            #if os(macOS)
            .inspector(isPresented: .constant(vocabularyDetailUsesInspector && selectedTerm != nil)) {
                if vocabularyDetailUsesInspector, let term = selectedTerm {
                    TermDetailInspector(
                        term: term,
                        selectedTerm: $selectedTerm,
                        savedTermsStore: savedTermsStore
                    )
                    .id(term.id)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                }
            }
            #endif
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    // Font size controls
                    Button {
                        if chineseFontSize > 14 {
                            chineseFontSize -= 2
                        }
                    } label: {
                        Label("Decrease Font Size", systemImage: "textformat.size.smaller")
                    }
                    .disabled(chineseFontSize <= 14)
                    .help("Decrease headword font size (⌘-)")
                    .keyboardShortcut("-", modifiers: .command)
                    
                    Button {
                        if chineseFontSize < 48 {
                            chineseFontSize += 2
                        }
                    } label: {
                        Label("Increase Font Size", systemImage: "textformat.size.larger")
                    }
                    .disabled(chineseFontSize >= 48)
                    .help("Increase headword font size (⌘+)")
                    .keyboardShortcut("=", modifiers: .command)
                    
                    Divider()
                    
                    Button {
                        VocabularyImportExportService.shared.importFromFile(into: savedTermsStore) { result in
                            if let result = result {
                                importResult = result
                                showingImportResult = true
                            }
                        }
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .help("Import vocabulary from file")
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(savedTermsStore.terms.isEmpty)
                    .help("Export vocabulary to file")
                    
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        
                        Divider()
                        
                        // Sort direction toggle
                        Button {
                            sortAscending.toggle()
                        } label: {
                            Label(
                                sortAscending ? "Oldest First" : "Newest First",
                                systemImage: sortAscending ? "arrow.up" : "arrow.down"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            savedTermsStore.clear()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                        .disabled(savedTermsStore.terms.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .help("More options")
                }
                #else
                ToolbarItemGroup(placement: .primaryAction) {
                    // Font size controls for iOS
                    Button {
                        if chineseFontSize > 14 {
                            chineseFontSize -= 2
                        }
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                    }
                    .disabled(chineseFontSize <= 14)
                    
                    Button {
                        if chineseFontSize < 48 {
                            chineseFontSize += 2
                        }
                    } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                    .disabled(chineseFontSize >= 48)
                    
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }

                        Divider()

                        // Sort direction toggle
                        Button {
                            sortAscending.toggle()
                        } label: {
                            Label(
                                sortAscending ? "Oldest First" : "Newest First",
                                systemImage: sortAscending ? "arrow.up" : "arrow.down"
                            )
                        }

                        Divider()

                        Button {
                            showingImportPicker = true
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }

                        Divider()

                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .disabled(savedTermsStore.terms.isEmpty)
                        
                        Divider()
                        
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
                #endif
            }
            #if os(iOS)
            .sheet(item: $selectedTerm) { _ in
                TermDetailSheet(selectedTerm: $selectedTerm)
                    .localizedSurface()
            }
            #endif
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(terms: savedTermsStore.terms)
                    .localizedSurface()
            }
            .sheet(item: $aiExplanationTerm) { term in
                AIExplanationSheet(term: term)
                    .localizedSurface()
            }
            #if os(iOS)
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType.json, UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    importFileURL = urls.first
                case .failure(let error):
                    importFileErrorMessage = error.localizedDescription
                }
            }
            .onChange(of: importFileURL) { _, newValue in
                guard let url = newValue else { return }
                let result = VocabularyImportExportService.shared.importFromFileURL(url, into: savedTermsStore)
                importResult = result
                showingImportResult = true
                importFileURL = nil
            }
            .onChange(of: importFileErrorMessage) { _, newValue in
                guard let message = newValue else { return }
                importResult = ImportResult(imported: 0, skipped: 0, errors: [message])
                showingImportResult = true
                importFileErrorMessage = nil
            }
            #endif
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importResult?.summary ?? "Import completed")
            }
            #if os(macOS)
            .focusable()
            .focusEffectDisabled()
            .focused($isVocabularyFocused)
            .onAppear {
                isVocabularyFocused = true
            }
            .onKeyPress(keys: [.downArrow, .rightArrow]) { _ in
                guard isVocabularyFocused else { return .ignored }
                selectNextTerm()
                return .handled
            }
            .onKeyPress(keys: [.upArrow, .leftArrow]) { _ in
                guard isVocabularyFocused else { return .ignored }
                selectPreviousTerm()
                return .handled
            }
            .onKeyPress(.space) {
                guard isVocabularyFocused else { return .ignored }
                toggleSelectedMastered()
                return .handled
            }
            .onKeyPress(.return) {
                guard isVocabularyFocused else { return .ignored }
                toggleSelectedMastered()
                return .handled
            }
            #endif
        }
    }
    
    // MARK: - Keyboard Navigation
    
    #if os(macOS)
    private func selectNextTerm() {
        let terms = filteredTerms
        guard !terms.isEmpty else { return }
        
        if let current = selectedTerm,
           let currentIndex = terms.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = min(currentIndex + 1, terms.count - 1)
            selectedTerm = terms[nextIndex]
        } else {
            // No selection, select first
            selectedTerm = terms.first
        }
    }
    
    private func selectPreviousTerm() {
        let terms = filteredTerms
        guard !terms.isEmpty else { return }
        
        if let current = selectedTerm,
           let currentIndex = terms.firstIndex(where: { $0.id == current.id }) {
            let prevIndex = max(currentIndex - 1, 0)
            selectedTerm = terms[prevIndex]
        } else {
            // No selection, select last
            selectedTerm = terms.last
        }
    }
    
    private func toggleSelectedMastered() {
        guard let term = selectedTerm else { return }
        savedTermsStore.toggleMastered(term)
    }
    #endif
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Saved Words", systemImage: "text.book.closed")
        } description: {
            Text("Words you save while translating will appear here")
        } actions: {
            Button {
                routeStore.selectedTab = .translate
            } label: {
                Text("Start Translating")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Vocabulary List
    
    @ViewBuilder
    private var vocabularyList: some View {
        let list = List {
            ForEach(filteredTerms) { term in
                VocabularyRow(
                    term: term,
                    chineseFontSize: chineseFontSize,
                    isSelected: selectedTerm?.id == term.id,
                    onMasteredToggle: {
                        savedTermsStore.toggleMastered(term)
                    },
                    onAIExplainTap: {
                        aiExplanationTerm = term
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTerm = term
                    #if os(macOS)
                    isVocabularyFocused = true
                    #endif
                }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            savedTermsStore.remove(term)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            savedTermsStore.toggleMastered(term)
                        } label: {
                            Label(
                                term.isMastered ? "Unmaster" : "Mastered",
                                systemImage: term.isMastered ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        .tint(term.isMastered ? .orange : .green)
                        
                        Button {
                            SpeechService.speakAuto(term.headlineText)
                        } label: {
                            Label("Speak", systemImage: "speaker.wave.2")
                        }
                        .tint(.blue)
                    }
            }
        }
        #if os(iOS)
        list
            .listStyle(.insetGrouped)
        #else
        if vocabularyDetailUsesInspector {
            list
                .focusable()
                .focused($isVocabularyFocused)
        } else {
            list
                .focusable()
                .focused($isVocabularyFocused)
                .popover(item: $selectedTerm) { term in
                    TermDetailInspector(
                        term: term,
                        selectedTerm: $selectedTerm,
                        savedTermsStore: savedTermsStore
                    )
                    .localizedSurface()
                    .id(term.id)
                    .frame(minWidth: 320, minHeight: 420)
                }
        }
        #endif
    }
}

// MARK: - Vocabulary Row

struct VocabularyRow: View {
    let term: SavedTerm
    var chineseFontSize: Double = 20
    var isSelected: Bool = false
    var onMasteredToggle: (() -> Void)?
    var onAIExplainTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            // Clickable mastered checkbox
            Button {
                onMasteredToggle?()
            } label: {
                Image(systemName: term.isMastered ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(term.isMastered ? .green : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            // Headword — the side in the language being learned — with the
            // adjustable font size (中文 UI: the English word; English UI:
            // the Chinese characters).
            Text(term.headlineText)
                .font(.system(size: chineseFontSize, weight: .medium))
                .frame(minWidth: max(60, chineseFontSize * 2.5), alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                // Pinyin with tone colors — a learner aid, shown only when
                // the user is learning Chinese.
                if term.showsPinyin {
                    // Scale the pinyin with the headword so enlarging the
                    // character also enlarges the pinyin and its tone marks
                    // (previously a fixed size, which stayed hard to read).
                    Text(PinyinConverter.coloredPinyin(preferred: term.pinyin, fallbackText: term.chineseSide))
                        .font(.system(size: chineseFontSize * 0.7))
                }

                // Native-language gloss, kept small.
                if !term.glossText.isEmpty {
                    Text(term.glossText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // AI Explain button
            if let onAIExplainTap = onAIExplainTap {
                AIExplainButton(
                    word: term.headlineText,
                    pinyin: term.pinyin,
                    onTap: onAIExplainTap
                )
            }
            
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
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Term Detail Sheet

/// Tiny −/+ control for adjusting the detail view's headword + pinyin size.
/// Shared by the sheet and inspector presentations; persists via AppStorage.
struct DetailFontSizeStepper: View {
    @Binding var size: Double
    var range: ClosedRange<Double> = 56...144
    var step: Double = 8

    var body: some View {
        HStack(spacing: 6) {
            Button {
                size = max(range.lowerBound, size - step)
            } label: {
                Image(systemName: "minus")
            }
            .disabled(size <= range.lowerBound)
            .accessibilityLabel(Text("Decrease character size"))

            Button {
                size = min(range.upperBound, size + step)
            } label: {
                Image(systemName: "plus")
            }
            .disabled(size >= range.upperBound)
            .accessibilityLabel(Text("Increase character size"))
        }
        .font(.caption2)
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .labelStyle(.iconOnly)
    }
}

struct TermDetailSheet: View {
    @Binding var selectedTerm: SavedTerm?
    @Environment(\.dismiss) private var dismiss
    @Environment(SavedTermsStore.self) private var savedTermsStore

    @State private var fetchedTranslation: String = ""
    @State private var isLoadingTranslation: Bool = false
    @State private var showCopiedFeedback: Bool = false
    /// Persisted size of the Chinese headword in the detail view; the −/+
    /// buttons adjust it and the pinyin scales with it.
    @AppStorage("vocabularyDetailChineseFontSize") private var detailFontSize: Double = 96
    
    /// The current term being displayed
    private var term: SavedTerm {
        selectedTerm ?? SavedTerm(chinese: "", pinyin: "", definition: "")
    }

    /// The gloss to display — the native-language side of the entry, or a
    /// freshly fetched translation when the stored one is missing/unwieldy.
    private var displayDefinition: String {
        if !fetchedTranslation.isEmpty {
            return fetchedTranslation
        }
        return term.glossText
    }

    /// Check if we should offer to fetch a better translation
    private var shouldOfferTranslation: Bool {
        term.glossText.isEmpty || term.glossText.count > 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Large headword display — the language being learned.
                    // English headwords can be long, so allow shrinking.
                    VStack(spacing: 12) {
                        Text(term.headlineText)
                            .font(.system(size: detailFontSize, weight: .medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.35)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if term.showsPinyin {
                            Text(PinyinConverter.coloredPinyin(preferred: term.pinyin, fallbackText: term.chineseSide))
                                .font(.system(size: detailFontSize * 0.4))
                        }

                        DetailFontSizeStepper(size: $detailFontSize)
                            .padding(.top, 2)

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
                    
                    // Definition section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Definition")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Spacer()
                            
                            if isLoadingTranslation {
                                ProgressView()
                                    .controlSize(.small)
                            } else if shouldOfferTranslation && fetchedTranslation.isEmpty {
                                Button {
                                    Task { await fetchTranslation() }
                                } label: {
                                    Label("Translate", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        if displayDefinition.isEmpty {
                            Text("No definition available")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(displayDefinition)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Show original if we fetched a new one
                        if !fetchedTranslation.isEmpty && !term.definition.isEmpty && fetchedTranslation != term.definition {
                            Divider()
                            
                            Text("Original Context")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(term.definition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Actions
                    HStack(spacing: 24) {
                        Button {
                            SpeechService.speakAuto(term.headlineText)
                            triggerHaptic()
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
                            ClipboardService.copy(term.headlineText)
                            showCopiedFeedback = true
                            triggerHaptic()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedFeedback = false
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                    .font(.title2)
                                Text(showCopiedFeedback ? "Copied!" : "Copy")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(showCopiedFeedback ? .green : nil)

                        Button {
                            let parts = [
                                term.headlineText,
                                term.showsPinyin ? term.pinyin : "",
                                displayDefinition
                            ].filter { !$0.isEmpty }
                            let text = parts.joined(separator: "\n")
                            ClipboardService.copy(text)
                            showCopiedFeedback = true
                            triggerHaptic()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedFeedback = false
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.title2)
                                Text("Copy All")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            savedTermsStore.toggleMastered(term)
                            selectedTerm = savedTermsStore.term(withID: term.id)
                            triggerHaptic()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: term.isMastered ? "checkmark.circle.fill" : "checkmark.circle")
                                    .font(.title2)
                                Text(term.isMastered ? "Mastered" : "Master")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(term.isMastered ? .green : nil)
                    }
                    
                    // Update definition button if we have a better translation
                    if !fetchedTranslation.isEmpty && fetchedTranslation != term.definition {
                        Button {
                            updateTermDefinition()
                        } label: {
                            Label("Update Saved Definition", systemImage: "arrow.down.doc")
                                .fitSingleLine()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Added \(term.dateAdded.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // AI Word Explanation Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI Word Analysis")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                        
                        AIWordExplanationView(
                            word: term.headlineText,
                            pinyin: term.pinyin,
                            context: term.glossText.isEmpty ? nil : term.glossText
                        )
                    }

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
            .task(id: selectedTerm?.id) {
                // Reset state when term changes
                fetchedTranslation = ""
                isLoadingTranslation = false
                showCopiedFeedback = false

                // Auto-fetch a translation when the native-language gloss is missing
                if term.glossText.isEmpty {
                    await fetchTranslation()
                }
            }
        }
    }

    /// Translate the headword into the user's native language (the headword's
    /// own language decides the direction, since it can be either).
    private func fetchTranslation() async {
        isLoadingTranslation = true

        do {
            let headword = term.headlineText
            let translation = try await WordTranslationService.shared
                .translate(headword, sourceIsChinese: headword.containsCJK)
            await MainActor.run {
                fetchedTranslation = translation
                isLoadingTranslation = false
            }
        } catch {
            await MainActor.run {
                isLoadingTranslation = false
            }
            print("Failed to fetch translation: \(error)")
        }
    }
    
    private func updateTermDefinition() {
        // Create updated term with new definition
        let updatedTerm = SavedTerm(
            id: term.id,
            chinese: term.chinese,
            pinyin: term.pinyin,
            definition: fetchedTranslation,
            partOfSpeech: term.partOfSpeech,
            dateAdded: term.dateAdded,
            isMastered: term.isMastered
        )
        
        // The term may have been deleted while this sheet was open; in that
        // case don't pretend the edit succeeded.
        guard savedTermsStore.update(updatedTerm) else { return }
        selectedTerm = savedTermsStore.term(withID: term.id)
        triggerHaptic()
    }

    private func triggerHaptic() {
        #if os(iOS)
        let hapticEnabled = UserDefaults.standard.bool(forKey: "hapticFeedback")
        if hapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        #endif
    }
}

// MARK: - Term Detail Inspector (macOS)

#if os(macOS)
struct TermDetailInspector: View {
    let term: SavedTerm
    @Binding var selectedTerm: SavedTerm?
    var savedTermsStore: SavedTermsStore

    @State private var fetchedTranslation: String = ""
    @State private var isLoadingTranslation: Bool = false
    @State private var showCopiedFeedback: Bool = false
    /// Persisted size of the Chinese headword in the detail view; shared with
    /// the sheet presentation so the −/+ buttons behave identically.
    @AppStorage("vocabularyDetailChineseFontSize") private var detailFontSize: Double = 96
    
    private var displayDefinition: String {
        if !fetchedTranslation.isEmpty {
            return fetchedTranslation
        }
        return term.glossText
    }

    private var shouldOfferTranslation: Bool {
        term.glossText.isEmpty || term.glossText.count > 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        selectedTerm = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Large headword display — the language being learned.
                VStack(spacing: 10) {
                    Text(term.headlineText)
                        .font(.system(size: detailFontSize, weight: .medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.35)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if term.showsPinyin {
                        Text(PinyinConverter.coloredPinyin(preferred: term.pinyin, fallbackText: term.chineseSide))
                            .font(.system(size: detailFontSize * 0.4))
                    }

                    DetailFontSizeStepper(size: $detailFontSize)
                        .padding(.top, 2)

                    if !term.partOfSpeech.isEmpty {
                        Text(term.partOfSpeech)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.blue))
                    }
                }
                
                Divider()
                
                // Mastered toggle
                Button {
                    savedTermsStore.toggleMastered(term)
                    selectedTerm = savedTermsStore.term(withID: term.id)
                } label: {
                    HStack {
                        Image(systemName: term.isMastered ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(term.isMastered ? .green : .secondary)
                        Text(term.isMastered ? "Mastered" : "Mark as Mastered")
                            .foregroundStyle(term.isMastered ? .green : .primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                
                Divider()
                
                // Definition section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Definition")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                        
                        if isLoadingTranslation {
                            ProgressView()
                                .controlSize(.small)
                        } else if shouldOfferTranslation && fetchedTranslation.isEmpty {
                            Button {
                                Task { await fetchTranslation() }
                            } label: {
                                Label("Translate", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    if displayDefinition.isEmpty {
                        Text("No definition available")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text(displayDefinition)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Actions
                HStack(spacing: 16) {
                    Button {
                        SpeechService.speakAuto(term.headlineText)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "speaker.wave.2")
                                .font(.title3)
                            Text("Speak")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button {
                        ClipboardService.copy(term.headlineText)
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedFeedback = false
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.title3)
                            Text(showCopiedFeedback ? "Copied!" : "Copy")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(showCopiedFeedback ? .green : nil)

                    Button {
                        let parts = [
                            term.headlineText,
                            term.showsPinyin ? term.pinyin : "",
                            displayDefinition
                        ].filter { !$0.isEmpty }
                        let text = parts.joined(separator: "\n")
                        ClipboardService.copy(text)
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedFeedback = false
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.title3)
                            Text("Copy All")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                // Update definition button
                if !fetchedTranslation.isEmpty && fetchedTranslation != term.definition {
                    Button {
                        updateTermDefinition()
                    } label: {
                        Label("Update Saved Definition", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                
                // Metadata
                Text("Added \(term.dateAdded.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 8)
                
                // AI Word Explanation Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Word Analysis")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                    
                    AIWordExplanationView(
                        word: term.headlineText,
                        pinyin: term.pinyin,
                        context: term.glossText.isEmpty ? nil : term.glossText
                    )
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .task(id: term.id) {
            // Reset state when term changes
            fetchedTranslation = ""
            isLoadingTranslation = false
            showCopiedFeedback = false

            if term.glossText.isEmpty {
                await fetchTranslation()
            }
        }
    }

    /// Translate the headword into the user's native language (the headword's
    /// own language decides the direction, since it can be either).
    private func fetchTranslation() async {
        isLoadingTranslation = true

        do {
            let headword = term.headlineText
            let translation = try await WordTranslationService.shared
                .translate(headword, sourceIsChinese: headword.containsCJK)
            await MainActor.run {
                fetchedTranslation = translation
                isLoadingTranslation = false
            }
        } catch {
            await MainActor.run {
                isLoadingTranslation = false
            }
            print("Failed to fetch translation: \(error)")
        }
    }
    
    private func updateTermDefinition() {
        let updatedTerm = SavedTerm(
            id: term.id,
            chinese: term.chinese,
            pinyin: term.pinyin,
            definition: fetchedTranslation,
            partOfSpeech: term.partOfSpeech,
            dateAdded: term.dateAdded,
            isMastered: term.isMastered
        )
        
        // The term may have been deleted while the inspector was open; in
        // that case don't pretend the edit succeeded.
        guard savedTermsStore.update(updatedTerm) else { return }
        selectedTerm = savedTermsStore.term(withID: term.id)
    }
}
#endif

// MARK: - Export Sheet

struct ExportSheet: View {
    let terms: [SavedTerm]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: VocabularyExportFormat = .json
    @State private var includeAIAnalysis: Bool = true
    @State private var showExportSuccess: Bool = false
    @State private var exportSuccessMessage: String = String(localized: "Exported Successfully")

    /// How many of the exported words have a saved AI analysis to bundle.
    private var aiAnalysisCount: Int {
        let cache = WordExplanationCacheStore.shared
        return terms.filter { cache.hasAnyExplanation(forWords: $0.aiCacheCandidateWords) }.count
    }

    private var exportPreview: String {
        guard let data = VocabularyImportExportService.shared.generateExportData(terms: terms, format: exportFormat, includeAIAnalysis: includeAIAnalysis),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }
        if content.count > 400 {
            return String(content.prefix(400)) + "..."
        }
        return content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with word count and icon
            HStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Vocabulary")
                        .font(.headline)
                    Text("\(terms.count) word\(terms.count == 1 ? "" : "s") ready to export")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            
            Divider()
            
            // Content
            Form {
                // Format Selection with visual cards
                Section {
                    HStack(spacing: 12) {
                        ForEach(VocabularyExportFormat.allCases) { format in
                            FormatCard(
                                format: format,
                                isSelected: exportFormat == format
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    exportFormat = format
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Format")
                }

                // AI analysis bundling
                Section {
                    Toggle("Include AI Analysis", isOn: $includeAIAnalysis)
                } footer: {
                    if aiAnalysisCount > 0 {
                        Text("Bundles saved AI analyses (\(aiAnalysisCount) of \(terms.count)) so they restore on import.")
                    } else {
                        Text("No saved AI analyses yet. Run Batch AI Analysis or open a word's analysis first.")
                    }
                }

                // Preview Section
                Section {
                    ScrollView {
                        Text(exportPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 120)
                } header: {
                    HStack {
                        Text("Preview")
                        Spacer()
                        Text(".\(exportFormat.fileExtension)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.blue))
                    }
                }
                
                // Export Actions
                Section {
                    #if os(macOS)
                    ExportActionRow(
                        icon: "folder.badge.plus",
                        iconColor: .blue,
                        title: "Save to File...",
                        subtitle: "Choose location and filename"
                    ) {
                        VocabularyImportExportService.shared.exportToFile(terms: terms, format: exportFormat, includeAIAnalysis: includeAIAnalysis)
                        exportSuccessMessage = String(localized: "Saved to File")
                        showExportSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                    #endif
                    
                    ExportActionRow(
                        icon: "doc.on.doc",
                        iconColor: .orange,
                        title: "Copy to Clipboard",
                        subtitle: "Paste anywhere you need"
                    ) {
                        if let data = VocabularyImportExportService.shared.generateExportData(terms: terms, format: exportFormat, includeAIAnalysis: includeAIAnalysis),
                           let content = String(data: data, encoding: .utf8) {
                            ClipboardService.copy(content)
                        }
                        exportSuccessMessage = String(localized: "Copied to Clipboard")
                        showExportSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                    
                    if let data = VocabularyImportExportService.shared.generateExportData(terms: terms, format: exportFormat, includeAIAnalysis: includeAIAnalysis),
                       let content = String(data: data, encoding: .utf8) {
                        ShareLink(item: content) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Share")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("Send via Messages, Mail, AirDrop...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Export To")
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 420, idealWidth: 480, minHeight: 480, idealHeight: 520)
        .overlay {
            if showExportSuccess {
                exportSuccessOverlay
            }
        }
    }
    
    private var exportSuccessOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            Text(exportSuccessMessage)
                .font(.headline)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Format Card

private struct FormatCard: View {
    let format: VocabularyExportFormat
    let isSelected: Bool
    let action: () -> Void
    
    private var formatDescription: String {
        switch format {
        case .json:
            return "Best for backup"
        case .csv:
            return "For spreadsheets"
        }
    }
    
    private var formatIcon: String {
        switch format {
        case .json:
            return "doc.text"
        case .csv:
            return "tablecells"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: formatIcon)
                    .font(.title)
                    .foregroundStyle(isSelected ? .white : .blue)
                
                Text(format.rawValue)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(LocalizedStringKey(formatDescription))
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AnyShapeStyle(.blue) : AnyShapeStyle(.quaternary.opacity(0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? AnyShapeStyle(.clear) : AnyShapeStyle(.quaternary), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Action Row

private struct ExportActionRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AI Explanation Sheet

struct AIExplanationSheet: View {
    let term: SavedTerm
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // macOS toolbar header
            HStack {
                Text("AI Word Analysis")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.bar)
            
            Divider()
            
            AIWordExplanationView(
                word: term.headlineText,
                pinyin: term.pinyin,
                context: term.glossText.isEmpty ? nil : term.glossText
            )
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 550, idealHeight: 650)
        #else
        NavigationStack {
            AIWordExplanationView(
                word: term.headlineText,
                pinyin: term.pinyin,
                context: term.glossText.isEmpty ? nil : term.glossText
            )
            .navigationTitle("AI Word Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    VocabularyView()
        .environment(SavedTermsStore.shared)
        .environment(AppRouteStore.shared)
}
