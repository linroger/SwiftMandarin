//
//  MiniMaxAudioCatalogModels.swift
//  SwiftMandarin
//
//  Public model and voice metadata used by MiniMax AI Audio settings.
//

import Foundation

/// The quality/latency class encoded in MiniMax speech model identifiers.
///
/// This deliberately does not imply a price or entitlement tier. MiniMax's
/// current documentation describes the variants as HD and Turbo; account
/// pricing and availability remain server-side concerns.
nonisolated enum MiniMaxSpeechModelTier: String, Codable, CaseIterable, Sendable {
    case hd
    case turbo

    var displayName: String {
        switch self {
        case .hd: return "HD"
        case .turbo: return "Turbo"
        }
    }
}

nonisolated enum MiniMaxSpeechModelLifecycle: String, Codable, Sendable {
    /// Listed as the current recommended family in MiniMax's model overview.
    case current
    /// Still accepted by T2A for compatibility, but no longer the current family.
    case legacy
}

/// Versioned, bundled speech-model metadata.
///
/// MiniMax's general `/models` endpoint does not currently enumerate speech
/// models. Keeping this small documented catalog avoids pretending that a text
/// model response is authoritative while still allowing Settings to present
/// the latest Speech 2.8 family separately from older compatible identifiers.
nonisolated struct MiniMaxSpeechModelDescriptor: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let family: String
    let tier: MiniMaxSpeechModelTier
    let lifecycle: MiniMaxSpeechModelLifecycle
    let isLatestFamily: Bool
    let summary: String

    var displayName: String {
        "Speech \(family) \(tier.displayName)"
    }

    static let documentedT2AModels: [Self] = [
        .init(
            id: "speech-2.8-turbo",
            family: "2.8",
            tier: .turbo,
            lifecycle: .current,
            isLatestFamily: true,
            summary: "Latest Turbo model, balancing generation speed with natural flow."
        ),
        .init(
            id: "speech-2.8-hd",
            family: "2.8",
            tier: .hd,
            lifecycle: .current,
            isLatestFamily: true,
            summary: "Latest HD model with ultra-realistic quality and sound-tag support."
        ),
        .init(
            id: "speech-2.6-turbo",
            family: "2.6",
            tier: .turbo,
            lifecycle: .legacy,
            isLatestFamily: false,
            summary: "Turbo model documented for value-oriented multilingual speech."
        ),
        .init(
            id: "speech-2.6-hd",
            family: "2.6",
            tier: .hd,
            lifecycle: .legacy,
            isLatestFamily: false,
            summary: "HD model with real-time response, text parsing, and fluent cloned voices."
        ),
        .init(
            id: "speech-02-turbo",
            family: "02",
            tier: .turbo,
            lifecycle: .legacy,
            isLatestFamily: false,
            summary: "Turbo model with stable rhythm and enhanced multilingual capability."
        ),
        .init(
            id: "speech-02-hd",
            family: "02",
            tier: .hd,
            lifecycle: .legacy,
            isLatestFamily: false,
            summary: "HD model emphasizing rhythm, stability, voice similarity, and sound quality."
        ),
    ]

    static let acceptedLegacyModels: [Self] = [
        .init(
            id: "speech-01-turbo",
            family: "01",
            tier: .turbo,
            lifecycle: .legacy,
            isLatestFamily: false,
            summary: "Legacy Turbo identifier retained for existing configurations."
        ),
        .init(
            id: "speech-01-hd",
            family: "01",
            tier: .hd,
            lifecycle: .legacy,
            isLatestFamily: false,
            summary: "Legacy HD identifier retained for existing configurations."
        ),
    ]

    static let selectableModels = documentedT2AModels + acceptedLegacyModels

    static func descriptor(for modelID: String) -> Self? {
        let normalizedID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectableModels.first { $0.id == normalizedID }
    }
}

nonisolated enum MiniMaxVoiceSource: String, Codable, CaseIterable, Sendable {
    case system
    case voiceCloning
    case voiceGeneration
    case musicGeneration
}

nonisolated enum MiniMaxKnownVoiceLanguage: String, Codable, Sendable {
    case mandarinChinese
    case english
}

