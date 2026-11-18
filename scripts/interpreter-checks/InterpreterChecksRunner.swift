#if INTERPRETER_CHECKS
import Foundation
import Observation

// Contract and scenario checks for the push-to-talk Interpreter.
//
// The transcript assembler is pure, and `SpeechTranslationCoordinator` talks
// only to protocols, so everything here runs without a microphone, a
// language pack or a speaker: the three stages are scripted stand-ins whose
// timing the checks control. Run through scripts/test-interpreter.sh.

/// Stand-in for the app's `AppLanguage` (LocalizationManager.swift), which
/// `TranslationDirection.persistedDefault` reads and which would otherwise
/// pull the app's observable preferences into this slice.
enum AppLanguage {
    case english
    case chinese

    static var persisted: AppLanguage { .english }
}

private struct CheckFailure: Error {
    let message: String
}

// Every check runs on the main actor, one after another.
@MainActor private var checksRun = 0

@MainActor
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    checksRun += 1
    guard condition() else { throw CheckFailure(message: message) }
}

// MARK: - Stand-ins

@MainActor
private final class FakeTranscriber: InterpreterTranscribing {
    var assetStates: [TranslationDirection: InterpreterAssetState] = [
        .englishToChinese: .ready, .chineseToEnglish: .ready,
    ]
    var installError: InterpreterError?
    var installProgress: [Double?] = [nil, 0.5, 1.0]
    /// When set, an installation waits here before it reports anything.
    var installGate: InterpreterOneShot<Bool>?
    var beginError: (any Error)?
    var finishError: (any Error)?
    var finalTranscript = "Where is the station?"
    /// When set, `begin` / `finish` wait here until the check opens the gate.
    var beginGate: InterpreterOneShot<Bool>?
    var finishGate: InterpreterOneShot<Bool>?
    /// When set, shutting the microphone waits here.
    var cancelGate: InterpreterOneShot<Bool>?

    private(set) var log: [String] = []
    private(set) var isCapturing = false
    private var onUpdate: (@MainActor (TranscriptSnapshot) -> Void)?
    private var generation = 0

    func assetState(for direction: TranslationDirection) async -> InterpreterAssetState {
        assetStates[direction] ?? .unknown
    }

    func installAssets(onProgress: @escaping @MainActor (Double?) -> Void) async throws {
        log.append("install")
        if let installGate { _ = await installGate.wait() }
        for step in installProgress {
            onProgress(step)
            await Task.yield()
        }
        if let installError { throw installError }
        for direction in TranslationDirection.allCases where assetStates[direction] == .needsDownload {
            assetStates[direction] = .ready
        }
    }

    func prepare(for direction: TranslationDirection) async {
        log.append("prepare \(direction.sourceSpeechCode)")
    }

    func begin(
        direction: TranslationDirection,
        onUpdate: @escaping @MainActor (TranscriptSnapshot) -> Void
    ) async throws {
        generation += 1
        let mine = generation
        log.append("begin \(direction.sourceSpeechCode)")
        if let beginGate { _ = await beginGate.wait() }
        guard generation == mine else { throw CancellationError() }
        if let beginError { throw beginError }
        isCapturing = true
        self.onUpdate = onUpdate
    }

    func emit(finalized: String = "", volatile: String = "") {
        onUpdate?(TranscriptSnapshot(finalized: finalized, volatile: volatile))
    }

    func finish() async throws -> String {
        let mine = generation
        log.append("finish")
        if let finishGate { _ = await finishGate.wait() }
        guard generation == mine else { throw CancellationError() }
        isCapturing = false
        onUpdate = nil
        if let finishError { throw finishError }
        return finalTranscript
    }

    func cancel() async {
        generation += 1
        log.append("cancel")
        if let cancelGate { _ = await cancelGate.wait() }
        isCapturing = false
        onUpdate = nil
        // A real cancel releases whatever is waiting on the recognizer.
        beginGate?.resolve(false)
        finishGate?.resolve(false)
    }

    func releaseResources() async {
        log.append("release")
    }
}

@MainActor
private final class FakeTranslator: InterpreterTranslating {
    var state: InterpreterAssetState = .ready
    var offersTwoModels = true
    /// Thrown by every translation, or only by `failingModel` when that is set.
    var error: (any Error)?
    var failingModel: InterpreterTranslationModel?
    var translations: [String: String] = [:]
    var gate: InterpreterOneShot<Bool>?
    private(set) var requests: [(text: String, direction: TranslationDirection, model: InterpreterTranslationModel)] = []
    /// Every warm-up, as "<source language> <model>".
    private(set) var warmed: [String] = []

    func assetState() async -> InterpreterAssetState { state }

    func warm(_ direction: TranslationDirection, model: InterpreterTranslationModel) async {
        warmed.append("\(direction.sourceSpeechCode) \(model.rawValue)")
    }

    func translate(
        _ text: String,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) async throws -> String {
        requests.append((text, direction, model))
        if let gate { _ = await gate.wait() }
        if let error, failingModel == nil || failingModel == model { throw error }
        return translations[text] ?? "<\(direction.targetSpeechCode)> \(text)"
    }
}

@MainActor
private final class FakeSpeaker: InterpreterSpeaking {
    var error: (any Error)?
    /// When true, speech keeps "playing" until `finishPlayback()` or `stop()`.
    var holdsPlayback = false
    /// The voice that reports having started, when it is not the one asked
    /// for: a MiniMax request that fell back to the system voice.
    var startsWith: SpeechVoiceEngine?
    private(set) var spoken: [(text: String, languageCode: String, engine: SpeechVoiceEngine)] = []
    private(set) var stopCount = 0
    private var playback: InterpreterOneShot<Bool>?

    var isPlaying: Bool { playback != nil }

    func speak(
        _ text: String,
        languageCode: String,
        engine: SpeechVoiceEngine,
        onStart: @escaping @MainActor (SpeechVoiceEngine) -> Void
    ) async throws {
        spoken.append((text, languageCode, engine))
        if let error { throw error }
        onStart(startsWith ?? engine)
        guard holdsPlayback else { return }
        let playback = InterpreterOneShot<Bool>()
        self.playback = playback
        let finished = await playback.wait()
        if self.playback === playback { self.playback = nil }
        if !finished { throw CancellationError() }
    }

    func finishPlayback() {
        let current = playback
        playback = nil
        current?.resolve(true)
    }

    func stop() {
        stopCount += 1
        // Silent as soon as this returns, like the real synthesizer.
        let current = playback
        playback = nil
        current?.resolve(false)
    }
}

@MainActor
private final class FakeEnvironment: InterpreterEnvironment {
    var microphonePermission: InterpreterPermissionState = .granted
    var permissionAnswer = true
    var beginAudioError: (any Error)?
    /// When set, opening the audio session waits here.
    var beginAudioGate: InterpreterOneShot<Bool>?
    var voiceEngine: SpeechVoiceEngine = .system
    var translationQuality: InterpreterTranslationQuality = .natural

    private(set) var permissionRequests = 0
    private(set) var stopOtherAudioCount = 0
    private(set) var beginAudioCount = 0
    private(set) var endAudioCount = 0
    /// Every request to hold the audio session ("hold") or to give it back
    /// ("give back"), in the order it was made.
    private(set) var audioRequests: [String] = []
    private(set) var history: [(source: String, translation: String, direction: TranslationDirection)] = []

    /// Whether the session is held once everything asked for has been done.
    /// The app's audio-session coordinator carries requests out in the order
    /// they are made, however long each takes, so the last one decides.
    var holdsAudioOnceSettled: Bool { audioRequests.last == "hold" }

    func requestMicrophonePermission() async -> Bool {
        permissionRequests += 1
        microphonePermission = permissionAnswer ? .granted : .denied
        return permissionAnswer
    }

    func stopOtherAudio() async { stopOtherAudioCount += 1 }

    func beginConversationAudio() async throws {
        audioRequests.append("hold")
        if let beginAudioGate { _ = await beginAudioGate.wait() }
        if let beginAudioError {
            // A request that failed holds nothing.
            audioRequests.append("give back")
            throw beginAudioError
        }
        beginAudioCount += 1
    }

    func endConversationAudio() {
        audioRequests.append("give back")
        endAudioCount += 1
    }

    func record(source: String, translation: String, direction: TranslationDirection) {
        history.append((source, translation, direction))
    }
}

/// A clock that only moves when a check says so.
private final class ManualClock: InterpreterClock, @unchecked Sendable {
    private struct Sleeper {
        let id: UUID
        let wakeAt: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private let origin = ContinuousClock.now
    private var elapsed: Duration = .zero
    private var sleepers: [Sleeper] = []

    var now: ContinuousClock.Instant {
        lock.withLock { origin.advanced(by: elapsed) }
    }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let alreadyCancelled = lock.withLock { () -> Bool in
                    if Task.isCancelled { return true }
                    sleepers.append(Sleeper(id: id, wakeAt: elapsed + duration, continuation: continuation))
                    return false
                }
                if alreadyCancelled { continuation.resume(throwing: CancellationError()) }
            }
        } onCancel: {
            let cancelled = lock.withLock { () -> Sleeper? in
                guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return sleepers.remove(at: index)
            }
            cancelled?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let due = lock.withLock { () -> [Sleeper] in
            elapsed += duration
            let ready = sleepers.filter { $0.wakeAt <= elapsed }
            sleepers.removeAll { $0.wakeAt <= elapsed }
            return ready
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }
}

@MainActor
private struct Harness {
    let transcriber = FakeTranscriber()
    let translator = FakeTranslator()
    let speaker = FakeSpeaker()
    let environment = FakeEnvironment()
    let clock = ManualClock()
    let coordinator: SpeechTranslationCoordinator

    init() {
        coordinator = SpeechTranslationCoordinator(
            transcriber: transcriber,
            translator: translator,
            speaker: speaker,
            environment: environment,
            clock: clock
        )
    }

    /// Opens the screen and lets the readiness check and warm-up run.
    func activate() async {
        coordinator.activate()
        await settle()
    }

    /// Lets every task that is ready to run do so, until all of them are
    /// either finished or parked on a gate a check has closed. Everything in
    /// this slice runs on the main actor and nothing waits on real time, so a
    /// fixed number of yields drains the queue deterministically.
    func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    func yield() async {
        await settle()
    }

    /// One complete turn: press, hold for `held`, release, wait for the reply.
    /// Returns the press, for a check that goes on to release it again.
    @discardableResult
    func turn(_ direction: TranslationDirection, held: Duration = .seconds(1)) async -> InterpreterPress? {
        let press = coordinator.pressDown(direction)
        await settle()
        clock.advance(by: held)
        coordinator.pressUp()
        await settle()
        return press
    }

    /// An input going down, for a check that needs the press to be taken.
    func press(_ direction: TranslationDirection) throws -> InterpreterPress {
        guard let press = coordinator.pressDown(direction) else {
            throw CheckFailure(message: "The press for \(direction.sourceSpeechCode) was not taken: \(coordinator.state)")
        }
        return press
    }
}

// MARK: - Transcript assembler

