//
//  GeneratedSpeechStore.swift
//  SwiftMandarin
//
//  Persistent Application Support storage and paid-request coalescing for
//  MiniMax-generated speech.
//

import Foundation
import SwiftUI

actor GeneratedSpeechRepository {
    static let shared = GeneratedSpeechRepository()

    private struct Index: Codable {
        let schemaVersion: Int
        let records: [GeneratedSpeechRecord]
    }

    private let directoryURL: URL
    private let indexURL: URL
    private var recordsByID: [String: GeneratedSpeechRecord] = [:]
    private var hasLoaded = false

    init(rootDirectory: URL? = nil) {
        let root: URL
        if let rootDirectory {
            root = rootDirectory
        } else if let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            root = applicationSupport.appendingPathComponent("SwiftMandarin", isDirectory: true)
        } else {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("SwiftMandarin", isDirectory: true)
        }
        self.directoryURL = root.appendingPathComponent("GeneratedAudio", isDirectory: true)
        self.indexURL = self.directoryURL.appendingPathComponent("index.json", isDirectory: false)
    }

    func cachedSpeech(for identity: MiniMaxSpeechCacheIdentity) throws -> CachedGeneratedSpeech? {
        try loadIfNeeded()
        guard let record = recordsByID[identity.cacheKey] else { return nil }
        guard let url = validFileURL(for: record) else {
            recordsByID.removeValue(forKey: identity.cacheKey)
            try persistIndex()
            return nil
        }
        return CachedGeneratedSpeech(record: record, fileURL: url, wasCached: true)
    }

    func save(
        result: MiniMaxSynthesisResult,
        identity: MiniMaxSpeechCacheIdentity
    ) throws -> CachedGeneratedSpeech {
        try loadIfNeeded()
        guard !result.audioData.isEmpty else { throw MiniMaxAudioError.emptyAudio }

        if let existing = recordsByID[identity.cacheKey],
           let existingURL = validFileURL(for: existing) {
            return CachedGeneratedSpeech(record: existing, fileURL: existingURL, wasCached: true)
        }

        try ensureDirectory()
        let fileName = "\(identity.cacheKey).mp3"
        let destination = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        let previousRecord = recordsByID[identity.cacheKey]

        do {
            try result.audioData.write(to: destination, options: .atomic)
        } catch {
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }

        let record = GeneratedSpeechRecord(
            cacheKey: identity.cacheKey,
            text: identity.normalizedText,
            languageCode: identity.languageCode,
            model: identity.configuration.model,
            voiceID: identity.configuration.voiceID,
            region: identity.configuration.region,
            createdAt: Date(),
            durationMilliseconds: result.durationMilliseconds,
            byteCount: result.audioData.count,
            fileName: fileName,
            sampleRate: identity.configuration.sampleRate,
            bitrate: identity.configuration.bitrate,
            format: identity.configuration.format
        )
        recordsByID[record.id] = record

        do {
            try persistIndex()
        } catch {
            if let previousRecord {
                recordsByID[previousRecord.id] = previousRecord
            } else {
                recordsByID.removeValue(forKey: record.id)
            }
            try? FileManager.default.removeItem(at: destination)
            throw error
        }

        return CachedGeneratedSpeech(record: record, fileURL: destination, wasCached: false)
    }

    func allRecords() throws -> [GeneratedSpeechRecord] {
        try loadIfNeeded()
        return recordsByID.values.sorted { $0.createdAt > $1.createdAt }
    }

    func fileURL(for recordID: String) throws -> URL {
        try loadIfNeeded()
        guard let record = recordsByID[recordID], let url = validFileURL(for: record) else {
            if recordsByID.removeValue(forKey: recordID) != nil {
                try persistIndex()
            }
            throw MiniMaxAudioError.missingPersistedAudio
        }
        return url
    }

    func delete(recordID: String) throws {
        try loadIfNeeded()
        guard let record = recordsByID[recordID] else { return }
        let fileURL = directoryURL.appendingPathComponent(record.fileName, isDirectory: false)

        // Commit the metadata removal before touching the MP3. A failure to
        // persist therefore leaves both the index and file unchanged, while a
        // later file-removal failure can only leave a harmless orphan—never an
        // index entry pointing at a missing file.
        recordsByID.removeValue(forKey: recordID)
        do {
            try persistIndex()
        } catch {
            recordsByID[record.id] = record
            throw error
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                throw MiniMaxAudioError.persistence(
                    String(localized: "The library entry was deleted, but its audio file could not be removed:")
                        + " " + error.localizedDescription
                )
            }
        }
    }

    func clearAll() throws {
        let previous = recordsByID
        let previouslyLoaded = hasLoaded

        // Clear is an explicit destructive recovery path and therefore must
        // remain available even when the current app cannot decode a future
        // schema. Publish a known-empty index first, then remove every other
        // artifact in this dedicated GeneratedAudio directory.
        try ensureDirectory()

        recordsByID.removeAll()
        do {
            try persistIndex()
        } catch {
            recordsByID = previous
            hasLoaded = previouslyLoaded
            throw error
        }
        hasLoaded = true

        var firstCleanupError: Error?
        let candidates: [URL]
        do {
            candidates = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
        } catch {
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }
        for candidate in candidates where candidate.lastPathComponent != indexURL.lastPathComponent {
            do {
                try FileManager.default.removeItem(at: candidate)
            } catch {
                if firstCleanupError == nil { firstCleanupError = error }
            }
        }
        if let firstCleanupError {
            throw MiniMaxAudioError.persistence(
                String(localized: "The library was cleared, but one or more audio files could not be removed:")
                    + " " + firstCleanupError.localizedDescription
            )
        }
    }

    private func loadIfNeeded() throws {
        guard !hasLoaded else { return }
        try ensureDirectory()
        hasLoaded = true

        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            recordsByID = [:]
            cleanupOrphanedAudioFiles()
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: indexURL)
        } catch {
            hasLoaded = false
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }

        let decoded: Index
        do {
            decoded = try JSONDecoder().decode(Index.self, from: data)
        } catch {
            try recoverMalformedIndex()
            return
        }

        guard decoded.schemaVersion == 1 else {
            hasLoaded = false
            throw MiniMaxAudioError.unsupportedSavedAudioIndex(
                version: decoded.schemaVersion
            )
        }

        var valid: [String: GeneratedSpeechRecord] = [:]
        for record in decoded.records where validFileURL(for: record) != nil {
            valid[record.id] = record
        }
        recordsByID = valid
        if valid.count != decoded.records.count {
            do {
                try persistIndex()
            } catch {
                hasLoaded = false
                throw error
            }
        }
        cleanupOrphanedAudioFiles()
    }

    /// Malformed JSON must not permanently lock users out of their library.
    /// The original is moved aside only for transactional rollback, then
    /// deleted after a fresh empty index is durable so source text is not kept
    /// in a hidden quarantine. Unknown *valid* future schemas never take this
    /// path: they are left untouched and require an app update or explicit
    /// Clear All.
    private func recoverMalformedIndex() throws {
        let rollbackURL = directoryURL.appendingPathComponent(
            "index.recovery-\(UUID().uuidString).json",
            isDirectory: false
        )

        do {
            try FileManager.default.moveItem(at: indexURL, to: rollbackURL)
        } catch {
            hasLoaded = false
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }

        recordsByID = [:]
        do {
            try persistIndex()
        } catch {
            // Best-effort rollback keeps the original metadata at the canonical
            // path if the replacement could not be written.
            try? FileManager.default.removeItem(at: indexURL)
            try? FileManager.default.moveItem(at: rollbackURL, to: indexURL)
            hasLoaded = false
            throw error
        }
        cleanupOrphanedAudioFiles()
        do {
            try FileManager.default.removeItem(at: rollbackURL)
        } catch {
            hasLoaded = false
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }
    }

    private func ensureDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }
    }

    private func persistIndex() throws {
        let index = Index(
            schemaVersion: 1,
            records: recordsByID.values.sorted { $0.createdAt > $1.createdAt }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(index)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            throw MiniMaxAudioError.persistence(error.localizedDescription)
        }
    }

    private func validFileURL(for record: GeneratedSpeechRecord) -> URL? {
        let expectedName = "\(record.cacheKey).mp3"
        guard record.fileName == expectedName,
              record.cacheKey.count == 64,
              record.cacheKey.utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (97...102).contains(byte)
              }) else {
            return nil
        }
        let url = directoryURL.appendingPathComponent(record.fileName, isDirectory: false)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > 0,
              fileSize.intValue == record.byteCount else {
            return nil
        }
        return url
    }

    /// Best-effort reconciliation for files left behind by an interrupted or
    /// partially failed delete. Only cache-key-shaped MP3s in the dedicated
    /// generated-audio directory are eligible.
    private func cleanupOrphanedAudioFiles() {
        guard let candidates = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        let referencedNames = Set(recordsByID.values.map(\.fileName))
        for candidate in candidates where candidate.pathExtension.lowercased() == "mp3" {
            let stem = candidate.deletingPathExtension().lastPathComponent
            let isCacheKey = stem.count == 64 && stem.utf8.allSatisfy { byte in
                (48...57).contains(byte) || (97...102).contains(byte)
            }
            guard isCacheKey, !referencedNames.contains(candidate.lastPathComponent) else { continue }
            try? FileManager.default.removeItem(at: candidate)
        }
    }
}

