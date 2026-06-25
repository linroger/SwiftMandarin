//
//  BatchExplanationController.swift
//  SwiftMandarin
//
//  Drives a background batch run of the AI word-analysis over the user's saved
//  vocabulary. Only words that have not yet been analyzed (no cached
//  explanation for the current interface direction) are processed; results are
//  persisted to `WordExplanationCacheStore` exactly as the per-word detail view
//  does, so an analysis produced here is served instantly when that word is
//  later opened.
//
//  This is an `@Observable @MainActor` singleton — like every other store in
//  the app — so the work lives independently of any view. The user can navigate
//  away (or close Settings) while it runs; any view that reads this controller
//  shows the live progress, and returning to it resumes showing the same run.
//

import Foundation
import Observation

@Observable
@MainActor
final class BatchExplanationController {

    static let shared = BatchExplanationController()

    // MARK: - Status

    /// Lifecycle of a batch run. `idle` is the resting state (also the initial
    /// state); the others describe the last/active run so the UI can label it.
    enum Status: Equatable {
        case idle
        case running
        /// All work attempted. `generated` succeeded, `failed` errored,
        /// `skipped` were already cached when reached.
        case finished(generated: Int, failed: Int, skipped: Int)
        /// The user cancelled mid-run; `generated` analyses were already saved.
        case cancelled(generated: Int)
    }

    // MARK: - Observable state

    private(set) var status: Status = .idle
    /// Words queued for this run (the unprocessed set captured at start).
    private(set) var total: Int = 0
    /// Successfully generated-and-saved analyses this run.
    private(set) var generated: Int = 0
    /// Words that errored this run.
    private(set) var failed: Int = 0
    /// Words that turned out to be already cached when processed (rare — only if
    /// they were analyzed elsewhere after the run started).
    private(set) var skipped: Int = 0
    /// Most recently completed word, for a bit of life in the progress UI.
    private(set) var lastWord: String?
    /// Last error message seen this run, surfaced so failures aren't silent.
    private(set) var lastErrorMessage: String?

    // MARK: - Private

    private var task: Task<Void, Never>?

    private init() {}

    // MARK: - Derived

    var isRunning: Bool { status == .running }

    /// Words attempted so far (succeeded + failed + skipped).
    var processed: Int { generated + failed + skipped }

