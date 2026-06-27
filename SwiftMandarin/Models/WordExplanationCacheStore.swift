//
//  WordExplanationCacheStore.swift
//  SwiftMandarin
//
//  Persistent cache for AI-generated word explanations. Generating an
//  explanation is slow and (for cloud providers) costs API tokens, so once a
//  word has been explained the result is stored and re-served instantly the
//  next time that word is opened — until the user explicitly regenerates it.
//

import Foundation
import os.log

// MARK: - Cached Entry

/// One persisted AI word explanation plus the metadata needed to key and label
/// it. Entries are keyed by the (normalized word, direction) pair: toggling the
/// interface language flips the language the explanation is written in, so a
/// per-direction key prevents serving a stale-direction explanation.
struct CachedWordExplanation: Codable, Equatable, Sendable {
    /// The exact word that was explained (original casing/script preserved for
    /// display; matching is done on a normalized form).
    let word: String
    let pinyin: String
    /// Direction token from `ExplanationDirection.cacheToken`
    /// (e.g. `"zh>en"` — Chinese word explained in English).
    let directionToken: String
    /// Display name of the provider that generated this explanation.
    let providerName: String
    /// When the explanation was generated, shown so the user can judge staleness.
    let generatedAt: Date
    let result: WordExplanationResult

    init(
        word: String,
        pinyin: String,
        directionToken: String,
        providerName: String,
        generatedAt: Date,
        result: WordExplanationResult
    ) {
        self.word = word
        self.pinyin = pinyin
        self.directionToken = directionToken
        self.providerName = providerName
        self.generatedAt = generatedAt
        self.result = result
    }

    private enum CodingKeys: String, CodingKey {
        case word, pinyin, directionToken, providerName, generatedAt, result
    }

    /// Tolerant decode: only `word` and `result` are essential. A payload
    /// written by an older build (missing a field added later) still loads with
    /// sensible defaults instead of failing — and one bad field never discards
    /// the rest of the entry.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        result = try container.decode(WordExplanationResult.self, forKey: .result)
        pinyin = (try? container.decode(String.self, forKey: .pinyin)) ?? ""
        directionToken = (try? container.decode(String.self, forKey: .directionToken)) ?? ""
        providerName = (try? container.decode(String.self, forKey: .providerName)) ?? ""
        generatedAt = (try? container.decode(Date.self, forKey: .generatedAt))
            ?? Date(timeIntervalSince1970: 0)
    }
}

// MARK: - Cache Store

/// MainActor-isolated cache of word explanations, persisted to a JSON file in
/// Application Support. There is **no capacity limit** — every word the user
/// analyzes is retained, so a batch run's progress is permanent and the
/// "analyzed" count reflects reality rather than a cache ceiling. (An earlier
/// version capped this at 400 entries on an MRU basis, which silently evicted
/// older analyses and made the batch-progress count stick at 400.)
///
/// Two design points keep it fast at thousands of entries: the `lookupIndex`
/// membership set is maintained incrementally (never rebuilt per mutation), and
/// disk writes are coalesced and performed off the main thread.
@Observable
@MainActor
final class WordExplanationCacheStore {
    static let shared = WordExplanationCacheStore()

    /// All cached explanations. Order is insignificant — lookups go through
    /// `lookupIndex` (membership) or a linear scan (single-word reads, rare).
    private(set) var entries: [CachedWordExplanation] = []

    /// O(1) membership set of `"<directionToken>\u{1}<normalizedWord>"`.
    /// Maintained incrementally alongside `entries`: rebuilding it on every
    /// mutation would make a batch over N words O(N²) and saturate the main
    /// thread. Observed (not ignored) so the live "remaining" count updates as
    /// analyses are stored.
    private var lookupIndex: Set<String> = []

    /// O(1) membership set of normalized headwords across ALL directions, so
    /// "does this word have any analysis?" (used by the export count) is O(1)
    /// instead of an O(entries) scan per term.
    private var normalizedWordIndex: Set<String> = []

    /// Legacy UserDefaults key, read once at launch to migrate into the file.
    private let legacyDefaultsKey = "wordExplanationCache"
    /// On-disk JSON store in Application Support.
    private let fileName = "word-explanation-cache.json"

