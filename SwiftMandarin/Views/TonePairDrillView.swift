//
//  TonePairDrillView.swift
//  SwiftMandarin
//
//  Ten-question tone-perception drill for Mandarin learners: the app speaks
//  a two-character word, shows the characters, and the user picks its tone
//  pattern ("2-3" style) from four options. Every syllable answer feeds the
//  persisted tone-confusion matrix, which powers the "most confused pair"
//  insight on the summary screen. Hidden behind a friendly empty state for
//  中文-UI users (they are learning English — tones aren't their drill).
//

import SwiftUI

struct TonePairDrillView: View {

    // MARK: Round model

    struct ToneQuestion: Identifiable {
        let id = UUID()
        let item: PracticeItem
        /// The word's two tones, each 1–4.
        let tones: [Int]
        /// Four tone patterns to choose from (contains `tones` once).
        let options: [[Int]]
        let correctIndex: Int
    }

    struct Miss: Identifiable {
        let id = UUID()
        let question: ToneQuestion
        let chosen: [Int]
    }

    // MARK: State

    @State private var questions: [ToneQuestion] = []
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var selectedIndex: Int?
    @State private var misses: [Miss] = []
    @State private var roundRecorded = false
    /// Pending auto-advance; cancelled before replacement and on disappear.
    @State private var advanceTask: Task<Void, Never>?

    private var localization: LocalizationManager { .shared }
    private var practiceStore: PracticeStore { .shared }

    private var isFinished: Bool {
        !questions.isEmpty && currentIndex >= questions.count
    }

    private var currentQuestion: ToneQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    // MARK: Body

