#if STATS_HEATMAP_CHECKS
import Foundation

// Contract checks for per-day mastery accounting in the activity heatmap.
//
// The rule that is easy to get wrong — and impossible to notice by eye once a
// heatmap has months of data in it — is *which day* loses a milestone when a
// word is un-mastered. Un-mastering must refund the day the word was earned on,
// never today, or a user tidying up an old word silently erases a milestone
// they earned this morning. These checks pin that down, along with the legacy
// decode path that keeps existing heatmaps intact.

private struct CheckFailure: Error {
    let message: String
}

// `LearningActivityStore` is main-actor isolated, so unlike the other runners
// in this directory every check here runs on the main actor — including the
// counter, which is shared mutable state.
@MainActor private var checksRun = 0

@MainActor
private func expect<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String
) throws {
    checksRun += 1
    guard actual == expected else {
        throw CheckFailure(message: "\(message): expected \(expected), got \(actual)")
    }
}

@MainActor
private func expectTrue(_ actual: Bool, _ message: String) throws {
    checksRun += 1
    guard actual else {
        throw CheckFailure(message: "\(message): expected true")
    }
}

/// A fixed day well in the past, used as "the day an old word was mastered on".
private func day(_ key: String) throws -> Date {
    guard let date = DailyActivity.keyFormatter.date(from: key) else {
        throw CheckFailure(message: "Could not build a date from \(key)")
    }
    return date
}

@MainActor
private func runChecks() throws {

    // MARK: The score a heatmap cell is shaded by

    let mixed = DailyActivity(
        dateKey: "2024-05-05",
        wordsLearned: 1,
        wordsMastered: 2,
        reviewsCompleted: 3,
        translationsMade: 4,
        questionsGraded: 5
    )
    // 1×3 saved + 2×2 mastered + 3 reviews + 4 translations + 5 graded
    try expect(mixed.activityScore, 19, "Mastering a word counts double a review toward heatmap intensity")

    let masteryOnly = DailyActivity(dateKey: "2024-05-06", wordsMastered: 1)
    try expectTrue(
        masteryOnly.activityScore > 0,
        "A day spent only marking words mastered is an active day (it must hold a streak)"
    )

    // MARK: Existing heatmaps survive the new field

    let legacyPayload = Data("""
    {"dateKey":"2024-05-07","wordsLearned":4,"reviewsCompleted":6,"translationsMade":1,\
    "wordsByPartOfSpeech":{"Noun":4}}
    """.utf8)
    let legacy = try JSONDecoder().decode(DailyActivity.self, from: legacyPayload)
    try expect(legacy.wordsMastered, 0, "A day saved before mastery tracking loads with none")
    try expect(legacy.wordsLearned, 4, "The rest of a pre-existing day is preserved")
    try expect(legacy.activityScore, 19, "A pre-existing day keeps the intensity it always had")

    let roundTripped = try JSONDecoder().decode(
        DailyActivity.self,
        from: try JSONEncoder().encode(mixed)
    )
    try expect(roundTripped.wordsMastered, 2, "Mastery milestones survive the save/load round trip")

    // MARK: Which day a refund lands on
    //
    // Seed the store *before* first touching the singleton, so the past day
    // below exists exactly as a real user's history would.

    let activitiesKey = "learningActivities"
    UserDefaults.standard.removeObject(forKey: activitiesKey)
    UserDefaults.standard.removeObject(forKey: "\(activitiesKey).backup")
    UserDefaults.standard.removeObject(forKey: "longestStreak")

    let earnedOn = try day("2024-05-08")
    let neverTouched = try day("2024-05-09")
    PersistentCodableStore.save(
        ["2024-05-08": DailyActivity(dateKey: "2024-05-08", wordsMastered: 2)],
        key: activitiesKey
    )

    let store = LearningActivityStore.shared
    try expect(store.activity(for: earnedOn).wordsMastered, 2, "A stored day loads its mastery count")
    try expect(store.todayActivity.wordsMastered, 0, "Today starts with no milestones of its own")

    store.recordWordMastered()
    store.recordWordMastered()
    try expect(store.todayActivity.wordsMastered, 2, "Mastering a word credits today")

    // The check this whole file exists for.
    store.undoWordMastered(on: earnedOn)
    try expect(store.activity(for: earnedOn).wordsMastered, 1, "Un-mastering refunds the day the word was earned on")
    try expect(store.todayActivity.wordsMastered, 2, "Un-mastering an old word leaves today's milestones alone")

    // A mis-tap: mastered and un-mastered within the same day nets to nothing.
    store.undoWordMastered(on: Date())
    try expect(store.todayActivity.wordsMastered, 1, "Un-mastering a word earned today refunds today")

    // MARK: A refund can never invent activity

    store.undoWordMastered(on: earnedOn)
    store.undoWordMastered(on: earnedOn)
    try expect(store.activity(for: earnedOn).wordsMastered, 0, "A day cannot be refunded below zero")

    store.undoWordMastered(on: neverTouched)
    try expect(store.activity(for: neverTouched).wordsMastered, 0, "Refunding a day with no history is a no-op")
    try expect(store.activity(for: neverTouched).activityScore, 0, "Refunding a day with no history creates no record")

    try expect(store.totalWordsMastered, 1, "The all-time total follows the per-day counts")
    try expect(store.todayActivity.activityScore, 2, "Today's remaining milestone still shades its cell")
    try expectTrue(store.currentStreak >= 1, "A day of mastering alone keeps the streak alive")

    // The store persists as it goes, and this runner has its own defaults
    // domain (named for the binary, not the app), so clear it rather than
    // leaving a scratch domain behind on every smoke run.
    UserDefaults.standard.removePersistentDomain(
        forName: Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
    )
}

@main
private struct StatsHeatmapChecksRunner {
    @MainActor
    static func main() {
        do {
            try runChecks()
            print("Stats heatmap mastery checks passed (\(checksRun)/\(checksRun))")
        } catch let failure as CheckFailure {
            fputs("Stats heatmap mastery check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("Stats heatmap mastery checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
