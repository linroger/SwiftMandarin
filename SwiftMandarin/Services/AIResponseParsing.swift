//
//  AIResponseParsing.swift
//  SwiftMandarin
//
//  Provider-neutral parsing for AI model responses.
//
//  Two failure modes used to reach the learner verbatim, because translation
//  and OCR cleanup were raw-string-in / raw-string-out contracts with nothing
//  between the model and the UI:
//
//  1. Reasoning leakage. "Thinking" models (DeepSeek, Qwen, Zhipu, Kimi,
//     MiniMax, Doubao, and their Ollama equivalents) interleave a chain of
//     thought with the answer as `<think>…</think>`. Gateways differ: some emit
//     a matched pair, some stream the reasoning first and emit only the closing
//     tag, and a truncated response can open the tag and never close it. Every
//     one of those variants used to be displayed, spoken by text-to-speech, and
//     written into translation history.
//  2. Free-form answers. A plain-string contract gives a model that decides to
//     summarize, outline, or annotate the passage nowhere else to put that text,
//     so the commentary lands where the answer should be. Asking for a one-field
//     JSON envelope gives the answer exactly one slot, and anything written
//     around that slot is discarded by construction.
//
//  Kept Foundation-only so the exact production behavior can be exercised by
//  `scripts/test-ai-prompt-contracts.sh` without a model, credentials, or an
//  Apple Intelligence-capable device.
//

import Foundation

// MARK: - Generic Response Sanitizing

/// Cleanups that apply to any model completion, whatever it was asked for.
enum AIResponseSanitizer {

    /// One reasoning wrapper, as a pair of regular expressions.
    private struct ReasoningDelimiter: Sendable {
        let open: String
        let close: String
    }

    /// Reasoning wrappers emitted inline by thinking models. ASCII angle
    /// brackets cover the OpenAI-compatible providers; the triangle brackets
    /// cover MiniMax, which uses `◁think▷ … ◁/think▷`.
    private static let reasoningDelimiters: [ReasoningDelimiter] = {
        let names = [
            "think", "thinking", "thought", "thoughts",
            "reason", "reasoning", "reflection", "scratchpad",
        ]
        return names.flatMap { name in
            [
                ReasoningDelimiter(
                    open: "<\\s*\(name)\\b[^>]*>",
                    close: "<\\s*/\\s*\(name)\\s*>"
                ),
                ReasoningDelimiter(
                    open: "◁\\s*\(name)\\s*▷",
                    close: "◁\\s*/\\s*\(name)\\s*▷"
                ),
            ]
        }
    }()

