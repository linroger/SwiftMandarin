//
//  PushToTalkTranscriptionService.swift
//  SwiftMandarin
//
//  Speech-to-text for one held press: the microphone opens when the button
//  goes down, audio streams into `SpeechAnalyzer` while it is held, and the
//  transcript is finalized when it is released.
//
//  The order of operations is what makes this feel instant and never hang:
//
//  - The recognizer for each direction is built and prepared before any
//    press (`prepare`), so a press only has to start the audio engine.
//  - The microphone tap opens first and feeds an `AsyncStream`. The analyzer
//    is started on that stream a moment later; whatever was said in between
//    is already queued, so the first word is not lost.
//  - On release the tap is removed, the stream is finished, and
//    `finalizeAndFinishThroughEndOfInput()` is called. The task reading the
//    recognizer's results is then *left to end by itself*: the results
//    sequence only terminates once the analyzer has finished, and only then
//    has every final word been delivered. Cancelling it early loses words;
//    never finalizing leaves it waiting forever.
//  - A watchdog bounds that wait, so a recognizer that never finishes cannot
//    hold the screen.
//
//  One turn at a time. `begin` discards a turn that is still open, and
//  `cancel` makes an in-flight `begin` or `finish` throw `CancellationError`.
//
//  The microphone itself sits behind `InterpreterAudioCapturing`, so the
//  self-test can feed the same recognizer synthesized speech instead.
//

@preconcurrency import AVFAudio
import CoreMedia
import Foundation
import Speech
import os

/// What the recognizer's result stream produced, reduced to Sendable values
/// so it can cross from the stream's own task to the main actor.
nonisolated private enum RecognizerEvent: Sendable {
    case result(text: String, isFinal: Bool, start: Double, end: Double)
    case finished
    case failed(String)
}

/// Counts the buffers the microphone tap has delivered. Written on the audio
/// thread, read on the main actor.
nonisolated private final class TapActivity: Sendable {
    private let buffers = OSAllocatedUnfairLock(initialState: 0)

    func noteBuffer() {
        buffers.withLock { $0 += 1 }
    }

    var bufferCount: Int {
        buffers.withLock { $0 }
    }
}

/// Builds the block the audio engine calls with each microphone buffer.
///
/// It lives in a nonisolated type on purpose. The engine calls the block on
/// its own thread, and a closure written inside a main-actor method would be
/// main-actor-isolated — a wrong-isolation entry point that Swift 6 turns
/// into a crash. Everything the block needs is passed in, and it does all of
/// its work synchronously: the engine reuses `buffer` as soon as the block
/// returns, and separate tasks would not keep the buffers in order.
@available(iOS 26.0, macOS 26.0, *)
nonisolated private enum MicrophoneTap {
    static func makeBlock(
        converter: AVAudioConverter?,
        targetFormat: AVAudioFormat,
        input: AsyncStream<AnalyzerInput>.Continuation,
        activity: TapActivity
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            activity.noteBuffer()
            let output: AVAudioPCMBuffer?
            if let converter {
                output = convert(buffer, with: converter, to: targetFormat)
            } else {
                output = copy(buffer)
            }
            if let output {
                input.yield(AnalyzerInput(buffer: output))
            }
        }
    }

    /// Converts one microphone buffer to the recognizer's format. The input
    /// block hands the buffer over exactly once and then reports that no more
    /// is available, so the converter keeps its resampler state from one
    /// buffer to the next without ever re-reading the same frames.
    private static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, output.frameLength > 0 else { return nil }
        return output
    }

    /// An owned copy, for the case where the microphone already delivers the
    /// recognizer's format and no converter exists.
    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameCapacity) else {
            return nil
        }
        copy.frameLength = source.frameLength
        let sourceList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
        let destinationList = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<min(sourceList.count, destinationList.count) {
            guard let from = sourceList[index].mData, let to = destinationList[index].mData else { continue }
            memcpy(to, from, Int(sourceList[index].mDataByteSize))
            destinationList[index].mDataByteSize = sourceList[index].mDataByteSize
        }
        return copy
    }
}

/// Where a turn's audio comes from. In the app this is always the
/// microphone; the self-test substitutes synthesized speech so the real
/// recognizer can be exercised without anyone talking to the computer.
@MainActor
protocol InterpreterAudioCapturing: AnyObject {
    /// The format this source delivers. Throws when there is no usable
    /// input. Called once, before `start`.
    func inputFormat() throws -> AVAudioFormat

