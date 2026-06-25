//
//  LearningCard.swift
//  SwiftMandarin
//
//  Flashcard model for learning with spaced repetition
//

import Foundation
import SwiftUI
import Observation

struct LearningCard: Identifiable, Hashable, Codable {
    let id: String
    let chinese: String
    let english: String
    let pinyin: String?
    let exampleSentence: String?
    let tags: [String]
    let notes: String?
    
    init(chinese: String, english: String, pinyin: String? = nil, exampleSentence: String? = nil, tags: [String] = [], notes: String? = nil) {
        // Namespace built-in cards so their progress never collides with a
        // saved-vocabulary card that happens to share the same headword.
        self.id = "builtin:\(chinese)"
        self.chinese = chinese
        self.english = english
        self.pinyin = pinyin
        self.exampleSentence = exampleSentence
        self.tags = tags
        self.notes = notes
    }

    /// Build a card from a saved vocabulary term, namespacing the id with the
    /// term's stable UUID. This keeps each saved term's spaced-repetition
    /// history distinct — even from a built-in card with the same Chinese word.
    init(from term: SavedTerm) {
        self.id = "vocab:\(term.id.uuidString)"
        self.chinese = term.chineseSide.isEmpty ? term.chinese : term.chineseSide
        self.english = term.englishSide.isEmpty ? term.definition : term.englishSide
        self.pinyin = term.pinyin.isEmpty ? nil : term.pinyin
        self.exampleSentence = nil
        self.tags = ["Vocabulary"]
        self.notes = term.partOfSpeech.isEmpty ? nil : term.partOfSpeech
    }
}

// MARK: - Card Progress (Spaced Repetition)

struct CardProgress: Codable, Identifiable {
    let cardId: String
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var correctCount: Int
    var lastReviewDate: Date?
    var nextReviewDate: Date
    var easeFactor: Double
    /// The most recent scheduling interval, in seconds. Persisted so the
    /// next-review math survives relaunches instead of being re-derived.
    var interval: TimeInterval
    /// Consecutive incorrect reviews; reset to 0 on a correct answer. Tracked
    /// and persisted for spaced-repetition scheduling and analytics.
    var lapse: Int

    var id: String { cardId }

    var accuracy: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount)
    }

    init(cardId: String) {
        self.cardId = cardId
        self.masteryLevel = .new
        self.reviewCount = 0
        self.correctCount = 0
        self.lastReviewDate = nil
        self.nextReviewDate = Date()
        self.easeFactor = 2.5
        self.interval = 0
        self.lapse = 0
    }

    private enum CodingKeys: String, CodingKey {
        case cardId, masteryLevel, reviewCount, correctCount
        case lastReviewDate, nextReviewDate, easeFactor, interval, lapse
    }

    /// Tolerant, migrating decoder: legacy ids (raw Chinese, no namespace) are
    /// promoted to the built-in namespace, and the newer `interval`/`lapse`
    /// fields default cleanly when absent from older saved data. Individual
    /// missing fields fall back to sane defaults rather than failing the whole
    /// decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawCardId = try c.decode(String.self, forKey: .cardId)
        self.cardId = rawCardId.contains(":") ? rawCardId : "builtin:\(rawCardId)"
        self.masteryLevel = (try? c.decode(MasteryLevel.self, forKey: .masteryLevel)) ?? .new
        self.reviewCount = (try? c.decode(Int.self, forKey: .reviewCount)) ?? 0
        self.correctCount = (try? c.decode(Int.self, forKey: .correctCount)) ?? 0
        self.lastReviewDate = (try? c.decodeIfPresent(Date.self, forKey: .lastReviewDate)) ?? nil
        self.nextReviewDate = (try? c.decode(Date.self, forKey: .nextReviewDate)) ?? Date()
        self.easeFactor = (try? c.decode(Double.self, forKey: .easeFactor)) ?? 2.5
        self.interval = (try? c.decodeIfPresent(TimeInterval.self, forKey: .interval)) ?? 0
        self.lapse = (try? c.decodeIfPresent(Int.self, forKey: .lapse)) ?? 0
    }

    mutating func recordReview(correct: Bool, quality: ReviewQuality) {
        let reviewDate = Date()
        let priorReviewDate = lastReviewDate
        let previousInterval = max(
            nextReviewDate.timeIntervalSince(priorReviewDate ?? reviewDate),
            60 * 60 * 24
        )

        reviewCount += 1
        if correct {
            correctCount += 1
            lapse = 0
        } else {
            lapse += 1
        }
        lastReviewDate = reviewDate
        updateMasteryLevel()
        calculateNextReview(
            quality: quality,
            reviewDate: reviewDate,
            previousInterval: previousInterval
        )
        // Persist the freshly-computed interval (time until the next review).
        interval = nextReviewDate.timeIntervalSince(reviewDate)
    }
    
    private mutating func updateMasteryLevel() {
        switch accuracy {
        case 0..<0.3: masteryLevel = .learning
        case 0.3..<0.5: masteryLevel = .learning
        case 0.5..<0.7: masteryLevel = .familiar
        case 0.7..<0.9: masteryLevel = .proficient
        default: masteryLevel = reviewCount >= 5 ? .mastered : .proficient
        }
    }
    
    private mutating func calculateNextReview(
        quality: ReviewQuality,
        reviewDate: Date,
        previousInterval: TimeInterval
    ) {
        let q = Double(quality.rawValue)
        easeFactor = max(1.3, easeFactor + 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))
        
        let interval: TimeInterval
        if quality.rawValue < 3 {
            interval = 60 * 10 // 10 minutes
        } else {
            switch reviewCount {
            case 1: interval = 60 * 60 * 24 // 1 day
            case 2: interval = 60 * 60 * 24 * 6 // 6 days
            default:
                interval = previousInterval * easeFactor
            }
        }
        nextReviewDate = reviewDate.addingTimeInterval(interval)
    }
}