@Observable
@MainActor
final class GeneratedSpeechStore {
    static let shared = GeneratedSpeechStore()

    private(set) var records: [GeneratedSpeechRecord] = []
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

    var totalByteCount: Int { records.reduce(0) { $0 + $1.byteCount } }

    private let repository: GeneratedSpeechRepository
    private let coordinatesWithSharedPipeline: Bool

    init(repository: GeneratedSpeechRepository = .shared) {
        self.repository = repository
        self.coordinatesWithSharedPipeline = false
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            records = try await repository.allRecords()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func fileURL(for record: GeneratedSpeechRecord) async throws -> URL {
        try await fileURL(for: record.id)
    }

    func fileURL(for recordID: String) async throws -> URL {
        try await repository.fileURL(for: recordID)
    }

    func delete(_ record: GeneratedSpeechRecord) async throws {
        try await delete(recordID: record.id)
    }

    func delete(recordID: String) async throws {
        do {
            try await repository.delete(recordID: recordID)
            records.removeAll { $0.id == recordID }
            lastErrorMessage = nil
        } catch {
            await refresh()
            throw error
        }
    }

    func clearAll() async throws {
        do {
            if coordinatesWithSharedPipeline {
                // Clear is destructive and must not race a paid generation
                // that has already passed its final cancellation check. The
                // shared pipeline drains every generation before deleting the
                // repository and blocks new generation until deletion ends.
                try await MiniMaxSpeechPipeline.shared.clearAllGeneratedSpeech()
            } else {
                try await repository.clearAll()
            }
            records.removeAll()
            lastErrorMessage = nil
        } catch {
            await refresh()
            throw error
        }
    }

    func note(_ record: GeneratedSpeechRecord) {
        records.removeAll { $0.id == record.id }
        records.append(record)
        records.sort { $0.createdAt > $1.createdAt }
        lastErrorMessage = nil
    }

    private init() {
        self.repository = .shared
        self.coordinatesWithSharedPipeline = true
    }
}

actor MiniMaxSpeechPipeline {
    static let shared = MiniMaxSpeechPipeline()

    private struct InFlight {
        let generationID: UUID
        let task: Task<CachedGeneratedSpeech, Error>
        var waiters: Set<UUID>
    }

    private let client: MiniMaxAudioClient
    private let repository: GeneratedSpeechRepository
    private var inFlight: [String: InFlight] = [:]
    private var retiringTasks: [UUID: Task<CachedGeneratedSpeech, Error>] = [:]
    private var clearTask: Task<Void, Error>?

    init(
        client: MiniMaxAudioClient = MiniMaxAudioClient(),
        repository: GeneratedSpeechRepository = .shared
    ) {
        self.client = client
        self.repository = repository
    }

    func speech(
        for identity: MiniMaxSpeechCacheIdentity,
        apiKey: String
    ) async throws -> CachedGeneratedSpeech {
        guard clearTask == nil else { throw CancellationError() }
        if let cached = try await repository.cachedSpeech(for: identity) {
            guard clearTask == nil else { throw CancellationError() }
            return cached
        }
        guard clearTask == nil else { throw CancellationError() }

        let waiterID = UUID()
        let generationID: UUID
        let task: Task<CachedGeneratedSpeech, Error>

        if let abandoned = inFlight[identity.cacheKey], abandoned.waiters.isEmpty {
            abandoned.task.cancel()
            inFlight.removeValue(forKey: identity.cacheKey)
            retiringTasks[abandoned.generationID] = abandoned.task
        }

        if var existing = inFlight[identity.cacheKey] {
            existing.waiters.insert(waiterID)
            inFlight[identity.cacheKey] = existing
            generationID = existing.generationID
            task = existing.task
        } else {
            let newGenerationID = UUID()
            let client = self.client
            let repository = self.repository
            let newTask = Task<CachedGeneratedSpeech, Error> {
                let result = try await client.synthesize(identity: identity, apiKey: apiKey)
                try Task.checkCancellation()
                return try await repository.save(result: result, identity: identity)
            }
            inFlight[identity.cacheKey] = InFlight(
                generationID: newGenerationID,
                task: newTask,
                waiters: [waiterID]
            )
            generationID = newGenerationID
            task = newTask
        }

        return try await withTaskCancellationHandler {
            do {
                let result = try await task.value
                try Task.checkCancellation()
                finishWaiter(
                    cacheKey: identity.cacheKey,
                    waiterID: waiterID,
                    generationID: generationID
                )
                return result
            } catch {
                finishWaiter(
                    cacheKey: identity.cacheKey,
                    waiterID: waiterID,
                    generationID: generationID
                )
                throw error
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(
                    cacheKey: identity.cacheKey,
                    waiterID: waiterID,
                    generationID: generationID
                )
            }
        }
    }

    private func finishWaiter(cacheKey: String, waiterID: UUID, generationID: UUID) {
        guard var existing = inFlight[cacheKey], existing.generationID == generationID else {
            // A fully cancelled generation is removed from the active map so
            // an immediate repeat can start cleanly, but its task remains here
            // until this waiter observes completion for Clear All drainage.
            retiringTasks.removeValue(forKey: generationID)
            return
        }
        existing.waiters.remove(waiterID)
        if existing.waiters.isEmpty {
            inFlight.removeValue(forKey: cacheKey)
        } else {
            inFlight[cacheKey] = existing
        }
    }

    private func cancelWaiter(cacheKey: String, waiterID: UUID, generationID: UUID) {
        guard var existing = inFlight[cacheKey], existing.generationID == generationID else { return }
        existing.waiters.remove(waiterID)
        if existing.waiters.isEmpty {
            existing.task.cancel()
            // Remove it from the joinable map immediately: a rapid second tap
            // for the same text must start a fresh request, never inherit this
            // cancelled task. Retain the handle separately until completion so
            // destructive Clear All can still drain a queued save.
            inFlight.removeValue(forKey: cacheKey)
            retiringTasks[generationID] = existing.task
        } else {
            inFlight[cacheKey] = existing
        }
    }

    /// Cancels and drains every generation before clearing persisted audio.
    /// While the operation is suspended, reentrant `speech` calls fail closed
    /// instead of starting work that could repopulate the library mid-clear.
    func clearAllGeneratedSpeech() async throws {
        if let clearTask {
            try await clearTask.value
            return
        }

        let generationTasks = inFlight.values.map(\.task) + retiringTasks.values
        let repository = self.repository
        let task = Task<Void, Error> {
            for generationTask in generationTasks {
                generationTask.cancel()
            }
            for generationTask in generationTasks {
                _ = await generationTask.result
            }
            try await repository.clearAll()
        }
        clearTask = task

        do {
            try await task.value
            inFlight.removeAll()
            retiringTasks.removeAll()
            clearTask = nil
        } catch {
            // Generation tasks were drained even when repository cleanup
            // failed, so no stale handle should be eligible for reuse.
            inFlight.removeAll()
            retiringTasks.removeAll()
            clearTask = nil
            throw error
        }
    }

    #if MINIMAX_AUDIO_CHECKS
    /// Exercises the same cancellation transition as the public waiter path
    /// while exposing only whether the cancelled task remains joinable.
    func cancelActiveGenerationForChecks(cacheKey: String) -> Bool {
        guard let existing = inFlight[cacheKey] else { return false }
        for waiterID in existing.waiters {
            cancelWaiter(
                cacheKey: cacheKey,
                waiterID: waiterID,
                generationID: existing.generationID
            )
        }
        return inFlight[cacheKey] == nil
            && retiringTasks[existing.generationID] != nil
    }
    #endif
}
