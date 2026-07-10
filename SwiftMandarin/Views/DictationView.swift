//
//  DictationView.swift
//  SwiftMandarin
//
//  Eight-item listening round: the app speaks the LEARNING-language side of
//  a pooled item (text hidden), the user types what they heard. Chinese
//  answers must match character-for-character after stripping whitespace
//  and punctuation; English answers are compared case-insensitively with
//  punctuation stripped. A character-level diff colors each typed character
//  green (matches) or red (doesn't).
//

import SwiftUI

struct DictationView: View {

    private enum Feedback {
        case none
        case correct
        case incorrect
    }

    // MARK: State

    @State private var items: [PracticeItem] = []
    @State private var currentIndex = 0
    @State private var input = ""
    @State private var feedback: Feedback = .none
    @State private var revealed = false
    @State private var score = 0
    @State private var misses: [PracticeItem] = []
    /// Whether the current item was already counted as a miss (reveal and
    /// skip both mark it; the guard keeps reveal-then-skip from double-counting).
    @State private var missCounted = false
    @State private var roundRecorded = false
    /// Bumped by each `startRound` so the auto-speak task re-fires even when
    /// a fresh round happens to lead with the same item at index 0.
    @State private var roundNumber = 0
    /// Pending auto-advance; cancelled before replacement and on disappear.
    @State private var advanceTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private var isFinished: Bool {
        !items.isEmpty && currentIndex >= items.count
    }

    private var currentItem: PracticeItem? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    // MARK: Body

    var body: some View {
        Group {
            if items.isEmpty {
                SMEmptyState(
                    icon: "ear.and.waveform",
                    titleKey: "Nothing to dictate yet",
                    messageKey: "Save a few vocabulary words and come back for a round."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isFinished {
                summary
            } else if let item = currentItem {
                itemScreen(item)
            }
        }
        .background(SMTheme.pageBackground)
        .navigationTitle("Dictation")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if items.isEmpty { startRound() }
        }
        // Speak each new item automatically as it comes up (also fires for
        // the first item once the round exists).
        .task(id: roundTaskKey) {
            guard let item = currentItem else { return }
            SpeechService.speakAuto(item.promptText)
        }
        .onDisappear {
            advanceTask?.cancel()
            SpeechService.stop()
        }
    }

    /// Re-runs the auto-speak task when the question changes OR a fresh
    /// round replaces the items (index alone stays 0 across restarts).
    private var roundTaskKey: String {
        "\(roundNumber)-\(currentIndex)-\(currentItem?.id ?? "none")"
    }

    // MARK: - Item screen

    private func itemScreen(_ item: PracticeItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    SMProgressBar(
                        progress: Double(currentIndex) / Double(items.count),
                        tint: .orange
                    )
                    Text("Item \(currentIndex + 1) of \(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                playbackCard(item)
                answerCard(item)
            }
            .padding()
        }
    }