    /// Starts delivering buffers to `block`, on a thread of the source's
    /// choosing, until `stop()`.
    func start(block: @escaping AVAudioNodeTapBlock) throws

    /// Stops delivering buffers. Synchronous and idempotent.
    func stop()

    /// Called when the source stops by itself because its hardware changed.
    var onHardwareChange: (@MainActor () -> Void)? { get set }
}

/// The microphone, through an `AVAudioEngine` input tap.
@MainActor
final class MicrophoneCapture: InterpreterAudioCapturing {
    /// How much audio each tap buffer holds. `installTap` documents 100 ms
    /// as the smallest it supports; the smaller the buffer, the sooner
    /// partial results appear and the shorter the tail after release.
    private static let tapBufferDuration = 0.1

    var onHardwareChange: (@MainActor () -> Void)?

    private var engine: AVAudioEngine?
    private var format: AVAudioFormat?
    private var hardwareObserver: (any NSObjectProtocol)?
    private var isRunning = false

    init() {}

    func inputFormat() throws -> AVAudioFormat {
        // Read the microphone's format only at the moment of use. A format
        // with no sample rate or no channels is what a Mac with no input
        // device reports, and installing a tap with it raises an Objective-C
        // exception that Swift cannot catch.
        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw InterpreterError.noMicrophoneInput
        }
        self.engine = engine
        self.format = format
        return format
    }

    func start(block: @escaping AVAudioNodeTapBlock) throws {
        guard let engine, let format else {
            throw InterpreterError.noMicrophoneInput
        }
        engine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount((format.sampleRate * Self.tapBufferDuration).rounded()),
            format: format,
            block: block
        )
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            self.engine = nil
            throw InterpreterError.captureFailed(reason: error.localizedDescription)
        }
        isRunning = true

        // The engine stops itself when its hardware changes — a headset
        // plugged in, a different input selected.
        hardwareObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                self.onHardwareChange?()
            }
        }
    }

    func stop() {
        if let hardwareObserver {
            NotificationCenter.default.removeObserver(hardwareObserver)
            self.hardwareObserver = nil
        }
        guard let engine else { return }
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isRunning = false
        self.engine = nil
        format = nil
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class PushToTalkTranscriptionService: InterpreterTranscribing {

    /// Capture ended on its own: the audio hardware changed under it, or the
    /// recognizer failed while the button was still held. The message is
    /// ready to show.
    var onInterruption: (@MainActor (String) -> Void)?

    /// A recognizer that is loaded and has not been used. `SpeechAnalyzer`
    /// cannot be restarted once it has finished, so each turn consumes one.
    private struct Recognizer {
        let module: InterpreterSpeechModule
        let analyzer: SpeechAnalyzer
        let format: AVAudioFormat
    }

    /// One held press, from microphone open to transcript.
    @MainActor
    private final class Session {
        let id: Int
        let recognizer: Recognizer
        let capture: any InterpreterAudioCapturing
        let input: AsyncStream<AnalyzerInput>.Continuation
        let activity: TapActivity
        var onUpdate: (@MainActor (TranscriptSnapshot) -> Void)?
        var assembler = TranscriptAssembler()
        var resultsTask: Task<Void, Never>?
        /// Resolved when the results stream ends: `true` when it ended by
        /// itself, `false` when it failed or was torn down.
        let resultsEnded = InterpreterOneShot<Bool>()
        var failure: String?
        var isCapturing = true

        init(
            id: Int,
            recognizer: Recognizer,
            capture: any InterpreterAudioCapturing,
            input: AsyncStream<AnalyzerInput>.Continuation,
            activity: TapActivity,
            onUpdate: @escaping @MainActor (TranscriptSnapshot) -> Void
        ) {
            self.id = id
            self.recognizer = recognizer
            self.capture = capture
            self.input = input
            self.activity = activity
            self.onUpdate = onUpdate
        }
    }

    private let provisioner: SpeechModelProvisioner
    /// Makes the audio source for one turn. The microphone, except in the
    /// self-test.
    private let makeCapture: @MainActor () -> any InterpreterAudioCapturing
    private let log = Logger(subsystem: "com.rogerlin.SwiftMandarin", category: "Interpreter")

    private var prepared: [TranslationDirection: Recognizer] = [:]
    private var preparing: [TranslationDirection: Task<Void, Never>] = [:]
    private var session: Session?
    /// Goes up with every `begin` and `cancel`. A step that finds it changed
    /// after an `await` knows it has been superseded.
    private var generation = 0
    /// The microphone's own format on the last turn, a hint for choosing the
    /// recognizer's format on the next.
    private var lastInputFormat: AVAudioFormat?

    init(
        provisioner: SpeechModelProvisioner,
        makeCapture: @escaping @MainActor () -> any InterpreterAudioCapturing = { MicrophoneCapture() }
    ) {
        self.provisioner = provisioner
        self.makeCapture = makeCapture
    }

    private static func locale(for direction: TranslationDirection) -> Locale {
        Locale(identifier: direction.sourceSpeechCode)
    }

    // MARK: - Assets

    func assetState(for direction: TranslationDirection) async -> InterpreterAssetState {
        await provisioner.assetState(for: Self.locale(for: direction))
    }

    func installAssets(onProgress: @escaping @MainActor (Double?) -> Void) async throws {
        try await provisioner.install(
            locales: TranslationDirection.allCases.map(Self.locale(for:)),
            onProgress: onProgress
        )
    }

    // MARK: - Preparing

    func prepare(for direction: TranslationDirection) async {
        if prepared[direction] != nil { return }
        if let running = preparing[direction] {
            await running.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.preparing[direction] = nil }
            guard let recognizer = try? await self.makeRecognizer(for: direction) else { return }
            if self.prepared[direction] == nil {
                self.prepared[direction] = recognizer
            } else {
                await recognizer.analyzer.cancelAndFinishNow()
            }
        }
        preparing[direction] = task
        await task.value
    }

    private func takeRecognizer(for direction: TranslationDirection) async throws -> Recognizer {
        if let running = preparing[direction] {
            await running.value
        }
        if let ready = prepared.removeValue(forKey: direction) {
            return ready
        }
        return try await makeRecognizer(for: direction)
    }

    private func makeRecognizer(for direction: TranslationDirection) async throws -> Recognizer {
        let locale = Self.locale(for: direction)
        guard let module = await provisioner.makeModule(for: locale) else {
            throw InterpreterError.speechUnsupported(language: SpeechModelProvisioner.displayName(for: locale))
        }
        guard await AssetInventory.status(forModules: [module.module]) == .installed else {
            throw InterpreterError.speechAssetsMissing
        }

        // The model stays loaded for the life of the process, so the
        // recognizer built for the next turn starts without loading it
        // again. `releaseResources()` ends that when the screen closes.
        let analyzer = SpeechAnalyzer(
            modules: [module.module],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        )
        // No sample rate is assumed: the recognizer names the format it
        // wants, taking the microphone's own format into account once one
        // turn has shown what that is.
        let chosen: AVAudioFormat?
        if let natural = lastInputFormat {
            chosen = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [module.module],
                considering: AVAudioFormat(streamDescription: natural.streamDescription)
            )
        } else {
            chosen = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module.module])
        }
        guard let format = chosen else {
            throw InterpreterError.recognitionFailed(
                reason: String(localized: "The recognizer offered no audio format.", bundle: .appLanguage)
            )
        }
        do {
            try await analyzer.prepareToAnalyze(in: format)
        } catch {
            throw InterpreterError.recognitionFailed(reason: Self.describe(error))
        }
        return Recognizer(module: module, analyzer: analyzer, format: format)
    }

    // MARK: - One turn

    func begin(
        direction: TranslationDirection,
        onUpdate: @escaping @MainActor (TranscriptSnapshot) -> Void
    ) async throws {
        generation += 1
        let mine = generation
        // A turn that is still open is discarded, not merged.
        await tearDownSession()
        try checkCurrent(mine)

        let recognizer = try await takeRecognizer(for: direction)
        guard generation == mine else {
            putBack(recognizer, for: direction)
            throw CancellationError()
        }

        let capture = makeCapture()
        let inputFormat: AVAudioFormat
        do {
            inputFormat = try capture.inputFormat()
        } catch {
            putBack(recognizer, for: direction)
            throw error
        }

        var converter: AVAudioConverter?
        if inputFormat != recognizer.format {
            guard let made = AVAudioConverter(from: inputFormat, to: recognizer.format) else {
                putBack(recognizer, for: direction)
                throw InterpreterError.captureFailed(
                    reason: String(localized: "The microphone's audio format cannot be converted.", bundle: .appLanguage)
                )
            }
            converter = made
        }

        // The tap opens before the analyzer starts. Audio captured in
        // between waits in the stream, so nothing said right at the press is
        // lost.
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let activity = TapActivity()
        do {
            try capture.start(block: MicrophoneTap.makeBlock(
                converter: converter,
                targetFormat: recognizer.format,
                input: input,
                activity: activity
            ))
        } catch {
            capture.stop()
            input.finish()
            putBack(recognizer, for: direction)
            throw error
        }

        let newSession = Session(
            id: mine,
            recognizer: recognizer,
            capture: capture,
            input: input,
            activity: activity,
            onUpdate: onUpdate
        )
        session = newSession
        lastInputFormat = inputFormat
        newSession.resultsTask = startConsuming(recognizer.module, sessionID: mine)
        capture.onHardwareChange = { [weak self] in
            self?.audioHardwareChanged(sessionID: mine)
        }

        do {
            try await recognizer.analyzer.start(inputSequence: stream)
        } catch {
            let superseded = generation != mine
            if session === newSession {
                await tearDownSession()
            }
            if superseded { throw CancellationError() }
            throw InterpreterError.recognitionFailed(reason: Self.describe(error))
        }
        // `cancel()` may have arrived while the analyzer was starting; it has
        // already closed the microphone.
        try checkCurrent(mine)
    }

    func finish() async throws -> String {
        guard let current = session else { throw CancellationError() }
        let mine = generation

        // Audio captured just before the release is still inside the tap's
        // buffer. Wait for that buffer to be delivered, so the last syllable
        // is not cut off.
        await waitForTail(of: current)
        try checkCurrent(mine)

        stopCapture(of: current)

        let analyzer = current.recognizer.analyzer
        let resultsEnded = current.resultsEnded
        var timedOut = false
        do {
            try await withInterpreterDeadline(
                InterpreterTuning.finalizationTimeout,
                clock: SystemInterpreterClock(),
                timeoutError: .recognitionTimedOut
            ) {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
                // Not cancelled: the results stream ends by itself once the
                // analyzer has finished, and only then is every final word in.
                _ = await resultsEnded.wait()
            }
        } catch InterpreterError.recognitionTimedOut {
            timedOut = true
        } catch is CancellationError {
            abandon(current)
            closeIfCurrent(current)
            throw CancellationError()
        } catch {
            abandon(current)
            closeIfCurrent(current)
            try checkCurrent(mine)
            throw InterpreterError.recognitionFailed(reason: Self.describe(error))
        }

        if timedOut {
            // The recognizer never finished. Stop waiting on it, and use what
            // it had already said rather than losing the whole sentence.
            abandon(current)
        }
        closeIfCurrent(current)
        try checkCurrent(mine)

        if timedOut {
            log.error("The recognizer did not finish within the finalization deadline.")
            let partial = current.assembler.text
            guard !partial.isEmpty else { throw InterpreterError.recognitionTimedOut }
            return partial
        }
        if let failure = current.failure {
            throw InterpreterError.recognitionFailed(reason: failure)
        }
        return current.assembler.text
    }

    func cancel() async {
        generation += 1
        await tearDownSession()
    }

    func releaseResources() async {
        generation += 1
        await tearDownSession()
        for task in preparing.values {
            await task.value
        }
        let unused = Array(prepared.values)
        prepared.removeAll()
        for recognizer in unused {
            await recognizer.analyzer.cancelAndFinishNow()
        }
        await SpeechModels.endRetention()
    }

    // MARK: - Session plumbing

    private func checkCurrent(_ mine: Int) throws {
        guard generation == mine else { throw CancellationError() }
    }

    /// An unused recognizer goes back for the next press instead of being
    /// rebuilt.
    private func putBack(_ recognizer: Recognizer, for direction: TranslationDirection) {
        if prepared[direction] == nil {
            prepared[direction] = recognizer
        } else {
            let analyzer = recognizer.analyzer
            Task { await analyzer.cancelAndFinishNow() }
        }
    }

    /// Closes the microphone and ends the input stream. Synchronous, so the
    /// microphone is off by the time this returns. Idempotent.
    private func stopCapture(of target: Session) {
        guard target.isCapturing else { return }
        target.isCapturing = false
        target.capture.onHardwareChange = nil
        target.capture.stop()
        target.input.finish()
    }

    private func closeIfCurrent(_ target: Session) {
        if session === target {
            session = nil
        }
    }

    /// Stops waiting on a recognizer that did not finish cleanly: releases
    /// whatever is still waiting for its results to end, stops reading them,
    /// and tells the analyzer to stop. Without this the wait, and the
    /// analyzer it holds, would never be let go.
    private func abandon(_ target: Session) {
        target.resultsEnded.resolve(false)
        target.resultsTask?.cancel()
        let analyzer = target.recognizer.analyzer
        Task { await analyzer.cancelAndFinishNow() }
    }

    /// Discards the open turn, if there is one: microphone off, results
    /// ignored, recognizer told to stop without finishing its work.
    private func tearDownSession() async {
        guard let current = session else { return }
        session = nil
        stopCapture(of: current)
        current.onUpdate = nil
        current.resultsTask?.cancel()
        current.resultsEnded.resolve(false)
        await current.recognizer.analyzer.cancelAndFinishNow()
    }

    private func waitForTail(of target: Session) async {
        guard target.isCapturing else { return }
        let seen = target.activity.bufferCount
        let deadline = ContinuousClock.now.advanced(by: InterpreterTuning.releaseTail)
        while target.activity.bufferCount == seen, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Results

    private func startConsuming(_ module: InterpreterSpeechModule, sessionID: Int) -> Task<Void, Never> {
        let deliver: @MainActor @Sendable (RecognizerEvent) -> Void = { [weak self] event in
            self?.handle(event, sessionID: sessionID)
        }
        switch module {
        case .speech(let transcriber):
            return Self.consume(transcriber, text: { $0.text }, deliver: deliver)
        case .dictation(let transcriber):
            return Self.consume(transcriber, text: { $0.text }, deliver: deliver)
        }
    }

    /// Reads a recognizer's results in the stream's own task and passes each
    /// one to the main actor. Returns when the stream ends, which it does
    /// only after the analyzer has finished.
    nonisolated private static func consume<Module: SpeechModule>(
        _ module: Module,
        text: @escaping @Sendable (Module.Result) -> AttributedString,
        deliver: @escaping @MainActor @Sendable (RecognizerEvent) -> Void
    ) -> Task<Void, Never> {
        Task {
            do {
                for try await result in module.results {
                    await deliver(.result(
                        text: String(text(result).characters),
                        isFinal: result.isFinal,
                        start: result.range.start.seconds,
                        end: result.range.end.seconds
                    ))
                }
                await deliver(.finished)
            } catch is CancellationError {
                await deliver(.finished)
            } catch {
                await deliver(.failed(describe(error)))
            }
        }
    }

    private func handle(_ event: RecognizerEvent, sessionID: Int) {
        guard let current = session, current.id == sessionID else { return }
        switch event {
        case .result(let text, let isFinal, let start, let end):
            current.assembler.apply(text: text, isFinal: isFinal, start: start, end: end)
            current.onUpdate?(current.assembler.snapshot)
        case .finished:
            current.resultsEnded.resolve(true)
        case .failed(let reason):
            current.failure = reason
            current.resultsEnded.resolve(false)
            guard current.isCapturing else { return }
            // The recognizer failed while the button was still held. Close
            // the microphone now rather than at release.
            generation += 1
            let mine = generation
            let message = String.localizedStringWithFormat(
                String(localized: "Speech recognition stopped: %@", bundle: .appLanguage),
                reason
            )
            Task { [weak self] in
                await self?.tearDownSession()
                // A press that began in the meantime is not the one that failed.
                guard let self, self.generation == mine else { return }
                self.onInterruption?(message)
            }
        }
    }

    // MARK: - Hardware changes

    /// The audio hardware changed under a held press: a device was connected
    /// or removed, or its format changed. The engine has stopped itself and
    /// the tap's format no longer matches, so the turn cannot continue.
    private func audioHardwareChanged(sessionID: Int) {
        guard let current = session, current.id == sessionID, current.isCapturing else { return }
        generation += 1
        let mine = generation
        let message = String(localized: "The microphone changed while you were speaking. Hold the button and try again.", bundle: .appLanguage)
        Task { [weak self] in
            await self?.tearDownSession()
            // A press that began in the meantime is not the one that stopped.
            guard let self, self.generation == mine else { return }
            self.onInterruption?(message)
        }
    }

    /// Speech errors are opaque without their domain and code.
    nonisolated private static func describe(_ error: any Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))"
    }
}
