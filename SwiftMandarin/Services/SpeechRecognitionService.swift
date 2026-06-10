//
//  SpeechRecognitionService.swift
//  SwiftMandarin
//
//  Live speech-to-text service using SpeechAnalyzer (iOS 26+)
//  Supports both English and Chinese speech recognition
//

import Foundation
import Speech
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

/// Main speech recognition service using SpeechAnalyzer (iOS 26+)
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
    
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var recognitionTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    
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
        let installed = await SpeechTranscriber.installedLocales
        return installed.map { $0.identifier(.bcp47) }.contains(language.rawValue)
    }
    
    /// Check if the language is supported
    func isLanguageSupported(_ language: SpeechRecognitionLanguage) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(language.rawValue)
    }
    
    /// Download the speech model for a language if needed
    func downloadModelIfNeeded(for language: SpeechRecognitionLanguage) async throws {
        guard await isLanguageSupported(language) else {
            throw SpeechRecognitionError.localeNotSupported
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
    
    // MARK: - Setup
    
    /// Set up the speech transcriber for the specified language
    private func setupTranscriber(for language: SpeechRecognitionLanguage) async throws {
        transcriber = SpeechTranscriber(
            locale: language.locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],  // Enable real-time results
            attributeOptions: []
        )
        
        guard let transcriber else {
            throw SpeechRecognitionError.notAvailable
        }
        
        analyzer = SpeechAnalyzer(modules: [transcriber])
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    }
    
    /// Set up the audio session for recording
    private func setupAudioSession() throws {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }
    
    /// Set up the audio engine and converter
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine, let analyzerFormat else {
            throw SpeechRecognitionError.audioEngineError("Could not initialize audio engine")
        }
        
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        
        // Create converter if formats don't match
        if inputFormat != analyzerFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
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
        
        // Set up components
        currentLanguage = language
        try await setupTranscriber(for: language)
        try setupAudioSession()
        try setupAudioEngine()
        
        guard let audioEngine, let analyzer, let transcriber else {
            throw SpeechRecognitionError.notAvailable
        }
        
        // Clear previous state
        partialTranscript = ""
        finalTranscript = ""
        error = nil
        
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
                            // Final result - append to final transcript
                            if !self.finalTranscript.isEmpty && !textContent.isEmpty {
                                self.finalTranscript += " "
                            }
                            self.finalTranscript += textContent
                            self.partialTranscript = ""
                            self.delegate?.speechRecognitionDidReceiveFinalResult(textContent)
                        } else {
                            // Volatile/partial result
                            self.partialTranscript = textContent
                            self.delegate?.speechRecognitionDidReceivePartialResult(textContent)
                        }
                    }
                }
            } catch {
                // A normal stopRecording() cancels this task — that's not a
                // failure, so don't report it or re-enter teardown.
                guard let self, !Task.isCancelled else { return }
                await MainActor.run {
                    self.error = .recognitionError(error.localizedDescription)
                    self.delegate?.speechRecognitionDidFail(with: error)
                }
                // Tear down the mic tap, engine, and audio session — without
                // this the microphone keeps capturing after a mid-session
                // recognition failure. The delegate already got didFail, so
                // suppress the didFinish callback.
                await self.stopRecording(notifyDelegate: false)
            }
        }

        // Install audio tap
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
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
            // Remove the just-installed tap and unwind everything set up so far.
            await stopRecording()
            throw SpeechRecognitionError.audioEngineError(error.localizedDescription)
        }

        isRecording = true
        delegate?.speechRecognitionDidStart()
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
    
    /// Stop speech recognition. Idempotent — safe to call from error paths
    /// (including partially-completed starts) as well as the normal stop.
    /// - Parameter notifyDelegate: pass `false` from failure paths so the
    ///   delegate doesn't receive `didFinish` right after `didFail`.
    func stopRecording(notifyDelegate: Bool = true) async {
        let wasRecording = isRecording
        isRecording = false

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
}
