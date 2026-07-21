#if MINIMAX_AUDIO_CHECKS
import Foundation

// MiniMaxAudioModels.swift adds an AppPreferences convenience extension. The
// standalone contract target deliberately supplies the smallest compile-time
// surface that extension needs instead of loading UserDefaults or the app's
// singleton graph. No instance of this shim is created by the checks.
@MainActor
final class AppPreferences {
    static let aiAudioSpeedRange: ClosedRange<Double> = 0.5...2.0

    var aiAudioSpeed = 1.0
    var aiAudioRegion: MiniMaxAPIRegion = .mainlandChina
    var aiAudioModel = MiniMaxSpeechConfiguration.defaultModel
    var aiAudioChineseVoice = MiniMaxSpeechConfiguration.defaultChineseVoice
    var aiAudioEnglishVoice = MiniMaxSpeechConfiguration.defaultEnglishVoice
    var aiAudioChineseVoiceUsesCustomLanguage = false
    var aiAudioEnglishVoiceUsesCustomLanguage = false
}

private struct CheckFailure: Error {
    let message: String
}

private enum StubbedURLAction: Sendable {
    case respond(statusCode: Int, body: Data, delayNanoseconds: UInt64 = 0)
    case waitForCancellation
}

private struct ObservedRequest: Sendable {
    let url: URL?
    let method: String?
    let headers: [String: String]
    let body: Data?

    func header(named name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

/// Intercepts every request made by an injected ephemeral URLSession. The
/// contract runner never registers this class globally, so unrelated sessions
/// are unaffected and an absent fixture fails closed rather than reaching the
/// network.
private final class MiniMaxURLProtocolStub: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) -> StubbedURLAction

    private static let sharedLock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    nonisolated(unsafe) private static var capturedRequests: [ObservedRequest] = []

    private let instanceLock = NSLock()
    private var pendingWorkItem: DispatchWorkItem?

    static func install(_ newHandler: @escaping Handler) {
        sharedLock.lock()
        handler = newHandler
        capturedRequests = []
        sharedLock.unlock()
    }

    static func requests() -> [ObservedRequest] {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        return capturedRequests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let action: StubbedURLAction?
        Self.sharedLock.lock()
        Self.capturedRequests.append(
            ObservedRequest(
                url: request.url,
                method: request.httpMethod,
                headers: request.allHTTPHeaderFields ?? [:],
                body: Self.bodyData(from: request)
            )
        )
        action = Self.handler?(request)
        Self.sharedLock.unlock()

        guard let action else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch action {
        case let .respond(statusCode, body, delayNanoseconds):
            let workItem = DispatchWorkItem { [weak self] in
                self?.deliver(statusCode: statusCode, body: body)
            }
            instanceLock.lock()
            pendingWorkItem = workItem
            instanceLock.unlock()

            if delayNanoseconds == 0 {
                workItem.perform()
            } else {
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + .nanoseconds(Int(delayNanoseconds)),
                    execute: workItem
                )
            }
        case .waitForCancellation:
            break
        }
    }

    override func stopLoading() {
        instanceLock.lock()
        let workItem = pendingWorkItem
        pendingWorkItem = nil
        instanceLock.unlock()
        workItem?.cancel()
    }

    private func deliver(statusCode: Int, body: Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: statusCode,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !body.isEmpty {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                result.append(buffer, count: count)
            } else if count == 0 {
                return result
            } else {
                return nil
            }
        }
    }
}

private enum ExpectedClientError {
    case cancelled
    case httpStatus(Int)
    case apiStatus(Int)
    case incompleteAudio(Int?)
    case missingAudio
    case metadataMismatch(containing: String)
}

private func stubbedSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MiniMaxURLProtocolStub.self]
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration)
}