    /// Coalesced + throttled single-writer persistence: a running write task
    /// drains `needsWrite`, collapsing bursts of mutations into at most one
    /// off-main write per `writeThrottle` while still guaranteeing the final
    /// state reaches disk. Throttling matters because a batch over thousands of
    /// words re-encodes the whole (growing) file each write — without it that is
    /// O(n²) bytes of disk I/O.
    private var writeTask: Task<Void, Never>?
    private var needsWrite = false
    private static let writeThrottle: Duration = .seconds(10)

    nonisolated private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "WordExplanationCache")

    private init() {
        load()
    }

    // MARK: Queries

    var count: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    private static func lookupKey(directionToken: String, word: String) -> String {
        "\(directionToken)\u{1}\(normalizedKey(word))"
    }

    private func rebuildLookupIndex() {
        lookupIndex = Set(entries.map { Self.lookupKey(directionToken: $0.directionToken, word: $0.word) })
        normalizedWordIndex = Set(entries.map { Self.normalizedKey($0.word) })
    }

    /// Return a cached explanation for `word` in the given direction, if one
    /// exists. Matching ignores invisible characters and surrounding
    /// whitespace, and is case-insensitive (English headwords).
    func explanation(forWord word: String, directionToken: String) -> CachedWordExplanation? {
        let key = Self.normalizedKey(word)
        return entries.first {
            $0.directionToken == directionToken && Self.normalizedKey($0.word) == key
        }
    }

    /// Whether an explanation is cached for `word` in the given direction.
    /// O(1) via `lookupIndex` — this is the batch hot path.
    func hasExplanation(forWord word: String, directionToken: String) -> Bool {
        lookupIndex.contains(Self.lookupKey(directionToken: directionToken, word: word))
    }

    /// Every cached explanation whose headword matches any of `words` (across
    /// all directions). Used by export to bundle a term's AI analysis: a term's
    /// explanation may be stored under either learning-direction headword, so
    /// callers pass all candidate forms (see `SavedTerm.aiCacheCandidateWords`).
    func explanations(forWords words: [String]) -> [CachedWordExplanation] {
        let keys = Set(words.map(Self.normalizedKey)).subtracting([""])
        guard !keys.isEmpty else { return [] }
        return entries.filter { keys.contains(Self.normalizedKey($0.word)) }
    }

    /// Whether any of `words` has a cached explanation in any direction. O(1) per
    /// word via `normalizedWordIndex` — used by the export count, which would
    /// otherwise scan all entries once per term.
    func hasAnyExplanation(forWords words: [String]) -> Bool {
        for word in words {
            let key = Self.normalizedKey(word)
            if !key.isEmpty && normalizedWordIndex.contains(key) { return true }
        }
        return false
    }

    // MARK: Mutations

    /// Insert or replace the explanation for `(word, directionToken)`. A new
    /// word is appended (O(1) — the batch hot path); re-analyzing an existing
    /// word replaces it in place. There is no capacity trimming.
    func store(
        word: String,
        pinyin: String,
        directionToken: String,
        providerName: String,
        result: WordExplanationResult,
        generatedAt: Date = Date()
    ) {
        let entry = CachedWordExplanation(
            word: word,
            pinyin: pinyin,
            directionToken: directionToken,
            providerName: providerName,
            generatedAt: generatedAt,
            result: result
        )
        upsert(entry)
        scheduleSave()
    }

    /// Merge imported explanations into the cache in a single pass (one save).
    /// Each incoming entry replaces any existing entry with the same
    /// (word, direction) key. Used by vocabulary import so a restore of N
    /// analyses costs one write, not N.
    func merge(_ incoming: [CachedWordExplanation]) {
        guard !incoming.isEmpty else { return }
        for entry in incoming {
            upsert(entry)
        }
        scheduleSave()
    }

    /// Insert `entry`, or replace the existing entry with the same
    /// (word, direction) key in place, keeping `lookupIndex` in lockstep. Does
    /// not persist — callers invoke `scheduleSave()` once after a batch of
    /// upserts.
    private func upsert(_ entry: CachedWordExplanation) {
        let lk = Self.lookupKey(directionToken: entry.directionToken, word: entry.word)
        if lookupIndex.contains(lk) {
            let key = Self.normalizedKey(entry.word)
            if let idx = entries.firstIndex(where: {
                $0.directionToken == entry.directionToken && Self.normalizedKey($0.word) == key
            }) {
                entries[idx] = entry
                return
            }
        }
        entries.append(entry)
        lookupIndex.insert(lk)
        normalizedWordIndex.insert(Self.normalizedKey(entry.word))
    }

    /// Remove the cached explanation for a specific word+direction (e.g. when
    /// its saved term is deleted).
    func remove(word: String, directionToken: String) {
        let key = Self.normalizedKey(word)
        let updated = entries.filter {
            !($0.directionToken == directionToken && Self.normalizedKey($0.word) == key)
        }
        guard updated.count != entries.count else { return }
        entries = updated
        rebuildLookupIndex()
        scheduleSave()
    }

    /// Remove every cached explanation for `word`, regardless of direction.
    func removeAll(forWord word: String) {
        let key = Self.normalizedKey(word)
        let updated = entries.filter { Self.normalizedKey($0.word) != key }
        guard updated.count != entries.count else { return }
        entries = updated
        rebuildLookupIndex()
        scheduleSave()
    }

    func clear() {
        guard !entries.isEmpty else { return }
        entries = []
        lookupIndex = []
        normalizedWordIndex = []
        scheduleSave()
    }

    // MARK: Private

    /// Normalize a word for cache lookup: strip zero-width characters and BOM
    /// (AI/OCR sources attach these), trim whitespace, and lowercase so English
    /// headwords match regardless of capitalization.
    private static func normalizedKey(_ s: String) -> String {
        String(s.unicodeScalars.filter { ![0x200B, 0x200C, 0x200D, 0xFEFF].contains($0.value) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: Persistence (file-backed, coalesced, off the main thread)

    /// Request a persist. Encoding the (potentially large) entries array and
    /// writing it happen off the main thread; writes are coalesced so a batch
    /// that stores thousands of words doesn't re-encode the file thousands of
    /// times on the main actor.
    private func scheduleSave() {
        needsWrite = true
        guard writeTask == nil else { return }
        writeTask = Task { [weak self] in
            guard let self else { return }
            while self.needsWrite {
                self.needsWrite = false
                let snapshot = self.entries      // value-type COW snapshot (cheap)
                let name = self.fileName
                // Encode + write off the main actor; only Sendable values cross.
                _ = await Task.detached(priority: .utility) {
                    Self.writeToDisk(snapshot, fileName: name)
                }.value
                // Throttle: if more mutations arrived, wait so a burst (e.g. a
                // batch run) coalesces into one write per interval instead of
                // re-encoding the whole growing file per word. A trailing write
                // always follows the last mutation, so nothing is lost.
                if self.needsWrite {
                    try? await Task.sleep(for: Self.writeThrottle)
                }
            }
            self.writeTask = nil
        }
    }

    /// Encode and atomically write the cache. Returns whether it succeeded, so
    /// the migration can avoid deleting its source on a failed write.
    @discardableResult
    nonisolated private static func writeToDisk(_ entries: [CachedWordExplanation], fileName: String) -> Bool {
        guard let url = PersistentCodableStore.appSupportFileURL(fileName) else { return false }
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            // The cache is regenerable; a failed write just means a word may be
            // re-analyzed later. Don't crash or block on it.
            log.error("WordExplanationCache write failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func load() {
        // Preferred: the file-backed store.
        if let loaded = PersistentCodableStore.loadArrayFromFile([CachedWordExplanation].self, fileName: fileName) {
            entries = loaded
            rebuildLookupIndex()
            return
        }
        // One-time migration from the old UserDefaults-backed cache (≤ the old
        // 400-entry cap). Adopt it, write it to the file, and only when that
        // write succeeds clear the UserDefaults keys — otherwise leave them so
        // the migration retries next launch rather than losing the data.
        if let legacy = PersistentCodableStore.load([CachedWordExplanation].self, key: legacyDefaultsKey) {
            entries = legacy
            rebuildLookupIndex()
            if Self.writeToDisk(legacy, fileName: fileName) {   // small; fine during init
                UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
                UserDefaults.standard.removeObject(forKey: legacyDefaultsKey + ".backup")
            }
        }
    }
}
