//
//  LearnView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI

/// Flashcard learning view with FSRS spaced repetition.
///
/// A review session is an honest queue: due cards first (most overdue
/// first) plus today's remaining new-card budget. The four grade buttons
/// show the exact interval each answer would schedule, and a card graded
/// Again re-enters the current session a few cards later — it has to be
/// answered correctly before the session lets it go.
struct LearnView: View {
    @Environment(LearningProgressStore.self) private var learningStore
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(AppRouteStore.self) private var routeStore

    @State private var sessionCards: [LearningCard] = []
    @State private var currentCardIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var showingStats: Bool = false
    @State private var studyMode: StudyMode = .dueForReview
    @State private var cardSource: CardSource = .combined

    // Per-session bookkeeping, reset by `reloadSessionCards()`.
    @State private var sessionDueCount: Int = 0
    @State private var sessionNewCount: Int = 0
    @State private var sessionGradeCount: Int = 0
    @State private var sessionCorrectCount: Int = 0
    @State private var reviewedCardIds: Set<String> = []
    @State private var relearnCardIds: Set<String> = []

    /// The four FSRS grades offered as answer buttons, in escalating order.
    private static let gradeChoices: [ReviewQuality] = [.blackout, .hard, .good, .easy]

    enum CardSource: String, CaseIterable {
        case builtin = "Built-in Deck"
        case vocabulary = "My Vocabulary"
        case combined = "All Cards"
    }

    enum StudyMode: String, CaseIterable {
        case all = "All Cards"
        case dueForReview = "Due for Review"
        case newOnly = "New Cards"
        case difficult = "Difficult"
    }

    /// Convert saved terms to learning cards. Sides are detected by content
    /// because the headword field can hold either language depending on the
    /// learning direction the entry was saved under.
    private var vocabularyCards: [LearningCard] {
        savedTermsStore.terms.map { LearningCard(from: $0) }
    }

    /// All available cards based on source selection
    private var allAvailableCards: [LearningCard] {
        switch cardSource {
        case .builtin:
            return LearningDeck.cards
        case .vocabulary:
            return vocabularyCards
        case .combined:
            return LearningDeck.cards + vocabularyCards
        }
    }

    private var currentCard: LearningCard? {
        guard currentCardIndex < sessionCards.count else { return nil }
        return sessionCards[currentCardIndex]
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessionCards.isEmpty {
                    emptyState
                } else if let card = currentCard {
                    cardStudyView(card: card)
                } else {
                    completionView
                }
            }
            .navigationTitle("Learn")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Section("Card Source") {
                            Picker("Source", selection: $cardSource) {
                                ForEach(CardSource.allCases, id: \.self) { source in
                                    Label(L(source.rawValue), systemImage: source == .vocabulary ? "text.book.closed" : source == .builtin ? "rectangle.stack" : "square.stack.3d.up")
                                        .tag(source)
                                }
                            }
                        }

                        Section("Study Mode") {
                            Picker("Mode", selection: $studyMode) {
                                ForEach(StudyMode.allCases, id: \.self) { mode in
                                    Text(L(mode.rawValue)).tag(mode)
                                }
                            }
                        }

                        Divider()

                        Button {
                            showingStats = true
                        } label: {
                            Label("Statistics", systemImage: "chart.bar")
                        }

