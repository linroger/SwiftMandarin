//
//  QuizView.swift
//  SwiftMandarin
//
//  Ten-question multiple-choice round over the user's vocabulary
//  (supplemented by the starter deck while the list is small).
//  Direction-aware: the prompt is the LEARNING-language side (Chinese with
//  a pinyin subtitle for Mandarin learners; English for 中文-UI users) and
//  the four answers are native-language glosses.
//

import SwiftUI

struct QuizView: View {

    // MARK: Round model

    struct Question: Identifiable {
        let id = UUID()
        let item: PracticeItem
        let options: [String]
        let correctIndex: Int
    }

    struct Miss: Identifiable {
        let id = UUID()
        let question: Question
        let chosen: String
    }

    // MARK: State

    @State private var questions: [Question] = []
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var selectedIndex: Int?
    @State private var misses: [Miss] = []
    @State private var roundRecorded = false
    /// Pending auto-advance; cancelled before replacement and on disappear.
    @State private var advanceTask: Task<Void, Never>?

    private var isFinished: Bool {
        !questions.isEmpty && currentIndex >= questions.count
    }

    // MARK: Body

    var body: some View {
        Group {
            if questions.isEmpty {
                SMEmptyState(
                    icon: "checklist",
                    titleKey: "Nothing to quiz yet",
                    messageKey: "Save a few vocabulary words and come back for a round."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isFinished {
                summary
            } else {
                questionScreen(questions[currentIndex])
            }
        }
        .background(SMTheme.pageBackground)
        .navigationTitle("Quiz")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if questions.isEmpty { startRound() }
        }
        .onDisappear {
            advanceTask?.cancel()
            SpeechService.stop()
        }
    }

    // MARK: - Question screen

    private func questionScreen(_ question: Question) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    SMProgressBar(
                        progress: Double(currentIndex) / Double(questions.count),
                        tint: .purple
                    )
                    Text("Question \(currentIndex + 1) of \(questions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                promptCard(question.item)

                VStack(spacing: 10) {
                    ForEach(question.options.indices, id: \.self) { index in
                        answerButton(question: question, index: index)
                    }
                }
            }
            .padding()
        }
    }

    private func promptCard(_ item: PracticeItem) -> some View {
        SMCard {
            VStack(spacing: 10) {
                Text(item.promptText)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                if item.showsPinyin {
                    Text(PinyinConverter.coloredPinyin(fromPinyin: item.pinyin))
                        .font(.title3)
                }
                Button {
                    SpeechService.speakAuto(item.promptText)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .padding(10)
                }
                .glassButtonStyleCompat()
                .accessibilityLabel(Text("Play audio"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func answerButton(question: Question, index: Int) -> some View {
        let answered = selectedIndex != nil
        let isCorrect = index == question.correctIndex
        let isChosen = index == selectedIndex

        return Button {
            select(index)
        } label: {
            HStack(spacing: 10) {
                Text(question.options[index])
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if answered, isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if answered, isChosen {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                optionFill(answered: answered, isCorrect: isCorrect, isChosen: isChosen),
                in: RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
                    .strokeBorder(
                        optionBorder(answered: answered, isCorrect: isCorrect, isChosen: isChosen),
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

    private func optionFill(answered: Bool, isCorrect: Bool, isChosen: Bool) -> Color {
        guard answered else { return SMTheme.cardFill }
        if isCorrect { return Color.green.opacity(0.18) }
        if isChosen { return Color.red.opacity(0.15) }
        return SMTheme.cardFill
    }

    private func optionBorder(answered: Bool, isCorrect: Bool, isChosen: Bool) -> Color {
        guard answered else { return .clear }
        if isCorrect { return .green }
        if isChosen { return .red }
        return .clear
    }

    // MARK: - Summary

    private var summary: some View {
        PracticeRoundSummary(score: score, total: questions.count, onPracticeAgain: startRound) {
            if !misses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SMSectionHeader(titleKey: "Review these")
                    ForEach(misses) { miss in
                        missRow(miss)
                    }
                }
            }
        }
    }

    private func missRow(_ miss: Miss) -> some View {
        SMCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(miss.question.item.promptText)
                        .font(.headline)
                    if miss.question.item.showsPinyin {
                        Text(PinyinConverter.coloredPinyin(fromPinyin: miss.question.item.pinyin))
                            .font(.subheadline)
                    }
                    Spacer(minLength: 0)
                    Button {
                        SpeechService.speakAuto(miss.question.item.promptText)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(Text("Play audio"))
                }
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                    Text(miss.chosen)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text(miss.question.options[miss.question.correctIndex])
                        .foregroundStyle(.primary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Round lifecycle

    private func startRound() {
        advanceTask?.cancel()
        questions = Self.makeRound(from: PracticeStore.practicePool())
        currentIndex = 0
        score = 0
        selectedIndex = nil
        misses = []
        roundRecorded = false
    }

    private func select(_ index: Int) {
        guard selectedIndex == nil, currentIndex < questions.count else { return }
        let question = questions[currentIndex]
        selectedIndex = index
        if index == question.correctIndex {
            score += 1
            PracticeHaptics.success()
        } else {
            misses.append(Miss(question: question, chosen: question.options[index]))
            PracticeHaptics.error()
        }
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(for: .seconds(0.9))
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

    /// Persist the round exactly once (guarded so a stray re-entry can't
    /// double-count the activity or the stored result).
    private func finishRound() {
        guard !roundRecorded, !questions.isEmpty else { return }
        roundRecorded = true
        PracticeStore.shared.record(
            PracticeSessionResult(mode: .quiz, score: score, total: questions.count)
        )
        LearningActivityStore.shared.recordReviewCompleted()
    }

    // MARK: - Round generation

    /// Build up to `length` questions: each pairs a prompt with its gloss and
    /// three distractor glosses sampled from other items — same part of
    /// speech preferred, duplicate answer text never allowed. The starter
    /// deck pads the distractor supply when the pool is thin.
    static func makeRound(from pool: [PracticeItem], length: Int = 10) -> [Question] {
        let usable = pool.filter { !$0.promptText.isEmpty && !$0.answerText.isEmpty }
        let roundItems = usable.shuffled().prefix(length)
        let padding = LearningDeck.cards.map { PracticeItem(card: $0) }

        return roundItems.compactMap { item in
            let correct = item.answerText
            var seen: Set<String> = [normalized(correct)]
            var distractors: [String] = []

            let samePOS = usable.filter {
                $0.id != item.id && !$0.partOfSpeech.isEmpty && $0.partOfSpeech == item.partOfSpeech
            }.shuffled()
            let others = usable.filter { $0.id != item.id }.shuffled()

            for candidate in samePOS + others + padding.shuffled() {
                guard distractors.count < 3 else { break }
                let answer = candidate.answerText
                let key = normalized(answer)
                guard !answer.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                distractors.append(answer)
            }
            guard distractors.count == 3 else { return nil }

            let options = (distractors + [correct]).shuffled()
            guard let correctIndex = options.firstIndex(of: correct) else { return nil }
            return Question(item: item, options: options, correctIndex: correctIndex)
        }
    }

    /// Duplicate detection key: distractors that differ only in case or
    /// surrounding whitespace would still give the answer away.
    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QuizView()
    }
    .environment(SavedTermsStore.shared)
}