    /// Remove any inline chain of thought from a completion.
    ///
    /// Handles all three shapes seen in the wild:
    /// - a matched `<think>…</think>` pair anywhere in the text;
    /// - a stray closing tag, which means everything before it was reasoning;
    /// - a stray opening tag, which means everything after it is reasoning
    ///   (the response was cut off before the model finished thinking).
    ///
    /// Returning an empty string is a meaningful result: it says the provider
    /// spent the whole response on reasoning and never produced an answer, and
    /// callers surface that as a failure instead of showing the reasoning.
    static func strippingReasoning(_ text: String) -> String {
        // Every delimiter opens with one of these two characters, so the
        // overwhelmingly common clean response skips all the pattern work.
        guard text.contains("<") || text.contains("◁") else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var result = text
        for delimiter in reasoningDelimiters {
            // Matched pairs first, so the stray-tag rules below only ever see
            // a genuinely unbalanced tag.
            result = result.replacingOccurrences(
                of: "(?s)\(delimiter.open).*?\(delimiter.close)",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            if let close = lastRange(of: delimiter.close, in: result) {
                result = String(result[close.upperBound...])
            }
            if let open = result.range(
                of: delimiter.open,
                options: [.regularExpression, .caseInsensitive]
            ) {
                result = String(result[..<open.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strip a surrounding markdown code fence, with or without a language tag.
    static func strippingCodeFence(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        if let firstNewline = trimmed.firstIndex(of: "\n") {
            trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
        } else {
            trimmed = String(trimmed.dropFirst(3))
        }
        if let fence = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<fence.lowerBound])
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Quote pairs a model may wrap a whole answer in.
    private static let quotePairs: [(open: Character, close: Character)] = [
        ("\"", "\""), ("“", "”"), ("'", "'"), ("‘", "’"), ("「", "」"), ("『", "』"),
    ]

    /// Remove quotation marks that wrap the entire text.
    ///
    /// Only strips when the closing mark appears nowhere inside, so a passage
    /// that legitimately quotes several speakers keeps its punctuation.
    static func strippingWrappingQuotes(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let first = trimmed.first, let last = trimmed.last else { return trimmed }
        guard quotePairs.contains(where: { $0.open == first && $0.close == last }) else { return trimmed }
        let inner = trimmed.dropFirst().dropLast()
        guard !inner.contains(last) else { return trimmed }
        return String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The last range matching `pattern`, searched forwards.
    ///
    /// `NSString.range(of:options:)` refuses to combine `.backwards` with
    /// `.regularExpression`, so walk the matches instead.
    private static func lastRange(of pattern: String, in text: String) -> Range<String.Index>? {
        var searchStart = text.startIndex
        var last: Range<String.Index>?
        while searchStart < text.endIndex,
              let found = text.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive],
                range: searchStart..<text.endIndex
              ) {
            last = found
            searchStart = found.upperBound > found.lowerBound
                ? found.upperBound
                : text.index(after: found.lowerBound)
        }
        return last
    }
}

// MARK: - One-Field JSON Envelopes

/// Reads a named string out of the one-field JSON envelope the app asks every
/// provider for, tolerating the ways models actually deviate from it.
enum AIStructuredResponse {

    /// Read a one-field envelope out of a completion.
    ///
    /// The ladder is ordered by confidence, and deliberately consults the
    /// original text as well as the reasoning-free one: an answer that
    /// legitimately contains a reasoning-like tag (translating a sentence
    /// *about* `<think>`, say) survives intact, because a strict parse of the
    /// untouched response beats a salvage of the stripped one.
    static func envelopeValue(anyOf keys: [String], reasoningFree: String, original: String) -> String? {
        parsedField(anyOf: keys, in: reasoningFree)
            ?? parsedField(anyOf: keys, in: original)
            ?? salvagedField(anyOf: keys, in: reasoningFree)
            ?? salvagedField(anyOf: keys, in: original)
    }

    /// The first strictly valid JSON object in `text` that carries a non-empty
    /// value under one of `keys` — the whole object, so callers can read the
    /// companion fields that travel with the answer.
    ///
    /// Prefers the reasoning-free text but falls back to the original for the
    /// same reason `envelopeValue` does.
    static func envelopeObject(
        containingAnyOf keys: [String],
        reasoningFree: String,
        original: String
    ) -> [String: Any]? {
        parsedObject(containingAnyOf: keys, in: reasoningFree)
            ?? parsedObject(containingAnyOf: keys, in: original)
    }

    /// The first non-empty string value among `keys` in `object`.
    static func string(anyOf keys: [String], in object: [String: Any]) -> String? {
        for key in keys {
            guard let value = object[key] as? String,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            return value
        }
        return nil
    }

    /// The first array value among `keys` in `object`.
    static func array(anyOf keys: [String], in object: [String: Any]) -> [Any]? {
        for key in keys {
            if let value = object[key] as? [Any] { return value }
        }
        return nil
    }

    /// The first non-empty value among `keys`, taken from the first strictly
    /// valid JSON object in `text` that carries one.
    ///
    /// Scanning past a failed candidate matters because models sometimes
    /// precede the object with prose containing a brace.
    private static func parsedField(anyOf keys: [String], in text: String) -> String? {
        parsedObject(containingAnyOf: keys, in: text).flatMap { string(anyOf: keys, in: $0) }
    }

    private static func parsedObject(containingAnyOf keys: [String], in text: String) -> [String: Any]? {
        for candidate in jsonObjectCandidates(in: text) {
            guard let data = candidate.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  string(anyOf: keys, in: object) != nil else { continue }
            return object
        }
        return nil
    }

    /// Whether the text is a bare JSON object or array rather than prose.
    ///
    /// Structured data here means the model returned an envelope shape the
    /// reader could not use, or echoed the request payload back. Either way it
    /// is machine output, and showing it to a learner is worse than an error.
    static func looksLikeMachineData(_ text: String, envelopeKeys: [String]) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
                || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else { return false }
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            // Unparseable but envelope-shaped: still machine output, not prose.
            return envelopeKeys.contains { trimmed.contains("\"\($0)\"") }
        }
        return object is [String: Any] || object is [Any]
    }

    // MARK: Object scanning

    /// Balanced, string-aware JSON object substrings, in source order.
    ///
    /// String awareness is what makes this safe for translated text: braces and
    /// quotation marks inside the answer never end the object early. Bounded
    /// because only the first few candidates can plausibly be the envelope, and
    /// each one costs a parse attempt.
    private static func jsonObjectCandidates(in text: String, limit: Int = 8) -> [String] {
        let characters = Array(text)
        var candidates: [String] = []
        var start = 0
        while start < characters.count, candidates.count < limit {
            guard characters[start] == "{" else {
                start += 1
                continue
            }
            if let end = balancedObjectEnd(in: characters, from: start) {
                candidates.append(String(characters[start...end]))
            }
            start += 1
        }
        return candidates
    }

    /// Index of the `}` closing the object that opens at `start`, or `nil` when
    /// the object never closes (a truncated response).
    private static func balancedObjectEnd(in characters: [Character], from start: Int) -> Int? {
        var depth = 0
        var inString = false
        var escaped = false
        var index = start
        while index < characters.count {
            let character = characters[index]
            if inString {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inString = false }
            } else {
                switch character {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 { return index }
                default: break
                }
            }
            index += 1
        }
        return nil
    }

    // MARK: Salvage

    /// Recover a field from an envelope that will not parse.
    ///
    /// Two real cases: the response ran out of output tokens mid-string, and
    /// the model wrote literal line breaks inside the JSON string instead of
    /// escaping them. Both leave the answer intact up to the cut, and a partial
    /// answer is far more useful to a learner than raw JSON.
    static func salvagedField(anyOf keys: [String], in text: String) -> String? {
        let characters = Array(text)
        for key in keys {
            guard let keyRange = text.range(of: "\"\(key)\"") else { continue }
            var index = text.distance(from: text.startIndex, to: keyRange.upperBound)
            index = skippingWhitespace(in: characters, from: index)
            guard index < characters.count, characters[index] == ":" else { continue }
            index = skippingWhitespace(in: characters, from: index + 1)
            guard index < characters.count, characters[index] == "\"" else { continue }
            index += 1

            var body: [Character] = []
            var escaped = false
            while index < characters.count {
                let character = characters[index]
                if escaped {
                    body.append(character)
                    escaped = false
                } else if character == "\\" {
                    body.append(character)
                    escaped = true
                } else if character == "\"" {
                    break
                } else {
                    body.append(character)
                }
                index += 1
            }

            if let decoded = jsonStringBodyDecoded(String(body)),
               !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return decoded
            }
        }
        return nil
    }

