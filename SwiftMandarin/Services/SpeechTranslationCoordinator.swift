//
//  SpeechTranslationCoordinator.swift
//  SwiftMandarin
//
//  The Interpreter's state machine: hold a button, speak, release, and hear
//  the translation. It sequences three stages — speech-to-text, translation,
//  speech output — and owns every decision about what happens when a press
//  is too short, nothing was said, something fails, or a new press arrives
//  while the last reply is still being spoken.
//
//  It knows nothing about the Speech, Translation or AVFoundation
//  frameworks. It drives the protocols in `InterpreterPipeline.swift`, so
//  the same code runs against the real services in the app and against
//  scripted stand-ins in `scripts/test-interpreter.sh`.
//
//  Three rules hold throughout:
//
//  1. A new press always wins over a reply. It stops speech at once and
//     takes the microphone; a translation still in progress is kept as text
//     and not spoken. It never wins over words: a press that lands while the
//     previous press is still being settled waits for it, and starts the
//     moment its transcript is in, if the button is still down.
//  2. Every asynchronous step carries the identity of the activity that
//     started it, and checks it is still the current one before touching
//     state. Late results therefore cannot overwrite a newer turn.
//  3. Translation and speech never start for a press shorter than
//     `InterpreterTuning.minimumHold`, or for an empty transcript.
//
//  One thing is done for speed alone. A turn is translated by one model,
//  chosen when the button goes down, and that model is kept warm for as long
//  as the button is held. Measured on the development Mac, a translation
//  model that has rested for a few seconds, or that follows a call to the
//  other model, answers 0.3–0.6 s late; a one-word translation every few
//  seconds of the hold removes that wait from the moment that matters, the
//  one after release.
//

import Foundation
import Observation
import os

@Observable
@MainActor
final class SpeechTranslationCoordinator {

    // MARK: - Observable state

    /// Where the current turn is. The only writer is this class.
    private(set) var state: PipelineState = .idle

    /// The conversation so far, oldest first.
    private(set) var turns: [InterpreterTurn] = []

    /// What is installed and permitted.
    private(set) var readiness = InterpreterReadiness()

    /// The transcript of the turn in progress: finalized text and the tail
    /// the recognizer may still rewrite.
    private(set) var liveTranscript = TranscriptSnapshot()

    /// The microphone is delivering audio. Becomes true slightly after
    /// `.listening` begins, and is what the button's "live" look follows.
    private(set) var isMicrophoneLive = false

    /// A short note for a press that produced nothing.
    private(set) var hint: InterpreterHint?

    /// The turn being spoken, for the card that shows a Stop control.
    private(set) var speakingTurnID: UUID?

    /// Whose turn is in progress, from press to the end of its reply. The
    /// button for this direction shows the turn's stage.
    private(set) var activeDirection: TranslationDirection?

    /// A press that is down and waiting: it arrived while the previous one
    /// was still being settled.
    private(set) var pendingPress: InterpreterPress?

    /// The button the waiting press is for, which shows it.
    var pendingPressDirection: TranslationDirection? { pendingPress?.direction }

    /// Goes up by one each time the screen should ask the system for the
    /// translation languages. Only a SwiftUI view can host that request, so
    /// the screen watches this number.
    private(set) var translationDownloadRequests = 0

    /// An Interpreter screen is on display. Observed, like everything a view
    /// reads to decide what to show: a screen builds its buttons before it
    /// has appeared, and must be told when that changes.
    private(set) var isActive = false

    /// The device has two translation models, so the screen has a setting to
    /// offer. False until the first readiness check has answered.
    private(set) var offersTranslationChoice = false

    /// A press can start a turn: the screen is active, every asset is in
    /// place, and nothing is being installed.
    var canStartTurn: Bool {
        // Read all three before deciding, so that whoever asked is told when
        // any of them changes, not only the first one that said no.
        let active = isActive
        let usable = readiness.assetsAreUsable
        let installing: Bool
        if case .preparingModels = state { installing = true } else { installing = false }
        return active && usable && !installing
    }

    // MARK: - Dependencies

    @ObservationIgnored private let transcriber: any InterpreterTranscribing
    @ObservationIgnored private let translator: any InterpreterTranslating
    @ObservationIgnored private let speaker: any InterpreterSpeaking
    @ObservationIgnored private let environment: any InterpreterEnvironment
    @ObservationIgnored private let clock: any InterpreterClock

    // MARK: - Bookkeeping

    /// One thing the coordinator is doing on the user's behalf: a turn from
    /// press to the end of its reply, or a replay.
    nonisolated private struct Activity: Sendable {
        let id: UUID
        let direction: TranslationDirection
        /// The model this turn is translated with, fixed at the press so that
        /// the one kept warm during the hold is the one that is used.
        let model: InterpreterTranslationModel
        let pressedAt: ContinuousClock.Instant
        /// Resolves to whether the microphone went live. `nil` for a replay.
        let beginTask: Task<Bool, Never>?
        var liveAt: ContinuousClock.Instant?
        var isReleased = false
    }

