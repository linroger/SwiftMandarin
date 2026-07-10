//
//  ReaderStore.swift
//  SwiftMandarin
//
//  Library of texts for the immersive Reader: pasted articles, texts the
//  user wrote in, and AI-generated graded stories. Texts can be long, so the
//  store is file-backed (Application Support JSON, like the word-explanation
//  cache) rather than UserDefaults-backed, with coalesced off-main writes.
//

import Foundation
import os.log

// MARK: - Reader Text Model

/// One text in the Reader library. `content` holds the full body; paragraphs
/// are derived by splitting on newlines so both pasted articles and generated
/// stories (blank-line separated) segment naturally.
struct ReaderText: Identifiable, Codable, Equatable, Hashable {

    /// Where the text came from — drives the small badge on library cards.
    enum Source: String, Codable {
        case pasted
        case written
        case generated
    }

    let id: UUID
    var title: String
    var content: String
    var source: Source
    let dateAdded: Date
    /// Index of the paragraph the user last had focused, for resume-on-open.
    var lastReadParagraphIndex: Int
    /// When the text was last opened in a reading session (nil = never opened).
    var dateLastOpened: Date?

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        source: Source,
        dateAdded: Date = Date(),
        lastReadParagraphIndex: Int = 0,
        dateLastOpened: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.dateAdded = dateAdded
        self.lastReadParagraphIndex = lastReadParagraphIndex
        self.dateLastOpened = dateLastOpened
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, content, source, dateAdded, lastReadParagraphIndex, dateLastOpened
    }

    /// Tolerant decode: only `content` really matters — a payload written by an
    /// older/newer build (missing a field, unknown source raw value) still
    /// loads with sensible defaults instead of dropping the user's text.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        source = (try? c.decode(Source.self, forKey: .source)) ?? .pasted
        dateAdded = (try? c.decode(Date.self, forKey: .dateAdded)) ?? Date()
        lastReadParagraphIndex = (try? c.decode(Int.self, forKey: .lastReadParagraphIndex)) ?? 0
        dateLastOpened = try? c.decode(Date.self, forKey: .dateLastOpened)
    }

    // MARK: Derived reading structure

    /// Non-empty paragraphs of the text, in order. Splitting on single
    /// newlines means blank-line-separated stories and line-per-paragraph
    /// pastes both produce the same clean paragraph list.
    var paragraphs: [String] {
        content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Short single-line preview for library cards.
    var excerpt: String {
        let collapsed = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return String(collapsed.prefix(160))
    }

    /// 0…1 reading progress. A never-opened text is 0; the last paragraph of
    /// an opened text is 1. Single-paragraph texts count as fully read once
    /// opened (there is nowhere further to advance).
    var progressFraction: Double {
        let count = paragraphs.count
        guard count > 0, dateLastOpened != nil else { return 0 }
        guard count > 1 else { return 1 }
        let clamped = min(max(lastReadParagraphIndex, 0), count - 1)
        return Double(clamped) / Double(count - 1)
    }

    /// Whether this text is study material in Chinese. Uses a proportion
    /// threshold rather than "contains any CJK": an English article that
    /// mentions one Chinese name (e.g. "…in Beijing (北京)…") must NOT be routed
    /// through the Chinese ruby pipeline for a Mandarin-native learner.
    var isChineseContent: Bool {
        ReaderStore.isPredominantlyChinese(content)
    }

    /// Approximate length: CJK characters for Chinese texts (each carries
    /// roughly a word of meaning), whitespace-separated tokens for English.
    var wordCount: Int {
        if isChineseContent {
            return content.unicodeScalars.reduce(into: 0) { count, scalar in
                if scalar.isCJKIdeograph { count += 1 }
            }
        }
        return content.split(whereSeparator: \.isWhitespace).count
    }
}

// MARK: - Vocabulary Coverage

/// Shared "how much of this text do I already know?" estimate, used by the
/// library cards and the reading-session toolbar. Chinese texts are segmented
/// with the NL tokenizer; English texts are split on non-letters. A word
/// counts as known when a saved term's matching-language side equals it.
enum ReaderVocabularyCoverage {

    /// Percentage (0–100) of unique words in `content` present in the user's
    /// saved vocabulary, or nil when the text has no countable words.
    @MainActor
    static func knownPercent(for content: String) -> Int? {
        let isChinese = ReaderStore.isPredominantlyChinese(content)
        let terms = SavedTermsStore.shared.terms

        let knownWords: Set<String>
        let uniqueWords: Set<String>
        if isChinese {
            knownWords = Set(terms.map(\.chineseSide).filter { !$0.isEmpty })
            uniqueWords = Set(
                ChineseTextAnalyzer.shared.segmentWords(content)
                    .map(\.text)
                    .filter { $0.containsCJK }
            )
        } else {
            knownWords = Set(
                terms.map { $0.englishSide.lowercased().trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            )
            uniqueWords = Set(
                content.lowercased()
                    .split { !($0.isLetter || $0 == "'") }
                    .map(String.init)
            )
        }

        guard !uniqueWords.isEmpty else { return nil }
        let knownCount = uniqueWords.lazy.filter { knownWords.contains($0) }.count
        return Int((Double(knownCount) / Double(uniqueWords.count) * 100).rounded())
    }
}

// MARK: - Reader Store

/// MainActor-isolated library of Reader texts, persisted to a JSON file in
/// Application Support (texts can be far too large for UserDefaults). Writes
/// are coalesced and performed off the main thread, following the
/// `WordExplanationCacheStore` pattern: paragraph-by-paragraph progress
/// updates during a reading session collapse into at most one disk write per
/// throttle interval, with a trailing write guaranteeing the final state lands.
@Observable
@MainActor
final class ReaderStore {

