//
//  ReaderSessionView.swift
//  SwiftMandarin
//
//  Immersive paragraph-by-paragraph reading. Only the CURRENT paragraph is
//  rendered with the interactive tappable word component (ruby text with
//  pinyin for Chinese material, word chips for English material) — neighbors
//  stay plain text so long articles scroll smoothly. Reading position is
//  persisted per text and restored on open.
//

import SwiftUI

struct ReaderSessionView: View {

    let text: ReaderText

    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var store = ReaderStore.shared

    /// Paragraphs snapshotted once — the content is immutable in-session and
    /// re-splitting a long text on every body evaluation would be wasteful.
    private let paragraphs: [String]

    @State private var currentIndex: Int
    @State private var didAppear = false

    /// On-demand paragraph translations (index → gloss), fetched once each.
    @State private var translationCache: [Int: String] = [:]
    /// Which paragraphs currently show their translation.
    @State private var visibleTranslations: Set<Int> = []
    /// Paragraph a translation request is in flight for (drives the spinner).
    @State private var translatingIndex: Int?
    @State private var translationTask: Task<Void, Never>?
    @State private var errorBanner: String?

    /// Word-analysis cache for English material (index → analyzed words).
    @State private var englishWordsCache: [Int: [AnalyzedEnglishWord]] = [:]

    /// Vocabulary coverage shown in the toolbar, computed once on appear.
    @State private var knownPercent: Int?

    // Word-detail presentation (same pattern as TranslateView / PhotoTranslateView).
    @State private var selectedSegment: RubySegment?
    @State private var selectedEnglishWord: AnalyzedEnglishWord?

    /// Reader body-text size, shared across sessions.
    @AppStorage("readerFontSize") private var fontSize: Double = 21

    private static let minFontSize: Double = 15
    private static let maxFontSize: Double = 33

    /// A text is Chinese-study material when it contains any CJK; otherwise
    /// it is English material for a Mandarin-native learner.
    private var contentIsChinese: Bool { text.isChineseContent }

    init(text: ReaderText) {
        self.text = text
        let paragraphs = text.paragraphs
        self.paragraphs = paragraphs
        // Restore the saved reading position (clamped in case the text model
        // was edited by an older build).
        let restored = min(max(text.lastReadParagraphIndex, 0), max(paragraphs.count - 1, 0))
        _currentIndex = State(initialValue: restored)
    }

