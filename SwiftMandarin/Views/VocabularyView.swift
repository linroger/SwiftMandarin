//
//  VocabularyView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

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
    /// Stable presentation identity for the iOS detail session. The selected
    /// word changes while paging, so using `selectedTerm` itself as the sheet
    /// item can make SwiftUI replace the presentation on every page.
    @State private var detailSession: VocabularyDetailSession?
    @FocusState private var isVocabularyFocused: Bool
    @State private var showingImportPicker: Bool = false
    @State private var importFileURL: URL?
    @State private var importFileErrorMessage: String?
    
    /// Term selected for AI explanation
    @State private var aiExplanationTerm: SavedTerm?

    /// Font size for the headword in the vocabulary list (persisted). The
    /// headword is whichever language the user is studying, so this sizes the
    /// Chinese word for an English speaker and the English word for a Mandarin
    /// speaker. The storage key keeps its original name so existing
    /// preferences survive; also driven by the "Text Size" slider in Settings.
    @AppStorage("vocabularyChineseFontSize") private var headwordFontSize: Double = 20
    @AppStorage("vocabularyDetailUsesInspector") private var vocabularyDetailUsesInspector: Bool = true
    
    enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case alphabetical = "Alphabetical"
        case pinyin = "Pinyin"

        var title: LocalizedStringKey {
            switch self {
            case .dateAdded: "Date Added"
            case .alphabetical: "Alphabetical"
            case .pinyin: "Pinyin"
            }
        }

        /// Sorting by pinyin orders Chinese headwords by their reading — the
        /// Mandarin equivalent of alphabetical order. For a Mandarin speaker
        /// studying English the headwords are already alphabetical, so the
        /// option is redundant and is left out of the menu.
        @MainActor
        static var available: [SortOrder] {
            LearningContext.current.showsPinyinAffordances
                ? allCases
                : allCases.filter { $0 != .pinyin }
        }
    }

    /// The effective sort, ignoring a stored `.pinyin` choice that the current
    /// direction no longer offers so the list never sorts by an invisible key.
    private var effectiveSortOrder: SortOrder {
        SortOrder.available.contains(sortOrder) ? sortOrder : .dateAdded
    }

    private var filteredTerms: [SavedTerm] {
        var terms = savedTermsStore.terms

        // Apply search filter. Both sides and the reading are searchable, so a
        // learner can find an entry by whichever half they remember.
        if !searchText.isEmpty {
            terms = terms.filter { term in
                term.chinese.localizedCaseInsensitiveContains(searchText) ||
                term.pinyin.localizedCaseInsensitiveContains(searchText) ||
                term.definition.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sort with direction (alphabetical sorts the visible headword,
        // which is the learning-language side)
        switch effectiveSortOrder {
        case .dateAdded:
            return terms.sorted { lhs, rhs in
                if lhs.dateAdded == rhs.dateAdded {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return sortAscending ? lhs.dateAdded < rhs.dateAdded : lhs.dateAdded > rhs.dateAdded
            }
        case .alphabetical:
            return terms.sorted { lhs, rhs in
                let comparison = lhs.headlineText.localizedStandardCompare(rhs.headlineText)
                if comparison == .orderedSame {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
            }
        case .pinyin:
            return terms.sorted { lhs, rhs in
                let comparison = lhs.pinyin.localizedStandardCompare(rhs.pinyin)
                if comparison == .orderedSame {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
            }
        }
    }

    private var sortDirectionTitle: LocalizedStringKey {
        switch effectiveSortOrder {
        case .dateAdded:
            sortAscending ? "Oldest First" : "Newest First"
        case .alphabetical, .pinyin:
            sortAscending ? "A to Z" : "Z to A"
        }
    }

    private var sortDirectionSymbol: String {
        sortAscending ? "arrow.up" : "arrow.down"
    }

    private func syncSelectedTerm() {
        guard let currentID = selectedTerm?.id else { return }
        selectedTerm = savedTermsStore.term(withID: currentID)
        if selectedTerm == nil {
            detailSession = nil
        }
    }

    private func openDetail(for term: SavedTerm) {
        selectedTerm = term
        #if os(iOS)
        detailSession = VocabularyDetailSession(
            initialTermID: term.id,
            orderedTermIDs: filteredTerms.map(\.id)
        )
        #else
        isVocabularyFocused = true
        #endif
    }

    #if os(macOS)
    private var isInspectorPresented: Binding<Bool> {
        Binding(
            get: { vocabularyDetailUsesInspector && selectedTerm != nil },
            set: { isPresented in
                if !isPresented {
                    selectedTerm = nil
                }
            }
        )
    }
    #endif
    
    // NOTE: No own NavigationStack here. This screen is always presented inside
    // an ambient navigation container — pushed into the Study hub's
    // NavigationStack on iOS, or shown in the NavigationSplitView detail column
    // on macOS. Wrapping it in its own NavigationStack created a *nested* stack
    // on iOS, and a nested `.searchable` there fails to lay out — which is why
    // the vocabulary screen appeared unopenable when reached from the Study tab.
    var body: some View {
            Group {
                if savedTermsStore.terms.isEmpty {
                    emptyState
                } else if filteredTerms.isEmpty {
                    noSearchResultsState
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
            .inspector(isPresented: isInspectorPresented) {
                if vocabularyDetailUsesInspector, let term = selectedTerm {
                    TermDetailInspector(
                        term: term,
                        selectedTerm: $selectedTerm,
                        savedTermsStore: savedTermsStore,
                        orderedTerms: filteredTerms
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
                        if headwordFontSize > 14 {
                            headwordFontSize -= 2
                        }
                    } label: {
                        Label("Decrease Font Size", systemImage: "textformat.size.smaller")
                    }
                    .disabled(headwordFontSize <= 14)
                    .help("Decrease headword font size (⌘-)")
                    .keyboardShortcut("-", modifiers: .command)
                    
                    Button {
                        if headwordFontSize < 48 {
                            headwordFontSize += 2
                        }
                    } label: {
                        Label("Increase Font Size", systemImage: "textformat.size.larger")
                    }
                    .disabled(headwordFontSize >= 48)
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
                            ForEach(SortOrder.available, id: \.self) { order in
                                Text(order.title).tag(order)
                            }
                        }
                        
                        Divider()
                        
                        // Sort direction toggle
                        Button {
                            sortAscending.toggle()
                        } label: {
                            Label(sortDirectionTitle, systemImage: sortDirectionSymbol)
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
                    // Keep the compact iPhone toolbar focused. Less-frequent
                    // text-size and data actions live in the system menu, which
                    // adopts the current Liquid Glass treatment automatically.
                    Menu {
                        Picker("Sort by", selection: $sortOrder) {
                            ForEach(SortOrder.available, id: \.self) { order in
                                Text(order.title).tag(order)
                            }
                        }

                        Divider()

                        // Sort direction toggle
                        Button {
                            sortAscending.toggle()
                        } label: {
                            Label(sortDirectionTitle, systemImage: sortDirectionSymbol)
                        }

                        Divider()

                        Button {
                            headwordFontSize = max(14, headwordFontSize - 2)
                        } label: {
                            Label("Decrease Headword Size", systemImage: "textformat.size.smaller")
                        }
                        .disabled(headwordFontSize <= 14)

                        Button {
                            headwordFontSize = min(48, headwordFontSize + 2)
                        } label: {
                            Label("Increase Headword Size", systemImage: "textformat.size.larger")
                        }
                        .disabled(headwordFontSize >= 48)

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
            .sheet(item: $detailSession, onDismiss: {
                selectedTerm = nil
            }) { session in
                TermDetailSheet(session: session, selectedTerm: $selectedTerm)
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
            #endif
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

    private var noSearchResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }
    
    // MARK: - Vocabulary List
    
    @ViewBuilder
    private var vocabularyList: some View {
        let list = List {
            ForEach(filteredTerms) { term in
                VocabularyRow(
                    term: term,
                    headwordFontSize: headwordFontSize,
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
                    openDetail(for: term)
                }
                .accessibilityAction(named: Text("Open Word Details")) {
                    openDetail(for: term)
                }
                #if os(iOS)
                .hoverEffect(.highlight)
                #endif
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
                                term.isMastered ? "Unmaster" : "Mark as Mastered",
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
                        savedTermsStore: savedTermsStore,
                        orderedTerms: filteredTerms
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
    /// Size of the headword — the word in the language being studied, which is
    /// Chinese for an English speaker and English for a Mandarin speaker. The
    /// storage key is still named for Chinese for backward compatibility.
    var headwordFontSize: Double = 20
    var isSelected: Bool = false
    var onMasteredToggle: (() -> Void)?
    var onAIExplainTap: (() -> Void)?
    @ScaledMetric(relativeTo: .title2) private var dynamicTypeScale: CGFloat = 1

    /// Han characters carry far more detail per glyph than Latin letters, so
    /// the same point size reads as noticeably smaller for Chinese. The slider
    /// is calibrated for Chinese headwords; an English headword is stepped
    /// down so the two directions look equally weighted in the row.
    private var renderedHeadwordFontSize: CGFloat {
        let base = CGFloat(headwordFontSize) * min(dynamicTypeScale, 1.5)
        return term.headlineText.containsCJK ? base : base * 0.85
    }

    private var secondaryControlSize: CGFloat {
        #if os(iOS)
        44
        #else
        28
        #endif
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Clickable mastered checkbox
            Button {
                onMasteredToggle?()
            } label: {
                Image(systemName: term.isMastered ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(term.isMastered ? .green : .secondary)
                    .font(.title3)
                    .frame(width: secondaryControlSize, height: secondaryControlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(term.isMastered ? "Unmaster" : "Mark as Mastered"))

            // Keep each word's related text in one flexible column so long
            // English headwords and accessibility text do not collide with
            // the row's secondary actions on narrow, resizable windows.
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // The headword — always the language being studied. A
                    // Mandarin speaker learning English sees the English word
                    // here, in the main font, with 中文 below as the gloss.
                    Text(term.headlineText)
                        .font(.system(size: renderedHeadwordFontSize, weight: .medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    if !term.partOfSpeech.isEmpty {
                        Text(term.partOfSpeech)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }

                // The reading, scaled with the headword so enlarging the word
                // also enlarges its pronunciation. Pinyin gets tone colors;
                // IPA is monospaced so the phonetic symbols stay legible.
                if term.showsPinyin {
                    Text(PinyinConverter.coloredPinyin(preferred: term.pinyin, fallbackText: term.chineseSide))
                        .font(.system(size: renderedHeadwordFontSize * 0.5))
                } else if term.showsPhonetic {
                    Text(term.pinyin)
                        .font(.system(size: renderedHeadwordFontSize * 0.55, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Native-language gloss, kept small.
                if !term.glossText.isEmpty {
                    Text(term.glossText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // AI Explain button
            if let onAIExplainTap = onAIExplainTap {
                AIExplainButton(
                    word: term.headlineText,
                    pinyin: term.headwordReading,
                    onTap: onAIExplainTap
                )
            }
        }
        .padding(.vertical, 2)
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

    private var controlSize: CGFloat {
        #if os(iOS)
        44
        #else
        24
        #endif
    }

    var body: some View {
        HStack(spacing: 18) {
            Button {
                size = max(range.lowerBound, size - step)
            } label: {
                Image(systemName: "minus")
                    .frame(width: controlSize, height: controlSize)
                    .contentShape(Rectangle())
            }
            .disabled(size <= range.lowerBound)
            .accessibilityLabel(Text("Decrease headword size"))

            Button {
                size = min(range.upperBound, size + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: controlSize, height: controlSize)
                    .contentShape(Rectangle())
            }
            .disabled(size >= range.upperBound)
            .accessibilityLabel(Text("Increase headword size"))
        }
        // Bare symbols with equal square hit areas. iOS uses the 44-point
        // minimum target from Apple's current button guidance.
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }
}

/// One modal browsing session. Its identity remains stable while the selected
/// term changes, and its ordered ID snapshot preserves the exact filtered and
/// sorted list the learner opened.
struct VocabularyDetailSession: Identifiable, Equatable {
    let id: UUID
    let initialTermID: SavedTerm.ID
    let orderedTermIDs: [SavedTerm.ID]

    init(
        id: UUID = UUID(),
        initialTermID: SavedTerm.ID,
        orderedTermIDs: [SavedTerm.ID]
    ) {
        self.id = id
        self.initialTermID = initialTermID
        self.orderedTermIDs = VocabularyPaging.uniqueIDs(orderedTermIDs)
    }
}

#if os(iOS)
struct TermDetailSheet: View {
    let session: VocabularyDetailSession
    @Binding var selectedTerm: SavedTerm?
    @Environment(\.dismiss) private var dismiss
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var visibleTermID: SavedTerm.ID?
    @State private var pageRequest: VocabularyPageRequest?

    init(session: VocabularyDetailSession, selectedTerm: Binding<SavedTerm?>) {
        self.session = session
        self._selectedTerm = selectedTerm
        // Seed UIKit's native pager and the toolbar from the exact row the
        // learner opened.
        self._visibleTermID = State(initialValue: session.initialTermID)
    }

    /// Resolve the snapshot through the live store so edits/mastery changes
    /// appear immediately and deleted terms disappear without stale pages.
    private var orderedTerms: [SavedTerm] {
        var termsByID: [SavedTerm.ID: SavedTerm] = [:]
        for term in savedTermsStore.terms {
            termsByID[term.id] = term
        }
        return session.orderedTermIDs.compactMap { termsByID[$0] }
    }

    private func currentIndex(in terms: [SavedTerm]) -> Int? {
        guard let visibleTermID else { return nil }
        return terms.firstIndex { $0.id == visibleTermID }
    }

    private func canGoPrevious(in terms: [SavedTerm]) -> Bool {
        guard let currentIndex = currentIndex(in: terms) else { return false }
        return currentIndex > terms.startIndex
    }

    private func canGoNext(in terms: [SavedTerm]) -> Bool {
        guard !terms.isEmpty,
              let currentIndex = currentIndex(in: terms) else { return false }
        return currentIndex < terms.index(before: terms.endIndex)
    }

    private func navigateToNeighbor(offset: Int, in terms: [SavedTerm]) {
        guard pageRequest == nil else { return }
        guard let targetID = VocabularyPaging.neighborID(
            currentID: visibleTermID,
            offset: offset,
            orderedIDs: terms.map(\.id)
        ) else { return }
        pageRequest = VocabularyPageRequest(targetID: targetID)
    }

    var body: some View {
        let terms = orderedTerms
        let visibleIndex = currentIndex(in: terms)

        NavigationStack {
            Group {
                if terms.isEmpty {
                    ContentUnavailableView(
                        "Word No Longer Available",
                        systemImage: "text.book.closed",
                        description: Text("This word was removed from your vocabulary.")
                    )
                } else {
                    nativePager(terms: terms)
                }
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if terms.count > 1 {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            navigateToNeighbor(offset: -1, in: terms)
                        } label: {
                            Label("Previous Word", systemImage: "chevron.backward")
                        }
                        .disabled(pageRequest != nil || !canGoPrevious(in: terms))
                        .keyboardShortcut(.leftArrow, modifiers: [.command])
                        .help("Previous word (⌘←)")

                        Spacer()

                        if let visibleIndex {
                            Text("\(visibleIndex + 1) of \(terms.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(
                                    Text("Word \(visibleIndex + 1) of \(terms.count)")
                                )
                        }

                        Spacer()

                        Button {
                            navigateToNeighbor(offset: 1, in: terms)
                        } label: {
                            Label("Next Word", systemImage: "chevron.forward")
                        }
                        .disabled(pageRequest != nil || !canGoNext(in: terms))
                        .keyboardShortcut(.rightArrow, modifiers: [.command])
                        .help("Next word (⌘→)")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            reconcileVisibleTerm(in: terms)
        }
        .onChange(of: terms.map(\.id)) { _, _ in
            // This observer lives outside the conditional pager so deleting
            // the final visible term still reconciles and closes the sheet.
            reconcileVisibleTerm(in: terms)
        }
    }

    private func nativePager(terms: [SavedTerm]) -> some View {
        VocabularyDetailPageController(
            terms: terms,
            settledID: $visibleTermID,
            request: $pageRequest,
            animatesProgrammaticTransitions: !reduceMotion,
            savedTermsStore: savedTermsStore,
            locale: locale
        )
        .background(SMTheme.pageBackground)
        .onChange(of: visibleTermID) { _, newID in
            guard let newID,
                  let term = terms.first(where: { $0.id == newID }) else { return }
            selectedTerm = term
        }
        .accessibilityAction(named: Text("Previous Word")) {
            navigateToNeighbor(offset: -1, in: terms)
        }
        .accessibilityAction(named: Text("Next Word")) {
            navigateToNeighbor(offset: 1, in: terms)
        }
    }

    private func reconcileVisibleTerm(in terms: [SavedTerm]) {
        guard !terms.isEmpty else {
            selectedTerm = nil
            dismiss()
            return
        }

        let reconciledID = VocabularyPaging.reconciledID(
            preferredID: visibleTermID,
            initialID: session.initialTermID,
            orderedIDs: terms.map(\.id)
        )
        guard let reconciledID else {
            selectedTerm = nil
            dismiss()
            return
        }
        visibleTermID = reconciledID
        selectedTerm = terms.first { $0.id == reconciledID }
    }
}

/// A toolbar/accessibility navigation request. Keeping this separate from the
/// settled selection means the underlying vocabulary list is not invalidated
/// until UIKit has finished the page transition.
private struct VocabularyPageRequest: Equatable {
    let token = UUID()
    let targetID: SavedTerm.ID
}

/// UIKit owns the interactive transition lifecycle here because a page-style
/// SwiftUI `TabView` does not expose a completion callback. In the former
/// implementation, changing the selection also changed the TabView's child
/// collection during the same gesture, which could strand two pages at a
/// partial offset. The data source below resolves neighbors lazily and commits
/// the SwiftUI selection only after UIKit reports a completed transition.
private struct VocabularyDetailPageController: UIViewControllerRepresentable {
    let terms: [SavedTerm]
    @Binding var settledID: SavedTerm.ID?
    @Binding var request: VocabularyPageRequest?
    let animatesProgrammaticTransitions: Bool
    let savedTermsStore: SavedTermsStore
    let locale: Locale

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pageController.dataSource = context.coordinator
        pageController.delegate = context.coordinator
        pageController.view.backgroundColor = .clear
        context.coordinator.attach(pageController, parent: self)
        return pageController
    }

    func updateUIViewController(
        _ pageController: UIPageViewController,
        context: Context
    ) {
        context.coordinator.update(parent: self, pageController: pageController)
    }

    static func dismantleUIViewController(
        _ pageController: UIPageViewController,
        coordinator: Coordinator
    ) {
        pageController.dataSource = nil
        pageController.delegate = nil
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        private typealias PageHost = UIHostingController<VocabularyHostedDetailPage>

        private var parent: VocabularyDetailPageController
        private weak var pageController: UIPageViewController?
        private var orderedIDs: [SavedTerm.ID] = []
        private var termSnapshot: [SavedTerm] = []
        private var termByID: [SavedTerm.ID: SavedTerm] = [:]
        private var indexByID: [SavedTerm.ID: Int] = [:]
        private var cachedHosts: [SavedTerm.ID: PageHost] = [:]
        private var currentID: SavedTerm.ID?
        private var lastHandledRequestToken: UUID?
        private var transitionIsInFlight = false

        init(parent: VocabularyDetailPageController) {
            self.parent = parent
        }

        func attach(
            _ pageController: UIPageViewController,
            parent: VocabularyDetailPageController
        ) {
            self.pageController = pageController
            self.parent = parent
            rebuildLookupIfNeeded(force: true)
            guard let initialID = resolvedRequestedOrSettledID(),
                  let host = host(for: initialID) else { return }
            currentID = initialID
            refreshCachedHosts()
            pageController.setViewControllers(
                [host],
                direction: .forward,
                animated: false
            )
            publishSettledIDIfNeeded(initialID)
            pruneCache()
        }

        func update(
            parent: VocabularyDetailPageController,
            pageController: UIPageViewController
        ) {
            self.parent = parent
            self.pageController = pageController

            // Never replace or remove controllers while UIKit is settling a
            // touch-driven or programmatic page transition.
            guard !transitionIsInFlight else { return }

            rebuildLookupIfNeeded()
            guard !orderedIDs.isEmpty else {
                cachedHosts.removeAll()
                return
            }

            if currentID.flatMap({ indexByID[$0] }) == nil {
                guard let replacementID = resolvedRequestedOrSettledID() else { return }
                showImmediately(replacementID, publishSelection: true)
                return
            }

            refreshCachedHosts()
            pruneCache()

            if let request = parent.request,
               request.token != lastHandledRequestToken {
                perform(request)
                return
            }

            // Store mutation reconciliation can legitimately change the
            // settled binding without producing a toolbar request.
            if let settledID = parent.settledID,
               indexByID[settledID] != nil,
               settledID != currentID {
                showImmediately(settledID, publishSelection: false)
            }
        }

        func tearDown() {
            transitionIsInFlight = false
            cachedHosts.removeAll()
            pageController = nil
        }

        private func rebuildLookupIfNeeded(force: Bool = false) {
            guard force || parent.terms != termSnapshot else { return }
            termSnapshot = parent.terms
            orderedIDs = parent.terms.map(\.id)
            termByID = Dictionary(uniqueKeysWithValues: parent.terms.map { ($0.id, $0) })
            indexByID = Dictionary(
                uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, $0.offset) }
            )
        }

        private func resolvedRequestedOrSettledID() -> SavedTerm.ID? {
            VocabularyPaging.resolvedIDAfterTransition(
                visibleID: nil,
                requestedID: parent.request?.targetID,
                settledID: parent.settledID,
                currentID: currentID,
                orderedIDs: orderedIDs
            )
        }

        private func rootView(for id: SavedTerm.ID) -> VocabularyHostedDetailPage? {
            guard let term = termByID[id], let index = indexByID[id] else { return nil }
            return VocabularyHostedDetailPage(
                term: term,
                position: index + 1,
                totalCount: orderedIDs.count,
                isCurrent: id == currentID,
                savedTermsStore: parent.savedTermsStore,
                locale: parent.locale
            )
        }

        private func host(for id: SavedTerm.ID) -> PageHost? {
            guard let rootView = rootView(for: id) else { return nil }
            if let cachedHost = cachedHosts[id] {
                cachedHost.rootView = rootView
                return cachedHost
            }

            let host = PageHost(rootView: rootView)
            host.view.backgroundColor = .clear
            cachedHosts[id] = host
            return host
        }

        private func refreshCachedHosts() {
            for (id, host) in cachedHosts {
                guard let rootView = rootView(for: id) else { continue }
                host.rootView = rootView
            }
        }

        private func pruneCache() {
            let retainedIDs = VocabularyPaging.pageWindowIDs(
                currentID: currentID,
                orderedIDs: orderedIDs
            )
            cachedHosts = cachedHosts.filter { retainedIDs.contains($0.key) }
            assert(
                cachedHosts.count <= 3,
                "Vocabulary pager must retain only the current page and its neighbors."
            )
        }

        /// Reconcile against the controller UIKit actually left on screen.
        /// This is essential when the store changes during an interactive
        /// transition: a cancelled gesture can otherwise reveal a hosting
        /// controller whose term was deleted while UIKit was settling it.
        private func reconcileVisibleControllerAfterTransition() {
            rebuildLookupIfNeeded()
            guard !orderedIDs.isEmpty else {
                cachedHosts.removeAll()
                return
            }

            let visibleID = (pageController?.viewControllers?.first as? PageHost)?.rootView.termID
            guard let resolvedID = VocabularyPaging.resolvedIDAfterTransition(
                visibleID: visibleID,
                requestedID: parent.request?.targetID,
                settledID: parent.settledID,
                currentID: currentID,
                orderedIDs: orderedIDs
            ) else {
                cachedHosts.removeAll()
                return
            }

            if resolvedID == visibleID {
                settle(on: resolvedID)
            } else {
                showImmediately(resolvedID, publishSelection: true)
            }
        }

        private func showImmediately(
            _ id: SavedTerm.ID,
            publishSelection: Bool
        ) {
            guard let pageController, let host = host(for: id) else { return }
            currentID = id
            refreshCachedHosts()
            pageController.setViewControllers(
                [host],
                direction: .forward,
                animated: false
            )
            if publishSelection {
                publishSettledIDIfNeeded(id)
            }
            publishRequest(nil)
            pruneCache()
        }

        private func perform(_ request: VocabularyPageRequest) {
            lastHandledRequestToken = request.token
            guard let pageController,
                  let targetIndex = indexByID[request.targetID],
                  let currentID,
                  let currentIndex = indexByID[currentID],
                  let targetHost = host(for: request.targetID) else {
                publishRequest(nil)
                return
            }

            guard targetIndex != currentIndex else {
                publishRequest(nil)
                return
            }

            transitionIsInFlight = true
            let direction: UIPageViewController.NavigationDirection =
                targetIndex > currentIndex ? .forward : .reverse

            pageController.setViewControllers(
                [targetHost],
                direction: direction,
                animated: parent.animatesProgrammaticTransitions
            ) { [weak self] finished in
                guard let self else { return }
                self.transitionIsInFlight = false
                self.rebuildLookupIfNeeded()
                if finished {
                    self.settle(on: request.targetID)
                } else {
                    self.reconcileVisibleControllerAfterTransition()
                }
                self.publishRequest(nil)
            }
        }

        private func settle(on candidateID: SavedTerm.ID) {
            guard indexByID[candidateID] != nil else {
                if let replacementID = resolvedRequestedOrSettledID() {
                    showImmediately(replacementID, publishSelection: true)
                }
                return
            }
            currentID = candidateID
            refreshCachedHosts()
            publishSettledIDIfNeeded(candidateID)
            pruneCache()
        }

        private func publishSettledIDIfNeeded(_ id: SavedTerm.ID) {
            let binding = parent.$settledID
            guard binding.wrappedValue != id else { return }
            DispatchQueue.main.async {
                guard binding.wrappedValue != id else { return }
                binding.wrappedValue = id
            }
        }

        private func publishRequest(_ request: VocabularyPageRequest?) {
            let binding = parent.$request
            DispatchQueue.main.async {
                guard binding.wrappedValue != request else { return }
                binding.wrappedValue = request
            }
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let currentHost = viewController as? PageHost,
                  let index = indexByID[currentHost.rootView.termID],
                  index > orderedIDs.startIndex else { return nil }
            return host(for: orderedIDs[index - 1])
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let currentHost = viewController as? PageHost,
                  let index = indexByID[currentHost.rootView.termID],
                  index + 1 < orderedIDs.endIndex else { return nil }
            return host(for: orderedIDs[index + 1])
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            willTransitionTo pendingViewControllers: [UIViewController]
        ) {
            transitionIsInFlight = true
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            transitionIsInFlight = false
            rebuildLookupIfNeeded()
            if completed,
               let host = pageViewController.viewControllers?.first as? PageHost {
                settle(on: host.rootView.termID)
            } else {
                reconcileVisibleControllerAfterTransition()
            }
        }
    }
}

private struct VocabularyHostedDetailPage: View {
    let term: SavedTerm
    let position: Int
    let totalCount: Int
    let isCurrent: Bool
    let savedTermsStore: SavedTermsStore
    let locale: Locale

    var termID: SavedTerm.ID { term.id }

    var body: some View {
        TermDetailPage(
            term: term,
            position: position,
            totalCount: totalCount,
            isCurrent: isCurrent
        )
        .environment(savedTermsStore)
        .environment(\.locale, locale)
    }
}

private struct TermDetailPage: View {
    let term: SavedTerm
    let position: Int
    let totalCount: Int
    let isCurrent: Bool
    @Environment(SavedTermsStore.self) private var savedTermsStore

    @State private var fetchedTranslation: String = ""
    @State private var isLoadingTranslation: Bool = false
    @State private var copiedAction: CopyAction?
    @State private var translationTask: Task<Void, Never>?
    @State private var copyResetTask: Task<Void, Never>?
    @AccessibilityFocusState private var isHeadwordFocused: Bool
    /// Persisted size of the headword in the detail view; the −/+ buttons
    /// adjust it and the reading scales with it. The stored key keeps its
    /// original name so existing preferences survive.
    @AppStorage("vocabularyDetailChineseFontSize") private var detailFontSize: Double = 96
    @ScaledMetric(relativeTo: .largeTitle) private var dynamicTypeScale: CGFloat = 1

    private enum CopyAction: Equatable {
        case headword
        case all
    }

    /// 96 pt suits one or two Han characters. An English headword is a word,
    /// not a glyph, so the same size overflows the block and immediately hits
    /// `minimumScaleFactor` — stepping it down keeps the two directions
    /// visually equivalent instead of merely equal in points.
    private var renderedDetailFontSize: CGFloat {
        let base = CGFloat(detailFontSize) * min(dynamicTypeScale, 1.4)
        return term.headlineText.containsCJK ? base : base * 0.6
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

    private var masteredBinding: Binding<Bool> {
        Binding(
            get: { term.isMastered },
            set: { isMastered in
                guard savedTermsStore.term(withID: term.id)?.isMastered != isMastered else { return }
                savedTermsStore.setMastered(term, isMastered: isMastered)
                triggerHaptic()
            }
        )
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    // Large headword display — the language being learned.
                    // English headwords can be long, so allow shrinking.
                    VStack(spacing: 12) {
                        Text(term.headlineText)
                            .font(.system(size: renderedDetailFontSize, weight: .medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.35)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .accessibilityFocused($isHeadwordFocused)
                            .accessibilityLabel(Text(term.headlineText))
                            .accessibilityValue(Text("Word \(position) of \(totalCount)"))
                            .accessibilityIdentifier("vocabulary-detail-headword-\(term.id.uuidString)")

                        if term.showsPinyin {
                            Text(PinyinConverter.coloredPinyin(preferred: term.pinyin, fallbackText: term.chineseSide))
                                .font(.system(size: renderedDetailFontSize * 0.45))
                        } else if term.showsPhonetic {
                            Text(term.pinyin)
                                .font(.system(size: renderedDetailFontSize * 0.42, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }

                        if !term.partOfSpeech.isEmpty {
                            Text(term.partOfSpeech)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.blue))
                        }

                        // Size control tucked into the bottom-right of the
                        // headword block rather than centered beneath it.
                        HStack {
                            Spacer()
                            DetailFontSizeStepper(size: $detailFontSize)
                        }
                        .padding(.trailing, 4)
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
                                    startTranslation()
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
                    
                    // Adaptive action grid: two columns on compact phones,
                    // expanding naturally on iPad and at smaller text sizes.
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130), spacing: 12)],
                        spacing: 12
                    ) {
                        Button {
                            SpeechService.speakAuto(term.headlineText)
                            triggerHaptic()
                        } label: {
                            Label("Speak", systemImage: "speaker.wave.2")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            performCopy(.headword)
                        } label: {
                            Label(
                                copiedAction == .headword ? "Copied!" : "Copy",
                                systemImage: copiedAction == .headword ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(copiedAction == .headword ? .green : nil)

                        Button {
                            performCopy(.all)
                        } label: {
                            Label(
                                copiedAction == .all ? "Copied!" : "Copy All",
                                systemImage: copiedAction == .all ? "checkmark" : "doc.on.doc.fill"
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(copiedAction == .all ? .green : nil)
                        
                        Toggle(isOn: masteredBinding) {
                            Label(
                                "Mastered",
                                systemImage: term.isMastered ? "checkmark.circle.fill" : "checkmark.circle"
                            )
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(term.isMastered ? .green : nil)
                    }
                    .padding(.horizontal)
                    
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
                            pinyin: term.headwordReading,
                            context: term.glossText.isEmpty ? nil : term.glossText,
                            contentLayout: .embedded,
                            isActive: isCurrent
                        )
                    }

                    Spacer()
                }
                .padding(.vertical, 12)
                .frame(maxWidth: SMTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
        }
        .background(SMTheme.pageBackground)
        .task(id: isCurrent) {
            guard isCurrent, term.glossText.isEmpty else { return }
            await fetchTranslation()
        }
        .onAppear {
            if isCurrent {
                isHeadwordFocused = true
            }
        }
        .onChange(of: isCurrent) { _, isNowCurrent in
            if isNowCurrent {
                isHeadwordFocused = true
            } else {
                translationTask?.cancel()
            }
        }
        .onDisappear {
            translationTask?.cancel()
            copyResetTask?.cancel()
        }
    }

    /// Translate the headword into the user's native language (the headword's
    /// own language decides the direction, since it can be either).
    private func startTranslation() {
        translationTask?.cancel()
        translationTask = Task { @MainActor in
            await fetchTranslation()
            translationTask = nil
        }
    }

    private func fetchTranslation() async {
        guard !isLoadingTranslation else { return }
        isLoadingTranslation = true

        do {
            let headword = term.headlineText
            let translation = try await WordTranslationService.shared
                .translate(headword, sourceIsChinese: headword.containsCJK)
            try Task.checkCancellation()
            fetchedTranslation = translation
        } catch is CancellationError {
            // Expected when a lazily-created neighboring page moves offscreen.
        } catch {
            print("Failed to fetch translation: \(error)")
        }
        isLoadingTranslation = false
    }

    private func performCopy(_ action: CopyAction) {
        let text: String
        switch action {
        case .headword:
            text = term.headlineText
        case .all:
            text = [
                term.headlineText,
                term.headwordReading,
                displayDefinition
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        }

        ClipboardService.copy(text)
        copiedAction = action
        triggerHaptic()

        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, copiedAction == action else { return }
            copiedAction = nil
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
        triggerHaptic()
    }

    private func triggerHaptic() {
        #if os(iOS)
        // The Settings toggle defaults to ON, so an unset key must read as
        // true (`bool(forKey:)` would return false until the user ever
        // touches the toggle).
        let hapticEnabled = (UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool) ?? true
        if hapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        #endif
    }
}

#endif

// MARK: - Term Detail Inspector (macOS)

#if os(macOS)
struct TermDetailInspector: View {
    let term: SavedTerm
    @Binding var selectedTerm: SavedTerm?
    var savedTermsStore: SavedTermsStore
    /// The visible (filtered + sorted) list this term was opened from, in
    /// display order — prev/next navigation walks exactly this order.
    var orderedTerms: [SavedTerm] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fetchedTranslation: String = ""
    @State private var isLoadingTranslation: Bool = false
    @State private var copiedAction: CopyAction?
    @State private var copyResetTask: Task<Void, Never>?
    /// Persisted size of the Chinese headword in the detail view; shared with
    /// the sheet presentation so the −/+ buttons behave identically.
    @AppStorage("vocabularyDetailChineseFontSize") private var detailFontSize: Double = 96
    @ScaledMetric(relativeTo: .largeTitle) private var dynamicTypeScale: CGFloat = 1

    private enum CopyAction: Equatable {
        case headword
        case all
    }

    /// See `TermDetailPage.renderedDetailFontSize`: an English headword is a
    /// word rather than one or two glyphs, so it is stepped down to stay
    /// visually equivalent to a Chinese one at the same slider position.
    private var renderedDetailFontSize: CGFloat {
        let base = CGFloat(detailFontSize) * min(dynamicTypeScale, 1.4)
        return term.headlineText.containsCJK ? base : base * 0.6
    }

    // MARK: Prev/Next Navigation

    /// Position of the shown term in the visible list; nil when the list has
    /// changed under the inspector (disables navigation + hides the indicator).
    private var currentIndex: Int? {
        orderedTerms.firstIndex(where: { $0.id == term.id })
    }

    private var canGoPrevious: Bool {
        guard let index = currentIndex else { return false }
        return index > 0
    }

    private var canGoNext: Bool {
        guard let index = currentIndex else { return false }
        return index < orderedTerms.count - 1
    }

    /// Move the selection by `offset` within the visible list. Updating
    /// `selectedTerm` re-presents the inspector for the neighbor and keeps
    /// the list selection highlight in sync.
    private func navigateToNeighbor(offset: Int) {
        guard let index = currentIndex else { return }
        let target = index + offset
        guard orderedTerms.indices.contains(target) else { return }
        if reduceMotion {
            selectedTerm = orderedTerms[target]
        } else {
            withAnimation(.snappy(duration: 0.3)) {
                selectedTerm = orderedTerms[target]
            }
        }
    }

    private var displayDefinition: String {
        if !fetchedTranslation.isEmpty {
            return fetchedTranslation
        }
        return term.glossText
    }

    private var shouldOfferTranslation: Bool {
        term.glossText.isEmpty || term.glossText.count > 100
    }

    private var masteredBinding: Binding<Bool> {
        Binding(
            get: { term.isMastered },
            set: { isMastered in
                guard savedTermsStore.term(withID: term.id)?.isMastered != isMastered else { return }
                savedTermsStore.setMastered(term, isMastered: isMastered)
                selectedTerm = savedTermsStore.term(withID: term.id)
            }
        )
    }

    private var inspectorHeader: some View {
        HStack(spacing: 10) {
            Button {
                navigateToNeighbor(offset: -1)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(!canGoPrevious)
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .help("Previous word (⌘←)")
            .accessibilityLabel(Text("Previous Word"))

            Button {
                navigateToNeighbor(offset: 1)
            } label: {
                Image(systemName: "chevron.forward")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(!canGoNext)
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .help("Next word (⌘→)")
            .accessibilityLabel(Text("Next Word"))

            if let index = currentIndex, orderedTerms.count > 1 {
                Text("\(index + 1) of \(orderedTerms.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Word \(index + 1) of \(orderedTerms.count)"))
            }

            Spacer()

            Button {
                selectedTerm = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Keep navigation in the macOS navigation layer so it remains
            // reachable while a long definition or AI explanation scrolls.
            inspectorHeader
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                // Large headword display — the language being learned.
                VStack(spacing: 10) {
                    Text(term.headlineText)
                        .font(.system(size: renderedDetailFontSize, weight: .medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.35)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if term.showsPinyin {
                        Text(PinyinConverter.coloredPinyin(preferred: term.pinyin, fallbackText: term.chineseSide))
                            .font(.system(size: renderedDetailFontSize * 0.45))
                    } else if term.showsPhonetic {
                        Text(term.pinyin)
                            .font(.system(size: renderedDetailFontSize * 0.42, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }

                    if !term.partOfSpeech.isEmpty {
                        Text(term.partOfSpeech)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.blue))
                    }

                    // Size control tucked into the bottom-right of the
                    // headword block rather than centered beneath it.
                    HStack {
                        Spacer()
                        DetailFontSizeStepper(size: $detailFontSize)
                    }
                    .padding(.trailing, 4)
                }
                
                Divider()
                
                // Mastered toggle
                Toggle(isOn: masteredBinding) {
                    HStack {
                        Image(systemName: term.isMastered ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(term.isMastered ? .green : .secondary)
                        Text("Mastered")
                            .foregroundStyle(term.isMastered ? .green : .primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .toggleStyle(.button)
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
                        performCopy(.headword, text: term.headlineText)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: copiedAction == .headword ? "checkmark" : "doc.on.doc")
                                .font(.title3)
                            Text(copiedAction == .headword ? "Copied!" : "Copy")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedAction == .headword ? .green : nil)

                    Button {
                        let parts = [
                            term.headlineText,
                            term.headwordReading,
                            displayDefinition
                        ].filter { !$0.isEmpty }
                        let text = parts.joined(separator: "\n")
                        performCopy(.all, text: text)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: copiedAction == .all ? "checkmark" : "doc.on.doc.fill")
                                .font(.title3)
                            Text(copiedAction == .all ? "Copied!" : "Copy All")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedAction == .all ? .green : nil)
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
                        pinyin: term.headwordReading,
                        context: term.glossText.isEmpty ? nil : term.glossText,
                        contentLayout: .embedded
                    )
                }

                Spacer()
                }
                .padding(.vertical)
            }
        }
        .task(id: term.id) {
            // Reset state when term changes
            fetchedTranslation = ""
            isLoadingTranslation = false
            copiedAction = nil

            if term.glossText.isEmpty {
                await fetchTranslation()
            }
        }
        .onDisappear {
            copyResetTask?.cancel()
        }
    }

    private func performCopy(_ action: CopyAction, text: String) {
        ClipboardService.copy(text)
        copiedAction = action
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled, copiedAction == action else { return }
                copiedAction = nil
            } catch is CancellationError {
                // Expected when another copy action replaces this feedback.
            } catch {
                // Task.sleep currently only throws for cancellation.
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
    @State private var exportSuccessMessage: String = String(localized: "Exported Successfully", bundle: .appLanguage)

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
                        exportSuccessMessage = String(localized: "Saved to File", bundle: .appLanguage)
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
                        exportSuccessMessage = String(localized: "Copied to Clipboard", bundle: .appLanguage)
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
                pinyin: term.headwordReading,
                context: term.glossText.isEmpty ? nil : term.glossText
            )
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 550, idealHeight: 650)
        #else
        NavigationStack {
            AIWordExplanationView(
                word: term.headlineText,
                pinyin: term.headwordReading,
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
    NavigationStack {
        VocabularyView()
            .environment(SavedTermsStore.shared)
            .environment(AppRouteStore.shared)
    }
}