    static let shared = ReaderStore()

    /// A text is treated as Chinese study material only when CJK ideographs
    /// make up a meaningful share of its letter-bearing characters — not merely
    /// because one appears. This keeps an English article that quotes a Chinese
    /// name out of the Chinese ruby/coverage pipeline (which would be wrong for
    /// a Mandarin-native learner reading English). The 20% threshold cleanly
    /// separates genuinely-Chinese text (well above) from incidental mentions
    /// (well below).
    nonisolated static func isPredominantlyChinese(_ content: String) -> Bool {
        var cjk = 0
        var meaningful = 0
        for scalar in content.unicodeScalars {
            if scalar.isCJKIdeograph {
                cjk += 1
                meaningful += 1
            } else if CharacterSet.letters.contains(scalar) {
                meaningful += 1
            }
        }
        guard meaningful > 0 else { return false }
        return Double(cjk) / Double(meaningful) >= 0.2
    }

    /// All texts, kept sorted newest-opened first (never-opened texts sort by
    /// the date they were added), so the library and Home's "continue
    /// reading" surface both read straight off the front.
    private(set) var texts: [ReaderText] = []

    /// On-disk JSON store in Application Support.
    private let fileName = "reader-texts.json"

    /// Coalesced single-writer persistence (see `WordExplanationCacheStore`):
    /// a running write task drains `needsWrite`, collapsing bursts of
    /// mutations (e.g. progress updates while paging through paragraphs) into
    /// at most one off-main write per `writeThrottle`.
    private var writeTask: Task<Void, Never>?
    private var needsWrite = false
    private static let writeThrottle: Duration = .seconds(2)

    nonisolated private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "ReaderStore")

    private init() {
        load()
    }

    // MARK: Queries

    var isEmpty: Bool { texts.isEmpty }

    func text(withID id: UUID) -> ReaderText? {
        texts.first { $0.id == id }
    }

    /// The text most recently opened in a reading session, if any — the Home
    /// screen's "continue reading" entry point.
    var mostRecentlyRead: ReaderText? {
        texts.first { $0.dateLastOpened != nil }
    }

    // MARK: Mutations

    /// Add a fully formed text to the library.
    func add(_ text: ReaderText) {
        texts.append(text)
        resort()
        scheduleSave()
    }

    /// Create and add a text; returns it so callers can open it immediately.
    @discardableResult
    func add(title: String, content: String, source: ReaderText.Source) -> ReaderText {
        let text = ReaderText(title: title, content: content, source: source)
        add(text)
        return text
    }

    func remove(_ text: ReaderText) {
        remove(id: text.id)
    }

    func remove(id: UUID) {
        let updated = texts.filter { $0.id != id }
        guard updated.count != texts.count else { return }
        texts = updated
        scheduleSave()
    }

    /// Record that the user's focus moved to `paragraphIndex`, so the session
    /// resumes there next time. Does not reorder the library (only opening
    /// does), keeping list identity stable while the user reads.
    func updateProgress(id: UUID, paragraphIndex: Int) {
        guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
        let clamped = max(paragraphIndex, 0)
        guard texts[index].lastReadParagraphIndex != clamped else { return }
        texts[index].lastReadParagraphIndex = clamped
        scheduleSave()
    }

    /// Stamp a text as just-opened, moving it to the front of the library.
    func markOpened(id: UUID) {
        guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
        texts[index].dateLastOpened = Date()
        resort()
        scheduleSave()
    }

    // MARK: Private

    private func resort() {
        texts.sort {
            ($0.dateLastOpened ?? $0.dateAdded) > ($1.dateLastOpened ?? $1.dateAdded)
        }
    }

    // MARK: Persistence (file-backed, coalesced, off the main thread)

    /// Request a persist. Encoding and writing happen off the main actor;
    /// writes are coalesced so rapid progress updates don't re-encode the
    /// whole (potentially large) library once per paragraph.
    private func scheduleSave() {
        needsWrite = true
        guard writeTask == nil else { return }
        writeTask = Task { [weak self] in
            guard let self else { return }
            while self.needsWrite {
                self.needsWrite = false
                let snapshot = self.texts       // value-type COW snapshot (cheap)
                let name = self.fileName
                // Encode + write off the main actor; only Sendable values cross.
                _ = await Task.detached(priority: .utility) {
                    Self.writeToDisk(snapshot, fileName: name)
                }.value
                // Throttle: a burst of mutations coalesces into one write per
                // interval; a trailing write always follows the last mutation.
                if self.needsWrite {
                    try? await Task.sleep(for: Self.writeThrottle)
                }
            }
            self.writeTask = nil
        }
    }

    /// Encode and atomically write the library.
    @discardableResult
    nonisolated private static func writeToDisk(_ texts: [ReaderText], fileName: String) -> Bool {
        guard let url = PersistentCodableStore.appSupportFileURL(fileName) else { return false }
        do {
            let data = try JSONEncoder().encode(texts)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            // Reading progress is recoverable and texts remain in memory for
            // the session; log rather than crash on a failed write.
            log.error("ReaderStore write failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func load() {
        if let loaded = PersistentCodableStore.loadArrayFromFile([ReaderText].self, fileName: fileName) {
            texts = loaded
            resort()
        }
    }
}