    /// Progress in 0...1 for a determinate progress bar.
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(processed) / Double(total))
    }

    // MARK: - Work discovery

    /// The subset of `terms` that still need analysis for the current interface
    /// direction — i.e. whose `(headlineText, directionToken)` is not in the
    /// persistent cache. Empty headwords are excluded. Reading the cache here
    /// makes the count reactive: as analyses complete, this shrinks.
    func unprocessedTerms(from terms: [SavedTerm]) -> [SavedTerm] {
        let cache = WordExplanationCacheStore.shared
        return terms.filter { term in
            let word = term.headlineText
            guard !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            let token = ExplanationDirection.current(forWord: word).cacheToken
            return !cache.hasExplanation(forWord: word, directionToken: token)
        }
    }

    /// Convenience: how many saved terms still need analysis right now.
    func remainingCount(from terms: [SavedTerm]) -> Int {
        unprocessedTerms(from: terms).count
    }

    // MARK: - Control

    /// Begin analyzing every currently-unprocessed saved term, `concurrency`
    /// words at a time. No-op if a run is already in progress. The work list is
    /// snapshotted now, so terms added after starting are not included (the user
    /// can run again to pick them up).
    func start(concurrency: Int) {
        guard !isRunning else { return }

        let pending = unprocessedTerms(from: SavedTermsStore.shared.terms)
        guard !pending.isEmpty else {
            // Nothing to do — report a clean, zero-work finish.
            resetCounters(total: 0)
            status = .finished(generated: 0, failed: 0, skipped: 0)
            return
        }

        guard AIModelSettings.shared.isAnyProviderAvailable else {
            lastErrorMessage = String(localized: "No AI provider is configured. Add one in Settings → AI (or run a local Ollama server).")
            resetCounters(total: 0)
            status = .finished(generated: 0, failed: 0, skipped: 0)
            return
        }

        let limit = min(max(concurrency, AIModelSettings.batchConcurrencyRange.lowerBound),
                        AIModelSettings.batchConcurrencyRange.upperBound)

        resetCounters(total: pending.count)
        status = .running

        task = Task { [weak self] in
            await self?.run(pending: pending, concurrency: limit)
        }
    }

    /// Request cancellation of the active run. Already-saved analyses are kept;
    /// in-flight network calls are cancelled and the run settles into
    /// `.cancelled`. Safe to call when idle.
    func cancel() {
        task?.cancel()
    }

    // MARK: - Execution

    private func resetCounters(total: Int) {
        self.total = total
        generated = 0
        failed = 0
        skipped = 0
        lastWord = nil
        lastErrorMessage = nil
    }

    /// Outcome of analyzing one term, reported back to the main actor.
    private enum WorkOutcome: Sendable {
        case generated(word: String)
        case failed(word: String, message: String)
        case skipped
        case cancelled
    }

    /// Run the queue through a bounded-concurrency task group: at most
    /// `concurrency` analyses are in flight at once. Each analysis suspends on
    /// the network, so the main actor is free during the slow part and the
    /// in-flight requests genuinely overlap.
    private func run(pending: [SavedTerm], concurrency: Int) async {
        await withTaskGroup(of: WorkOutcome.self) { group in
            var nextIndex = 0

            func addTaskIfPossible() {
                guard nextIndex < pending.count else { return }
                let term = pending[nextIndex]
                nextIndex += 1
                group.addTask { await Self.process(term: term) }
            }

            // Prime the window.
            for _ in 0..<concurrency { addTaskIfPossible() }

            while let outcome = await group.next() {
                apply(outcome)
                // Stop scheduling new work once cancelled; let in-flight tasks
                // drain (they will observe cancellation and return quickly).
                if Task.isCancelled {
                    group.cancelAll()
                } else {
                    addTaskIfPossible()
                }
            }
        }
        finish()
    }

    /// Fold one outcome into the observable counters (runs on the main actor).
    private func apply(_ outcome: WorkOutcome) {
        switch outcome {
        case let .generated(word):
            generated += 1
            lastWord = word
        case let .failed(word, message):
            failed += 1
            lastWord = word
            lastErrorMessage = message
        case .skipped:
            skipped += 1
        case .cancelled:
            break  // not counted; the run is settling into .cancelled
        }
    }

    private func finish() {
        if Task.isCancelled {
            status = .cancelled(generated: generated)
        } else {
            // Any queued-but-unreached work (shouldn't happen on a clean drain)
            // is reported as skipped so the totals reconcile.
            let unreached = max(0, total - processed)
            status = .finished(generated: generated, failed: failed, skipped: skipped + unreached)
        }
        task = nil
    }

    /// Analyze a single term and persist the result. Runs on the main actor for
    /// its synchronous bookkeeping; the embedded `await` for the AI call yields
    /// the actor so sibling analyses overlap on the network.
    @MainActor
    private static func process(term: SavedTerm) async -> WorkOutcome {
        if Task.isCancelled { return .cancelled }

        let word = term.headlineText
        guard !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .skipped }

        let token = ExplanationDirection.current(forWord: word).cacheToken
        let cache = WordExplanationCacheStore.shared

        // It may have been analyzed (here or in the detail view) since the queue
        // was snapshotted — never pay for it twice.
        if cache.hasExplanation(forWord: word, directionToken: token) { return .skipped }

        let context = term.glossText.isEmpty ? nil : term.glossText
        do {
            let result = try await AIWordExplanationService.shared.generateExplanationWithProvider(
                for: word,
                pinyin: term.pinyin,
                context: context
            )
            if Task.isCancelled { return .cancelled }
            cache.store(
                word: word,
                pinyin: term.pinyin,
                directionToken: token,
                providerName: AIModelSettings.shared.effectiveProvider.displayName,
                result: result
            )
            return .generated(word: word)
        } catch is CancellationError {
            return .cancelled
        } catch {
            if Task.isCancelled { return .cancelled }
            return .failed(word: word, message: error.localizedDescription)
        }
    }
}