    /// What Retry does after a failure, when there is something to retry.
    nonisolated private enum RetryAction: Sendable {
        case translate(source: String, direction: TranslationDirection, timings: InterpreterTurnTimings)
        case speak(turnID: UUID)
    }

    @ObservationIgnored private var activity: Activity? {
        didSet { activeDirection = activity?.direction }
    }
    @ObservationIgnored private var retryAction: RetryAction?
    @ObservationIgnored private var pipelineTask: Task<Void, Never>?
    @ObservationIgnored private var startupTask: Task<Void, Never>?
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var hintTask: Task<Void, Never>?
    /// The most recent request to shut the microphone. A new turn waits for
    /// it, so a teardown can never land on the turn that follows it.
    @ObservationIgnored private var captureTeardown: Task<Void, Never>?
    /// Touches the turn's translation model while the button is held.
    @ObservationIgnored private var keepWarmTask: Task<Void, Never>?
    /// Automatic quality: how many turns in a row the natural model has been
    /// too slow for, and whether that has moved this visit to the fast one.
    @ObservationIgnored private var slowNaturalTurns = 0
    @ObservationIgnored private var automaticUsesFastModel = false
    /// How many screens are showing the Interpreter. `isActive` follows it.
    @ObservationIgnored private var activationCount = 0 {
        didSet {
            let active = activationCount > 0
            if isActive != active { isActive = active }
        }
    }
    /// Whether the hold on the audio session is in place. Only the steps of
    /// `conversationAudioWork` change it, one at a time, so it is always what
    /// the last step to run left behind.
    @ObservationIgnored private var conversationAudioIsOpen = false
    /// Goes up with every request to give the session back, so that a
    /// request to open it that has not had its turn yet can tell it is no
    /// longer wanted.
    @ObservationIgnored private var conversationAudioCloses = 0
    /// Every opening and every hand-back of the audio session, each waiting
    /// for the one before it. The app's audio-session coordinator carries
    /// out what it is asked in the order it is asked, however long each
    /// takes. Two of these in flight at once could therefore land in the
    /// wrong order: the hand-back of a session opened for an earlier visit,
    /// asked for after the request that opens it for this one.
    @ObservationIgnored private var conversationAudioWork: Task<Void, Never>?
    /// Identifies the download in progress. One that was abandoned finishes
    /// later, since an installation cannot be cancelled, and must not write
    /// over what came after it.
    @ObservationIgnored private var downloadToken: UUID?

    @ObservationIgnored private let signposter = OSSignposter(
        subsystem: "com.rogerlin.SwiftMandarin",
        category: "Interpreter"
    )
    @ObservationIgnored private let log = Logger(
        subsystem: "com.rogerlin.SwiftMandarin",
        category: "Interpreter"
    )

    init(
        transcriber: any InterpreterTranscribing,
        translator: any InterpreterTranslating,
        speaker: any InterpreterSpeaking,
        environment: any InterpreterEnvironment,
        clock: any InterpreterClock = SystemInterpreterClock()
    ) {
        self.transcriber = transcriber
        self.translator = translator
        self.speaker = speaker
        self.environment = environment
        self.clock = clock
    }

    // MARK: - Screen lifecycle

    /// The Interpreter screen appeared. Checks what is installed and, when
    /// everything is, loads the models so the first press does not wait.
    /// Balanced by `deactivate()`; several windows may be active at once.
    func activate() {
        activationCount += 1
        guard activationCount == 1 else { return }
        startupTask = Task { [weak self] in
            await self?.startUp()
        }
    }

    /// The Interpreter screen went away. When the last one does, everything
    /// in progress stops, the audio session is given back, and the models
    /// are released.
    func deactivate() {
        guard activationCount > 0 else { return }
        activationCount -= 1
        guard activationCount == 0 else { return }

        startupTask?.cancel()
        startupTask = nil
        downloadTask?.cancel()
        downloadTask = nil
        downloadToken = nil
        pipelineTask?.cancel()
        pipelineTask = nil
        stopKeepingTranslationWarm()
        clearHint()
        pendingPress = nil
        // The next visit gives the natural model a fresh chance.
        slowNaturalTurns = 0
        automaticUsesFastModel = false

        speaker.stop()
        let wasCapturing = activity?.beginTask != nil
        activity = nil
        retryAction = nil
        isMicrophoneLive = false
        speakingTurnID = nil
        liveTranscript = TranscriptSnapshot()
        state = .idle
        if wasCapturing {
            scheduleCaptureTeardown()
        }
        closeConversationAudio()

        // Releasing the models joins the teardown chain, so a press on the
        // next visit waits for it instead of losing its recognizer to it.
        let teardown = captureTeardown
        captureTeardown = Task { [transcriber] in
            await teardown?.value
            await transcriber.releaseResources()
        }
    }

    /// The scene lost focus for a moment (a system sheet, the app switcher,
    /// another window taking key). A held press cannot be trusted to end
    /// normally, so the microphone closes; a reply in progress carries on.
    func sceneBecameInactive() {
        // A button that was waiting its turn is no more trustworthy than one
        // that was recording.
        pendingPress = nil
        cancelCapture()
    }

