//
//  MiniMaxVoiceCatalogClient.swift
//  SwiftMandarin
//
//  Strict Get Voice API client and public-metadata cache.
//

import Foundation

actor MiniMaxVoiceCatalogClient {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func fetch(region: MiniMaxAPIRegion, apiKey: String) async throws -> MiniMaxVoiceCatalog {
        try Task.checkCancellation()

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw MiniMaxVoiceCatalogError.missingAPIKey }
        guard let endpoint = URL(string: region.baseURLString + "/get_voice") else {
            throw MiniMaxVoiceCatalogError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(GetVoiceRequest(voiceType: "all"))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw MiniMaxVoiceCatalogError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw MiniMaxVoiceCatalogError.cancelled
        } catch let error as URLError {
            throw MiniMaxVoiceCatalogError.transport(error.localizedDescription)
        } catch {
            throw MiniMaxVoiceCatalogError.transport(error.localizedDescription)
        }

        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MiniMaxVoiceCatalogError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MiniMaxVoiceCatalogError.httpStatus(httpResponse.statusCode)
        }

        let payload: GetVoiceResponse
        do {
            payload = try decoder.decode(GetVoiceResponse.self, from: data)
        } catch {
            throw MiniMaxVoiceCatalogError.responseDecoding
        }
        guard payload.baseResponse.statusCode == 0 else {
            throw MiniMaxVoiceCatalogError.apiStatus(
                code: payload.baseResponse.statusCode,
                message: payload.baseResponse.statusMessage
            )
        }

        return MiniMaxVoiceCatalog(
            region: region,
            fetchedAt: Date(),
            origin: .live,
            systemVoices: Self.descriptors(payload.systemVoices, source: .system),
            clonedVoices: Self.descriptors(payload.clonedVoices, source: .voiceCloning),
            generatedVoices: Self.descriptors(payload.generatedVoices, source: .voiceGeneration),
            musicGenerationVoices: Self.descriptors(
                payload.musicGenerationVoices,
                source: .musicGeneration
            )
        )
    }

    private static func descriptors(
        _ payloads: [GetVoiceResponse.VoicePayload],
        source: MiniMaxVoiceSource
    ) -> [MiniMaxVoiceDescriptor] {
        var seenVoiceIDs = Set<String>()
        return payloads.compactMap { payload in
            guard let rawVoiceID = payload.voiceID else { return nil }
            let voiceID = rawVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !voiceID.isEmpty, seenVoiceIDs.insert(voiceID).inserted else { return nil }

            let trimmedName = payload.voiceName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptions = payload.descriptions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return MiniMaxVoiceDescriptor(
                voiceID: voiceID,
                name: trimmedName?.isEmpty == false ? trimmedName : nil,
                descriptions: descriptions,
                createdTime: payload.createdTime,
                source: source
            )
        }
    }
}

nonisolated private struct GetVoiceRequest: Encodable {
    let voiceType: String

    enum CodingKeys: String, CodingKey {
        case voiceType = "voice_type"
    }
}

nonisolated private struct GetVoiceResponse: Decodable {
    let systemVoices: [VoicePayload]
    let clonedVoices: [VoicePayload]
    let generatedVoices: [VoicePayload]
    let musicGenerationVoices: [VoicePayload]
    let baseResponse: BaseResponse

    enum CodingKeys: String, CodingKey {
        case systemVoices = "system_voice"
        case clonedVoices = "voice_cloning"
        case generatedVoices = "voice_generation"
        case musicGenerationVoices = "music_generation"
        case baseResponse = "base_resp"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        systemVoices = try container.decodeIfPresent([VoicePayload].self, forKey: .systemVoices) ?? []
        clonedVoices = try container.decodeIfPresent([VoicePayload].self, forKey: .clonedVoices) ?? []
        generatedVoices = try container.decodeIfPresent([VoicePayload].self, forKey: .generatedVoices) ?? []
        musicGenerationVoices = try container.decodeIfPresent(
            [VoicePayload].self,
            forKey: .musicGenerationVoices
        ) ?? []
        baseResponse = try container.decode(BaseResponse.self, forKey: .baseResponse)
    }

    struct VoicePayload: Decodable {
        let voiceID: String?
        let voiceName: String?
        let descriptions: [String]
        let createdTime: String?

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case voiceName = "voice_name"
            case descriptions = "description"
            case createdTime = "created_time"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            voiceID = try? container.decode(String.self, forKey: .voiceID)
            voiceName = try? container.decode(String.self, forKey: .voiceName)

            if let values = try? container.decode([String].self, forKey: .descriptions) {
                descriptions = values
            } else if let value = try? container.decode(String.self, forKey: .descriptions) {
                descriptions = [value]
            } else {
                descriptions = []
            }

            if let string = try? container.decode(String.self, forKey: .createdTime) {
                createdTime = string
            } else if let integer = try? container.decode(Int64.self, forKey: .createdTime) {
                createdTime = String(integer)
            } else {
                createdTime = nil
            }
        }
    }

    struct BaseResponse: Decodable {
        let statusCode: Int
        let statusMessage: String?

        enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case statusMessage = "status_msg"
        }
    }
}