enum MasteryLevel: String, Codable, CaseIterable {
    case new, learning, familiar, proficient, mastered
    
    var label: String {
        rawValue.capitalized
    }
}

enum ReviewQuality: Int, CaseIterable {
    case blackout = 0
    case incorrect = 1
    case difficult = 2
    case hard = 3
    case good = 4
    case easy = 5
}

// MARK: - Learning Deck (Built-in Cards)

enum LearningDeck {
    static let cards: [LearningCard] = [
        LearningCard(chinese: "你好", english: "Hello", exampleSentence: "你好，我是小明。", tags: ["Greeting"]),
        LearningCard(chinese: "谢谢", english: "Thank you", exampleSentence: "谢谢你的帮助。", tags: ["Polite"]),
        LearningCard(chinese: "对不起", english: "Sorry", exampleSentence: "对不起，我迟到了。", tags: ["Polite"]),
        LearningCard(chinese: "没关系", english: "No problem", exampleSentence: "没关系，别担心。", tags: ["Polite"]),
        LearningCard(chinese: "再见", english: "Goodbye", exampleSentence: "再见，明天见！", tags: ["Greeting"]),
        LearningCard(chinese: "请问", english: "Excuse me", exampleSentence: "请问，这是哪里？", tags: ["Travel"]),
        LearningCard(chinese: "多少钱", english: "How much?", exampleSentence: "这个多少钱？", tags: ["Shopping"]),
        LearningCard(chinese: "我想要这个", english: "I want this", exampleSentence: "我想要这个苹果。", tags: ["Shopping"]),
        LearningCard(chinese: "卫生间在哪儿", english: "Where is the restroom?", tags: ["Travel"]),
        LearningCard(chinese: "我叫", english: "My name is...", exampleSentence: "我叫张伟。", tags: ["Intro"]),
        LearningCard(chinese: "你叫什么名字", english: "What's your name?", tags: ["Intro"]),
        LearningCard(chinese: "今天", english: "Today", exampleSentence: "今天天气很好。", tags: ["Time"]),
        LearningCard(chinese: "明天", english: "Tomorrow", exampleSentence: "明天我要去北京。", tags: ["Time"]),
        LearningCard(chinese: "好吃", english: "Delicious", exampleSentence: "这个菜很好吃！", tags: ["Food"]),
        LearningCard(chinese: "我们走吧", english: "Let's go", tags: ["Everyday"]),
    ]
}

// MARK: - Learning Progress Store

@Observable
@MainActor
final class LearningProgressStore {
    static let shared = LearningProgressStore()
    
    private(set) var progress: [String: CardProgress] = [:]
    private(set) var todayReviewedCount: Int = 0
    
    private let storageKey = "learningProgress"
    private let todayCountKey = "todayReviewedCount"
    private let lastResetDateKey = "lastProgressResetDate"
    
    private init() {
        load()
        resetDailyCountIfNeeded()
    }
    
    func getProgress(for cardId: String) -> CardProgress {
        progress[cardId] ?? CardProgress(cardId: cardId)
    }
    
    func recordReview(cardId: String, quality: ReviewQuality) {
        // Roll the daily counter over if the app stayed open past midnight.
        resetDailyCountIfNeeded()
        var cardProgress = getProgress(for: cardId)
        let correct = quality.rawValue >= 3
        cardProgress.recordReview(correct: correct, quality: quality)
        progress[cardId] = cardProgress
        todayReviewedCount += 1
        save()
        // Track activity
        LearningActivityStore.shared.recordReviewCompleted()
    }
    
    func getCardsForReview(from cards: [LearningCard], limit: Int = 20) -> [LearningCard] {
        let now = Date()
        
        let sorted = cards.sorted { card1, card2 in
            let p1 = getProgress(for: card1.id)
            let p2 = getProgress(for: card2.id)
            
            if p1.masteryLevel == .new && p2.masteryLevel != .new { return false }
            if p1.masteryLevel != .new && p2.masteryLevel == .new { return true }
            
            let due1 = p1.nextReviewDate
            let due2 = p2.nextReviewDate
            
            if due1 <= now && due2 > now { return true }
            if due1 > now && due2 <= now { return false }
            
            return due1 < due2
        }
        
        return Array(sorted.prefix(limit))
    }
    
    func getDueCards(from cards: [LearningCard]) -> [LearningCard] {
        let now = Date()
        return cards.filter { card in
            let p = getProgress(for: card.id)
            return p.nextReviewDate <= now || p.masteryLevel == .new
        }
    }
    
    func resetProgress() {
        progress.removeAll()
        todayReviewedCount = 0
        save()
    }
    
    private func resetDailyCountIfNeeded() {
        let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(lastResetDate) {
            todayReviewedCount = 0
            UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
            UserDefaults.standard.set(todayReviewedCount, forKey: todayCountKey)
        }
    }
    
    private func load() {
        if let decoded = PersistentCodableStore.load([String: CardProgress].self, key: storageKey) {
            // Re-key by each entry's (migrated) cardId so legacy plain-text keys
            // become "builtin:<term>" and always agree with the stored cardId.
            progress = Dictionary(
                decoded.values.map { ($0.cardId, $0) },
                uniquingKeysWith: { existing, _ in existing }
            )
        }
        todayReviewedCount = UserDefaults.standard.integer(forKey: todayCountKey)
    }

    private func save() {
        PersistentCodableStore.save(progress, key: storageKey)
        UserDefaults.standard.set(todayReviewedCount, forKey: todayCountKey)
    }
}
