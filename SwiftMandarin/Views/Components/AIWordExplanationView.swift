//
//  AIWordExplanationView.swift
//  SwiftMandarin
//
//  A reusable view component that displays AI-generated word explanations
//  using either Apple Intelligence or Ollama based on user settings
//

import SwiftUI

/// A view that displays a detailed AI-generated explanation for a Mandarin word
struct AIWordExplanationView: View {
    enum ContentLayout {
        /// The explanation owns its vertical scrolling, as in the standalone
        /// analysis sheet.
        case selfScrolling
        /// A parent detail page owns vertical scrolling, so this view renders
        /// its full content without introducing a competing gesture region.
        case embedded
    }

    let word: String
    let pinyin: String
    let context: String?
    let contentLayout: ContentLayout

    init(
        word: String,
        pinyin: String,
        context: String?,
        contentLayout: ContentLayout = .selfScrolling
    ) {
        self.word = word
        self.pinyin = pinyin
        self.context = context
        self.contentLayout = contentLayout
    }

    /// Every collapsible-section id the explanation card can render. Kept in
    /// one place so the initial expansion state can't drift out of sync with
    /// the sections themselves (previously only definition/examples started
    /// expanded, hiding nuances/grammar/synonyms/collocations behind taps).
    private static let allSectionIDs: Set<String> = [
        "definition", "nuances", "grammar", "contexts", "examples",
        "synonyms", "antonyms", "collocations", "tip"
    ]

    @State private var explanation: WordExplanationResult?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    /// Sections currently expanded. Everything starts open; users collapse
    /// what they don't need (tap-to-collapse is preserved).
    @State private var expandedSections: Set<String> = AIWordExplanationView.allSectionIDs
    /// True when the currently shown explanation came from the persistent cache
    /// rather than a fresh generation, so the UI can label it.
    @State private var servedFromCache: Bool = false
    /// Identity (word + direction) the currently shown explanation belongs to.
    /// Lets us drop a stale explanation if the view instance is reused for a
    /// different word (e.g. `sheet(item:)` reuse) or the interface language
    /// flips while open.
    @State private var shownKey: String?
    /// Provider that generated the currently shown explanation. For a cached
    /// result this is the provider recorded at generation time (which may differ
    /// from the current selection), so the badge stays accurate.
    @State private var shownProviderName: String?

    private let aiService = AIWordExplanationService.shared
    private let aiSettings = AIModelSettings.shared
    private let cache = WordExplanationCacheStore.shared

    /// Direction token for the current word + interface language, used as the
    /// per-direction cache key. Recomputed if the language changes while open.
    private var directionToken: String {
        ExplanationDirection.current(forWord: word).cacheToken
    }

    /// Identity of what should be shown right now: the word plus its direction.
    /// Drives `.task(id:)` so the view reconciles when reused for another word.
    private var currentKey: String { "\(word)\u{1}\(directionToken)" }

    /// Provider label for the header: the generating provider for a cached
    /// result, otherwise the current selection.
    private var displayedProviderName: String {
        servedFromCache ? (shownProviderName ?? currentProviderName) : currentProviderName
    }

    /// Provider whose icon/name the header shows. For a cached result this is
    /// resolved from the recorded provider name (display names are unique), so
    /// the icon matches the label even after the user switches providers.
    private var displayedProvider: AIProvider {
        if servedFromCache, let name = shownProviderName,
           let match = AIProvider.allCases.first(where: { $0.displayName == name }) {
            return match
        }
        return aiSettings.effectiveProvider
    }
    
    /// Check if any AI provider is available
    private var isAnyProviderAvailable: Bool {
        aiSettings.isAnyProviderAvailable
    }
    
    /// Get the current provider name for display
    private var currentProviderName: String {
        aiSettings.effectiveProvider.displayName
    }
    
    var body: some View {
        Group {
            if !isAnyProviderAvailable {
                unavailableView
            } else if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let explanation = explanation {
                explanationContent(explanation)
            } else {
                generateButton
            }
        }
        // Serve a previously generated explanation instantly, without another
        // AI round-trip. Re-runs if the word OR direction changes (view reuse /
        // interface-language flip). Never overrides a fresh in-memory result.
        .task(id: currentKey) {
            loadCachedExplanationIfAvailable()
        }
    }
    
    // MARK: - Unavailable State
    
    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("AI Not Available")
                .font(.headline)

            Text("Enable Apple Intelligence, connect to Ollama, or add a cloud provider API key (OpenAI, Claude, Qwen, and more) in Settings to use AI features.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("Generating explanation...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Using \(currentProviderName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error State
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            
            Text("Could not generate explanation")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await generateExplanation(force: true) }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)
            
