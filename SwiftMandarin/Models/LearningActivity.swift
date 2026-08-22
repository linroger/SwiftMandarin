//
//  LearningActivity.swift
//  SwiftMandarin
//
//  Created by Claude on 2025.
//

import Foundation

/// Represents learning activity for a specific day
struct DailyActivity: Codable, Identifiable {
    var id: String { dateKey }
    
    /// Date key in format "yyyy-MM-dd"
    let dateKey: String
    
    /// Number of new vocabulary terms saved on this day
    var wordsLearned: Int

    /// Number of saved terms (single words *and* multi-character phrases —
    /// both are stored as `SavedTerm`) marked mastered on this day.
    ///
    /// Un-mastering gives the count back to the day it was *earned* on rather
    /// than to the day of the undo, so a mis-tap corrects itself and undoing an
    /// old word never eats one of today's milestones — see
    /// `undoWordMastered(on:)`. Deleting a mastered word leaves the day alone,
    /// matching how `wordsLearned` already keeps the day a word was saved.
    var wordsMastered: Int

    /// Number of flashcard reviews completed
    var reviewsCompleted: Int

    /// Number of translations made
    var translationsMade: Int

    /// Number of workbook questions graded this day (Photo-tab grader).
    var questionsGraded: Int

    /// Words learned broken down by part of speech
    var wordsByPartOfSpeech: [String: Int]

    /// Computed total activity score for heatmap intensity.
    /// Mastering a term sits between saving one (3) and a single review (1):
    /// it is a deliberate milestone, but one the user awards themselves.
    var activityScore: Int {
        wordsLearned * 3 + wordsMastered * 2 + reviewsCompleted + translationsMade + questionsGraded
    }
    
    /// The actual date represented by this activity
    var date: Date {
        DailyActivity.keyFormatter.date(from: dateKey) ?? Date()
    }

    /// Formatter for the "yyyy-MM-dd" activity keys. Pinned to the POSIX
    /// locale and the Gregorian calendar so keys never pick up localized
    /// digits or a non-Gregorian system calendar (which would corrupt the
    /// heatmap/streak data). The day boundary intentionally follows the
    /// device's local time zone — a "day" of studying is a local day.
    static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()

    init(dateKey: String, wordsLearned: Int = 0, wordsMastered: Int = 0, reviewsCompleted: Int = 0, translationsMade: Int = 0, questionsGraded: Int = 0, wordsByPartOfSpeech: [String: Int] = [:]) {
        self.dateKey = dateKey
        self.wordsLearned = wordsLearned
        self.wordsMastered = wordsMastered
        self.reviewsCompleted = reviewsCompleted
        self.translationsMade = translationsMade
        self.questionsGraded = questionsGraded
        self.wordsByPartOfSpeech = wordsByPartOfSpeech
    }

    init(date: Date, wordsLearned: Int = 0, wordsMastered: Int = 0, reviewsCompleted: Int = 0, translationsMade: Int = 0, questionsGraded: Int = 0, wordsByPartOfSpeech: [String: Int] = [:]) {
        self.dateKey = DailyActivity.keyFormatter.string(from: date)
        self.wordsLearned = wordsLearned
        self.wordsMastered = wordsMastered
        self.reviewsCompleted = reviewsCompleted
        self.translationsMade = translationsMade
        self.questionsGraded = questionsGraded
        self.wordsByPartOfSpeech = wordsByPartOfSpeech
    }

    enum CodingKeys: String, CodingKey {
        case dateKey, wordsLearned, wordsMastered, reviewsCompleted, translationsMade, questionsGraded, wordsByPartOfSpeech
    }

    // Tolerant decode: `questionsGraded` and `wordsMastered` were added later,
    // so older saved payloads omit them. Defaulting every field (rather than
    // letting a missing key throw) keeps existing heatmap/streak data from
    // being discarded.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = (try? c.decode(String.self, forKey: .dateKey)) ?? DailyActivity.keyFormatter.string(from: Date())
        wordsLearned = (try? c.decode(Int.self, forKey: .wordsLearned)) ?? 0
        wordsMastered = (try? c.decode(Int.self, forKey: .wordsMastered)) ?? 0
        reviewsCompleted = (try? c.decode(Int.self, forKey: .reviewsCompleted)) ?? 0
        translationsMade = (try? c.decode(Int.self, forKey: .translationsMade)) ?? 0
        questionsGraded = (try? c.decode(Int.self, forKey: .questionsGraded)) ?? 0
        wordsByPartOfSpeech = (try? c.decode([String: Int].self, forKey: .wordsByPartOfSpeech)) ?? [:]
    }
}

