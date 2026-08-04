//
//  AudioTranscriptionService.swift
//  SwiftMandarin
//
//  One-shot transcription for recorded or imported audio files. This uses the
//  Apple Speech URL recognizer and prefers on-device recognition whenever the
//  selected locale supports it.
//

import Foundation
@preconcurrency import Speech

/// Which engine turns a recorded or imported clip into text.
///
/// Apple Speech is the default: free, no key, and on-device whenever the
/// locale's dictation model is installed. The AI provider is the answer when
/// that model is missing or the recording defeats it — at the cost of sending
/// the audio to the configured provider, which is why it is an explicit choice.
nonisolated enum AudioTranscriptionEngine: String, CaseIterable, Identifiable, Sendable {
    case appleSpeech
    case aiProvider

    var id: String { rawValue }
}

nonisolated enum AudioTranscriptionError: LocalizedError {
    case notAuthorized
    case restricted
    case recognizerUnavailable(language: String)
    case emptyTranscript
    case recognitionFailed(String)
    case timedOut
    case noTranscriptionProvider

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            #if os(iOS)
            return String(localized: "Speech recognition access is required to transcribe audio. Enable it in Settings and try again.", bundle: .appLanguage)
            #else
            return String(localized: "Speech recognition access is required to transcribe audio. Enable it in System Settings and try again.", bundle: .appLanguage)
            #endif
        case .restricted:
            return String(localized: "Speech recognition is restricted on this device.", bundle: .appLanguage)
        case .recognizerUnavailable(let language):
            return String.localizedStringWithFormat(
                String(localized: "Apple Speech has no recognizer available for %@. Turn on Dictation in Settings (which downloads the language), check your network connection, or switch to an AI transcription provider.", bundle: .appLanguage),
                language
            )
        case .emptyTranscript:
            return String(localized: "Apple Speech could not find spoken words in this audio. Check the recognition language and audio quality, then try again.", bundle: .appLanguage)
        case .recognitionFailed(let message):
            return String(localized: "Audio transcription failed:", bundle: .appLanguage) + " " + message
        case .timedOut:
            return String(localized: "Apple Speech stopped responding before it finished this audio. Try a shorter clip, or switch to an AI transcription provider.", bundle: .appLanguage)
        case .noTranscriptionProvider:
            return String(localized: "AI transcription needs a provider with a speech-to-text endpoint (OpenAI, Qwen, or Quotio). Add an API key in Settings → AI, or switch back to Apple Speech.", bundle: .appLanguage)
        }
    }
}

extension SpeechRecognitionLanguage {
    /// ISO-639-1 hint for a speech-to-text API. Both Chinese variants map to
    /// `zh`; script selection is the model's job, not a language hint's.
    var transcriptionLanguageCode: String {
        switch self {
        case .english: return "en"
        case .chinese, .chineseTraditional: return "zh"
        }
    }
}

/// A lock-protected, exactly-once bridge for the callback-based Speech API.
/// It also remembers cancellation that arrives before a continuation is
/// installed, which avoids leaving a cancelled task suspended indefinitely.
nonisolated private final class AudioRecognitionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var completion: Result<String, Error>?

    func install(_ continuation: CheckedContinuation<String, Error>) {
        let pending: Result<String, Error>?
        lock.lock()
        if let completion {
            pending = completion
        } else {
            self.continuation = continuation
            pending = nil
        }
        lock.unlock()

        if let pending {
            continuation.resume(with: pending)
        }
    }

    func succeed(_ transcript: String) {
        resolve(.success(transcript))
    }

    func fail(_ error: Error) {
        resolve(.failure(error))
    }

    func cancel() {
        resolve(.failure(CancellationError()))
    }

    private func resolve(_ result: Result<String, Error>) {
        let continuation: CheckedContinuation<String, Error>?
        lock.lock()
        guard completion == nil else {
            lock.unlock()
            return
        }
        completion = result
        continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(with: result)
    }
}

@MainActor
final class AudioTranscriptionService {
    private var activeTask: SFSpeechRecognitionTask?
    private var activeGate: AudioRecognitionGate?

    /// How long a single recognition pass may run before it is treated as
    /// stalled. Speech can accept a URL request and then never call back — for
    /// an unavailable on-device asset, or when the service drops the request —
    /// which used to leave the UI spinning forever with no way out but Cancel.
    private static let recognitionTimeout: Duration = .seconds(120)

    /// How long to wait for a freshly constructed recognizer to report itself
    /// available. `SFSpeechRecognizer.isAvailable` is false for a short window
    /// after `init` while Speech resolves the locale, so the old immediate
    /// check rejected perfectly good recognizers.
    private static let availabilityTimeout: Duration = .seconds(3)

    /// Transcribe one app-owned audio file with the learner's chosen engine.
    ///
    /// Routing lives here rather than in the view so every audio surface picks
    /// up the same engine preference, and so neither engine can silently
    /// substitute for the other: switching to the AI provider sends the
    /// recording off the device, and that stays an explicit choice.
    func transcribe(
        audioURL: URL,
        language: SpeechRecognitionLanguage,
        engine: AudioTranscriptionEngine
    ) async throws -> String {
        switch engine {
        case .appleSpeech:
            return try await transcribe(audioURL: audioURL, language: language)
        case .aiProvider:
            return try await transcribeWithAI(audioURL: audioURL, language: language)
        }
    }

