//
//  BatchExplanationController.swift
//  SwiftMandarin
//
//  Independent, resumable-by-cache batch queues for AI explanations and
//  persistent MiniMax pronunciation audio.
//

import CryptoKit
import Foundation
import Observation

nonisolated enum BatchCredentialFingerprint {
    static func make(_ credential: String) -> String {
        let normalized = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "no-credential" }
        return SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// An in-memory, secret-free identity for every mutable AI request setting
/// used by word explanations. The service can continue to own request
/// construction, while a reviewed batch refuses to mix models, accounts,
/// endpoints, formats, or local-Ollama options mid-run.
nonisolated struct BatchAnalysisConfigurationSnapshot: Equatable, Sendable {
    let providerRawValue: String
    let providerName: String
    let modelID: String
    let endpointIdentity: String
    let optionsIdentity: String
    let credentialFingerprint: String

    @MainActor
    static func current() -> Self {
        let settings = AIModelSettings.shared
        let provider = settings.effectiveProvider
        let modelID = settings.selectedModel(for: provider)

        switch provider {
        case .appleIntelligence:
            return Self(
                providerRawValue: provider.rawValue,
                providerName: provider.displayName,
                modelID: modelID,
                endpointIdentity: "on-device",
                optionsIdentity: "foundation-models",
                credentialFingerprint: "no-credential"
            )
        case .ollama:
            return Self(
                providerRawValue: provider.rawValue,
                providerName: provider.displayName,
                modelID: modelID,
                endpointIdentity: OllamaService.shared.hostURL.absoluteString,
                optionsIdentity: "thinking=\(settings.enableThinking);context=\(settings.contextLength)",
                credentialFingerprint: "no-credential"
            )
        default:
            let style: String
            switch settings.effectiveAPIStyle(for: provider) {
            case .openAICompatible: style = "openai"
            case .anthropic: style = "anthropic"
            }
            return Self(
                providerRawValue: provider.rawValue,
                providerName: provider.displayName,
                modelID: modelID,
                endpointIdentity: settings.baseURL(for: provider)
                    + "\u{1}" + settings.effectiveChatPath(for: provider),
                optionsIdentity: style,
                credentialFingerprint: BatchCredentialFingerprint.make(
                    settings.apiKey(for: provider)
                )
            )
        }
    }

    @MainActor
    func matchesCurrentSettings() -> Bool {
        self == Self.current()
    }
}

nonisolated struct BatchAnalysisTarget: Hashable, Sendable {
    let word: String
    let pinyin: String
    let context: String?
    let directionToken: String
}

nonisolated struct BatchRunPlan: Sendable, Identifiable {
    let id: UUID
    let analysisTargets: [BatchAnalysisTarget]
    let analysisConfiguration: BatchAnalysisConfigurationSnapshot
    let audioPlan: BatchAudioPlan?
    let audioLearningIsChinese: Bool?
    let audioCredentialFingerprint: String?

    var analysisCount: Int { analysisTargets.count }
    var newAudioCount: Int { audioPlan?.newClipCount ?? 0 }
    var cachedAudioCount: Int { audioPlan?.cachedClipCount ?? 0 }
    var totalAudioCount: Int { audioPlan?.totalClipCount ?? 0 }
    var totalNewAudioCharacters: Int { audioPlan?.totalNewCharacters ?? 0 }
    var hasWork: Bool { analysisCount > 0 || newAudioCount > 0 }
}

nonisolated struct BatchRunSummary: Equatable, Sendable {
    let analysesGenerated: Int
    let analysesFailed: Int
    let analysesSkipped: Int
    let analysesUnattempted: Int
    let audioGenerated: Int
    let audioCached: Int
    let audioFailed: Int
    let audioUnattempted: Int
}

@Observable
@MainActor
final class BatchExplanationController {
    static let shared = BatchExplanationController()

    enum RunPhase: Equatable {
        case analyzing
        case generatingAudio
    }

    enum Status: Equatable {
        case idle
        case running(RunPhase)
        case finished(BatchRunSummary)
        case cancelled(BatchRunSummary)
        case failed(BatchRunSummary)
    }

    private(set) var status: Status = .idle

    private(set) var analysisTotal = 0
    private(set) var analysesGenerated = 0
    private(set) var analysesFailed = 0
    private(set) var analysesSkipped = 0

    private(set) var audioTotal = 0
    private(set) var audioGenerated = 0
    private(set) var audioCached = 0
    private(set) var audioFailed = 0

    private(set) var lastWord: String?
    private(set) var lastErrorMessage: String?

    private var task: Task<Void, Never>?
    private var userRequestedCancellation = false
    private var stoppedByFailure = false

    private init() {}

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    var currentPhase: RunPhase? {
        if case let .running(phase) = status { return phase }
        return nil
    }

    var analysisProcessed: Int {
        analysesGenerated + analysesFailed + analysesSkipped
    }

    var audioProcessed: Int {
        audioGenerated + audioCached + audioFailed
    }

    var total: Int { analysisTotal + audioTotal }
    var processed: Int { analysisProcessed + audioProcessed }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(processed) / Double(total))
    }

    var analysisProgress: Double {
        guard analysisTotal > 0 else { return 1 }
        return min(1, Double(analysisProcessed) / Double(analysisTotal))
    }

    var audioProgress: Double {
        guard audioTotal > 0 else { return 1 }
        return min(1, Double(audioProcessed) / Double(audioTotal))
    }

    func unprocessedTerms(from terms: [SavedTerm]) -> [SavedTerm] {
        let cache = WordExplanationCacheStore.shared
        return terms.filter { term in
            let word = term.headlineText
            guard !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            let token = ExplanationDirection.current(forWord: word).cacheToken
            return !cache.hasExplanation(forWord: word, directionToken: token)
        }
    }

    func remainingCount(from terms: [SavedTerm]) -> Int {
        unprocessedTerms(from: terms).count
    }

    /// Builds an exact, credential-free paid-request preflight. Explanation
    /// and audio queues are independent, so an audio-only run remains possible
    /// after every word has already been analyzed.
    func preparePlan(
        from terms: [SavedTerm],
        includeAudio: Bool,
        audioScope: BatchAudioScope
    ) async throws -> BatchRunPlan {
        let sorted = terms.sorted { $0.dateAdded > $1.dateAdded }
        let explanationCache = WordExplanationCacheStore.shared
        let nativeIsChinese = LocalizationManager.shared.nativeIsChinese
        let learningIsChinese = LocalizationManager.shared.learningIsChinese
        let analysisConfiguration = BatchAnalysisConfigurationSnapshot.current()
        var seenAnalyses = Set<String>()
        var analysisTargets: [BatchAnalysisTarget] = []
        var audioSnapshots: [BatchAudioTermSnapshot] = []

        for term in sorted {
            let word = term.headlineText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !word.isEmpty {
                let token = ExplanationDirection(
                    wordIsChinese: word.containsCJK,
                    explainInChinese: nativeIsChinese
                ).cacheToken
                let analysisID = token + "\u{1}" + word.folding(
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    locale: Locale(identifier: "en_US_POSIX")
                )
                if !explanationCache.hasExplanation(forWord: word, directionToken: token),
                   seenAnalyses.insert(analysisID).inserted {
                    analysisTargets.append(
                        BatchAnalysisTarget(
                            word: word,
                            pinyin: term.pinyin,
                            context: term.glossText.isEmpty ? nil : term.glossText,
                            directionToken: token
                        )
                    )
                }
            }

            if includeAudio {
                audioSnapshots.append(
                    BatchAudioTermSnapshot(
                        termID: term.id,
                        displayWord: word.isEmpty ? term.chinese : word,
                        chineseText: term.chineseSide,
                        englishText: term.englishSide
                    )
                )
            }
        }

        let audioPlan: BatchAudioPlan?
        if includeAudio {
            let preferences = AppPreferences.shared
            let chineseConfiguration = preferences.miniMaxSpeechConfiguration(languageCode: "zh-CN")
            let englishConfiguration = preferences.miniMaxSpeechConfiguration(languageCode: "en-US")
            let uncachedPlan = BatchAudioPlanner.makePlan(
                terms: audioSnapshots,
                scope: audioScope,
                learningIsChinese: learningIsChinese,
                chineseConfiguration: chineseConfiguration,
                englishConfiguration: englishConfiguration,
                existingRecordIDs: []
            )
            let existing = try await GeneratedSpeechRepository.shared.existingRecordIDs(
                among: Set(uncachedPlan.allTargets.map(\.id))
            )
            audioPlan = BatchAudioPlanner.makePlan(
                terms: audioSnapshots,
                scope: audioScope,
                learningIsChinese: learningIsChinese,
                chineseConfiguration: chineseConfiguration,
                englishConfiguration: englishConfiguration,
                existingRecordIDs: existing
            )
        } else {
            audioPlan = nil
        }

        return BatchRunPlan(
            id: UUID(),
            analysisTargets: analysisTargets,
            analysisConfiguration: analysisConfiguration,
            audioPlan: audioPlan,
            audioLearningIsChinese: includeAudio ? learningIsChinese : nil,
            audioCredentialFingerprint: includeAudio
                ? BatchCredentialFingerprint.make(
                    AIModelSettings.shared.apiKey(for: .minimax)
                )
                : nil
        )
    }

    func start(plan: BatchRunPlan, concurrency: Int) {
        guard !isRunning else { return }

        let settings = AIModelSettings.shared
        if plan.analysisCount > 0, !settings.isAnyProviderAvailable {
            resetCounters(for: plan)
            lastErrorMessage = String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).")
            status = .failed(summary())
            return
        }

        if plan.analysisCount > 0,
           !plan.analysisConfiguration.matchesCurrentSettings() {
            resetCounters(for: plan)
            lastErrorMessage = String(localized: "AI settings changed after this batch was reviewed. Review the batch again before starting.")
            status = .failed(summary())
            return
        }

        if plan.analysisTargets.contains(where: {
            ExplanationDirection.current(forWord: $0.word).cacheToken != $0.directionToken
        }) {
            resetCounters(for: plan)
            lastErrorMessage = String(localized: "Language settings changed after this batch was reviewed. Review the batch again before starting.")
            status = .failed(summary())
            return
        }

        if plan.audioPlan?.scope == .learningLanguage,
           plan.audioLearningIsChinese != LocalizationManager.shared.learningIsChinese {
            resetCounters(for: plan)
            lastErrorMessage = String(localized: "Language settings changed after this batch was reviewed. Review the batch again before starting.")
            status = .failed(summary())
            return
        }

        let apiKey = plan.newAudioCount > 0 ? settings.apiKey(for: .minimax) : ""
        if plan.newAudioCount > 0,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resetCounters(for: plan)
            lastErrorMessage = String(localized: "Add a MiniMax API key in AI Audio settings before generating batch audio.")
            status = .failed(summary())
            return
        }
        if plan.newAudioCount > 0,
           plan.audioCredentialFingerprint != BatchCredentialFingerprint.make(apiKey) {
            resetCounters(for: plan)
            lastErrorMessage = String(localized: "The MiniMax API key changed after this batch was reviewed. Review the batch again before starting.")
            status = .failed(summary())
            return
        }

        let analysisLimit = min(
            max(concurrency, AIModelSettings.batchConcurrencyRange.lowerBound),
            AIModelSettings.batchConcurrencyRange.upperBound
        )
        resetCounters(for: plan)
        guard plan.hasWork else {
            status = .finished(summary())
            return
        }

        status = .running(plan.analysisCount > 0 ? .analyzing : .generatingAudio)
        task = Task { [weak self] in
            await self?.run(
                plan: plan,
                analysisConcurrency: analysisLimit,
                apiKey: apiKey,
                analysisConfiguration: plan.analysisConfiguration
            )
        }
    }

    func cancel() {
        userRequestedCancellation = true
        task?.cancel()
    }

    private func resetCounters(for plan: BatchRunPlan) {
        analysisTotal = plan.analysisCount
        analysesGenerated = 0
        analysesFailed = 0
        analysesSkipped = 0
        audioTotal = plan.totalAudioCount
        audioGenerated = 0
        audioCached = plan.cachedAudioCount
        audioFailed = 0
        lastWord = nil
        lastErrorMessage = nil
        userRequestedCancellation = false
        stoppedByFailure = false
    }

    private func run(
        plan: BatchRunPlan,
        analysisConcurrency: Int,
        apiKey: String,
        analysisConfiguration: BatchAnalysisConfigurationSnapshot
    ) async {
        let runtimeAudioPlan: BatchAudioPlan?
        do {
            if let reviewedAudioPlan = plan.audioPlan {
                let existing = try await GeneratedSpeechRepository.shared.existingRecordIDs(
                    among: Set(reviewedAudioPlan.allTargets.map(\.id))
                )
                runtimeAudioPlan = try BatchAudioPlanRevalidator.revalidate(
                    reviewed: reviewedAudioPlan,
                    existingRecordIDs: existing
                )
                audioCached = runtimeAudioPlan?.cachedClipCount ?? 0
            } else {
                runtimeAudioPlan = nil
            }
        } catch is CancellationError {
            finish()
            return
        } catch {
            stoppedByFailure = true
            lastErrorMessage = error.localizedDescription
            finish()
            return
        }

        if Task.isCancelled {
            finish()
            return
        }

        if !plan.analysisTargets.isEmpty {
            await runAnalyses(
                plan.analysisTargets,
                concurrency: analysisConcurrency,
                analysisConfiguration: analysisConfiguration
            )
        }

        if !Task.isCancelled,
           let audioPlan = runtimeAudioPlan,
           !audioPlan.pendingTargets.isEmpty {
            status = .running(.generatingAudio)
            await runAudio(
                audioPlan.pendingTargets,
                apiKey: apiKey,
                credentialFingerprint: plan.audioCredentialFingerprint
                    ?? BatchCredentialFingerprint.make(apiKey)
            )
        }

        finish()
    }

    private enum AnalysisOutcome: Sendable {
        case generated(word: String)
        case failed(word: String, message: String, stopRemaining: Bool)
        case skipped
        case cancelled
    }

    private func runAnalyses(
        _ targets: [BatchAnalysisTarget],
        concurrency: Int,
        analysisConfiguration: BatchAnalysisConfigurationSnapshot
    ) async {
        await withTaskGroup(of: AnalysisOutcome.self) { group in
            var nextIndex = 0

            func addTaskIfPossible() {
                guard nextIndex < targets.count, !Task.isCancelled else { return }
                let target = targets[nextIndex]
                nextIndex += 1
                group.addTask {
                    await Self.processAnalysis(
                        target,
                        analysisConfiguration: analysisConfiguration
                    )
                }
            }

            for _ in 0..<concurrency { addTaskIfPossible() }
            while let outcome = await group.next() {
                apply(outcome)
                if Task.isCancelled {
                    group.cancelAll()
                } else {
                    addTaskIfPossible()
                }
            }
        }
    }

    @MainActor
    private static func processAnalysis(
        _ target: BatchAnalysisTarget,
        analysisConfiguration: BatchAnalysisConfigurationSnapshot
    ) async -> AnalysisOutcome {
        if Task.isCancelled { return .cancelled }
        guard analysisConfiguration.matchesCurrentSettings(),
              ExplanationDirection.current(forWord: target.word).cacheToken == target.directionToken else {
            return .failed(
                word: target.word,
                message: String(localized: "AI or language settings changed while the batch was running. Start a new reviewed batch to continue."),
                stopRemaining: true
            )
        }
        let cache = WordExplanationCacheStore.shared
        if cache.hasExplanation(forWord: target.word, directionToken: target.directionToken) {
            return .skipped
        }

        do {
            let result = try await AIWordExplanationService.shared.generateExplanationWithProvider(
                for: target.word,
                pinyin: target.pinyin,
                context: target.context
            )
            if Task.isCancelled { return .cancelled }
            guard analysisConfiguration.matchesCurrentSettings(),
                  ExplanationDirection.current(forWord: target.word).cacheToken == target.directionToken else {
                return .failed(
                    word: target.word,
                    message: String(localized: "AI or language settings changed while the batch was running. The completed response was not cached under stale settings."),
                    stopRemaining: true
                )
            }
            cache.store(
                word: target.word,
                pinyin: target.pinyin,
                directionToken: target.directionToken,
                providerName: analysisConfiguration.providerName,
                result: result
            )
            return .generated(word: target.word)
        } catch is CancellationError {
            return .cancelled
        } catch {
            if Task.isCancelled { return .cancelled }
            return .failed(
                word: target.word,
                message: error.localizedDescription,
                stopRemaining: false
            )
        }
    }

    private func apply(_ outcome: AnalysisOutcome) {
        switch outcome {
        case let .generated(word):
            analysesGenerated += 1
            lastWord = word
        case let .failed(word, message, stopRemaining):
            analysesFailed += 1
            lastWord = word
            lastErrorMessage = message
            if stopRemaining {
                stopForFailure()
            }
        case .skipped:
            analysesSkipped += 1
        case .cancelled:
            break
        }
    }

    private enum AudioOutcome: Sendable {
        case generated(record: GeneratedSpeechRecord, word: String, wasCached: Bool)
        case failed(word: String, message: String, stopRemaining: Bool)
        case cancelled
    }

    private func runAudio(
        _ targets: [BatchAudioTarget],
        apiKey: String,
        credentialFingerprint: String
    ) async {
        let gate = BatchAudioStartGate()
        await withTaskGroup(of: AudioOutcome.self) { group in
            var nextIndex = 0
            let concurrency = min(2, targets.count)

            func addTaskIfPossible() {
                guard nextIndex < targets.count, !Task.isCancelled else { return }
                let target = targets[nextIndex]
                nextIndex += 1
                group.addTask {
                    await Self.processAudio(
                        target,
                        apiKey: apiKey,
                        credentialFingerprint: credentialFingerprint,
                        gate: gate
                    )
                }
            }

            for _ in 0..<concurrency { addTaskIfPossible() }
            while let outcome = await group.next() {
                apply(outcome)
                if Task.isCancelled {
                    group.cancelAll()
                } else {
                    addTaskIfPossible()
                }
            }
        }
    }

    @MainActor
    private static func processAudio(
        _ target: BatchAudioTarget,
        apiKey: String,
        credentialFingerprint: String,
        gate: BatchAudioStartGate
    ) async -> AudioOutcome {
        if Task.isCancelled { return .cancelled }
        do {
            try await gate.waitForPermit()
            guard credentialFingerprint == BatchCredentialFingerprint.make(apiKey),
                  credentialFingerprint == BatchCredentialFingerprint.make(
                    AIModelSettings.shared.apiKey(for: .minimax)
                  ) else {
                return .failed(
                    word: target.displayWord,
                    message: String(localized: "The MiniMax API key changed while the batch was running. Start a new reviewed batch to continue."),
                    stopRemaining: true
                )
            }
            let generated = try await MiniMaxSpeechPipeline.shared.speech(
                for: target.identity,
                apiKey: apiKey
            )
            GeneratedSpeechStore.shared.note(generated.record)
            return .generated(
                record: generated.record,
                word: target.displayWord,
                wasCached: generated.wasCached
            )
        } catch is CancellationError {
            return .cancelled
        } catch MiniMaxAudioError.cancelled {
            return .cancelled
        } catch {
            if Task.isCancelled { return .cancelled }
            return .failed(
                word: target.displayWord,
                message: error.localizedDescription,
                stopRemaining: BatchAudioFailurePolicy.shouldStop(after: error)
            )
        }
    }

    private func apply(_ outcome: AudioOutcome) {
        switch outcome {
        case let .generated(_, word, wasCached):
            if wasCached {
                audioCached += 1
            } else {
                audioGenerated += 1
            }
            lastWord = word
        case let .failed(word, message, stopRemaining):
            audioFailed += 1
            lastWord = word
            lastErrorMessage = message
            if stopRemaining {
                // Authentication, configuration, quota, and rate-limit errors
                // affect the remaining queue. Stop before repeating the same
                // failing paid request; a later run resumes from saved clips.
                stopForFailure()
            }
        case .cancelled:
            break
        }
    }

    private func summary() -> BatchRunSummary {
        BatchRunSummary(
            analysesGenerated: analysesGenerated,
            analysesFailed: analysesFailed,
            analysesSkipped: analysesSkipped,
            analysesUnattempted: max(0, analysisTotal - analysisProcessed),
            audioGenerated: audioGenerated,
            audioCached: audioCached,
            audioFailed: audioFailed,
            audioUnattempted: max(0, audioTotal - audioProcessed)
        )
    }

    private func finish() {
        let finalSummary = summary()
        if stoppedByFailure {
            status = .failed(finalSummary)
        } else if userRequestedCancellation || Task.isCancelled {
            status = .cancelled(finalSummary)
        } else {
            status = .finished(finalSummary)
        }
        task = nil
    }

    private func stopForFailure() {
        stoppedByFailure = true
        task?.cancel()
    }
}