    var body: some View {
        Group {
            if paragraphs.isEmpty {
                SMEmptyState(
                    icon: "doc.plaintext",
                    titleKey: "Nothing to Read",
                    messageKey: "This text is empty."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                readerContent
            }
        }
        .background(SMTheme.pageBackground)
        .navigationTitle(text.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { statusToolbar }
        .overlay(alignment: .top) { errorBannerView }
        .onDisappear {
            translationTask?.cancel()
            SpeechService.stop()
        }
        #if os(iOS)
        .sheet(item: $selectedSegment) { segment in
            NavigationStack {
                chineseWordDetail(for: segment)
                    .navigationTitle("Word Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { selectedSegment = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .localizedSurface()
        }
        #else
        .popover(item: $selectedSegment) { segment in
            chineseWordDetail(for: segment)
                .frame(minWidth: 300, minHeight: 350)
                .localizedSurface()
        }
        #endif
        .sheet(item: $selectedEnglishWord) { word in
            EnglishWordDetailSheet(word: word)
                .localizedSurface()
        }
    }

    // MARK: - Reader content

    private var readerContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(paragraphs.indices, id: \.self) { index in
                        paragraphView(index: index)
                            .id(index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) { controlBar }
            .onAppear {
                guard !didAppear else { return }
                didAppear = true
                store.markOpened(id: text.id)
                knownPercent = ReaderVocabularyCoverage.knownPercent(for: text.content)
                prepareEnglishWords(for: currentIndex)
                if currentIndex > 0 {
                    // Defer one runloop turn so the paragraph views exist
                    // before scrolling to the restored position.
                    let target = currentIndex
                    Task { @MainActor in
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
            .onChange(of: currentIndex) { _, newIndex in
                prepareEnglishWords(for: newIndex)
                store.updateProgress(id: text.id, paragraphIndex: newIndex)
                withAnimation(.spring(duration: 0.4)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func paragraphView(index: Int) -> some View {
        if index == currentIndex {
            VStack(alignment: .leading, spacing: 12) {
                interactiveParagraph(index: index)
                translationSection(index: index)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                SMTheme.cardFill,
                in: RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
            )
        } else {
            // Neighbors are plain text: cheap to lay out, and tapping one
            // makes it the current (interactive) paragraph.
            Text(paragraphs[index])
                .font(.system(size: fontSize))
                .lineSpacing(6)
                .foregroundStyle(index < currentIndex ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(duration: 0.35)) {
                        currentIndex = index
                    }
                }
        }
    }

    /// The current paragraph, rendered with the tappable word component for
    /// the material's language.
    @ViewBuilder
    private func interactiveParagraph(index: Int) -> some View {
        if contentIsChinese {
            RubyTextView(chineseText: paragraphs[index]) { segment in
                selectedSegment = segment
            }
        } else {
            EnglishRubyTextView(
                words: englishWordsCache[index] ?? [],
                showTranslations: false
            ) { word in
                selectedEnglishWord = word
            }
        }
    }

    @ViewBuilder
    private func translationSection(index: Int) -> some View {
        if translatingIndex == index {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Translating…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if visibleTranslations.contains(index), let translation = translationCache[index] {
            VStack(alignment: .leading, spacing: 4) {
                Text("Translation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(translation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.accentColor.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
    }

    // MARK: - Control bar

    private var controlBar: some View {
        HStack(spacing: 2) {
            controlButton(
                icon: "speaker.wave.2.fill",
                labelKey: "Read Aloud"
            ) {
                SpeechService.speakAuto(paragraphs[currentIndex])
            }
            controlButton(
                icon: "chevron.up",
                labelKey: "Previous Paragraph",
                isDisabled: currentIndex == 0
            ) {
                currentIndex = max(currentIndex - 1, 0)
            }
            controlButton(
                icon: "chevron.down",
                labelKey: "Next Paragraph",
                isDisabled: currentIndex >= paragraphs.count - 1
            ) {
                currentIndex = min(currentIndex + 1, paragraphs.count - 1)
            }
            controlButton(
                icon: "translate",
                labelKey: "Translate Paragraph",
                isActive: visibleTranslations.contains(currentIndex)
            ) {
                toggleTranslation()
            }
            controlButton(
                icon: "textformat.size.smaller",
                labelKey: "Smaller Text",
                isDisabled: fontSize <= Self.minFontSize
            ) {
                fontSize = max(fontSize - 2, Self.minFontSize)
            }
            controlButton(
                icon: "textformat.size.larger",
                labelKey: "Larger Text",
                isDisabled: fontSize >= Self.maxFontSize
            ) {
                fontSize = min(fontSize + 2, Self.maxFontSize)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffectCapsuleCompat()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        icon: String,
        labelKey: LocalizedStringKey,
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .frame(width: 40, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .accessibilityLabel(Text(labelKey))
    }

    // MARK: - Toolbar status

    private var statusToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 10) {
                if let knownPercent {
                    Text("\(knownPercent)% known")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !paragraphs.isEmpty {
                    Text(verbatim: "\(currentIndex + 1)/\(paragraphs.count)")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Error banner

    @ViewBuilder
    private var errorBannerView: some View {
        if let message = errorBanner {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    withAnimation { errorBanner = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Dismiss"))
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Word detail (Chinese material)

    /// Same detail presentation as TranslateView: the popover resolves the
    /// full word info and offers narration/copy/save.
    private func chineseWordDetail(for segment: RubySegment) -> some View {
        WordDetailPopover(
            segment: segment,
            contextTranslation: translationCache[currentIndex] ?? "",
            onSave: { definition in
                let term = SavedTerm(
                    chinese: segment.text,
                    pinyin: segment.pinyin,
                    definition: definition,
                    partOfSpeech: segment.partOfSpeech.rawValue
                )
                if !savedTermsStore.contains(chinese: segment.text) {
                    savedTermsStore.add(term)
                }
            },
            onCopy: {},
            onDismiss: { selectedSegment = nil }
        )
    }

    // MARK: - Actions

    /// Analyze the paragraph's English words once, so the interactive chips
    /// render instantly when a paragraph becomes current again.
    private func prepareEnglishWords(for index: Int) {
        guard !contentIsChinese,
              paragraphs.indices.contains(index),
              englishWordsCache[index] == nil else { return }
        englishWordsCache[index] = EnglishTextAnalyzer.shared.analyzeWords(paragraphs[index])
    }

    /// Toggle the current paragraph's translation: hide if shown, show the
    /// cached gloss if we have it, otherwise fetch it from the AI provider.
    private func toggleTranslation() {
        let index = currentIndex
        if visibleTranslations.contains(index) {
            visibleTranslations.remove(index)
            return
        }
        visibleTranslations.insert(index)
        guard translationCache[index] == nil else { return }

        let paragraph = paragraphs[index]
        let sourceIsChinese = contentIsChinese
        translationTask?.cancel()
        // A cancelled in-flight fetch leaves its paragraph with no gloss —
        // untoggle it so the toggle state matches what is actually shown.
        if let inFlight = translatingIndex, inFlight != index, translationCache[inFlight] == nil {
            visibleTranslations.remove(inFlight)
        }
        translatingIndex = index
        translationTask = Task {
            do {
                let translation = try await AIWordExplanationService.shared
                    .translateWithProvider(paragraph, sourceIsChinese: sourceIsChinese)
                guard !Task.isCancelled else { return }
                translationCache[index] = translation
            } catch {
                guard !Task.isCancelled else { return }
                visibleTranslations.remove(index)
                withAnimation {
                    errorBanner = error.localizedDescription
                }
            }
            if translatingIndex == index {
                translatingIndex = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReaderSessionView(
            text: ReaderText(
                title: "小猫的一天",
                content: "小猫早上起床了。它很饿。\n\n它去厨房找吃的。妈妈给它一条鱼。\n\n吃完饭，小猫去公园玩。它看到很多朋友。",
                source: .generated
            )
        )
    }
    .environment(SavedTermsStore.shared)
}
