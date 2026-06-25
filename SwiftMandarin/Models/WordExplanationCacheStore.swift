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

// MARK: - Cached Entry

/// One persisted AI word explanation plus the metadata needed to key and label
/// it. Entries are keyed by the (normalized word, direction) pair: toggling the
/// interface language flips the language the explanation is written in, so a
/// per-direction key prevents serving a stale-direction explanation.
struct CachedWordExplanation: Codable, Equatable {
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

/// MainActor-isolated, UserDefaults-backed cache of word explanations. Bounded
/// to `maxEntries` on a most-recently-used basis so it can't grow without
/// limit. Persistence is performed once per mutation (never per element), to
/// avoid the write-amplification that an O(n) save loop would cause.
@Observable
@MainActor
final class WordExplanationCacheStore {
    static let shared = WordExplanationCacheStore()

    /// Most-recently-used first; trimmed from the tail when over capacity.
    /// The `didSet` keeps `lookupIndex` in lockstep so membership tests never
    /// rescan the array — critical because the batch UI calls `hasExplanation`
    /// once per saved term on every render, which would otherwise be
    /// O(terms × entries) and saturate the main thread during a batch run.
    private(set) var entries: [CachedWordExplanation] = [] {
        didSet { rebuildLookupIndex() }
    }

    /// O(1) membership set of `"<directionToken>\u{1}<normalizedWord>"` for the
    /// current `entries`. Observed (not ignored) so the live "remaining" count
    /// updates as analyses are stored.
    private var lookupIndex: Set<String> = []

    private let saveKey = "wordExplanationCache"
    private let maxEntries = 400

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

    // MARK: Mutations

    /// Insert or replace the explanation for `(word, directionToken)`, moving it
    /// to the front (most-recently-used) and trimming the cache to capacity.
    func store(
        word: String,
        pinyin: String,
        directionToken: String,
        providerName: String,
        result: WordExplanationResult,
        generatedAt: Date = Date()
    ) {
        let key = Self.normalizedKey(word)
        var updated = entries.filter {
            !($0.directionToken == directionToken && Self.normalizedKey($0.word) == key)
        }
        updated.insert(
            CachedWordExplanation(
                word: word,
                pinyin: pinyin,
                directionToken: directionToken,
                providerName: providerName,
                generatedAt: generatedAt,
                result: result
            ),
            at: 0
        )
        if updated.count > maxEntries {
            updated.removeLast(updated.count - maxEntries)
        }
        entries = updated
        save()
    }

    /// Merge imported explanations into the cache in a single pass (one save).
    /// Each incoming entry replaces any existing entry with the same
    /// (word, direction) key and is promoted to the front (most-recently-used),
    /// then the cache is trimmed to capacity. Used by vocabulary import so a
    /// restore of N analyses costs one write, not N.
    func merge(_ incoming: [CachedWordExplanation]) {
        guard !incoming.isEmpty else { return }
        var result = entries
        // Newest-imported-first: iterate in reverse so the first incoming entry
        // ends up at the front after each prepend.
        for entry in incoming.reversed() {
            let key = Self.normalizedKey(entry.word)
            result.removeAll {
                $0.directionToken == entry.directionToken && Self.normalizedKey($0.word) == key
            }
            result.insert(entry, at: 0)
        }
        if result.count > maxEntries {
            result.removeLast(result.count - maxEntries)
        }
        entries = result
        save()
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
        save()
    }

    /// Remove every cached explanation for `word`, regardless of direction.
    func removeAll(forWord word: String) {
        let key = Self.normalizedKey(word)
        let updated = entries.filter { Self.normalizedKey($0.word) != key }
        guard updated.count != entries.count else { return }
        entries = updated
        save()
    }

    func clear() {
        guard !entries.isEmpty else { return }
        entries = []
        save()
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

    private func save() {
        PersistentCodableStore.save(entries, key: saveKey)
    }

    private func load() {
        if let decoded = PersistentCodableStore.load([CachedWordExplanation].self, key: saveKey) {
            entries = decoded
        }
    }
}
