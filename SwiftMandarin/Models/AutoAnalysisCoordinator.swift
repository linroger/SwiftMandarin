//
//  AutoAnalysisCoordinator.swift
//  SwiftMandarin
//
//  Background AI analysis of words the moment they are saved.
//
//  This is the automatic sibling of `BatchExplanationController`: instead of a
//  reviewed, user-started run over the whole vocabulary list, every newly saved
//  word is translated and analyzed by the selected provider on its own, so
//  opening it later shows a finished analysis rather than a spinner. It writes
//  into the very same `WordExplanationCacheStore` under the very same
//  (word, direction) key, so the two never duplicate each other's work and the
//  batch screen's "Needs Analysis" count falls as the queue drains.
//
//  Because the run is automatic it holds itself to stricter rules than the
//  manual batch:
//
//  * It is off by default and does nothing at all until the user opts in.
//  * It never generates MiniMax audio. Audio is paid per character and the
//    manual flow gates it behind an explicit preflight; nothing that spends on
//    it should happen without a press.
//  * It yields to a running manual batch rather than competing with it for the
//    same provider's rate limit.
//  * It stops after repeated failures instead of re-billing a broken endpoint
//    once per saved word, and surfaces the error for the user to act on.
//

import Foundation
import Observation

@Observable
@MainActor
final class AutoAnalysisCoordinator {

    static let shared = AutoAnalysisCoordinator()

    /// What the queue is doing, so the settings pane can always explain a
    /// non-empty queue that is not moving.
    enum Status: Equatable {
        case idle
        case analyzing
        /// No provider is configured; the queue is intact and waits for one.
        case waitingForProvider
        /// A reviewed manual batch owns the provider right now.
        case waitingForBatch
        /// Stopped after consecutive failures; needs an explicit resume.
        case pausedAfterFailures
    }

    private(set) var status: Status = .idle
    private(set) var queue = AutoAnalysisQueue()

    /// Words analyzed, and words given up on, since the app launched. Session
    /// counters — the durable record of what has been analyzed is the cache
    /// itself, which the batch screen already reports.
    private(set) var analyzedCount = 0
    private(set) var failedCount = 0
    private(set) var lastAnalyzedWord: String?
    private(set) var lastErrorMessage: String?

    private var drainTask: Task<Void, Never>?
    /// Bumped whenever the current drain is abandoned. Outcomes that arrive
    /// from an abandoned drain are ignored, so a cancelled request can never
    /// re-add a word to a queue the user has just cleared.
    private var drainGeneration = 0
    private var consecutiveFailures = 0

    private var persistTask: Task<Void, Never>?
    private var needsPersist = false

    // These constants are `nonisolated` because one of them is a default
    // argument, which Swift evaluates outside the main actor.
    nonisolated private static let storageKey = "autoAnalysisQueue"

    /// Saving a word is a burst event — a reader taps three words in a row, an
    /// import adds hundreds — so the first dispatch waits briefly. That also
    /// lets vocabulary import's `WordExplanationCacheStore.merge` land first,
    /// which spares re-analyzing words whose analysis arrived in the same file.
    nonisolated private static let coalescingDelay: Duration = .seconds(2)
    /// Poll interval while a manual batch is running.
    nonisolated private static let batchWaitDelay: Duration = .seconds(5)
    /// Gap before picking up words saved while the previous pass was finishing.
    nonisolated private static let followUpDelay: Duration = .seconds(1)
    /// Coalescing window for queue writes.
    nonisolated private static let persistDelay: Duration = .seconds(1)
    /// Consecutive failures tolerated before the queue pauses itself. A dead
    /// endpoint, a revoked key, or an exhausted quota fails every word
    /// identically; three is enough to tell that apart from one bad word.
    nonisolated private static let failurePauseThreshold = 3

    private init() {
        queue = PersistentCodableStore.load(AutoAnalysisQueue.self, key: Self.storageKey)
            ?? AutoAnalysisQueue()
    }

    // MARK: - Read-only state for the UI

    /// Words still owed an analysis (waiting plus in flight).
    var outstandingCount: Int { queue.outstandingCount }
    var isEnabled: Bool { AIModelSettings.shared.autoAnalyzeNewTerms }
    var isPaused: Bool { status == .pausedAfterFailures }
    var isAnalyzing: Bool { status == .analyzing }
    /// Words refused because the queue was already full.
    var rejectedByCapacity: Int { queue.rejectedByCapacity }
    /// The word at the head of the queue, shown as "up next" / "analyzing".
    var currentWord: String? {
        queue.inFlight.first?.word ?? queue.pending.first?.word
    }

    // MARK: - Entry points