@MainActor
private func runAssemblerChecks() throws {
    // The exact sequence measured from SpeechTranscriber with fast results.
    var english = TranscriptAssembler()
    english.apply(text: "Where", isFinal: false, start: 0, end: 1.1)
    english.apply(text: "Where is", isFinal: false, start: 0, end: 1.1)
    english.apply(text: "Where is the nearest", isFinal: false, start: 0, end: 1.1)
    try expect(english.snapshot == TranscriptSnapshot(finalized: "", volatile: "Where is the nearest"),
               "A volatile result replaces the one before it: \(english.snapshot)")
    english.apply(text: "Where is the nearest train station?", isFinal: false, start: 0, end: 3.0)
    english.apply(text: "Where is the nearest train station?", isFinal: true, start: 0, end: 2.04)
    try expect(english.snapshot == TranscriptSnapshot(finalized: "Where is the nearest train station?", volatile: ""),
               "A final result replaces the guess for its stretch: \(english.snapshot)")
    english.apply(text: " I", isFinal: false, start: 2.04, end: 3.1)
    english.apply(text: " I need to buy", isFinal: false, start: 2.04, end: 3.1)
    try expect(english.snapshot.finalized == "Where is the nearest train station?" && english.snapshot.volatile == "I need to buy",
               "The tail after a final is kept apart from it: \(english.snapshot)")
    try expect(english.text == "Where is the nearest train station? I need to buy",
               "Finalized text and the tail join with the segment's own space: \(english.text)")
    english.apply(text: " I need to buy 2 tickets to Shanghai.", isFinal: true, start: 2.04, end: 4.4)
    try expect(english.text == "Where is the nearest train station? I need to buy 2 tickets to Shanghai.",
               "Two finalized segments read as one transcript: \(english.text)")
    try expect(english.snapshot.volatile.isEmpty, "Nothing is volatile after the last final")

    // The final's range is not exactly the volatile range it replaces.
    var drift = TranscriptAssembler()
    drift.apply(text: "Hello there.", isFinal: true, start: 0, end: 1.86)
    drift.apply(text: " How are", isFinal: false, start: 1.86, end: 4.4)
    drift.apply(text: " How are you?", isFinal: true, start: 1.92, end: 4.38)
    try expect(drift.text == "Hello there. How are you?" && drift.snapshot.volatile.isEmpty,
               "A final whose range differs slightly still clears the tail: \(drift.snapshot)")

    // A repeated final for the same stretch replaces it instead of doubling it.
    var repeated = TranscriptAssembler()
    repeated.apply(text: "Good morning.", isFinal: true, start: 0, end: 1.2)
    repeated.apply(text: "Good morning!", isFinal: true, start: 0.05, end: 1.2)
    try expect(repeated.text == "Good morning!", "A second final for one stretch replaces the first: \(repeated.text)")

    // A late guess about audio that is already final is ignored.
    var stale = TranscriptAssembler()
    stale.apply(text: "One two three.", isFinal: true, start: 0, end: 2.0)
    stale.apply(text: "One two", isFinal: false, start: 0, end: 1.5)
    try expect(stale.snapshot.volatile.isEmpty && stale.text == "One two three.",
               "A stale volatile result does not come back: \(stale.snapshot)")

    // Finals that arrive out of order are put back in spoken order.
    var reordered = TranscriptAssembler()
    reordered.apply(text: " second.", isFinal: true, start: 2.0, end: 3.0)
    reordered.apply(text: "First,", isFinal: true, start: 0, end: 1.9)
    try expect(reordered.text == "First, second.", "Finalized segments are kept in time order: \(reordered.text)")

    // Chinese: the recognizer's stray space before punctuation is removed,
    // and nothing is inserted between segments.
    var chinese = TranscriptAssembler()
    chinese.apply(text: "请问最近的火车站在哪里 ？", isFinal: false, start: 0, end: 3.0)
    try expect(chinese.snapshot.volatile == "请问最近的火车站在哪里？", "A space before Chinese punctuation is removed: \(chinese.snapshot.volatile)")
    chinese.apply(text: "请问最近的火车站在哪里 ？", isFinal: true, start: 0, end: 3.0)
    chinese.apply(text: "我想买两张去上海的票。", isFinal: true, start: 3.0, end: 5.08)
    try expect(chinese.text == "请问最近的火车站在哪里？我想买两张去上海的票。",
               "Chinese segments join without a space: \(chinese.text)")

    try expect(TranscriptAssembler.normalize("你 好 ， 世界") == "你好，世界", "Spaces between Chinese characters are removed")
    try expect(TranscriptAssembler.normalize("我用 iPhone 拍照") == "我用 iPhone 拍照", "A space between Chinese and a Latin word is kept")
    try expect(TranscriptAssembler.normalize("  Hello   world \n again ") == "Hello world again", "English whitespace is collapsed and trimmed")
    try expect(TranscriptAssembler.normalize("") == "" && TranscriptAssembler.normalize(" \n ") == "", "Whitespace alone is an empty transcript")
    try expect(TranscriptAssembler.join("Where is it?", "I need") == "Where is it? I need", "A missing space between English pieces is supplied")
    try expect(TranscriptAssembler.join("Hello", ", world") == "Hello, world", "No space is put before closing punctuation")
    try expect(TranscriptAssembler.join("你好。", "再见") == "你好。再见", "No space is put between Chinese pieces")
    try expect(TranscriptAssembler.join("", " Hi") == "Hi" && TranscriptAssembler.join("Hi ", "") == "Hi", "An empty side adds nothing")

    // Results without a usable range still assemble, in arrival order.
    var rangeless = TranscriptAssembler()
    rangeless.apply(text: "Hello", isFinal: false)
    rangeless.apply(text: "Hello there", isFinal: false, start: .nan, end: .infinity)
    rangeless.apply(text: "Hello there.", isFinal: true)
    rangeless.apply(text: " Bye", isFinal: false)
    try expect(rangeless.text == "Hello there. Bye", "Results without ranges assemble in arrival order: \(rangeless.text)")

    // After a timeout the tail is still part of the transcript.
    var unfinished = TranscriptAssembler()
    unfinished.apply(text: "I would like", isFinal: true, start: 0, end: 1)
    unfinished.apply(text: " a coffee", isFinal: false, start: 1, end: 2)
    try expect(unfinished.text == "I would like a coffee" && !unfinished.isEmpty, "An unfinished tail is kept rather than dropped")
    unfinished.reset()
    try expect(unfinished.isEmpty && unfinished.snapshot == TranscriptSnapshot(), "Reset empties the assembler")

    // A first word shorter than the boundary tolerance is still its own
    // stretch: the sentence that begins where it ends does not replace it.
    var brief = TranscriptAssembler()
    brief.apply(text: "Hi.", isFinal: true, start: 0, end: 0.24)
    brief.apply(text: " How are you?", isFinal: true, start: 0.24, end: 1.2)
    try expect(brief.text == "Hi. How are you?", "A quarter-second final is not overwritten by the one after it: \(brief.text)")
    // A second report of the same short stretch still replaces the first.
    brief.apply(text: "Hi!", isFinal: true, start: 0.02, end: 0.24)
    try expect(brief.text == "Hi! How are you?", "A repeated final for a short stretch replaces it: \(brief.text)")

    // A short final clears the guess it replaces, and a late guess about it
    // is ignored.
    var parting = TranscriptAssembler()
    parting.apply(text: "See you tomorrow.", isFinal: true, start: 0, end: 3.0)
    parting.apply(text: " Bye", isFinal: false, start: 3.0, end: 3.2)
    parting.apply(text: " Bye.", isFinal: true, start: 3.0, end: 3.2)
    try expect(parting.text == "See you tomorrow. Bye." && parting.snapshot.volatile.isEmpty, "A short final clears its own guess: \(parting.text)")
    parting.apply(text: " Bye", isFinal: false, start: 3.0, end: 3.2)
    try expect(parting.text == "See you tomorrow. Bye.", "A late guess about a short finalized stretch is ignored: \(parting.text)")
    // A guess about what follows a short final is kept.
    parting.apply(text: " Take", isFinal: false, start: 3.2, end: 3.6)
    try expect(parting.snapshot.volatile == "Take" && parting.text == "See you tomorrow. Bye. Take", "A guess that begins where a short final ends is kept: \(parting.text)")
}

// MARK: - Coordinator scenarios

@MainActor
private func runTurnChecks() async throws {
    // English to Chinese, start to finish.
    let h = Harness()
    try expect(h.coordinator.state == .idle && !h.coordinator.canStartTurn, "Nothing can start before the screen is active")
    await h.activate()
    try expect(h.coordinator.readiness.assetsAreUsable && h.coordinator.canStartTurn, "An active screen with every asset can start a turn")
    try expect(h.transcriber.log == ["prepare en-US", "prepare zh-CN"] && h.translator.warmed == ["en-US natural", "zh-CN natural"],
               "Opening the screen loads both recognizers and the translation model, each way: \(h.transcriber.log) \(h.translator.warmed)")
    try expect(h.environment.beginAudioCount == 1, "Opening the screen configures the audio session once")

    h.translator.translations["Where is the station?"] = "车站在哪里？"
    h.coordinator.pressDown(.englishToChinese)
    try expect(h.coordinator.state == .listening(direction: .englishToChinese, liveTranscript: ""), "A press starts listening at once")
    try expect(!h.coordinator.isMicrophoneLive, "The microphone is not reported live before it is")
    await h.settle()
    try expect(h.coordinator.isMicrophoneLive && h.transcriber.isCapturing, "The microphone goes live once capture has begun")
    try expect(h.environment.stopOtherAudioCount == 1, "Other audio features are stopped before capture")

    h.transcriber.emit(volatile: "Where is")
    try expect(h.coordinator.state == .listening(direction: .englishToChinese, liveTranscript: "Where is"), "The live transcript reaches the state")
    h.transcriber.emit(finalized: "Where is the station?", volatile: "")
    try expect(h.coordinator.liveTranscript.finalized == "Where is the station?", "Finalized text is kept apart for display")

    h.clock.advance(by: .seconds(2))
    h.coordinator.pressUp()
    try expect(!h.coordinator.isMicrophoneLive, "Release ends the live look immediately")
    await h.settle()

    try expect(h.coordinator.state == .idle, "The turn ends idle: \(h.coordinator.state)")
    try expect(h.coordinator.turns.count == 1, "One turn is recorded")
    let turn = h.coordinator.turns[0]
    try expect(turn.sourceText == "Where is the station?" && turn.translatedText == "车站在哪里？" && turn.direction == .englishToChinese,
               "The turn holds the transcript and its translation")
    try expect(h.speaker.spoken.count == 1 && h.speaker.spoken[0].text == "车站在哪里？" && h.speaker.spoken[0].languageCode == "zh-CN",
               "English is answered in Mandarin: \(h.speaker.spoken)")
    try expect(h.translator.requests.count == 1 && h.translator.requests[0].direction == .englishToChinese, "The translation runs English to Chinese")
    try expect(h.environment.history.count == 1 && h.environment.history[0].translation == "车站在哪里？", "The turn is offered to history")
    try expect(h.transcriber.log.suffix(3) == ["begin en-US", "finish", "prepare en-US"],
               "Capture uses the English recognizer and reloads it for the next turn: \(h.transcriber.log)")
    try expect(turn.timings.held == 2_000, "The hold is timed: \(turn.timings)")
    try expect(h.coordinator.speakingTurnID == nil && h.coordinator.liveTranscript.isEmpty, "Nothing is left over after the reply")

    // Chinese to English uses the other recognizer and the other voice.
    h.transcriber.finalTranscript = "请问洗手间在哪里"
    h.translator.translations["请问洗手间在哪里"] = "Where is the restroom?"
    await h.turn(.chineseToEnglish)
    try expect(h.coordinator.turns.count == 2 && h.coordinator.turns[1].direction == .chineseToEnglish, "The second turn is recorded")
    try expect(h.speaker.spoken[1].languageCode == "en-US" && h.speaker.spoken[1].text == "Where is the restroom?", "Mandarin is answered in English")
    try expect(h.transcriber.log.contains("begin zh-CN"), "The Mandarin button listens in Mandarin")
    try expect(h.environment.beginAudioCount >= 1 && h.environment.endAudioCount == 0, "The audio session stays open between turns")
}