            ProviderIcon(provider: aiSettings.effectiveProvider, size: 40)
                .foregroundStyle(.blue)
            
            Text("Get a detailed explanation of this word including nuances, grammar usage, examples, and more.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await generateExplanation() }
            } label: {
                Label("Explain with \(currentProviderName)", systemImage: "sparkles")
                    .fitSingleLine()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Explanation Content
    
    @ViewBuilder
    private func explanationContent(_ explanation: WordExplanationResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI badge header
            HStack {
                ProviderIcon(provider: displayedProvider, size: 16)
                    .foregroundStyle(.blue)
                Text(displayedProviderName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                if servedFromCache {
                    Label("Saved", systemImage: "internaldrive")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Loaded from a previously generated explanation. Tap refresh to regenerate.")
                }
                Spacer()
                // Re-run the analysis with the currently selected AI model,
                // replacing the saved result. Always bypasses the cache —
                // including the service's in-memory one.
                Button {
                    Task { await generateExplanation(force: true) }
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Re-run this analysis with \(currentProviderName)")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.blue.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 16) {
                    // Definition Section
                    collapsibleSection(
                        title: "Definition",
                        icon: "text.book.closed",
                        id: "definition"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            if !explanation.partOfSpeech.isEmpty {
                                Text(explanation.partOfSpeech)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.blue))
                            }
                            
                            Text(explanation.definition)
                                .font(.body)
                        }
                    }
                    
                    // Nuances Section
                    if !explanation.nuances.isEmpty {
                        collapsibleSection(
                            title: "Nuances & Context",
                            icon: "lightbulb",
                            id: "nuances"
                        ) {
                            Text(explanation.nuances)
                                .font(.callout)
                        }
                    }
                    
                    // Grammar Usage Section
                    if !explanation.grammarUsage.isEmpty {
                        collapsibleSection(
                            title: "Grammar Usage",
                            icon: "text.alignleft",
                            id: "grammar"
                        ) {
                            Text(explanation.grammarUsage)
                                .font(.callout)
                        }
                    }
                    
                    // Usage Contexts Section
                    if !explanation.usageContexts.isEmpty {
                        collapsibleSection(
                            title: "When to Use",
                            icon: "bubble.left.and.bubble.right",
                            id: "contexts"
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(explanation.usageContexts, id: \.self) { context in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        Text(context)
                                            .font(.callout)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Example Sentences Section
                    if !explanation.exampleSentences.isEmpty {
                        collapsibleSection(
                            title: "Examples",
                            icon: "text.quote",
                            id: "examples"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(explanation.exampleSentences) { sentence in
                                    exampleSentenceRow(sentence)
                                }
                            }
                        }
                    }
                    
                    // Synonyms Section
                    if !explanation.synonyms.isEmpty {
                        collapsibleSection(
                            title: "Synonyms",
                            icon: "equal.circle",
                            id: "synonyms"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(explanation.synonyms) { synonym in
                                    relatedWordRow(synonym, tint: .blue)
                                }
                            }
                        }
                    }
                    
                    // Antonyms Section
                    if !explanation.antonyms.isEmpty {
                        collapsibleSection(
                            title: "Antonyms",
                            icon: "arrow.left.arrow.right",
                            id: "antonyms"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(explanation.antonyms) { antonym in
                                    relatedWordRow(antonym, tint: .orange)
                                }
                            }
                        }
                    }
                    
                    // Common Collocations Section
                    if !explanation.commonCollocations.isEmpty {
                        collapsibleSection(
                            title: "Common Phrases",
                            icon: "text.badge.plus",
                            id: "collocations"
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(explanation.commonCollocations) { collocation in
                                    collocationRow(collocation)
                                }
                            }
                        }
                    }
                    
                    // Learning Tip Section
                    if !explanation.learningTip.isEmpty {
                        collapsibleSection(
                            title: "Learning Tip",
                            icon: "graduationcap",
                            id: "tip"
                        ) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text(explanation.learningTip)
                                    .font(.callout)
                                    .italic()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.yellow.opacity(0.1))
                            )
                        }
                    }
            }
            .padding()
            .aiExplanationScrollContainer(contentLayout == .selfScrolling)
        }
    }
    
    // MARK: - Section Components
    
    @ViewBuilder
    private func collapsibleSection<Content: View>(
        title: String,
        icon: String,
        id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(id) {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: expandedSections.contains(id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            
            if expandedSections.contains(id) {
                content()
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func exampleSentenceRow(_ sentence: ExampleSentenceResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // The sentence is in the word's own language (the learning
                // target), so it leads; pinyin only exists for Chinese text.
                Text(sentence.sentence)
                    .font(.body)
                    .fontWeight(.medium)

                if !sentence.pinyin.isEmpty {
                    Text(PinyinConverter.coloredPinyin(fromPinyin: sentence.pinyin))
                        .font(.caption)
                }

                Text(sentence.translation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                SpeechService.speakAuto(sentence.sentence)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .accessibilityLabel(Text("Read sentence aloud"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private func relatedWordRow(_ word: RelatedWordResult, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(word.word)
                    .font(.body)
                    .fontWeight(.medium)

                if !word.pinyin.isEmpty {
                    Text(word.pinyin)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(word.meaning)
                    .font(.caption)
                    .foregroundStyle(tint)
            }

            if !word.difference.isEmpty {
                Text(word.difference)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func collocationRow(_ collocation: CollocationResult) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(collocation.phrase)
                    .font(.callout)
                    .fontWeight(.medium)

                if !collocation.pinyin.isEmpty {
                    Text(collocation.pinyin)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(collocation.translation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    /// Reconcile the view with the current direction: if a previously shown
    /// explanation belongs to a now-stale direction (interface language flipped),
    /// drop it; then serve this direction's cached explanation if one exists and
    /// nothing fresh is already shown. Safe to call repeatedly.
    private func loadCachedExplanationIfAvailable() {
        // Drop a previously shown explanation belonging to a different word or
        // direction (view reused for another term, or interface language flipped).
        if let shown = shownKey, shown != currentKey {
            explanation = nil
            errorMessage = nil
            servedFromCache = false
            shownProviderName = nil
            shownKey = nil
        }
        guard explanation == nil, !isLoading else { return }
        guard let cached = cache.explanation(forWord: word, directionToken: directionToken) else { return }
        explanation = cached.result
        errorMessage = nil
        servedFromCache = true
        shownProviderName = cached.providerName.isEmpty ? nil : cached.providerName
        shownKey = currentKey
    }

    /// Generate a fresh explanation and persist the result for instant reuse
    /// later. `force` additionally evicts the service's in-memory cache entry
    /// (the "Regenerate"/"Try Again" path) so the model actually re-runs
    /// instead of instantly echoing the previous result back.
    private func generateExplanation(force: Bool = false) async {
        isLoading = true
        errorMessage = nil
        servedFromCache = false

        do {
            // Use the unified provider method that routes to Apple Intelligence or Ollama
            let result = try await aiService.generateExplanationWithProvider(
                for: word,
                pinyin: pinyin,
                context: context,
                bypassCache: force
            )
            explanation = result
            // A freshly generated explanation opens fully expanded so nothing
            // the model produced is hidden behind collapsed sections.
            expandedSections = Self.allSectionIDs
            shownKey = currentKey
            shownProviderName = nil  // fresh result → header shows the current provider
            cache.store(
                word: word,
                pinyin: pinyin,
                directionToken: directionToken,
                providerName: aiSettings.effectiveProvider.displayName,
                result: result
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private extension View {
    /// Conditionally provide the one vertical scroll owner used by the
    /// standalone explanation screen. Embedded explanations expand naturally
    /// inside their parent page's existing ScrollView.
    @ViewBuilder
    func aiExplanationScrollContainer(_ isEnabled: Bool) -> some View {
        if isEnabled {
            ScrollView { self }
        } else {
            self
        }
    }
}

// MARK: - Compact AI Button for List Rows

/// A small button that can be added to vocabulary rows to trigger AI explanation
struct AIExplainButton: View {
    let word: String
    let pinyin: String
    let onTap: () -> Void
    
    @State private var isAvailable: Bool = true
    
    private var provider: AIProvider {
        AIModelSettings.shared.effectiveProvider
    }

    private var providerName: String {
        AIModelSettings.shared.effectiveProvider.displayName
    }

    private var controlSize: CGFloat {
        #if os(iOS)
        44
        #else
        28
        #endif
    }

    var body: some View {
        Button(action: onTap) {
            ProviderIcon(provider: provider, size: 16)
                .foregroundStyle(isAvailable ? .blue : .secondary)
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .help(isAvailable ? "Explain with \(providerName)" : "AI not available")
        .accessibilityLabel(Text("AI Word Analysis"))
        .accessibilityHint(
            Text(isAvailable ? "Explain with \(providerName)" : "AI not available")
        )
        .onAppear {
            // Any configured provider (including cloud ones) enables the
            // button — checking only Apple Intelligence/Ollama wrongly
            // disabled it for cloud-only users.
            isAvailable = AIModelSettings.shared.isAnyProviderAvailable
        }
    }
}

// MARK: - Preview

#Preview {
    AIWordExplanationView(
        word: "学习",
        pinyin: "xuéxí",
        context: nil
    )
    .frame(width: 400, height: 600)
}
