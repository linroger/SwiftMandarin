//
//  GlobalSearchView.swift
//  SwiftMandarin
//
//  One search field over everything the learner has accumulated: saved
//  vocabulary, the phrasebook, translation history, and Reader texts. On
//  iOS 26 it is the system search tab, so the field sits in the tab bar; on
//  earlier iOS it is a Library row in the Study hub; on macOS a sidebar item.
//

import SwiftUI

struct GlobalSearchView: View {
    @Binding var selectedTab: AppTab
    /// In the iOS 26 search tab the system owns the field's placement (it
    /// lives in the tab bar). Pushed anywhere else, the field is pinned open:
    /// the default navigation-bar drawer starts collapsed, so a pushed search
    /// screen showed no field at all until the list was pulled down.
    var isSearchTab = false
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(TranslationHistoryStore.self) private var historyStore
    @State private var readerStore = ReaderStore.shared
    @State private var localization = LocalizationManager.shared

    @State private var query = ""
    @State private var results = SearchResults()
    @State private var openText: ReaderText?
    @State private var phraseDetail: Phrase?
    #if os(iOS)
    @State private var detailSession: VocabularyDetailSession?
    @State private var detailTerm: SavedTerm?
    #else
    @State private var inspectedTerm: SavedTerm?
    #endif

