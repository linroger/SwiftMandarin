//
//  SpeechRecognitionService.swift
//  SwiftMandarin
//
//  Live speech-to-text service. On iOS 26+/macOS 26+ it uses the modern
//  SpeechAnalyzer/SpeechTranscriber pipeline; on iOS 17 it falls back to the
//  classic SFSpeechRecognizer so live speech translation keeps working.
//  Supports both English and Chinese speech recognition.
//

import Foundation
@preconcurrency import Speech
@preconcurrency import AVFAudio
@preconcurrency import AVFoundation

/// Errors that can occur during speech recognition
enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case notAvailable
    case audioEngineError(String)
    case recognitionError(String)
    case localeNotSupported
    case modelNotInstalled

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return String(localized: "Speech recognition is not authorized. Please enable it in Settings.", bundle: .appLanguage)
        case .notAvailable:
            return String(localized: "Speech recognition is not available on this device.", bundle: .appLanguage)
        case .audioEngineError(let message):
            // The interpolated detail stays a format argument so the whole
            // sentence is one catalog key; concatenating a translated prefix
            // would leave the word order untranslatable.
            return String.localizedStringWithFormat(
                String(localized: "Audio error: %@", bundle: .appLanguage),
                message
            )
        case .recognitionError(let message):
            return String.localizedStringWithFormat(
                String(localized: "Recognition error: %@", bundle: .appLanguage),
                message
            )
        case .localeNotSupported:
            return String(localized: "The selected language is not supported for speech recognition.", bundle: .appLanguage)
        case .modelNotInstalled:
            return String(localized: "The speech recognition model needs to be downloaded.", bundle: .appLanguage)
        }
    }
}

/// Language options for speech recognition
enum SpeechRecognitionLanguage: String, CaseIterable {
    case english = "en-US"
    case chinese = "zh-CN"
    case chineseTraditional = "zh-TW"

