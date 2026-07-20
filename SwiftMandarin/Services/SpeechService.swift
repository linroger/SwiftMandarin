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
    private static var activeRequestID: UUID?
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
        activeRequestID = requestID
        AIAudioRuntimeState.shared.update(
            phase: .cacheHit,
            message: String(localized: "Preparing saved AI audio…"),
            currentRecordID: recordID,
            usedCache: true
        )

        do {
            let fileURL = try await GeneratedSpeechStore.shared.fileURL(for: recordID)
            try Task.checkCancellation()
            guard activeRequestID == requestID else { throw CancellationError() }
            do {
                try playGeneratedFile(fileURL)
            } catch {
                // A cache entry that cannot be decoded must not poison every
                // future replay. Eviction lets the next Speak regenerate it.
                try? await GeneratedSpeechStore.shared.delete(recordID: recordID)
                throw error
            }
            AIAudioRuntimeState.shared.update(
                phase: .cacheHit,
                message: String(localized: "Playing saved AI audio"),
                currentRecordID: recordID,
                usedCache: true
            )
        } catch {
            if activeRequestID == requestID {
                activeRequestID = nil
                let message = error.localizedDescription
                AIAudioRuntimeState.shared.update(phase: .failed, message: message)
                AIAudioRuntimeState.shared.publishNotice(message, isError: true)
            }
            throw error
        }
    }

    static func stop() {
        if let requestID = activeRequestID {
            completeTrackedRequest(requestID, outcome: .cancelled)
            activeRequestID = nil
        }
        generationTask?.cancel()
        generationTask = nil

        generatedAudioPlayer?.stop()
        generatedAudioPlayer = nil
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)

        AIAudioRuntimeState.shared.update(phase: .idle)
        deactivateAudioSessionIfIdle()
    }

    static var isSpeaking: Bool {
        generationTask != nil || generatedAudioPlayer?.isPlaying == true || synthesizer.isSpeaking
    }

    // MARK: - Routing

    private static func routeSpeech(
        _ text: String,
        languageCode: String?,
        localRate: Float,
        aiSpeedScale: Double,
        trackCompletion: Bool
    ) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()
        stop()
        AIAudioRuntimeState.shared.clearNotice()
        let requestID = UUID()
        activeRequestID = requestID
        if trackCompletion {
            trackedRequestIDs.insert(requestID)
        }
        let resolvedLanguage = languageCode ?? (trimmed.containsCJK ? "zh-CN" : "en-US")
        let preferences = AppPreferences.shared
        guard preferences.aiAudioEnabled else {
            speakLocally(trimmed, languageCode: resolvedLanguage, rate: localRate)
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
            message: String(localized: "Generating AI audio…")
        )

        let fallback = preferences.aiAudioFallbackToSystemSpeech
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
                    try playGeneratedFile(generated.fileURL)
                } catch {
                    try? await GeneratedSpeechStore.shared.delete(recordID: generated.record.id)
                    throw error
                }
                generationTask = nil
                AIAudioRuntimeState.shared.update(
                    phase: generated.wasCached ? .cacheHit : .playing,
                    message: generated.wasCached
                        ? String(localized: "Playing saved AI audio")
                        : String(localized: "Playing AI audio"),
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
        generationTask = nil
        AIAudioRuntimeState.shared.update(phase: .idle)
        deactivateAudioSessionIfIdle()
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
            let notice = message + " " + String(localized: "Using the system voice.")
            AIAudioRuntimeState.shared.update(
                phase: .localFallback,
                message: notice
            )
            AIAudioRuntimeState.shared.publishNotice(notice, isError: false)
            speakLocally(text, languageCode: languageCode, rate: localRate)
        } else {
            completeTrackedRequest(requestID, outcome: .failed(message))
            activeRequestID = nil
            AIAudioRuntimeState.shared.update(phase: .failed, message: message)
            AIAudioRuntimeState.shared.publishNotice(message, isError: true)
            deactivateAudioSessionIfIdle()
        }
    }

    // MARK: - Generated Audio Playback

    private static func playGeneratedFile(_ url: URL) throws {
        _ = generatedAudioDelegate
        configureAudioSessionForPlayback()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = generatedAudioDelegate
            guard player.prepareToPlay(), player.play() else {
                throw MiniMaxAudioError.playback(
                    String(localized: "The audio player could not start.")
                )
            }
            generatedAudioPlayer = player
        } catch let error as MiniMaxAudioError {
            generatedAudioPlayer = nil
            deactivateAudioSessionIfIdle()
            throw error
        } catch {
            generatedAudioPlayer = nil
            deactivateAudioSessionIfIdle()
            throw MiniMaxAudioError.playback(error.localizedDescription)
        }
    }

    fileprivate static func generatedAudioDidFinish(
        player: AVAudioPlayer,
        successfully: Bool
    ) {
        guard player === generatedAudioPlayer else { return }
        let recordID = AIAudioRuntimeState.shared.currentRecordID
        let requestID = activeRequestID
        generatedAudioPlayer = nil
        activeRequestID = nil
        if successfully {
            if let requestID {
                completeTrackedRequest(requestID, outcome: .success)
            }
            AIAudioRuntimeState.shared.update(phase: .idle)
        } else {
            let message = String(localized: "The generated audio stopped before it finished.")
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
        deactivateAudioSessionIfIdle()
    }

    // MARK: - System Speech

    private static func speakLocally(_ text: String, languageCode: String, rate: Float) {
        _ = sessionReleaser
        configureAudioSessionForPlayback()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice(forLanguage: languageCode)
        utterance.rate = rate
        activeUtterance = utterance
        synthesizer.speak(utterance)
    }

    fileprivate static func systemSpeechDidFinish(
        utterance: AVSpeechUtterance,
        cancelled: Bool
    ) {
        guard utterance === activeUtterance else {
            deactivateAudioSessionIfIdle()
            return
        }
        activeUtterance = nil
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
        deactivateAudioSessionIfIdle()
    }

    /// Reconciles playback state when iOS interrupts the shared audio session.
    /// Generation that has not started playback is left alone; an active
    /// player or synthesizer is stopped and any awaiting App Intent receives
    /// the interruption for its own request rather than another utterance's
    /// eventual result.
    static func handleAudioSessionLoss(message: String) {
        guard generatedAudioPlayer != nil || activeUtterance != nil else { return }

        let requestID = activeRequestID
        activeRequestID = nil
        generatedAudioPlayer?.stop()
        generatedAudioPlayer = nil
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        if let requestID {
            completeTrackedRequest(requestID, outcome: .failed(message))
        }
        AIAudioRuntimeState.shared.update(phase: .failed, message: message)
        AIAudioRuntimeState.shared.publishNotice(message, isError: true)
        deactivateAudioSessionIfIdle()
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

    // MARK: - Audio Session (iOS)

    private static func configureAudioSessionForPlayback() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            log.error("Audio session configuration failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    fileprivate static func deactivateAudioSessionIfIdle() {
        #if os(iOS)
        guard !synthesizer.isSpeaking, generatedAudioPlayer?.isPlaying != true,
              generationTask == nil,
              !SourceAudioActivityCoordinator.shared.hasActiveSourceAudio else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Audio session deactivation failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
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

private final class SpeechSessionReleaser: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            SpeechService.systemSpeechDidFinish(utterance: utterance, cancelled: false)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            SpeechService.systemSpeechDidFinish(utterance: utterance, cancelled: true)
        }
    }
}

private final class GeneratedAudioPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        MainActor.assumeIsolated {
            SpeechService.generatedAudioDidFinish(player: player, successfully: flag)
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        MainActor.assumeIsolated {
            SpeechService.generatedAudioDidFinish(player: player, successfully: false)
        }
    }
}