/// Stores only MiniMax's public system-voice metadata. Account-created voice
/// IDs never cross this persistence boundary.
actor MiniMaxVoiceCatalogCache {
    private static let schemaVersion = 1
    private let directoryOverride: URL?
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.directoryOverride = directoryURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load(region: MiniMaxAPIRegion) throws -> MiniMaxVoiceCatalog? {
        let fileURL = try catalogFileURL(region: region, createDirectory: false)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try decoder.decode(PublicVoiceCatalogSnapshot.self, from: data)
            guard snapshot.schemaVersion == Self.schemaVersion else {
                throw MiniMaxVoiceCatalogError.unsupportedCacheVersion(snapshot.schemaVersion)
            }
            guard snapshot.region == region else {
                throw MiniMaxVoiceCatalogError.cachedRegionMismatch
            }

            // Reassert the persistence boundary on read rather than trusting a
            // hand-edited or older cache file's source values.
            let publicSystemVoices = snapshot.systemVoices
                .filter { $0.source == .system }
            return MiniMaxVoiceCatalog(
                region: region,
                fetchedAt: snapshot.fetchedAt,
                origin: .cachedPublicMetadata,
                systemVoices: publicSystemVoices,
                clonedVoices: [],
                generatedVoices: [],
                musicGenerationVoices: []
            )
        } catch let error as MiniMaxVoiceCatalogError {
            throw error
        } catch {
            throw MiniMaxVoiceCatalogError.persistence(error.localizedDescription)
        }
    }

    func savePublicMetadata(from catalog: MiniMaxVoiceCatalog) throws {
        let publicSystemVoices = catalog.systemVoices.filter { $0.source == .system }
        let snapshot = PublicVoiceCatalogSnapshot(
            schemaVersion: Self.schemaVersion,
            region: catalog.region,
            fetchedAt: catalog.fetchedAt,
            systemVoices: publicSystemVoices
        )

        do {
            let fileURL = try catalogFileURL(region: catalog.region, createDirectory: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch let error as MiniMaxVoiceCatalogError {
            throw error
        } catch {
            throw MiniMaxVoiceCatalogError.persistence(error.localizedDescription)
        }
    }

    private func catalogFileURL(
        region: MiniMaxAPIRegion,
        createDirectory: Bool
    ) throws -> URL {
        let directoryURL: URL
        if let directoryOverride {
            directoryURL = directoryOverride
        } else {
            do {
                let applicationSupport = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: createDirectory
                )
                directoryURL = applicationSupport
                    .appendingPathComponent("SwiftMandarin", isDirectory: true)
                    .appendingPathComponent("MiniMaxVoiceCatalogs", isDirectory: true)
            } catch {
                throw MiniMaxVoiceCatalogError.persistence(error.localizedDescription)
            }
        }

        if createDirectory {
            do {
                try fileManager.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
            } catch {
                throw MiniMaxVoiceCatalogError.persistence(error.localizedDescription)
            }
        }

        return directoryURL.appendingPathComponent(
            "public-voices-\(region.rawValue)-v\(Self.schemaVersion).json",
            isDirectory: false
        )
    }
}

nonisolated private struct PublicVoiceCatalogSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let region: MiniMaxAPIRegion
    let fetchedAt: Date
    let systemVoices: [MiniMaxVoiceDescriptor]
}