    /// Names a language to the learner, so it goes through the string catalog:
    /// these reach the language pickers and the transcription error text, and
    /// would otherwise stay English in the 中文 interface. The BCP-47 `rawValue`
    /// above stays a literal — it identifies a locale to the Speech framework.
    var displayName: String {
        switch self {
        case .english: return String(localized: "English", bundle: .appLanguage)
        case .chinese: return String(localized: "Chinese (Simplified)", bundle: .appLanguage)
        case .chineseTraditional: return String(localized: "Chinese (Traditional)", bundle: .appLanguage)
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// Delegate protocol for receiving speech recognition updates
protocol SpeechRecognitionDelegate: AnyObject {
    func speechRecognitionDidStart()
    func speechRecognitionDidReceivePartialResult(_ text: String)
    func speechRecognitionDidReceiveFinalResult(_ text: String)
    func speechRecognitionDidFinish()
    func speechRecognitionDidFail(with error: Error)
}

/// Recognition engine abstraction so the service can store either the modern
/// (iOS 26+) or legacy (iOS 17) engine in a version-agnostic property.
@MainActor
private protocol SpeechRecognitionEngine: AnyObject {
    var onPartialResult: ((String) -> Void)? { get set }
    var onFinalResult: ((String) -> Void)? { get set }
    /// Called when the recognition stream fails mid-session.
    var onStreamError: ((Error) -> Void)? { get set }

    func start(language: SpeechRecognitionLanguage) async throws
    func stop() async
    /// Tear down without waiting on anything: the microphone tap and audio
    /// engine stop synchronously, the recognizer is told to finish on its
    /// own time, and every reference is dropped. The service calls this when
    /// `stop()` overruns its bound.
    func forceStop()
}

/// Resolves a bounded wait exactly once, from whichever of the engine's own
/// `stop()` or the deadline finishes first. Main-actor isolated like the
/// service, so no lock is needed; a second `finish` is a no-op.
@MainActor
private final class StopRace {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var result: Bool?

    /// Suspends until `finish(cleanly:)` is called; returns at once if it
    /// already was.
    func wait() async -> Bool {
        if let result { return result }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish(cleanly: Bool) {
        guard result == nil else { return }
        result = cleanly
        continuation?.resume(returning: cleanly)
        continuation = nil
    }
}

/// Main speech recognition service
@MainActor
@Observable
final class SpeechRecognitionService {
    static let shared = SpeechRecognitionService()

    // MARK: - Published State

    var isRecording: Bool = false
    var partialTranscript: String = ""
    var finalTranscript: String = ""
    var currentLanguage: SpeechRecognitionLanguage = .english
    var isModelDownloading: Bool = false
    var downloadProgress: Double = 0.0
    var error: SpeechRecognitionError?

    // MARK: - Private Properties

    private var engine: SpeechRecognitionEngine?
    private var operationID: UUID?
    private var activeResultRequestID: UUID?
    private var failureRequestID: UUID?
    private var isStarting = false
    private var isStopping = false
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []
    private var audioSessionOwner: AudioSessionOwner?

    weak var delegate: SpeechRecognitionDelegate?

    /// How long an engine's own `stop()` may take before it is torn down by
    /// force. The modern engine waits for the analyzer to finalize the last
    /// results, and an analyzer that never does left `stopRecording` suspended
    /// with the Live Speech button stuck on "stopping". Final results arrive
    /// within a second or so of the last audio; three is generous.
    private static let engineStopTimeout: Duration = .seconds(3)

    private init() {}

    // MARK: - Authorization

    /// Check if speech recognition is authorized
    func checkAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Request speech recognition authorization
    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Check and request microphone authorization
    func checkMicrophoneAuthorization() async -> Bool {
        let status = AVAudioApplication.shared.recordPermission

        switch status {
        case .granted:
            return true
        case .undetermined:
            return await requestMicrophoneAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Model Management

    /// Check if the speech model for the given language is installed
    func isModelInstalled(for language: SpeechRecognitionLanguage) async -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            let installed = await SpeechTranscriber.installedLocales
            return installed.map { $0.identifier(.bcp47) }.contains(language.rawValue)
        } else {
            // SFSpeechRecognizer has no user-visible model install step.
            return SFSpeechRecognizer(locale: language.locale) != nil
        }
    }

    /// Check if the language is supported
    func isLanguageSupported(_ language: SpeechRecognitionLanguage) async -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            let supported = await SpeechTranscriber.supportedLocales
            return supported.map { $0.identifier(.bcp47) }.contains(language.rawValue)
        } else {
            return SFSpeechRecognizer(locale: language.locale) != nil
        }
    }

    /// Download the speech model for a language if needed
    func downloadModelIfNeeded(for language: SpeechRecognitionLanguage) async throws {
        guard await isLanguageSupported(language) else {
            throw SpeechRecognitionError.localeNotSupported
        }

        guard #available(iOS 26.0, macOS 26.0, *) else {
            // Legacy recognition downloads nothing up front.
            return
        }

        if await isModelInstalled(for: language) {
            return
        }

        isModelDownloading = true
        downloadProgress = 0.0

        let tempTranscriber = SpeechTranscriber(
            locale: language.locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        do {
            if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [tempTranscriber]) {
                let progress = downloader.progress

                // Poll the download's progress for the UI. The handle is kept
                // and cancelled on every exit: a download that throws can leave
                // `progress` neither finished nor cancelled, and an unowned
                // poller then runs forever at 10 Hz, re-rendering every view
                // that reads `downloadProgress` — one more loop per retry.
                let monitor = Task { [weak self] in
                    while !Task.isCancelled, !progress.isFinished, !progress.isCancelled {
                        self?.downloadProgress = progress.fractionCompleted
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                defer { monitor.cancel() }

                try await downloader.downloadAndInstall()
            }

            isModelDownloading = false
            downloadProgress = 1.0
        } catch {
            isModelDownloading = false
            throw SpeechRecognitionError.modelNotInstalled
        }
    }

    // MARK: - Recording

    /// Start live speech recognition
    func startRecording(language: SpeechRecognitionLanguage = .english) async throws {
        guard !isRecording, !isStarting, !isStopping else { return }

        let requestID = UUID()
        let sessionOwner = AudioSessionOwner()
        operationID = requestID
        isStarting = true
        var candidateEngine: SpeechRecognitionEngine?

        do {
            // Check authorizations.
            guard await checkAuthorization() else {
                throw SpeechRecognitionError.notAuthorized
            }
            try ensureCurrentOperation(requestID)

            guard await checkMicrophoneAuthorization() else {
                throw SpeechRecognitionError.notAuthorized
            }
            try ensureCurrentOperation(requestID)

            // Ensure the on-device model is available before taking audio
            // ownership or interrupting another playback feature.
            try await downloadModelIfNeeded(for: language)
            try ensureCurrentOperation(requestID)

            SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()
            SpeechService.stop()
            currentLanguage = language

            // Clear previous state.
            partialTranscript = ""
            finalTranscript = ""
            error = nil

            // Pick the recognition engine for this OS release.
            let engine: SpeechRecognitionEngine
            if #available(iOS 26.0, macOS 26.0, *) {
                engine = ModernSpeechEngine()
            } else {
                engine = LegacySpeechEngine()
            }
            candidateEngine = engine
            self.engine = engine
            audioSessionOwner = sessionOwner
            activeResultRequestID = requestID
            failureRequestID = nil

            engine.onPartialResult = { [weak self] text in
                guard let self, self.activeResultRequestID == requestID else { return }
                self.partialTranscript = text
                self.delegate?.speechRecognitionDidReceivePartialResult(text)
            }
            engine.onFinalResult = { [weak self] text in
                guard let self, self.activeResultRequestID == requestID else { return }
                if !self.finalTranscript.isEmpty && !text.isEmpty {
                    self.finalTranscript += " "
                }
                self.finalTranscript += text
                self.partialTranscript = ""
                self.delegate?.speechRecognitionDidReceiveFinalResult(text)
            }
            engine.onStreamError = { [weak self] error in
                guard let self,
                      self.activeResultRequestID == requestID,
                      self.failureRequestID != requestID else { return }
                self.failureRequestID = requestID
                self.error = .recognitionError(error.localizedDescription)
                self.delegate?.speechRecognitionDidFail(with: error)
                // Tear down the mic tap, engine, and audio session — without
                // this the microphone keeps capturing after a mid-session
                // recognition failure. The delegate already got didFail, so
                // suppress the didFinish callback.
                Task { await self.stopRecording(notifyDelegate: false) }
            }

            try await AudioSessionCoordinator.shared.acquire(
                .liveRecognition,
                owner: sessionOwner
            )
            try ensureCurrentOperation(requestID)
            try await engine.start(language: language)
            try ensureCurrentOperation(requestID)

            isStarting = false
            isRecording = true
            delegate?.speechRecognitionDidStart()
        } catch {
            if let candidateEngine, self.engine === candidateEngine {
                self.engine = nil
            }
            if operationID == requestID {
                operationID = nil
                isStarting = false
                isRecording = false
            }
            if audioSessionOwner == sessionOwner {
                audioSessionOwner = nil
            }
            if activeResultRequestID == requestID {
                activeResultRequestID = nil
            }
            if failureRequestID == requestID {
                failureRequestID = nil
            }
            // stopRecording may already have detached this candidate while
            // start() was suspended. Run candidate-local cleanup again so a
            // late-resuming engine cannot leave a hidden microphone tap alive.
            if let candidateEngine {
                await stopEngine(candidateEngine)
            }
            AudioSessionCoordinator.shared.release(sessionOwner)
            throw error
        }
    }

    /// Stop an engine, but never wait on it for longer than
    /// `engineStopTimeout`. Past the bound the engine is torn down by force
    /// and this returns, so the service's "stopping" state always ends. The
    /// overrunning `stop()` is cancelled and left to finish — or not — on its
    /// own; nothing here references the engine afterwards.
    private func stopEngine(_ engine: SpeechRecognitionEngine) async {
        let race = StopRace()
        let stop = Task {
            await engine.stop()
            race.finish(cleanly: true)
        }
        let deadline = Task {
            try? await Task.sleep(for: Self.engineStopTimeout)
            guard !Task.isCancelled else { return }
            race.finish(cleanly: false)
        }
        let stoppedCleanly = await race.wait()
        deadline.cancel()
        guard !stoppedCleanly else { return }
        stop.cancel()
        engine.forceStop()
    }

    /// Stop speech recognition. Idempotent — safe to call from error paths
    /// (including partially-completed starts) as well as the normal stop.
    /// - Parameter notifyDelegate: pass `false` from failure paths so the
    ///   delegate doesn't receive `didFinish` right after `didFail`.
    func stopRecording(notifyDelegate: Bool = true) async {
        if isStopping {
            await withCheckedContinuation { continuation in
                stopWaiters.append(continuation)
            }
            return
        }
        isStopping = true
        let wasRecording = isRecording
        let engineToStop = engine
        let sessionOwner = audioSessionOwner
        let resultRequestID = activeResultRequestID

        operationID = nil
        isStarting = false
        isRecording = false
        engine = nil
        audioSessionOwner = nil

        if let engineToStop {
            await stopEngine(engineToStop)
        }
        if activeResultRequestID == resultRequestID {
            activeResultRequestID = nil
        }
        if failureRequestID == resultRequestID {
            failureRequestID = nil
        }
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
        isStopping = false
        let waiters = stopWaiters
        stopWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        if wasRecording && notifyDelegate {
            delegate?.speechRecognitionDidFinish()
        }
    }

    /// Toggle recording state
    func toggleRecording(language: SpeechRecognitionLanguage = .english) async throws {
        if isRecording {
            await stopRecording()
        } else {
            try await startRecording(language: language)
        }
    }

    /// Settles observable and session state after iOS interrupts capture or a
    /// required route disappears. The shared notification bridge invokes this
    /// for all audio features so recognition cannot retain a stale owner.
    func handleAudioSessionLoss(message: String) async {
        guard isRecording || isStarting || engine != nil || audioSessionOwner != nil else { return }
        let requestID = activeResultRequestID ?? operationID
        if failureRequestID != requestID {
            failureRequestID = requestID
            let interruptionError = SpeechRecognitionError.audioEngineError(message)
            error = interruptionError
            delegate?.speechRecognitionDidFail(with: interruptionError)
        }
        await stopRecording(notifyDelegate: false)
    }

    /// Get the complete transcript (final + partial)
    var completeTranscript: String {
        if partialTranscript.isEmpty {
            return finalTranscript
        }
        return finalTranscript + (finalTranscript.isEmpty ? "" : " ") + partialTranscript
    }

    /// Clear all transcripts
    func clearTranscripts() {
        partialTranscript = ""
        finalTranscript = ""
    }

    private func ensureCurrentOperation(_ requestID: UUID) throws {
        try Task.checkCancellation()
        guard operationID == requestID else { throw CancellationError() }
    }
}

// MARK: - Modern Engine (SpeechAnalyzer, iOS 26+/macOS 26+)

@available(iOS 26.0, macOS 26.0, *)
@MainActor
private final class ModernSpeechEngine: SpeechRecognitionEngine {

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onStreamError: ((Error) -> Void)?

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var recognitionTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    private var stopRequested = false

    func start(language: SpeechRecognitionLanguage) async throws {
        stopRequested = false
        // Set up the transcriber + analyzer
        let transcriber = SpeechTranscriber(
            locale: language.locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],  // Enable real-time results
            attributeOptions: []
        )
        self.transcriber = transcriber

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard !stopRequested else { throw CancellationError() }

        // Set up the audio engine and converter
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        guard let analyzerFormat else {
            // This detail is surfaced verbatim inside the user-visible
            // "Audio error: %@" sentence, unlike the neighbouring throws that
            // pass an already system-localized `error.localizedDescription`.
            throw SpeechRecognitionError.audioEngineError(
                String(localized: "Could not initialize audio engine", bundle: .appLanguage)
            )
        }

        // Create input stream for the analyzer
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputBuilder

        // Start the analyzer
        try await analyzer.start(inputSequence: inputSequence)
        guard !stopRequested else { throw CancellationError() }

        // Read the microphone format only now, after the suspension above, and
        // refuse to tap when it is not a real format. `installTap` with a
        // zero-rate or zero-channel format raises an Objective-C exception
        // (`IsFormatSampleRateAndChannelCountValid`) that Swift cannot catch —
        // a hard crash. That is exactly what a Mac with no input device
        // reports, and what a route change (AirPods connecting) between
        // reading the format and installing the tap produces on iPhone.
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw SpeechRecognitionError.audioEngineError(
                String(localized: "No microphone input is available. Connect or enable a microphone and try again.", bundle: .appLanguage)
            )
        }

        // Create converter if formats don't match
        if inputFormat != analyzerFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        }