@MainActor
private func runStageChecks() async throws {
    // Each stage is visible while it runs.
    let h = Harness()
    await h.activate()
    h.transcriber.finishGate = InterpreterOneShot()
    h.translator.gate = InterpreterOneShot()
    h.speaker.holdsPlayback = true

    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    h.clock.advance(by: .milliseconds(40))
    h.clock.advance(by: .seconds(1))
    h.coordinator.pressUp()
    await h.yield()
    try expect(h.coordinator.state == .finalizingTranscript, "After release the recognizer is finishing: \(h.coordinator.state)")

    h.clock.advance(by: .milliseconds(120))
    h.transcriber.finishGate?.resolve(true)
    await h.yield()
    try expect(h.coordinator.state == .translating(sourceText: "Where is the station?"), "Then the transcript is translated: \(h.coordinator.state)")
    try expect(h.coordinator.liveTranscript.finalized == "Where is the station?", "The final transcript stays on screen while translating")
    try expect(h.coordinator.turns.isEmpty, "No turn is recorded before its translation exists")

    h.clock.advance(by: .milliseconds(30))
    h.translator.gate?.resolve(true)
    await h.yield()
    let expected = "<zh-CN> Where is the station?"
    try expect(h.coordinator.state == .speaking(sourceText: "Where is the station?", translatedText: expected), "Then it is spoken: \(h.coordinator.state)")
    try expect(h.coordinator.turns.count == 1 && h.coordinator.speakingTurnID == h.coordinator.turns[0].id, "The spoken turn is identified")
    let timings = h.coordinator.turns[0].timings
    try expect(timings.releaseToTranscript == 120 && timings.transcriptToTranslation == 30, "Stage timings are recorded: \(timings)")
    try expect(timings.translationToSpeech == 0 && timings.releaseToSpeech == 150, "The listener's wait is recorded: \(timings)")

    try expect(h.coordinator.activeDirection == .englishToChinese, "The turn's direction is known for as long as it runs")
    h.speaker.finishPlayback()
    await h.settle()
    try expect(h.coordinator.state == .idle && h.coordinator.speakingTurnID == nil, "The reply ends idle")
    try expect(h.coordinator.activeDirection == nil, "No direction is active once the turn is over")

    // The time from press to a live microphone is measured.
    let slow = Harness()
    await slow.activate()
    slow.transcriber.beginGate = InterpreterOneShot()
    slow.coordinator.pressDown(.englishToChinese)
    await slow.yield()
    slow.clock.advance(by: .milliseconds(70))
    slow.transcriber.beginGate?.resolve(true)
    await slow.settle()
    slow.clock.advance(by: .seconds(1))
    slow.coordinator.pressUp()
    await slow.settle()
    try expect(slow.coordinator.turns.first?.timings.pressToLive == 70, "Press to live is timed: \(String(describing: slow.coordinator.turns.first?.timings))")
}

@MainActor
private func runShortAndEmptyChecks() async throws {
    // A press shorter than a deliberate hold says nothing.
    let h = Harness()
    await h.activate()
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    h.clock.advance(by: .milliseconds(249))
    h.coordinator.pressUp()
    await h.settle()
    try expect(h.coordinator.state == .idle && h.coordinator.hint == .holdToSpeak, "A 249 ms press is a slip: \(h.coordinator.state)")
    try expect(h.translator.requests.isEmpty && h.speaker.spoken.isEmpty && h.coordinator.turns.isEmpty, "A slip is neither translated nor spoken")
    try expect(h.transcriber.log.suffix(3) == ["begin en-US", "cancel", "prepare en-US"] && !h.transcriber.isCapturing,
               "A slip closes the microphone without finalizing, and the next recognizer is loaded: \(h.transcriber.log)")
    h.clock.advance(by: .seconds(3))
    await h.yield()
    try expect(h.coordinator.hint == nil, "The hint clears by itself")

    // Exactly the minimum is a turn.
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    h.clock.advance(by: .milliseconds(250))
    h.coordinator.pressUp()
    await h.settle()
    try expect(h.coordinator.turns.count == 1 && h.speaker.spoken.count == 1, "A 250 ms press is a turn")

    // Released before the microphone was even live.
    let early = Harness()
    await early.activate()
    early.transcriber.beginGate = InterpreterOneShot()
    early.coordinator.pressDown(.englishToChinese)
    await early.yield()
    early.clock.advance(by: .milliseconds(100))
    early.coordinator.pressUp()
    await early.yield()
    try expect(early.coordinator.state == .listening(direction: .englishToChinese, liveTranscript: ""), "A release waits for the start to settle")
    early.transcriber.beginGate?.resolve(true)
    await early.settle()
    try expect(early.coordinator.state == .idle && early.coordinator.hint == .holdToSpeak && !early.transcriber.isCapturing,
               "A short press released during start-up still closes the microphone")
    try expect(early.translator.requests.isEmpty, "…and translates nothing")

    // Held, but nothing was recognized.
    let silent = Harness()
    await silent.activate()
    silent.transcriber.finalTranscript = "  \n "
    await silent.turn(.chineseToEnglish)
    try expect(silent.coordinator.state == .idle && silent.coordinator.hint == .nothingHeard, "An empty transcript is not an error")
    try expect(silent.translator.requests.isEmpty && silent.speaker.spoken.isEmpty && silent.coordinator.turns.isEmpty, "An empty transcript is neither translated nor spoken")

    // A new press clears the hint.
    silent.coordinator.pressDown(.chineseToEnglish)
    try expect(silent.coordinator.hint == nil, "A new press clears the hint")
}