    var body: some View {
        Group {
            if !localization.learningIsChinese {
                SMEmptyState(
                    icon: "waveform",
                    titleKey: "Tone drills are for Mandarin learners",
                    messageKey: "Tone practice unlocks when you are learning Chinese."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if questions.isEmpty {
                SMEmptyState(
                    icon: "waveform",
                    titleKey: "No tone pairs yet",
                    messageKey: "Save some two-character Mandarin words to unlock tone drills."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isFinished {
                summary
            } else if let question = currentQuestion {
                questionScreen(question)
            }
        }
        .background(SMTheme.pageBackground)
        .navigationTitle("Tone Drills")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if localization.learningIsChinese, questions.isEmpty { startRound() }
        }
        // Speak each new word automatically as it comes up.
        .task(id: currentQuestion?.id) {
            guard let question = currentQuestion else { return }
            SpeechService.speakChinese(question.item.chinese)
        }
        .onDisappear {
            advanceTask?.cancel()
            SpeechService.stop()
        }
    }

    // MARK: - Question screen

    private func questionScreen(_ question: ToneQuestion) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    SMProgressBar(
                        progress: Double(currentIndex) / Double(questions.count),
                        tint: .pink
                    )
                    Text("Question \(currentIndex + 1) of \(questions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                wordCard(question)
                optionGrid(question)
            }
            .padding()
        }
    }

    private func wordCard(_ question: ToneQuestion) -> some View {
        SMCard {
            VStack(spacing: 12) {
                Text("Which tone pattern do you hear?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(question.item.chinese)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                if selectedIndex != nil {
                    Text(PinyinConverter.coloredPinyin(fromPinyin: question.item.pinyin))
                        .font(.title3.weight(.semibold))
                    if !question.item.english.isEmpty {
                        Text(question.item.english)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    SpeechService.speakChinese(question.item.chinese)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .padding(10)
                }
                .glassButtonStyleCompat()
                .accessibilityLabel(Text("Play audio"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private func optionGrid(_ question: ToneQuestion) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(question.options.indices, id: \.self) { index in
                optionChip(question: question, index: index)
            }
        }
    }

    private func optionChip(question: ToneQuestion, index: Int) -> some View {
        let answered = selectedIndex != nil
        let isCorrect = index == question.correctIndex
        let isChosen = index == selectedIndex
        let pattern = question.options[index]

        return Button {
            select(index)
        } label: {
            VStack(spacing: 6) {
                Text(patternLabel(pattern))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                exemplarText(pattern)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                chipFill(answered: answered, isCorrect: isCorrect, isChosen: isChosen),
                in: RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
                    .strokeBorder(
                        chipBorder(answered: answered, isCorrect: isCorrect, isChosen: isChosen),
                        lineWidth: 1.5
                    )
            )
            .opacity(answered && !isCorrect && !isChosen ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .animation(.spring(duration: 0.3), value: selectedIndex)
    }

    private func chipFill(answered: Bool, isCorrect: Bool, isChosen: Bool) -> Color {
        guard answered else { return SMTheme.cardFill }
        if isCorrect { return Color.green.opacity(0.18) }
        if isChosen { return Color.red.opacity(0.15) }
        return SMTheme.cardFill
    }

    private func chipBorder(answered: Bool, isCorrect: Bool, isChosen: Bool) -> Color {
        guard answered else { return .clear }
        if isCorrect { return .green }
        if isChosen { return .red }
        return .clear
    }

    // MARK: - Pattern rendering

    /// "2-3" style label for a tone pattern.
    private func patternLabel(_ pattern: [Int]) -> String {
        pattern.map(String.init).joined(separator: "-")
    }

    /// "má·mǎ" exemplar, each syllable in its tone color.
    private func exemplarText(_ pattern: [Int]) -> Text {
        var result = AttributedString()
        for (index, tone) in pattern.enumerated() {
            if index > 0 {
                var dot = AttributedString("·")
                dot.foregroundColor = Color.secondary
                result += dot
            }
            let toneCase = PinyinConverter.Tone(rawValue: tone) ?? .neutral
            var syllable = AttributedString(Self.exemplars[tone] ?? "ma")
            syllable.foregroundColor = toneCase.color
            result += syllable
        }
        return Text(result)
    }

    /// The classic "ma" demonstration syllable in each of the four tones.
    private static let exemplars: [Int: String] = [1: "mā", 2: "má", 3: "mǎ", 4: "mà"]

    // MARK: - Round lifecycle

    private func startRound() {
        advanceTask?.cancel()
        questions = Self.makeRound(from: PracticeStore.toneDrillPool())
        currentIndex = 0
        score = 0
        selectedIndex = nil
        misses = []
        roundRecorded = false
    }

    private func select(_ index: Int) {
        guard selectedIndex == nil, let question = currentQuestion else { return }
        selectedIndex = index
        let chosen = question.options[index]
        // Feed the confusion matrix per syllable — including correct answers,
        // so per-tone accuracy stays derivable from the diagonal.
        for (expected, heard) in zip(question.tones, chosen) {
            practiceStore.recordToneAnswer(expected: expected, chosen: heard)
        }
        if index == question.correctIndex {
            score += 1
            PracticeHaptics.success()
        } else {
            misses.append(Miss(question: question, chosen: chosen))
            PracticeHaptics.error()
        }
        advanceTask?.cancel()
        advanceTask = Task {
            // Slightly longer than the quiz so the colored pinyin reveal
            // registers before the next word plays.
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        selectedIndex = nil
        currentIndex += 1
        if currentIndex >= questions.count {
            finishRound()
        }
    }

    /// Persist the round exactly once, mirroring QuizView.
    private func finishRound() {
        guard !roundRecorded, !questions.isEmpty else { return }
        roundRecorded = true
        PracticeStore.shared.record(
            PracticeSessionResult(mode: .toneDrill, score: score, total: questions.count)
        )
        LearningActivityStore.shared.recordReviewCompleted()
    }

    // MARK: - Summary

    private var summary: some View {
        PracticeRoundSummary(score: score, total: questions.count, onPracticeAgain: startRound) {
            VStack(alignment: .leading, spacing: 12) {
                if let pair = practiceStore.mostConfusedTonePair {
                    insightCard(pair)
                }
                if !misses.isEmpty {
                    SMSectionHeader(titleKey: "Listen again")
                    ForEach(misses) { miss in
                        missRow(miss)
                    }
                }
            }
        }
    }

    private func insightCard(_ pair: (expected: Int, chosen: Int, count: Int)) -> some View {
        SMCard {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text(String(
                    format: L("You most often hear tone %1$d as tone %2$d — listen for that contrast."),
                    pair.expected, pair.chosen
                ))
                .font(.subheadline)
            }
        }
    }

    private func missRow(_ miss: Miss) -> some View {
        SMCard {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(miss.question.item.chinese)
                            .font(.headline)
                        Text(PinyinConverter.coloredPinyin(fromPinyin: miss.question.item.pinyin))
                            .font(.subheadline)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                        Text(patternLabel(miss.chosen))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text(patternLabel(miss.question.tones))
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                }
                Spacer(minLength: 0)
                Button {
                    SpeechService.speakChinese(miss.question.item.chinese)
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

    // MARK: - Round generation

    /// Build a round of `length` questions from the tone-drill candidates.
    /// A thin candidate list repeats words (avoiding back-to-back repeats
    /// when possible) so the round always has ten listens.
    static func makeRound(from candidates: [PracticeItem], length: Int = 10) -> [ToneQuestion] {
        guard !candidates.isEmpty else { return [] }

        var picked: [PracticeItem] = []
        if candidates.count >= length {
            picked = Array(candidates.shuffled().prefix(length))
        } else {
            var previousID: String?
            for _ in 0..<length {
                let avoidingRepeat = candidates.filter { $0.id != previousID }
                let pick = (avoidingRepeat.isEmpty ? candidates : avoidingRepeat).randomElement()!
                picked.append(pick)
                previousID = pick.id
            }
        }

        return picked.compactMap { item in
            let tones = PracticeStore.tonePattern(fromPinyin: item.pinyin)
            // The pool already filters for two diacritic-marked syllables;
            // re-check here so a stale item can't produce a broken question.
            guard tones.count == 2, tones.allSatisfy({ (1...4).contains($0) }) else { return nil }

            var wrongPatterns: [[Int]] = []
            for first in 1...4 {
                for second in 1...4 where [first, second] != tones {
                    wrongPatterns.append([first, second])
                }
            }
            let options = ([tones] + wrongPatterns.shuffled().prefix(3)).shuffled()
            guard let correctIndex = options.firstIndex(of: tones) else { return nil }
            return ToneQuestion(item: item, tones: tones, options: options, correctIndex: correctIndex)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TonePairDrillView()
    }
    .environment(SavedTermsStore.shared)
}