                        Button {
                            learningStore.resetProgress()
                            reloadSessionCards()
                        } label: {
                            Label("Reset Progress", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingStats) {
                LearningStatsSheet()
                    .localizedSurface()
            }
            .onChange(of: studyMode) { _, _ in
                reloadSessionCards()
            }
            .onChange(of: cardSource) { _, _ in
                reloadSessionCards()
            }
            .task(id: routeStore.pendingAction?.id) {
                if !applyPendingAction(), sessionCards.isEmpty {
                    reloadSessionCards()
                }
            }
            // Keyboard navigation works on macOS and iOS/iPadOS with hardware keyboard
            .onKeyPress(.leftArrow) {
                goToPreviousCard()
                return .handled
            }
            .onKeyPress(.rightArrow) {
                goToNextCard()
                return .handled
            }
            .onKeyPress(.space) {
                flipCard()
                return .handled
            }
            .onKeyPress(.return) {
                flipCard()
                return .handled
            }
        }
        .focusable()
    }

    // MARK: - Pending Actions

    @discardableResult
    private func applyPendingAction() -> Bool {
        guard let action = routeStore.pendingAction else { return false }
        switch action.kind {
        case .startReview(let mode, let source):
            studyMode = mapStudyMode(mode)
            cardSource = mapCardSource(source)
            reloadSessionCards()
            // Clear only the action this view actually handled, so a camera /
            // screenshot action routed to the Photo tab isn't swallowed here.
            routeStore.clearPendingAction()
            return true
        case .openCameraScanner, .translateScreenshots, .openStudyRoute:
            return false
        }
    }

    private func mapStudyMode(_ raw: String) -> StudyMode {
        switch raw {
        case "due": return .dueForReview
        case "new": return .newOnly
        case "difficult": return .difficult
        default: return .all
        }
    }

    private func mapCardSource(_ raw: String) -> CardSource {
        switch raw {
        case "builtin": return .builtin
        case "vocabulary": return .vocabulary
        default: return .combined
        }
    }

    // MARK: - Session Building

    private func reloadSessionCards() {
        let base = allAvailableCards
        switch studyMode {
        case .dueForReview:
            // The real SRS session: due cards ordered by urgency plus new
            // cards within today's remaining introduction budget.
            sessionCards = learningStore.getCardsForReview(from: base)
        case .all:
            sessionCards = base
        case .newOnly:
            sessionCards = base.filter { (learningStore.progress[$0.id]?.reviewCount ?? 0) == 0 }
        case .difficult:
            sessionCards = base.filter { card in
                guard let p = learningStore.progress[card.id] else { return false }
                return p.masteryLevel == .learning || p.srsState == .relearning || p.lapse > 0
            }
        }
        sessionDueCount = sessionCards.filter { (learningStore.progress[$0.id]?.reviewCount ?? 0) > 0 }.count
        sessionNewCount = sessionCards.count - sessionDueCount
        currentCardIndex = 0
        isFlipped = false
        sessionGradeCount = 0
        sessionCorrectCount = 0
        reviewedCardIds = []
        relearnCardIds = []
    }

    // MARK: - Keyboard Navigation

    private func goToPreviousCard() {
        guard !sessionCards.isEmpty, currentCardIndex > 0 else { return }
        withAnimation {
            isFlipped = false
            currentCardIndex -= 1
        }
    }

    private func goToNextCard() {
        // Clamp at the last card (no wrap-around). Grading — not arrow keys — is
        // what completes a review session; without this clamp a hardware
        // keyboard could skip past a re-inserted relearn card and reach the end
        // with it unpassed, defeating the must-pass relearn queue.
        guard !sessionCards.isEmpty, currentCardIndex < sessionCards.count - 1 else { return }
        withAnimation {
            isFlipped = false
            currentCardIndex += 1
        }
    }

    private func flipCard() {
        guard currentCard != nil else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isFlipped.toggle()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Cards Available", systemImage: "rectangle.on.rectangle.slash")
        } description: {
            if cardSource == .vocabulary && savedTermsStore.terms.isEmpty {
                Text("Save some words from the Translate tab to study them here")
            } else {
                switch studyMode {
                case .all:
                    Text("No flashcards in the deck")
                case .dueForReview:
                    Text("No cards due for review. Great job!")
                case .newOnly:
                    Text("You've seen all available cards")
                case .difficult:
                    Text("No difficult cards to review")
                }
            }
        } actions: {
            if cardSource == .vocabulary && savedTermsStore.terms.isEmpty {
                // No action needed - they need to save words first
            } else if studyMode != .all {
                Button("Study All Cards") {
                    studyMode = .all
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Card Study View

    private func cardStudyView(card: LearningCard) -> some View {
        VStack(spacing: 20) {
            // Progress indicator
            progressHeader

            Spacer()

            // Flashcard
            FlashcardView(card: card, isFlipped: $isFlipped)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isFlipped.toggle()
                    }
                }

            Spacer()

            // Controls
            if isFlipped {
                reviewButtons(for: card)
            } else {
                Text("Tap card to reveal answer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                if studyMode == .dueForReview {
                    Text("\(sessionDueCount) due · \(sessionNewCount) new")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("\(sessionCards.count) cards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                if let card = currentCard {
                    if relearnCardIds.contains(card.id) {
                        // This card was missed earlier in the session and is
                        // back for its must-pass relearn attempt.
                        TagChip(text: L("Relearn"), tint: .red)
                    } else if let progress = learningStore.progress[card.id] {
                        MasteryBadge(level: progress.masteryLevel)
                    }
                }
            }

            SMProgressBar(progress: Double(currentCardIndex) / Double(max(sessionCards.count, 1)))

            HStack {
                Text("\(min(currentCardIndex + 1, sessionCards.count)) of \(sessionCards.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer()
            }
        }
    }

    // MARK: - Review Buttons

    /// Four FSRS grade buttons, each captioned with the exact interval that
    /// grade would schedule — seeing "Good · 6d" vs "Easy · 3w" is what makes
    /// the scheduler feel trustworthy instead of arbitrary.
    private func reviewButtons(for card: LearningCard) -> some View {
        let previews = learningStore.previewIntervals(cardId: card.id)
        return HStack(spacing: 10) {
            ForEach(Self.gradeChoices, id: \.self) { quality in
                gradeButton(for: card, quality: quality, predictedInterval: previews[quality])
            }
        }
    }

    private func gradeButton(for card: LearningCard, quality: ReviewQuality, predictedInterval: TimeInterval?) -> some View {
        Button {
            recordReview(card: card, quality: quality)
        } label: {
            VStack(spacing: 3) {
                Text(quality.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(quality.color)
                    .fitSingleLine()
                if let predictedInterval {
                    Text(SRSEngine.formattedInterval(predictedInterval))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(quality.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Completion View

    /// Session summary: what was accomplished, the streak it fed, and an
    /// honest look at the week ahead so "done for today" means something.
    private var completionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    CelebrationBurst()
                }
                .padding(.top, 24)

                Text("Session Complete!")
                    .font(.title2.bold())

                Text("Great work! Your next reviews are scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    StatTile(
                        icon: "rectangle.stack.fill",
                        iconColor: .blue,
                        value: "\(reviewedCardIds.count)",
                        labelKey: "Cards Reviewed"
                    )
                    StatTile(
                        icon: "target",
                        iconColor: .green,
                        value: sessionAccuracyText,
                        labelKey: "Accuracy"
                    )
                    StatTile(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: "\(LearningActivityStore.shared.currentStreak)",
                        labelKey: "Day Streak"
                    )
                }

                forecastCard

                Button("Start New Session") {
                    reloadSessionCards()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    private var sessionAccuracyText: String {
        guard sessionGradeCount > 0 else { return "—" }
        let percent = Int((Double(sessionCorrectCount) / Double(sessionGradeCount) * 100).rounded())
        return "\(percent)%"
    }

    /// Seven-day due-count forecast so the learner sees tomorrow's workload
    /// shrink as today's session lands.
    private var forecastCard: some View {
        let counts = SRSEngine.reviewForecast(progress: Array(learningStore.progress.values), days: 7)
        let maxCount = max(counts.max() ?? 0, 1)
        return SMCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming Reviews")
                    .font(.headline)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(counts.enumerated()), id: \.offset) { dayOffset, count in
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(dayOffset == 0 ? AnyShapeStyle(SMTheme.heroGradient) : AnyShapeStyle(Color.accentColor.opacity(0.35)))
                                .frame(height: 6 + 50 * CGFloat(count) / CGFloat(maxCount))
                            forecastDayLabel(offset: dayOffset)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func forecastDayLabel(offset: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return Group {
            if offset == 0 {
                Text("Today")
            } else {
                // Weekday abbreviation localizes through the environment locale.
                Text(date, format: .dateTime.weekday(.abbreviated))
            }
        }
        .font(.caption2)
        .foregroundStyle(offset == 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .fitSingleLine()
    }

    // MARK: - Actions

    private func recordReview(card: LearningCard, quality: ReviewQuality) {
        learningStore.recordReview(cardId: card.id, quality: quality)

        sessionGradeCount += 1
        reviewedCardIds.insert(card.id)
        if quality.rawValue >= 3 {
            sessionCorrectCount += 1
            relearnCardIds.remove(card.id)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isFlipped = false
            if quality.rawValue < 3 {
                // In-session relearn queue: a missed card comes back 3–5
                // positions later and must be answered correctly before the
                // session releases it.
                relearnCardIds.insert(card.id)
                let reinsertIndex = min(currentCardIndex + Int.random(in: 3...5), sessionCards.count)
                sessionCards.insert(card, at: reinsertIndex)
            }
            currentCardIndex += 1

            // If advancing would end the session but cards are still awaiting a
            // correct answer (e.g. one was navigated past with arrow keys), jump
            // back to the first still-pending relearn card instead of completing.
            if currentCardIndex >= sessionCards.count, !relearnCardIds.isEmpty,
               let pendingIndex = sessionCards.firstIndex(where: { relearnCardIds.contains($0.id) }) {
                currentCardIndex = pendingIndex
            }
        }
    }
}

// MARK: - Flashcard View

struct FlashcardView: View {
    let card: LearningCard
    @Binding var isFlipped: Bool

    /// The front of the card quizzes the LEARNING language (中文 UI → English
    /// front with English narration; English UI → Chinese front with pinyin
    /// and Mandarin narration). The back reveals the native-language meaning.
    private var learningChinese: Bool { LocalizationManager.shared.learningIsChinese }

    var body: some View {
        ZStack {
            // Front of card — the learning-language side
            cardFace(isFront: true) {
                VStack(spacing: 16) {
                    if learningChinese {
                        Text(card.chinese)
                            .font(.system(size: 72, weight: .medium))

                        // Use stored pinyin if available, otherwise convert
                        if let pinyin = card.pinyin, !pinyin.isEmpty {
                            Text(pinyin)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(PinyinConverter.coloredPinyin(card.chinese))
                                .font(.title2)
                        }
                    } else {
                        Text(card.english)
                            .font(.system(size: 56, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.3)
                    }

                    Button {
                        if learningChinese {
                            SpeechService.speakChinese(card.chinese)
                        } else {
                            SpeechService.speakEnglish(card.english)
                        }
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.title3)
                    }
                    .glassButtonStyleCompat()
                }
            }
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            // Back of card — the native-language meaning
            cardFace(isFront: false) {
                VStack(spacing: 16) {
                    Text(learningChinese ? card.english : card.chinese)
                        .font(.title)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)

                    if let example = card.exampleSentence {
                        Divider()

                        VStack(spacing: 8) {
                            Text(example)
                                .font(.body)

                            // Pinyin is a learner aid; native Chinese readers
                            // don't need it on their own-language side.
                            if learningChinese {
                                Text(PinyinConverter.convert(example))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private func cardFace<Content: View>(isFront: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: 400)
            .padding(24)
            .glassEffectCompat(cornerRadius: 20)
    }
}

// MARK: - Mastery Badge

struct MasteryBadge: View {
    let level: MasteryLevel

    var body: some View {
        Text(level.label)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(level.color)
            )
    }
}

// MARK: - Review Quality Extensions

extension ReviewQuality {
    var label: String {
        switch self {
        case .blackout: return String(localized: "Again")
        case .incorrect: return String(localized: "Wrong")
        case .difficult: return String(localized: "Difficult")
        case .hard: return String(localized: "Hard")
        case .good: return String(localized: "Good")
        case .easy: return String(localized: "Easy")
        }
    }

    var color: Color {
        switch self {
        case .blackout: return .red
        case .incorrect: return .red
        case .difficult: return .orange
        case .hard: return .orange
        case .good: return .green
        case .easy: return .blue
        }
    }
}

// MARK: - Mastery Level Color

extension MasteryLevel {
    var color: Color {
        switch self {
        case .new: return .gray
        case .learning: return .orange
        case .familiar: return .yellow
        case .proficient: return .green
        case .mastered: return .blue
        }
    }
}

// MARK: - Learning Stats Sheet

struct LearningStatsSheet: View {
    @Environment(LearningProgressStore.self) private var learningStore
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    HStack {
                        Text("Total Cards")
                        Spacer()
                        Text("\(LearningDeck.cards.count + savedTermsStore.terms.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Cards Studied")
                        Spacer()
                        Text("\(learningStore.progress.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Total Reviews")
                        Spacer()
                        Text("\(learningStore.progress.values.reduce(0) { $0 + $1.reviewCount })")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("New cards today")
                        Spacer()
                        Text("\(learningStore.newCardsIntroducedToday) / \(learningStore.dailyNewCardLimit)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section("Mastery Breakdown") {
                    ForEach(MasteryLevel.allCases, id: \.self) { level in
                        HStack {
                            MasteryBadge(level: level)
                            Spacer()
                            Text("\(countCards(at: level))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Due for Review") {
                    let dueCount = learningStore.progress.values.filter { $0.nextReviewDate <= Date() }.count
                    HStack {
                        Text("Cards due now")
                        Spacer()
                        Text("\(dueCount)")
                            .foregroundStyle(dueCount > 0 ? .orange : .green)
                    }
                }
            }
            .navigationTitle("Statistics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Roll the daily counters over before showing them: the app can
            // stay open past midnight (especially on macOS), so the reset that
            // otherwise only runs on the next review must be forced here.
            .onAppear { learningStore.refreshDailyCounters() }
        }
    }

    private func countCards(at level: MasteryLevel) -> Int {
        learningStore.progress.values.filter { $0.masteryLevel == level }.count
    }
}

// MARK: - Preview

#Preview {
    LearnView()
        .environment(LearningProgressStore.shared)
        .environment(SavedTermsStore.shared)
        .environment(AppRouteStore.shared)
}
