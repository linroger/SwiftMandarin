//
//  GetLearningStatsIntent.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

struct GetLearningStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Learning Stats"
    static var description = IntentDescription("Get SwiftMandarin learning stats for a selected time range.")

    @Parameter(title: "Range", default: .last7Days)
    var range: ShortcutStatsRange

    static var parameterSummary: some ParameterSummary {
        Summary("Get learning stats for \(\.$range)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary = LearningStatsSummary(range: range)
        // Siri speaks the dialog, so the numbers go there as one sentence;
        // the line-per-stat text stays the value for Shortcuts to use.
        return .result(value: summary.formatted, dialog: IntentDialog(stringLiteral: summary.spoken))
    }
}

private struct LearningStatsSummary {
    let wordsLearned: Int
    let reviewsCompleted: Int
    let translationsMade: Int
    let streak: Int

    init(range: ShortcutStatsRange) {
        let activityStore = LearningActivityStore.shared
        switch range {
        case .today:
            let today = activityStore.activity(for: Date())
            wordsLearned = today.wordsLearned
            reviewsCompleted = today.reviewsCompleted
            translationsMade = today.translationsMade
        case .last7Days:
            let activities = activityStore.activitiesForLastDays(7)
            wordsLearned = activities.reduce(0) { $0 + $1.wordsLearned }
            reviewsCompleted = activities.reduce(0) { $0 + $1.reviewsCompleted }
            translationsMade = activities.reduce(0) { $0 + $1.translationsMade }
        case .last30Days:
            let activities = activityStore.activitiesForLastDays(30)
            wordsLearned = activities.reduce(0) { $0 + $1.wordsLearned }
            reviewsCompleted = activities.reduce(0) { $0 + $1.reviewsCompleted }
            translationsMade = activities.reduce(0) { $0 + $1.translationsMade }
        case .allTime:
            wordsLearned = activityStore.totalWordsLearned
            reviewsCompleted = activityStore.totalReviewsCompleted
            translationsMade = activityStore.totalTranslationsMade
        }

        streak = activityStore.currentStreak
    }

    /// One spoken sentence for Siri.
    var spoken: String {
        String(
            format: String(localized: "%lld words learned, %lld reviews, %lld translations, and a %lld-day streak.", bundle: .appLanguage),
            Int64(wordsLearned), Int64(reviewsCompleted), Int64(translationsMade), Int64(streak)
        )
    }

    /// Localized line-per-stat summary (follows the in-app language toggle).
    var formatted: String {
        [
            String(localized: "Words learned: \(wordsLearned)", bundle: .appLanguage),
            String(localized: "Reviews: \(reviewsCompleted)", bundle: .appLanguage),
            String(localized: "Translations: \(translationsMade)", bundle: .appLanguage),
            String(localized: "Current streak: \(streak)", bundle: .appLanguage),
        ].joined(separator: "\n")
    }
}