    /// Transcribe through the configured AI provider's speech-to-text endpoint.
    private func transcribeWithAI(
        audioURL: URL,
        language: SpeechRecognitionLanguage
    ) async throws -> String {
        let settings = AIModelSettings.shared
        guard let provider = settings.transcriptionProvider() else {
            throw AudioTranscriptionError.noTranscriptionProvider
        }
        try Task.checkCancellation()
        let transcript = try await CloudAIService.shared.transcribeAudio(
            provider: provider,
            model: settings.transcriptionModel(for: provider),
            audioURL: audioURL,
            languageCode: language.transcriptionLanguageCode
        )
        // A provider that heard nothing returns an empty or whitespace body;
        // report that the same way Apple Speech does rather than committing a
        // blank transcript to the editor.
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AudioTranscriptionError.emptyTranscript
        }
        return transcript
    }

    /// Transcribe one app-owned audio file with Apple Speech.
    ///
    /// On-device recognition is preferred for privacy and offline use, but
    /// `supportsOnDeviceRecognition` only says the *recognizer* can work
    /// offline — it does not promise the locale's assets are installed. When
    /// the on-device pass fails or hears nothing, this retries through Apple's
    /// service rather than reporting a dead end, which is what made
    /// transcription look broken on devices without the Chinese (or any)
    /// dictation model downloaded.
    func transcribe(
        audioURL: URL,
        language: SpeechRecognitionLanguage
    ) async throws -> String {
        try Task.checkCancellation()
        try await ensureAuthorization()
        try Task.checkCancellation()

        guard let recognizer = SFSpeechRecognizer(locale: language.locale) else {
            throw AudioTranscriptionError.recognizerUnavailable(language: language.displayName)
        }
        try await waitUntilAvailable(recognizer, language: language)

        guard recognizer.supportsOnDeviceRecognition else {
            return try await runRecognition(recognizer: recognizer, audioURL: audioURL, onDevice: false)
        }

        do {
            return try await runRecognition(recognizer: recognizer, audioURL: audioURL, onDevice: true)
        } catch let error as AudioTranscriptionError {
            switch error {
            case .recognitionFailed, .emptyTranscript, .timedOut:
                // The on-device model is missing, incomplete, or silent. Apple's
                // service can still read this audio, so try it before failing.
                try Task.checkCancellation()
                return try await runRecognition(recognizer: recognizer, audioURL: audioURL, onDevice: false)
            case .notAuthorized, .restricted, .recognizerUnavailable, .noTranscriptionProvider:
                throw error
            }
        }
    }

    /// Poll until the recognizer reports availability, so a transient false
    /// right after construction is not mistaken for an unusable language.
    private func waitUntilAvailable(
        _ recognizer: SFSpeechRecognizer,
        language: SpeechRecognitionLanguage
    ) async throws {
        guard !recognizer.isAvailable else { return }
        let deadline = ContinuousClock.now.advanced(by: Self.availabilityTimeout)
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
            if recognizer.isAvailable { return }
        }
        throw AudioTranscriptionError.recognizerUnavailable(language: language.displayName)
    }

    /// One recognition pass over the file, on-device or through Apple's service.
    private func runRecognition(
        recognizer: SFSpeechRecognizer,
        audioURL: URL,
        onDevice: Bool
    ) async throws -> String {
        // Only one URL recognition request should run per service instance.
        cancelActiveRecognition()

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = onDevice
        // Sentence punctuation makes a transcript usable as editor text and as
        // translation input, instead of one unbroken run of words.
        request.addsPunctuation = true

        let gate = AudioRecognitionGate()
        activeGate = gate

        // The gate resolves exactly once, so this fires only if Speech never
        // does; a late timeout after a successful result is a no-op.
        let timeout = Task {
            try? await Task.sleep(for: Self.recognitionTimeout)
            guard !Task.isCancelled else { return }
            gate.fail(AudioTranscriptionError.timedOut)
        }

        defer {
            timeout.cancel()
            if activeGate === gate {
                // Always stop the underlying recognizer before releasing our
                // only strong reference. In particular, cancellation resolves
                // the continuation immediately; relying on a later main-actor
                // hop would race this defer and could leave Speech processing
                // an abandoned request in the background.
                activeTask?.cancel()
                activeTask = nil
                activeGate = nil
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                guard !Task.isCancelled else {
                    gate.cancel()
                    return
                }

                activeTask = recognizer.recognitionTask(with: request) { result, error in
                    // Speech may deliver a valid final result together with a
                    // stream-end error. A nonempty final transcript is success
                    // and must win over that companion error.
                    if let result, result.isFinal {
                        let transcript = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if transcript.isEmpty {
                            gate.fail(AudioTranscriptionError.emptyTranscript)
                        } else {
                            gate.succeed(transcript)
                        }
                        return
                    }

                    if let error {
                        gate.fail(AudioTranscriptionError.recognitionFailed(Self.describe(error)))
                    }
                }
            }
        } onCancel: {
            gate.cancel()
        }
    }

    /// Speech errors are famously opaque ("The operation couldn't be
    /// completed"), so keep the domain and code — they are the only way to tell
    /// a missing on-device asset from a network failure.
    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))"
    }

    func cancel() {
        cancelActiveRecognition()
    }

    private func cancelActiveRecognition() {
        activeGate?.cancel()
        activeTask?.cancel()
        activeTask = nil
        activeGate = nil
    }

    private func ensureAuthorization() async throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            switch status {
            case .authorized:
                return
            case .restricted:
                throw AudioTranscriptionError.restricted
            case .denied, .notDetermined:
                throw AudioTranscriptionError.notAuthorized
            @unknown default:
                throw AudioTranscriptionError.notAuthorized
            }
        case .denied:
            throw AudioTranscriptionError.notAuthorized
        case .restricted:
            throw AudioTranscriptionError.restricted
        @unknown default:
            throw AudioTranscriptionError.notAuthorized
        }
    }
}
