//
//  SRSEngine.swift
//  SwiftMandarin
//
//  Pure FSRS-4.5 spaced-repetition scheduler.
//
//  FSRS (Free Spaced Repetition Scheduler) models a card as three numbers:
//    - Difficulty D ∈ [1, 10]  — how hard the material is for this user.
//    - Stability  S (days)     — how long the memory lasts: the number of days
//                                until retrievability decays to 90%.
//    - Retrievability R ∈ (0,1] — probability of successful recall right now.
//  Every review updates D and S from the answer grade and the elapsed time,
//  and the next interval is chosen so R will have decayed to the desired
//  retention (default 90%) when the card comes back.
//
//  All formulas below are the published FSRS-4.5 definitions from the
//  open-spaced-repetition project, using its 17 default model weights.
//  Everything in this file is nonisolated, deterministic, and dependency-free
//  (Foundation only) so it can be unit-tested and called from any context.
//

import Foundation

// MARK: - Grades

/// The four FSRS answer grades. Raw values match the FSRS papers
/// (1 = again … 4 = easy) so the formulas can use `rawValue` directly.
nonisolated enum SRSGrade: Int, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    /// Map the app's six-point `ReviewQuality` scale onto FSRS's four grades:
    /// 0/1/2 (blackout / incorrect / difficult) → again, 3 → hard,
    /// 4 → good, 5 → easy.
    init(quality: ReviewQuality) {
        switch quality {
        case .blackout, .incorrect, .difficult: self = .again
        case .hard: self = .hard
        case .good: self = .good
        case .easy: self = .easy
        }
    }
}

// MARK: - Parameters

/// The FSRS-4.5 model weights plus the fixed forgetting-curve shape constants.
nonisolated struct SRSParameters {
    /// w0…w16 — the 17 published FSRS-4.5 default weights
    /// (open-spaced-repetition/fsrs4anki v4.5), fitted on hundreds of
    /// millions of real reviews:
    ///   w0–w3  initial stability per first grade (again/hard/good/easy)
    ///   w4,w5  initial difficulty (base and per-grade slope)
    ///   w6,w7  difficulty update step and mean-reversion weight
    ///   w8–w10 stability growth after successful recall
    ///   w11–w14 post-lapse stability
    ///   w15    hard-answer penalty, w16 easy-answer bonus
    let w: [Double]

    /// Forgetting-curve decay exponent. Fixed at −0.5 in FSRS-4.5.
    let decay: Double

    /// Curve scale factor, defined as 0.9^(1/decay) − 1 = 19/81 so that
    /// R(t = S, S) is exactly 0.9 — i.e. stability *is* the 90%-retention
    /// interval by construction.
    let factor: Double

    init(w: [Double] = [
        0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031,
        1.6474, 0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755
    ]) {
        precondition(w.count == 17, "FSRS-4.5 requires exactly 17 weights")
        self.w = w
        self.decay = -0.5
        self.factor = 19.0 / 81.0
    }

    /// The published FSRS-4.5 defaults.
    static var standard: SRSParameters { SRSParameters() }
}

// MARK: - Engine