    /// Rows shown per section. The header still reports the full count, so a
    /// broad query reads "Vocabulary 30 of 212" without listing all 212.
    private static let sectionLimit = 30

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if trimmedQuery.isEmpty {
                overview
            } else if results.isEmpty {
                // "No results" only once this query's search has finished.
                // Until then `results` still belongs to the previous query,
                // and on the first keystroke it flashed "No results" for the
                // length of the debounce.
                if results.query == trimmedQuery {
                    noResults
                } else {
                    Color.clear
                }
            } else {
                resultList
            }
        }
        .background(SMTheme.pageBackground)
        .navigationTitle("Search")
        .modifier(SearchFieldPlacement(query: $query, isSearchTab: isSearchTab))
        .task(id: trimmedQuery) { await runSearch(for: trimmedQuery) }
        // Editing a result in its own detail sheet (Mastered, the entry
        // itself) changes a store without changing the query or hiding this
        // screen, so the rows kept the old seal, headline, and gloss.
        .onChange(of: savedTermsStore.terms) { refreshResults() }
        .onChange(of: historyStore.entries) { refreshResults() }
        .onChange(of: readerStore.texts) { refreshResults() }
        .navigationDestination(item: $openText) { text in
            ReaderSessionView(text: text)
        }
        .sheet(item: $phraseDetail) { phrase in
            PhraseDetailSheet(phrase: phrase)
                .localizedSurface()
        }
        #if os(iOS)
        .sheet(item: $detailSession) { session in
            TermDetailSheet(session: session, selectedTerm: $detailTerm)
                .localizedSurface()
        }
        #else
        .sheet(item: $inspectedTerm) { term in
            NavigationStack {
                TermDetailInspector(
                    term: term,
                    selectedTerm: $inspectedTerm,
                    savedTermsStore: savedTermsStore,
                    orderedTerms: results.terms
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { inspectedTerm = nil }
                    }
                }
            }
            .frame(minWidth: 380, idealWidth: 440, minHeight: 540)
            .localizedSurface()
        }
        #endif
    }

    // MARK: - States

    /// The empty field: how to search, plus the newest material, so the
    /// screen is useful before a single character is typed.
    private var overview: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Search everything you've saved", systemImage: "magnifyingglass")
                        .font(.headline)
                    Text("Saved words by headword, pinyin, or meaning; phrasebook entries; past translations; and Reader texts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            let recentTerms = Array(savedTermsStore.terms.sorted { $0.dateAdded > $1.dateAdded }.prefix(5))
            if !recentTerms.isEmpty {
                Section("Recently saved") {
                    ForEach(recentTerms) { term in
                        termRow(term, in: recentTerms)
                    }
                }
            }

            let recentHistory = Array(historyStore.entries.prefix(5))
            if !recentHistory.isEmpty {
                Section("Recent translations") {
                    ForEach(recentHistory) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var noResults: some View {
        SMEmptyState(
            icon: "magnifyingglass",
            titleKey: "No results",
            messageKey: "Nothing matches “\(trimmedQuery)”. Try the other language, pinyin without tones, or a shorter word."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultList: some View {
        List {
            if !results.terms.isEmpty {
                Section {
                    ForEach(results.terms) { term in
                        termRow(term, in: results.terms)
                    }
                } header: {
                    sectionHeader("Vocabulary", shown: results.terms.count, total: results.termTotal)
                }
            }
            if !results.phrases.isEmpty {
                Section {
                    ForEach(results.phrases) { hit in
                        phraseRow(hit)
                    }
                } header: {
                    sectionHeader("Phrases", shown: results.phrases.count, total: results.phraseTotal)
                }
            }
            if !results.history.isEmpty {
                Section {
                    ForEach(results.history) { entry in
                        historyRow(entry)
                    }
                } header: {
                    sectionHeader("History", shown: results.history.count, total: results.historyTotal)
                }
            }
            if !results.texts.isEmpty {
                Section {
                    ForEach(results.texts) { text in
                        textRow(text)
                    }
                } header: {
                    sectionHeader("Reader", shown: results.texts.count, total: results.textTotal)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ titleKey: LocalizedStringKey, shown: Int, total: Int) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            if total > shown {
                Text("\(shown) of \(total)")
                    .monospacedDigit()
            } else {
                Text(verbatim: "\(total)")
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Rows

    private func termRow(_ term: SavedTerm, in list: [SavedTerm]) -> some View {
        Button {
            open(term, in: list)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(highlighted(term.headlineText))
                        .font(.headline)
                    Text(highlighted(termSubtitle(term)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if term.isMastered {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel(Text("Mastered"))
                }
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Pinyin is a reading aid for a Chinese headword: it helps the learner
    /// studying Chinese and never applies to an IPA reading.
    private func termSubtitle(_ term: SavedTerm) -> String {
        let gloss = term.glossText
        guard localization.learningIsChinese, !term.pinyin.isEmpty, !term.pinyin.looksLikeIPA else { return gloss }
        return gloss.isEmpty ? term.pinyin : "\(term.pinyin) · \(gloss)"
    }

    private func phraseRow(_ hit: PhraseHit) -> some View {
        let learningChinese = localization.learningIsChinese
        return Button {
            phraseDetail = hit.phrase
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(highlighted(learningChinese ? hit.phrase.chinese : hit.phrase.english))
                        .font(.headline)
                    Text(highlighted(learningChinese ? "\(hit.phrase.pinyin) · \(hit.phrase.english)" : hit.phrase.chinese))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(L(hit.category))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ entry: TranslationHistoryEntry) -> some View {
        Button {
            TranslationState.shared.restore(from: entry)
            selectedTab = .translate
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(highlighted(entry.source))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Text(highlighted(entry.target))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(entry.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens this translation in Translate"))
    }

    private func textRow(_ text: ReaderText) -> some View {
        Button {
            openText = text
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "book.pages")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(highlighted(text.title))
                        .font(.headline)
                        .lineLimit(1)
                    Text(highlighted(snippet(of: text)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                chevron
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Actions

    private func open(_ term: SavedTerm, in list: [SavedTerm]) {
        #if os(iOS)
        detailTerm = term
        detailSession = VocabularyDetailSession(
            initialTermID: term.id,
            orderedTermIDs: list.isEmpty ? [term.id] : list.map(\.id)
        )
        #else
        inspectedTerm = term
        #endif
    }

    // MARK: - Search

    private func runSearch(for q: String) async {
        guard !q.isEmpty else {
            results = SearchResults()
            return
        }
        // Typing quickly would otherwise scan every store on each keystroke.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        results = search(for: q)
    }

    /// Re-runs the current query at once, without the keystroke debounce:
    /// the data changed, not the query.
    private func refreshResults() {
        let q = trimmedQuery
        guard !q.isEmpty else { return }
        results = search(for: q)
    }

    private func search(for q: String) -> SearchResults {
        var found = SearchResults(query: q)

        let termHits = savedTermsStore.terms.filter { SavedTermEntityQuery.matches($0, query: q) }
        found.termTotal = termHits.count
        found.terms = Array(termHits.prefix(Self.sectionLimit))

        // Phrases match on either side or on tone-stripped pinyin, so "ni hao"
        // finds 你好 just as the vocabulary search does.
        let foldedQuery = SavedTermEntityQuery.foldedPinyin(q)
        let phraseHits = PhraseCategory.allCategories.flatMap { category in
            category.phrases
                .filter { phrase in
                    phrase.chinese.localizedCaseInsensitiveContains(q)
                        || phrase.english.localizedCaseInsensitiveContains(q)
                        || (!foldedQuery.isEmpty && SavedTermEntityQuery.foldedPinyin(phrase.pinyin).contains(foldedQuery))
                }
                .map { PhraseHit(phrase: $0, category: category.name) }
        }
        found.phraseTotal = phraseHits.count
        found.phrases = Array(phraseHits.prefix(Self.sectionLimit))

        let historyHits = historyStore.entries.filter {
            $0.source.localizedCaseInsensitiveContains(q) || $0.target.localizedCaseInsensitiveContains(q)
        }
        found.historyTotal = historyHits.count
        found.history = Array(historyHits.prefix(Self.sectionLimit))

        let textHits = readerStore.texts.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.content.localizedCaseInsensitiveContains(q)
        }
        found.textTotal = textHits.count
        found.texts = Array(textHits.prefix(Self.sectionLimit))

        return found
    }

    /// The query's first occurrence in `text`, tinted and emphasized, so a
    /// row shows *where* it matched.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let q = trimmedQuery
        guard !q.isEmpty,
              let range = text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]),
              let lower = AttributedString.Index(range.lowerBound, within: attributed),
              let upper = AttributedString.Index(range.upperBound, within: attributed) else {
            return attributed
        }
        attributed[lower..<upper].foregroundColor = .accentColor
        attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        return attributed
    }

    /// The passage around the first match, so a Reader row shows why the text
    /// matched rather than its opening words.
    private func snippet(of text: ReaderText) -> String {
        let content = text.content
        let q = trimmedQuery
        guard !q.isEmpty,
              let range = content.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(content.prefix(120))
        }
        let start = content.index(range.lowerBound, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: 80, limitedBy: content.endIndex) ?? content.endIndex
        var excerpt = String(content[start..<end]).replacingOccurrences(of: "\n", with: " ")
        if start > content.startIndex { excerpt = "…" + excerpt }
        if end < content.endIndex { excerpt += "…" }
        return excerpt
    }
}

// MARK: - Search field

private struct SearchFieldPlacement: ViewModifier {
    @Binding var query: String
    let isSearchTab: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        if isSearchTab {
            content.searchable(text: $query, prompt: Text("Words, phrases, translations, texts"))
        } else {
            content.searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Words, phrases, translations, texts")
            )
        }
        #else
        content.searchable(text: $query, prompt: Text("Words, phrases, translations, texts"))
        #endif
    }
}

// MARK: - Results

private struct SearchResults {
    /// The query these results answer; empty before any search has finished.
    var query = ""
    var terms: [SavedTerm] = []
    var phrases: [PhraseHit] = []
    var history: [TranslationHistoryEntry] = []
    var texts: [ReaderText] = []
    var termTotal = 0
    var phraseTotal = 0
    var historyTotal = 0
    var textTotal = 0

    var isEmpty: Bool {
        terms.isEmpty && phrases.isEmpty && history.isEmpty && texts.isEmpty
    }
}

private struct PhraseHit: Identifiable {
    let phrase: Phrase
    let category: String
    var id: String { phrase.id }
}