    /// The app left the foreground: stop everything and give the audio
    /// session back so other apps' audio can resume.
    func sceneEnteredBackground() {
        pendingPress = nil
        switch state {
        case .listening:
            cancelCapture()
        case .finalizingTranscript:
            // The reply could only be spoken from the background. Give the
            // turn up, and stop the recognizer before the session goes.
            scheduleCaptureTeardown()
            prepareRecognizer(for: activity?.direction)
            endActivity()
            liveTranscript = TranscriptSnapshot()
        case .translating:
            // The translation is kept as text when it arrives. It is not
            // spoken: nobody is looking at the app.
            endActivity()
            liveTranscript = TranscriptSnapshot()
        case .speaking:
            stopSpeaking()
        case .idle, .preparingModels, .error:
            break
        }
        closeConversationAudio()
    }

    /// The app is frontmost again. Permissions and downloads may have
    /// changed while it was away.
    func sceneBecameActive() {
        guard isActive, startupTask == nil else { return }
        startupTask = Task { [weak self] in
            await self?.startUp()
        }
    }

    private func startUp() async {
        await refreshReadiness()
        // A model can already be on its way, started by this app earlier or
        // by another. Look again until it has arrived or stopped.
        while isActive, !Task.isCancelled, readiness.isDownloading {
            do {
                try await clock.sleep(for: InterpreterTuning.downloadPollInterval)
            } catch {
                break
            }
            guard isActive, !Task.isCancelled else { break }
            await refreshReadiness()
        }
        if isActive, !Task.isCancelled {
            await warmUpIfReady()
        }
        // A start-up that was cancelled has been replaced by the next visit's;
        // only the current one clears the handle.
        if !Task.isCancelled {
            startupTask = nil
        }
    }

    private func refreshReadiness() async {
        var updated = readiness
        updated.microphone = environment.microphonePermission
        updated.englishSpeech = await transcriber.assetState(for: .englishToChinese)
        updated.chineseSpeech = await transcriber.assetState(for: .chineseToEnglish)
        updated.translation = await translator.assetState()
        readiness = updated
        let hasChoice = translator.offersTwoModels
        if offersTranslationChoice != hasChoice {
            offersTranslationChoice = hasChoice
        }
    }

    /// Loads the recognizers and translation models, and opens the audio
    /// session, so none of that work lands on a press.
    private func warmUpIfReady() async {
        guard isActive, readiness.assetsAreUsable else { return }
        if environment.microphonePermission.allowsCapture {
            try? await openConversationAudio()
        }
        guard isActive, !Task.isCancelled else { return }
        await transcriber.prepare(for: .englishToChinese)
        guard isActive, !Task.isCancelled else { return }
        await transcriber.prepare(for: .chineseToEnglish)
        guard isActive, !Task.isCancelled else { return }
        // Only the model the turns will use: loading the other one after it
        // would leave the wrong one in memory.
        let model = modelForNextTurn
        await translator.warm(.englishToChinese, model: model)
        guard isActive, !Task.isCancelled else { return }
        await translator.warm(.chineseToEnglish, model: model)
    }

    /// Configures the audio session for the conversation, once. It then stays
    /// that way between turns, so a press does not pay for it again; an
    /// interruption or the background gives it back, and the next press
    /// opens it again.
    ///
    /// Returns when the request has had its turn. If the session was asked
    /// back in the meantime it is not open on return, and whatever asked for
    /// it has been stopped by the same event; callers check that they are
    /// still wanted before going on.
    private func openConversationAudio() async throws {
        // Read before any waiting: a hand-back asked for during the wait has
        // to be seen.
        let closes = conversationAudioCloses
        let earlier = conversationAudioWork
        // These steps hold on to `self` until they have run. One that was
        // dropped would leave the session held, or given back, out of turn.
        let opening = Task { () -> Result<Void, any Error> in
            await earlier?.value
            // Asked back before its turn came, or open already.
            guard closes == self.conversationAudioCloses, !self.conversationAudioIsOpen else {
                return .success(())
            }
            do {
                try await self.environment.beginConversationAudio()
            } catch {
                return .failure(error)
            }
            // A hand-back asked for while this was opening is next in line,
            // and gives back what it finds open.
            self.conversationAudioIsOpen = true
            return .success(())
        }
        conversationAudioWork = Task { _ = await opening.value }
        try await opening.value.get()
    }

    /// Gives the audio session back, after whatever opening or hand-back is
    /// already under way. The microphone is shut first: a session cannot be
    /// deactivated while audio is still running through it.
    private func closeConversationAudio() {
        conversationAudioCloses += 1
        let teardown = captureTeardown
        let earlier = conversationAudioWork
        conversationAudioWork = Task {
            await earlier?.value
            guard self.conversationAudioIsOpen else { return }
            self.conversationAudioIsOpen = false
            await teardown?.value
            self.environment.endConversationAudio()
        }
    }

    // MARK: - Downloads