@MainActor
private func runInterruptionChecks() async throws {
    // A press during the reply stops it and listens.
    let h = Harness()
    await h.activate()
    h.speaker.holdsPlayback = true
    await h.turn(.englishToChinese)
    try expect(h.speaker.isPlaying, "The reply is playing")
    let stopsBefore = h.speaker.stopCount
    h.coordinator.pressDown(.chineseToEnglish)
    try expect(h.speaker.stopCount == stopsBefore + 1 && !h.speaker.isPlaying, "A press stops the reply at once")
    try expect(h.coordinator.state == .listening(direction: .chineseToEnglish, liveTranscript: ""), "…and starts listening")
    await h.settle()
    try expect(h.coordinator.state.isListening && h.transcriber.isCapturing, "The interrupted reply does not disturb the new turn: \(h.coordinator.state)")
    try expect(h.coordinator.turns.count == 1, "The interrupted turn stays in the conversation")
    h.speaker.holdsPlayback = false
    h.clock.advance(by: .seconds(1))
    h.coordinator.pressUp()
    await h.settle()
    try expect(h.coordinator.turns.count == 2 && h.coordinator.state == .idle, "The new turn completes")

    // A press while the previous turn is still being translated.
    let t = Harness()
    await t.activate()
    t.translator.gate = InterpreterOneShot()
    await t.turn(.englishToChinese)
    try expect(t.coordinator.state == .translating(sourceText: "Where is the station?"), "The first turn is waiting on its translation")
    t.coordinator.pressDown(.chineseToEnglish)
    await t.settle()
    try expect(t.coordinator.state.isListening, "The new press takes the microphone")
    t.translator.gate?.resolve(true)
    await t.yield()
    try expect(t.coordinator.turns.count == 1 && t.coordinator.turns[0].sourceText == "Where is the station?", "The overtaken turn is still recorded as text")
    try expect(t.speaker.spoken.isEmpty, "…but it is never spoken")
    try expect(t.coordinator.state.isListening && t.coordinator.speakingTurnID == nil, "…and it does not disturb the new turn: \(t.coordinator.state)")

    // A press while the recognizer is still finishing the previous turn
    // waits for those words instead of throwing them away.
    let f = Harness()
    await f.activate()
    f.transcriber.finishGate = InterpreterOneShot()
    await f.turn(.englishToChinese)
    try expect(f.coordinator.state == .finalizingTranscript, "The first turn is finalizing")
    let fWaiting = try f.press(.chineseToEnglish)
    await f.settle()
    try expect(f.coordinator.state == .finalizingTranscript && f.coordinator.pendingPressDirection == .chineseToEnglish,
               "A press during finalizing waits: \(f.coordinator.state)")
    try expect(!f.transcriber.log.contains("cancel") && !f.transcriber.log.contains("begin zh-CN"),
               "…and does not take the microphone from the words being finalized: \(f.transcriber.log)")
    let finishing = f.transcriber.finishGate
    f.transcriber.finishGate = nil
    finishing?.resolve(true)
    await f.settle()
    try expect(f.coordinator.state == .listening(direction: .chineseToEnglish, liveTranscript: "") && f.coordinator.pendingPressDirection == nil,
               "The waiting press starts once the transcript is in: \(f.coordinator.state)")
    try expect(f.transcriber.log.contains("begin zh-CN") && !f.transcriber.log.contains("cancel") && f.transcriber.isCapturing,
               "…with the microphone, and without a teardown: \(f.transcriber.log)")
    try expect(f.coordinator.turns.count == 1 && f.coordinator.turns[0].sourceText == "Where is the station?" && f.translator.requests.count == 1,
               "The words that were being finalized are translated and kept: \(f.coordinator.turns.count)")
    try expect(f.speaker.spoken.isEmpty, "…but not spoken over the person now speaking")
    f.transcriber.finalTranscript = "请问洗手间在哪里"
    f.clock.advance(by: .seconds(1))
    f.coordinator.pressUp(fWaiting)
    await f.settle()
    try expect(f.coordinator.turns.count == 2 && f.speaker.spoken.count == 1 && f.speaker.spoken[0].languageCode == "en-US" && f.coordinator.state == .idle,
               "The waiting press completes as an ordinary turn: \(f.coordinator.state)")

    // A waiting press whose button comes up before its turn began is forgotten.
    let g = Harness()
    await g.activate()
    g.transcriber.finishGate = InterpreterOneShot()
    guard let gFirst = await g.turn(.englishToChinese) else {
        throw CheckFailure(message: "The first press was not taken: \(g.coordinator.state)")
    }
    let gWaiting = try g.press(.chineseToEnglish)
    g.coordinator.pressUp(gFirst)
    try expect(g.coordinator.pendingPressDirection == .chineseToEnglish, "Another press's release does not cancel a waiting press")
    g.coordinator.pressUp(gWaiting)
    try expect(g.coordinator.pendingPressDirection == nil && g.coordinator.state == .finalizingTranscript, "Its own release does")
    let gGate = g.transcriber.finishGate
    g.transcriber.finishGate = nil
    gGate?.resolve(true)
    await g.settle()
    try expect(g.coordinator.state == .idle && g.speaker.spoken.count == 1 && !g.transcriber.log.contains("begin zh-CN"),
               "The first turn then completes and is spoken as usual: \(g.coordinator.state)")

    // A slip followed at once by a real hold: the hold starts when the slip
    // has been dismissed, instead of being swallowed with it.
    let q = Harness()
    await q.activate()
    q.transcriber.beginGate = InterpreterOneShot()
    let qSlip = try q.press(.englishToChinese)
    await q.yield()
    q.clock.advance(by: .milliseconds(80))
    q.coordinator.pressUp(qSlip)
    let qHold = try q.press(.englishToChinese)
    try expect(q.coordinator.pendingPressDirection == .englishToChinese, "A press that follows a release at once waits for the first press to settle")
    let qGate = q.transcriber.beginGate
    q.transcriber.beginGate = nil
    qGate?.resolve(true)
    await q.settle()
    try expect(q.coordinator.state.isListening && q.coordinator.hint == nil && q.transcriber.isCapturing,
               "The hold starts when the slip has been dismissed: \(q.coordinator.state)")
    try expect(q.transcriber.log.filter { $0 == "begin en-US" }.count == 2 && q.transcriber.log.contains("cancel"),
               "…on a microphone opened for it, after the slip's was closed: \(q.transcriber.log)")
    q.clock.advance(by: .seconds(1))
    q.coordinator.pressUp(qSlip)
    try expect(q.coordinator.state.isListening && q.coordinator.isMicrophoneLive, "A second release of the slip does not end the hold")
    q.coordinator.pressUp(qHold)
    await q.settle()
    try expect(q.coordinator.turns.count == 1 && q.speaker.spoken.count == 1, "…and completes as a turn")

    // Losing focus forgets a waiting press as well as a recording one.
    let w = Harness()
    await w.activate()
    w.transcriber.finishGate = InterpreterOneShot()
    await w.turn(.englishToChinese)
    w.coordinator.pressDown(.chineseToEnglish)
    w.coordinator.sceneBecameInactive()
    try expect(w.coordinator.pendingPressDirection == nil, "Losing focus forgets a waiting press")
    let wGate = w.transcriber.finishGate
    w.transcriber.finishGate = nil
    wGate?.resolve(true)
    await w.settle()
    try expect(!w.transcriber.log.contains("begin zh-CN") && w.coordinator.turns.count == 1 && w.speaker.spoken.count == 1,
               "…so nothing starts by itself, and the first turn is unaffected: \(w.transcriber.log)")

    // A release ends the press it belongs to and no other. Here one input's
    // press is ended from outside while the input stays down, and a second
    // input then presses the same button.
    let one = Harness()
    await one.activate()
    let oneEarlier = try one.press(.englishToChinese)
    await one.settle()
    one.coordinator.sceneBecameInactive()
    await one.settle()
    let oneHeld = try one.press(.englishToChinese)
    await one.settle()
    try expect(one.coordinator.pressDown(.englishToChinese) == nil && one.coordinator.pressDown(.chineseToEnglish) == nil,
               "While a press is held, another input's press is not taken for either button, so it has nothing to release")
    one.coordinator.pressUp(oneEarlier)
    try expect(one.coordinator.state.isListening && one.coordinator.isMicrophoneLive,
               "The release of a press that was ended earlier does not end the one now held: \(one.coordinator.state)")
    one.clock.advance(by: .seconds(1))
    one.coordinator.pressUp(oneHeld)
    await one.settle()
    try expect(one.coordinator.turns.count == 1 && one.coordinator.state == .idle, "Its own release does")

    // A screen that closes while one of its inputs is down gives up that
    // press, and only that one: another Interpreter window is still open.
    let gone = Harness()
    await gone.activate()
    gone.coordinator.activate()
    let goneMine = try gone.press(.englishToChinese)
    await gone.settle()
    gone.coordinator.cancelPress(goneMine)
    gone.coordinator.deactivate()
    try expect(gone.coordinator.state == .idle && !gone.coordinator.isMicrophoneLive && gone.coordinator.isActive,
               "A press whose screen closed is given up, and the other screen stays open: \(gone.coordinator.state)")
    await gone.settle()
    try expect(!gone.transcriber.isCapturing && gone.translator.requests.isEmpty && gone.speaker.spoken.isEmpty,
               "…its microphone is shut, and nothing is translated or spoken: \(gone.transcriber.log)")
    let goneTheirs = try gone.press(.chineseToEnglish)
    await gone.settle()
    gone.coordinator.cancelPress(goneMine)
    try expect(gone.coordinator.state.isListening && gone.coordinator.isMicrophoneLive, "Giving up a press that is already over does not end the one now held")
    gone.clock.advance(by: .seconds(1))
    gone.transcriber.finishGate = InterpreterOneShot()
    gone.coordinator.pressUp(goneTheirs)
    await gone.settle()
    let goneWaiting = try gone.press(.englishToChinese)
    gone.coordinator.cancelPress(goneWaiting)
    try expect(gone.coordinator.pendingPressDirection == nil && gone.coordinator.state == .finalizingTranscript,
               "A waiting press whose screen closed is forgotten, and the words being finalized are left alone: \(gone.coordinator.state)")
    let goneGate = gone.transcriber.finishGate
    gone.transcriber.finishGate = nil
    goneGate?.resolve(true)
    await gone.settle()
    try expect(gone.coordinator.turns.count == 1 && gone.speaker.spoken.count == 1 && gone.coordinator.state == .idle,
               "…and are translated and spoken as usual: \(gone.coordinator.state)")

    // While one button is held, the other does nothing.
    let b = Harness()
    await b.activate()
    b.coordinator.pressDown(.englishToChinese)
    b.coordinator.pressDown(.chineseToEnglish)
    await b.settle()
    try expect(b.coordinator.state == .listening(direction: .englishToChinese, liveTranscript: ""), "The first button keeps the microphone")
    try expect(b.transcriber.log.filter { $0.hasPrefix("begin") } == ["begin en-US"], "Only one capture starts")

    // Losing focus mid-press closes the microphone and says nothing.
    b.coordinator.sceneBecameInactive()
    try expect(b.coordinator.state == .idle && !b.coordinator.isMicrophoneLive, "Losing focus ends the press")
    await b.settle()
    try expect(b.transcriber.log.suffix(2) == ["cancel", "prepare en-US"] && !b.transcriber.isCapturing,
               "…closes the microphone, and loads the next recognizer: \(b.transcriber.log)")
    b.coordinator.pressUp()
    await b.settle()
    try expect(b.translator.requests.isEmpty && b.speaker.spoken.isEmpty && b.coordinator.state == .idle, "The release that follows is ignored")

    // Losing focus during a reply leaves the reply alone.
    let r = Harness()
    await r.activate()
    r.speaker.holdsPlayback = true
    await r.turn(.englishToChinese)
    r.coordinator.sceneBecameInactive()
    try expect(r.speaker.isPlaying, "A reply keeps playing when focus is lost")
    // Going to the background stops it and gives the session back.
    r.coordinator.sceneEnteredBackground()
    await r.settle()
    try expect(!r.speaker.isPlaying && r.coordinator.state == .idle && r.environment.endAudioCount == 1, "The background stops speech and releases the session")
    r.speaker.holdsPlayback = false
    r.coordinator.sceneBecameActive()
    await r.settle()
    try expect(r.environment.beginAudioCount == 2, "Coming back reopens the audio session: \(r.environment.beginAudioCount)")

    // An interruption from the system fails the turn in progress.
    let i = Harness()
    await i.activate()
    i.coordinator.pressDown(.englishToChinese)
    await i.settle()
    i.coordinator.audioSessionLost(message: "Audio was interrupted by another app. Please try again.")
    await i.settle()
    guard case .error(let interruption) = i.coordinator.state else {
        throw CheckFailure(message: "An interruption during capture is an error: \(i.coordinator.state)")
    }
    try expect(interruption.recovery == .retry && interruption.message.contains("interrupted"), "The interruption is explained")
    try expect(!i.transcriber.isCapturing, "An interruption closes the microphone")
    i.coordinator.pressDown(.englishToChinese)
    await i.settle()
    try expect(i.coordinator.state.isListening && i.environment.beginAudioCount == 2, "The next press reopens the session and listens")
}

@MainActor
private func runFailureChecks() async throws {
    // The microphone could not start.
    let h = Harness()
    await h.activate()
    h.transcriber.beginError = InterpreterError.noMicrophoneInput
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    guard case .error(let captureError) = h.coordinator.state else {
        throw CheckFailure(message: "A failed start is an error: \(h.coordinator.state)")
    }
    try expect(captureError.recovery == .retry && captureError.message.contains("microphone"), "The failure names the microphone: \(captureError.message)")
    h.coordinator.pressUp()
    await h.settle()
    try expect(h.translator.requests.isEmpty, "A failed start translates nothing")
    h.transcriber.beginError = nil
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    try expect(h.coordinator.state.isListening, "A press recovers from the error")
    h.coordinator.cancelCapture()
    await h.settle()

    // Errors from the system that are not ours keep their description.
    struct SystemError: LocalizedError { var errorDescription: String? { "The engine could not start." } }
    h.transcriber.beginError = SystemError()
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    guard case .error(let wrapped) = h.coordinator.state else {
        throw CheckFailure(message: "A system failure is an error: \(h.coordinator.state)")
    }
    try expect(wrapped.message.contains("The engine could not start."), "A system error keeps its own words: \(wrapped.message)")
    h.transcriber.beginError = nil
    h.coordinator.dismissError()
    try expect(h.coordinator.state == .idle, "An error can be dismissed")

    // The recognizer failed while finishing.
    h.transcriber.finishError = InterpreterError.recognitionTimedOut
    await h.turn(.englishToChinese)
    guard case .error(let finishError) = h.coordinator.state else {
        throw CheckFailure(message: "A failed finish is an error: \(h.coordinator.state)")
    }
    try expect(finishError.recovery == .retry && h.translator.requests.isEmpty, "A failed finish translates nothing")
    h.transcriber.finishError = nil
    h.coordinator.dismissError()

    // Translation failed, then succeeded on Retry.
    h.translator.error = InterpreterError.translationFailed(reason: "offline models not available")
    await h.turn(.englishToChinese)
    guard case .error(let translationError) = h.coordinator.state else {
        throw CheckFailure(message: "A failed translation is an error: \(h.coordinator.state)")
    }
    try expect(translationError.recovery == .retry && translationError.message.contains("offline models not available"), "The translation failure is explained")
    try expect(h.coordinator.turns.isEmpty && h.speaker.spoken.isEmpty, "A failed translation records and speaks nothing")
    h.translator.error = nil
    h.coordinator.performRecovery()
    await h.settle()
    try expect(h.coordinator.state == .idle && h.coordinator.turns.count == 1 && h.speaker.spoken.count == 1, "Retry translates the same words again and speaks them")
    try expect(h.translator.requests.count == 2 && h.translator.requests[1].text == "Where is the station?", "Retry does not ask the person to speak again")

    // An empty translation is a failure, not a silent turn.
    h.translator.translations["Where is the station?"] = "   "
    await h.turn(.englishToChinese)
    guard case .error = h.coordinator.state else {
        throw CheckFailure(message: "An empty translation is an error: \(h.coordinator.state)")
    }
    try expect(h.coordinator.turns.count == 1, "An empty translation is not recorded")
    h.translator.translations["Where is the station?"] = nil
    h.coordinator.dismissError()

    // Translation that never returns is abandoned at the deadline.
    let slow = Harness()
    await slow.activate()
    slow.translator.gate = InterpreterOneShot()
    await slow.turn(.englishToChinese)
    try expect(slow.coordinator.state == .translating(sourceText: "Where is the station?"), "The translation is pending")
    slow.clock.advance(by: .seconds(12))
    await slow.settle()
    guard case .error(let timeout) = slow.coordinator.state else {
        throw CheckFailure(message: "A stalled translation ends in an error: \(slow.coordinator.state)")
    }
    try expect(timeout.recovery == .retry, "A stalled translation can be retried")
    slow.translator.gate?.resolve(true)
    await slow.settle()
    try expect(slow.coordinator.turns.isEmpty && slow.speaker.spoken.isEmpty, "A translation that arrives after the deadline is ignored")

    // The reply could not be spoken: the text is kept and Retry speaks it.
    let quiet = Harness()
    await quiet.activate()
    struct PlaybackError: LocalizedError { var errorDescription: String? { "The audio player could not start." } }
    quiet.speaker.error = PlaybackError()
    await quiet.turn(.englishToChinese)
    guard case .error(let speechError) = quiet.coordinator.state else {
        throw CheckFailure(message: "A failed reply is an error: \(quiet.coordinator.state)")
    }
    try expect(speechError.recovery == .retry && speechError.message.contains("The audio player could not start."), "The speech failure is explained")
    try expect(quiet.coordinator.turns.count == 1 && quiet.coordinator.turns[0].speechFailure != nil, "The translation is kept when it cannot be spoken")
    quiet.speaker.error = nil
    quiet.coordinator.performRecovery()
    await quiet.settle()
    try expect(quiet.coordinator.state == .idle && quiet.speaker.spoken.count == 2 && quiet.coordinator.turns[0].speechFailure == nil,
               "Retry speaks the kept translation and clears the failure")

    // The audio session could not be configured: not when the screen opened,
    // and not at the press that tries again.
    let session = Harness()
    struct SessionError: LocalizedError { var errorDescription: String? { "The audio session could not be activated." } }
    session.environment.beginAudioError = SessionError()
    await session.activate()
    try expect(session.coordinator.canStartTurn, "A session that could not be configured at launch does not block the screen")
    session.coordinator.pressDown(.englishToChinese)
    await session.settle()
    guard case .error(let sessionError) = session.coordinator.state else {
        throw CheckFailure(message: "A failed session is an error: \(session.coordinator.state)")
    }
    try expect(sessionError.message.contains("The audio session could not be activated.") && !session.transcriber.log.contains("begin en-US"),
               "The microphone is not opened when the session cannot be configured")
}

