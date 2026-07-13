#if VOCABULARY_PAGING_CHECKS
import Foundation

private struct CheckFailure: Error {
    let message: String
}

private var checksRun = 0

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

private func runChecks() throws {
    let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let middle = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let last = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let missing = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
    let visibleOrder = [last, first, middle]

    try expect(
        VocabularyPaging.uniqueIDs([last, first, last, middle, first]),
        visibleOrder,
        "Duplicate IDs are removed without changing visible order"
    )

    try expect(
        VocabularyPaging.neighborID(currentID: first, offset: 1, orderedIDs: visibleOrder),
        middle,
        "Next follows the supplied visible order"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: first, offset: -1, orderedIDs: visibleOrder),
        last,
        "Previous follows the supplied visible order"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: last, offset: -1, orderedIDs: visibleOrder),
        nil,
        "Previous from the first visible item does not wrap"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: middle, offset: 1, orderedIDs: visibleOrder),
        nil,
        "Next from the last visible item does not wrap"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: missing, offset: 1, orderedIDs: visibleOrder),
        nil,
        "Missing current IDs fail safely"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: nil, offset: 1, orderedIDs: visibleOrder),
        nil,
        "Nil selection fails safely"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: first, offset: 0, orderedIDs: visibleOrder),
        nil,
        "A zero offset is not a page transition"
    )
    try expect(
        VocabularyPaging.neighborID(currentID: first, offset: 1, orderedIDs: []),
        nil,
        "Empty collections fail safely"
    )
    try expect(
        VocabularyPaging.pageWindowIndices(currentID: last, orderedIDs: visibleOrder),
        [0, 1],
        "The first page window contains only the current and next pages"
    )
    try expect(
        VocabularyPaging.pageWindowIndices(currentID: first, orderedIDs: visibleOrder),
        [0, 1, 2],
        "A middle page window contains only the previous, current, and next pages"
    )
    try expect(
        VocabularyPaging.pageWindowIndices(currentID: middle, orderedIDs: visibleOrder),
        [1, 2],
        "The final page window contains only the previous and current pages"
    )
    try expect(
        VocabularyPaging.pageWindowIndices(currentID: missing, orderedIDs: visibleOrder),
        [],
        "A missing current page produces no stale window"
    )

    let largeOrder = (0..<7_000).map { index in
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }
    try expect(
        VocabularyPaging.pageWindowIndices(currentID: largeOrder[3_500], orderedIDs: largeOrder),
        [3_499, 3_500, 3_501],
        "Large sessions retain the constant three-page window"
    )
    try expect(
        VocabularyPaging.reconciledID(
            preferredID: middle,
            initialID: first,
            orderedIDs: visibleOrder
        ),
        middle,
        "A surviving preferred page is preserved"
    )
    try expect(
        VocabularyPaging.reconciledID(
            preferredID: missing,
            initialID: first,
            orderedIDs: visibleOrder
        ),
        first,
        "A missing preferred page falls back to the initial page"
    )
    try expect(
        VocabularyPaging.reconciledID(
            preferredID: missing,
            initialID: missing,
            orderedIDs: [middle]
        ),
        middle,
        "A removed initial page falls back to the first survivor"
    )
    try expect(
        VocabularyPaging.reconciledID(
            preferredID: missing,
            initialID: first,
            orderedIDs: []
        ),
        nil,
        "An empty session has no fabricated fallback"
    )

    let survivorsAfterDeletingCurrent = [last, middle]
    try expect(
        VocabularyPaging.resolvedIDAfterTransition(
            visibleID: first,
            requestedID: middle,
            settledID: last,
            currentID: first,
            orderedIDs: survivorsAfterDeletingCurrent
        ),
        middle,
        "A deleted visible page yields to the live requested destination"
    )
    try expect(
        VocabularyPaging.resolvedIDAfterTransition(
            visibleID: last,
            requestedID: middle,
            settledID: middle,
            currentID: middle,
            orderedIDs: survivorsAfterDeletingCurrent
        ),
        last,
        "A surviving UIKit page remains authoritative after cancellation"
    )
    try expect(
        VocabularyPaging.resolvedIDAfterTransition(
            visibleID: first,
            requestedID: first,
            settledID: middle,
            currentID: last,
            orderedIDs: survivorsAfterDeletingCurrent
        ),
        middle,
        "A surviving settled selection wins when visible and requested pages were deleted"
    )
    try expect(
        VocabularyPaging.resolvedIDAfterTransition(
            visibleID: first,
            requestedID: first,
            settledID: first,
            currentID: last,
            orderedIDs: survivorsAfterDeletingCurrent
        ),
        last,
        "The prior current page wins when newer candidates were deleted"
    )
    try expect(
        VocabularyPaging.resolvedIDAfterTransition(
            visibleID: first,
            requestedID: first,
            settledID: first,
            currentID: first,
            orderedIDs: survivorsAfterDeletingCurrent
        ),
        last,
        "The first survivor is used when every candidate was deleted"
    )
    try expect(
        VocabularyPaging.resolvedIDAfterTransition(
            visibleID: first,
            requestedID: middle,
            settledID: last,
            currentID: first,
            orderedIDs: []
        ),
        nil,
        "An empty post-transition session cannot retain a stale controller"
    )
    try expect(
        VocabularyPaging.pageWindowIDs(
            currentID: last,
            orderedIDs: survivorsAfterDeletingCurrent
        ),
        Set(survivorsAfterDeletingCurrent),
        "Post-deletion cache retention contains only live bounded neighbors"
    )
}

@main
private struct VocabularyPagingChecksRunner {
    static func main() {
        do {
            try runChecks()
            print("Vocabulary paging checks passed (\(checksRun)/\(checksRun))")
        } catch let failure as CheckFailure {
            fputs("Vocabulary paging check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("Vocabulary paging checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
