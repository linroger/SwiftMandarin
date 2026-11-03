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
/// Two design points keep it fast at thousands of entries: every lookup goes
/// through indexes that are maintained incrementally alongside `entries`
/// (never rebuilt per mutation, never scanned), and disk writes are coalesced
/// and performed off the main thread.
///
/// Loading is the one synchronous step: `init` decodes the JSON file on the
/// main actor the first time `shared` is touched. `PersistentCodableStore`
/// offers no asynchronous load, so the decode stays where it is.
@Observable
@MainActor
final class WordExplanationCacheStore {
    static let shared = WordExplanationCacheStore()

    /// All cached explanations. Order is insignificant — every read resolves
    /// through `positions` or `directionsByWord`, and a removal moves the last
    /// entry into the freed slot rather than shifting the array.
    private(set) var entries: [CachedWordExplanation] = []

    /// Position in `entries` of the entry for each
    /// `"<directionToken>\u{1}<normalizedWord>"` key, so a single-word read is
    /// one dictionary lookup instead of a scan over every entry. Maintained
    /// incrementally: rebuilding it on every mutation would make a batch over
    /// N words O(N²) and saturate the main thread. Observed (not ignored) so
    /// the live "remaining" count updates as analyses are stored.
    private var positions: [String: Int] = [:]

    /// The direction tokens that hold an entry for each normalized headword,
    /// across ALL directions. "Does this word have any analysis?" (the export
    /// count) and "every analysis for this word" (the export itself, once per
    /// term) both resolve from it without touching `entries` — the export of a
    /// large vocabulary used to scan the whole cache once per term.
    private var directionsByWord: [String: Set<String>] = [:]

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
        lookupKey(directionToken: directionToken, normalizedWord: normalizedKey(word))
    }

    private static func lookupKey(directionToken: String, normalizedWord: String) -> String {
        "\(directionToken)\u{1}\(normalizedWord)"
    }

    /// Rebuild both indexes from `entries` after a load. Two entries under one
    /// key would break the position index's invariant (one slot per key), so
    /// the later one wins and the earlier is dropped — a defensive measure;
    /// this store never writes duplicates.
    private func rebuildIndexes() {
        var unique: [CachedWordExplanation] = []
        unique.reserveCapacity(entries.count)
        positions = [:]
        positions.reserveCapacity(entries.count)
        directionsByWord = [:]
        for entry in entries {
            let word = Self.normalizedKey(entry.word)
            let key = Self.lookupKey(directionToken: entry.directionToken, normalizedWord: word)
            if let position = positions[key] {
                unique[position] = entry
            } else {
                positions[key] = unique.count
                unique.append(entry)
                directionsByWord[word, default: []].insert(entry.directionToken)
            }
        }
        if unique.count != entries.count {
            entries = unique
        }
    }

    /// Return a cached explanation for `word` in the given direction, if one
    /// exists. Matching ignores invisible characters and surrounding
    /// whitespace, and is case-insensitive (English headwords). O(1).
    func explanation(forWord word: String, directionToken: String) -> CachedWordExplanation? {
        guard let position = positions[Self.lookupKey(directionToken: directionToken, word: word)] else {
            return nil
        }
        return entries[position]
    }

    /// Whether an explanation is cached for `word` in the given direction.
    /// O(1) via `positions` — this is the batch hot path.
    func hasExplanation(forWord word: String, directionToken: String) -> Bool {
        positions[Self.lookupKey(directionToken: directionToken, word: word)] != nil
    }

    /// Every cached explanation whose headword matches any of `words` (across
    /// all directions). Used by export to bundle a term's AI analysis: a term's
    /// explanation may be stored under either learning-direction headword, so
    /// callers pass all candidate forms (see `SavedTerm.aiCacheCandidateWords`).
    /// O(matches) via `directionsByWord`; the result keeps storage order, as
    /// the former scan did.
    func explanations(forWords words: [String]) -> [CachedWordExplanation] {
        var seen = Set<String>()
        var found: [Int] = []
        for word in words {
            let key = Self.normalizedKey(word)
            guard !key.isEmpty, seen.insert(key).inserted,
                  let directions = directionsByWord[key] else { continue }
            for direction in directions {
                if let position = positions[Self.lookupKey(directionToken: direction, normalizedWord: key)] {
                    found.append(position)
                }
            }
        }
        return found.sorted().map { entries[$0] }
    }

    /// Whether any of `words` has a cached explanation in any direction. O(1)
    /// per word via `directionsByWord` — used by the export count, which would
    /// otherwise scan all entries once per term.
    func hasAnyExplanation(forWords words: [String]) -> Bool {
        for word in words {
            let key = Self.normalizedKey(word)
            if !key.isEmpty && directionsByWord[key] != nil { return true }
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
    /// (word, direction) key in place, keeping both indexes in lockstep. O(1).
    /// Does not persist — callers invoke `scheduleSave()` once after a batch
    /// of upserts.
    private func upsert(_ entry: CachedWordExplanation) {
        let word = Self.normalizedKey(entry.word)
        let key = Self.lookupKey(directionToken: entry.directionToken, normalizedWord: word)
        if let position = positions[key] {
            entries[position] = entry
            return
        }
        positions[key] = entries.count
        entries.append(entry)
        directionsByWord[word, default: []].insert(entry.directionToken)
    }

    /// Remove the cached explanation for a specific word+direction (e.g. when
    /// its saved term is deleted).
    func remove(word: String, directionToken: String) {
        guard removeEntry(normalizedWord: Self.normalizedKey(word), directionToken: directionToken) else {
            return
        }
        scheduleSave()
    }

    /// Remove every cached explanation for `word`, regardless of direction.
    func removeAll(forWord word: String) {
        let key = Self.normalizedKey(word)
        guard let directions = directionsByWord[key] else { return }
        for direction in directions {
            removeEntry(normalizedWord: key, directionToken: direction)
        }
        scheduleSave()
    }

    /// Remove one entry in O(1): the last entry moves into the freed slot
    /// (order is insignificant) and both indexes follow. Returns `false` when
    /// there was nothing under that key. Does not persist.
    @discardableResult
    private func removeEntry(normalizedWord: String, directionToken: String) -> Bool {
        let key = Self.lookupKey(directionToken: directionToken, normalizedWord: normalizedWord)
        guard let position = positions.removeValue(forKey: key) else { return false }
        let lastPosition = entries.count - 1
        if position != lastPosition {
            let moved = entries[lastPosition]
            entries[position] = moved
            positions[Self.lookupKey(directionToken: moved.directionToken, word: moved.word)] = position
        }
        entries.removeLast()
        if var directions = directionsByWord[normalizedWord] {
            directions.remove(directionToken)
            directionsByWord[normalizedWord] = directions.isEmpty ? nil : directions
        }
        return true
    }

    func clear() {
        guard !entries.isEmpty else { return }
        entries = []
        positions = [:]
        directionsByWord = [:]
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
            rebuildIndexes()
            return
        }
        // One-time migration from the old UserDefaults-backed cache (≤ the old
        // 400-entry cap). Adopt it, write it to the file, and only when that
        // write succeeds clear the UserDefaults keys — otherwise leave them so
        // the migration retries next launch rather than losing the data.
        if let legacy = PersistentCodableStore.load([CachedWordExplanation].self, key: legacyDefaultsKey) {
            entries = legacy
            rebuildIndexes()
            if Self.writeToDisk(legacy, fileName: fileName) {   // small; fine during init
                UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
                UserDefaults.standard.removeObject(forKey: legacyDefaultsKey + ".backup")
            }
        }
    }
}
