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
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .audioEngineError(let message):
            return "Audio error: \(message)"
        case .recognitionError(let message):
            return "Recognition error: \(message)"
        case .localeNotSupported:
            return "The selected language is not supported for speech recognition."
        case .modelNotInstalled:
            return "The speech recognition model needs to be downloaded."
        }
    }
}

/// Language options for speech recognition
enum SpeechRecognitionLanguage: String, CaseIterable {
    case english = "en-US"
    case chinese = "zh-CN"
    case chineseTraditional = "zh-TW"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "Chinese (Simplified)"
        case .chineseTraditional: return "Chinese (Traditional)"
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

    weak var delegate: SpeechRecognitionDelegate?

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
                // Store reference to progress for observation
                let progress = downloader.progress

                // Observe download progress using KVO
                Task {
                    while !progress.isFinished && !progress.isCancelled {
                        await MainActor.run {
                            self.downloadProgress = progress.fractionCompleted
                        }
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }

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
        guard !isRecording else { return }

        // Check authorizations
        guard await checkAuthorization() else {
            throw SpeechRecognitionError.notAuthorized
        }

        guard await checkMicrophoneAuthorization() else {
            throw SpeechRecognitionError.notAuthorized
        }

        // Ensure model is available
        try await downloadModelIfNeeded(for: language)

        currentLanguage = language

        // Clear previous state
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
        self.engine = engine

        engine.onPartialResult = { [weak self] text in
            guard let self else { return }
            self.partialTranscript = text
            self.delegate?.speechRecognitionDidReceivePartialResult(text)
        }
        engine.onFinalResult = { [weak self] text in
            guard let self else { return }
            if !self.finalTranscript.isEmpty && !text.isEmpty {
                self.finalTranscript += " "
            }
            self.finalTranscript += text
            self.partialTranscript = ""
            self.delegate?.speechRecognitionDidReceiveFinalResult(text)
        }
        engine.onStreamError = { [weak self] error in
            guard let self else { return }
            self.error = .recognitionError(error.localizedDescription)
            self.delegate?.speechRecognitionDidFail(with: error)
            // Tear down the mic tap, engine, and audio session — without
            // this the microphone keeps capturing after a mid-session
            // recognition failure. The delegate already got didFail, so
            // suppress the didFinish callback.
            Task { await self.stopRecording(notifyDelegate: false) }
        }

        do {
            try await engine.start(language: language)
        } catch {
            // Unwind anything the engine set up before it failed.
            await stopRecording(notifyDelegate: false)
            throw error
        }

        isRecording = true
        delegate?.speechRecognitionDidStart()
    }

    /// Stop speech recognition. Idempotent — safe to call from error paths
    /// (including partially-completed starts) as well as the normal stop.
    /// - Parameter notifyDelegate: pass `false` from failure paths so the
    ///   delegate doesn't receive `didFinish` right after `didFail`.
    func stopRecording(notifyDelegate: Bool = true) async {
        let wasRecording = isRecording
        isRecording = false

        await engine?.stop()
        engine = nil

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif

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

    /// Set up the audio session for recording (shared by both engines).
    fileprivate static func activateAudioSession() throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
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

    func start(language: SpeechRecognitionLanguage) async throws {
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

        try SpeechRecognitionService.activateAudioSession()

        // Set up the audio engine and converter
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        guard let analyzerFormat else {
            throw SpeechRecognitionError.audioEngineError("Could not initialize audio engine")
        }

        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)

        // Create converter if formats don't match
        if inputFormat != analyzerFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
        }

        // Create input stream for the analyzer
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = inputBuilder

        // Start the analyzer
        try await analyzer.start(inputSequence: inputSequence)

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

        // Install audio tap
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            Task {
                await self.processAudioBuffer(buffer)
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw SpeechRecognitionError.audioEngineError(error.localizedDescription)
        }
    }

    /// Process audio buffer and send to analyzer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async {
        guard let inputContinuation, let analyzerFormat else { return }

        var bufferToSend = buffer

        // Convert format if needed
        if let converter = audioConverter {
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: analyzerFormat,
                frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * (analyzerFormat.sampleRate / buffer.format.sampleRate))
            )

            guard let convertedBuffer else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil {
                bufferToSend = convertedBuffer
            }
        }

        let input = AnalyzerInput(buffer: bufferToSend)
        inputContinuation.yield(input)
    }

    func stop() async {
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

        try SpeechRecognitionService.activateAudioSession()

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
}
