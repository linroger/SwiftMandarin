//
//  MiniMaxAudioClient.swift
//  SwiftMandarin
//
//  Strict, non-streaming MiniMax T2A v2 HTTP client.
//

import Foundation

nonisolated enum MiniMaxAudioError: LocalizedError, Sendable {
    case cancelled
    case emptyText
    case textTooLong(actual: Int, maximumExclusive: Int)
    case missingAPIKey
    case invalidConfiguration(String)
    case invalidHTTPResponse
    case httpStatus(Int)
    case transport(String)
    case responseDecoding
    case apiStatus(code: Int, message: String?)
    case incompleteAudio(status: Int?)
    case missingAudio
    case malformedHexAudio
    case emptyAudio
    case responseMetadataMismatch(String)
    case persistence(String)
    case unsupportedSavedAudioIndex(version: Int)
    case missingPersistedAudio
    case playback(String)

    private static let transientCodes: Set<Int> = [1000, 1001, 1002, 1024, 1033, 2045]

    var isTransient: Bool {
        switch self {
        case .transport, .httpStatus:
            return true
        case let .apiStatus(code, _):
            return Self.transientCodes.contains(code)
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return String(localized: "AI Audio was cancelled.")
        case .emptyText:
            return String(localized: "Enter some text before generating speech.")
        case let .textTooLong(actual, maximumExclusive):
            return String.localizedStringWithFormat(
                String(localized: "AI Audio supports fewer than %1$lld characters; this text has %2$lld."),
                Int64(maximumExclusive),
                Int64(actual)
            )
        case .missingAPIKey:
            return String(localized: "Add a MiniMax API key in AI Audio settings.")
        case let .invalidConfiguration(reason):
            return String(localized: "AI Audio settings are invalid:") + " " + reason
        case .invalidHTTPResponse:
            return String(localized: "MiniMax returned an invalid network response.")
        case let .httpStatus(status):
            return String.localizedStringWithFormat(
                String(localized: "MiniMax returned HTTP status %lld."),
                Int64(status)
            )
        case let .transport(message):
            return String(localized: "MiniMax could not be reached:") + " " + message
        case .responseDecoding:
            return String(localized: "MiniMax returned a response the app could not read.")
        case let .apiStatus(code, message):
            if let message, !message.isEmpty {
                return String.localizedStringWithFormat(
                    String(localized: "MiniMax error %lld:"),
                    Int64(code)
                ) + " " + message
            }
            return String.localizedStringWithFormat(
                String(localized: "MiniMax returned error %lld."),
                Int64(code)
            )
        case let .incompleteAudio(status):
            if let status {
                return String.localizedStringWithFormat(
                    String(localized: "MiniMax did not finish the audio (status %lld)."),
                    Int64(status)
                )
            }
            return String(localized: "MiniMax did not return an audio completion status.")
        case .missingAudio:
            return String(localized: "MiniMax completed the request without returning audio.")
        case .malformedHexAudio:
            return String(localized: "MiniMax returned malformed audio data.")
        case .emptyAudio:
            return String(localized: "MiniMax returned an empty audio file.")
        case let .responseMetadataMismatch(reason):
            return String(localized: "MiniMax returned inconsistent audio metadata:") + " " + reason
        case let .persistence(message):
            return String(localized: "The generated audio could not be saved:") + " " + message
        case let .unsupportedSavedAudioIndex(version):
            return String.localizedStringWithFormat(
                String(localized: "This saved-audio library was created by a newer app version (schema %lld). Update SwiftMandarin to open it, or use Clear All to reset it."),
                Int64(version)
            )
        case .missingPersistedAudio:
            return String(localized: "The saved audio file is missing.")
        case let .playback(message):
            return String(localized: "The generated audio could not be played:") + " " + message
        }
    }
}

nonisolated struct MiniMaxSynthesisResult: Sendable {
    let audioData: Data
    let durationMilliseconds: Int?
    let reportedByteCount: Int?
    let audioFormat: String?
    let traceID: String?
}