        // Start recognition task to process results
        recognitionTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }

                    // Convert AttributedString to plain String
                    let textContent = String(result.text.characters)

                    await MainActor.run {
                        if result.isFinal {
                            self.onFinalResult?(textContent)
                        } else {
                            self.onPartialResult?(textContent)
                        }
                    }
                }
            } catch {
                // A normal stop() cancels this task — that's not a failure.
                guard let self, !Task.isCancelled else { return }
                await MainActor.run {
                    self.onStreamError?(error)
                }
            }
        }

        // Install audio tap.
        //
        // Capture the conversion context locally so the tap can run *fully
        // synchronously* on the audio thread, exactly like the legacy engine's
        // `request.append(buffer)`. The previous implementation hopped onto an
        // unstructured `Task` while holding the engine's reused input buffer,
        // which risked three concrete defects: (1) use-after-reuse — the engine
        // overwrites `buffer` as soon as the tap returns, before the async Task
        // reads it; (2) frame reordering — independent `Task`s have no ordering
        // guarantee, so buffers could reach the analyzer out of sequence; and
        // (3) a broken converter input block that returned the same buffer on
        // every callback. Doing the work synchronously here removes all three.
        let converter = audioConverter
        let targetFormat = analyzerFormat
        let continuation = inputBuilder

        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            let outputBuffer: AVAudioPCMBuffer
            if let converter {
                let ratio = targetFormat.sampleRate / buffer.format.sampleRate
                let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
                guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

                var consumed = false
                var conversionError: NSError?
                converter.convert(to: converted, error: &conversionError) { _, outStatus in
                    // One-shot input block: hand the source buffer over exactly
                    // once, then report exhaustion so the converter never re-reads
                    // the same frames (the prior code looped on the same buffer).
                    if consumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    consumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                guard conversionError == nil, converted.frameLength > 0 else { return }
                outputBuffer = converted
            } else {
                // Formats already match, so no converter was created; the engine
                // reuses `buffer`, so the analyzer must receive an owned copy
                // rather than the soon-to-be-overwritten original.
                guard let copy = ModernSpeechEngine.copyBuffer(buffer) else { return }
                outputBuffer = copy
            }
            continuation.yield(AnalyzerInput(buffer: outputBuffer))
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechRecognitionError.audioEngineError(error.localizedDescription)
        }
    }

    /// Deep-copies a PCM buffer so it can safely outlive the audio engine's
    /// reuse of the tap buffer. Copies the raw audio buffer list, so it works
    /// for any PCM layout (float/int, interleaved/non-interleaved).
    ///
    /// `nonisolated` because it is called from the audio render thread inside the
    /// tap; it touches only its argument, so it must not be main-actor isolated.
    nonisolated private static func copyBuffer(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameCapacity) else {
            return nil
        }
        copy.frameLength = source.frameLength

        let sourceList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
        let destinationList = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<min(sourceList.count, destinationList.count) {
            guard let sourceData = sourceList[index].mData,
                  let destinationData = destinationList[index].mData else { continue }
            memcpy(destinationData, sourceData, Int(sourceList[index].mDataByteSize))
            destinationList[index].mDataByteSize = sourceList[index].mDataByteSize
        }
        return copy
    }

    func stop() async {
        stopRequested = true
        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Finish the input stream
        inputContinuation?.finish()
        inputContinuation = nil

        // Finalize and wait for remaining results
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            print("Error finalizing analyzer: \(error)")
        }

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Clean up
        analyzer = nil
        transcriber = nil
        audioConverter = nil
    }

    func forceStop() {
        stopRequested = true
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        inputContinuation?.finish()
        inputContinuation = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        // Finishing is what `stop()` is still waiting on; cancelling instead
        // discards whatever the analyzer has not delivered and lets it wind
        // down without anyone waiting on it.
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
        transcriber = nil
        audioConverter = nil
    }
}

