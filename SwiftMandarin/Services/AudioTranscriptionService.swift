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

nonisolated enum AudioTranscriptionError: LocalizedError {
    case notAuthorized
    case restricted
    case recognizerUnavailable(language: String)
    case emptyTranscript
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            #if os(iOS)
            return String(localized: "Speech recognition access is required to transcribe audio. Enable it in Settings and try again.")
            #else
            return String(localized: "Speech recognition access is required to transcribe audio. Enable it in System Settings and try again.")
            #endif
        case .restricted:
            return String(localized: "Speech recognition is restricted on this device.")
        case .recognizerUnavailable:
            return String(localized: "Apple Speech is not currently available for the selected language. Try again when the language model or network service is available.")
        case .emptyTranscript:
            return String(localized: "Apple Speech could not find spoken words in this audio. Check the recognition language and audio quality, then try again.")
        case .recognitionFailed(let message):
            return String(localized: "Audio transcription failed:") + " " + message
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

    /// Transcribe one app-owned audio file. Setting
    /// `requiresOnDeviceRecognition` when supported ensures the preferred
    /// private/offline path while retaining Apple's service as a fallback on
    /// devices or locales that do not expose an on-device recognizer.
    func transcribe(
        audioURL: URL,
        language: SpeechRecognitionLanguage
    ) async throws -> String {
        try Task.checkCancellation()
        try await ensureAuthorization()
        try Task.checkCancellation()

        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.isAvailable else {
            throw AudioTranscriptionError.recognizerUnavailable(language: language.displayName)
        }

        // Only one URL recognition request should run per service instance.
        cancelActiveRecognition()

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let gate = AudioRecognitionGate()
        activeGate = gate

        defer {
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
                        gate.fail(AudioTranscriptionError.recognitionFailed(error.localizedDescription))
                    }
                }
            }
        } onCancel: {
            gate.cancel()
        }
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