/// Metadata returned by MiniMax's Get Voice endpoint.
nonisolated struct MiniMaxVoiceDescriptor: Codable, Hashable, Identifiable, Sendable {
    var id: String { voiceID }

    let voiceID: String
    let name: String?
    let descriptions: [String]
    let createdTime: String?
    let source: MiniMaxVoiceSource

    var displayName: String {
        guard let name, !name.isEmpty, name != voiceID else { return voiceID }
        return name
    }

    /// Only system voices are classified. A user can name an account-created
    /// voice with any prefix, so inferring its language would be misleading.
    var knownLanguage: MiniMaxKnownVoiceLanguage? {
        guard source == .system else { return nil }
        return Self.classifySystemVoiceID(voiceID)
    }

    static func classifySystemVoiceID(_ voiceID: String) -> MiniMaxKnownVoiceLanguage? {
        let normalizedID = voiceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedID.hasPrefix("chinese (mandarin)_")
            || normalizedID == "arrogant_miss"
            || normalizedID == "robot_armor" {
            return .mandarinChinese
        }
        if normalizedID.hasPrefix("english_") {
            return .english
        }
        return nil
    }

    /// Determines whether a voice should take its language from the Mandarin
    /// or English settings slot. Live catalog provenance wins because an
    /// account-created voice may deliberately use a system-looking prefix.
    /// Without provenance, recognized system IDs remain language-validated so
    /// manually entering an English system voice cannot bypass the Mandarin
    /// preview guard by being treated as a custom voice.
    static func usesSlotLanguageAssignment(
        voiceID: String,
        catalogSource: MiniMaxVoiceSource?
    ) -> Bool {
        if let catalogSource {
            return catalogSource != .system
        }
        return classifySystemVoiceID(voiceID) == nil
    }

    /// Reconciles persisted account/custom provenance with a credential or
    /// region boundary and an optional live-catalog result. A live descriptor
    /// is authoritative in both directions. When the catalog cannot yet prove
    /// provenance, a changed account/region revokes only system-looking IDs;
    /// unclassified custom IDs retain the language slot the user chose.
    static func reconciledSlotLanguageAssignment(
        voiceID: String,
        persistedAssignment: Bool,
        liveCatalogSource: MiniMaxVoiceSource?,
        scopeChanged: Bool
    ) -> Bool {
        if let liveCatalogSource {
            return liveCatalogSource != .system
        }
        if scopeChanged, classifySystemVoiceID(voiceID) != nil {
            return false
        }
        return persistedAssignment
    }
}

nonisolated enum MiniMaxVoiceCatalogOrigin: String, Codable, Sendable {
    case live
    case cachedPublicMetadata
}

/// One regional MiniMax voice response.
///
/// Cached instances intentionally contain only `systemVoices`; cloned,
/// generated, and music voices are private account metadata and are kept only
/// in memory for the current live response.
nonisolated struct MiniMaxVoiceCatalog: Hashable, Sendable {
    let region: MiniMaxAPIRegion
    let fetchedAt: Date
    let origin: MiniMaxVoiceCatalogOrigin
    let systemVoices: [MiniMaxVoiceDescriptor]
    let clonedVoices: [MiniMaxVoiceDescriptor]
    let generatedVoices: [MiniMaxVoiceDescriptor]
    let musicGenerationVoices: [MiniMaxVoiceDescriptor]

    var mandarinSystemVoices: [MiniMaxVoiceDescriptor] {
        systemVoices.filter { $0.knownLanguage == .mandarinChinese }
    }

    var englishSystemVoices: [MiniMaxVoiceDescriptor] {
        systemVoices.filter { $0.knownLanguage == .english }
    }

    var unclassifiedSystemVoices: [MiniMaxVoiceDescriptor] {
        systemVoices.filter { $0.knownLanguage == nil }
    }

    var accountVoices: [MiniMaxVoiceDescriptor] {
        clonedVoices + generatedVoices + musicGenerationVoices
    }
}

nonisolated enum MiniMaxVoiceCatalogError: LocalizedError, Sendable {
    case cancelled
    case missingAPIKey
    case invalidEndpoint
    case invalidHTTPResponse
    case httpStatus(Int)
    case transport(String)
    case responseDecoding
    case apiStatus(code: Int, message: String?)
    case persistence(String)
    case unsupportedCacheVersion(Int)
    case cachedRegionMismatch

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return String(localized: "MiniMax voice refresh was cancelled.")
        case .missingAPIKey:
            return String(localized: "Add a MiniMax API key before refreshing voices.")
        case .invalidEndpoint:
            return String(localized: "The MiniMax voice-catalog URL is invalid.")
        case .invalidHTTPResponse:
            return String(localized: "MiniMax returned an invalid voice-catalog response.")
        case let .httpStatus(status):
            return String.localizedStringWithFormat(
                String(localized: "MiniMax returned HTTP status %lld while refreshing voices."),
                Int64(status)
            )
        case let .transport(message):
            return String(localized: "MiniMax voices could not be refreshed:") + " " + message
        case .responseDecoding:
            return String(localized: "MiniMax returned a voice catalog the app could not read.")
        case let .apiStatus(code, message):
            if let message, !message.isEmpty {
                return String.localizedStringWithFormat(
                    String(localized: "MiniMax voice-catalog error %lld:"),
                    Int64(code)
                ) + " " + message
            }
            return String.localizedStringWithFormat(
                String(localized: "MiniMax returned voice-catalog error %lld."),
                Int64(code)
            )
        case let .persistence(message):
            return String(localized: "The public MiniMax voice catalog could not be saved:")
                + " " + message
        case let .unsupportedCacheVersion(version):
            return String.localizedStringWithFormat(
                String(localized: "The saved MiniMax voice catalog uses unsupported schema %lld."),
                Int64(version)
            )
        case .cachedRegionMismatch:
            return String(localized: "The saved MiniMax voice catalog belongs to another API region.")
        }
    }
}