@MainActor
private func runPermissionChecks() async throws {
    // First press: the system asks, and that press records nothing.
    let h = Harness()
    h.environment.microphonePermission = .undetermined
    await h.activate()
    try expect(h.environment.beginAudioCount == 0, "The audio session is not configured before the microphone is allowed")
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    try expect(h.environment.permissionRequests == 1, "The first press asks for the microphone")
    try expect(h.coordinator.state == .idle && !h.transcriber.log.contains("begin en-US"), "The press that raised the prompt records nothing: \(h.coordinator.state)")
    try expect(h.coordinator.readiness.microphone == .granted, "The answer is remembered")
    h.coordinator.pressUp()
    await h.settle()
    await h.turn(.englishToChinese)
    try expect(h.environment.permissionRequests == 1 && h.coordinator.turns.count == 1, "The next press records without asking again")

    // The answer was no.
    let refused = Harness()
    refused.environment.microphonePermission = .undetermined
    refused.environment.permissionAnswer = false
    await refused.activate()
    refused.coordinator.pressDown(.englishToChinese)
    await refused.settle()
    guard case .error(let denied) = refused.coordinator.state else {
        throw CheckFailure(message: "A refused prompt is an error: \(refused.coordinator.state)")
    }
    try expect(denied.recovery == .openSettings, "A refusal points to Settings")
    try expect(refused.coordinator.readiness.microphone == .denied, "The refusal is remembered")

    // Already refused: no prompt, straight to Settings.
    let blocked = Harness()
    blocked.environment.microphonePermission = .denied
    await blocked.activate()
    blocked.coordinator.pressDown(.chineseToEnglish)
    await blocked.settle()
    guard case .error(let blockedError) = blocked.coordinator.state else {
        throw CheckFailure(message: "A denied microphone is an error: \(blocked.coordinator.state)")
    }
    try expect(blockedError.recovery == .openSettings && blocked.environment.permissionRequests == 0, "A denied microphone is not asked for again")
    blocked.coordinator.performRecovery()
    try expect(blocked.coordinator.state == .idle, "Opening Settings clears the error")
}

@MainActor
private func runReadinessChecks() async throws {
    // Missing speech model and missing translation languages.
    let h = Harness()
    h.transcriber.assetStates[.chineseToEnglish] = .needsDownload
    h.translator.state = .needsDownload
    await h.activate()
    try expect(h.coordinator.readiness.needsDownload && !h.coordinator.canStartTurn, "Missing assets block a turn")
    try expect(h.transcriber.log.isEmpty && h.translator.warmed.isEmpty, "Nothing is loaded while assets are missing: \(h.transcriber.log)")
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    try expect(h.coordinator.state == .idle && !h.transcriber.log.contains("begin en-US"), "A press records nothing while assets are missing")

    h.coordinator.downloadModels()
    try expect(h.coordinator.state == .preparingModels(progress: nil), "Download starts with no progress yet")
    await h.yield()
    await h.settle()
    try expect(h.transcriber.log.first == "install", "Speech models are installed: \(h.transcriber.log)")
    try expect(h.coordinator.readiness.chineseSpeech == .ready, "The speech model is ready after install")
    try expect(h.coordinator.translationDownloadRequests == 1, "The screen is asked to request the translation languages")
    try expect(h.coordinator.state == .idle && !h.coordinator.canStartTurn, "Translation is still missing")

    h.translator.state = .ready
    h.coordinator.translationLanguagesPrepared()
    await h.yield()
    await h.settle()
    try expect(h.coordinator.readiness.assetsAreUsable && h.coordinator.canStartTurn, "Everything is ready after the system installs the languages")
    try expect(h.translator.warmed.count == 2 && h.transcriber.log.contains("prepare zh-CN"), "Models are loaded once they exist")
    await h.turn(.chineseToEnglish)
    try expect(h.coordinator.turns.count == 1, "A turn works after the download")

    // Progress is visible while installing.
    let progress = Harness()
    progress.transcriber.assetStates[.englishToChinese] = .needsDownload
    progress.transcriber.installProgress = [0.25]
    await progress.activate()
    progress.coordinator.downloadModels()
    await progress.yield()
    await progress.settle()
    try expect(progress.coordinator.state == .idle && progress.coordinator.canStartTurn, "The install completes: \(progress.coordinator.state)")

    // A download failure offers Download again.
    let broken = Harness()
    broken.transcriber.assetStates[.englishToChinese] = .needsDownload
    broken.transcriber.installError = .speechAssetInstallFailed(reason: "The network connection was lost.")
    await broken.activate()
    broken.coordinator.downloadModels()
    await broken.yield()
    await broken.settle()
    guard case .error(let installError) = broken.coordinator.state else {
        throw CheckFailure(message: "A failed download is an error: \(broken.coordinator.state)")
    }
    try expect(installError.recovery == .downloadModels && installError.message.contains("The network connection was lost."), "A failed download can be tried again")
    broken.transcriber.installError = nil
    broken.coordinator.performRecovery()
    await broken.yield()
    await broken.settle()
    try expect(broken.coordinator.canStartTurn && broken.coordinator.state == .idle, "Trying again installs the model")

    // The Simulator's stand-ins count as usable.
    let simulator = Harness()
    simulator.translator.state = .simulatorMock
    simulator.transcriber.assetStates = [.englishToChinese: .simulatorMock, .chineseToEnglish: .simulatorMock]
    await simulator.activate()
    try expect(simulator.coordinator.canStartTurn, "The Simulator's stand-ins allow a turn")

    // A device that cannot do it says so and offers no download.
    let unsupported = Harness()
    unsupported.translator.state = .unsupported
    await unsupported.activate()
    try expect(unsupported.coordinator.readiness.hasUnsupportedAsset && !unsupported.coordinator.readiness.needsDownload && !unsupported.coordinator.canStartTurn,
               "An unsupported device cannot start a turn and is not offered a download")
}

@MainActor
private func runVoiceAndReplayChecks() async throws {
    let h = Harness()
    await h.activate()
    h.environment.voiceEngine = .miniMax
    h.environment.translationQuality = .fast
    await h.turn(.englishToChinese)
    try expect(h.speaker.spoken[0].engine == .miniMax && h.coordinator.turns[0].spokenWith == .miniMax, "The chosen voice speaks the reply")
    try expect(h.translator.requests[0].model == .fast && h.coordinator.turns[0].translatedWith == .fast, "The chosen translation quality is used")

    // A MiniMax reply that fell back to the system voice is recorded as
    // spoken by the system voice, so its card does not claim otherwise.
    let fallback = Harness()
    await fallback.activate()
    fallback.environment.voiceEngine = .miniMax
    fallback.speaker.startsWith = .system
    await fallback.turn(.englishToChinese)
    try expect(fallback.speaker.spoken[0].engine == .miniMax && fallback.coordinator.turns[0].spokenWith == .system,
               "A turn records the voice that actually spoke it: \(fallback.coordinator.turns[0].spokenWith)")

    // Replay uses the voice that spoke the turn, whatever is selected now.
    h.environment.voiceEngine = .system
    h.speaker.holdsPlayback = true
    let turnID = h.coordinator.turns[0].id
    h.coordinator.replay(turnID)
    await h.yield()
    try expect(h.coordinator.state == .speaking(sourceText: h.coordinator.turns[0].sourceText, translatedText: h.coordinator.turns[0].translatedText),
               "Replay shows the turn being spoken: \(h.coordinator.state)")
    try expect(h.speaker.spoken.count == 2 && h.speaker.spoken[1].engine == .miniMax && h.speaker.spoken[1].languageCode == "zh-CN", "Replay keeps the turn's voice")
    try expect(h.coordinator.speakingTurnID == turnID && h.translator.requests.count == 1, "Replay does not translate again")

    // Stop ends the reply and keeps the turn.
    h.coordinator.stopSpeaking()
    await h.settle()
    try expect(h.coordinator.state == .idle && h.coordinator.turns.count == 1 && h.coordinator.speakingTurnID == nil, "Stop ends the reply and keeps the turn")

    // A press during a replay wins, like any other reply.
    h.coordinator.replay(turnID)
    await h.yield()
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    try expect(h.coordinator.state.isListening && !h.speaker.isPlaying, "A press interrupts a replay")
    // Replay is refused while the microphone is in use.
    let spokenBefore = h.speaker.spoken.count
    h.coordinator.replay(turnID)
    await h.yield()
    try expect(h.speaker.spoken.count == spokenBefore && h.coordinator.state.isListening, "Replay is ignored while listening")
    h.coordinator.cancelCapture()
    await h.settle()

    // Clearing the conversation.
    h.speaker.holdsPlayback = false
    h.coordinator.clearConversation()
    try expect(h.coordinator.turns.isEmpty, "The conversation can be cleared")
    h.coordinator.replay(turnID)
    await h.settle()
    try expect(h.coordinator.state == .idle, "Replaying a turn that is gone does nothing")
}

@MainActor
private func runLifecycleChecks() async throws {
    // Leaving the screen mid-translation stops everything.
    let h = Harness()
    await h.activate()
    h.translator.gate = InterpreterOneShot()
    await h.turn(.englishToChinese)
    try expect(h.coordinator.state == .translating(sourceText: "Where is the station?"), "A translation is pending")
    h.coordinator.deactivate()
    try expect(h.coordinator.state == .idle && !h.coordinator.canStartTurn, "Leaving the screen ends the turn")
    h.translator.gate?.resolve(true)
    await h.settle()
    for _ in 0..<4 { await h.yield() }
    try expect(h.coordinator.turns.isEmpty && h.speaker.spoken.isEmpty, "Work that finishes after leaving is discarded")
    try expect(h.environment.endAudioCount == 1 && h.transcriber.log.last == "release", "Leaving gives back the session and the models: \(h.transcriber.log)")
    h.coordinator.pressDown(.englishToChinese)
    try expect(h.coordinator.state == .idle, "A press does nothing once the screen is gone")

    // Leaving mid-press closes the microphone before releasing the models.
    let p = Harness()
    await p.activate()
    p.coordinator.pressDown(.englishToChinese)
    await p.settle()
    p.coordinator.deactivate()
    await p.settle()
    for _ in 0..<4 { await p.yield() }
    try expect(p.transcriber.log.suffix(2) == ["cancel", "release"] && !p.transcriber.isCapturing, "The microphone closes before the models go: \(p.transcriber.log)")

    // Two windows: the session survives until the last one closes.
    let w = Harness()
    w.coordinator.activate()
    w.coordinator.activate()
    await w.settle()
    w.coordinator.deactivate()
    try expect(w.coordinator.canStartTurn && w.environment.endAudioCount == 0, "One of two windows closing changes nothing")
    w.coordinator.deactivate()
    try expect(!w.coordinator.canStartTurn, "The last window closing ends the session")
    await w.settle()
    try expect(w.environment.endAudioCount == 1, "…and gives the audio session back")
    w.coordinator.deactivate()
    await w.settle()
    try expect(w.environment.endAudioCount == 1, "An unbalanced close is ignored")

    // Reopening works.
    await w.activate()
    await w.turn(.englishToChinese)
    try expect(w.coordinator.turns.count == 1, "The screen works again after reopening")
}