    private func playbackCard(_ item: PracticeItem) -> some View {
        SMCard {
            VStack(spacing: 14) {
                Text("Listen, then type what you hear")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 24) {
                    Button {
                        SpeechService.speakAuto(item.promptText)
                    } label: {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.title)
                            .frame(width: 68, height: 68)
                            .background(Color.orange.opacity(0.14), in: Circle())
                            .foregroundStyle(Color.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Play audio"))

                    // "Slow" replay: re-speaks the utterance at a reduced rate
                    // (content-aware voice) so the ear can pick apart each
                    // syllable and tone.
                    Button {
                        SpeechService.speakAutoSlow(item.promptText)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "tortoise.fill")
                                .font(.title3)
                            Text("Slow")
                                .font(.caption2)
                        }
                        .frame(width: 56, height: 56)
                        .background(Color.orange.opacity(0.08), in: Circle())
                        .foregroundStyle(Color.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Replay slowly"))
                }

                if revealed {
                    VStack(spacing: 4) {
                        Text(item.promptText)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .multilineTextAlignment(.center)
                        if item.showsPinyin {
                            Text(PinyinConverter.coloredPinyin(fromPinyin: item.pinyin))
                                .font(.subheadline)
                        }
                        if !item.answerText.isEmpty {
                            Text(item.answerText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func answerCard(_ item: PracticeItem) -> some View {
        SMCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Type what you hear", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .submitLabel(.done)
                    .focused($inputFocused)
                    .onSubmit { check(item) }
                    .disabled(revealed)

                switch feedback {
                case .correct:
                    Label("Correct!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                case .incorrect:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Not quite — try again", systemImage: "xmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                        diffText(expected: item.promptText, typed: input)
                            .font(.system(.title3, design: .monospaced))
                    }
                case .none:
                    EmptyView()
                }

                controls(item)
            }
        }
    }

    @ViewBuilder
    private func controls(_ item: PracticeItem) -> some View {
        if revealed {
            Button {
                advance()
            } label: {
                Text("Next")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            HStack(spacing: 10) {
                Button {
                    check(item)
                } label: {
                    Text("Check")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feedback == .correct)

                Button {
                    reveal(item)
                } label: {
                    Text("Reveal")
                        .frame(maxWidth: .infinity)
                }
                .glassButtonStyleCompat()
                .disabled(feedback == .correct)

                Button {
                    skip(item)
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .glassButtonStyleCompat()
                .disabled(feedback == .correct)
            }
        }
    }

    // MARK: - Diff

    /// Character-level diff of the normalized answer against the normalized
    /// expected text: position-by-position zip, green when the characters
    /// agree, red otherwise; missing tail characters render as red blanks.
    private func diffText(expected: String, typed: String) -> Text {
        let expectedChars = Array(Self.normalized(expected))
        let typedChars = Array(Self.normalized(typed))
        var result = AttributedString()
        for index in 0..<max(expectedChars.count, typedChars.count) {
            if index < typedChars.count {
                let matches = index < expectedChars.count && expectedChars[index] == typedChars[index]
                var piece = AttributedString(String(typedChars[index]))
                piece.foregroundColor = matches ? Color.green : Color.red
                result += piece
            } else {
                var piece = AttributedString("＿")
                piece.foregroundColor = Color.red
                result += piece
            }
        }
        return Text(result)
    }

    // MARK: - Answer checking

    /// Direction-aware normalization: Chinese → strip whitespace/punctuation
    /// and compare characters exactly; English → additionally lowercase and
    /// collapse runs of whitespace.
    static func normalized(_ text: String) -> String {
        if LocalizationManager.shared.learningIsChinese {
            return text.filter { !$0.isWhitespace && !$0.isPunctuation && !$0.isSymbol }
        }
        let cleaned = text.lowercased().filter { !$0.isPunctuation && !$0.isSymbol }
        return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func matches(expected: String, answer: String) -> Bool {
        let normalizedExpected = normalized(expected)
        return !normalizedExpected.isEmpty && normalizedExpected == normalized(answer)
    }

    // MARK: - Round lifecycle

    private func startRound() {
        advanceTask?.cancel()
        items = Array(
            PracticeStore.practicePool()
                .filter { !$0.promptText.isEmpty }
                .shuffled()
                .prefix(8)
        )
        currentIndex = 0
        input = ""
        feedback = .none
        revealed = false
        score = 0
        misses = []
        missCounted = false
        roundRecorded = false
        roundNumber += 1
        inputFocused = true
    }

    private func check(_ item: PracticeItem) {
        guard feedback != .correct, !revealed else { return }
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if Self.matches(expected: item.promptText, answer: input) {
            feedback = .correct
            score += 1
            PracticeHaptics.success()
            advanceTask?.cancel()
            advanceTask = Task {
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
                advance()
            }
        } else {
            // Leave the input editable so the user can fix it and re-check.
            feedback = .incorrect
            PracticeHaptics.error()
        }
    }

    private func reveal(_ item: PracticeItem) {
        guard !revealed else { return }
        revealed = true
        recordMiss(item)
        SpeechService.speakAuto(item.promptText)
    }

    private func skip(_ item: PracticeItem) {
        recordMiss(item)
        advance()
    }

    private func recordMiss(_ item: PracticeItem) {
        guard !missCounted else { return }
        missCounted = true
        misses.append(item)
    }

    private func advance() {
        advanceTask?.cancel()
        input = ""
        feedback = .none
        revealed = false
        missCounted = false
        currentIndex += 1
        if currentIndex >= items.count {
            finishRound()
        } else {
            inputFocused = true
        }
    }

    /// Persist the round exactly once, mirroring QuizView.
    private func finishRound() {
        guard !roundRecorded, !items.isEmpty else { return }
        roundRecorded = true
        PracticeStore.shared.record(
            PracticeSessionResult(mode: .dictation, score: score, total: items.count)
        )
        LearningActivityStore.shared.recordReviewCompleted()
    }

    // MARK: - Summary

    private var summary: some View {
        PracticeRoundSummary(score: score, total: items.count, onPracticeAgain: startRound) {
            if !misses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SMSectionHeader(titleKey: "Listen again")
                    ForEach(misses) { item in
                        missRow(item)
                    }
                }
            }
        }
    }

    private func missRow(_ item: PracticeItem) -> some View {
        SMCard {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.promptText)
                            .font(.headline)
                        if item.showsPinyin {
                            Text(PinyinConverter.coloredPinyin(fromPinyin: item.pinyin))
                                .font(.subheadline)
                        }
                    }
                    if !item.answerText.isEmpty {
                        Text(item.answerText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    SpeechService.speakAuto(item.promptText)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(Text("Play audio"))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DictationView()
    }
    .environment(SavedTermsStore.shared)
}
