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
    
    /// Number of flashcard reviews completed
    var reviewsCompleted: Int
    
    /// Number of translations made
    var translationsMade: Int
    
    /// Words learned broken down by part of speech
    var wordsByPartOfSpeech: [String: Int]
    
    /// Computed total activity score for heatmap intensity
    var activityScore: Int {
        wordsLearned * 3 + reviewsCompleted + translationsMade
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

    init(dateKey: String, wordsLearned: Int = 0, reviewsCompleted: Int = 0, translationsMade: Int = 0, wordsByPartOfSpeech: [String: Int] = [:]) {
        self.dateKey = dateKey
        self.wordsLearned = wordsLearned
        self.reviewsCompleted = reviewsCompleted
        self.translationsMade = translationsMade
        self.wordsByPartOfSpeech = wordsByPartOfSpeech
    }

    init(date: Date, wordsLearned: Int = 0, reviewsCompleted: Int = 0, translationsMade: Int = 0, wordsByPartOfSpeech: [String: Int] = [:]) {
        self.dateKey = DailyActivity.keyFormatter.string(from: date)
        self.wordsLearned = wordsLearned
        self.reviewsCompleted = reviewsCompleted
        self.translationsMade = translationsMade
        self.wordsByPartOfSpeech = wordsByPartOfSpeech
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
    
    /// Total words learned all time
    var totalWordsLearned: Int {
        activities.values.reduce(0) { $0 + $1.wordsLearned }
    }
    
    /// Total reviews completed all time
    var totalReviewsCompleted: Int {
        activities.values.reduce(0) { $0 + $1.reviewsCompleted }
    }
    
    /// Total translations made all time
    var totalTranslationsMade: Int {
        activities.values.reduce(0) { $0 + $1.translationsMade }
    }
    
    private init() {
        loadActivities()
    }
    
    // MARK: - Public Methods
    
    /// Record that a word was learned today with its part of speech
    func recordWordLearned(partOfSpeech: String = "") {
        var activity = todayActivity()
        activity.wordsLearned += 1
        
        // Track by part of speech
        let category = PartOfSpeechCategory.categorize(partOfSpeech)
        activity.wordsByPartOfSpeech[category.rawValue, default: 0] += 1
        
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }
    
    /// Record that a review was completed today
    func recordReviewCompleted() {
        var activity = todayActivity()
        activity.reviewsCompleted += 1
        activities[activity.dateKey] = activity
        updateLongestStreak()
        saveActivities()
    }
    
    /// Record that a translation was made today
    func recordTranslationMade() {
        var activity = todayActivity()
        activity.translationsMade += 1
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
    
    private func todayActivity() -> DailyActivity {
        let key = dateKey(for: Date())
        return activities[key] ?? DailyActivity(dateKey: key)
    }
    
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
    
    private func loadActivities() {
        if let decoded = PersistentCodableStore.load([String: DailyActivity].self, key: userDefaultsKey) {
            activities = decoded
        }
        longestStreak = UserDefaults.standard.integer(forKey: "longestStreak")
    }

    private func saveActivities() {
        PersistentCodableStore.save(activities, key: userDefaultsKey)
    }
}
