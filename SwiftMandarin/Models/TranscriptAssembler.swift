//
//  TranscriptAssembler.swift
//  SwiftMandarin
//
//  Builds one transcript out of the results a live recognizer delivers.
//
//  `SpeechTranscriber` reports two kinds of result. A *volatile* result is a
//  guess for a stretch of audio, and is delivered again and again as the
//  guess grows ("Where", "Where is", "Where is the"…) and sometimes changes.
//  A *final* result replaces the guesses for its stretch and never changes.
//  Appending every result as it arrives would therefore repeat the sentence
//  many times over.
//
//  So the assembler keeps two things: the finalized segments, in time order,
//  and at most one volatile tail that the next result for that stretch
//  replaces. What was measured (scripts/probe-interpreter.sh speech):
//
//  - English segments carry their own leading space (" I need to buy…"), so
//    joining them verbatim is correct.
//  - Chinese results can contain a stray space before punctuation
//    ("哪里 ？我想"), so spaces next to Chinese text are removed.
//  - A final result's range is not exactly the volatile range it replaces
//    (1.92 s against 1.86 s), so matching is by overlap, never by equality.
//
//  Pure and Foundation-only.
//

import Foundation

nonisolated struct TranscriptAssembler: Sendable {
    /// One stretch of recognized audio. `start`/`end` are seconds from the
    /// start of the turn, or `nil` when the recognizer gave no usable range.
    private struct Segment: Sendable {
        var start: Double?
        var end: Double?
        var text: String
    }

    private var finalized: [Segment] = []
    private var volatile: Segment?

    /// How far apart two range boundaries may be and still count as the same
    /// boundary. Larger than the 60 ms difference measured between a volatile
    /// range and the final that replaces it.
    private static let boundaryTolerance = 0.25

    init() {}

    /// Folds one recognizer result into the transcript.
    ///
    /// - Parameters:
    ///   - text: The result's text, exactly as delivered.
    ///   - isFinal: Whether the recognizer has committed to this text.
    ///   - start: Where the result's audio begins, in seconds, if known.
    ///   - end: Where it ends, in seconds, if known.
    mutating func apply(text: String, isFinal: Bool, start: Double? = nil, end: Double? = nil) {
        let segment = Segment(start: Self.usable(start), end: Self.usable(end), text: text)
        if isFinal {
            applyFinal(segment)
        } else {
            applyVolatile(segment)
        }
    }

    /// Finalized text and the volatile tail, each normalized for display.
    var snapshot: TranscriptSnapshot {
        let finalizedText = Self.normalize(finalized.map(\.text).reduce("", Self.concatenate))
        let volatileText = Self.normalize(volatile?.text ?? "")
        return TranscriptSnapshot(finalized: finalizedText, volatile: volatileText)
    }

    /// The whole transcript: every finalized segment, then whatever tail is
    /// still volatile. A final clears the guess it replaces, so after a clean
    /// finish the tail is normally empty; after a timeout it is the
    /// recognizer's last guess, which is better than dropping the end of the
    /// sentence.
    var text: String {
        snapshot.text
    }

    var isEmpty: Bool {
        text.isEmpty
    }

    mutating func reset() {
        finalized.removeAll()
        volatile = nil
    }

    // MARK: - Applying results

    private mutating func applyFinal(_ segment: Segment) {
        // A final for a stretch that is already finalized replaces it rather
        // than repeating it.
        if let start = segment.start,
           let index = finalized.firstIndex(where: { Self.isSameStretch($0, startingAt: start) }) {
            finalized[index] = segment
        } else if let start = segment.start,
                  let index = finalized.firstIndex(where: { ($0.start ?? -.infinity) > start }) {
            // Results normally arrive in time order; this keeps the
            // transcript in spoken order if one ever does not.
            finalized.insert(segment, at: index)
        } else {
            finalized.append(segment)
        }

        // The guess for this stretch is now obsolete. A tail that begins
        // where this final ends is a guess about later audio and stays.
        if let tail = volatile {
            if let tailStart = tail.start, segment.start != nil, segment.end != nil {
                if Self.isInside(tailStart, segment) {
                    volatile = nil
                }
            } else {
                volatile = nil
            }
        }
    }

    private mutating func applyVolatile(_ segment: Segment) {
        // A late guess about audio that has since been finalized is stale.
        if let start = segment.start, let end = segment.end,
           let finalizedEnd = finalized.compactMap(\.end).max(),
           end <= finalizedEnd + Self.boundaryTolerance,
           finalized.contains(where: { Self.isInside(start, $0) }) {
            return
        }
        volatile = segment
    }

    /// Whether `time` falls inside `segment` rather than at its end, where
    /// the next stretch begins. Two reports of one boundary differ by tens of
    /// milliseconds, so "at its end" means within the tolerance — or within
    /// half the segment, when the segment is shorter than that. Without the
    /// second rule a quarter-second "Hi." would count as ending where it
    /// begins, and be taken for the sentence that follows it.
    private static func isInside(_ time: Double, _ segment: Segment) -> Bool {
        guard let start = segment.start, let end = segment.end, end > start else { return false }
        let margin = min(boundaryTolerance, (end - start) / 2)
        return time > start - boundaryTolerance && time < end - margin
    }

    /// Whether a final that starts at `start` is a second report of
    /// `existing`, rather than the stretch after it.
    private static func isSameStretch(_ existing: Segment, startingAt start: Double) -> Bool {
        guard let existingStart = existing.start, abs(existingStart - start) < boundaryTolerance else {
            return false
        }
        // With no end to go by, the matching start is all there is.
        guard existing.end != nil else { return true }
        return isInside(start, existing)
    }

    private static func usable(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    // MARK: - Joining and normalizing

    /// Joins the finalized text and the volatile tail into one transcript.
    static func join(_ finalized: String, _ volatile: String) -> String {
        normalize(concatenate(finalized, volatile))
    }

    /// Puts two pieces of transcript next to each other, adding a space only
    /// where two words in a spaced script would otherwise run together.
    private static func concatenate(_ left: String, _ right: String) -> String {
        guard let last = left.unicodeScalars.last, let first = right.unicodeScalars.first else {
            return left + right
        }
        let alreadySeparated = last.properties.isWhitespace || first.properties.isWhitespace
        let needsNoSpace = isChineseScalar(last) || isChineseScalar(first) || isClosingPunctuation(first)
        return alreadySeparated || needsNoSpace ? left + right : left + " " + right
    }

    /// Collapses whitespace, removes spaces that touch Chinese text or
    /// Chinese punctuation, and trims the ends.
    static func normalize(_ text: String) -> String {
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(text.unicodeScalars.count)
        var pendingSpace = false

        for scalar in text.unicodeScalars {
            if scalar.properties.isWhitespace {
                pendingSpace = !scalars.isEmpty
                continue
            }
            if pendingSpace, let previous = scalars.last {
                // Chinese is written without spaces, so a space between two
                // Chinese characters, or before Chinese punctuation, is noise
                // from the recognizer. A space between a Chinese character
                // and a Latin word ("用 iPhone 拍照") is kept.
                let bothChinese = isChineseScalar(previous) && isChineseScalar(scalar)
                let touchesChinesePunctuation = isChinesePunctuation(scalar) || isChinesePunctuation(previous)
                if !(bothChinese || touchesChinesePunctuation) {
                    scalars.append(" ")
                }
            }
            pendingSpace = false
            scalars.append(scalar)
        }

        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }

    /// Han ideographs, and the punctuation written with them.
    private static func isChineseScalar(_ scalar: Unicode.Scalar) -> Bool {
        isHanIdeograph(scalar) || isChinesePunctuation(scalar)
    }

    private static func isHanIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,     // CJK Unified Ideographs Extension A
             0x4E00...0x9FFF,     // CJK Unified Ideographs
             0xF900...0xFAFF,     // CJK Compatibility Ideographs
             0x20000...0x2FA1F,   // Extensions B–F and compatibility supplement
             0x30000...0x323AF:   // Extensions G–H
            return true
        default:
            return false
        }
    }

    private static func isChinesePunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3000...0x303F,     // CJK Symbols and Punctuation (。、「」《》…)
             0xFF00...0xFF65,     // Fullwidth forms (，！？：；（）)
             0xFE30...0xFE4F:     // CJK Compatibility Forms
            return true
        case 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x2014:
            // Curly quotes, ellipsis and the long dash are shared with
            // English, where the spacing around them must survive.
            return false
        default:
            return false
        }
    }

    /// Punctuation that attaches to the word before it, in either script.
    private static func isClosingPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case ".", ",", "!", "?", ";", ":", ")", "]", "}", "%", "'", "\"":
            return true
        default:
            return false
        }
    }
}
