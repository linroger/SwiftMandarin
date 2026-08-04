//
//  ReaderView.swift
//  SwiftMandarin
//
//  The Reader library: every pasted, written, or AI-generated text the user
//  is working through, with reading progress and a vocabulary-coverage
//  estimate per text. Tapping a card opens the immersive paragraph-by-
//  paragraph reading session.
//

import SwiftUI

struct ReaderView: View {

    @State private var store = ReaderStore.shared

    /// Pushes the reading session when set (navigationDestination(item:)).
    @State private var selectedText: ReaderText?
    /// A text created inside a sheet, opened once the sheet finishes
    /// dismissing — pushing while the sheet is still up drops the navigation.
    @State private var pendingOpen: ReaderText?

    @State private var showComposeSheet = false
    @State private var showGenerateSheet = false
    @State private var showClipboardEmptyAlert = false

    /// Vocabulary coverage per text id, computed lazily as cards appear so
    /// scrolling never re-segments the same text twice.
    @State private var knownPercent: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if store.texts.isEmpty {
                    emptyState
                } else {
                    libraryList
                }
            }
            .background(SMTheme.pageBackground)
            .navigationTitle("Reader")
            .toolbar { addMenu }
            .navigationDestination(item: $selectedText) { text in
                ReaderSessionView(text: text)
            }
            .sheet(isPresented: $showComposeSheet, onDismiss: openPendingText) {
                ReaderComposeSheet { title, content in
                    addComposedText(title: title, content: content)
                }
                .localizedSurface()
            }
            .sheet(isPresented: $showGenerateSheet, onDismiss: openPendingText) {
                StoryGenerationSheet { generated in
                    pendingOpen = generated
                }
                .localizedSurface()
            }
            .alert("Clipboard Is Empty", isPresented: $showClipboardEmptyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Copy some text first, then try again.")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        SMEmptyState(
            icon: "book.pages",
            titleKey: "Your Reading Library",
            messageKey: "Read anything paragraph by paragraph — tap words for instant help, listen aloud, and see how much you already know.",
            actionKey: "Add Your First Text",
            action: { showComposeSheet = true }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Library list

    /// A List (not a ScrollView) so rows get swipe-to-delete; rows are styled
    /// as free-floating cards on the grouped page background.
    private var libraryList: some View {
        List {
            ForEach(store.texts) { text in
                Button {
                    selectedText = text
                } label: {
                    ReaderTextCard(text: text, knownPercent: knownPercent[text.id])
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.remove(text)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        store.remove(text)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onAppear { updateCoverage(for: text) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Toolbar

    private var addMenu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                Button {
                    showComposeSheet = true
                } label: {
                    Label("Write or Paste Text…", systemImage: "square.and.pencil")
                }
                Button {
                    showGenerateSheet = true
                } label: {
                    Label("Generate a Story…", systemImage: "sparkles")
                }
            } label: {
                Label("Add Text", systemImage: "plus")
            }
        }
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        let pasted = ClipboardService.paste()?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pasted.isEmpty else {
            showClipboardEmptyAlert = true
            return
        }
        let text = store.add(
            title: Self.derivedTitle(from: pasted),
            content: pasted,
            source: .pasted
        )
        selectedText = text
    }

    private func addComposedText(title: String, content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = store.add(
            title: trimmedTitle.isEmpty ? Self.derivedTitle(from: trimmedContent) : trimmedTitle,
            content: trimmedContent,
            source: .written
        )
        pendingOpen = text
    }

    /// Push the reading session for a text created inside a sheet, after the
    /// sheet has fully dismissed.
    private func openPendingText() {
        guard let pending = pendingOpen else { return }
        pendingOpen = nil
        selectedText = pending
    }

    private func updateCoverage(for text: ReaderText) {
        guard knownPercent[text.id] == nil else { return }
        if let pct = ReaderVocabularyCoverage.knownPercent(for: text.content) {
            knownPercent[text.id] = pct
        }
    }

    /// Library texts don't always come with a title (clipboard pastes rarely
    /// do) — fall back to the first line of the content.
    private static func derivedTitle(from content: String) -> String {
        let firstLine = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        guard !firstLine.isEmpty else {
            return String(localized: "Untitled", bundle: .appLanguage)
        }
        return String(firstLine.prefix(60))
    }
}

// MARK: - Library card

private struct ReaderTextCard: View {
    let text: ReaderText
    let knownPercent: Int?

    var body: some View {
        SMCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(text.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    TagChip(text: text.source.label, tint: text.source.tint)
                }

                Text(text.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if text.isChineseContent {
                        Text("\(text.wordCount) characters")
                    } else {
                        Text("\(text.wordCount) words")
                    }
                    if let knownPercent {
                        Text(verbatim: "·")
                        Text("~\(knownPercent)% known")
                    }
                    Spacer(minLength: 8)
                    if text.progressFraction > 0 {
                        Text(verbatim: "\(Int((text.progressFraction * 100).rounded()))%")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                SMProgressBar(progress: text.progressFraction)
            }
        }
    }
}

// MARK: - Source badge styling

private extension ReaderText.Source {
    @MainActor
    var label: String {
        switch self {
        case .pasted: return L("Pasted")
        case .written: return L("Written")
        case .generated: return L("Generated")
        }
    }

    var tint: Color {
        switch self {
        case .pasted: return .blue
        case .written: return .purple
        case .generated: return .orange
        }
    }
}

// MARK: - Compose sheet

/// Title + free-form editor for writing or pasting a longer text.
private struct ReaderComposeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""

    let onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                }
                Section("Text") {
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 220)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Text")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(title, content)
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 440)
        #endif
    }
}

// MARK: - Story generation sheet

/// Level + optional topic → AI-written graded story, saved to the library
/// and opened immediately via the parent's `onGenerated` callback.
private struct StoryGenerationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var level: StoryLevel = .beginner
    @State private var topic = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generationTask: Task<Void, Never>?

    let onGenerated: (ReaderText) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Level") {
                    Picker("Level", selection: $level) {
                        ForEach(StoryLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    TextField("Topic (optional)", text: $topic)
                } footer: {
                    Text("The story reuses words you've already saved, so most of it will feel familiar.")
                }

                if let errorMessage {
                    Section {
                        Label {
                            Text(errorMessage)
                                .font(.footnote)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        generate()
                    } label: {
                        HStack(spacing: 10) {
                            if isGenerating {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Writing your story…")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Story")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isGenerating)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Generate a Story")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isGenerating)
        .onDisappear { generationTask?.cancel() }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 380)
        #endif
    }

    private func generate() {
        generationTask?.cancel()
        errorMessage = nil
        isGenerating = true
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        generationTask = Task {
            do {
                let result = try await StoryGenerationService.shared.generateStory(
                    level: level,
                    topic: trimmedTopic.isEmpty ? nil : trimmedTopic,
                    learningIsChinese: LocalizationManager.shared.learningIsChinese
                )
                guard !Task.isCancelled else { return }
                let text = ReaderStore.shared.add(
                    title: result.title,
                    content: result.body,
                    source: .generated
                )
                isGenerating = false
                onGenerated(text)
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                isGenerating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReaderView()
        .environment(SavedTermsStore.shared)
}
