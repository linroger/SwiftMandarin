//
//  MenuBarTranslateView.swift
//  SwiftMandarin
//
//  Compact translate panel for the macOS menu bar. The MenuBarExtra scene
//  itself is wired in SwiftMandarinApp; this view is self-contained: it keeps
//  its own state, auto-detects the translation direction from the input's
//  content, and routes through the configured AI provider.
//

#if os(macOS)
import SwiftUI
import AppKit

/// A 320×420 quick-translate panel for the menu bar extra.
/// Direction is detected from content (CJK → English, otherwise → Chinese),
/// so it serves both audiences without a direction toggle.
@MainActor
struct MenuBarTranslateView: View {

    @State private var inputText: String = ""
    @State private var resultText: String = ""
    /// Snapshot of the input the shown result was translated from, so the
    /// save-to-vocabulary pairing can't drift while the user keeps typing.
    @State private var translatedSource: String = ""
    @State private var isTranslating: Bool = false
    @State private var errorMessage: String?
    @State private var translationTask: Task<Void, Never>?
    @State private var showCopiedFeedback: Bool = false

    // Singletons directly (not @Environment): the menu bar panel lives in its
    // own scene and must not depend on injection wiring elsewhere.
    private var aiSettings: AIModelSettings { AIModelSettings.shared }
    private var savedTermsStore: SavedTermsStore { SavedTermsStore.shared }

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sourceIsChinese: Bool { trimmedInput.containsCJK }

    /// Pinyin is a learner aid for reading Chinese — shown under Chinese
    /// results only when the user is learning Chinese (English UI), never as
    /// native furniture for a Mandarin-native user.
    private var showsResultPinyin: Bool {
        resultText.containsCJK && LocalizationManager.shared.learningIsChinese
    }

    /// When the translated pair is a single word, the (chinese, english)
    /// sides for saving; nil for phrases/sentences (the vocabulary list is a
    /// word list, so only single words offer the save action).
    private var saveableTerm: (chinese: String, english: String)? {
        let source = translatedSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = resultText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !result.isEmpty,
              source.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        if source.containsCJK {
            // Chinese has no spaces, so length is the word/sentence signal.
            guard source.count <= 4 else { return nil }
            return (chinese: source, english: result)
        }
        guard result.containsCJK, result.count <= 6 else { return nil }
        return (chinese: result, english: source)
    }

    private var isTermSaved: Bool {
        guard let pair = saveableTerm else { return false }
        return savedTermsStore.contains(chinese: pair.chinese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            TextField("Enter text to translate", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .font(.body)
                .onSubmit { translate() }

            HStack(spacing: 8) {
                Button {
                    translate()
                } label: {
                    Label("Translate", systemImage: "character.bubble")
                        .fitSingleLine()
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedInput.isEmpty || isTranslating)

                if isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                if !inputText.isEmpty || !resultText.isEmpty {
                    Button {
                        clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                    .accessibilityLabel(Text("Clear"))
                }
            }

            if !aiSettings.isAnyProviderAvailable {
                providerHint
            }

            Divider()

            resultArea

            Divider()

            footer
        }
        .padding(12)
        .frame(width: 320, height: 420)
        .localizedSurface()
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Quick Translate")
                .font(.headline)

            Spacer()

            // Auto-detected direction badge (language names stay in their own
            // scripts, recognizable to both audiences).
            Group {
                if trimmedInput.isEmpty {
                    Text("Auto-detect")
                } else {
                    Text(verbatim: sourceIsChinese ? "中文 → English" : "English → 中文")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(.quaternary.opacity(0.6)))
        }
    }

    /// Inline guidance when no AI provider is configured — the panel's only
    /// translation backend, so surface the fix before the user even tries.
    private var providerHint: some View {
        Label {
            Text("No AI provider configured. Add one in SwiftMandarin's AI Settings, or run a local Ollama server.")
                .font(.caption)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.12)))
    }

    @ViewBuilder
    private var resultArea: some View {
        if let errorMessage {
            ScrollView {
                Label {
                    Text(errorMessage)
                        .font(.caption)
                        .textSelection(.enabled)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        } else if isTranslating {
            VStack(spacing: 10) {
                ProgressView()
                Text("Translating…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if resultText.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "character.bubble")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("Translation will appear here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(resultText)
                            .font(.title3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if showsResultPinyin {
                            Text(PinyinConverter.coloredPinyin(resultText))
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                }

                resultActions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var resultActions: some View {
        HStack(spacing: 8) {
            Button {
                ClipboardService.copy(resultText)
                showCopiedFeedback = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    showCopiedFeedback = false
                }
            } label: {
                Label(showCopiedFeedback ? "Copied!" : "Copy",
                      systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    .fitSingleLine()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(showCopiedFeedback ? .green : nil)

            Button {
                SpeechService.speakAuto(resultText)
            } label: {
                Label("Speak", systemImage: "speaker.wave.2")
                    .fitSingleLine()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            if let pair = saveableTerm {
                Button {
                    guard !isTermSaved else { return }
                    savedTermsStore.add(
                        chinese: pair.chinese,
                        pinyin: PinyinConverter.convert(pair.chinese),
                        definition: pair.english,
                        partOfSpeech: ""
                    )
                } label: {
                    Label(isTermSaved ? "Saved" : "Save to Vocabulary",
                          systemImage: isTermSaved ? "bookmark.fill" : "bookmark")
                        .fitSingleLine()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(isTermSaved ? .green : nil)
                .disabled(isTermSaved)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                // `activate(ignoringOtherApps:)` is deprecated on modern
                // macOS; the parameterless form is the supported call.
                NSApp.activate()
            } label: {
                Label("Open SwiftMandarin", systemImage: "arrow.up.forward.app")
                    .fitSingleLine()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            Spacer()

            if aiSettings.isAnyProviderAvailable {
                Text(aiSettings.effectiveProvider.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func translate() {
        let text = trimmedInput
        guard !text.isEmpty, !isTranslating else { return }

        translationTask?.cancel()
        errorMessage = nil
        resultText = ""
        translatedSource = ""
        showCopiedFeedback = false
        isTranslating = true

        let isChinese = text.containsCJK
        translationTask = Task { @MainActor in
            do {
                let translation = try await AIWordExplanationService.shared
                    .translateWithProvider(text, sourceIsChinese: isChinese)
                guard !Task.isCancelled else { return }
                resultText = translation
                translatedSource = text
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isTranslating = false
        }
    }

    private func clear() {
        translationTask?.cancel()
        inputText = ""
        resultText = ""
        translatedSource = ""
        errorMessage = nil
        isTranslating = false
        showCopiedFeedback = false
    }
}

// MARK: - Preview

#Preview {
    MenuBarTranslateView()
}
#endif
