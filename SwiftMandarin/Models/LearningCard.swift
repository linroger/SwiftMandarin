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

// MARK: - SRS Card State

/// FSRS card lifecycle state. `new` cards have never been studied;
/// `learning` cards were just introduced (or failed their first review) and
/// are on short sub-day steps; `review` cards graduated to day-scale
/// intervals; `relearning` cards lapsed out of review and must pass a
/// relearning step to graduate again.
enum SRSState: String, Codable, CaseIterable {
    case new, learning, review, relearning
}

// MARK: - Card Progress (Spaced Repetition)

struct CardProgress: Codable, Identifiable {
    let cardId: String
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var correctCount: Int
    var lastReviewDate: Date?
    var nextReviewDate: Date
    /// Legacy SM-2 ease factor. Scheduling is FSRS-based now, but this stays
    /// populated (via the inverse of the migration mapping below) so older
    /// builds reading the same persisted data keep working.
    var easeFactor: Double
    /// The most recent scheduling interval, in seconds. Persisted so the
    /// next-review math survives relaunches instead of being re-derived.
    var interval: TimeInterval
    /// Consecutive incorrect reviews; reset to 0 on a correct answer. Tracked
    /// and persisted for spaced-repetition scheduling and analytics.
    var lapse: Int
    /// FSRS memory stability in days (time for retrievability to decay to
    /// 90%). `nil` until the card's first FSRS-scheduled review.
    var stability: Double?
    /// FSRS difficulty ∈ [1, 10]. `nil` until the first FSRS review.
    var difficulty: Double?
    /// FSRS lifecycle state. `nil` on data written before the FSRS migration;
    /// treated as `.new` until the next review migrates the card.
    var srsState: SRSState?

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
        self.stability = nil
        self.difficulty = nil
        self.srsState = SRSState.new
    }

    private enum CodingKeys: String, CodingKey {
        case cardId, masteryLevel, reviewCount, correctCount
        case lastReviewDate, nextReviewDate, easeFactor, interval, lapse
        case stability, difficulty, srsState
    }

    /// Tolerant, migrating decoder: legacy ids (raw Chinese, no namespace) are
    /// promoted to the built-in namespace, and the newer FSRS fields
    /// (`stability`/`difficulty`/`srsState`) plus `interval`/`lapse` default
    /// cleanly when absent from older saved data. Individual missing or
    /// malformed fields fall back to sane defaults rather than failing the
    /// whole decode.
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
        self.stability = (try? c.decodeIfPresent(Double.self, forKey: .stability)) ?? nil
        self.difficulty = (try? c.decodeIfPresent(Double.self, forKey: .difficulty)) ?? nil
        // Unknown raw values (from a future build) decode as nil, not a crash.
        self.srsState = (try? c.decodeIfPresent(SRSState.self, forKey: .srsState)) ?? nil
    }

    /// Record a review and reschedule the card with the FSRS-4.5 engine.
    /// `reviewDate` is injectable so `previewIntervals` can simulate all four
    /// grades against the same "now" without mutating real state.
    mutating func recordReview(correct: Bool, quality: ReviewQuality, at reviewDate: Date = Date()) {
        // Bring pre-FSRS cards into the FSRS state space BEFORE the counters
        // change (the migration keys off the *prior* review history).
        migrateLegacySRSStateIfNeeded()

        let grade = SRSGrade(quality: quality)
        let previousState = srsState ?? .new

        reviewCount += 1
        if correct {
            correctCount += 1
            lapse = 0
        } else {
            lapse += 1
        }

        if let currentStability = stability, let currentDifficulty = difficulty {
            // Subsequent review: fold the real elapsed time into
            // retrievability so recalling near the point of forgetting is
            // rewarded with the biggest stability gains (the spacing effect).
            let elapsedSeconds = lastReviewDate.map { reviewDate.timeIntervalSince($0) } ?? 0
            let elapsedDays = max(elapsedSeconds, 0) / SRSEngine.secondsPerDay
            let recall = SRSEngine.retrievability(elapsedDays: elapsedDays, stability: currentStability)
            let newDifficulty = SRSEngine.nextDifficulty(current: currentDifficulty, grade: grade)
            let newStability: Double
            if grade == .again {
                newStability = SRSEngine.stabilityAfterLapse(
                    stability: currentStability,
                    difficulty: newDifficulty,
                    retrievability: recall
                )
            } else {
                newStability = SRSEngine.stabilityAfterRecall(
                    stability: currentStability,
                    difficulty: newDifficulty,
                    retrievability: recall,
                    grade: grade
                )
            }
            stability = newStability
            difficulty = newDifficulty
        } else {
            // First-ever review: seed both memory variables from the grade.
            stability = SRSEngine.initialStability(grade: grade)
            difficulty = SRSEngine.initialDifficulty(grade: grade)
        }

        // Lifecycle transitions: Again keeps (or returns) the card in a
        // (re)learning step; any successful grade promotes it to review.
        switch (previousState, grade) {
        case (.new, .again):
            srsState = .learning
        case (.learning, .again), (.relearning, .again):
            srsState = previousState
        case (.review, .again):
            srsState = .relearning
        default:
            srsState = .review
        }

        // Schedule: Again → the short relearning step; any successful grade →
        // the FSRS interval derived from the new stability.
        let scheduled: TimeInterval
        if grade == .again {
            scheduled = SRSEngine.relearningStepInterval
        } else {
            scheduled = SRSEngine.nextInterval(stability: stability ?? 0.5)
        }

        lastReviewDate = reviewDate
        nextReviewDate = reviewDate.addingTimeInterval(scheduled)
        interval = scheduled

        // Keep the legacy ease factor in sync (inverse of the migration map
        // below) so downgrading to a pre-FSRS build degrades gracefully.
        easeFactor = max(1.3, (11.9 - (difficulty ?? 5.0)) / 2.76)

        updateMasteryLevel()
    }

    /// One-time migration from the legacy SM-2 scheduler into FSRS state,
    /// run lazily the first time an already-reviewed card is graded again.
    ///
    /// Mapping rationale:
    /// - **stability** — FSRS stability is "days until retrievability drops
    ///   to 90%", the same role the legacy interval played, so seed it from
    ///   the last scheduled interval (floored at half a day so sub-day
    ///   learning steps don't produce degenerate stability).
    /// - **difficulty** — SM-2 ease ∈ [1.3, ~3.0] and FSRS difficulty
    ///   ∈ [1, 10] run in opposite directions. The linear map
    ///   D = clamp(11.9 − 2.76·ease, 1, 10) sends the SM-2 default ease 2.5
    ///   to FSRS's default-ish difficulty 5.0 and the SM-2 floor 1.3 to ≈8.3
    ///   (hard), preserving relative ordering across the whole deck.
    private mutating func migrateLegacySRSStateIfNeeded() {
        if srsState == nil && reviewCount == 0 {
            srsState = .new
            return
        }
        guard stability == nil, reviewCount > 0 else { return }
        stability = max(interval / SRSEngine.secondsPerDay, 0.5)
        difficulty = min(max(11.9 - 2.76 * easeFactor, 1.0), 10.0)
        if srsState == nil {
            srsState = interval >= SRSEngine.secondsPerDay
                ? .review
                : (lapse > 0 ? .relearning : .learning)
        }
    }

    /// Mastery derives from the SRS lifecycle plus the scheduled interval —
    /// NOT lifetime accuracy, which never decayed and permanently inflated
    /// after an early streak of correct answers. A review-state card
    /// scheduled ≥ 21 days out with no outstanding lapse is mastered
    /// (Anki's classic "mature" threshold); ≥ 7 days is proficient; shorter
    /// review intervals are familiar; (re)learning cards are learning.
    private mutating func updateMasteryLevel() {
        let intervalDays = interval / SRSEngine.secondsPerDay
        switch srsState ?? .new {
        case .new:
            masteryLevel = .new
        case .learning, .relearning:
            masteryLevel = .learning
        case .review:
            if intervalDays >= 21 && lapse == 0 {
                masteryLevel = .mastered
            } else if intervalDays >= 7 {
                masteryLevel = .proficient
            } else {
                masteryLevel = .familiar
            }
        }
    }
}

