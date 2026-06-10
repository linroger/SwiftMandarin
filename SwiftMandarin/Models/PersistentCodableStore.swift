//
//  PersistentCodableStore.swift
//  SwiftMandarin
//
//  Shared loader/saver for the app's UserDefaults-backed JSON stores
//  (vocabulary, history, learning progress, activity). Decode failures are
//  logged instead of silently discarded, and a last-known-good snapshot is
//  kept under "<key>.backup" so a corrupted payload can't wipe user data.
//

import Foundation
import os.log

enum PersistentCodableStore {

    private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "Persistence")

    /// Load and decode the value stored under `key`.
    ///
    /// On a successful decode the payload is also snapshotted to
    /// "<key>.backup" (once per launch is enough — this is called from each
    /// store's init). If the primary payload fails to decode, the backup is
    /// tried; when the backup succeeds it is promoted back to the primary key.
    static func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        let defaults = UserDefaults.standard
        let backupKey = key + ".backup"

        if let data = defaults.data(forKey: key) {
            do {
                let value = try JSONDecoder().decode(T.self, from: data)
                defaults.set(data, forKey: backupKey)
                return value
            } catch {
                log.error("Decode failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public) — trying backup")
            }
        }

        if let backup = defaults.data(forKey: backupKey) {
            do {
                let value = try JSONDecoder().decode(T.self, from: backup)
                log.notice("Restored \(key, privacy: .public) from last-known-good backup")
                defaults.set(backup, forKey: key)
                return value
            } catch {
                log.error("Backup decode also failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return nil
    }

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
}
