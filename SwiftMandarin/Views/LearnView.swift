//
//  LearnView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI

/// Flashcard learning view with spaced repetition
struct LearnView: View {
    @Environment(LearningProgressStore.self) private var learningStore
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(AppRouteStore.self) private var routeStore
    
    @State private var sessionCards: [LearningCard] = []
    @State private var currentCardIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var showingStats: Bool = false
    @State private var studyMode: StudyMode = .all
    @State private var cardSource: CardSource = .combined
    
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
    
    private var filteredStudyCards: [LearningCard] {
        let baseCards = allAvailableCards
        
        switch studyMode {
        case .all:
            return baseCards
        case .dueForReview:
            return baseCards.filter { card in
                if let progress = learningStore.progress[card.id] {
                    return progress.nextReviewDate <= Date()
                }
                return false
            }
        case .newOnly:
            return baseCards.filter { card in
                learningStore.progress[card.id] == nil
            }
        case .difficult:
            return baseCards.filter { card in
                if let progress = learningStore.progress[card.id] {
                    return progress.masteryLevel == .learning || progress.masteryLevel == .new
                }
                return false
            }
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
                                    Label(source.rawValue, systemImage: source == .vocabulary ? "text.book.closed" : source == .builtin ? "rectangle.stack" : "square.stack.3d.up")
                                        .tag(source)
                                }
                            }
                        }
                        
                        Section("Study Mode") {
                            Picker("Mode", selection: $studyMode) {
                                ForEach(StudyMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
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
                            currentCardIndex = 0
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
        case .openCameraScanner, .translateScreenshots:
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

    private func reloadSessionCards() {
        // For a review session, run the due cards through the spaced-repetition
        // scheduler so they're ordered by urgency and capped at a sensible
        // session size; other study modes keep their full filtered list.
        if studyMode == .dueForReview {
            sessionCards = learningStore.getCardsForReview(from: filteredStudyCards)
        } else {
            sessionCards = filteredStudyCards
        }
        currentCardIndex = 0
        isFlipped = false
    }

    // MARK: - Keyboard Navigation
    
    private func goToPreviousCard() {
        guard !sessionCards.isEmpty else { return }
        withAnimation {
            isFlipped = false
            if currentCardIndex > 0 {
                currentCardIndex -= 1
            } else {
                currentCardIndex = sessionCards.count - 1 // Wrap to last card
            }
        }
    }
    
    private func goToNextCard() {
        guard !sessionCards.isEmpty else { return }
        withAnimation {
            isFlipped = false
            if currentCardIndex < sessionCards.count - 1 {
                currentCardIndex += 1
            } else {
                currentCardIndex = 0 // Wrap to first card
            }
        }
    }
    
    private func flipCard() {
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
                Text("\(min(currentCardIndex + 1, sessionCards.count)) of \(sessionCards.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let card = currentCard, let progress = learningStore.progress[card.id] {
                    MasteryBadge(level: progress.masteryLevel)
                }
            }
            
            ProgressView(value: Double(min(currentCardIndex + 1, sessionCards.count)), total: Double(max(sessionCards.count, 1)))
                .tint(.blue)
        }
    }
    
    // MARK: - Review Buttons
    
    private func reviewButtons(for card: LearningCard) -> some View {
        HStack(spacing: 12) {
            ForEach([ReviewQuality.blackout, .incorrect, .difficult, .hard, .good, .easy], id: \.self) { quality in
                Button {
                    recordReview(card: card, quality: quality)
                } label: {
                    VStack(spacing: 4) {
                        Text(quality.emoji)
                            .font(.title2)
                        Text(quality.label)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(quality.color.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        ContentUnavailableView {
            Label("Session Complete!", systemImage: "checkmark.circle")
        } description: {
            Text("You've reviewed all \(sessionCards.count) cards in this session")
        } actions: {
            Button("Start Over") {
                reloadSessionCards()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Actions
    
    private func recordReview(card: LearningCard, quality: ReviewQuality) {
        learningStore.recordReview(cardId: card.id, quality: quality)
        
        withAnimation {
            isFlipped = false
            if currentCardIndex < sessionCards.count - 1 {
                currentCardIndex += 1
            } else {
                currentCardIndex = sessionCards.count // Trigger completion view
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
        Text(level.rawValue.capitalized)
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
    var emoji: String {
        switch self {
        case .blackout: return "❌"
        case .incorrect: return "😕"
        case .difficult: return "😐"
        case .hard: return "🤔"
        case .good: return "🙂"
        case .easy: return "😄"
        }
    }
    
    var label: String {
        switch self {
        case .blackout: return "Again"
        case .incorrect: return "Wrong"
        case .difficult: return "Difficult"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
    
    var color: Color {
        switch self {
        case .blackout: return .red
        case .incorrect: return .orange
        case .difficult: return .yellow
        case .hard: return .mint
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