    /// The Download button. Installs missing speech models, showing their
    /// progress, then asks the screen to request the translation languages.
    func downloadModels() {
        guard isActive, downloadTask == nil, !state.isBusy else { return }
        retryAction = nil
        state = .preparingModels(progress: nil)
        let token = UUID()
        downloadToken = token
        downloadTask = Task { [weak self] in
            await self?.runDownload(token)
        }
    }

    private func runDownload(_ token: UUID) async {
        defer {
            if downloadToken == token {
                downloadToken = nil
                downloadTask = nil
            }
        }
        do {
            let speechStates = [readiness.englishSpeech, readiness.chineseSpeech]
            if speechStates.contains(where: { !$0.isUsable && $0 != .unsupported }) {
                try await transcriber.installAssets { [weak self] progress in
                    guard let self, self.downloadToken == token, case .preparingModels = self.state else { return }
                    self.state = .preparingModels(progress: progress)
                }
            }
            guard isActive, downloadToken == token else { return }
            await refreshReadiness()
            guard isActive, downloadToken == token else { return }

            if readiness.translation == .needsDownload {
                // Only the system can install translation languages, and only
                // from a view. The screen reports back through
                // `translationLanguagesPrepared()`.
                translationDownloadRequests += 1
            }
            if case .preparingModels = state {
                state = .idle
            }
            await warmUpIfReady()
        } catch is CancellationError {
            guard downloadToken == token else { return }
            if case .preparingModels = state {
                state = .idle
            }
        } catch {
            guard isActive, downloadToken == token else { return }
            await refreshReadiness()
            guard isActive, downloadToken == token else { return }
            fail(Self.interpreterError(from: error) { .speechAssetInstallFailed(reason: $0) })
        }
    }

