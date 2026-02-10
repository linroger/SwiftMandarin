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
    
    @State private var currentCardIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var showingStats: Bool = false
    @State private var studyMode: StudyMode = .all
    @State private var cardSource: CardSource = .builtin
    
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
    
    /// Convert saved terms to learning cards
    private var vocabularyCards: [LearningCard] {
        savedTermsStore.terms.map { term in
            LearningCard(
                chinese: term.chinese,
                english: term.definition,
                exampleSentence: nil,
                tags: ["Vocabulary"],
                notes: term.partOfSpeech.isEmpty ? nil : term.partOfSpeech
            )
        }
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
    
    private var studyCards: [LearningCard] {
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
        guard currentCardIndex < studyCards.count else { return nil }
        return studyCards[currentCardIndex]
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if studyCards.isEmpty {
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
            }
            .onChange(of: studyMode) { _, _ in
                currentCardIndex = 0
                isFlipped = false
            }
            .onChange(of: cardSource) { _, _ in
                currentCardIndex = 0
                isFlipped = false
            }
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
                Text("\(currentCardIndex + 1) of \(studyCards.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let card = currentCard, let progress = learningStore.progress[card.id] {
                    MasteryBadge(level: progress.masteryLevel)
                }
            }
            
            ProgressView(value: Double(currentCardIndex), total: Double(studyCards.count))
                .tint(.blue)
        }
    }
    
    // MARK: - Review Buttons
    
    private func reviewButtons(for card: LearningCard) -> some View {
        HStack(spacing: 12) {
            ForEach([ReviewQuality.blackout, .incorrect, .hard, .good, .easy], id: \.self) { quality in
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
            Text("You've reviewed all \(studyCards.count) cards in this session")
        } actions: {
            Button("Start Over") {
                currentCardIndex = 0
                isFlipped = false
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Actions
    
    private func recordReview(card: LearningCard, quality: ReviewQuality) {
        learningStore.recordReview(cardId: card.id, quality: quality)
        
        withAnimation {
            isFlipped = false
            if currentCardIndex < studyCards.count - 1 {
                currentCardIndex += 1
            } else {
                currentCardIndex = studyCards.count // Trigger completion view
            }
        }
    }
}

// MARK: - Flashcard View

struct FlashcardView: View {
    let card: LearningCard
    @Binding var isFlipped: Bool
    
    var body: some View {
        ZStack {
            // Front of card (Chinese)
            cardFace(isFront: true) {
                VStack(spacing: 16) {
                    Text(card.chinese)
                        .font(.system(size: 72, weight: .medium))
                    
                    Text(PinyinConverter.coloredPinyin(card.chinese))
                        .font(.title2)
                    
                    Button {
                        SpeechService.speakChinese(card.chinese)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.title3)
                    }
                    .buttonStyle(.glass)
                }
            }
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back of card (English)
            cardFace(isFront: false) {
                VStack(spacing: 16) {
                    Text(card.english)
                        .font(.title)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    if let example = card.exampleSentence {
                        Divider()
                        
                        VStack(spacing: 8) {
                            Text(example)
                                .font(.body)
                            
                            Text(PinyinConverter.convert(example))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
            .glassEffect(in: .rect(cornerRadius: 20))
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    HStack {
                        Text("Total Cards")
                        Spacer()
                        Text("\(LearningDeck.cards.count)")
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
}
