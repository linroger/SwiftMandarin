//
//  BatchAudioPlan.swift
//  SwiftMandarin
//
//  Pure, credential-free planning for persistent MiniMax batch audio.
//

import Foundation

nonisolated enum BatchAudioScope: String, CaseIterable, Identifiable, Sendable {
    case learningLanguage
    case bothLanguages

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .learningLanguage: return "Learning Language Only"
        case .bothLanguages: return "Mandarin and English"
        }
    }
}

nonisolated struct BatchAudioTermSnapshot: Hashable, Sendable {
    let termID: UUID
    let displayWord: String
    let chineseText: String
    let englishText: String
}

nonisolated struct BatchAudioTarget: Hashable, Identifiable, Sendable {
    var id: String { identity.cacheKey }

    let termID: UUID
    let displayWord: String
    let text: String
    let languageCode: String
    let identity: MiniMaxSpeechCacheIdentity

    var isMandarin: Bool { identity.languageBoost == .chinese }
}

nonisolated struct BatchAudioPlan: Sendable {
    let scope: BatchAudioScope
    let allTargets: [BatchAudioTarget]
    let pendingTargets: [BatchAudioTarget]
    let cachedRecordIDs: Set<String>

    var totalClipCount: Int { allTargets.count }
    var cachedClipCount: Int { cachedRecordIDs.count }
    var newClipCount: Int { pendingTargets.count }
    var totalNewCharacters: Int { pendingTargets.reduce(0) { $0 + $1.text.count } }
    var newMandarinClipCount: Int { pendingTargets.lazy.filter(\.isMandarin).count }
    var newEnglishClipCount: Int { pendingTargets.count - newMandarinClipCount }
}

nonisolated enum BatchAudioPlanRevalidationError: LocalizedError, Sendable {
    case reviewedSavedAudioChanged

    var errorDescription: String? {
        switch self {
        case .reviewedSavedAudioChanged:
            return String(localized: "Saved audio changed after this batch was reviewed. Review the batch again before starting any paid requests.")
        }
    }
}

/// Rechecks the exact cache set at execution time. Newly cached clips safely
/// reduce paid work, but a clip counted as saved during review may not become a
/// surprise paid request if another window deletes it before Start.
nonisolated enum BatchAudioPlanRevalidator {
    static func revalidate(
        reviewed plan: BatchAudioPlan,
        existingRecordIDs: Set<String>
    ) throws -> BatchAudioPlan {
        guard plan.cachedRecordIDs.isSubset(of: existingRecordIDs) else {
            throw BatchAudioPlanRevalidationError.reviewedSavedAudioChanged
        }

        let targetIDs = Set(plan.allTargets.map(\.id))
        let cached = existingRecordIDs.intersection(targetIDs)
        return BatchAudioPlan(
            scope: plan.scope,
            allTargets: plan.allTargets,
            pendingTargets: plan.allTargets.filter { !cached.contains($0.id) },
            cachedRecordIDs: cached
        )
    }
}

nonisolated enum BatchAudioPlanner {
    static func makePlan(
        terms: [BatchAudioTermSnapshot],
        scope: BatchAudioScope,
        learningIsChinese: Bool,
        chineseConfiguration: MiniMaxSpeechConfiguration,
        englishConfiguration: MiniMaxSpeechConfiguration,
        existingRecordIDs: Set<String>
    ) -> BatchAudioPlan {
        var seen = Set<String>()
        var targets: [BatchAudioTarget] = []

        func append(
            text rawText: String,
            languageCode: String,
            configuration: MiniMaxSpeechConfiguration,
            term: BatchAudioTermSnapshot
        ) {
            let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            let identity = MiniMaxSpeechCacheIdentity(
                text: text,
                languageCode: languageCode,
                configuration: configuration
            )
            guard seen.insert(identity.cacheKey).inserted else { return }
            targets.append(
                BatchAudioTarget(
                    termID: term.termID,
                    displayWord: term.displayWord,
                    text: text,
                    languageCode: identity.languageCode,
                    identity: identity
                )
            )
        }

        for term in terms {
            switch scope {
            case .learningLanguage:
                if learningIsChinese {
                    append(
                        text: term.chineseText,
                        languageCode: "zh-CN",
                        configuration: chineseConfiguration,
                        term: term
                    )
                } else {
                    append(
                        text: term.englishText,
                        languageCode: "en-US",
                        configuration: englishConfiguration,
                        term: term
                    )
                }
            case .bothLanguages:
                append(
                    text: term.chineseText,
                    languageCode: "zh-CN",
                    configuration: chineseConfiguration,
                    term: term
                )
                append(
                    text: term.englishText,
                    languageCode: "en-US",
                    configuration: englishConfiguration,
                    term: term
                )
            }
        }

        let targetIDs = Set(targets.map(\.id))
        let cached = existingRecordIDs.intersection(targetIDs)
        return BatchAudioPlan(
            scope: scope,
            allTargets: targets,
            pendingTargets: targets.filter { !cached.contains($0.id) },
            cachedRecordIDs: cached
        )
    }
}

/// Stops a paid queue when the app cannot prove that another request will
/// produce a usable, persistable clip. Every non-cancellation synthesis error
/// is fail-closed; the user may explicitly review and resume from saved clips.
nonisolated enum BatchAudioFailurePolicy {
    static func shouldStop(after error: Error) -> Bool {
        if let audioError = error as? MiniMaxAudioError,
           case .cancelled = audioError {
            return false
        }
        return !(error is CancellationError)
    }
}

/// MiniMax documents 60 ordinary T2A request starts per minute. Reserving a
/// timestamp before suspension remains correct under actor reentrancy.
actor BatchAudioStartGate {
    private let intervalNanoseconds: UInt64
    private var nextPermitNanoseconds = DispatchTime.now().uptimeNanoseconds

    init(intervalNanoseconds: UInt64 = 1_000_000_000) {
        self.intervalNanoseconds = intervalNanoseconds
    }

    func waitForPermit() async throws {
        let now = DispatchTime.now().uptimeNanoseconds
        let permit = max(now, nextPermitNanoseconds)
        nextPermitNanoseconds = permit &+ intervalNanoseconds
        if permit > now {
            try await Task.sleep(nanoseconds: permit - now)
        }
        try Task.checkCancellation()
    }
}