/// The model a turn will be translated with is touched when the button goes
/// down and again every few seconds of the hold, so that the translation
/// after release does not wait for a model that has gone cold.
@MainActor
private func runKeepWarmChecks() async throws {
    let interval = InterpreterTuning.translationKeepWarmInterval
    let h = Harness()
    await h.activate()

    h.coordinator.pressDown(.chineseToEnglish)
    await h.settle()
    try expect(h.translator.warmed.count == 3 && h.translator.warmed.last == "zh-CN natural",
               "A press touches the turn's translation model at once: \(h.translator.warmed)")
    h.clock.advance(by: interval - .milliseconds(1))
    await h.yield()
    try expect(h.translator.warmed.count == 3, "…and not again before the interval has passed")
    h.clock.advance(by: .milliseconds(1))
    await h.yield()
    try expect(h.translator.warmed.count == 4, "…then again once it has")
    h.clock.advance(by: interval)
    await h.yield()
    try expect(h.translator.warmed.count == 5 && h.translator.requests.isEmpty, "…for as long as the button is held, and without translating anything")

    h.coordinator.pressUp()
    await h.settle()
    try expect(h.coordinator.turns.count == 1 && h.translator.requests.count == 1 && h.translator.requests[0].model == .natural,
               "The turn is translated by the model that was kept warm")
    h.clock.advance(by: interval * 3)
    await h.settle()
    try expect(h.translator.warmed.count == 5, "Nothing is touched once the button is up: \(h.translator.warmed)")

    // The fast setting keeps the fast model warm, in the direction of the press.
    h.environment.translationQuality = .fast
    h.coordinator.pressDown(.englishToChinese)
    await h.settle()
    try expect(h.translator.warmed.last == "en-US fast", "The model follows the setting: \(h.translator.warmed)")

    // A press that is abandoned stops it.
    let whileHeld = h.translator.warmed.count
    h.coordinator.cancelCapture()
    await h.settle()
    h.clock.advance(by: interval * 2)
    await h.settle()
    try expect(h.translator.warmed.count == whileHeld, "An abandoned press stops touching the model")

    // So does a press that fails to start.
    let failing = Harness()
    await failing.activate()
    failing.transcriber.beginError = InterpreterError.noMicrophoneInput
    failing.coordinator.pressDown(.englishToChinese)
    await failing.settle()
    let afterFailure = failing.translator.warmed.count
    failing.clock.advance(by: interval * 2)
    await failing.settle()
    try expect(failing.translator.warmed.count == afterFailure, "A press that fails to start stops touching the model")

    // And leaving the screen.
    let leaving = Harness()
    await leaving.activate()
    leaving.coordinator.pressDown(.englishToChinese)
    await leaving.settle()
    let beforeLeaving = leaving.translator.warmed.count
    leaving.coordinator.deactivate()
    await leaving.settle()
    leaving.clock.advance(by: interval * 2)
    await leaving.settle()
    try expect(leaving.translator.warmed.count == beforeLeaving, "Leaving the screen stops touching the model")

    // With the fast setting, opening the screen loads the fast model only.
    let fastOpening = Harness()
    fastOpening.environment.translationQuality = .fast
    await fastOpening.activate()
    try expect(fastOpening.translator.warmed == ["en-US fast", "zh-CN fast"], "Opening the screen loads only the model the setting names: \(fastOpening.translator.warmed)")
}

/// The translation setting: which model each choice means, and how the
/// automatic one decides.
@MainActor
private func runQualityChecks() async throws {
    let settings: [(InterpreterTranslationQuality, InterpreterTranslationModel)] = [
        (.natural, .natural), (.fast, .fast), (.automatic, .natural),
    ]
    for (quality, model) in settings {
        let h = Harness()
        h.environment.translationQuality = quality
        await h.activate()
        await h.turn(.englishToChinese)
        try expect(h.translator.requests.count == 1 && h.translator.requests[0].model == model && h.coordinator.turns[0].translatedWith == model,
                   "\(quality.rawValue) translates with the \(model.rawValue) model: \(h.translator.requests.map(\.model))")
    }

    try expect(InterpreterTuning.naturalTranslationAllowance(heldMilliseconds: nil) == .milliseconds(500)
               && InterpreterTuning.naturalTranslationAllowance(heldMilliseconds: 1_000) == .milliseconds(500)
               && InterpreterTuning.naturalTranslationAllowance(heldMilliseconds: 2_000) == .milliseconds(600)
               && InterpreterTuning.naturalTranslationAllowance(heldMilliseconds: 4_700) == .milliseconds(870)
               && InterpreterTuning.naturalTranslationAllowance(heldMilliseconds: 60_000) == .milliseconds(1_200),
               "Longer speech is allowed a longer translation, within bounds")

    // One turn whose translation takes exactly `translationTakes`.
    func turn(in h: Harness, held: Duration = .seconds(2), translationTakes: Duration) async {
        h.translator.gate = InterpreterOneShot()
        h.coordinator.pressDown(.englishToChinese)
        await h.settle()
        h.clock.advance(by: held)
        h.coordinator.pressUp()
        await h.settle()
        h.clock.advance(by: translationTakes)
        let gate = h.translator.gate
        h.translator.gate = nil
        gate?.resolve(true)
        await h.settle()
    }

    // Automatic: two slow natural turns in a row move the visit to the fast
    // model. A two-second hold allows the translation 600 ms.
    let h = Harness()
    h.environment.translationQuality = .automatic
    await h.activate()
    await turn(in: h, translationTakes: .milliseconds(601))
    await turn(in: h, translationTakes: .milliseconds(600))
    await turn(in: h, translationTakes: .milliseconds(601))
    try expect(h.translator.requests.map(\.model) == [.natural, .natural, .natural], "One slow turn does not change the model, and a quick one clears it")
    await turn(in: h, translationTakes: .milliseconds(900))
    await turn(in: h, translationTakes: .milliseconds(20))
    try expect(h.translator.requests.map(\.model) == [.natural, .natural, .natural, .natural, .fast],
               "Two slow turns in a row move the next one to the fast model: \(h.translator.requests.map(\.model))")
    try expect(h.translator.warmed.last == "en-US fast" && h.coordinator.turns.last?.translatedWith == .fast, "…which is then the one kept warm and recorded")
    await turn(in: h, translationTakes: .milliseconds(5_000))
    await turn(in: h, translationTakes: .milliseconds(20))
    try expect(h.translator.requests.suffix(2).map(\.model) == [.fast, .fast], "The visit stays on the fast model")
    try expect(h.coordinator.turns.count == 7 && h.speaker.spoken.count == 7, "Every one of those turns was spoken")

    // The next visit gives the natural model a fresh chance.
    h.coordinator.deactivate()
    await h.settle()
    await h.activate()
    await turn(in: h, translationTakes: .milliseconds(20))
    try expect(h.translator.requests.last?.model == .natural, "Reopening the screen starts with the natural model again")

    // A longer hold allows a longer translation: 900 ms is slow after two
    // seconds of speech and not after six.
    let long = Harness()
    long.environment.translationQuality = .automatic
    await long.activate()
    await turn(in: long, held: .seconds(6), translationTakes: .milliseconds(900))
    await turn(in: long, held: .seconds(6), translationTakes: .milliseconds(900))
    await turn(in: long, held: .seconds(6), translationTakes: .milliseconds(20))
    try expect(long.translator.requests.map(\.model) == [.natural, .natural, .natural], "Longer speech is allowed a longer wait: \(long.translator.requests.map(\.model))")

    // Automatic: a turn that a waiting press has overtaken is translated
    // behind that press's warm-up, and nobody is waiting for its reply. Its
    // time says nothing about the model, so it is not held against it.
    let overtaken = Harness()
    overtaken.environment.translationQuality = .automatic
    await overtaken.activate()
    for _ in 0..<2 {
        overtaken.transcriber.finishGate = InterpreterOneShot()
        await overtaken.turn(.englishToChinese, held: .seconds(2))
        overtaken.coordinator.pressDown(.chineseToEnglish)
        overtaken.translator.gate = InterpreterOneShot()
        let finishing = overtaken.transcriber.finishGate
        overtaken.transcriber.finishGate = nil
        finishing?.resolve(true)
        await overtaken.settle()
        try expect(overtaken.coordinator.state.isListening && overtaken.coordinator.activeDirection == .chineseToEnglish,
                   "The waiting press has taken over: \(overtaken.coordinator.state)")
        overtaken.clock.advance(by: .milliseconds(900))
        let translating = overtaken.translator.gate
        overtaken.translator.gate = nil
        translating?.resolve(true)
        await overtaken.settle()
        // The press that took over is given up, so the only translations
        // are those of the overtaken turns.
        overtaken.coordinator.sceneBecameInactive()
        await overtaken.settle()
    }
    try expect(overtaken.coordinator.turns.count == 2 && overtaken.speaker.spoken.isEmpty,
               "Both overtaken turns were translated and kept, and neither was spoken: \(overtaken.coordinator.turns.count)")
    await overtaken.turn(.englishToChinese)
    try expect(overtaken.translator.requests.map(\.model) == [.natural, .natural, .natural],
               "Two overtaken turns that were slow to translate do not move the visit to the fast model: \(overtaken.translator.requests.map(\.model))")

    // The other settings never move.
    let fixed = Harness()
    await fixed.activate()
    await turn(in: fixed, translationTakes: .seconds(3))
    await turn(in: fixed, translationTakes: .seconds(3))
    await turn(in: fixed, translationTakes: .milliseconds(20))
    try expect(fixed.translator.requests.map(\.model) == [.natural, .natural, .natural], "The natural setting stays natural however slow it is")

    // A device with one model has nothing to move to.
    let single = Harness()
    single.translator.offersTwoModels = false
    single.environment.translationQuality = .automatic
    await single.activate()
    try expect(!single.coordinator.offersTranslationChoice, "A device with one model offers no choice")
    await turn(in: single, translationTakes: .seconds(3))
    await turn(in: single, translationTakes: .seconds(3))
    await turn(in: single, translationTakes: .milliseconds(20))
    try expect(single.translator.requests.map(\.model) == [.natural, .natural, .natural], "With one model the automatic setting stays put")

    // Automatic: a natural translation that fails is answered by the fast
    // model, and the visit stays on it.
    let failing = Harness()
    failing.environment.translationQuality = .automatic
    await failing.activate()
    failing.translator.error = InterpreterError.translationFailed(reason: "The model stopped.")
    failing.translator.failingModel = .natural
    await failing.turn(.englishToChinese)
    try expect(failing.coordinator.state == .idle && failing.coordinator.turns.count == 1 && failing.speaker.spoken.count == 1,
               "A natural translation that fails does not lose the reply: \(failing.coordinator.state)")
    try expect(failing.translator.requests.map(\.model) == [.natural, .fast] && failing.coordinator.turns[0].translatedWith == .fast,
               "…the fast model answers it")
    await failing.turn(.englishToChinese)
    try expect(failing.translator.requests.map(\.model) == [.natural, .fast, .fast], "…and later turns go straight to it")

    // The natural setting asked for that model, so it reports the failure.
    let strict = Harness()
    await strict.activate()
    strict.translator.error = InterpreterError.translationFailed(reason: "The model stopped.")
    strict.translator.failingModel = .natural
    await strict.turn(.englishToChinese)
    guard case .error(let strictError) = strict.coordinator.state else {
        throw CheckFailure(message: "The natural setting reports a failed translation: \(strict.coordinator.state)")
    }
    try expect(strictError.recovery == .retry && strict.translator.requests.map(\.model) == [.natural], "The natural setting does not fall back")

    // A missing language pack is missing for both models.
    let missing = Harness()
    missing.environment.translationQuality = .automatic
    await missing.activate()
    missing.translator.error = InterpreterError.translationLanguagesMissing
    await missing.turn(.englishToChinese)
    guard case .error(let missingError) = missing.coordinator.state else {
        throw CheckFailure(message: "Missing languages are an error: \(missing.coordinator.state)")
    }
    try expect(missingError.recovery == .downloadModels && missing.translator.requests.count == 1, "Missing languages are not retried with the other model")

    // Both models failing is a failed turn that can be tried again.
    let both = Harness()
    both.environment.translationQuality = .automatic
    await both.activate()
    both.translator.error = InterpreterError.translationFailed(reason: "The model stopped.")
    await both.turn(.englishToChinese)
    guard case .error(let bothError) = both.coordinator.state else {
        throw CheckFailure(message: "Both models failing is an error: \(both.coordinator.state)")
    }
    try expect(bothError.recovery == .retry && both.translator.requests.map(\.model) == [.natural, .fast] && both.coordinator.turns.isEmpty,
               "Both models failing is a failed turn")
    both.translator.error = nil
    both.coordinator.performRecovery()
    await both.settle()
    try expect(both.coordinator.state == .idle && both.coordinator.turns.count == 1 && both.coordinator.turns[0].translatedWith == .fast,
               "Trying again uses the model the visit has moved to: \(both.coordinator.state)")

    // Automatic: a natural translation that runs out of time is not chased
    // with a second one, which could only wait behind it. Try Again uses the
    // fast model.
    let stuck = Harness()
    stuck.environment.translationQuality = .automatic
    await stuck.activate()
    stuck.translator.gate = InterpreterOneShot()
    await stuck.turn(.englishToChinese)
    try expect(stuck.coordinator.state == .translating(sourceText: "Where is the station?"), "The translation is underway: \(stuck.coordinator.state)")
    stuck.clock.advance(by: InterpreterTuning.translationTimeout)
    await stuck.settle()
    guard case .error(let stuckError) = stuck.coordinator.state else {
        throw CheckFailure(message: "A translation that never returns is an error: \(stuck.coordinator.state)")
    }
    try expect(stuckError == InterpreterError.translationTimedOut.userFacing && stuck.translator.requests.map(\.model) == [.natural],
               "A translation that runs out of time fails the turn without a second attempt: \(stuck.translator.requests.map(\.model))")
    let late = stuck.translator.gate
    stuck.translator.gate = nil
    late?.resolve(true)
    await stuck.settle()
    try expect(stuck.coordinator.turns.isEmpty && stuck.speaker.spoken.isEmpty, "Its late answer is ignored")
    stuck.coordinator.performRecovery()
    await stuck.settle()
    try expect(stuck.translator.requests.map(\.model) == [.natural, .fast] && stuck.coordinator.turns.count == 1 && stuck.coordinator.state == .idle,
               "Try Again uses the fast model: \(stuck.translator.requests.map(\.model))")

    // The screen is told whether there is a choice to offer.
    let choice = Harness()
    let flag = ChangeFlag()
    try expect(!choice.coordinator.offersTranslationChoice, "No choice is offered before the device has been asked")
    withObservationTracking {
        _ = choice.coordinator.offersTranslationChoice
    } onChange: {
        flag.set()
    }
    await choice.activate()
    try expect(flag.take() && choice.coordinator.offersTranslationChoice, "A device with two models offers the choice, and the screen is told")
}