    private static func skippingWhitespace(in characters: [Character], from index: Int) -> Int {
        var result = index
        while result < characters.count, characters[result].isWhitespace {
            result += 1
        }
        return result
    }

    /// Interpret the body of a JSON string literal, repairing the two damage
    /// patterns a truncation or a sloppy model leaves behind: unescaped control
    /// characters, and an escape sequence cut in half at the end.
    private static func jsonStringBodyDecoded(_ body: String) -> String? {
        var repaired = body
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        if let partialUnicode = repaired.range(
            of: "\\\\u[0-9a-fA-F]{0,3}$",
            options: .regularExpression
        ) {
            repaired.removeSubrange(partialUnicode)
        }
        while repaired.hasSuffix("\\") {
            repaired.removeLast()
        }
        guard let data = "[\"\(repaired)\"]".data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else { return nil }
        return array.first
    }
}

// MARK: - Errors

enum AITranslationResponseError: LocalizedError, Equatable {
    /// The provider produced no target-language text: an empty completion, a
    /// response consumed entirely by reasoning, or structured data with no
    /// translation in it.
    case noTranslation

    var errorDescription: String? {
        switch self {
        case .noTranslation:
            return String(localized: "The model returned commentary instead of a translation. Try again, or choose a different model in Settings → AI.", bundle: .appLanguage)
        }
    }
}

