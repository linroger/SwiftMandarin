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
                defaults.set(data, forKey: backupKey)
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

    // MARK: - Save

    /// Encode and store `value` under `key`, logging encode failures
    /// (which would otherwise silently skip the write).
    static func save<T: Codable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            log.error("Encode failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