    /// The system finished (or the user dismissed) the translation-language
    /// request. Check what is installed now.
    func translationLanguagesPrepared() {
        guard isActive else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.refreshReadiness()
            await self.warmUpIfReady()
        }
    }

    // MARK: - Press and release

    /// A hold-to-speak input went down: a finger or the pointer on a button,
    /// or the Space bar.
    ///
    /// Returns the press when it was taken, whether it started at once or is
    /// waiting its turn, and nil when it was ignored. The input keeps what it
    /// is given and hands it to `pressUp(_:)` when it comes up, so an input
    /// whose press was ignored has nothing to release.
    @discardableResult
    func pressDown(_ direction: TranslationDirection) -> InterpreterPress? {
        guard canStartTurn else { return nil }
        let press = InterpreterPress(direction: direction)
        switch state {
        case .listening:
            // The first input down owns the microphone until it is released.
            // A press that lands after that release, while the released
            // press is still being settled, waits its turn.
            guard activity?.isReleased == true else { return nil }
            pendingPress = press
        case .finalizingTranscript:
            // Taking the microphone now would throw away the words that were
            // just spoken. This press starts when they are in.
            pendingPress = press
        case .idle, .preparingModels, .translating, .speaking, .error:
            startPress(press)
        }
        return press
    }

    private func startPress(_ press: InterpreterPress) {
        pendingPress = nil
        // A new press wins over a reply: silence it, and leave whatever the
        // previous turn had not finished unspoken.
        speaker.stop()
        speakingTurnID = nil
        clearHint()
        retryAction = nil

        // The turn is known by its press, which is how a release finds it.
        let id = press.id
        let direction = press.direction
        signposter.emitEvent("Press")
        liveTranscript = TranscriptSnapshot()
        isMicrophoneLive = false
        state = .listening(direction: direction, liveTranscript: "")

        let beginTask = Task { [weak self] () -> Bool in
            guard let self else { return false }
            return await self.beginCapture(activityID: id, direction: direction)
        }
        let model = modelForNextTurn
        activity = Activity(
            id: id,
            direction: direction,
            model: model,
            pressedAt: clock.now,
            beginTask: beginTask
        )
        keepTranslationWarm(activityID: id, direction: direction, model: model)
    }

    /// Starts the press that was waiting, if its input is still down.
    @discardableResult
    private func startPendingPress() -> Bool {
        guard let press = pendingPress else { return false }
        pendingPress = nil
        guard canStartTurn else { return false }
        startPress(press)
        return true
    }

    /// The input that made `press` came up. Ends that press and no other. A
    /// press that was still waiting is forgotten. A release for any press
    /// but the one that is recording changes nothing: that covers a press
    /// that was ended some other way while its input stayed down, after
    /// which another input may be holding the same button.
    func pressUp(_ press: InterpreterPress) {
        if pendingPress == press {
            pendingPress = nil
            return
        }
        guard case .listening = state, activity?.id == press.id else { return }
        pressUp()
    }

    /// The input that made `press` is gone while it was still down: its
    /// screen closed. The press is given up without translating or speaking,
    /// and any other press is left alone.
    func cancelPress(_ press: InterpreterPress) {
        if pendingPress == press {
            pendingPress = nil
            return
        }
        guard activity?.id == press.id else { return }
        cancelCapture()
    }

    /// Whatever is being held was released.
    func pressUp() {
        guard case .listening = state, var turn = activity, !turn.isReleased else { return }
        let releasedAt = clock.now
        turn.isReleased = true
        activity = turn
        isMicrophoneLive = false
        stopKeepingTranslationWarm()
        signposter.emitEvent("Release")

        pipelineTask = Task { [weak self] in
            await self?.completeTurn(turn, releasedAt: releasedAt)
        }
    }

    /// Closes the microphone and forgets the turn in progress, without
    /// translating or speaking. Used when a press can no longer be trusted
    /// to end normally. Does nothing unless the microphone is in use.
    func cancelCapture() {
        guard case .listening = state else { return }
        pendingPress = nil
        let direction = activity?.direction
        endActivity()
        liveTranscript = TranscriptSnapshot()
        scheduleCaptureTeardown()
        prepareRecognizer(for: direction)
    }

    /// The audio session was taken away (a phone call, a disconnected
    /// headset). The turn in progress cannot continue.
    func audioSessionLost(message: String) {
        switch state {
        case .listening, .finalizingTranscript:
            let direction = activity?.direction
            scheduleCaptureTeardown()
            prepareRecognizer(for: direction)
            fail(InterpreterError.audioInterrupted(reason: message))
        case .translating:
            // The words are kept as text when their translation arrives. A
            // reply spoken into a session that was just taken away would be
            // lost, or would talk over the call that took it.
            endActivity()
            liveTranscript = TranscriptSnapshot()
        case .speaking:
            stopSpeaking()
        case .idle, .preparingModels, .error:
            break
        }
        // The session is no longer this screen's to rely on. Give the hold
        // on it back, so that nothing else takes it for held and active; the
        // next press opens it again.
        closeConversationAudio()
    }

    private func beginCapture(activityID: UUID, direction: TranslationDirection) async -> Bool {
        // Let any earlier teardown finish first, so it cannot close the
        // microphone this turn is about to open.
        await captureTeardown?.value
        guard isCurrent(activityID) else { return false }

        do {
            switch environment.microphonePermission {
            case .granted, .notRequired:
                break
            case .undetermined, .unknown:
                let granted = await environment.requestMicrophonePermission()
                readiness.microphone = granted ? .granted : .denied
                guard isCurrent(activityID) else { return false }
                guard granted else { throw InterpreterError.microphoneDenied }
                // The system prompt interrupted the press, so the finger is
                // no longer a deliberate hold. Start clean on the next press.
                endActivity()
                return false
            case .denied:
                throw InterpreterError.microphoneDenied
            }

            await environment.stopOtherAudio()
            guard isCurrent(activityID) else { return false }
            try await openConversationAudio()
            guard isCurrent(activityID) else { return false }

            // The button came up before the microphone could open. Opening
            // it now would record after the release, and there is nothing
            // from before it to record.
            guard activity?.isReleased == false else {
                endActivity()
                liveTranscript = TranscriptSnapshot()
                showHint(.holdToSpeak)
                startPendingPress()
                return false
            }

            try await transcriber.begin(direction: direction) { [weak self] snapshot in
                self?.transcriptUpdated(snapshot, activityID: activityID)
            }
            // Whoever replaced this turn has already scheduled the teardown.
            guard isCurrent(activityID) else { return false }

            let liveAt = clock.now
            activity?.liveAt = liveAt
            signposter.emitEvent("MicrophoneLive")
            if activity?.isReleased == false {
                isMicrophoneLive = true
            }
            return true
        } catch is CancellationError {
            // Whoever cancelled it has normally settled the state already.
            // If nobody has, a press must not be left listening for ever.
            if isCurrent(activityID) {
                endActivity()
                liveTranscript = TranscriptSnapshot()
            }
            return false
        } catch {
            guard isCurrent(activityID) else { return false }
            fail(Self.interpreterError(from: error) { .captureFailed(reason: $0) })
            return false
        }
    }

    private func transcriptUpdated(_ snapshot: TranscriptSnapshot, activityID: UUID) {
        guard isCurrent(activityID), case .listening(let direction, _) = state else { return }
        liveTranscript = snapshot
        state = .listening(direction: direction, liveTranscript: snapshot.text)
    }

    // MARK: - The turn, after release

    private func completeTurn(_ turn: Activity, releasedAt: ContinuousClock.Instant) async {
        let microphoneWentLive = await turn.beginTask?.value ?? false
        // A failed or abandoned start has already settled the state. A press
        // that was waiting behind it does not start: whatever stopped this
        // one would stop that one too.
        guard isCurrent(turn.id), microphoneWentLive else {
            pendingPress = nil
            return
        }

        let held = releasedAt - turn.pressedAt
        var timings = InterpreterTurnTimings()
        timings.held = held.interpreterMilliseconds
        if let liveAt = activity?.liveAt {
            timings.pressToLive = (liveAt - turn.pressedAt).interpreterMilliseconds
        }

        guard held >= InterpreterTuning.minimumHold else {
            // A slip, not speech: close the microphone and say nothing.
            endActivity()
            liveTranscript = TranscriptSnapshot()
            showHint(.holdToSpeak)
            scheduleCaptureTeardown()
            prepareRecognizer(for: turn.direction)
            // A real hold that followed the slip at once starts now.
            startPendingPress()
            return
        }

        state = .finalizingTranscript
        let transcript: String
        do {
            transcript = try await transcriber.finish()
        } catch is CancellationError {
            // Torn down on purpose, and whoever did it has normally settled
            // the state. If nobody has, the turn must not stay finalizing.
            pendingPress = nil
            if isCurrent(turn.id) {
                endActivity()
                liveTranscript = TranscriptSnapshot()
            }
            return
        } catch {
            guard isCurrent(turn.id) else { return }
            prepareRecognizer(for: turn.direction)
            fail(Self.interpreterError(from: error) { .recognitionFailed(reason: $0) })
            return
        }
        guard isCurrent(turn.id) else { return }

        let transcriptAt = clock.now
        timings.releaseToTranscript = (transcriptAt - releasedAt).interpreterMilliseconds
        signposter.emitEvent("Transcript")

        // The recognizer for this direction was used up by the turn. Load the
        // next one while the reply is being translated and spoken.
        let direction = turn.direction
        prepareRecognizer(for: direction)

        let source = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            endActivity()
            liveTranscript = TranscriptSnapshot()
            showHint(.nothingHeard)
            startPendingPress()
            return
        }

        liveTranscript = TranscriptSnapshot(finalized: source)
        // A press that waited for these words starts now. The words are still
        // translated and kept, but not spoken: the reply would talk over the
        // person who is already speaking.
        startPendingPress()
        await translateAndSpeak(
            source: source,
            direction: direction,
            model: turn.model,
            activityID: turn.id,
            timings: timings,
            transcriptAt: transcriptAt,
            releasedAt: releasedAt
        )
    }

    private func translateAndSpeak(
        source: String,
        direction: TranslationDirection,
        model requestedModel: InterpreterTranslationModel,
        activityID: UUID,
        timings initialTimings: InterpreterTurnTimings,
        transcriptAt: ContinuousClock.Instant,
        releasedAt: ContinuousClock.Instant?
    ) async {
        var timings = initialTimings
        // An overtaken turn is translated behind the one that overtook it.
        if isCurrent(activityID) {
            state = .translating(sourceText: source)
        }

        var model = requestedModel
        let translation: String
        do {
            do {
                translation = try await translate(source, direction: direction, model: model)
            } catch let error where canFallBackToFastModel(from: model, after: error) {
                // Automatic quality: the natural model failed where the fast
                // one may not, so later turns, and Try Again, use the fast one.
                automaticUsesFastModel = true
                // A translation that ran out of time is still running, and
                // cannot be stopped; a second one would only wait behind it.
                if case .translationTimedOut? = error as? InterpreterError { throw error }
                model = .fast
                translation = try await translate(source, direction: direction, model: model)
            }
        } catch is CancellationError {
            return
        } catch {
            // A newer turn is underway; this one failed quietly.
            guard isCurrent(activityID) else { return }
            fail(
                Self.interpreterError(from: error) { .translationFailed(reason: $0) },
                retry: .translate(source: source, direction: direction, timings: timings)
            )
            return
        }

        let translatedAt = clock.now
        let translationTook = translatedAt - transcriptAt
        timings.transcriptToTranslation = translationTook.interpreterMilliseconds
        signposter.emitEvent("Translation")
        // Only a turn whose reply is still awaited says anything about the
        // model's speed. One that a newer press has overtaken was translated
        // behind that press's warm-up, and nobody was waiting for it.
        if model == .natural, requestedModel == .natural, isCurrent(activityID) {
            noteNaturalTranslation(took: translationTook, heldMilliseconds: timings.held)
        }

        let translated = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else {
            guard isCurrent(activityID) else { return }
            fail(
                InterpreterError.translationFailed(
                    reason: String(localized: "The translation came back empty.", bundle: .appLanguage)
                ),
                retry: .translate(source: source, direction: direction, timings: timings)
            )
            return
        }

        // The turn is complete as text whether or not it is spoken, so it is
        // recorded even when a newer press has taken over in the meantime.
        let turn = InterpreterTurn(
            direction: direction,
            sourceText: source,
            translatedText: translated,
            translatedWith: model,
            spokenWith: environment.voiceEngine,
            timings: timings
        )
        turns.append(turn)
        environment.record(source: source, translation: translated, direction: direction)

        guard isCurrent(activityID) else { return }
        liveTranscript = TranscriptSnapshot()
        state = .speaking(sourceText: source, translatedText: translated)
        speakingTurnID = turn.id
        await speak(turn, activityID: activityID, translatedAt: translatedAt, releasedAt: releasedAt)
    }

    /// One translation, given up on after `InterpreterTuning.translationTimeout`.
    private func translate(
        _ source: String,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) async throws -> String {
        try await withInterpreterDeadline(
            InterpreterTuning.translationTimeout,
            clock: clock,
            timeoutError: .translationTimedOut
        ) { [translator] in
            try await translator.translate(source, direction: direction, model: model)
        }
    }

    // MARK: - Translation model

    /// The model the next turn is translated with.
    private var modelForNextTurn: InterpreterTranslationModel {
        switch environment.translationQuality {
        case .natural: return .natural
        case .fast: return .fast
        case .automatic: return automaticUsesFastModel ? .fast : .natural
        }
    }

    /// Automatic quality answers a failed natural translation with the fast
    /// model, where the device has both. A cancellation is not a failure,
    /// and a missing language pack is missing for both.
    private func canFallBackToFastModel(from model: InterpreterTranslationModel, after error: any Error) -> Bool {
        guard model == .natural,
              environment.translationQuality == .automatic,
              translator.offersTwoModels,
              !(error is CancellationError) else { return false }
        switch error as? InterpreterError {
        case .translationLanguagesMissing, .translationUnsupported: return false
        default: return true
        }
    }

    /// Automatic quality: a natural translation that outlasts its allowance
    /// twice in a row moves the rest of this visit to the fast model. One
    /// slow turn can be the system being busy; two is the device.
    private func noteNaturalTranslation(took elapsed: Duration, heldMilliseconds: Int?) {
        guard environment.translationQuality == .automatic,
              translator.offersTwoModels,
              !automaticUsesFastModel else { return }
        let allowance = InterpreterTuning.naturalTranslationAllowance(heldMilliseconds: heldMilliseconds)
        guard elapsed > allowance else {
            slowNaturalTurns = 0
            return
        }
        slowNaturalTurns += 1
        if slowNaturalTurns >= InterpreterTuning.slowNaturalTurnsBeforeFast {
            automaticUsesFastModel = true
        }
    }

    /// Touches the turn's translation model now and again every few seconds
    /// for as long as the button stays down, so the translation that follows
    /// the release starts from a loaded model. The first touch also absorbs
    /// whatever a cold or just-switched model costs, while the person is
    /// still speaking.
    private func keepTranslationWarm(
        activityID: UUID,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) {
        keepWarmTask?.cancel()
        keepWarmTask = Task { [weak self, translator, clock] in
            while !Task.isCancelled {
                await translator.warm(direction, model: model)
                do {
                    try await clock.sleep(for: InterpreterTuning.translationKeepWarmInterval)
                } catch {
                    return
                }
                guard let self, self.isCurrent(activityID), self.activity?.isReleased == false else { return }
            }
        }
    }

    private func stopKeepingTranslationWarm() {
        keepWarmTask?.cancel()
        keepWarmTask = nil
    }

    private func speak(
        _ turn: InterpreterTurn,
        activityID: UUID,
        translatedAt: ContinuousClock.Instant?,
        releasedAt: ContinuousClock.Instant?
    ) async {
        do {
            try await speaker.speak(
                turn.translatedText,
                languageCode: turn.direction.targetSpeechCode,
                engine: turn.spokenWith
            ) { [weak self] voice in
                self?.speechStarted(turnID: turn.id, voice: voice, translatedAt: translatedAt, releasedAt: releasedAt)
            }
            signposter.emitEvent("SpeechEnd")
            updateTurn(turn.id) { $0.speechFailure = nil }
        } catch is CancellationError {
            // Stopped on purpose: a new press, Stop, or leaving the screen.
        } catch {
            let message = error.localizedDescription
            updateTurn(turn.id) { $0.speechFailure = message }
            guard isCurrent(activityID) else { return }
            fail(InterpreterError.speechOutputFailed(reason: message), retry: .speak(turnID: turn.id))
            return
        }
        guard isCurrent(activityID) else { return }
        endActivity()
    }

    private func speechStarted(
        turnID: UUID,
        voice: SpeechVoiceEngine,
        translatedAt: ContinuousClock.Instant?,
        releasedAt: ContinuousClock.Instant?
    ) {
        let startedAt = clock.now
        signposter.emitEvent("SpeechStart")
        updateTurn(turnID) { turn in
            // The voice that is speaking, which is the system's when a
            // MiniMax request fell back to it.
            turn.spokenWith = voice
            if let translatedAt {
                turn.timings.translationToSpeech = (startedAt - translatedAt).interpreterMilliseconds
            }
            if let releasedAt {
                turn.timings.releaseToSpeech = (startedAt - releasedAt).interpreterMilliseconds
            }
        }
        if let turn = turns.first(where: { $0.id == turnID }), releasedAt != nil {
            let timings = turn.timings
            // Numbers and the model's name only: what was said never goes to
            // the log.
            log.debug(
                """
                Interpreter turn: model=\(turn.translatedWith.rawValue, privacy: .public) \
                pressToLive=\(timings.pressToLive ?? -1, privacy: .public)ms \
                releaseToTranscript=\(timings.releaseToTranscript ?? -1, privacy: .public)ms \
                transcriptToTranslation=\(timings.transcriptToTranslation ?? -1, privacy: .public)ms \
                translationToSpeech=\(timings.translationToSpeech ?? -1, privacy: .public)ms \
                releaseToSpeech=\(timings.releaseToSpeech ?? -1, privacy: .public)ms
                """
            )
        }
    }

    // MARK: - Replay, stop, retry

    /// Speaks a finished turn again, with the voice that spoke it first.
    func replay(_ turnID: UUID) {
        guard isActive, let turn = turns.first(where: { $0.id == turnID }) else { return }
        switch state {
        case .idle, .error, .speaking:
            break
        case .preparingModels, .listening, .finalizingTranscript, .translating:
            return
        }
        speaker.stop()
        clearHint()
        retryAction = nil

        let id = UUID()
        activity = Activity(
            id: id,
            direction: turn.direction,
            model: turn.translatedWith,
            pressedAt: clock.now,
            beginTask: nil,
            isReleased: true
        )
        state = .speaking(sourceText: turn.sourceText, translatedText: turn.translatedText)
        speakingTurnID = turn.id
        pipelineTask = Task { [weak self] in
            guard let self else { return }
            if self.environment.microphonePermission.allowsCapture {
                try? await self.openConversationAudio()
            }
            guard self.isCurrent(id) else { return }
            await self.speak(turn, activityID: id, translatedAt: nil, releasedAt: nil)
        }
    }

    /// Stops the reply being spoken. The turn stays in the conversation.
    func stopSpeaking() {
        guard case .speaking = state else { return }
        speaker.stop()
        endActivity()
    }

    /// The action offered beside an error. Opening Settings is the screen's
    /// job, since only it can reach the platform's Settings; this just
    /// clears the error for that case.
    func performRecovery() {
        guard case .error(let error) = state else { return }
        switch error.recovery {
        case .none, .openSettings:
            dismissError()
        case .downloadModels:
            state = .idle
            downloadModels()
        case .retry:
            let action = retryAction
            retryAction = nil
            switch action {
            case .translate(let source, let direction, let timings):
                let id = UUID()
                let now = clock.now
                let model = modelForNextTurn
                activity = Activity(
                    id: id,
                    direction: direction,
                    model: model,
                    pressedAt: now,
                    beginTask: nil,
                    isReleased: true
                )
                pipelineTask = Task { [weak self] in
                    await self?.translateAndSpeak(
                        source: source,
                        direction: direction,
                        model: model,
                        activityID: id,
                        timings: timings,
                        transcriptAt: now,
                        releasedAt: nil
                    )
                }
            case .speak(let turnID):
                state = .idle
                replay(turnID)
            case nil:
                state = .idle
            }
        }
    }

    func dismissError() {
        guard case .error = state else { return }
        retryAction = nil
        state = .idle
    }

    /// Empties the conversation. Not offered while a turn is in progress.
    func clearConversation() {
        guard !state.isBusy else { return }
        turns.removeAll()
        speakingTurnID = nil
    }

    // MARK: - Helpers

    private func isCurrent(_ id: UUID) -> Bool {
        activity?.id == id
    }

    /// The current activity is over and nothing went wrong.
    private func endActivity() {
        stopKeepingTranslationWarm()
        activity = nil
        isMicrophoneLive = false
        speakingTurnID = nil
        state = .idle
    }

    private func fail(_ error: InterpreterError, retry: RetryAction? = nil) {
        stopKeepingTranslationWarm()
        pendingPress = nil
        activity = nil
        isMicrophoneLive = false
        speakingTurnID = nil
        liveTranscript = TranscriptSnapshot()
        retryAction = retry
        state = .error(error.userFacing)
    }

    /// Services throw `InterpreterError`. Anything else is wrapped by the
    /// stage it happened in, keeping the system's own description.
    private static func interpreterError(
        from error: any Error,
        otherwise wrap: (String) -> InterpreterError
    ) -> InterpreterError {
        if let known = error as? InterpreterError { return known }
        return wrap(error.localizedDescription)
    }

    private func updateTurn(_ id: UUID, _ change: (inout InterpreterTurn) -> Void) {
        guard let index = turns.firstIndex(where: { $0.id == id }) else { return }
        change(&turns[index])
    }

    /// A turn uses up the recognizer for its direction, whether it ends in a
    /// transcript or is thrown away. This loads the next one, after whatever
    /// teardown is queued, so the following press only has to open the
    /// microphone. Not once the screen has closed, which released the models.
    private func prepareRecognizer(for direction: TranslationDirection?) {
        guard let direction else { return }
        let teardown = captureTeardown
        Task { [weak self, transcriber] in
            await teardown?.value
            guard self?.isActive == true else { return }
            await transcriber.prepare(for: direction)
        }
    }

    /// Asks the transcriber to shut the microphone, after any teardown that
    /// is already queued. The next turn waits on the tail of this chain.
    private func scheduleCaptureTeardown() {
        let previous = captureTeardown
        captureTeardown = Task { [transcriber] in
            await previous?.value
            await transcriber.cancel()
        }
    }

    private func showHint(_ newHint: InterpreterHint) {
        hintTask?.cancel()
        hint = newHint
        hintTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: InterpreterTuning.hintDuration)
            } catch {
                return
            }
            guard let self, self.hint == newHint else { return }
            self.hint = nil
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hintTask = nil
        hint = nil
    }
}