// MARK: - Translation Result

/// One word or phrase from the source worth studying, as chosen by the model.
///
/// `id` is view identity only; it is regenerated on decode rather than
/// persisted, matching `ExampleSentenceResult` and friends.
struct AITranslationKeyTerm: Identifiable, Equatable, Codable, Sendable {
    let id = UUID()
    /// The term exactly as it appears in the source.
    let term: String
    /// Pinyin with tone marks for a Chinese term; empty for English.
    let reading: String
    /// Short gloss in the learner's native language, for the sense used here.
    let meaning: String
    /// One sentence on the nuance, structure, or trap worth remembering.
    let note: String

    private enum CodingKeys: String, CodingKey {
        case term, reading, meaning, note
    }

    static func == (lhs: AITranslationKeyTerm, rhs: AITranslationKeyTerm) -> Bool {
        lhs.term == rhs.term && lhs.meaning == rhs.meaning
    }
}

/// A translation plus the study notes that explain it.
///
/// The notes are always optional: the contract tells the model to return
/// nothing when a passage is too easy to need them, so an empty `explanation`
/// and `keyTerms` is a correct result, not a failure.
struct AITranslationResult: Equatable, Codable, Sendable {
    let translation: String
    let explanation: String
    let keyTerms: [AITranslationKeyTerm]

    init(translation: String, explanation: String = "", keyTerms: [AITranslationKeyTerm] = []) {
        self.translation = translation
        self.explanation = explanation
        self.keyTerms = keyTerms
    }

    /// Whether there is anything to show in a notes panel.
    var hasNotes: Bool { !explanation.isEmpty || !keyTerms.isEmpty }
}

// MARK: - Translation Response Parser

/// Turns one raw provider completion into the clean target-language string the
/// app displays, speaks, saves to history, and stores in vocabulary.
enum AITranslationResponseParser {

    /// Field names the translation envelope may arrive under, most trustworthy
    /// first. `translation` is the contract; the rest absorb the neighboring
    /// shapes models fall back to when they echo a familiar schema from
    /// training instead of the one they were given.
    static let fieldNames = [
        "translation", "translatedText", "translated_text",
        "targetText", "target_text", "target", "output", "result",
    ]

    /// Field names the study-note fields may arrive under.
    static let explanationFieldNames = ["explanation", "notes", "note", "translationNotes", "translation_notes"]
    static let keyTermFieldNames = ["keyTerms", "key_terms", "terms", "vocabulary", "keyVocabulary"]

    /// At most this many key terms reach the UI, matching the ceiling the
    /// prompt states for a long passage. A model that ignores the scale rule
    /// gets truncated rather than flooding the panel.
    static let maximumKeyTerms = 8

    /// Parse a provider response into the translation and study notes it was
    /// asked for.
    ///
    /// - Throws: `AITranslationResponseError.noTranslation` when no translation
    ///   survives, so the caller shows an actionable error rather than the
    ///   model's own prose.
    static func result(from raw: String) throws -> AITranslationResult {
        let withoutReasoning = AIResponseSanitizer.strippingReasoning(raw)

        if let object = AIStructuredResponse.envelopeObject(
            containingAnyOf: fieldNames,
            reasoningFree: withoutReasoning,
            original: raw
        ) {
            let translation = sanitizedEnvelopeValue(
                AIStructuredResponse.string(anyOf: fieldNames, in: object) ?? ""
            )
            if !translation.isEmpty {
                return AITranslationResult(
                    translation: translation,
                    explanation: sanitizedEnvelopeValue(
                        AIStructuredResponse.string(anyOf: explanationFieldNames, in: object) ?? ""
                    ),
                    keyTerms: keyTerms(in: object)
                )
            }
        }

        // A damaged or envelope-less response can still carry a usable
        // translation; the notes are optional, so losing them is acceptable
        // where losing the translation would not be.
        return AITranslationResult(translation: try translation(from: raw))
    }