/// What the audio session and the microphone are left holding on the paths
/// that end a turn from outside: an interruption, the background, a release
/// that comes before the microphone has opened.
@MainActor
private func runSessionChecks() async throws {
    // An interruption gives the hold on the session back, and leaving the
    // screen afterwards does not give it back twice.
    let lost = Harness()
    await lost.activate()
    try expect(lost.environment.beginAudioCount == 1 && lost.environment.endAudioCount == 0, "The session is held while the screen is open")
    lost.coordinator.audioSessionLost(message: "Audio was interrupted by another app. Please try again.")
    await lost.settle()
    try expect(lost.environment.endAudioCount == 1 && lost.coordinator.state == .idle, "An interruption gives the hold on the session back: \(lost.environment.endAudioCount)")
    lost.coordinator.deactivate()
    await lost.settle()
    try expect(lost.environment.endAudioCount == 1, "Leaving afterwards does not give it back a second time")

    // During a hold, the microphone is shut before the session is given back.
    let held = Harness()
    await held.activate()
    held.coordinator.pressDown(.englishToChinese)
    await held.settle()
    held.coordinator.audioSessionLost(message: "Audio was interrupted by another app. Please try again.")
    try expect(held.environment.endAudioCount == 0, "The session is not given back before the microphone is shut")
    await held.settle()
    try expect(held.environment.endAudioCount == 1 && !held.transcriber.isCapturing && held.transcriber.log.contains("cancel"),
               "…and is given back once it is: \(held.transcriber.log)")

    // An interruption while the reply is being translated keeps the words
    // and does not speak into the session that was taken away.
    let translating = Harness()
    await translating.activate()
    translating.translator.gate = InterpreterOneShot()
    await translating.turn(.englishToChinese)
    translating.coordinator.audioSessionLost(message: "Audio was interrupted by another app. Please try again.")
    try expect(translating.coordinator.state == .idle, "An interruption during translation ends the turn quietly: \(translating.coordinator.state)")
    translating.translator.gate?.resolve(true)
    await translating.settle()
    try expect(translating.coordinator.turns.count == 1 && translating.speaker.spoken.isEmpty, "…its words are kept and not spoken")

    // Going to the background while the reply is being translated: the same.
    let away = Harness()
    await away.activate()
    away.translator.gate = InterpreterOneShot()
    await away.turn(.englishToChinese)
    away.coordinator.sceneEnteredBackground()
    try expect(away.coordinator.state == .idle, "The background ends a turn that was being translated: \(away.coordinator.state)")
    away.translator.gate?.resolve(true)
    await away.settle()
    try expect(away.coordinator.turns.count == 1 && away.speaker.spoken.isEmpty && away.environment.endAudioCount == 1,
               "…its words are kept, nothing is spoken from the background, and the session is given back")

    // Going to the background while the words are still being finalized
    // gives the turn up and stops the recognizer.
    let finishing = Harness()
    await finishing.activate()
    finishing.transcriber.finishGate = InterpreterOneShot()
    await finishing.turn(.englishToChinese)
    try expect(finishing.coordinator.state == .finalizingTranscript, "The turn is finalizing")
    finishing.coordinator.sceneEnteredBackground()
    await finishing.settle()
    try expect(finishing.coordinator.state == .idle && finishing.transcriber.log.contains("cancel"), "The background stops a turn that was finalizing: \(finishing.transcriber.log)")
    try expect(finishing.translator.requests.isEmpty && finishing.speaker.spoken.isEmpty && finishing.coordinator.turns.isEmpty, "…and nothing is translated or spoken")

    // The session finishes opening after the screen has gone: it is given
    // back, not kept by a screen that is no longer there.
    let late = Harness()
    late.environment.beginAudioGate = InterpreterOneShot()
    late.coordinator.activate()
    await late.settle()
    late.coordinator.deactivate()
    let opening = late.environment.beginAudioGate
    late.environment.beginAudioGate = nil
    opening?.resolve(true)
    await late.settle()
    try expect(late.environment.beginAudioCount == 1 && late.environment.endAudioCount == 1, "A session that finishes opening after the screen left is given back: \(late.environment.endAudioCount)")

    // The screen is left and opened again while the session is still being
    // opened for the first visit. Giving the first visit's session back must
    // not come after the request that holds it for the second: whatever is
    // asked for last is what the session is left as.
    let returning = Harness()
    returning.environment.beginAudioGate = InterpreterOneShot()
    returning.coordinator.activate()
    await returning.settle()
    returning.coordinator.deactivate()
    await returning.settle()
    returning.coordinator.activate()
    await returning.settle()
    let firstVisitOpening = returning.environment.beginAudioGate
    returning.environment.beginAudioGate = nil
    firstVisitOpening?.resolve(true)
    await returning.settle()
    try expect(returning.environment.holdsAudioOnceSettled,
               "Leaving and coming back while the session is still opening ends with it held: \(returning.environment.audioRequests)")
    await returning.turn(.englishToChinese)
    try expect(returning.coordinator.turns.count == 1 && returning.environment.holdsAudioOnceSettled,
               "…and a turn then works without asking for it again: \(returning.environment.audioRequests)")
    returning.coordinator.deactivate()
    await returning.settle()
    try expect(!returning.environment.holdsAudioOnceSettled, "…and leaving gives it back: \(returning.environment.audioRequests)")

    // The session is still being given back, behind a microphone that is
    // slow to shut, when the app comes forward and asks for it again; then
    // the screen is left before that request has had its turn. Nothing wants
    // the session any more, so it must not end up held.
    let unseen = Harness()
    await unseen.activate()
    unseen.coordinator.pressDown(.englishToChinese)
    await unseen.settle()
    unseen.transcriber.cancelGate = InterpreterOneShot()
    unseen.coordinator.sceneEnteredBackground()
    await unseen.settle()
    unseen.coordinator.sceneBecameActive()
    await unseen.settle()
    unseen.coordinator.deactivate()
    await unseen.settle()
    try expect(unseen.environment.audioRequests == ["hold"],
               "The session is not given back while the microphone is still shutting: \(unseen.environment.audioRequests)")
    let shutting = unseen.transcriber.cancelGate
    unseen.transcriber.cancelGate = nil
    shutting?.resolve(true)
    await unseen.settle()
    try expect(unseen.environment.audioRequests == ["hold", "give back"],
               "A request for the session that was overtaken by leaving is dropped, not opened for nobody: \(unseen.environment.audioRequests)")

    // The button comes up before the microphone could open: it is not opened
    // afterwards.
    let quick = Harness()
    await quick.activate()
    // Back from the background, the session has to be opened again by the
    // press itself, which is what makes this start a slow one.
    quick.coordinator.sceneEnteredBackground()
    await quick.settle()
    quick.environment.beginAudioGate = InterpreterOneShot()
    let quickPress = try quick.press(.englishToChinese)
    await quick.yield()
    quick.clock.advance(by: .milliseconds(400))
    quick.coordinator.pressUp(quickPress)
    let reopening = quick.environment.beginAudioGate
    quick.environment.beginAudioGate = nil
    reopening?.resolve(true)
    await quick.settle()
    try expect(!quick.transcriber.log.contains("begin en-US") && !quick.transcriber.isCapturing, "A microphone that was not open by the release is not opened after it: \(quick.transcriber.log)")
    try expect(quick.coordinator.state == .idle && quick.coordinator.hint == .holdToSpeak, "…and the press is treated as too short: \(quick.coordinator.state)")

    // A start that is cancelled without anyone settling the state does not
    // leave the screen listening for ever.
    let orphan = Harness()
    await orphan.activate()
    orphan.transcriber.beginError = CancellationError()
    orphan.coordinator.pressDown(.englishToChinese)
    await orphan.settle()
    try expect(orphan.coordinator.state == .idle, "A cancelled start ends the press: \(orphan.coordinator.state)")
    orphan.transcriber.beginError = nil
    await orphan.turn(.englishToChinese)
    try expect(orphan.coordinator.turns.count == 1, "…and the next press works")

    // The same for a finalization that is cancelled.
    let cut = Harness()
    await cut.activate()
    cut.transcriber.finishError = CancellationError()
    await cut.turn(.englishToChinese)
    try expect(cut.coordinator.state == .idle && cut.coordinator.turns.isEmpty, "A cancelled finalization ends the turn: \(cut.coordinator.state)")

    // A model that is already downloading when the screen opens is looked at
    // again until it has arrived.
    let arriving = Harness()
    arriving.transcriber.assetStates[.chineseToEnglish] = .downloading(progress: nil)
    arriving.coordinator.activate()
    await arriving.settle()
    try expect(arriving.coordinator.readiness.isDownloading && !arriving.coordinator.canStartTurn, "A model on its way blocks a turn")
    arriving.transcriber.assetStates[.chineseToEnglish] = .ready
    arriving.clock.advance(by: InterpreterTuning.downloadPollInterval)
    await arriving.settle()
    try expect(arriving.coordinator.canStartTurn && arriving.transcriber.log.contains("prepare zh-CN"), "…and the screen becomes ready when it arrives, without being reopened")

    // A download that was abandoned by leaving finishes later without
    // disturbing the next visit.
    let stale = Harness()
    stale.transcriber.assetStates[.englishToChinese] = .needsDownload
    await stale.activate()
    stale.transcriber.installGate = InterpreterOneShot()
    stale.coordinator.downloadModels()
    await stale.settle()
    stale.coordinator.deactivate()
    await stale.settle()
    await stale.activate()
    stale.coordinator.downloadModels()
    try expect(stale.coordinator.state == .preparingModels(progress: nil), "The next visit can start its own download")
    let installing = stale.transcriber.installGate
    stale.transcriber.installGate = nil
    installing?.resolve(true)
    await stale.settle()
    try expect(stale.coordinator.canStartTurn && stale.coordinator.state == .idle, "Both downloads finishing leaves the screen ready and idle: \(stale.coordinator.state)")
}