    /// Queue a freshly saved term. Called by `SavedTermsStore` for every add, so
    /// words captured from translation, photos, the reader, Shortcuts, and
    /// import all take the same path.
    ///
    /// The headword and its sense hints are resolved here exactly the way
    /// `BatchExplanationController.preparePlan` resolves them, so an automatic
    /// analysis and a manual one produce the same cache entry.
    func noteTermAdded(_ term: SavedTerm) {
        guard AIModelSettings.shared.autoAnalyzeNewTerms else { return }

        let word = term.headlineText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }

        let directionToken = ExplanationDirection.current(forWord: word).cacheToken
        guard !WordExplanationCacheStore.shared.hasExplanation(
            forWord: word,
            directionToken: directionToken
        ) else { return }

        let outcome = queue.enqueue(
            AutoAnalysisRequest(
                word: word,
                pinyin: term.headwordReading,
                context: term.glossText.isEmpty ? nil : term.glossText
            )
        )

        switch outcome {
        case .queued:
            schedulePersist()
            scheduleDrain()
        case .full:
            // Persist the refusal count so the settings pane can report it.
            schedulePersist()
        case .duplicate, .empty:
            break
        }
    }

    /// Recover a queue interrupted by quitting the app and start working.
    /// Called when the app's first window appears.
    ///
    /// Recovery only runs when no pass owns the in-flight half. This is not
    /// only called once: the root view's identity changes on an in-app language
    /// switch, which re-runs its `task`, and returning a request that is
    /// genuinely in flight to the queue would dispatch — and pay for — it twice.
    func resumePendingWork() {
        if drainTask == nil {
            queue.restoreInFlight()
            schedulePersist()
        }
        scheduleDrain()
    }

    /// React to the settings toggle being flipped.
    func enabledDidChange() {
        if AIModelSettings.shared.autoAnalyzeNewTerms {
            consecutiveFailures = 0
            lastErrorMessage = nil
            status = .idle
            scheduleDrain(after: .zero)
        } else {
            cancelDrain()
            status = .idle
        }
    }

    /// Nudge the queue after something that may have unblocked it — a provider
    /// selected, an API key added, or the batch screen appearing.
    func kick() {
        guard AIModelSettings.shared.autoAnalyzeNewTerms, !queue.isEmpty else { return }
        if status == .waitingForProvider { status = .idle }
        scheduleDrain(after: .zero)
    }

    /// Resume after the queue paused itself on repeated failures.
    func resumeAfterFailures() {
        guard status == .pausedAfterFailures else { return }
        consecutiveFailures = 0
        lastErrorMessage = nil
        status = .idle
        scheduleDrain(after: .zero)
    }

    /// Drop every waiting word. The words stay saved — only the automatic work
    /// is abandoned, and a reviewed manual batch can still analyze them later.
    func clearQueue() {
        cancelDrain()
        queue.removeAll()
        consecutiveFailures = 0
        status = .idle
        persistNow()
    }

    // MARK: - Draining

    private func scheduleDrain(after delay: Duration = AutoAnalysisCoordinator.coalescingDelay) {
        guard AIModelSettings.shared.autoAnalyzeNewTerms,
              status != .pausedAfterFailures,
              !queue.pending.isEmpty,
              drainTask == nil else { return }

        drainGeneration &+= 1
        let generation = drainGeneration
        drainTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard let self, !Task.isCancelled else { return }
            await self.drain(generation: generation)
            guard self.drainGeneration == generation else { return }
            self.drainTask = nil
            // A word saved in the moment between the loop's last look at the
            // queue and this line would otherwise wait for the next save, so
            // give it its own pass. Only from `.idle`: a pass that stopped
            // because it is waiting on something (a provider, a batch, a
            // resume) must not immediately restart, or it would spin once a
            // second for as long as the queue stays blocked. Those states are
            // resumed by `kick()` or the next save instead.
            if !Task.isCancelled, self.status == .idle, !self.queue.pending.isEmpty {
                self.scheduleDrain(after: Self.followUpDelay)
            }
        }
    }

    /// Abandon the current drain. Any word recorded as in flight goes back to
    /// the queue immediately (rather than waiting for the next launch), and the
    /// generation bump makes the abandoned pass's outcomes inert.
    private func cancelDrain() {
        drainGeneration &+= 1
        drainTask?.cancel()
        drainTask = nil
        queue.restoreInFlight()
        schedulePersist()
    }

    private func drain(generation: Int) async {
        while !Task.isCancelled {
            guard AIModelSettings.shared.autoAnalyzeNewTerms,
                  drainGeneration == generation,
                  status != .pausedAfterFailures,
                  !queue.pending.isEmpty else { break }

            // A reviewed batch was started deliberately and may already be
            // analyzing these same words; let it finish rather than doubling the
            // request rate against one provider's limit.
            if BatchExplanationController.shared.isRunning {
                status = .waitingForBatch
                try? await Task.sleep(for: Self.batchWaitDelay)
                continue
            }

            guard AIModelSettings.shared.isAnyProviderAvailable else {
                // Keep the queue: configuring a provider later resumes it.
                status = .waitingForProvider
                return
            }

            status = .analyzing
            let limit = max(1, min(AIModelSettings.shared.batchConcurrency, queue.pendingCount))
            var dispatched: [AutoAnalysisRequest] = []
            for _ in 0..<limit {
                guard let next = queue.dequeue() else { break }
                dispatched.append(next)
            }
            guard !dispatched.isEmpty else { break }
            schedulePersist()

            await withTaskGroup(of: AnalysisOutcome.self) { group in
                for request in dispatched {
                    group.addTask { await Self.process(request) }
                }
                while let outcome = await group.next() {
                    apply(outcome, generation: generation)
                }
            }
            schedulePersist()
        }

        guard drainGeneration == generation else { return }
        switch status {
        case .analyzing, .waitingForBatch:
            status = .idle
        case .idle, .waitingForProvider, .pausedAfterFailures:
            break
        }
    }

    private enum AnalysisOutcome: Sendable {
        case analyzed(AutoAnalysisRequest)
        /// Already in the cache by the time it was dispatched (a manual batch,
        /// an import, or the user opening the word got there first).
        case alreadyAnalyzed(AutoAnalysisRequest)
        /// A response came back under settings that are no longer current, so
        /// it was not cached.
        case staleSettings(AutoAnalysisRequest, message: String)
        case failed(AutoAnalysisRequest, message: String)
        case cancelled(AutoAnalysisRequest)
    }

    /// Analyze one word and cache the result, refusing to write anything under
    /// settings that changed while the request was in flight — the same
    /// guarantee `BatchExplanationController` makes, which is what keeps a
    /// cached explanation an honest record of the provider and direction that
    /// produced it.
    @MainActor
    private static func process(_ request: AutoAnalysisRequest) async -> AnalysisOutcome {
        if Task.isCancelled { return .cancelled(request) }

        // The direction is resolved at dispatch, not at save time: the learner
        // may have switched interface language while this word waited.
        let directionToken = ExplanationDirection.current(forWord: request.word).cacheToken
        let cache = WordExplanationCacheStore.shared
        if cache.hasExplanation(forWord: request.word, directionToken: directionToken) {
            return .alreadyAnalyzed(request)
        }

        let configuration = BatchAnalysisConfigurationSnapshot.current()
        do {
            let result = try await AIWordExplanationService.shared.generateExplanationWithProvider(
                for: request.word,
                pinyin: request.pinyin,
                context: request.context
            )
            if Task.isCancelled { return .cancelled(request) }
            guard configuration.matchesCurrentSettings(),
                  ExplanationDirection.current(forWord: request.word).cacheToken == directionToken else {
                return .staleSettings(
                    request,
                    message: String(localized: "AI or language settings changed while a word was being analyzed automatically. The response was discarded and the word was queued again.", bundle: .appLanguage)
                )
            }
            cache.store(
                word: request.word,
                pinyin: request.pinyin,
                directionToken: directionToken,
                providerName: configuration.providerName,
                result: result
            )
            return .analyzed(request)
        } catch is CancellationError {
            return .cancelled(request)
        } catch {
            if Task.isCancelled { return .cancelled(request) }
            return .failed(request, message: error.localizedDescription)
        }
    }

    private func apply(_ outcome: AnalysisOutcome, generation: Int) {
        // An outcome from an abandoned pass must not touch the live queue.
        guard drainGeneration == generation else { return }

        switch outcome {
        case let .analyzed(request):
            queue.complete(request)
            analyzedCount += 1
            lastAnalyzedWord = request.word
            consecutiveFailures = 0
            lastErrorMessage = nil
        case let .alreadyAnalyzed(request):
            queue.complete(request)
        case let .staleSettings(request, message):
            lastErrorMessage = message
            // The request did reach the provider, so it costs an attempt even
            // though the word itself was blameless.
            if !queue.retry(request) { failedCount += 1 }
        case let .failed(request, message):
            lastErrorMessage = message
            consecutiveFailures += 1
            if !queue.retry(request) { failedCount += 1 }
            if consecutiveFailures >= Self.failurePauseThreshold {
                status = .pausedAfterFailures
            }
        case let .cancelled(request):
            // No verdict was reached, so no attempt is consumed.
            queue.returnToQueue(request)
        }
    }

    // MARK: - Persistence

    /// Coalesced queue write. A bulk import enqueues hundreds of words in one
    /// run loop turn; re-encoding the growing queue per word would be the same
    /// O(n²) write storm `SavedTermsStore` documents avoiding.
    private func schedulePersist() {
        needsPersist = true
        guard persistTask == nil else { return }
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: Self.persistDelay)
            guard let self else { return }
            self.persistTask = nil
            if self.needsPersist { self.persistNow() }
        }
    }

    private func persistNow() {
        needsPersist = false
        PersistentCodableStore.save(queue, key: Self.storageKey)
    }
}