/// Standard parts of speech categories
enum PartOfSpeechCategory: String, CaseIterable, Codable {
    case noun = "Noun"
    case verb = "Verb"
    case adjective = "Adjective"
    case adverb = "Adverb"
    case pronoun = "Pronoun"
    case preposition = "Preposition"
    case conjunction = "Conjunction"
    case interjection = "Interjection"
    case classifier = "Classifier"
    case particle = "Particle"
    case other = "Other"
    
    /// Map raw part of speech strings to categories
    static func categorize(_ rawPOS: String) -> PartOfSpeechCategory {
        let lower = rawPOS.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if lower.isEmpty { return .other }

        // Chinese POS labels — AI explanations are written in Mandarin when
        // the interface language is 中文, so saved terms carry these values.
        // (形容词/副词 are checked before 名词/动词 so compounds match first;
        // 助动词 intentionally falls through to the 动词 check.)
        if lower.contains("形容词") || lower.contains("形容詞") { return .adjective }
        if lower.contains("副词") || lower.contains("副詞") { return .adverb }
        if lower.contains("代词") || lower.contains("代詞") { return .pronoun }
        if lower.contains("介词") || lower.contains("介詞") { return .preposition }
        if lower.contains("连词") || lower.contains("連詞") { return .conjunction }
        if lower.contains("叹词") || lower.contains("嘆詞") || lower.contains("感叹词") { return .interjection }
        if lower.contains("量词") || lower.contains("量詞") { return .classifier }
        if lower.contains("助词") || lower.contains("助詞") { return .particle }
        if lower.contains("名词") || lower.contains("名詞") { return .noun }
        if lower.contains("动词") || lower.contains("動詞") { return .verb }

        // Match common patterns
        if lower.contains("noun") { return .noun }
        if lower.contains("verb") { return .verb }
        if lower.contains("adj") { return .adjective }
        if lower.contains("adv") { return .adverb }
        if lower.contains("pron") { return .pronoun }
        if lower.contains("prep") { return .preposition }
        if lower.contains("conj") { return .conjunction }
        if lower.contains("interj") { return .interjection }
        if lower.contains("class") || lower.contains("measure") { return .classifier }
        if lower.contains("part") { return .particle }
        
        return .other
    }
    
    /// Human-readable label for charts and legends. The raw values are
    /// persisted in saved activity records and matched against AI output, so
    /// they must stay the English strings above; this separate property is
    /// what display code should read, otherwise the Stats chart legend stays
    /// English in the 中文 interface. Each case spells its key out as a
    /// literal because the catalog extractor cannot follow `rawValue`.
    var displayName: String {
        switch self {
        case .noun: return String(localized: "Noun", bundle: .appLanguage)
        case .verb: return String(localized: "Verb", bundle: .appLanguage)
        case .adjective: return String(localized: "Adjective", bundle: .appLanguage)
        case .adverb: return String(localized: "Adverb", bundle: .appLanguage)
        case .pronoun: return String(localized: "Pronoun", bundle: .appLanguage)
        case .preposition: return String(localized: "Preposition", bundle: .appLanguage)
        case .conjunction: return String(localized: "Conjunction", bundle: .appLanguage)
        case .interjection: return String(localized: "Interjection", bundle: .appLanguage)
        case .classifier: return String(localized: "Classifier", bundle: .appLanguage)
        case .particle: return String(localized: "Particle", bundle: .appLanguage)
        case .other: return String(localized: "Other", bundle: .appLanguage)
        }
    }

    var color: String {
        switch self {
        case .noun: return "blue"
        case .verb: return "green"
        case .adjective: return "orange"
        case .adverb: return "purple"
        case .pronoun: return "pink"
        case .preposition: return "teal"
        case .conjunction: return "indigo"
        case .interjection: return "red"
        case .classifier: return "cyan"
        case .particle: return "mint"
        case .other: return "gray"
        }
    }
}

/// Observable store that tracks and persists daily learning activity
@Observable @MainActor
final class LearningActivityStore {
    static let shared = LearningActivityStore()
    
    private let userDefaultsKey = "learningActivities"
    
    /// Dictionary of date keys to daily activity records
    private(set) var activities: [String: DailyActivity] = [:]
    
    /// Current streak (consecutive days with activity)
    var currentStreak: Int {
        calculateStreak()
    }

    /// Longest streak ever achieved
    private(set) var longestStreak: Int = 0

