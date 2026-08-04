//
//  SpeechService.swift
//  SwiftMandarin
//
//  Central speech router for local system voices and persistent MiniMax audio.
//

import AVFoundation
import os.log

@MainActor
enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()
    private static let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "Speech")

    /// Retained delegates release the iOS ducking session when either speech
    /// engine finishes. Both are installed lazily by their respective paths.
    private static let sessionReleaser: SpeechSessionReleaser = {
        let releaser = SpeechSessionReleaser()
        synthesizer.delegate = releaser
        return releaser
    }()
    private static let generatedAudioDelegate = GeneratedAudioPlaybackDelegate()

    /// Multiplier applied to the selected speed for a learner slow replay.
    static let slowRateFactor: Float = 0.6

    private static var voiceCache: [String: AVSpeechSynthesisVoice] = [:]
    private static var generatedAudioPlayer: AVAudioPlayer?
    private static var activeUtterance: AVSpeechUtterance?
    private static var generationTask: Task<Void, Never>?
    private static var playbackStartTask: Task<Void, Never>?
    private static var activeRequestID: UUID?
    private static var activeAudioSessionOwner: AudioSessionOwner?
    private static var trackedRequestIDs: Set<UUID> = []
    private static var completedRequestOutcomes: [UUID: SpeechRequestOutcome] = [:]

    static func speak(_ text: String, languageCode: String? = nil) {
        _ = routeSpeech(
            text,
            languageCode: languageCode,
            localRate: Float(AppPreferences.shared.ttsRate),
            aiSpeedScale: 1,
            trackCompletion: false
        )
    }

    static func speakSlow(_ text: String, languageCode: String? = nil) {
        _ = routeSpeech(
            text,
            languageCode: languageCode,
            localRate: Float(AppPreferences.shared.ttsRate) * slowRateFactor,
            aiSpeedScale: Double(slowRateFactor),
            trackCompletion: false
        )
    }

    static func speakChinese(_ text: String) {
        speak(text, languageCode: "zh-CN")
    }

    static func speakEnglish(_ text: String) {
        speak(text, languageCode: "en-US")
    }

    static func speakAuto(_ text: String) {
        speak(text, languageCode: text.containsCJK ? "zh-CN" : "en-US")
    }

    static func speakAutoSlow(_ text: String) {
        speakSlow(text, languageCode: text.containsCJK ? "zh-CN" : "en-US")
    }

    /// Async convenience for App Intents and other workflows that must not
    /// return until generation and playback have completed.
    static func speakAndWait(_ text: String, languageCode: String? = nil) async throws {
        guard let requestID = routeSpeech(
            text,
            languageCode: languageCode,
            localRate: Float(AppPreferences.shared.ttsRate),
            aiSpeedScale: 1,
            trackCompletion: true
        ) else { return }

        try await waitForCompletion(of: requestID)
    }

    /// Exercises the configured MiniMax path itself, with no system-speech
    /// fallback. Settings previews use this contract so a failed API request,
    /// wrong region, or invalid voice cannot be mistaken for a successful
    /// MiniMax voice preview.
    static func previewMiniMaxAndWait(
        _ text: String,
        languageCode: String
    ) async throws {
        guard let requestID = routeSpeech(
            text,
            languageCode: languageCode,
            localRate: Float(AppPreferences.shared.ttsRate),
            aiSpeedScale: 1,
            trackCompletion: true,
            requireMiniMax: true
        ) else { return }

        try await waitForCompletion(of: requestID)
    }

    private static func waitForCompletion(of requestID: UUID) async throws {
        do {
            while true {
                if let outcome = completedRequestOutcomes.removeValue(forKey: requestID) {
                    trackedRequestIDs.remove(requestID)
                    switch outcome {
                    case .success:
                        return
                    case .failed(let message):
                        throw AIAudioSpeechFailure(message: message)
                    case .cancelled:
                        throw CancellationError()
                    }
                }
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(50))
            }
        } catch {
            if activeRequestID == requestID {
                stop()
            }
            trackedRequestIDs.remove(requestID)
            completedRequestOutcomes.removeValue(forKey: requestID)
            throw error
        }
    }

    /// Plays an existing library item without contacting MiniMax.
    static func playGeneratedAudio(_ record: GeneratedSpeechRecord) async throws {
        try await playGeneratedAudio(recordID: record.id)
    }

    /// Plays an existing library item without contacting MiniMax.
    static func playGeneratedAudio(recordID: String) async throws {
        SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()
        stop()
        let requestID = UUID()
        let sessionOwner = AudioSessionOwner()
        activeRequestID = requestID
        activeAudioSessionOwner = sessionOwner
        AIAudioRuntimeState.shared.update(
            phase: .cacheHit,
            message: String(localized: "Preparing saved AI audio…", bundle: .appLanguage),
            currentRecordID: recordID,
            usedCache: true
        )

        do {
            let fileURL = try await GeneratedSpeechStore.shared.fileURL(for: recordID)
            try Task.checkCancellation()
            guard activeRequestID == requestID else { throw CancellationError() }
            do {
                try await playGeneratedFile(
                    fileURL,
                    requestID: requestID,
                    sessionOwner: sessionOwner
                )
            } catch let error as GeneratedAudioFileUnreadable {
                // A cache entry that cannot be decoded must not poison every
                // future replay. Eviction lets the next Speak regenerate it.
                try? await GeneratedSpeechStore.shared.delete(recordID: recordID)
                throw error
            }
            AIAudioRuntimeState.shared.update(
                phase: .cacheHit,
                message: String(localized: "Playing saved AI audio", bundle: .appLanguage),
                currentRecordID: recordID,
                usedCache: true
            )
        } catch {
            if activeRequestID == requestID {
                activeRequestID = nil
                activeAudioSessionOwner = nil
                AudioSessionCoordinator.shared.release(sessionOwner)
                let message = error.localizedDescription
                AIAudioRuntimeState.shared.update(phase: .failed, message: message)
                AIAudioRuntimeState.shared.publishNotice(message, isError: true)
            }
            throw error
        }
    }

    static func stop() {
        let sessionOwner = activeAudioSessionOwner
        activeAudioSessionOwner = nil
        if let requestID = activeRequestID {
            completeTrackedRequest(requestID, outcome: .cancelled)
            activeRequestID = nil
        }
        generationTask?.cancel()
        generationTask = nil
        playbackStartTask?.cancel()
        playbackStartTask = nil

        generatedAudioPlayer?.stop()
        generatedAudioPlayer = nil
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)

        AIAudioRuntimeState.shared.update(phase: .idle)
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
    }

    static var isSpeaking: Bool {
        generationTask != nil || playbackStartTask != nil
            || generatedAudioPlayer?.isPlaying == true || synthesizer.isSpeaking
    }

    // MARK: - Routing

    private static func routeSpeech(
        _ text: String,
        languageCode: String?,
        localRate: Float,
        aiSpeedScale: Double,
        trackCompletion: Bool,
        requireMiniMax: Bool = false
    ) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()
        stop()
        AIAudioRuntimeState.shared.clearNotice()
        let requestID = UUID()
        let sessionOwner = AudioSessionOwner()
        activeRequestID = requestID
        activeAudioSessionOwner = sessionOwner
        if trackCompletion {
            trackedRequestIDs.insert(requestID)
        }
        let resolvedLanguage = languageCode ?? (trimmed.containsCJK ? "zh-CN" : "en-US")
        let preferences = AppPreferences.shared
        guard preferences.aiAudioEnabled || requireMiniMax else {
            speakLocally(
                trimmed,
                languageCode: resolvedLanguage,
                rate: localRate,
                requestID: requestID,
                sessionOwner: sessionOwner
            )
            return requestID
        }

        let apiKey = AIModelSettings.shared.apiKey(for: .minimax)
        let configuration = preferences.miniMaxSpeechConfiguration(
            languageCode: resolvedLanguage,
            speedScale: aiSpeedScale
        )
        let identity = MiniMaxSpeechCacheIdentity(
            text: trimmed,
            languageCode: resolvedLanguage,
            configuration: configuration
        )
        AIAudioRuntimeState.shared.update(
            phase: .generating,
            message: String(localized: "Generating AI audio…", bundle: .appLanguage)
        )

        let fallback = requireMiniMax ? false : preferences.aiAudioFallbackToSystemSpeech
        generationTask = Task { @MainActor in
            do {
                let generated = try await MiniMaxSpeechPipeline.shared.speech(
                    for: identity,
                    apiKey: apiKey
                )
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }

                GeneratedSpeechStore.shared.note(generated.record)
                do {
                    try await playGeneratedFile(
                        generated.fileURL,
                        requestID: requestID,
                        sessionOwner: sessionOwner
                    )
                } catch let error as GeneratedAudioFileUnreadable {
                    try? await GeneratedSpeechStore.shared.delete(recordID: generated.record.id)
                    throw error
                }
                generationTask = nil
                AIAudioRuntimeState.shared.update(
                    phase: generated.wasCached ? .cacheHit : .playing,
                    message: generated.wasCached
                        ? String(localized: "Playing saved AI audio", bundle: .appLanguage)
                        : String(localized: "Playing AI audio", bundle: .appLanguage),
                    currentRecordID: generated.record.id,
                    usedCache: generated.wasCached
                )
            } catch is CancellationError {
                finishCancelledRequest(requestID)
            } catch MiniMaxAudioError.cancelled {
                finishCancelledRequest(requestID)
            } catch {
                guard activeRequestID == requestID else { return }
                generationTask = nil
                handleAIFailure(
                    error,
                    requestID: requestID,
                    text: trimmed,
                    languageCode: resolvedLanguage,
                    localRate: localRate,
                    shouldFallback: fallback
                )
            }
        }
        return requestID
    }

    private static func finishCancelledRequest(_ requestID: UUID) {
        guard activeRequestID == requestID else { return }
        completeTrackedRequest(requestID, outcome: .cancelled)
        activeRequestID = nil
        let sessionOwner = activeAudioSessionOwner
        activeAudioSessionOwner = nil
        generationTask = nil
        AIAudioRuntimeState.shared.update(phase: .idle)
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
    }

    private static func handleAIFailure(
        _ error: Error,
        requestID: UUID,
        text: String,
        languageCode: String,
        localRate: Float,
        shouldFallback: Bool
    ) {
        guard activeRequestID == requestID else { return }
        generationTask = nil
        let message = error.localizedDescription
        if shouldFallback {
            let notice = message + " " + String(localized: "Using the system voice.", bundle: .appLanguage)
            AIAudioRuntimeState.shared.update(
                phase: .localFallback,
                message: notice
            )
            AIAudioRuntimeState.shared.publishNotice(notice, isError: false)
            guard let sessionOwner = activeAudioSessionOwner else { return }
            speakLocally(
                text,
                languageCode: languageCode,
                rate: localRate,
                requestID: requestID,
                sessionOwner: sessionOwner
            )
        } else {
            completeTrackedRequest(requestID, outcome: .failed(message))
            activeRequestID = nil
            let sessionOwner = activeAudioSessionOwner
            activeAudioSessionOwner = nil
            AIAudioRuntimeState.shared.update(phase: .failed, message: message)
            AIAudioRuntimeState.shared.publishNotice(message, isError: true)
            if let sessionOwner {
                AudioSessionCoordinator.shared.release(sessionOwner)
            }
        }
    }

    // MARK: - Generated Audio Playback

    private static func playGeneratedFile(
        _ url: URL,
        requestID: UUID,
        sessionOwner: AudioSessionOwner
    ) async throws {
        _ = generatedAudioDelegate
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player.delegate = generatedAudioDelegate
            guard player.prepareToPlay() else {
                throw GeneratedAudioFileUnreadable(
                    message: String(localized: "The audio player could not start.", bundle: .appLanguage)
                )
            }
        } catch let error as GeneratedAudioFileUnreadable {
            throw error
        } catch {
            throw GeneratedAudioFileUnreadable(message: error.localizedDescription)
        }

        do {
            await SpeechRecognitionService.shared.stopRecording()
            try Task.checkCancellation()
            guard activeRequestID == requestID,
                  activeAudioSessionOwner == sessionOwner else {
                AudioSessionCoordinator.shared.release(sessionOwner)
                throw CancellationError()
            }
            SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()

            try await AudioSessionCoordinator.shared.acquire(
                .spokenPlayback,
                owner: sessionOwner
            )
            try Task.checkCancellation()
            guard activeRequestID == requestID,
                  activeAudioSessionOwner == sessionOwner else {
                AudioSessionCoordinator.shared.release(sessionOwner)
                throw CancellationError()
            }

            generatedAudioPlayer = player
            guard player.play() else {
                generatedAudioPlayer = nil
                throw MiniMaxAudioError.playback(
                    String(localized: "The audio player could not start.", bundle: .appLanguage)
                )
            }
        } catch let error as MiniMaxAudioError {
            if generatedAudioPlayer === player {
                generatedAudioPlayer = nil
            }
            AudioSessionCoordinator.shared.release(sessionOwner)
            throw error
        } catch is CancellationError {
            if generatedAudioPlayer === player {
                generatedAudioPlayer = nil
            }
            AudioSessionCoordinator.shared.release(sessionOwner)
            throw CancellationError()
        } catch {
            if generatedAudioPlayer === player {
                generatedAudioPlayer = nil
            }
            AudioSessionCoordinator.shared.release(sessionOwner)
            throw MiniMaxAudioError.playback(error.localizedDescription)
        }
    }

    fileprivate static func generatedAudioDidFinish(
        playerID: ObjectIdentifier,
        successfully: Bool
    ) {
        guard let currentPlayer = generatedAudioPlayer,
              ObjectIdentifier(currentPlayer) == playerID else { return }
        let recordID = AIAudioRuntimeState.shared.currentRecordID
        let requestID = activeRequestID
        let sessionOwner = activeAudioSessionOwner
        generatedAudioPlayer = nil
        activeRequestID = nil
        activeAudioSessionOwner = nil
        if successfully {
            if let requestID {
                completeTrackedRequest(requestID, outcome: .success)
            }
            AIAudioRuntimeState.shared.update(phase: .idle)
        } else {
            let message = String(localized: "The generated audio stopped before it finished.", bundle: .appLanguage)
            if let requestID {
                completeTrackedRequest(requestID, outcome: .failed(message))
            }
            AIAudioRuntimeState.shared.update(
                phase: .failed,
                message: message
            )
            AIAudioRuntimeState.shared.publishNotice(message, isError: true)
            if let recordID {
                Task { try? await GeneratedSpeechStore.shared.delete(recordID: recordID) }
            }
        }
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
    }

    // MARK: - System Speech

    private static func speakLocally(
        _ text: String,
        languageCode: String,
        rate: Float,
        requestID: UUID,
        sessionOwner: AudioSessionOwner
    ) {
        _ = sessionReleaser
        playbackStartTask?.cancel()
        playbackStartTask = Task { @MainActor in
            do {
                await SpeechRecognitionService.shared.stopRecording()
                try Task.checkCancellation()
                guard activeRequestID == requestID,
                      activeAudioSessionOwner == sessionOwner else {
                    AudioSessionCoordinator.shared.release(sessionOwner)
                    return
                }
                SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()

                try await AudioSessionCoordinator.shared.acquire(
                    .spokenPlayback,
                    owner: sessionOwner
                )
                try Task.checkCancellation()
                guard activeRequestID == requestID,
                      activeAudioSessionOwner == sessionOwner else {
                    AudioSessionCoordinator.shared.release(sessionOwner)
                    return
                }

                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = bestVoice(forLanguage: languageCode)
                utterance.rate = rate
                activeUtterance = utterance
                playbackStartTask = nil
                synthesizer.speak(utterance)
            } catch is CancellationError {
                AudioSessionCoordinator.shared.release(sessionOwner)
            } catch {
                AudioSessionCoordinator.shared.release(sessionOwner)
                guard activeRequestID == requestID,
                      activeAudioSessionOwner == sessionOwner else { return }

                playbackStartTask = nil
                completeTrackedRequest(
                    requestID,
                    outcome: .failed(error.localizedDescription)
                )
                activeRequestID = nil
                activeAudioSessionOwner = nil
                log.error(
                    "Audio session activation failed: \(error.localizedDescription, privacy: .public)"
                )
                AIAudioRuntimeState.shared.update(
                    phase: .failed,
                    message: error.localizedDescription
                )
                AIAudioRuntimeState.shared.publishNotice(
                    error.localizedDescription,
                    isError: true
                )
            }
        }
    }

    fileprivate static func systemSpeechDidFinish(
        utteranceID: ObjectIdentifier,
        cancelled: Bool
    ) {
        guard let currentUtterance = activeUtterance,
              ObjectIdentifier(currentUtterance) == utteranceID else { return }
        let sessionOwner = activeAudioSessionOwner
        activeUtterance = nil
        activeAudioSessionOwner = nil
        if let requestID = activeRequestID {
            completeTrackedRequest(
                requestID,
                outcome: cancelled ? .cancelled : .success
            )
            activeRequestID = nil
        }
        if AIAudioRuntimeState.shared.phase == .localFallback {
            AIAudioRuntimeState.shared.update(phase: .idle)
        }
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
    }

    /// Reconciles playback state when iOS interrupts the shared audio session.
    /// Generation that has not started playback is left alone; an active
    /// player or synthesizer is stopped and any awaiting App Intent receives
    /// the interruption for its own request rather than another utterance's
    /// eventual result.
    static func handleAudioSessionLoss(message: String) {
        guard generatedAudioPlayer != nil || activeUtterance != nil else { return }

        let requestID = activeRequestID
        let sessionOwner = activeAudioSessionOwner
        activeRequestID = nil
        activeAudioSessionOwner = nil
        generatedAudioPlayer?.stop()
        generatedAudioPlayer = nil
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        if let requestID {
            completeTrackedRequest(requestID, outcome: .failed(message))
        }
        AIAudioRuntimeState.shared.update(phase: .failed, message: message)
        AIAudioRuntimeState.shared.publishNotice(message, isError: true)
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
    }

    private static func completeTrackedRequest(
        _ requestID: UUID,
        outcome: SpeechRequestOutcome
    ) {
        guard trackedRequestIDs.contains(requestID) else { return }
        completedRequestOutcomes[requestID] = outcome
    }

    // MARK: - Voice Selection

    private static func bestVoice(forLanguage code: String) -> AVSpeechSynthesisVoice? {
        if let cached = voiceCache[code] { return cached }

        let matches = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == code }
        let picked: AVSpeechSynthesisVoice?
        if let premium = matches.first(where: { $0.quality == .premium }) {
            picked = premium
        } else if let enhanced = matches.first(where: { $0.quality == .enhanced }) {
            picked = enhanced
        } else {
            picked = AVSpeechSynthesisVoice(language: code)
        }

        if let picked { voiceCache[code] = picked }
        return picked
    }

}

nonisolated private enum SpeechRequestOutcome: Sendable {
    case success
    case failed(String)
    case cancelled
}

nonisolated private struct AIAudioSpeechFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

nonisolated private struct GeneratedAudioFileUnreadable: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private final class SpeechSessionReleaser: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            SpeechService.systemSpeechDidFinish(utteranceID: utteranceID, cancelled: false)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let utteranceID = ObjectIdentifier(utterance)
        Task { @MainActor in
            SpeechService.systemSpeechDidFinish(utteranceID: utteranceID, cancelled: true)
        }
    }
}

private final class GeneratedAudioPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let playerID = ObjectIdentifier(player)
        Task { @MainActor in
            SpeechService.generatedAudioDidFinish(playerID: playerID, successfully: flag)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let playerID = ObjectIdentifier(player)
        Task { @MainActor in
            SpeechService.generatedAudioDidFinish(playerID: playerID, successfully: false)
        }
    }
}