    /// Parse a provider response into just the translation.
    static func translation(from raw: String) throws -> String {
        let withoutReasoning = AIResponseSanitizer.strippingReasoning(raw)

        if let field = AIStructuredResponse.envelopeValue(
            anyOf: fieldNames,
            reasoningFree: withoutReasoning,
            original: raw
        ) {
            let cleaned = sanitizedEnvelopeValue(field)
            if !cleaned.isEmpty { return cleaned }
        }

        // Older or non-compliant models still answer with a bare string; keep
        // them working rather than failing them outright.
        let cleaned = sanitizedFreeformText(withoutReasoning)
        guard !cleaned.isEmpty,
              !AIStructuredResponse.looksLikeMachineData(cleaned, envelopeKeys: fieldNames) else {
            throw AITranslationResponseError.noTranslation
        }
        return cleaned
    }

    /// Read the key-term list, tolerating the neighboring field names models
    /// reach for and dropping entries with no term or no meaning — a row that
    /// teaches nothing is worse than a shorter list.
    static func keyTerms(in object: [String: Any]) -> [AITranslationKeyTerm] {
        guard let rawItems = AIStructuredResponse.array(anyOf: keyTermFieldNames, in: object) else { return [] }
        var seen = Set<String>()
        var result: [AITranslationKeyTerm] = []
        for item in rawItems {
            guard result.count < maximumKeyTerms, let entry = item as? [String: Any] else { continue }
            let term = sanitizedEnvelopeValue(
                AIStructuredResponse.string(anyOf: ["term", "word", "phrase", "text"], in: entry) ?? ""
            )
            let meaning = sanitizedEnvelopeValue(
                AIStructuredResponse.string(anyOf: ["meaning", "definition", "gloss", "translation"], in: entry) ?? ""
            )
            guard !term.isEmpty, !meaning.isEmpty, seen.insert(term).inserted else { continue }
            result.append(
                AITranslationKeyTerm(
                    term: term,
                    reading: sanitizedEnvelopeValue(
                        AIStructuredResponse.string(anyOf: ["reading", "pinyin", "pronunciation"], in: entry) ?? ""
                    ),
                    meaning: meaning,
                    note: sanitizedEnvelopeValue(
                        AIStructuredResponse.string(anyOf: ["note", "usage", "explanation", "nuance"], in: entry) ?? ""
                    )
                )
            )
        }
        return result
    }