enum MasteryLevel: String, Codable, CaseIterable {
    case new, learning, familiar, proficient, mastered

    var label: String {
        switch self {
        case .new: return String(localized: "New", bundle: .appLanguage)
        case .learning: return String(localized: "Learning", bundle: .appLanguage)
        case .familiar: return String(localized: "Familiar", bundle: .appLanguage)
        case .proficient: return String(localized: "Proficient", bundle: .appLanguage)
        case .mastered: return String(localized: "Mastered", bundle: .appLanguage)
        }
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
    /// Brand-new cards first graded today. Counted against
    /// `dailyNewCardLimit` so review sessions introduce new material at a
    /// sustainable pace instead of flooding the future review queue.
    private(set) var newCardsIntroducedToday: Int = 0

    private let storageKey = "learningProgress"
    private let todayCountKey = "todayReviewedCount"
    private let newCardsTodayKey = "newCardsIntroducedToday"
    private let lastResetDateKey = "lastProgressResetDate"
    private let dailyNewCardLimitKey = "dailyNewCardLimit"

    /// User-configurable cap on new cards introduced per day (default 10 —
    /// roughly 60–90 accumulated daily reviews at steady state, a widely
    /// used sustainable default). Stored in UserDefaults so a settings
    /// screen can adjust it without touching this store.
    var dailyNewCardLimit: Int {
        UserDefaults.standard.object(forKey: dailyNewCardLimitKey) as? Int ?? 10
    }

    private init() {
        load()
        resetDailyCountIfNeeded()
    }

    func getProgress(for cardId: String) -> CardProgress {
        progress[cardId] ?? CardProgress(cardId: cardId)
    }

    func recordReview(cardId: String, quality: ReviewQuality) {
        // Roll the daily counters over if the app stayed open past midnight.
        resetDailyCountIfNeeded()
        let isFirstEncounter = progress[cardId] == nil
        var cardProgress = getProgress(for: cardId)
        let correct = quality.rawValue >= 3
        cardProgress.recordReview(correct: correct, quality: quality)
        progress[cardId] = cardProgress
        todayReviewedCount += 1
        if isFirstEncounter {
            newCardsIntroducedToday += 1
        }
        save()
        // Track activity
        LearningActivityStore.shared.recordReviewCompleted()
    }

    /// The interval each grade WOULD schedule if the card were answered right
    /// now — simulated against a copy of the card's progress, so nothing is
    /// persisted. Powers the "Good · 6d" style captions under the review
    /// buttons, which is what makes the scheduler feel trustworthy.
    func previewIntervals(cardId: String) -> [ReviewQuality: TimeInterval] {
        let current = getProgress(for: cardId)
        let now = Date()
        var intervals: [ReviewQuality: TimeInterval] = [:]
        for quality in ReviewQuality.allCases {
            var simulated = current
            simulated.recordReview(correct: quality.rawValue >= 3, quality: quality, at: now)
            intervals[quality] = simulated.interval
        }
        return intervals
    }

    /// Build a review session: every due card first (most overdue first),
    /// then brand-new cards up to whatever remains of today's new-card
    /// budget. Cards with history that aren't due yet are NOT padded in —
    /// an honest queue is what makes the schedule trustworthy.
    func getCardsForReview(from cards: [LearningCard], limit: Int = 20) -> [LearningCard] {
        resetDailyCountIfNeeded()
        let now = Date()
        var due: [(card: LearningCard, dueDate: Date)] = []
        var newCards: [LearningCard] = []
        for card in cards {
            if let p = progress[card.id], p.reviewCount > 0 {
                if p.nextReviewDate <= now {
                    due.append((card, p.nextReviewDate))
                }
            } else {
                newCards.append(card)
            }
        }
        due.sort { $0.dueDate < $1.dueDate }

        var session = due.map(\.card)
        let remainingBudget = max(0, dailyNewCardLimit - newCardsIntroducedToday)
        session.append(contentsOf: newCards.prefix(remainingBudget))
        return Array(session.prefix(limit))
    }

    func getDueCards(from cards: [LearningCard]) -> [LearningCard] {
        let now = Date()
        return cards.filter { card in
            let p = getProgress(for: card.id)
            return p.nextReviewDate <= now || p.masteryLevel == .new
        }
    }

    /// The exact size of the session `getCardsForReview` would build right now:
    /// every card with history that is due, plus new cards only up to whatever
    /// remains of today's new-card budget. This is what the Home and Study
    /// "Review now" badges show, so the badge matches the session the button
    /// starts — and reaching zero genuinely means "all caught up" (the whole
    /// never-studied backlog is NOT counted, which would make the badge read in
    /// the thousands and never clear).
    ///
    /// Read-only (no day-rollover reset) so it is safe to call from a SwiftUI
    /// view body; call `refreshDailyCounters()` from `onAppear`/scene-active to
    /// keep `newCardsIntroducedToday` current across midnight.
    func pendingReviewCount(from cards: [LearningCard]) -> Int {
        let now = Date()
        var dueWithHistory = 0
        var newAvailable = 0
        for card in cards {
            if let p = progress[card.id], p.reviewCount > 0 {
                if p.nextReviewDate <= now { dueWithHistory += 1 }
            } else {
                newAvailable += 1
            }
        }
        let remainingBudget = max(0, dailyNewCardLimit - newCardsIntroducedToday)
        return dueWithHistory + min(remainingBudget, newAvailable)
    }

    /// Force a day-rollover check and surface the current daily counters. UI
    /// that displays `newCardsIntroducedToday` / `todayReviewedCount` (e.g. the
    /// stats sheet) should read through this so the numbers reset at midnight
    /// even when the app stayed open — otherwise the reset only happens on the
    /// next review or session build.
    @discardableResult
    func refreshDailyCounters() -> (reviewed: Int, newIntroduced: Int) {
        resetDailyCountIfNeeded()
        return (todayReviewedCount, newCardsIntroducedToday)
    }

    /// Remove all spaced-repetition history for one card — e.g. when the
    /// saved vocabulary term backing it is deleted.
    func removeProgress(forCardId cardId: String) {
        guard progress.removeValue(forKey: cardId) != nil else { return }
        save()
    }

    func resetProgress() {
        progress.removeAll()
        todayReviewedCount = 0
        newCardsIntroducedToday = 0
        save()
    }

    private func resetDailyCountIfNeeded() {
        let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(lastResetDate) {
            todayReviewedCount = 0
            newCardsIntroducedToday = 0
            UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
            UserDefaults.standard.set(todayReviewedCount, forKey: todayCountKey)
            UserDefaults.standard.set(newCardsIntroducedToday, forKey: newCardsTodayKey)
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
        newCardsIntroducedToday = UserDefaults.standard.integer(forKey: newCardsTodayKey)
    }

    private func save() {
        PersistentCodableStore.save(progress, key: storageKey)
        UserDefaults.standard.set(todayReviewedCount, forKey: todayCountKey)
        UserDefaults.standard.set(newCardsIntroducedToday, forKey: newCardsTodayKey)
    }
}
