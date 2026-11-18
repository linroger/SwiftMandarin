//
//  InterpreterPipeline.swift
//  SwiftMandarin
//
//  The seams between the Interpreter's state machine and the three system
//  frameworks it drives. `SpeechTranslationCoordinator` talks only to these
//  protocols, which is what lets `scripts/test-interpreter.sh` run every
//  transition, cancellation and failure against scripted stand-ins, without
//  a microphone, a language pack or a speaker.
//
//  The production conformances are `PushToTalkTranscriptionService`
//  (Speech), `InterpreterTranslationService` (Translation) and the adapters
//  in `InterpreterAdapters.swift` (speech output, audio session, history).
//

import Foundation

/// Speech-to-text for one held press.
@MainActor
protocol InterpreterTranscribing: AnyObject, Sendable {
    /// Whether the speech model for the language `direction` listens to is
    /// installed and usable.
    func assetState(for direction: TranslationDirection) async -> InterpreterAssetState

    /// Installs whatever speech models are missing. `onProgress` receives the
    /// fraction complete, or `nil` when the system has not reported one yet.
    func installAssets(onProgress: @escaping @MainActor (Double?) -> Void) async throws

    /// Loads the recognizer for `direction` ahead of the press, so the press
    /// itself does not wait on it. Safe to call repeatedly.
    func prepare(for direction: TranslationDirection) async

    /// Opens the microphone and starts recognizing. Returns once audio is
    /// flowing; `onUpdate` then delivers the transcript as it grows.
    ///
    /// Throws `CancellationError` if `cancel()` arrives first.
    func begin(
        direction: TranslationDirection,
        onUpdate: @escaping @MainActor (TranscriptSnapshot) -> Void
    ) async throws

    /// Closes the microphone, lets the recognizer deliver its last words, and
    /// returns the whole transcript. Throws `CancellationError` if `cancel()`
    /// arrives first.
    func finish() async throws -> String

    /// Closes the microphone and discards the turn. Idempotent.
    func cancel() async

    /// Frees the loaded models when the screen closes.
    func releaseResources() async
}

/// Text-to-text translation between English and Chinese.
@MainActor
protocol InterpreterTranslating: AnyObject, Sendable {
    /// Whether the language pair is installed and usable.
    func assetState() async -> InterpreterAssetState

    /// The device has both a natural and a fast model, so the setting that
    /// chooses between them means something. Known once `assetState()` has
    /// answered.
    var offersTwoModels: Bool { get }

    /// Gets `model` ready for `direction`, so a translation that follows
    /// soon does not wait for it to load. Cheap, and safe to call often: a
    /// turn calls it at the press and again every few seconds of the hold.
    func warm(_ direction: TranslationDirection, model: InterpreterTranslationModel) async

    func translate(
        _ text: String,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) async throws -> String
}

/// Speech output for a finished translation.
@MainActor
protocol InterpreterSpeaking: AnyObject, Sendable {
    /// Speaks `text` and returns when it has finished. `onStart` runs when
    /// audio actually begins, with the voice that is speaking: the system's
    /// when a MiniMax request fell back to it. Throws `CancellationError`
    /// when `stop()` or a newer request cuts it short.
    func speak(
        _ text: String,
        languageCode: String,
        engine: SpeechVoiceEngine,
        onStart: @escaping @MainActor (SpeechVoiceEngine) -> Void
    ) async throws

    /// Stops speaking at once.
    func stop()
}

/// Everything else the state machine needs from the app: permissions, the
/// shared audio session, the user's preferences, and history.
@MainActor
protocol InterpreterEnvironment: AnyObject, Sendable {
    var microphonePermission: InterpreterPermissionState { get }

    /// Shows the system's microphone prompt. Returns whether access was granted.
    func requestMicrophonePermission() async -> Bool

    /// Stops any other feature that is recording or playing audio.
    func stopOtherAudio() async

    /// Configures the audio session for a conversation and keeps it that way
    /// until `endConversationAudio()`. Safe to call when already begun.
    func beginConversationAudio() async throws

    func endConversationAudio()

    var voiceEngine: SpeechVoiceEngine { get }
    var translationQuality: InterpreterTranslationQuality { get }

    /// Adds a finished turn to the app's translation history, if the user
    /// keeps one.
    func record(source: String, translation: String, direction: TranslationDirection)
}

/// Time, injectable so the checks can hold a press for exactly 249 ms.
nonisolated protocol InterpreterClock: Sendable {
    var now: ContinuousClock.Instant { get }
    func sleep(for duration: Duration) async throws
}

nonisolated struct SystemInterpreterClock: InterpreterClock {
    var now: ContinuousClock.Instant { ContinuousClock.now }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

nonisolated extension Duration {
    /// Whole milliseconds, for timing records and logs.
    var interpreterMilliseconds: Int {
        let parts = components
        return Int(parts.seconds) * 1_000 + Int(parts.attoseconds / 1_000_000_000_000_000)
    }
}

/// A value that is delivered exactly once, from whichever of several
/// competitors gets there first: the work itself, a deadline, or a
/// cancellation. Later deliveries are ignored.
///
/// This is what lets a watchdog release a caller from a system call that
/// never returns. A task group cannot do that, because a group waits for
/// every child — including the one that is stuck.
@MainActor
final class InterpreterOneShot<Value: Sendable> {
    private var waiters: [CheckedContinuation<Value, Never>] = []
    private var value: Value?

    init() {}

    /// Suspends until a value is delivered; returns at once if one already
    /// was. Any number of callers may wait, and each gets the value.
    func wait() async -> Value {
        if let value { return value }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Delivers `newValue` unless something else already won.
    func resolve(_ newValue: Value) {
        guard value == nil else { return }
        value = newValue
        let waiting = waiters
        waiters.removeAll()
        for waiter in waiting {
            waiter.resume(returning: newValue)
        }
    }

    var isResolved: Bool { value != nil }
}

/// Runs `operation` on the main actor, but never waits on it for longer than
/// `duration`. Past the deadline `timeoutError` is thrown and the operation
/// is cancelled and left to wind down by itself.
@MainActor
func withInterpreterDeadline<Value: Sendable>(
    _ duration: Duration,
    clock: any InterpreterClock,
    timeoutError: InterpreterError,
    operation: @escaping @MainActor () async throws -> Value
) async throws -> Value {
    let outcome = InterpreterOneShot<Result<Value, any Error>>()
    let work = Task { @MainActor in
        do {
            outcome.resolve(.success(try await operation()))
        } catch {
            outcome.resolve(.failure(error))
        }
    }
    let deadline = Task { @MainActor in
        do {
            try await clock.sleep(for: duration)
        } catch {
            return
        }
        outcome.resolve(.failure(timeoutError))
    }
    defer {
        deadline.cancel()
    }

    let result = await withTaskCancellationHandler {
        await outcome.wait()
    } onCancel: {
        work.cancel()
        Task { @MainActor in
            outcome.resolve(.failure(CancellationError()))
        }
    }
    if case .failure = result {
        work.cancel()
    }
    return try result.get()
}