// MARK: - Legacy Engine (SFSpeechRecognizer, iOS 17)

/// Classic recognition pipeline for systems without SpeechAnalyzer.
/// SFSpeechRecognizer reports a cumulative transcription that grows as the
/// user speaks, delivered here as partial results; the transcript is
/// finalized when recording stops.
@MainActor
private final class LegacySpeechEngine: SpeechRecognitionEngine {

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onStreamError: ((Error) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscription: String = ""
    private var deliveredFinal = false
    private var isStopping = false

    func start(language: SpeechRecognitionLanguage) async throws {
        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }
        self.recognizer = recognizer
        latestTranscription = ""
        deliveredFinal = false
        isStopping = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition when the device has the model.
        // Note: unlike the iOS 26 SpeechAnalyzer engine (always on-device),
        // devices without an on-device model for the chosen language (common
        // for zh-CN on older hardware) fall back to Apple's server-based
        // recognition here.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        // Same guard as the modern engine: tapping with an empty format is an
        // uncatchable Objective-C exception, not a Swift error.
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw SpeechRecognitionError.audioEngineError(
                String(localized: "No microphone input is available. Connect or enable a microphone and try again.", bundle: .appLanguage)
            )
        }
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Extract Sendable values before hopping to the main actor.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failure = error
            Task { @MainActor [weak self] in
                self?.handleResult(text: text, isFinal: isFinal, error: failure)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechRecognitionError.audioEngineError(error.localizedDescription)
        }
    }

    private func handleResult(text: String?, isFinal: Bool, error: Error?) {
        if let text {
            latestTranscription = text
            if isFinal {
                deliverFinalIfNeeded()
            } else {
                onPartialResult?(text)
            }
        }

        if let error {
            // A final result can arrive together with a stream-end error —
            // the transcription succeeded, so don't report a failure. The
            // same applies to the cancellation-style error endAudio() causes
            // during a normal stop.
            if isFinal || isStopping {
                deliverFinalIfNeeded()
            } else {
                onStreamError?(error)
            }
        }
    }

    /// Promote the cumulative transcription to a final result exactly once.
    private func deliverFinalIfNeeded() {
        guard !deliveredFinal else { return }
        deliveredFinal = true
        if !latestTranscription.isEmpty {
            onFinalResult?(latestTranscription)
        }
    }

    func stop() async {
        isStopping = true

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Let the recognizer flush its last result, then finalize whatever
        // transcription we have so the caller never loses the transcript.
        request?.endAudio()
        try? await Task.sleep(for: .milliseconds(300))
        deliverFinalIfNeeded()

        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizer = nil
    }

    func forceStop() {
        isStopping = true
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        request?.endAudio()
        deliverFinalIfNeeded()

        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        recognizer = nil
    }
}
