#if AUTO_ANALYSIS_CHECKS
import Foundation

private struct CheckFailure: Error {
    let message: String
}

// Single-threaded runner, so the counter needs no synchronization; the
// annotation just satisfies strict concurrency (the other contract runners do
// the same).
nonisolated(unsafe) private var checksRun = 0

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

private func expectTrue(_ condition: Bool, _ message: String) throws {
    checksRun += 1
    guard condition else {
        throw CheckFailure(message: message)
    }
}

private func request(_ word: String) -> AutoAnalysisRequest {
    AutoAnalysisRequest(word: word)
}

/// Automatic analysis dispatches paid provider requests with nobody watching,
/// so the queue's rules are the safety rail: one request per word, a bounded
/// backlog, a bounded number of retries, and no work silently lost when the app
/// is quit mid-request. These checks state those rules as invariants rather
/// than trusting the coordinator to re-derive them.
private func runChecks() throws {

    // MARK: One word is one entry

    var queue = AutoAnalysisQueue()
    try expect(queue.enqueue(request("苹果")), .queued, "A new word is queued")
    try expect(queue.enqueue(request("苹果")), .duplicate, "The same word is not queued twice")
    try expect(queue.outstandingCount, 1, "A duplicate does not grow the queue")

    // The fold matches SavedTermsStore/WordExplanationCacheStore: case,
    // surrounding whitespace, and the zero-width characters AI and OCR sources
    // attach must not create a second paid request for one word.
    try expect(queue.enqueue(request("  苹果 ")), .duplicate, "Whitespace does not make a new word")
    try expect(queue.enqueue(request("苹\u{200B}果")), .duplicate, "A zero-width space does not make a new word")
    try expect(queue.enqueue(request("Charge")), .queued, "A different word is queued")
    try expect(queue.enqueue(request("charge")), .duplicate, "Case does not make a new word")
    try expect(queue.outstandingCount, 2, "Only genuinely distinct words are queued")

    // MARK: Nothing empty is ever dispatched

    try expect(queue.enqueue(request("")), .empty, "An empty word is refused")
    try expect(queue.enqueue(request("   ")), .empty, "A whitespace-only word is refused")
    try expect(queue.enqueue(request("\u{FEFF}")), .empty, "A word of only invisible characters is refused")
    try expect(queue.outstandingCount, 2, "Refused words do not enter the queue")

    // MARK: FIFO dispatch, and a dispatched word cannot be dispatched twice

    let first = queue.dequeue()
    try expect(first?.word, "苹果", "The oldest word is dispatched first")
    try expect(queue.pendingCount, 1, "A dispatched word leaves the pending half")
    try expect(queue.inFlightCount, 1, "A dispatched word is recorded in flight")
    try expect(queue.outstandingCount, 2, "A dispatched word is still outstanding")
    try expect(queue.enqueue(request("苹果")), .duplicate, "A word in flight is still a duplicate")
    try expectTrue(queue.contains("苹果"), "An in-flight word is reported as present")

    queue.complete(first!)
    try expect(queue.inFlightCount, 0, "A completed word leaves the in-flight half")
    try expect(queue.outstandingCount, 1, "A completed word is no longer outstanding")
    try expectTrue(!queue.contains("苹果"), "A completed word is no longer present")
    try expect(queue.enqueue(request("苹果")), .queued, "A completed word may be queued again later")

    // MARK: Retries are bounded, so a failing word cannot bill forever

    var retryQueue = AutoAnalysisQueue()
    try expect(retryQueue.enqueue(request("失败")), .queued, "The failing word is queued")
    var dispatches = 0
    while let inFlight = retryQueue.dequeue() {
        dispatches += 1
        try expectTrue(dispatches <= AutoAnalysisQueue.maxAttempts + 1, "Retries terminate")
        if !retryQueue.retry(inFlight) { break }
    }
    try expect(dispatches, AutoAnalysisQueue.maxAttempts, "A word is dispatched at most maxAttempts times")
    try expectTrue(retryQueue.isEmpty, "An exhausted word is dropped from both halves")

    // A retry goes to the tail, so one stubborn word cannot starve the words
    // saved behind it.
    var orderQueue = AutoAnalysisQueue()
    orderQueue.enqueue(request("first"))
    orderQueue.enqueue(request("second"))
    let retried = orderQueue.dequeue()!
    try expectTrue(orderQueue.retry(retried), "The first failure still has attempts left")
    try expect(orderQueue.dequeue()?.word, "second", "A retried word does not jump ahead of waiting words")

    // MARK: Work without a verdict costs no attempt and keeps its place

    var cancelQueue = AutoAnalysisQueue()
    cancelQueue.enqueue(request("cancelled"))
    cancelQueue.enqueue(request("behind"))
    let cancelled = cancelQueue.dequeue()!
    cancelQueue.returnToQueue(cancelled)
    try expect(cancelQueue.inFlightCount, 0, "A returned word leaves the in-flight half")
    let redispatched = cancelQueue.dequeue()!
    try expect(redispatched.word, "cancelled", "An interrupted word keeps its place at the head")
    try expect(redispatched.attempts, 0, "An interrupted word consumes no attempt")

    // MARK: A quit mid-request loses nothing

    var crashQueue = AutoAnalysisQueue()
    crashQueue.enqueue(request("inflight-a"))
    crashQueue.enqueue(request("inflight-b"))
    crashQueue.enqueue(request("waiting"))
    _ = crashQueue.dequeue()
    _ = crashQueue.dequeue()
    let encoded = try JSONEncoder().encode(crashQueue)
    var recovered = try JSONDecoder().decode(AutoAnalysisQueue.self, from: encoded)
    try expect(recovered, crashQueue, "A queue round-trips through its persisted form")
    try expect(recovered.inFlightCount, 2, "The interrupted requests survive persistence")
    recovered.restoreInFlight()
    try expect(recovered.inFlightCount, 0, "Recovery empties the in-flight half")
    try expect(recovered.pendingCount, 3, "Recovery loses no word")
    try expect(recovered.dequeue()?.word, "inflight-a", "Recovered words keep their original order")
    try expect(recovered.dequeue()?.word, "inflight-b", "Recovered words are retried before newer ones")

    // MARK: A bulk import cannot enqueue an unbounded bill

    var fullQueue = AutoAnalysisQueue()
    for index in 0..<AutoAnalysisQueue.capacity {
        try expect(fullQueue.enqueue(request("word-\(index)")), .queued, "Word \(index) fits under the ceiling")
    }
    try expectTrue(fullQueue.isFull, "The queue reports itself full at capacity")
    try expect(fullQueue.enqueue(request("overflow")), .full, "A word past the ceiling is refused")
    try expect(fullQueue.rejectedByCapacity, 1, "A refusal is counted so it can be reported")
    try expect(fullQueue.outstandingCount, AutoAnalysisQueue.capacity, "A refusal never evicts an accepted word")
    try expectTrue(!fullQueue.contains("overflow"), "A refused word is not silently queued")

    // Dispatching does not free a slot — an in-flight word is still outstanding
    // — but completing one does.
    let dispatched = fullQueue.dequeue()!
    try expect(fullQueue.enqueue(request("overflow-2")), .full, "An in-flight word still occupies its slot")
    fullQueue.complete(dispatched)
    try expect(fullQueue.enqueue(request("overflow-2")), .queued, "A completed word frees its slot")

    fullQueue.removeAll()
    try expectTrue(fullQueue.isEmpty, "Clearing empties both halves")
    try expect(fullQueue.rejectedByCapacity, 0, "Clearing resets the refusal count")

    // MARK: A queue written by an older build still loads

    let partial = Data(#"{"pending":[{"word":"legacy"}]}"#.utf8)
    let legacy = try JSONDecoder().decode(AutoAnalysisQueue.self, from: partial)
    try expect(legacy.pendingCount, 1, "A payload missing later fields still loads its words")
    try expect(legacy.inFlightCount, 0, "A missing in-flight half defaults to empty")
    try expect(legacy.rejectedByCapacity, 0, "A missing refusal count defaults to zero")
    try expect(legacy.pending.first?.attempts, 0, "A word with no recorded attempts starts fresh")
    try expect(legacy.pending.first?.pinyin, "", "A word with no recorded reading loads with none")
    try expectTrue(legacy.pending.first?.context == nil, "A word with no recorded gloss loads with none")

    // MARK: Sense hints survive the round trip

    var hintQueue = AutoAnalysisQueue()
    hintQueue.enqueue(AutoAnalysisRequest(word: "洗澡", pinyin: "xǐ zǎo", context: "to take a bath"))
    let hintData = try JSONEncoder().encode(hintQueue)
    let hintRecovered = try JSONDecoder().decode(AutoAnalysisQueue.self, from: hintData)
    try expect(hintRecovered.pending.first?.pinyin, "xǐ zǎo", "The reading sent as a sense hint is preserved")
    try expect(hintRecovered.pending.first?.context, "to take a bath", "The gloss sent as context is preserved")
}

@main
private struct AutoAnalysisQueueChecksRunner {
    static func main() {
        do {
            try runChecks()
            print("Auto-analysis queue checks passed (\(checksRun)/\(checksRun))")
        } catch let failure as CheckFailure {
            fputs("Auto-analysis queue check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("Auto-analysis queue checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
