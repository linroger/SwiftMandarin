#if LEARNING_DIRECTION_CHECKS
import Foundation

private struct CheckFailure: Error {
    let message: String
}

// Single-threaded runner, so the counter needs no synchronization; the
// annotation just satisfies strict concurrency (the AI prompt runner does the
// same).
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

/// The two learner modes must be mirror images. The reverse mode ("Mandarin
/// speaker learning English") was added long after the forward one, and the
/// failure mode it kept hitting was partial reversal: the text would swap
/// while a learner aid, a font role, or a reader stayed pinned to the original
/// audience. These checks state the symmetry as an invariant rather than
/// trusting each call site to remember it.
private func runChecks() throws {
    let forward = LearningContext(learningIsChinese: true)   // English speaker → Mandarin
    let reverse = LearningContext(learningIsChinese: false)  // Mandarin speaker → English

    // MARK: Roles are complementary, never both or neither

    try expect(forward.nativeIsChinese, false, "An English speaker's native language is not Chinese")
    try expect(reverse.nativeIsChinese, true, "A Mandarin speaker's native language is Chinese")
    try expectTrue(
        forward.learningIsChinese != forward.nativeIsChinese,
        "Studied and native language are never the same side (forward)"
    )
    try expectTrue(
        reverse.learningIsChinese != reverse.nativeIsChinese,
        "Studied and native language are never the same side (reverse)"
    )

    // MARK: Mirroring is an involution

    try expect(forward.mirrored, reverse, "Mirroring the forward mode yields the reverse mode")
    try expect(reverse.mirrored, forward, "Mirroring the reverse mode yields the forward mode")
    try expect(forward.mirrored.mirrored, forward, "Mirroring twice is the identity")

    // MARK: Primary / secondary swap, and only swap

    let 中 = "学习"
    let en = "study"

    try expect(forward.primary(chinese: 中, english: en), 中, "An English speaker studies the Chinese side")
    try expect(forward.secondary(chinese: 中, english: en), en, "…and reads the English gloss")
    try expect(reverse.primary(chinese: 中, english: en), en, "A Mandarin speaker studies the English side")
    try expect(reverse.secondary(chinese: 中, english: en), 中, "…and reads the 中文 gloss")

    // The mirror property itself: swapping the learner swaps exactly these two
    // answers and introduces nothing new. This is what stops a future edit from
    // "fixing" one direction into a state the other cannot reach.
    try expect(
        reverse.primary(chinese: 中, english: en),
        forward.secondary(chinese: 中, english: en),
        "The reverse learner's headword is the forward learner's gloss"
    )
    try expect(
        reverse.secondary(chinese: 中, english: en),
        forward.primary(chinese: 中, english: en),
        "The reverse learner's gloss is the forward learner's headword"
    )

    // A pair is exhaustive: between them, primary and secondary always cover
    // both sides, so no direction can silently drop one.
    for context in [forward, reverse] {
        try expect(
            Set([context.primary(chinese: 中, english: en), context.secondary(chinese: 中, english: en)]),
            Set([中, en]),
            "Both sides remain reachable (learningIsChinese: \(context.learningIsChinese))"
        )
    }

    // MARK: Learner aids belong to the learner who needs them

    // Pinyin teaches how to READ Chinese. Offering it to a native Mandarin
    // reader is noise over their own language, and withholding it from a
    // Mandarin learner removes the app's main scaffold — so it must track the
    // studied language exactly, not the content or a display preference.
    try expect(forward.showsPinyinAffordances, true, "A Mandarin learner gets pinyin")
    try expect(reverse.showsPinyinAffordances, false, "A native Mandarin reader does not")
    try expectTrue(
        forward.showsPinyinAffordances != reverse.showsPinyinAffordances,
        "Pinyin affordances are exclusive to one direction"
    )

    // The tappable word-by-word reader annotates the studied language, so it
    // segments Chinese for one audience and English for the other.
    try expect(forward.interactiveReaderIsChinese, true, "A Mandarin learner taps Chinese words")
    try expect(reverse.interactiveReaderIsChinese, false, "A Mandarin speaker taps English words")

    // MARK: Every derived answer flips with the learner

    // Stated as a loop so a newly added accessor that forgets to mirror shows
    // up here rather than as a half-reversed screen.
    let accessors: [(String, (LearningContext) -> Bool)] = [
        ("learningIsChinese", { $0.learningIsChinese }),
        ("nativeIsChinese", { $0.nativeIsChinese }),
        ("showsPinyinAffordances", { $0.showsPinyinAffordances }),
        ("interactiveReaderIsChinese", { $0.interactiveReaderIsChinese }),
    ]
    for (name, read) in accessors {
        try expectTrue(
            read(forward) != read(reverse),
            "\(name) must differ between the two directions"
        )
        try expect(
            read(forward.mirrored),
            read(reverse),
            "\(name) on the mirrored forward mode equals the reverse mode"
        )
    }
}

@main
private struct LearningDirectionChecksRunner {
    static func main() {
        do {
            try runChecks()
            print("Learning direction checks passed (\(checksRun)/\(checksRun))")
        } catch let failure as CheckFailure {
            fputs("Learning direction check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("Learning direction checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
