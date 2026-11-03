//
//  PersistentCodableStore.swift
//  SwiftMandarin
//
//  Shared loader/saver for the app's UserDefaults-backed JSON stores
//  (vocabulary, history, learning progress, activity). Decode failures are
//  logged instead of silently discarded, and a last-known-good snapshot is
//  kept under "<key>.backup" so a corrupted payload can't wipe user data.
//
//  Collections decode resiliently: a single corrupt row is dropped rather than
//  discarding the entire store. Combined with each model's tolerant
//  `init(from:)` (field-level defaults), this means a schema change or one bad
//  element degrades gracefully instead of losing everything.
//

import Foundation
import os.log

/// Wraps a single element so a decode failure yields `nil` instead of aborting
/// the whole array/dictionary decode.
private struct FailableDecodable<Element: Decodable>: Decodable {
    let value: Element?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(Element.self)
    }
}

enum PersistentCodableStore {

    nonisolated private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "Persistence")

    // MARK: - Load

    /// Resilient array load: decodes element-by-element and drops any row that
    /// fails to decode, so one corrupt entry can't discard the collection.
    /// More specialized than the generic overload, so array call sites bind here.
    static func load<Element: Decodable>(_ type: [Element].Type, key: String) -> [Element]? {
        loadData(key: key) { data in
            try JSONDecoder().decode([FailableDecodable<Element>].self, from: data).compactMap(\.value)
        }
    }

    /// Resilient dictionary load: drops only the entries whose value fails.
    static func load<Value: Decodable>(_ type: [String: Value].Type, key: String) -> [String: Value]? {
        loadData(key: key) { data in
            try JSONDecoder().decode([String: FailableDecodable<Value>].self, from: data).compactMapValues(\.value)
        }
    }

    /// Load and decode a non-collection value stored under `key`.
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        loadData(key: key) { data in try JSONDecoder().decode(T.self, from: data) }
    }

    /// Shared primary→backup decode pipeline.
    ///
    /// On a successful primary decode the payload is snapshotted to
    /// "<key>.backup". If the primary fails to decode, the backup is tried; when
    /// the backup succeeds it is promoted back to the primary key.
    private static func loadData<R>(key: String, decode: (Data) throws -> R) -> R? {
        let defaults = UserDefaults.standard
        let backupKey = key + ".backup"

        if let data = defaults.data(forKey: key) {
            do {
                let value = try decode(data)
                // Snapshot the known-good payload, but only when it changed: every
                // launch used to rewrite a full copy of every store.
                if defaults.data(forKey: backupKey) != data {
                    defaults.set(data, forKey: backupKey)
                }
                return value
            } catch {
                log.error("Decode failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public) — trying backup")
            }
        }

        if let backup = defaults.data(forKey: backupKey) {
            do {
                let value = try decode(backup)
                log.notice("Restored \(key, privacy: .public) from last-known-good backup")
                defaults.set(backup, forKey: key)
                return value
            } catch {
                log.error("Backup decode also failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return nil
    }

    // MARK: - Save (coalesced, off the main thread)

    /// One queued write: encodes the snapshot it captured. Kept as a closure so
    /// the encode itself can run on a background thread later, while the
    /// snapshot is taken at the moment `save` was called.
    private typealias PendingWrite = @Sendable () -> Result<Data, Error>

    /// Writes waiting to be flushed, newest value per key. Every store hands
    /// `save` its *entire* contents, so the latest snapshot for a key makes
    /// every earlier one redundant — a burst of mutations costs one encode.
    ///
    /// Explicitly main-actor rather than relying on the target's default
    /// isolation: the contract runners compile this file standalone without
    /// that default, where unannotated static state is a strict-concurrency
    /// error.
    @MainActor private static var pendingWrites: [String: PendingWrite] = [:]
    @MainActor private static var flushTask: Task<Void, Never>?

    /// How long a burst may keep extending before it is written. Long enough
    /// to fold an import's thousands of `add` calls (each of which used to
    /// re-encode the whole vocabulary synchronously — O(n²) on the main thread,
    /// and the shape of "the app hangs" during a big import) into one write;
    /// short enough that nothing of consequence is lost to a crash.
    nonisolated private static let coalescingDelay: Duration = .milliseconds(250)

    /// Persist `value` under `key`. The encode and the `UserDefaults` write
    /// happen off the main thread shortly afterwards; mutations arriving in
    /// the meantime replace the pending snapshot rather than queueing behind
    /// it. Anything still pending is written synchronously when the app
    /// resigns active or terminates (`flushPendingWritesNow`), so the deferral
    /// never costs data across a normal quit.
    @MainActor
    static func save<T: Codable & Sendable>(_ value: T, key: String) {
        pendingWrites[key] = {
            Result { try JSONEncoder().encode(value) }
        }
        scheduleFlush()
    }

    @MainActor
    private static func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task {
            // Cancelled only by `flushPendingWritesNow`, which has already
            // drained the batch and may have let a newer `save` schedule its
            // own task; clearing `flushTask` here would orphan that one.
            do { try await Task.sleep(for: coalescingDelay) } catch { return }
            flushTask = nil
            await flushPendingWrites()
        }
    }

    /// Every batch is encoded and written on this one serial queue, in the
    /// order batches leave `pendingWrites`. Two independent background writes
    /// could finish out of order — an older snapshot of a store landing after
    /// a newer one and silently reverting the user's last edit — and a quit
    /// had no way to wait for a write that was still encoding.
    nonisolated private static let writeQueue = DispatchQueue(
        label: "com.rogerlin.SwiftMandarin.PersistentCodableStore.write",
        qos: .utility
    )

    /// Encode and write everything pending, off the main thread, and wait for
    /// it to land.
    @MainActor
    static func flushPendingWrites() async {
        let batch = pendingWrites
        pendingWrites = [:]
        guard !batch.isEmpty else { return }
        // The enqueue happens synchronously, on the main actor, in the same
        // step that empties `pendingWrites` — so queue order is snapshot order.
        // Hopping to another task first would let a later synchronous flush
        // reach the queue ahead of this older batch.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writeQueue.async {
                write(batch)
                continuation.resume()
            }
        }
    }

    /// Write everything pending right now, on the calling thread. For the
    /// moments the process may not get another turn — going to the background,
    /// terminating — where a deferred write would be a lost write. One encode
    /// per dirty store, so it is cheap enough for those moments and never runs
    /// in steady state.
    @MainActor
    static func flushPendingWritesNow() {
        flushTask?.cancel()
        flushTask = nil
        let batch = pendingWrites
        pendingWrites = [:]
        // Runs even for an empty batch: `sync` on the serial queue first waits
        // out any batch a scheduled flush already handed over, so a write
        // still encoding at quit is not dropped, and nothing older can land
        // after this newer snapshot.
        writeQueue.sync { write(batch) }
    }

    nonisolated private static func write(_ batch: [String: PendingWrite]) {
        for (key, encode) in batch {
            switch encode() {
            case let .success(data):
                UserDefaults.standard.set(data, forKey: key)
            case let .failure(error):
                // Logged rather than swallowed: an encode failure here means a
                // store's in-memory state will not survive relaunch.
                log.error("Encode failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - File-backed (for large stores)

    /// URL for a JSON store kept in Application Support, creating the directory
    /// if needed. Used for stores too large for UserDefaults (which is loaded
    /// wholesale into memory at launch), e.g. the word-explanation cache.
    /// `nonisolated`/pure so it is safe to call from a background write task.
    nonisolated static func appSupportFileURL(_ name: String) -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else {
            log.error("Could not resolve Application Support directory for \(name, privacy: .public)")
            return nil
        }
        return dir.appendingPathComponent(name)
    }

    /// Resilient array load from an Application Support JSON file: missing file
    /// → nil; a single corrupt row is dropped rather than discarding the rest.
    static func loadArrayFromFile<Element: Decodable>(_ type: [Element].Type, fileName: String) -> [Element]? {
        guard let url = appSupportFileURL(fileName),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        do {
            return try JSONDecoder().decode([FailableDecodable<Element>].self, from: data).compactMap(\.value)
        } catch {
            log.error("Decode failed for file \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
