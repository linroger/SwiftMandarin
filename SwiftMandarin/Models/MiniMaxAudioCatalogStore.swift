//
//  MiniMaxAudioCatalogStore.swift
//  SwiftMandarin
//
//  Main-actor state for regional live and cached MiniMax voice catalogs.
//

import CryptoKit
import Foundation
import Observation

@MainActor
@Observable
final class MiniMaxAudioCatalogStore {
    static let shared = MiniMaxAudioCatalogStore()

    private(set) var activeRegion: MiniMaxAPIRegion
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?
    private(set) var warningMessage: String?

    @ObservationIgnored private let client: MiniMaxVoiceCatalogClient
    @ObservationIgnored private let cache: MiniMaxVoiceCatalogCache
    private var catalogsByRegion: [MiniMaxAPIRegion: MiniMaxVoiceCatalog] = [:]
    @ObservationIgnored private var credentialFingerprintsByRegion: [MiniMaxAPIRegion: String] = [:]
    @ObservationIgnored private var requestSequence = 0

    var catalog: MiniMaxVoiceCatalog? {
        catalogsByRegion[activeRegion]
    }

    var speechModels: [MiniMaxSpeechModelDescriptor] {
        MiniMaxSpeechModelDescriptor.selectableModels
    }

    var lastUpdated: Date? { catalog?.fetchedAt }

    init(
        activeRegion: MiniMaxAPIRegion = .international,
        client: MiniMaxVoiceCatalogClient = MiniMaxVoiceCatalogClient(),
        cache: MiniMaxVoiceCatalogCache = MiniMaxVoiceCatalogCache()
    ) {
        self.activeRegion = activeRegion
        self.client = client
        self.cache = cache
    }

    /// Selects a region without showing stale metadata from another endpoint.
    func activate(region: MiniMaxAPIRegion) {
        activeRegion = region
        errorMessage = nil
        warningMessage = nil
    }

    /// Associates credential-scoped in-memory metadata with an opaque,
    /// process-local fingerprint. A key change invalidates late responses and
    /// removes cloned/generated voice names immediately while preserving the
    /// public system catalog. Neither the key nor its fingerprint is persisted.
    func activateCredential(region: MiniMaxAPIRegion, apiKey: String) {
        activeRegion = region
        activateSharedCredential(apiKey: apiKey)
    }

    /// The MiniMax Keychain entry is shared by both regional endpoints. A
    /// replacement therefore purges private voice metadata and invalidates
    /// in-flight responses for every region, including inactive catalogs.
    func activateSharedCredential(apiKey: String) {
        let fingerprint = Self.credentialFingerprint(apiKey)
        let changedRegions = MiniMaxAPIRegion.allCases.filter {
            credentialFingerprintsByRegion[$0] != fingerprint
        }
        guard !changedRegions.isEmpty else { return }

        for region in changedRegions {
            credentialFingerprintsByRegion[region] = fingerprint
            stripAccountMetadata(for: region)
        }
        requestSequence += 1
        isRefreshing = false
        errorMessage = nil
        warningMessage = nil
    }

    /// Applies MiniMax's stable public system-ID conventions independently of
    /// live/cache availability. This keeps validation and cache behavior
    /// deterministic across relaunches and stale catalogs. Other IDs remain
    /// explicitly assigned by whichever Mandarin/English slot contains them.
    func knownLanguage(
        for voiceID: String,
        region: MiniMaxAPIRegion
    ) -> MiniMaxKnownVoiceLanguage? {
        _ = region
        return MiniMaxVoiceDescriptor.classifySystemVoiceID(voiceID)
    }

    /// Loads a public system-voice snapshot when no newer in-memory catalog is
    /// available. A late disk read can never replace a live response.
    func loadCachedCatalog(for region: MiniMaxAPIRegion) async {
        activeRegion = region
        guard catalogsByRegion[region] == nil else { return }

        do {
            guard let cachedCatalog = try await cache.load(region: region),
                  catalogsByRegion[region] == nil else { return }
            catalogsByRegion[region] = cachedCatalog
        } catch {
            guard activeRegion == region else { return }
            warningMessage = error.localizedDescription
        }
    }

    /// Fetches all currently available voices. Request results are guarded by a
    /// monotonically increasing token, so only the newest refresh can mutate
    /// user-visible state. Credentials are passed directly to the actor client
    /// and are never assigned to store or cache properties.
    func refresh(region: MiniMaxAPIRegion, apiKey: String) async {
        activateCredential(region: region, apiKey: apiKey)
        requestSequence += 1
        let requestID = requestSequence
        isRefreshing = true
        errorMessage = nil
        warningMessage = nil

        do {
            let liveCatalog = try await client.fetch(region: region, apiKey: apiKey)
            guard requestID == requestSequence else { return }

            catalogsByRegion[region] = liveCatalog
            isRefreshing = false

            do {
                try await cache.savePublicMetadata(from: liveCatalog)
            } catch {
                guard requestID == requestSequence else { return }
                warningMessage = error.localizedDescription
            }
        } catch is CancellationError {
            guard requestID == requestSequence else { return }
            isRefreshing = false
        } catch MiniMaxVoiceCatalogError.cancelled {
            guard requestID == requestSequence else { return }
            isRefreshing = false
        } catch {
            guard requestID == requestSequence else { return }
            // Deliberately retain the last successful live or cached catalog.
            isRefreshing = false
            errorMessage = error.localizedDescription
        }
    }

    /// Invalidates any in-flight result. URLSession cancellation remains the
    /// caller task's responsibility; the token guarantees a late response is
    /// ignored even when a transport cannot be cancelled immediately.
    func cancelRefresh() {
        requestSequence += 1
        isRefreshing = false
    }

    func clearMessages() {
        errorMessage = nil
        warningMessage = nil
    }

    private func stripAccountMetadata(for region: MiniMaxAPIRegion) {
        guard let existing = catalogsByRegion[region],
              existing.origin == .live || !existing.accountVoices.isEmpty else { return }
        catalogsByRegion[region] = MiniMaxVoiceCatalog(
            region: existing.region,
            fetchedAt: existing.fetchedAt,
            // This is only the public portion of a response obtained under a
            // different credential. Keep it available, but never present it
            // as a live catalog for the replacement account.
            origin: .cachedPublicMetadata,
            systemVoices: existing.systemVoices,
            clonedVoices: [],
            generatedVoices: [],
            musicGenerationVoices: []
        )
    }

    nonisolated private static func credentialFingerprint(_ apiKey: String) -> String {
        let normalized = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "no-credential" }
        return SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