private func t2aResponse(
    audioHex: String? = "494433",
    audioStatus: Int? = 2,
    audioSize: Int? = 3,
    audioFormat: String? = "mp3",
    baseStatus: Int = 0,
    baseMessage: String = "success"
) throws -> Data {
    var audioPayload: [String: Any] = [:]
    if let audioHex { audioPayload["audio"] = audioHex }
    if let audioStatus { audioPayload["status"] = audioStatus }

    var extraInfo: [String: Any] = ["audio_length": 321]
    if let audioSize { extraInfo["audio_size"] = audioSize }
    if let audioFormat { extraInfo["audio_format"] = audioFormat }

    let object: [String: Any] = [
        "data": audioPayload,
        "extra_info": extraInfo,
        "trace_id": "offline-trace",
        "base_resp": [
            "status_code": baseStatus,
            "status_msg": baseMessage,
        ],
    ]
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private func voiceCatalogResponse(
    primaryMandarinVoiceID: String = "Chinese (Mandarin)_News_Anchor",
    baseStatus: Int = 0,
    baseMessage: String = "success",
    includeAccountVoices: Bool = true
) throws -> Data {
    let object: [String: Any] = [
        "system_voice": [
            [
                "voice_id": primaryMandarinVoiceID,
                "voice_name": "新闻女声",
                "description": ["清晰", "沉稳"],
                "created_time": 1_700_000_001,
            ],
            [
                "voice_id": "English_Graceful_Lady",
                "voice_name": "Graceful Lady",
                "description": "Warm English voice",
            ],
            [
                "voice_id": "Arrogant_Miss",
                "voice_name": "傲娇小姐",
                "description": [],
            ],
            [
                "voice_id": "Unclassified_System_Voice",
                "description": [],
            ],
        ],
        "voice_cloning": includeAccountVoices
            ? [["voice_id": "account-clone", "voice_name": "My Voice"]]
            : [],
        "voice_generation": includeAccountVoices
            ? [["voice_id": "account-generated", "description": ["Designed"]]]
            : [],
        "music_generation": [],
        "base_resp": [
            "status_code": baseStatus,
            "status_msg": baseMessage,
        ],
    ]
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private struct ContractChecks {
    private(set) var checksRun = 0

    mutating func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        checksRun += 1
        guard condition() else { throw CheckFailure(message: message) }
    }

    mutating func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String
    ) throws {
        try expect(actual == expected, "\(message): expected \(expected), got \(actual)")
    }

    mutating func expectHexFailure(
        _ encoded: String,
        expected expectedError: MiniMaxAudioError,
        _ message: String
    ) throws {
        checksRun += 1
        do {
            _ = try MiniMaxAudioClient.decodeStrictHex(encoded)
        } catch let error as MiniMaxAudioError {
            let matches: Bool
            switch (error, expectedError) {
            case (.emptyAudio, .emptyAudio),
                 (.malformedHexAudio, .malformedHexAudio):
                matches = true
            default:
                matches = false
            }
            guard matches else {
                throw CheckFailure(message: "\(message): received \(error.localizedDescription)")
            }
            return
        } catch {
            throw CheckFailure(message: "\(message): received unexpected error \(error)")
        }
        throw CheckFailure(message: "\(message): malformed input was accepted")
    }

    mutating func expectClientError<T>(
        _ expected: ExpectedClientError,
        _ message: String,
        operation: () async throws -> T
    ) async throws {
        checksRun += 1
        do {
            _ = try await operation()
        } catch let error as MiniMaxAudioError {
            let matches: Bool
            switch (error, expected) {
            case (.cancelled, .cancelled):
                matches = true
            case let (.httpStatus(actual), .httpStatus(expectedStatus)):
                matches = actual == expectedStatus
            case let (.apiStatus(actual, _), .apiStatus(expectedStatus)):
                matches = actual == expectedStatus
            case let (.incompleteAudio(actual), .incompleteAudio(expectedStatus)):
                matches = actual == expectedStatus
            case (.missingAudio, .missingAudio):
                matches = true
            case let (.responseMetadataMismatch(reason), .metadataMismatch(fragment)):
                matches = reason.contains(fragment)
            default:
                matches = false
            }
            guard matches else {
                throw CheckFailure(message: "\(message): received \(error.localizedDescription)")
            }
            return
        } catch {
            throw CheckFailure(message: "\(message): received unexpected error \(error)")
        }
        throw CheckFailure(message: "\(message): operation unexpectedly succeeded")
    }

    mutating func runHexChecks() throws {
        try expectEqual(
            try MiniMaxAudioClient.decodeStrictHex("00ff10a5"),
            Data([0x00, 0xff, 0x10, 0xa5]),
            "Lowercase hex decodes byte-for-byte"
        )
        try expectEqual(
            try MiniMaxAudioClient.decodeStrictHex("4D5033"),
            Data([0x4d, 0x50, 0x33]),
            "Uppercase hex is accepted"
        )
        try expectHexFailure(
            "",
            expected: .emptyAudio,
            "An empty payload is rejected explicitly"
        )
        try expectHexFailure(
            "abc",
            expected: .malformedHexAudio,
            "Odd-length hex is rejected"
        )
        try expectHexFailure(
            "0g",
            expected: .malformedHexAudio,
            "Non-hex characters are rejected"
        )
        try expectHexFailure(
            "00 ff",
            expected: .malformedHexAudio,
            "Whitespace is not silently tolerated inside a strict payload"
        )
    }

    mutating func runCacheIdentityChecks() throws -> MiniMaxSpeechCacheIdentity {
        let base = MiniMaxSpeechConfiguration(
            region: .mainlandChina,
            model: MiniMaxSpeechConfiguration.defaultModel,
            voiceID: MiniMaxSpeechConfiguration.defaultChineseVoice,
            languageBoost: .chinese,
            speed: 1.0
        )
        let fixture = MiniMaxSpeechCacheIdentity(
            text: "你好，世界！",
            languageCode: "zh-CN",
            configuration: base
        )
        let same = MiniMaxSpeechCacheIdentity(
            text: "  你好，世界！\r\n",
            languageCode: " ZH-CN ",
            configuration: MiniMaxSpeechConfiguration(
                region: .mainlandChina,
                model: "  speech-2.8-turbo ",
                voiceID: " Chinese (Mandarin)_News_Anchor  ",
                languageBoost: .chinese,
                speed: 1.0,
                format: "MP3"
            )
        )

        try expectEqual(
            fixture.cacheKey,
            "93432d55bc2443998f7d3789e9c20ea830373fa973273002b3d0972951b95fe6",
            "The schema-v2 language-aware cache fixture remains stable"
        )
        try expectEqual(
            same.cacheKey,
            fixture.cacheKey,
            "Equivalent normalized text, language, and settings reuse one key"
        )
        try expectEqual(
            same.normalizedText,
            "你好，世界！",
            "Text normalization removes only boundary whitespace and line-ending noise"
        )
        try expectEqual(
            same.languageCode,
            "zh-cn",
            "Language identifiers normalize case and boundary whitespace"
        )
        try expect(
            fixture.cacheKey.count == 64 && fixture.cacheKey.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            },
            "Cache keys are lowercase SHA-256 hex"
        )

        let canonicallyEquivalent = MiniMaxSpeechCacheIdentity(
            text: " Cafe\u{0301} ",
            languageCode: "en-US",
            configuration: base
        )
        let precomposed = MiniMaxSpeechCacheIdentity(
            text: "Caf\u{00E9}",
            languageCode: "en-us",
            configuration: base
        )
        try expectEqual(
            canonicallyEquivalent.cacheKey,
            precomposed.cacheKey,
            "Canonically equivalent Unicode text shares one key"
        )

        let variants: [(String, MiniMaxSpeechCacheIdentity)] = [
            (
                "text",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界。",
                    languageCode: "zh-CN",
                    configuration: base
                )
            ),
            (
                "language",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界！",
                    languageCode: "zh-Hans",
                    configuration: base
                )
            ),
            (
                "region",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界！",
                    languageCode: "zh-CN",
                    configuration: MiniMaxSpeechConfiguration(
                        region: .international,
                        model: base.model,
                        voiceID: base.voiceID,
                        languageBoost: base.languageBoost,
                        speed: base.speed
                    )
                )
            ),
            (
                "model",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界！",
                    languageCode: "zh-CN",
                    configuration: MiniMaxSpeechConfiguration(
                        region: base.region,
                        model: "speech-2.8-hd",
                        voiceID: base.voiceID,
                        languageBoost: base.languageBoost,
                        speed: base.speed
                    )
                )
            ),
            (
                "voice",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界！",
                    languageCode: "zh-CN",
                    configuration: MiniMaxSpeechConfiguration(
                        region: base.region,
                        model: base.model,
                        voiceID: "Chinese (Mandarin)_Reliable_Executive",
                        languageBoost: base.languageBoost,
                        speed: base.speed
                    )
                )
            ),
            (
                "speed",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界！",
                    languageCode: "zh-CN",
                    configuration: MiniMaxSpeechConfiguration(
                        region: base.region,
                        model: base.model,
                        voiceID: base.voiceID,
                        languageBoost: base.languageBoost,
                        speed: 0.9
                    )
                )
            ),
            (
                "encoding",
                MiniMaxSpeechCacheIdentity(
                    text: "你好，世界！",
                    languageCode: "zh-CN",
                    configuration: MiniMaxSpeechConfiguration(
                        region: base.region,
                        model: base.model,
                        voiceID: base.voiceID,
                        languageBoost: base.languageBoost,
                        speed: base.speed,
                        bitrate: 192_000
                    )
                )
            ),
        ]
        for (field, variant) in variants {
            try expect(
                variant.cacheKey != fixture.cacheKey,
                "Changing \(field) changes the paid-audio cache identity"
            )
        }

        return fixture
    }

    mutating func runClientChecks(identity: MiniMaxSpeechCacheIdentity) async throws {
        let session = stubbedSession()
        defer { session.invalidateAndCancel() }
        let client = MiniMaxAudioClient(session: session)
        let successBody = try t2aResponse()

        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: successBody)
        }
        let result = try await client.synthesize(
            identity: identity,
            apiKey: "  offline-contract-token  "
        )

        let observations = MiniMaxURLProtocolStub.requests()
        try expectEqual(observations.count, 1, "A synthesis performs exactly one HTTP request")
        guard let request = observations.first else {
            throw CheckFailure(message: "The synthesis request was not captured")
        }
        try expectEqual(request.method, "POST", "The T2A request uses POST")
        try expectEqual(
            request.url?.absoluteString,
            "https://api.minimaxi.com/v1/t2a_v2",
            "Mainland China speech uses the current T2A v2 endpoint"
        )
        try expect(
            request.url?.query?.lowercased().contains("groupid") != true,
            "The current T2A endpoint does not receive a deprecated GroupId query"
        )
        try expectEqual(
            request.header(named: "Authorization"),
            "Bearer offline-contract-token",
            "Authorization is a trimmed Bearer credential"
        )
        try expectEqual(
            request.header(named: "Content-Type"),
            "application/json",
            "The request body is declared as JSON"
        )
        try expectEqual(
            request.header(named: "Accept"),
            "application/json",
            "The client explicitly accepts JSON"
        )

        guard let body = request.body,
              let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let voice = payload["voice_setting"] as? [String: Any],
              let audio = payload["audio_setting"] as? [String: Any] else {
            throw CheckFailure(message: "The captured T2A request body is not valid JSON")
        }
        try expectEqual(payload["model"] as? String, "speech-2.8-turbo", "Payload includes the selected model")
        try expectEqual(payload["text"] as? String, "你好，世界！", "Payload includes normalized source text")
        try expectEqual(payload["stream"] as? Bool, false, "Interactive generation is non-streaming")
        try expectEqual(payload["language_boost"] as? String, "Chinese", "Mandarin payload explicitly selects Chinese")
        try expectEqual(payload["output_format"] as? String, "hex", "Non-streaming output requests strict hex")

        try expectEqual(
            voice["voice_id"] as? String,
            "Chinese (Mandarin)_News_Anchor",
            "Payload includes the configured voice"
        )
        try expectEqual((voice["speed"] as? NSNumber)?.doubleValue, 1.0, "Payload includes speech speed")
        try expectEqual((voice["vol"] as? NSNumber)?.doubleValue, 1.0, "Payload keeps the supported volume")
        try expectEqual((voice["pitch"] as? NSNumber)?.intValue, 0, "Payload keeps the supported pitch")

        try expectEqual((audio["sample_rate"] as? NSNumber)?.intValue, 32_000, "Payload requests 32 kHz audio")
        try expectEqual((audio["bitrate"] as? NSNumber)?.intValue, 128_000, "Payload requests 128 kbps audio")
        try expectEqual(audio["format"] as? String, "mp3", "Payload requests MP3")
        try expectEqual((audio["channel"] as? NSNumber)?.intValue, 1, "Payload requests mono audio")

        try expectEqual(result.audioData, Data([0x49, 0x44, 0x33]), "Successful hex audio reaches the caller as bytes")
        try expectEqual(result.durationMilliseconds, 321, "Successful duration metadata is preserved")
        try expectEqual(result.reportedByteCount, 3, "Successful byte-count metadata is preserved")
        try expectEqual(result.audioFormat, "mp3", "Successful format metadata is preserved")
        try expectEqual(result.traceID, "offline-trace", "Successful trace metadata is preserved")

        let internationalIdentity = MiniMaxSpeechCacheIdentity(
            text: identity.normalizedText,
            languageCode: identity.languageCode,
            configuration: MiniMaxSpeechConfiguration(
                region: .international,
                model: identity.configuration.model,
                voiceID: identity.configuration.voiceID,
                languageBoost: identity.configuration.languageBoost,
                speed: identity.configuration.speed
            )
        )
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: successBody)
        }
        _ = try await client.synthesize(
            identity: internationalIdentity,
            apiKey: "offline-contract-token"
        )
        try expectEqual(
            MiniMaxURLProtocolStub.requests().first?.url?.absoluteString,
            "https://api.minimax.io/v1/t2a_v2",
            "International speech uses the current global T2A v2 endpoint"
        )

        let englishIdentity = MiniMaxSpeechCacheIdentity(
            text: "Hello from MiniMax.",
            languageCode: "en-US",
            configuration: MiniMaxSpeechConfiguration(
                region: .mainlandChina,
                model: "speech-2.8-turbo",
                voiceID: "English_Graceful_Lady",
                languageBoost: .english,
                speed: 1
            )
        )
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: successBody)
        }
        _ = try await client.synthesize(
            identity: englishIdentity,
            apiKey: "offline-contract-token"
        )
        guard let englishBody = MiniMaxURLProtocolStub.requests().first?.body,
              let englishPayload = try JSONSerialization.jsonObject(
                with: englishBody
              ) as? [String: Any] else {
            throw CheckFailure(message: "The English request body was not captured")
        }
        try expectEqual(
            englishPayload["language_boost"] as? String,
            "English",
            "English payload explicitly selects English"
        )

        let mismatchedIdentity = MiniMaxSpeechCacheIdentity(
            text: "你好",
            languageCode: "zh-CN",
            configuration: englishIdentity.configuration
        )
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: successBody)
        }
        checksRun += 1
        do {
            _ = try await client.synthesize(
                identity: mismatchedIdentity,
                apiKey: "offline-contract-token"
            )
            throw CheckFailure(message: "A mismatched text/configuration language was accepted")
        } catch let error as MiniMaxAudioError {
            guard case .invalidConfiguration = error else {
                throw CheckFailure(message: "A language mismatch produced the wrong typed error")
            }
        }
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            0,
            "A language mismatch is rejected before any paid request"
        )

        let wrongSystemVoiceIdentity = MiniMaxSpeechCacheIdentity(
            text: "你好",
            languageCode: "zh-CN",
            configuration: MiniMaxSpeechConfiguration(
                region: .mainlandChina,
                model: "speech-2.8-turbo",
                voiceID: "English_Graceful_Lady",
                languageBoost: .chinese,
                speed: 1
            )
        )
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: successBody)
        }
        checksRun += 1
        do {
            _ = try await client.synthesize(
                identity: wrongSystemVoiceIdentity,
                apiKey: "offline-contract-token"
            )
            throw CheckFailure(message: "A known English system voice was accepted for Mandarin")
        } catch let error as MiniMaxAudioError {
            guard case .invalidConfiguration = error else {
                throw CheckFailure(message: "A system-voice language mismatch produced the wrong typed error")
            }
        }
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            0,
            "A known wrong-language system voice is rejected before any paid request"
        )

        let customPrefixVoiceIdentity = MiniMaxSpeechCacheIdentity(
            text: "你好",
            languageCode: "zh-CN",
            configuration: MiniMaxSpeechConfiguration(
                region: .mainlandChina,
                model: "speech-2.8-turbo",
                voiceID: "English_my_account_clone",
                languageBoost: .chinese,
                voiceUsesCustomLanguageAssignment: true,
                speed: 1
            )
        )
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: successBody)
        }
        _ = try await client.synthesize(
            identity: customPrefixVoiceIdentity,
            apiKey: "offline-contract-token"
        )
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            1,
            "An explicitly assigned account voice is not misclassified by its custom prefix"
        )

        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 429, body: Data())
        }
        try await expectClientError(.httpStatus(429), "Non-success HTTP status is rejected") {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }

        let baseFailure = try t2aResponse(baseStatus: 1002, baseMessage: "fixture failure")
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: baseFailure)
        }
        try await expectClientError(.apiStatus(1002), "MiniMax base_resp failure is rejected") {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }

        let incomplete = try t2aResponse(audioStatus: 1)
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: incomplete)
        }
        try await expectClientError(
            .incompleteAudio(1),
            "An unfinished MiniMax audio status is rejected"
        ) {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }

        let missingAudio = try t2aResponse(audioHex: nil)
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: missingAudio)
        }
        try await expectClientError(.missingAudio, "A completed response without audio is rejected") {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }

        let wrongSize = try t2aResponse(audioSize: 4)
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: wrongSize)
        }
        try await expectClientError(
            .metadataMismatch(containing: "reported 4 bytes"),
            "Reported byte count must match decoded audio"
        ) {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }

        let wrongFormat = try t2aResponse(audioFormat: "wav")
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: wrongFormat)
        }
        try await expectClientError(
            .metadataMismatch(containing: "reported wav instead of mp3"),
            "Reported format must match requested encoding"
        ) {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }

        MiniMaxURLProtocolStub.install { _ in .waitForCancellation }
        let cancellationTask = Task {
            try await client.synthesize(identity: identity, apiKey: "offline-contract-token")
        }
        for _ in 0..<100 where MiniMaxURLProtocolStub.requests().isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            1,
            "The cancellation fixture intercepted the request before cancellation"
        )
        cancellationTask.cancel()
        try await expectClientError(.cancelled, "Task cancellation becomes the typed client error") {
            try await cancellationTask.value
        }
    }

    mutating func runCatalogModelChecks() throws {
        let models = MiniMaxSpeechModelDescriptor.selectableModels
        try expectEqual(models.count, 8, "The bundled T2A catalog includes current and accepted legacy models")
        try expectEqual(models.first?.id, "speech-2.8-turbo", "The latest low-latency model leads the catalog")
        try expectEqual(
            Set(models.filter(\.isLatestFamily).map(\.id)),
            Set(["speech-2.8-turbo", "speech-2.8-hd"]),
            "Only Speech 2.8 is marked as the latest family"
        )
        try expectEqual(
            Set(models.filter { $0.lifecycle == .legacy }.map(\.id)),
            Set([
                "speech-2.6-turbo", "speech-2.6-hd",
                "speech-02-turbo", "speech-02-hd",
                "speech-01-turbo", "speech-01-hd",
            ]),
            "Every older accepted family is clearly labeled as compatible legacy"
        )
        try expectEqual(
            MiniMaxVoiceDescriptor.classifySystemVoiceID("Chinese (Mandarin)_News_Anchor"),
            .mandarinChinese,
            "The normal Mandarin system prefix is classified"
        )
        try expectEqual(
            MiniMaxVoiceDescriptor.classifySystemVoiceID("Arrogant_Miss"),
            .mandarinChinese,
            "The documented Mandarin prefix exception remains available"
        )
        try expectEqual(
            MiniMaxVoiceDescriptor.classifySystemVoiceID("Robot_Armor"),
            .mandarinChinese,
            "The second documented Mandarin prefix exception remains available"
        )
        try expectEqual(
            MiniMaxVoiceDescriptor.classifySystemVoiceID("English_Graceful_Lady"),
            .english,
            "The English system prefix is classified"
        )
        try expect(
            MiniMaxVoiceDescriptor.classifySystemVoiceID("Unknown") == nil,
            "Unknown system voices are not assigned a guessed language"
        )
        try expect(
            !MiniMaxVoiceDescriptor.usesSlotLanguageAssignment(
                voiceID: "English_Graceful_Lady",
                catalogSource: nil
            ),
            "A manually entered known English system ID remains language-validated"
        )
        try expect(
            !MiniMaxVoiceDescriptor.usesSlotLanguageAssignment(
                voiceID: "Chinese (Mandarin)_News_Anchor",
                catalogSource: .system
            ),
            "A catalog system voice remains language-validated"
        )
        try expect(
            MiniMaxVoiceDescriptor.usesSlotLanguageAssignment(
                voiceID: "English_my_account_clone",
                catalogSource: .voiceCloning
            ),
            "Live account provenance overrides a system-looking voice prefix"
        )
        try expect(
            MiniMaxVoiceDescriptor.usesSlotLanguageAssignment(
                voiceID: "my_unclassified_voice",
                catalogSource: nil
            ),
            "An unclassified custom ID takes its language from the selected slot"
        )
        try expect(
            !MiniMaxVoiceDescriptor.reconciledSlotLanguageAssignment(
                voiceID: "English_my_account_clone",
                persistedAssignment: true,
                liveCatalogSource: nil,
                scopeChanged: true
            ),
            "A key or region change revokes stale custom provenance for a system-looking ID"
        )
        try expect(
            MiniMaxVoiceDescriptor.reconciledSlotLanguageAssignment(
                voiceID: "English_my_account_clone",
                persistedAssignment: false,
                liveCatalogSource: .voiceCloning,
                scopeChanged: false
            ),
            "A new live account catalog can restore custom provenance"
        )
        try expect(
            !MiniMaxVoiceDescriptor.reconciledSlotLanguageAssignment(
                voiceID: "English_Graceful_Lady",
                persistedAssignment: true,
                liveCatalogSource: .system,
                scopeChanged: false
            ),
            "A live system descriptor demotes stale custom provenance"
        )
        try expect(
            MiniMaxVoiceDescriptor.reconciledSlotLanguageAssignment(
                voiceID: "my_unclassified_voice",
                persistedAssignment: true,
                liveCatalogSource: nil,
                scopeChanged: true
            ),
            "An unclassified custom ID preserves its chosen slot across scope changes"
        )
    }

    mutating func runVoiceCatalogChecks() async throws {
        let session = stubbedSession()
        defer { session.invalidateAndCancel() }
        let body = try voiceCatalogResponse()
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: body)
        }

        let client = MiniMaxVoiceCatalogClient(session: session)
        let catalog = try await client.fetch(
            region: .mainlandChina,
            apiKey: "  offline-catalog-token  "
        )
        let observations = MiniMaxURLProtocolStub.requests()
        try expectEqual(observations.count, 1, "One voice refresh performs exactly one HTTP request")
        guard let request = observations.first,
              let requestBody = request.body,
              let requestJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any] else {
            throw CheckFailure(message: "The voice-catalog request was not captured as JSON")
        }
        try expectEqual(request.method, "POST", "Voice refresh uses POST")
        try expectEqual(
            request.url?.absoluteString,
            "https://api.minimaxi.com/v1/get_voice",
            "Mainland voice refresh uses the selected regional endpoint"
        )
        try expectEqual(
            request.header(named: "Authorization"),
            "Bearer offline-catalog-token",
            "Voice refresh trims and applies the bearer credential"
        )
        try expectEqual(requestJSON["voice_type"] as? String, "all", "Voice refresh requests every voice source")

        try expectEqual(catalog.systemVoices.count, 4, "All unique system voices decode")
        try expectEqual(catalog.mandarinSystemVoices.count, 2, "Prefix and exception Mandarin voices are retained")
        try expectEqual(catalog.englishSystemVoices.count, 1, "English system voices are separated")
        try expectEqual(catalog.unclassifiedSystemVoices.count, 1, "Unclassified system voices remain visible")
        try expectEqual(catalog.clonedVoices.count, 1, "Account cloned voices decode without language guesses")
        try expectEqual(catalog.generatedVoices.count, 1, "Account generated voices decode")
        try expect(catalog.accountVoices.allSatisfy { $0.knownLanguage == nil }, "Account voices never inherit a guessed locale")
        try expectEqual(
            catalog.systemVoices.first { $0.voiceID == "English_Graceful_Lady" }?.descriptions,
            ["Warm English voice"],
            "A scalar description decodes as one description"
        )
        try expectEqual(
            catalog.systemVoices.first { $0.voiceID == "Chinese (Mandarin)_News_Anchor" }?.descriptions,
            ["清晰", "沉稳"],
            "A description array round-trips"
        )

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-catalog-cache-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }
        let cache = MiniMaxVoiceCatalogCache(directoryURL: root)
        try await cache.savePublicMetadata(from: catalog)
        guard let cached = try await cache.load(region: .mainlandChina) else {
            throw CheckFailure(message: "The public voice catalog did not reload")
        }
        try expectEqual(cached.origin, .cachedPublicMetadata, "Reloaded catalog identifies its offline origin")
        try expectEqual(cached.systemVoices.count, 4, "Public system metadata persists")
        try expectEqual(cached.accountVoices.count, 0, "Private account voice metadata is not persisted")

        let failedBody = try voiceCatalogResponse(baseStatus: 2049, baseMessage: "invalid key region")
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: failedBody)
        }
        checksRun += 1
        do {
            _ = try await client.fetch(region: .international, apiKey: "offline-catalog-token")
            throw CheckFailure(message: "A voice-catalog application error was accepted")
        } catch let error as MiniMaxVoiceCatalogError {
            guard case .apiStatus(code: 2049, message: _) = error else {
                throw CheckFailure(message: "Voice-catalog application error had the wrong type")
            }
        }
    }

    mutating func runCatalogStoreChecks() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-catalog-store-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: root) }

        let session = stubbedSession()
        defer { session.invalidateAndCancel() }
        let client = MiniMaxVoiceCatalogClient(session: session)
        let cache = MiniMaxVoiceCatalogCache(directoryURL: root)
        let store = await MainActor.run {
            MiniMaxAudioCatalogStore(
                activeRegion: .international,
                client: client,
                cache: cache
            )
        }

        let slowInternational = try voiceCatalogResponse(
            primaryMandarinVoiceID: "Chinese (Mandarin)_Old_Account"
        )
        let fastMainland = try voiceCatalogResponse(
            primaryMandarinVoiceID: "Chinese (Mandarin)_Newest_Account"
        )
        MiniMaxURLProtocolStub.install { request in
            if request.url?.host == "api.minimax.io" {
                return .respond(
                    statusCode: 200,
                    body: slowInternational,
                    delayNanoseconds: 200_000_000
                )
            }
            return .respond(statusCode: 200, body: fastMainland)
        }

        let olderRefresh = Task {
            await store.refresh(region: .international, apiKey: "older-account")
        }
        for _ in 0..<100 where MiniMaxURLProtocolStub.requests().isEmpty {
            try await Task.sleep(for: .milliseconds(2))
        }
        let newestRefresh = Task {
            await store.refresh(region: .mainlandChina, apiKey: "newest-account")
        }
        await newestRefresh.value
        await olderRefresh.value

        let newestState = await MainActor.run {
            (
                store.activeRegion,
                store.catalog?.systemVoices.first?.voiceID,
                store.catalog?.accountVoices.count,
                store.isRefreshing
            )
        }
        try expectEqual(
            newestState.0,
            .mainlandChina,
            "The newest regional refresh remains active"
        )
        try expectEqual(
            newestState.1,
            "Chinese (Mandarin)_Newest_Account",
            "A late older response cannot replace the newest voice catalog"
        )
        try expectEqual(
            newestState.2,
            2,
            "A successful live refresh exposes the current account's voices in memory"
        )
        try expectEqual(
            newestState.3,
            false,
            "The latest completed request clears refreshing state"
        )

        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: slowInternational)
        }
        await store.refresh(region: .international, apiKey: "newest-account")
        await MainActor.run { store.activate(region: .mainlandChina) }

        await MainActor.run {
            store.activateSharedCredential(apiKey: "replacement-account")
        }
        let strippedState = await MainActor.run {
            let mainland = (
                store.catalog?.systemVoices.count,
                store.catalog?.accountVoices.count,
                store.catalog?.origin
            )
            store.activate(region: .international)
            let international = (
                store.catalog?.accountVoices.count,
                store.catalog?.origin
            )
            store.activate(region: .mainlandChina)
            return (
                mainland.0,
                mainland.1,
                mainland.2,
                international.0,
                international.1
            )
        }
        try expectEqual(
            strippedState.0,
            4,
            "Changing credentials preserves public system voices"
        )
        try expectEqual(
            strippedState.1,
            0,
            "Changing credentials immediately removes the prior account's private voices"
        )
        try expectEqual(
            strippedState.2,
            .cachedPublicMetadata,
            "Public voices retained after a key change are labeled as an offline snapshot"
        )
        try expectEqual(
            strippedState.3,
            0,
            "A shared-key change also strips private voices from the inactive region"
        )
        try expectEqual(
            strippedState.4,
            .cachedPublicMetadata,
            "The inactive region is also prevented from claiming a stale live catalog"
        )

        let failedBody = try voiceCatalogResponse(
            baseStatus: 2049,
            baseMessage: "invalid replacement account"
        )
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: failedBody)
        }
        await store.refresh(
            region: .mainlandChina,
            apiKey: "replacement-account"
        )
        let failedState = await MainActor.run {
            (
                store.catalog?.systemVoices.count,
                store.catalog?.accountVoices.count,
                store.errorMessage != nil
            )
        }
        try expectEqual(
            failedState.0,
            4,
            "A failed replacement-account refresh retains public voice choices"
        )
        try expectEqual(
            failedState.1,
            0,
            "A failed replacement-account refresh cannot restore stale private voices"
        )
        try expectEqual(
            failedState.2,
            true,
            "A failed refresh remains visible to the user"
        )

        let noAccountBody = try voiceCatalogResponse(includeAccountVoices: false)
        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: noAccountBody)
        }
        await store.refresh(
            region: .mainlandChina,
            apiKey: "replacement-account"
        )
        let liveEmptyAccountState = await MainActor.run {
            (store.catalog?.origin, store.catalog?.accountVoices.count)
        }
        try expectEqual(
            liveEmptyAccountState.0,
            .live,
            "A successful zero-account-voice refresh is initially live"
        )
        try expectEqual(
            liveEmptyAccountState.1,
            0,
            "The zero-account-voice fixture contains no private voices"
        )

        await MainActor.run {
            store.activateSharedCredential(apiKey: "empty-account-replacement")
        }
        let strippedEmptyAccountOrigin = await MainActor.run {
            store.catalog?.origin
        }
        try expectEqual(
            strippedEmptyAccountOrigin,
            .cachedPublicMetadata,
            "A live zero-account-voice catalog cannot remain labeled live after a key change"
        )

        guard let cached = try await cache.load(region: .mainlandChina) else {
            throw CheckFailure(message: "The catalog store did not persist its live public catalog")
        }
        try expectEqual(
            cached.accountVoices.count,
            0,
            "The store's offline snapshot never contains credential-scoped voices"
        )
    }

    mutating func runBatchAudioPlannerChecks() throws {
        let chineseConfiguration = MiniMaxSpeechConfiguration(
            region: .mainlandChina,
            model: "speech-2.8-turbo",
            voiceID: "Chinese (Mandarin)_News_Anchor",
            languageBoost: .chinese,
            speed: 1
        )
        let englishConfiguration = MiniMaxSpeechConfiguration(
            region: .mainlandChina,
            model: "speech-2.8-turbo",
            voiceID: "English_Graceful_Lady",
            languageBoost: .english,
            speed: 1
        )
        let firstID = UUID()
        let snapshots = [
            BatchAudioTermSnapshot(
                termID: firstID,
                displayWord: "你好",
                chineseText: " 你好 ",
                englishText: "hello"
            ),
            BatchAudioTermSnapshot(
                termID: UUID(),
                displayWord: "duplicate",
                chineseText: "你好",
                englishText: "hello"
            ),
            BatchAudioTermSnapshot(
                termID: UUID(),
                displayWord: "学习",
                chineseText: "学习",
                englishText: ""
            ),
        ]

        let uncached = BatchAudioPlanner.makePlan(
            terms: snapshots,
            scope: .bothLanguages,
            learningIsChinese: true,
            chineseConfiguration: chineseConfiguration,
            englishConfiguration: englishConfiguration,
            existingRecordIDs: []
        )
        try expectEqual(uncached.totalClipCount, 3, "Duplicate bilingual terms collapse to unique paid identities")
        try expectEqual(uncached.newMandarinClipCount, 2, "Both unique Mandarin clips are planned")
        try expectEqual(uncached.newEnglishClipCount, 1, "One unique English clip is planned")
        try expect(
            uncached.allTargets.filter(\.isMandarin).allSatisfy {
                $0.identity.languageBoost == .chinese && $0.languageCode == "zh-cn"
            },
            "Every Mandarin batch target uses explicit Chinese language selection"
        )
        try expect(
            uncached.allTargets.filter { !$0.isMandarin }.allSatisfy {
                $0.identity.languageBoost == .english && $0.languageCode == "en-us"
            },
            "Every English batch target uses explicit English language selection"
        )

        guard let cachedEnglishID = uncached.allTargets.first(where: { !$0.isMandarin })?.id else {
            throw CheckFailure(message: "The bilingual plan omitted its English identity")
        }
        let resumed = BatchAudioPlanner.makePlan(
            terms: snapshots,
            scope: .bothLanguages,
            learningIsChinese: true,
            chineseConfiguration: chineseConfiguration,
            englishConfiguration: englishConfiguration,
            existingRecordIDs: [cachedEnglishID]
        )
        try expectEqual(resumed.cachedClipCount, 1, "Preflight excludes a matching persisted clip")
        try expectEqual(resumed.newClipCount, 2, "Only uncached clips remain paid work")
        try expectEqual(resumed.totalNewCharacters, 4, "Character preflight counts only uncached normalized text")

        guard let newlyCachedID = resumed.pendingTargets.first?.id else {
            throw CheckFailure(message: "The resumed fixture omitted pending work")
        }
        let revalidated = try BatchAudioPlanRevalidator.revalidate(
            reviewed: resumed,
            existingRecordIDs: [cachedEnglishID, newlyCachedID]
        )
        try expectEqual(
            revalidated.cachedClipCount,
            2,
            "Cache revalidation safely reduces paid work added after review"
        )
        try expectEqual(
            revalidated.newClipCount,
            1,
            "Only still-missing reviewed targets remain after revalidation"
        )
        checksRun += 1
        do {
            _ = try BatchAudioPlanRevalidator.revalidate(
                reviewed: resumed,
                existingRecordIDs: []
            )
            throw CheckFailure(message: "A deleted reviewed cache hit silently expanded paid work")
        } catch BatchAudioPlanRevalidationError.reviewedSavedAudioChanged {
            // Expected: renewed confirmation is required before new charges.
        }

        let learningEnglish = BatchAudioPlanner.makePlan(
            terms: snapshots,
            scope: .learningLanguage,
            learningIsChinese: false,
            chineseConfiguration: chineseConfiguration,
            englishConfiguration: englishConfiguration,
            existingRecordIDs: []
        )
        try expectEqual(learningEnglish.totalClipCount, 1, "Learning-language scope selects and deduplicates only English")
        try expectEqual(learningEnglish.newMandarinClipCount, 0, "English learning scope schedules no Mandarin clip")
    }

    mutating func runBatchAudioOrchestrationChecks() async throws {
        try expect(
            BatchAudioFailurePolicy.shouldStop(
                after: MiniMaxAudioError.persistence("disk full fixture")
            ),
            "A systemic persistence failure stops remaining paid requests"
        )
        try expect(
            BatchAudioFailurePolicy.shouldStop(
                after: MiniMaxAudioError.httpStatus(429)
            ),
            "A client/rate-limit HTTP failure stops the current paid queue"
        )
        try expect(
            BatchAudioFailurePolicy.shouldStop(
                after: MiniMaxAudioError.httpStatus(503)
            ),
            "A server failure stops an ambiguous paid queue"
        )
        try expect(
            BatchAudioFailurePolicy.shouldStop(
                after: MiniMaxAudioError.transport("offline fixture")
            ),
            "A transport failure requires explicit cache-first resume"
        )

        let gate = BatchAudioStartGate(intervalNanoseconds: 20_000_000)
        let start = DispatchTime.now().uptimeNanoseconds
        try await gate.waitForPermit()
        try await gate.waitForPermit()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        try expect(
            elapsed >= 15_000_000,
            "The audio start gate spaces paid request starts"
        )

        let cancellationGate = BatchAudioStartGate(intervalNanoseconds: 1_000_000_000)
        try await cancellationGate.waitForPermit()
        let waitingTask = Task {
            try await cancellationGate.waitForPermit()
        }
        waitingTask.cancel()
        checksRun += 1
        do {
            try await waitingTask.value
            throw CheckFailure(message: "A cancelled paced request still received a permit")
        } catch is CancellationError {
            // Expected: cancellation prevents a later paid request start.
        }
    }

    mutating func runRepositoryChecks(identity: MiniMaxSpeechCacheIdentity) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-audio-contracts-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let audio = Data([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x01])
        let result = MiniMaxSynthesisResult(
            audioData: audio,
            durationMilliseconds: 1_250,
            reportedByteCount: audio.count,
            audioFormat: "mp3",
            traceID: "offline-fixture"
        )

        let firstRepository = GeneratedSpeechRepository(rootDirectory: root)
        let firstSave = try await firstRepository.save(result: result, identity: identity)
        try expect(!firstSave.wasCached, "The first save is identified as newly generated")
        try expectEqual(firstSave.record.id, identity.cacheKey, "The record ID is the cache key")
        try expectEqual(firstSave.record.byteCount, audio.count, "The record stores the decoded byte count")
        try expectEqual(firstSave.record.durationMilliseconds, 1_250, "The record stores MiniMax duration metadata")
        try expect(fileManager.fileExists(atPath: firstSave.fileURL.path), "Saving creates a persistent MP3")
        try expectEqual(try Data(contentsOf: firstSave.fileURL), audio, "The persistent MP3 bytes round-trip")

        let duplicateSave = try await firstRepository.save(result: result, identity: identity)
        try expect(duplicateSave.wasCached, "A duplicate paid result reuses the existing file")
        let directCacheHit = try await firstRepository.cachedSpeech(for: identity)
        try expect(directCacheHit?.wasCached == true, "Repository lookup reports an explicit cache hit")

        let indexURL = root
            .appendingPathComponent("GeneratedAudio", isDirectory: true)
            .appendingPathComponent("index.json", isDirectory: false)
        try expect(fileManager.fileExists(atPath: indexURL.path), "Saving atomically creates the JSON index")

        let staleRecoveryURL = indexURL.deletingLastPathComponent()
            .appendingPathComponent("index.recovery-stale.json", isDirectory: false)
        try Data("private rollback fixture".utf8).write(to: staleRecoveryURL, options: .atomic)

        let reloadedRepository = GeneratedSpeechRepository(rootDirectory: root)
        let reloadedRecords = try await reloadedRepository.allRecords()
        try expectEqual(reloadedRecords.count, 1, "A fresh repository reloads one persisted record")
        try expect(
            !fileManager.fileExists(atPath: staleRecoveryURL.path),
            "A supported-schema reload removes stale private recovery metadata"
        )
        try expectEqual(reloadedRecords.first?.id, identity.cacheKey, "Reload preserves record identity")
        let reloadedURL = try await reloadedRepository.fileURL(for: identity.cacheKey)
        try expectEqual(try Data(contentsOf: reloadedURL), audio, "Reload resolves the persisted audio URL")

        try await reloadedRepository.delete(recordID: identity.cacheKey)
        try expect(!fileManager.fileExists(atPath: reloadedURL.path), "Delete removes the persistent MP3")
        try expectEqual(
            try await reloadedRepository.allRecords().count,
            0,
            "Delete removes the in-memory record"
        )

        let afterDeleteRepository = GeneratedSpeechRepository(rootDirectory: root)
        try expectEqual(
            try await afterDeleteRepository.allRecords().count,
            0,
            "Delete persists across repository reloads"
        )
        let missingFileError: Error?
        do {
            _ = try await afterDeleteRepository.fileURL(for: identity.cacheKey)
            missingFileError = nil
        } catch {
            missingFileError = error
        }
        checksRun += 1
        guard let audioError = missingFileError as? MiniMaxAudioError,
              case .missingPersistedAudio = audioError else {
            throw CheckFailure(message: "A deleted record fails with missingPersistedAudio")
        }
    }

    mutating func runCorruptIndexRecoveryChecks(
        identity: MiniMaxSpeechCacheIdentity
    ) async throws {
        try await runMalformedIndexRecoveryChecks(identity: identity)
        try await runFutureIndexPreservationChecks(identity: identity)
    }

    private mutating func runMalformedIndexRecoveryChecks(
        identity: MiniMaxSpeechCacheIdentity
    ) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-malformed-index-\(UUID().uuidString)",
            isDirectory: true
        )
        let audioDirectory = root.appendingPathComponent("GeneratedAudio", isDirectory: true)
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let indexURL = audioDirectory.appendingPathComponent("index.json", isDirectory: false)
        let orphanURL = audioDirectory.appendingPathComponent(
            "\(identity.cacheKey).mp3",
            isDirectory: false
        )
        let unrelatedMP3URL = audioDirectory.appendingPathComponent("keep-me.mp3", isDirectory: false)
        try Data("{ this is not valid JSON".utf8).write(to: indexURL, options: .atomic)
        try Data([0x49, 0x44, 0x33, 0x01]).write(to: orphanURL, options: .atomic)
        try Data([0x49, 0x44, 0x33, 0x02]).write(to: unrelatedMP3URL, options: .atomic)

        let repository = GeneratedSpeechRepository(rootDirectory: root)
        try expectEqual(
            try await repository.allRecords().count,
            0,
            "Malformed JSON transactionally recovers the library to an empty index"
        )
        try expectEqual(
            try await repository.allRecords().count,
            0,
            "Malformed JSON leaves the recovered repository immediately reusable"
        )
        try expect(
            !fileManager.fileExists(atPath: orphanURL.path),
            "Malformed-index reconciliation removes a cache-key-shaped orphan MP3"
        )
        try expect(
            fileManager.fileExists(atPath: unrelatedMP3URL.path),
            "Malformed-index reconciliation preserves MP3s outside the cache-key namespace"
        )

        let directoryContents = try fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )
        let recoveryMetadata = directoryContents.filter {
            $0.lastPathComponent.hasPrefix("index.recovery-")
                || $0.lastPathComponent.hasPrefix("index.corrupt-")
        }
        try expectEqual(
            recoveryMetadata.count,
            0,
            "Successful malformed-index recovery leaves no recovery or corrupt metadata"
        )

        guard let replacementObject = try JSONSerialization.jsonObject(
            with: Data(contentsOf: indexURL)
        ) as? [String: Any] else {
            throw CheckFailure(message: "Malformed JSON did not publish a readable replacement index")
        }
        try expectEqual(
            (replacementObject["schemaVersion"] as? NSNumber)?.intValue,
            1,
            "Malformed JSON recovery publishes the supported schema version"
        )
        try expectEqual(
            (replacementObject["records"] as? [Any])?.count,
            0,
            "Malformed JSON replacement index starts with no fabricated records"
        )

        let audio = Data([0x49, 0x44, 0x33, 0x04, 0x55])
        let result = MiniMaxSynthesisResult(
            audioData: audio,
            durationMilliseconds: 900,
            reportedByteCount: audio.count,
            audioFormat: "mp3",
            traceID: "recovery-fixture"
        )
        let saved = try await repository.save(result: result, identity: identity)
        try expect(!saved.wasCached, "Malformed JSON recovery leaves the repository writable")
        try expect(
            fileManager.fileExists(atPath: saved.fileURL.path),
            "Malformed JSON recovery allows a subsequent persistent save"
        )
        let immediateCacheHit = try await repository.cachedSpeech(for: identity)
        try expect(
            immediateCacheHit?.wasCached == true,
            "Malformed JSON recovery allows an immediate cache lookup"
        )
        let reloadedRepository = GeneratedSpeechRepository(rootDirectory: root)
        let reloadedCacheHit = try await reloadedRepository.cachedSpeech(for: identity)
        try expect(
            reloadedCacheHit?.wasCached == true,
            "Malformed JSON recovered save remains cacheable after repository reload"
        )
    }

    private mutating func runFutureIndexPreservationChecks(
        identity: MiniMaxSpeechCacheIdentity
    ) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-future-index-\(UUID().uuidString)",
            isDirectory: true
        )
        let audioDirectory = root.appendingPathComponent("GeneratedAudio", isDirectory: true)
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let indexURL = audioDirectory.appendingPathComponent("index.json", isDirectory: false)
        let unsupportedIndex = try JSONSerialization.data(
            withJSONObject: [
                "schemaVersion": 99,
                "records": [],
                "futureMetadata": ["mustRemain": true],
            ],
            options: [.sortedKeys]
        )
        let cacheShapedMP3URL = audioDirectory.appendingPathComponent(
            "\(String(repeating: "a", count: 64)).mp3",
            isDirectory: false
        )
        let unrelatedMP3URL = audioDirectory.appendingPathComponent(
            "future-owned.mp3",
            isDirectory: false
        )
        let staleRecoveryURL = audioDirectory.appendingPathComponent(
            "index.recovery-stale.json",
            isDirectory: false
        )
        let staleCorruptURL = audioDirectory.appendingPathComponent(
            "index.corrupt-stale.json",
            isDirectory: false
        )
        let cacheShapedBytes = Data([0x49, 0x44, 0x33, 0x11])
        let unrelatedBytes = Data([0x49, 0x44, 0x33, 0x22])
        try unsupportedIndex.write(to: indexURL, options: .atomic)
        try cacheShapedBytes.write(to: cacheShapedMP3URL, options: .atomic)
        try unrelatedBytes.write(to: unrelatedMP3URL, options: .atomic)
        try Data("rollback".utf8).write(to: staleRecoveryURL, options: .atomic)
        try Data("diagnostic".utf8).write(to: staleCorruptURL, options: .atomic)

        let originalNames = Set(
            try fileManager.contentsOfDirectory(atPath: audioDirectory.path)
        )
        let repository = GeneratedSpeechRepository(rootDirectory: root)
        try await expectUnsupportedIndexError(
            from: repository,
            version: 99,
            "The first read rejects a valid future schema"
        )
        try await expectUnsupportedIndexError(
            from: repository,
            version: 99,
            "Repeated reads continue to reject the untouched future schema"
        )
        try expectEqual(
            try Data(contentsOf: indexURL),
            unsupportedIndex,
            "Future-schema reads preserve index bytes exactly"
        )
        try expectEqual(
            try Data(contentsOf: cacheShapedMP3URL),
            cacheShapedBytes,
            "Future-schema reads do not reconcile cache-shaped MP3s"
        )
        try expectEqual(
            try Data(contentsOf: unrelatedMP3URL),
            unrelatedBytes,
            "Future-schema reads do not modify other MP3s"
        )
        try expectEqual(
            Set(try fileManager.contentsOfDirectory(atPath: audioDirectory.path)),
            originalNames,
            "Future-schema reads do not add, remove, or rename dedicated artifacts"
        )

        // Clear All is the explicit destructive recovery path and must not try
        // to decode the unsupported index first.
        try await repository.clearAll()
        try expectEqual(
            Set(try fileManager.contentsOfDirectory(atPath: audioDirectory.path)),
            Set(["index.json"]),
            "Explicit Clear All preserves only the canonical index"
        )
        guard let replacementObject = try JSONSerialization.jsonObject(
            with: Data(contentsOf: indexURL)
        ) as? [String: Any] else {
            throw CheckFailure(message: "Clear All did not publish a readable replacement index")
        }
        try expectEqual(
            (replacementObject["schemaVersion"] as? NSNumber)?.intValue,
            1,
            "Clear All replaces a future schema with supported schema v1"
        )
        try expectEqual(
            (replacementObject["records"] as? [Any])?.count,
            0,
            "Clear All publishes an empty replacement index"
        )
        try expectEqual(
            try await repository.allRecords().count,
            0,
            "The explicitly reset future-schema repository is immediately readable"
        )

        let audio = Data([0x49, 0x44, 0x33, 0x44, 0x66])
        let result = MiniMaxSynthesisResult(
            audioData: audio,
            durationMilliseconds: 1_100,
            reportedByteCount: audio.count,
            audioFormat: "mp3",
            traceID: "future-schema-clear-fixture"
        )
        let saved = try await repository.save(result: result, identity: identity)
        try expect(!saved.wasCached, "Clear All leaves the future-schema repository writable")
        try expect(
            fileManager.fileExists(atPath: saved.fileURL.path),
            "Clear All permits a subsequent persistent save"
        )
        try expect(
            fileManager.fileExists(atPath: indexURL.path),
            "The first post-clear save recreates a supported persistent index"
        )
        let immediateCacheHit = try await repository.cachedSpeech(for: identity)
        try expect(
            immediateCacheHit?.wasCached == true,
            "Clear All permits an immediate cache lookup"
        )
        let reloadedRepository = GeneratedSpeechRepository(rootDirectory: root)
        let reloadedCacheHit = try await reloadedRepository.cachedSpeech(for: identity)
        try expect(
            reloadedCacheHit?.wasCached == true,
            "A save after future-schema Clear All remains cacheable after reload"
        )
    }

    private mutating func expectUnsupportedIndexError(
        from repository: GeneratedSpeechRepository,
        version expectedVersion: Int,
        _ message: String
    ) async throws {
        checksRun += 1
        do {
            _ = try await repository.allRecords()
        } catch let error as MiniMaxAudioError {
            guard case let .unsupportedSavedAudioIndex(actualVersion) = error,
                  actualVersion == expectedVersion else {
                throw CheckFailure(message: "\(message): received \(error.localizedDescription)")
            }
            return
        } catch {
            throw CheckFailure(message: "\(message): received unexpected error \(error)")
        }
        throw CheckFailure(message: "\(message): unsupported schema was accepted")
    }

    mutating func runPipelineCoalescingChecks(identity: MiniMaxSpeechCacheIdentity) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-pipeline-contracts-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let session = stubbedSession()
        defer { session.invalidateAndCancel() }
        let responseBody = try t2aResponse()
        MiniMaxURLProtocolStub.install { _ in
            .respond(
                statusCode: 200,
                body: responseBody,
                delayNanoseconds: 150_000_000
            )
        }

        let repository = GeneratedSpeechRepository(rootDirectory: root)
        let client = MiniMaxAudioClient(session: session)
        let pipeline = MiniMaxSpeechPipeline(client: client, repository: repository)
        let results = try await withThrowingTaskGroup(
            of: CachedGeneratedSpeech.self,
            returning: [CachedGeneratedSpeech].self
        ) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await pipeline.speech(
                        for: identity,
                        apiKey: "offline-contract-token"
                    )
                }
            }
            var values: [CachedGeneratedSpeech] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }

        try expectEqual(results.count, 8, "Every concurrent waiter receives generated speech")
        try expect(
            results.allSatisfy { $0.record.id == identity.cacheKey },
            "Concurrent waiters share the same cache identity"
        )
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            1,
            "Concurrent identical requests coalesce into one paid HTTP call"
        )
        try expectEqual(
            try await repository.allRecords().count,
            1,
            "Coalesced generation persists exactly one record"
        )

        let laterCacheHit = try await pipeline.speech(
            for: identity,
            apiKey: "offline-contract-token"
        )
        try expect(laterCacheHit.wasCached, "A later pipeline request is served from disk cache")
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            1,
            "A persisted cache hit makes no additional HTTP call"
        )
    }

    mutating func runPipelineClearRaceChecks(identity: MiniMaxSpeechCacheIdentity) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-pipeline-clear-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let session = stubbedSession()
        defer { session.invalidateAndCancel() }
        let responseBody = try t2aResponse()
        MiniMaxURLProtocolStub.install { _ in
            .respond(
                statusCode: 200,
                body: responseBody,
                delayNanoseconds: 250_000_000
            )
        }

        let repository = GeneratedSpeechRepository(rootDirectory: root)
        let client = MiniMaxAudioClient(session: session)
        let pipeline = MiniMaxSpeechPipeline(client: client, repository: repository)
        let generation = Task {
            try await pipeline.speech(
                for: identity,
                apiKey: "offline-contract-token"
            )
        }

        for _ in 0..<100 where MiniMaxURLProtocolStub.requests().isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            1,
            "Clear-race fixture starts one in-flight generation"
        )

        try await pipeline.clearAllGeneratedSpeech()
        let clearedGenerationResult = await generation.result
        checksRun += 1
        if case .success = clearedGenerationResult {
            throw CheckFailure(message: "A waiter returned a record deleted by Clear All")
        }
        try await Task.sleep(for: .milliseconds(300))

        try expectEqual(
            try await repository.allRecords().count,
            0,
            "Clear All drains generation before publishing an empty repository"
        )
        let audioDirectory = root.appendingPathComponent("GeneratedAudio", isDirectory: true)
        try expectEqual(
            Set(try fileManager.contentsOfDirectory(atPath: audioDirectory.path)),
            Set(["index.json"]),
            "A drained generation cannot recreate audio after Clear All returns"
        )

        MiniMaxURLProtocolStub.install { _ in
            .respond(statusCode: 200, body: responseBody)
        }
        let postClear = try await pipeline.speech(
            for: identity,
            apiKey: "offline-contract-token"
        )
        try expect(
            !postClear.wasCached,
            "The pipeline accepts a fresh generation after coordinated clear completes"
        )
        try expectEqual(
            try await repository.allRecords().count,
            1,
            "A post-clear generation persists normally"
        )
    }

    mutating func runPipelineCancelThenRepeatChecks(
        identity: MiniMaxSpeechCacheIdentity
    ) async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "swiftmandarin-minimax-pipeline-repeat-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let session = stubbedSession()
        defer { session.invalidateAndCancel() }
        let responseBody = try t2aResponse()
        MiniMaxURLProtocolStub.install { _ in
            .respond(
                statusCode: 200,
                body: responseBody,
                delayNanoseconds: 200_000_000
            )
        }

        let repository = GeneratedSpeechRepository(rootDirectory: root)
        let client = MiniMaxAudioClient(session: session)
        let pipeline = MiniMaxSpeechPipeline(client: client, repository: repository)

        let alreadyCancelled = Task {
            do {
                try await Task.sleep(for: .milliseconds(20))
            } catch {
                // Deliberately continue with cancellation already set so the
                // pipeline boundary itself must reject paid work.
            }
            return try await pipeline.speech(
                for: identity,
                apiKey: "offline-contract-token"
            )
        }
        alreadyCancelled.cancel()
        checksRun += 1
        do {
            _ = try await alreadyCancelled.value
            throw CheckFailure(message: "An already-cancelled caller started speech")
        } catch is CancellationError {
            // Expected.
        }
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            0,
            "An already-cancelled caller creates no paid HTTP request"
        )

        let first = Task {
            try await pipeline.speech(
                for: identity,
                apiKey: "offline-contract-token"
            )
        }
        for _ in 0..<100 where MiniMaxURLProtocolStub.requests().isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            1,
            "Repeat fixture starts the first generation"
        )

        let retiredWithoutRemainingJoinableEntry = await pipeline
            .cancelActiveGenerationForChecks(cacheKey: identity.cacheKey)
        try expect(
            retiredWithoutRemainingJoinableEntry,
            "A cancelled last waiter retires its task outside the joinable map"
        )

        let repeated = try await pipeline.speech(
            for: identity,
            apiKey: "offline-contract-token"
        )
        _ = await first.result
        try expect(
            !repeated.wasCached,
            "An immediate same-text repeat starts fresh instead of inheriting cancellation"
        )
        try expectEqual(
            MiniMaxURLProtocolStub.requests().count,
            2,
            "Cancel then repeat produces one fresh paid request"
        )
        try expectEqual(
            try await repository.allRecords().count,
            1,
            "The fresh repeated generation persists exactly once"
        )
    }
}

@main
private struct MiniMaxAudioContractChecksRunner {
    static func main() async {
        var checks = ContractChecks()
        do {
            try checks.runHexChecks()
            let identity = try checks.runCacheIdentityChecks()
            try checks.runCatalogModelChecks()
            try await checks.runClientChecks(identity: identity)
            try await checks.runVoiceCatalogChecks()
            try await checks.runCatalogStoreChecks()
            try checks.runBatchAudioPlannerChecks()
            try await checks.runBatchAudioOrchestrationChecks()
            try await checks.runRepositoryChecks(identity: identity)
            try await checks.runCorruptIndexRecoveryChecks(identity: identity)
            try await checks.runPipelineCoalescingChecks(identity: identity)
            try await checks.runPipelineCancelThenRepeatChecks(identity: identity)
            try await checks.runPipelineClearRaceChecks(identity: identity)
            print("MiniMax audio contract checks passed (\(checks.checksRun)/\(checks.checksRun))")
        } catch let failure as CheckFailure {
            fputs("MiniMax audio contract check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("MiniMax audio contract checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