actor MiniMaxAudioClient {
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func synthesize(
        identity: MiniMaxSpeechCacheIdentity,
        apiKey: String
    ) async throws -> MiniMaxSynthesisResult {
        try Task.checkCancellation()
        let text = identity.normalizedText
        guard !text.isEmpty else { throw MiniMaxAudioError.emptyText }
        guard text.count < 10_000 else {
            throw MiniMaxAudioError.textTooLong(actual: text.count, maximumExclusive: 10_000)
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw MiniMaxAudioError.missingAPIKey }

        let configuration = identity.configuration
        try Self.validate(configuration)
        guard let endpoint = configuration.region.t2aEndpoint else {
            throw MiniMaxAudioError.invalidConfiguration(
                String(localized: "The regional API URL is invalid.")
            )
        }

        let payload = T2ARequest(
            model: configuration.model,
            text: text,
            stream: false,
            languageBoost: "auto",
            outputFormat: "hex",
            voiceSetting: .init(
                voiceID: configuration.voiceID,
                speed: configuration.speed,
                volume: configuration.volume,
                pitch: configuration.pitch
            ),
            audioSetting: .init(
                sampleRate: configuration.sampleRate,
                bitrate: configuration.bitrate,
                format: configuration.format,
                channel: configuration.channelCount
            )
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw MiniMaxAudioError.invalidConfiguration(
                String(localized: "The request could not be encoded.")
            )
        }

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw MiniMaxAudioError.cancelled
        } catch let error as URLError where error.code == .cancelled {
            throw MiniMaxAudioError.cancelled
        } catch let error as URLError {
            // URLError descriptions do not include request headers. Never
            // include the URLRequest itself in diagnostics because it contains
            // the bearer credential.
            throw MiniMaxAudioError.transport(error.localizedDescription)
        } catch {
            throw MiniMaxAudioError.transport(error.localizedDescription)
        }

        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw MiniMaxAudioError.invalidHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw MiniMaxAudioError.httpStatus(http.statusCode)
        }

        let decoded: T2AResponse
        do {
            decoded = try decoder.decode(T2AResponse.self, from: responseData)
        } catch {
            throw MiniMaxAudioError.responseDecoding
        }

        guard decoded.baseResponse.statusCode == 0 else {
            throw MiniMaxAudioError.apiStatus(
                code: decoded.baseResponse.statusCode,
                message: decoded.baseResponse.statusMessage
            )
        }
        guard decoded.data?.status == 2 else {
            throw MiniMaxAudioError.incompleteAudio(status: decoded.data?.status)
        }
        guard let encodedAudio = decoded.data?.audio, !encodedAudio.isEmpty else {
            throw MiniMaxAudioError.missingAudio
        }
        let audioData = try Self.decodeStrictHex(encodedAudio)
        guard !audioData.isEmpty else { throw MiniMaxAudioError.emptyAudio }
        if let reportedSize = decoded.extraInfo?.audioSize, reportedSize != audioData.count {
            throw MiniMaxAudioError.responseMetadataMismatch(
                "reported \(reportedSize.formatted()) bytes, received \(audioData.count.formatted())."
            )
        }
        if let reportedFormat = decoded.extraInfo?.audioFormat,
           reportedFormat.lowercased() != configuration.format {
            throw MiniMaxAudioError.responseMetadataMismatch(
                "reported \(reportedFormat) instead of \(configuration.format)."
            )
        }

        return MiniMaxSynthesisResult(
            audioData: audioData,
            durationMilliseconds: decoded.extraInfo?.audioLength,
            reportedByteCount: decoded.extraInfo?.audioSize,
            audioFormat: decoded.extraInfo?.audioFormat,
            traceID: decoded.traceID
        )
    }

    static func decodeStrictHex(_ encoded: String) throws -> Data {
        let bytes = Array(encoded.utf8)
        guard !bytes.isEmpty else { throw MiniMaxAudioError.emptyAudio }
        guard bytes.count.isMultiple(of: 2) else { throw MiniMaxAudioError.malformedHexAudio }

        var result = Data(capacity: bytes.count / 2)
        var index = 0
        while index < bytes.count {
            guard let high = nibble(bytes[index]), let low = nibble(bytes[index + 1]) else {
                throw MiniMaxAudioError.malformedHexAudio
            }
            result.append((high << 4) | low)
            index += 2
        }
        return result
    }

    private static func nibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 55
        case 97...102: return byte - 87
        default: return nil
        }
    }

    private static func validate(_ configuration: MiniMaxSpeechConfiguration) throws {
        guard !configuration.model.isEmpty else {
            throw MiniMaxAudioError.invalidConfiguration(String(localized: "Choose a speech model."))
        }
        guard !configuration.voiceID.isEmpty else {
            throw MiniMaxAudioError.invalidConfiguration(String(localized: "Choose a voice."))
        }
        guard (0.5...2).contains(configuration.speed) else {
            throw MiniMaxAudioError.invalidConfiguration(
                String(localized: "Speed must be between 0.5 and 2.0.")
            )
        }
        guard configuration.volume == 1,
              configuration.pitch == 0,
              configuration.sampleRate == 32_000,
              configuration.bitrate == 128_000,
              configuration.format == "mp3",
              configuration.channelCount == 1 else {
            throw MiniMaxAudioError.invalidConfiguration(
                String(localized: "Playback requires mono 32 kHz, 128 kbps MP3 with default volume and pitch.")
            )
        }
    }
}

nonisolated private struct T2ARequest: Encodable {
    let model: String
    let text: String
    let stream: Bool
    let languageBoost: String
    let outputFormat: String
    let voiceSetting: VoiceSetting
    let audioSetting: AudioSetting

    enum CodingKeys: String, CodingKey {
        case model, text, stream
        case languageBoost = "language_boost"
        case outputFormat = "output_format"
        case voiceSetting = "voice_setting"
        case audioSetting = "audio_setting"
    }

    struct VoiceSetting: Encodable {
        let voiceID: String
        let speed: Double
        let volume: Double
        let pitch: Int

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case speed
            case volume = "vol"
            case pitch
        }
    }

    struct AudioSetting: Encodable {
        let sampleRate: Int
        let bitrate: Int
        let format: String
        let channel: Int

        enum CodingKeys: String, CodingKey {
            case sampleRate = "sample_rate"
            case bitrate, format, channel
        }
    }
}

nonisolated private struct T2AResponse: Decodable {
    let data: AudioData?
    let extraInfo: ExtraInfo?
    let traceID: String?
    let baseResponse: BaseResponse

    enum CodingKeys: String, CodingKey {
        case data
        case extraInfo = "extra_info"
        case traceID = "trace_id"
        case baseResponse = "base_resp"
    }

    struct AudioData: Decodable {
        let audio: String?
        let status: Int?
    }

    struct ExtraInfo: Decodable {
        let audioLength: Int?
        let audioSize: Int?
        let audioFormat: String?

        enum CodingKeys: String, CodingKey {
            case audioLength = "audio_length"
            case audioSize = "audio_size"
            case audioFormat = "audio_format"
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