    /// Clean an answer that already arrived in a typed field — Apple's guided
    /// generation, or a parsed JSON envelope. The field is already scoped to
    /// the answer, so this only removes wrappers a model put *inside* it.
    static func sanitizedEnvelopeValue(_ text: String) -> String {
        let unfenced = AIResponseSanitizer.strippingCodeFence(text)
        return AIResponseSanitizer.strippingWrappingQuotes(unfenced)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clean a free-form completion from a model that ignored the envelope.
    ///
    /// Label and note stripping only runs here: inside the envelope those
    /// patterns are far more likely to be genuine translated content (a source
    /// line reading `翻译：…` really does translate to `Translation: …`).
    static func sanitizedFreeformText(_ text: String) -> String {
        var result = AIResponseSanitizer.strippingCodeFence(text)
        result = strippingLeadingLabel(result)
        result = strippingTrailingNotes(result)
        result = AIResponseSanitizer.strippingWrappingQuotes(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Free-form cleanup

    /// The colon that closes a label, plus the trailing markdown emphasis a
    /// bolded label carries (`**Translation:**`). The lookahead keeps a
    /// genuinely bold opening word — `Translation: **now**` — from losing its
    /// markers.
    private static let labelTerminator = "\\s*\\**\\s*[:：]\\s*(?:\\*{1,2}(?=\\s|$))?\\s*"

    /// Announcement labels a model puts in front of an answer it was told not
    /// to label. Anchored at the start and required to end in a colon, so a
    /// translation that merely happens to contain the word survives.
    private static let leadingLabelPatterns = [
        "^\\**\\s*(?:here(?:'s| is| are)\\s+)?(?:the\\s+|your\\s+)?"
            + "(?:english|chinese|mandarin|simplified\\s+chinese|target(?:\\s+language)?)?\\s*"
            + "(?:translation|translated\\s+text|translation\\s+result|output)"
            + labelTerminator,
        "^\\**\\s*(?:英文|英语|中文|简体中文)?\\s*(?:翻译|译文|翻译结果|译文如下)"
            + labelTerminator,
    ]

    /// Remove one leading announcement label, but never the whole answer.
    private static func strippingLeadingLabel(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in leadingLabelPatterns {
            guard let match = trimmed.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ), match.lowerBound == trimmed.startIndex else { continue }
            let remainder = String(trimmed[match.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty { return remainder }
        }
        return trimmed
    }

    /// Openers of a trailing translator's note or afterword.
    private static let trailingNotePattern =
        "^\\s*[*_>(（\\[【-]*\\s*"
        + "(?:note|notes|translator'?s?\\s+note|explanation|remark|remarks|"
        + "注|注释|译注|说明|备注|翻译说明)"
        + "\\s*[*_]*\\s*[:：]"

    /// A horizontal rule the model uses to fence off its afterword.
    private static let trailingRulePattern = "^\\s*(?:-{3,}|_{3,}|\\*{3,})\\s*$"

    /// Drop trailing note lines the model appended after the translation.
    ///
    /// Works upward from the end and stops at the first line that is part of
    /// the answer, so a note-like sentence in the middle of a passage is never
    /// touched, and a response that is *only* a note is left alone for the
    /// caller to reject.
    private static func strippingTrailingNotes(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        var lastKept = lines.count
        var index = lines.count - 1
        while index >= 0 {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                index -= 1
                continue
            }
            let isNote = line.range(of: trailingNotePattern, options: [.regularExpression, .caseInsensitive]) != nil
            let isRule = line.range(of: trailingRulePattern, options: .regularExpression) != nil
            guard isNote || isRule else { break }
            lastKept = index
            index -= 1
        }
        guard lastKept < lines.count else { return text }
        lines.removeSubrange(lastKept...)
        let remainder = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // A response consisting only of notes is not a translation; hand the
        // original back so the caller's emptiness check reports the failure.
        return remainder.isEmpty ? text : remainder
    }
}

// MARK: - OCR Cleanup Response Parser

/// Reads the corrected passage out of an OCR-cleanup response.
///
/// This output is not decoration: it replaces the scanned text the rest of the
/// photo pipeline segments, translates, and offers as vocabulary. A model that
/// answered with "Here is the corrected text:" plus a summary used to have that
/// commentary adopted wholesale as the learner's source material.
enum AITextCleanupResponseParser {

    /// Field names the cleanup envelope may arrive under.
    static let fieldNames = [
        "text", "cleanedText", "cleaned_text",
        "correctedText", "corrected_text", "content", "output", "result",
    ]

    /// The corrected passage, or `nil` when the response carried none.
    ///
    /// The free-form fallback deliberately does **less** cleanup than the
    /// translation one: it removes only a fence and wrapping quotes, never
    /// leading labels or trailing notes. A scanned page really can open with
    /// `翻译：` or end with `注：` — that is exercise text, and silently deleting
    /// it would corrupt the learner's source material far more damagingly than
    /// leaving a stray preface they can see and edit.
    static func cleanedText(from raw: String) -> String? {
        let withoutReasoning = AIResponseSanitizer.strippingReasoning(raw)

        if let field = AIStructuredResponse.envelopeValue(
            anyOf: fieldNames,
            reasoningFree: withoutReasoning,
            original: raw
        ) {
            let cleaned = AITranslationResponseParser.sanitizedEnvelopeValue(field)
            if !cleaned.isEmpty { return cleaned }
        }

        let cleaned = AITranslationResponseParser.sanitizedEnvelopeValue(withoutReasoning)
        guard !cleaned.isEmpty,
              !AIStructuredResponse.looksLikeMachineData(cleaned, envelopeKeys: fieldNames) else {
            return nil
        }
        return cleaned
    }
}