/// A flag an observation callback can set from wherever it is called.
private final class ChangeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var changed = false

    func set() { lock.withLock { changed = true } }
    func take() -> Bool {
        lock.withLock {
            defer { changed = false }
            return changed
        }
    }
}

/// What a screen reads to decide whether its buttons are live must tell the
/// screen when the answer changes. The screen builds its buttons before it
/// has appeared, so the first answer is always no; if the reason for that no
/// is not observed, the buttons stay disabled for good.
@MainActor
private func runObservationChecks() async throws {
    let h = Harness()
    let flag = ChangeFlag()

    withObservationTracking {
        _ = h.coordinator.canStartTurn
    } onChange: {
        flag.set()
    }
    try expect(!h.coordinator.canStartTurn, "Nothing can start before the screen appears")
    h.coordinator.activate()
    try expect(flag.take(), "Becoming active is observed by whoever asked whether a turn can start")

    withObservationTracking {
        _ = h.coordinator.canStartTurn
    } onChange: {
        flag.set()
    }
    await h.settle()
    try expect(flag.take() && h.coordinator.canStartTurn, "Readiness arriving is observed too")

    withObservationTracking {
        _ = h.coordinator.canStartTurn
    } onChange: {
        flag.set()
    }
    h.coordinator.deactivate()
    try expect(flag.take() && !h.coordinator.canStartTurn, "Leaving the screen is observed")

    // The same for a download that starts and ends.
    let d = Harness()
    d.transcriber.assetStates[.englishToChinese] = .needsDownload
    await d.activate()
    withObservationTracking {
        _ = d.coordinator.canStartTurn
    } onChange: {
        flag.set()
    }
    d.coordinator.downloadModels()
    await d.settle()
    try expect(flag.take() && d.coordinator.canStartTurn, "A finished download is observed")
}

@MainActor
private func runModelChecks() throws {
    try expect(InterpreterAssetState.ready.isUsable && InterpreterAssetState.simulatorMock.isUsable, "Ready and the Simulator stand-in are usable")
    try expect(!InterpreterAssetState.needsDownload.isUsable && !InterpreterAssetState.unknown.isUsable && !InterpreterAssetState.unsupported.isUsable
               && !InterpreterAssetState.downloading(progress: 0.5).isUsable, "Nothing else is usable")
    try expect(InterpreterPermissionState.granted.allowsCapture && InterpreterPermissionState.notRequired.allowsCapture
               && !InterpreterPermissionState.undetermined.allowsCapture && !InterpreterPermissionState.denied.allowsCapture, "Only a granted permission allows capture")

    var readiness = InterpreterReadiness()
    try expect(readiness.isUnknown && !readiness.assetsAreUsable, "Unchecked readiness is unknown")
    readiness.englishSpeech = .ready
    readiness.chineseSpeech = .downloading(progress: 0.3)
    readiness.translation = .needsDownload
    try expect(readiness.isDownloading && readiness.needsDownload && !readiness.isUnknown, "Readiness reports what is in progress and what is missing")
    try expect(readiness.speech(for: .englishToChinese) == .ready && readiness.speech(for: .chineseToEnglish) == .downloading(progress: 0.3),
               "Each direction reads the model for the language it listens to")

    try expect(UserFacingError(message: "x", recovery: .retry) == UserFacingError(message: "x", recovery: .retry), "Errors that read the same are equal")
    try expect(InterpreterError.microphoneDenied.userFacing.recovery == .openSettings
               && InterpreterError.speechAssetsMissing.userFacing.recovery == .downloadModels
               && InterpreterError.translationLanguagesMissing.userFacing.recovery == .downloadModels
               && InterpreterError.tooManyReservedLocales.userFacing.recovery == .none
               && InterpreterError.requiresNewerSystem.userFacing.recovery == .none
               && InterpreterError.recognitionTimedOut.userFacing.recovery == .retry
               && InterpreterError.translationTimedOut.userFacing.recovery == .retry, "Each failure offers the action that can fix it")
    try expect(InterpreterError.speechUnsupported(language: "Chinese").userFacing.message.contains("Chinese"), "The unsupported language is named")
    try expect(!InterpreterHint.holdToSpeak.message.isEmpty && InterpreterHint.holdToSpeak.message != InterpreterHint.nothingHeard.message, "The two hints differ")

    try expect(!PipelineState.idle.isBusy && !PipelineState.preparingModels(progress: nil).isBusy && !PipelineState.error(UserFacingError(message: "x", recovery: .none)).isBusy,
               "Idle, preparing and error are not a turn in progress")
    try expect(PipelineState.finalizingTranscript.isBusy && PipelineState.translating(sourceText: "a").isBusy
               && PipelineState.speaking(sourceText: "a", translatedText: "b").isBusy
               && PipelineState.listening(direction: .englishToChinese, liveTranscript: "").isBusy, "Every stage of a turn is busy")
    try expect(TranscriptSnapshot(finalized: "Hello.", volatile: " How").text == "Hello. How" && TranscriptSnapshot().isEmpty, "A snapshot joins its two parts")
    try expect(Duration.milliseconds(1_250).interpreterMilliseconds == 1_250 && Duration.seconds(2).interpreterMilliseconds == 2_000, "Durations convert to whole milliseconds")
    try expect(InterpreterTuning.minimumHold == .milliseconds(250), "The minimum hold is a quarter of a second")
    try expect(InterpreterTuning.translationKeepWarmInterval < .seconds(4), "The model is touched more often than the four seconds it stays warm")
    try expect(InterpreterTranslationQuality.allCases == [.automatic, .natural, .fast] && InterpreterTranslationModel.allCases == [.natural, .fast],
               "Three settings choose between two models")
}

@MainActor
private func runDeadlineChecks() async throws {
    let clock = ManualClock()
    let quick = try await withInterpreterDeadline(.seconds(1), clock: clock, timeoutError: .recognitionTimedOut) { "done" }
    try expect(quick == "done", "Work that finishes in time returns its value")

    let stuck = InterpreterOneShot<Bool>()
    let waiting = Task { @MainActor in
        try await withInterpreterDeadline(.seconds(4), clock: clock, timeoutError: .recognitionTimedOut) {
            _ = await stuck.wait()
            return "late"
        }
    }
    for _ in 0..<8 { await Task.yield() }
    clock.advance(by: .seconds(4))
    do {
        _ = try await waiting.value
        throw CheckFailure(message: "Work past its deadline must not return a value")
    } catch let error as InterpreterError {
        try expect(error == .recognitionTimedOut, "The deadline throws the error it was given")
    }
    stuck.resolve(true)

    struct Boom: Error {}
    do {
        _ = try await withInterpreterDeadline(.seconds(1), clock: clock, timeoutError: .recognitionTimedOut) { () -> String in throw Boom() }
        throw CheckFailure(message: "A failure inside the deadline must be thrown")
    } catch is Boom {
        try expect(true, "The work's own failure is passed through")
    }

    let once = InterpreterOneShot<Int>()
    once.resolve(1)
    once.resolve(2)
    let value = await once.wait()
    try expect(value == 1 && once.isResolved, "Only the first delivery counts")

    // Several waiters each get the value; none is left suspended.
    let shared = InterpreterOneShot<Int>()
    let first = Task { @MainActor in await shared.wait() }
    let second = Task { @MainActor in await shared.wait() }
    for _ in 0..<8 { await Task.yield() }
    shared.resolve(7)
    let both = await (first.value, second.value)
    try expect(both.0 == 7 && both.1 == 7, "Every waiter is given the value")
}

@main
private struct InterpreterChecksRunner {
    @MainActor
    static func main() async {
        // Set INTERPRETER_CHECKS_TRACE=1 to see which group is running, for
        // the case where a check stalls instead of failing.
        let trace = ProcessInfo.processInfo.environment["INTERPRETER_CHECKS_TRACE"] != nil
        func group(_ name: String) {
            if trace { fputs("… \(name)\n", stderr) }
        }
        do {
            group("assembler")
            try runAssemblerChecks()
            group("models")
            try runModelChecks()
            group("deadline")
            try await runDeadlineChecks()
            group("observation")
            try await runObservationChecks()
            group("turn")
            try await runTurnChecks()
            group("stages")
            try await runStageChecks()
            group("short and empty")
            try await runShortAndEmptyChecks()
            group("interruption")
            try await runInterruptionChecks()
            group("failure")
            try await runFailureChecks()
            group("permission")
            try await runPermissionChecks()
            group("readiness")
            try await runReadinessChecks()
            group("voice and replay")
            try await runVoiceAndReplayChecks()
            group("session")
            try await runSessionChecks()
            group("keep warm")
            try await runKeepWarmChecks()
            group("quality")
            try await runQualityChecks()
            group("lifecycle")
            try await runLifecycleChecks()
            print("Interpreter contract checks passed (\(checksRun)/\(checksRun))")
        } catch let failure as CheckFailure {
            fputs("Interpreter check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("Interpreter checks threw: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
