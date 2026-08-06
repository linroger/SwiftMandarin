//
//  AutoAnalysisQueue.swift
//  SwiftMandarin
//
//  The pure work queue behind automatic AI analysis of newly saved vocabulary.
//
//  Why this is its own value type
//  ------------------------------
//  Automatic analysis spends real API tokens without the user pressing
//  anything, so the rules about *what* gets dispatched — never the same word
//  twice, never more than a bounded number of waiting words, never an endless
//  retry of a word the provider keeps rejecting, never a word lost because the
//  app quit mid-request — are the part that must not drift. Keeping them in a
//  `Sendable`, Foundation-only value keeps them assertable by the standalone
//  contract runner in `scripts/auto-analysis-checks/` without a provider, a
//  cache, a bundle, or a main actor.
//
//  The queue deliberately stores no direction token: the learning direction can
//  flip while a word waits, and the correct token is the one current at
//  dispatch time. `AutoAnalysisCoordinator` resolves it there.
//

import Foundation

// MARK: - Request

/// One word waiting to be analyzed, with the same sense hints a manual batch
/// would send (`pinyin` is the headword's own reading, `context` the gloss).
nonisolated struct AutoAnalysisRequest: Codable, Equatable, Sendable {
    let word: String
    let pinyin: String
    let context: String?
    /// How many times this word has already been dispatched to a provider.
    /// Retries increment it; `AutoAnalysisQueue.maxAttempts` caps it.
    var attempts: Int

    init(word: String, pinyin: String = "", context: String? = nil, attempts: Int = 0) {
        self.word = word
        self.pinyin = pinyin
        self.context = context
        self.attempts = attempts
    }

    private enum CodingKeys: String, CodingKey {
        case word, pinyin, context, attempts
    }

    /// Tolerant decode, matching the app's other persisted models: only `word`
    /// is essential, so a queue written by an older build still loads instead of
    /// discarding every word that was waiting.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        pinyin = (try? container.decode(String.self, forKey: .pinyin)) ?? ""
        context = try? container.decode(String.self, forKey: .context)
        attempts = (try? container.decode(Int.self, forKey: .attempts)) ?? 0
    }
}

// MARK: - Queue