/// Stateless FSRS-4.5 math. Callers (see `CardProgress.recordReview`) own the
/// card state machine; this type only computes the model quantities.
nonisolated struct SRSEngine {

    /// One day in seconds — the engine's native time unit is days, the app's
    /// persisted intervals are seconds.
    static let secondsPerDay: TimeInterval = 86_400

    /// Fixed (re)learning step used when a card is graded Again: FSRS proper
    /// schedules in whole days, so sub-day relearning uses a short fixed step
    /// (the classic 10-minute Anki learning step) before the card graduates
    /// back to day-scale intervals.
    static var relearningStepInterval: TimeInterval { 10 * 60 }

    // MARK: Initial state (first review)

    /// Initial stability by first grade:  S0(G) = w[G−1].
    /// (again → w0 ≈ 0.49d, hard → w1 ≈ 1.4d, good → w2 ≈ 3.7d,
    /// easy → w3 ≈ 13.8d.) Floored at 0.1 day like the reference scheduler.
    static func initialStability(grade: SRSGrade, parameters: SRSParameters = .standard) -> Double {
        max(parameters.w[grade.rawValue - 1], 0.1)
    }

    /// Initial difficulty by first grade:  D0(G) = w4 − (G − 3)·w5,
    /// clamped to [1, 10]. Good (G = 3) lands exactly on w4 ≈ 5.16; harder
    /// first answers start the card at higher difficulty.
    static func initialDifficulty(grade: SRSGrade, parameters: SRSParameters = .standard) -> Double {
        clampDifficulty(parameters.w[4] - Double(grade.rawValue - 3) * parameters.w[5])
    }

    // MARK: Difficulty update

    /// Difficulty after a review, with mean reversion:
    ///   D′ = w7·D0(good) + (1 − w7)·(D − w6·(G − 3)),  clamped to [1, 10].
    /// The first term slowly pulls every card back toward the default
    /// difficulty so early misgrades don't pin a card at an extreme forever;
    /// the second term nudges difficulty down for easy answers and up for
    /// hard/again answers.
    static func nextDifficulty(current: Double, grade: SRSGrade, parameters: SRSParameters = .standard) -> Double {
        let nudged = current - parameters.w[6] * Double(grade.rawValue - 3)
        let meanTarget = initialDifficulty(grade: .good, parameters: parameters)
        return clampDifficulty(parameters.w[7] * meanTarget + (1.0 - parameters.w[7]) * nudged)
    }

    // MARK: Retrievability

    /// FSRS power forgetting curve:
    ///   R(t, S) = (1 + FACTOR·t/S)^DECAY
    /// where t is the elapsed time in days. A power curve (rather than the
    /// classic exponential) matches observed forgetting better at long
    /// delays. By the FACTOR/DECAY choice above, R(S, S) = 0.9.
    static func retrievability(elapsedDays: Double, stability: Double, parameters: SRSParameters = .standard) -> Double {
        guard stability > 0 else { return 0 }
        let t = max(elapsedDays, 0)
        return pow(1.0 + parameters.factor * t / stability, parameters.decay)
    }

    // MARK: Stability updates

    /// Stability after *successful* recall (hard/good/easy):
    ///   S′ = S · (1 + e^{w8} · (11 − D) · S^{−w9} · (e^{w10·(1−R)} − 1) · HP · EB)
    /// where HP = w15 (< 1) if the answer was Hard, and EB = w16 (> 1) if it
    /// was Easy. The factors encode the model's core insights:
    ///   (11 − D)          — easier material grows stability faster;
    ///   S^{−w9}           — the more stable a memory already is, the harder
    ///                       it is to make it more stable (saturation);
    ///   e^{w10·(1−R)} − 1 — recalling *near the point of forgetting*
    ///                       (low R) strengthens the memory the most
    ///                       (the spacing effect).
    static func stabilityAfterRecall(
        stability: Double,
        difficulty: Double,
        retrievability: Double,
        grade: SRSGrade,
        parameters: SRSParameters = .standard
    ) -> Double {
        let hardPenalty = (grade == .hard) ? parameters.w[15] : 1.0
        let easyBonus = (grade == .easy) ? parameters.w[16] : 1.0
        let growth = exp(parameters.w[8])
            * (11.0 - difficulty)
            * pow(stability, -parameters.w[9])
            * (exp(parameters.w[10] * (1.0 - retrievability)) - 1.0)
            * hardPenalty
            * easyBonus
        return clampStability(stability * (1.0 + growth))
    }

    /// Post-lapse stability (the card was forgotten — graded Again):
    ///   S′ = w11 · D^{−w12} · ((S + 1)^{w13} − 1) · e^{w14·(1−R)}
    /// A lapse costs most of the accumulated stability but not all of it —
    /// relearning a once-known card is faster than learning from scratch.
    /// Capped at the previous stability: forgetting can never *increase* it.
    static func stabilityAfterLapse(
        stability: Double,
        difficulty: Double,
        retrievability: Double,
        parameters: SRSParameters = .standard
    ) -> Double {
        let relearned = parameters.w[11]
            * pow(difficulty, -parameters.w[12])
            * (pow(stability + 1.0, parameters.w[13]) - 1.0)
            * exp(parameters.w[14] * (1.0 - retrievability))
        return clampStability(min(relearned, stability))
    }

    // MARK: Scheduling

    /// The interval after which retrievability will have decayed to
    /// `desiredRetention` — the inverse of the forgetting curve:
    ///   I(r, S) = (S / FACTOR) · (r^{1/DECAY} − 1)
    /// For the default r = 0.9 this is exactly S (stability *is* the
    /// 90%-retention interval). Rounded to whole days and clamped to
    /// [1 day, `maximumIntervalDays`]. Returned in seconds to match the
    /// app's persisted `CardProgress.interval`.
    static func nextInterval(
        stability: Double,
        desiredRetention: Double = 0.9,
        maximumIntervalDays: Double = 365,
        parameters: SRSParameters = .standard
    ) -> TimeInterval {
        let days = stability / parameters.factor * (pow(desiredRetention, 1.0 / parameters.decay) - 1.0)
        let clamped = min(max(days.rounded(), 1.0), maximumIntervalDays)
        return clamped * secondsPerDay
    }

    // MARK: Forecast

    /// Due counts per future day for the next `days` days. Index 0 is today
    /// (cards already overdue are folded into today — they'll be reviewed
    /// today at the earliest), index 1 is tomorrow, and so on. Cards that
    /// have never been reviewed carry no real schedule and are excluded.
    static func reviewForecast(progress: [CardProgress], days: Int) -> [Int] {
        guard days > 0 else { return [] }
        var counts = [Int](repeating: 0, count: days)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        for entry in progress where entry.reviewCount > 0 {
            let dueDay = calendar.startOfDay(for: entry.nextReviewDate)
            let offset = calendar.dateComponents([.day], from: startOfToday, to: dueDay).day ?? 0
            let bucket = max(offset, 0)
            if bucket < days {
                counts[bucket] += 1
            }
        }
        return counts
    }

    // MARK: Formatting

    /// Compact human-readable interval for grade-button labels and schedule
    /// hints: "10m", "3h", "6d", "3w", "2mo", "1y". Unit boundaries follow
    /// Anki's convention (days up to two weeks, weeks up to ~two months,
    /// then months, then years). Localized via `String(localized:)` so the
    /// unit suffixes can be translated.
    static func formattedInterval(_ seconds: TimeInterval) -> String {
        let minute = 60.0
        let hour = 3_600.0
        if seconds < hour {
            let minutes = max(Int((seconds / minute).rounded()), 1)
            return String(localized: "\(minutes)m", comment: "Abbreviated interval: minutes")
        }
        if seconds < secondsPerDay {
            let hours = max(Int((seconds / hour).rounded()), 1)
            return String(localized: "\(hours)h", comment: "Abbreviated interval: hours")
        }
        let days = seconds / secondsPerDay
        if days < 14 {
            return String(localized: "\(max(Int(days.rounded()), 1))d", comment: "Abbreviated interval: days")
        }
        if days < 56 {
            return String(localized: "\(Int((days / 7).rounded()))w", comment: "Abbreviated interval: weeks")
        }
        if days < 365 {
            // 30.44 = average Gregorian month length in days.
            return String(localized: "\(Int((days / 30.44).rounded()))mo", comment: "Abbreviated interval: months")
        }
        let years = max(Int((days / 365.25).rounded()), 1)
        return String(localized: "\(years)y", comment: "Abbreviated interval: years")
    }

    // MARK: Clamps

    /// FSRS difficulty is defined on [1, 10].
    private static func clampDifficulty(_ value: Double) -> Double {
        min(max(value, 1.0), 10.0)
    }

    /// Keep stability strictly positive (the formulas divide by it and raise
    /// it to negative powers) and below a century so intervals stay sane.
    private static func clampStability(_ value: Double) -> Double {
        min(max(value, 0.01), 36_500)
    }
}