    /// Today's date key ("yyyy-MM-dd"), exposed as observable state so views
    /// that display "today"-derived values (streak, today's reviews, week
    /// strips) get invalidated when the calendar day rolls over while the app
    /// stays open. `currentStreak` and `todayActivity` already compute against
    /// the *current* date on every read, but @Observable views only re-read
    /// them when some observed state changes — this token is that state.
    /// Views should call `refreshDayRollover()` from `onAppear` / scene-phase
    /// changes and read `dayChangeToken` somewhere in their body.
    private(set) var dayChangeToken: String = DailyActivity.keyFormatter.string(from: Date())

    /// Re-derive `dayChangeToken` from the current date. Cheap and idempotent:
    /// mutates (and therefore invalidates observers) only when the local
    /// calendar day actually changed since the last refresh.
    func refreshDayRollover() {
        let today = dateKey(for: Date())
        if dayChangeToken != today {
            dayChangeToken = today
        }
    }

    /// Activity recorded today (a zeroed record when nothing happened yet).
    /// Always computed against the current date so it never goes stale at
    /// midnight.
    var todayActivity: DailyActivity {
        activity(for: Date())
    }

    /// Convenience: flashcard reviews completed today.
    var reviewsToday: Int {
        todayActivity.reviewsCompleted
    }
    
    /// Total words learned all time
    var totalWordsLearned: Int {
        activities.values.reduce(0) { $0 + $1.wordsLearned }
    }

    /// Total mastery milestones recorded all time. This counts only terms
    /// mastered since per-day mastery tracking shipped, so it can trail
    /// `SavedTermsStore.masteredCount` on an existing library — use that store
    /// for "how many words are mastered", and this for "how much mastering has
    /// the heatmap seen".
    var totalWordsMastered: Int {
        activities.values.reduce(0) { $0 + $1.wordsMastered }
    }

    /// Total reviews completed all time
    var totalReviewsCompleted: Int {
        activities.values.reduce(0) { $0 + $1.reviewsCompleted }
    }
    
    /// Total translations made all time
    var totalTranslationsMade: Int {
        activities.values.reduce(0) { $0 + $1.translationsMade }
    }

    /// Total workbook questions graded all time
    var totalQuestionsGraded: Int {
        activities.values.reduce(0) { $0 + $1.questionsGraded }
    }
    
    private init() {
        loadActivities()
    }
    
    // MARK: - Public Methods
    
    /// Record that a word was learned today with its part of speech
    func recordWordLearned(partOfSpeech: String = "") {
        var activity = todayActivity
        activity.wordsLearned += 1
        
        // Track by part of speech
        let category = PartOfSpeechCategory.categorize(partOfSpeech)
        activity.wordsByPartOfSpeech[category.rawValue, default: 0] += 1
        
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }
    
    /// Record that a saved term (word or phrase) was marked mastered today.
    /// Call this only on a genuine not-mastered → mastered transition;
    /// `SavedTermsStore` is the single caller and guards that.
    func recordWordMastered() {
        var activity = todayActivity
        activity.wordsMastered += 1
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }

    /// Give back a mastery milestone that was recorded on `date`.
    ///
    /// The credit is removed from the day the term was *mastered*, not from
    /// today: un-mastering a word earned last week must not eat one of today's
    /// milestones, and un-mastering a mis-tap from a minute ago must leave
    /// today back where it started. `date` therefore comes from the term's own
    /// `dateMastered`; terms mastered before that field existed carry `nil` and
    /// were never counted, so callers skip the undo entirely for them.
    ///
    /// Days with no record, or with nothing left to give back, are left alone
    /// rather than going negative.
    func undoWordMastered(on date: Date) {
        let key = dateKey(for: date)
        guard var activity = activities[key], activity.wordsMastered > 0 else { return }
        activity.wordsMastered -= 1
        activities[key] = activity
        // Only `longestStreak` is persisted as a high-water mark and it can
        // never grow here, so there is nothing to recompute.
        saveActivities()
    }

    /// Record that a review was completed today
    func recordReviewCompleted() {
        var activity = todayActivity
        activity.reviewsCompleted += 1
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }
    
    /// Record that a translation was made today
    func recordTranslationMade() {
        var activity = todayActivity
        activity.translationsMade += 1
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }

    /// Record that workbook questions were graded today (Photo-tab grader).
    func recordQuestionsGraded(_ count: Int = 1) {
        guard count > 0 else { return }
        var activity = todayActivity
        activity.questionsGraded += count
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }
    
    /// Get activity for a specific date
    func activity(for date: Date) -> DailyActivity {
        let key = dateKey(for: date)
        return activities[key] ?? DailyActivity(dateKey: key)
    }
    