/// FIFO queue of words to analyze automatically, plus the words currently in
/// flight. Both halves persist, so a request interrupted by quitting the app is
/// recovered rather than silently dropped (see `restoreInFlight()`).
nonisolated struct AutoAnalysisQueue: Codable, Equatable, Sendable {

    /// Total dispatches allowed for one word before it is given up on. Three
    /// covers a transient network blip or a single rate-limit rejection without
    /// letting a permanently failing word bill for the same request forever.
    static let maxAttempts = 3

    /// Ceiling on words waiting at once. Automatic analysis is meant for the
    /// trickle of words a learner saves while reading; a bulk CSV import can
    /// otherwise enqueue thousands of paid requests that nobody asked for. Words
    /// past the ceiling are refused (and counted) rather than evicting words
    /// already accepted, so what is queued is exactly what will be processed —
    /// the reviewed manual batch remains the way to work through a backlog.
    static let capacity = 500

    /// The outcome of one `enqueue`, so callers can report refusals instead of
    /// dropping words silently.
    enum EnqueueOutcome: String, Equatable, Sendable {
        /// Accepted at the tail of the queue.
        case queued
        /// The same word is already waiting or in flight.
        case duplicate
        /// The word was empty once trimmed.
        case empty
        /// The queue is at `capacity`.
        case full
    }

    private(set) var pending: [AutoAnalysisRequest] = []
    private(set) var inFlight: [AutoAnalysisRequest] = []
    /// How many words have been refused because the queue was full, so the UI
    /// can say so instead of leaving the user to wonder. Cleared by `removeAll`.
    private(set) var rejectedByCapacity = 0

    init() {}

    private enum CodingKeys: String, CodingKey {
        case pending, inFlight, rejectedByCapacity
    }

    /// Tolerant decode: a malformed half loads as empty rather than throwing
    /// away the whole queue.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pending = (try? container.decode([AutoAnalysisRequest].self, forKey: .pending)) ?? []
        inFlight = (try? container.decode([AutoAnalysisRequest].self, forKey: .inFlight)) ?? []
        rejectedByCapacity = (try? container.decode(Int.self, forKey: .rejectedByCapacity)) ?? 0
    }

    // MARK: Queries

    var pendingCount: Int { pending.count }
    var inFlightCount: Int { inFlight.count }
    /// Everything still owed work — what the UI reports as "queued".
    var outstandingCount: Int { pending.count + inFlight.count }
    var isEmpty: Bool { pending.isEmpty && inFlight.isEmpty }
    var isFull: Bool { outstandingCount >= Self.capacity }

    /// Whether `word` is already waiting or in flight.
    func contains(_ word: String) -> Bool {
        let key = Self.normalizedKey(word)
        guard !key.isEmpty else { return false }
        return pending.contains { Self.normalizedKey($0.word) == key }
            || inFlight.contains { Self.normalizedKey($0.word) == key }
    }

    // MARK: Mutations

    /// Append a word to the tail, refusing empties, duplicates, and overflow.
    @discardableResult
    mutating func enqueue(_ request: AutoAnalysisRequest) -> EnqueueOutcome {
        let key = Self.normalizedKey(request.word)
        guard !key.isEmpty else { return .empty }
        guard !contains(request.word) else { return .duplicate }
        guard !isFull else {
            rejectedByCapacity += 1
            return .full
        }
        pending.append(request)
        return .queued
    }

    /// Take the next word and mark it in flight. Removing it from `pending`
    /// before dispatch is what stops two concurrent workers from analyzing —
    /// and paying for — the same word.
    mutating func dequeue() -> AutoAnalysisRequest? {
        guard !pending.isEmpty else { return nil }
        let next = pending.removeFirst()
        inFlight.append(next)
        return next
    }

    /// Retire a finished word (analyzed, or found already cached).
    mutating func complete(_ request: AutoAnalysisRequest) {
        removeFromInFlight(request)
    }

    /// Give a word another turn after a *completed* attempt failed, consuming
    /// one of its `maxAttempts`. Returns `false` when the word is out of
    /// attempts and has been dropped, so the caller can count it as failed.
    @discardableResult
    mutating func retry(_ request: AutoAnalysisRequest) -> Bool {
        removeFromInFlight(request)
        var next = request
        next.attempts += 1
        guard next.attempts < Self.maxAttempts else { return false }
        pending.append(next)
        return true
    }

    /// Put a word back without consuming an attempt, for work that never got a
    /// verdict (cancellation, or a shutdown mid-request). It returns to the
    /// head so the interrupted word stays first in line.
    mutating func returnToQueue(_ request: AutoAnalysisRequest) {
        removeFromInFlight(request)
        pending.insert(request, at: 0)
    }

    /// Recover work interrupted by app termination: anything recorded as in
    /// flight had no verdict, so it goes back to the head of the queue with its
    /// attempt count untouched. Called once at launch.
    mutating func restoreInFlight() {
        guard !inFlight.isEmpty else { return }
        pending.insert(contentsOf: inFlight, at: 0)
        inFlight.removeAll()
    }

    mutating func removeAll() {
        pending.removeAll()
        inFlight.removeAll()
        rejectedByCapacity = 0
    }

    private mutating func removeFromInFlight(_ request: AutoAnalysisRequest) {
        let key = Self.normalizedKey(request.word)
        inFlight.removeAll { Self.normalizedKey($0.word) == key }
    }

    // MARK: Normalization

    /// Fold a word to its comparison form: strip the zero-width characters and
    /// BOM that AI/OCR sources attach, trim, and lowercase. Identical to the
    /// rule `SavedTermsStore` and `WordExplanationCacheStore` use, so a word
    /// that those two consider one word is one queue entry too.
    static func normalizedKey(_ s: String) -> String {
        String(s.unicodeScalars.filter { ![0x200B, 0x200C, 0x200D, 0xFEFF].contains($0.value) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