    /// Get activities for the last N days
    func activitiesForLastDays(_ days: Int) -> [DailyActivity] {
        let calendar = Calendar.current
        var result: [DailyActivity] = []
        
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                result.append(activity(for: date))
            }
        }
        
        return result.reversed()
    }
    
    /// Get activities for a specific month
    func activitiesForMonth(year: Int, month: Int) -> [DailyActivity] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let startDate = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startDate) else {
            return []
        }
        
        var result: [DailyActivity] = []
        for day in range {
            components.day = day
            if let date = calendar.date(from: components) {
                result.append(activity(for: date))
            }
        }
        
        return result
    }
    
    /// Get weekly activity totals for the last N weeks
    func weeklyTotals(weeks: Int) -> [(weekStart: Date, total: Int)] {
        let calendar = Calendar.current
        var result: [(weekStart: Date, total: Int)] = []
        
        // Start from the beginning of the current week
        let today = Date()
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart) else {
                continue
            }
            
            var weekTotal = 0
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    weekTotal += activity(for: day).activityScore
                }
            }
            
            result.append((weekStart: weekStart, total: weekTotal))
        }
        
        return result.reversed()
    }
    
    /// Get weekly words by part of speech for the last N weeks
    func weeklyWordsByPOS(weeks: Int) -> [(weekStart: Date, wordsByPOS: [String: Int])] {
        let calendar = Calendar.current
        var result: [(weekStart: Date, wordsByPOS: [String: Int])] = []
        
        let today = Date()
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return []
        }
        
        for weekOffset in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart) else {
                continue
            }
            
            var weekPOS: [String: Int] = [:]
            for dayOffset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    let dayActivity = activity(for: day)
                    for (pos, count) in dayActivity.wordsByPartOfSpeech {
                        weekPOS[pos, default: 0] += count
                    }
                }
            }
            
            result.append((weekStart: weekStart, wordsByPOS: weekPOS))
        }
        
        return result.reversed()
    }
    
    // MARK: - Private Methods
    
    private func dateKey(for date: Date) -> String {
        DailyActivity.keyFormatter.string(from: date)
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        // Check if today has activity; if not, start from yesterday
        let todayKey = dateKey(for: currentDate)
        if let todayActivity = activities[todayKey], todayActivity.activityScore > 0 {
            streak = 1
        } else {
            // Check if yesterday had activity to continue counting
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                return 0
            }
            let yesterdayKey = dateKey(for: yesterday)
            if let yesterdayActivity = activities[yesterdayKey], yesterdayActivity.activityScore > 0 {
                streak = 1
                currentDate = yesterday
            } else {
                return 0
            }
        }
        
        // Count backwards
        while let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) {
            let key = dateKey(for: previousDate)
            if let activity = activities[key], activity.activityScore > 0 {
                streak += 1
                currentDate = previousDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func updateLongestStreak() {
        let current = calculateStreak()
        if current > longestStreak {
            longestStreak = current
            UserDefaults.standard.set(longestStreak, forKey: "longestStreak")
        }
    }
    
    /// Longest run of consecutive active days across the full history.
    /// Recomputed on load (rather than trusted from the cached high-water
    /// mark alone) so a restore/reinstall — where the "longestStreak"
    /// UserDefaults value may be missing or stale while the activity history
    /// itself survived — still reports the true best streak. Single backwards
    /// scan over the active dates sorted newest → oldest.
    private func computeLongestStreak() -> Int {
        let calendar = Calendar.current
        let activeDates = activities.values
            .filter { $0.activityScore > 0 }
            .compactMap { DailyActivity.keyFormatter.date(from: $0.dateKey) }
            .sorted(by: >)
        guard !activeDates.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<activeDates.count {
            // Calendar day-difference (not raw seconds) so DST transitions
            // never break a run. Dates descend, so newer − older == 1 day.
            let gap = calendar.dateComponents([.day], from: activeDates[index], to: activeDates[index - 1]).day ?? 0
            if gap == 1 {
                run += 1
                best = max(best, run)
            } else if gap > 1 {
                run = 1
            }
            // gap == 0 (duplicate key, defensive) extends nothing and resets nothing.
        }
        return best
    }

    private func loadActivities() {
        if let decoded = PersistentCodableStore.load([String: DailyActivity].self, key: userDefaultsKey) {
            activities = decoded
        }
        // Keep the incremental high-water mark, but never report less than
        // what the full history proves (true best streak after restore).
        let stored = UserDefaults.standard.integer(forKey: "longestStreak")
        longestStreak = max(stored, computeLongestStreak())
        if longestStreak > stored {
            UserDefaults.standard.set(longestStreak, forKey: "longestStreak")
        }
    }

    private func saveActivities() {
        PersistentCodableStore.save(activities, key: userDefaultsKey)
    }
}
