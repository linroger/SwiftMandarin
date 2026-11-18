//
//  InterpreterSelfTest.swift
//  SwiftMandarin
//
//  An end-to-end run of the real Interpreter pipeline inside the real app:
//  the real recognizer, the real translation models, the real state machine,
//  and — when asked — the real microphone and the real voices.
//
//  It exists because the Speech and Translation frameworks cannot be driven
//  from a command-line check, and a person holding a button cannot be put in
//  a script. Speech is therefore synthesized in memory and fed to the
//  recognizer through the same path a microphone buffer takes, at the pace a
//  microphone would deliver it. Nothing is played aloud unless
//  `-InterpreterSelfTestAudible` is passed.
//
//  The whole file compiles only with the INTERPRETER_SELFTEST condition,
//  which scripts/run-interpreter-selftest.sh sets. No shipping build, Debug
//  or Release, contains it.
//
//      -InterpreterSelfTest            run and exit (required)
//      -InterpreterSelfTestMicrophone  also open the real microphone for one
//                                      second, if the app is already allowed
//                                      to use it (it never asks)
//      -InterpreterSelfTestAudible     speak the replies through SpeechService
//      -InterpreterSelfTestMiniMax     also time a MiniMax request, streaming
//                                      and not, with the stored API key
//      -InterpreterSelfTestNoKeepWarm  leave the translation model alone while
//                                      the button is held, to measure what
//                                      keeping it warm is worth
//
//  Two more arguments exist for screenshots taken from a script, and do not
//  run the self-test:
//
//      -InterpreterShowScreen          open the Interpreter without a tap
//      -InterpreterSnapshotWindow      macOS, with the above: print the
//                                      window as a base64 PNG and exit
//

#if INTERPRETER_SELFTEST

#if os(macOS)
import AppKit
import SwiftUI
#endif
@preconcurrency import AVFAudio
import Foundation
import os

@MainActor
enum InterpreterSelfTestLauncher {
    /// Called from the app's initializer. Does nothing unless the launch
    /// arguments ask for the self-test.
    static func startIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-InterpreterShowScreen") {
            showScreen(printingWindow: arguments.contains("-InterpreterSnapshotWindow"))
            return
        }
        guard arguments.contains("-InterpreterSelfTest") else { return }
        // Lines appear as they are printed, so a step that stalls is visible.
        setlinebuf(stdout)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            print("SELFTEST requires iOS 26 or macOS 26")
            exit(2)
        }
        Task { @MainActor in
            await InterpreterSelfTest.run(
                audible: arguments.contains("-InterpreterSelfTestAudible"),
                probesMiniMax: arguments.contains("-InterpreterSelfTestMiniMax"),
                keepsWarm: !arguments.contains("-InterpreterSelfTestNoKeepWarm"),
                opensMicrophone: arguments.contains("-InterpreterSelfTestMicrophone")
            )
        }
    }
}

// MARK: - Screenshots from a script

extension InterpreterSelfTestLauncher {
    /// Opens the Interpreter the way the Study hub's row does. A script can
    /// then photograph the screen without touching it, which matters where
    /// touching would need a permission nobody is there to give.
    private static func showScreen(printingWindow: Bool) {
        Task { @MainActor in
            // Long enough for the first scene to be on screen, even on a
            // simulator that has just booted; a route set before then is lost.
            try? await Task.sleep(for: .seconds(8))
            AppRouteStore.shared.openStudy(route: "interpreter")
            #if os(macOS)
            guard printingWindow else { return }
            setlinebuf(stdout)
            // Launched from a script the app may have no window of its own
            // (macOS restores the windows it had, and that can be none), so
            // the screen is put in one made for the purpose.
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            let host = NSHostingController(rootView: NavigationStack { InterpreterView() }.localizedSurface())
            host.sceneBridgingOptions = [.toolbars, .title]
            window.contentViewController = host
            window.setContentSize(NSSize(width: 980, height: 720))
            window.center()
            window.makeKeyAndOrderFront(nil)
            // Long enough for the readiness check to settle.
            try? await Task.sleep(for: .seconds(5))
            if let png = png(of: window) {
                print("SNAPSHOT \(png.base64EncodedString())")
            } else {
                print("SNAPSHOT-FAILED")
            }
            exit(0)
            #endif
        }
    }

    #if os(macOS)
    /// A window of the app's own, drawn by the app into a bitmap. Unlike a
    /// screen capture this needs no screen-recording permission.
    private static func png(of window: NSWindow) -> Data? {
        guard let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return nil
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }
    #endif
}

// MARK: - Stand-ins that keep the run silent and hands-free

/// Delivers a synthesized sentence to the tap block at real-time pace, the
/// way a microphone delivers what it hears.
@MainActor
private final class SynthesizedSpeechCapture: InterpreterAudioCapturing {
    var onHardwareChange: (@MainActor () -> Void)?

    private let buffers: [AVAudioPCMBuffer]
    private let format: AVAudioFormat
    private var feeding: Task<Void, Never>?

    /// How long the sentence lasts, so the run knows how long to "hold".
    let duration: Duration

    init?(buffers: [AVAudioPCMBuffer]) {
        guard let first = buffers.first else { return nil }
        self.buffers = buffers
        self.format = first.format
        let frames = buffers.reduce(0) { $0 + Int($1.frameLength) }
        self.duration = .milliseconds(Int(Double(frames) / first.format.sampleRate * 1_000))
    }

    func inputFormat() throws -> AVAudioFormat {
        format
    }

    func start(block: @escaping AVAudioNodeTapBlock) throws {
        feeding = Self.feed(buffers, to: block)
    }

    func stop() {
        feeding?.cancel()
        feeding = nil
    }

    /// Runs off the main actor, like an audio thread does.
    nonisolated private static func feed(
        _ buffers: [AVAudioPCMBuffer],
        to block: @escaping AVAudioNodeTapBlock
    ) -> Task<Void, Never> {
        Task.detached {
            var position: AVAudioFramePosition = 0
            for buffer in buffers {
                guard !Task.isCancelled else { return }
                let rate = buffer.format.sampleRate
                block(buffer, AVAudioTime(sampleTime: position, atRate: rate))
                position += AVAudioFramePosition(buffer.frameLength)
                let milliseconds = Int(Double(buffer.frameLength) / rate * 1_000)
                try? await Task.sleep(for: .milliseconds(milliseconds))
            }
        }
    }

    /// Renders `text` with a system voice into PCM buffers, without playing it.
    nonisolated static func render(text: String, languageCode: String) async -> [AVAudioPCMBuffer] {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        let state = OSAllocatedUnfairLock(uncheckedState: (buffers: [AVAudioPCMBuffer](), finished: false))

        /// Hands back what has been rendered, exactly once.
        @Sendable func take() -> [AVAudioPCMBuffer]? {
            state.withLockUnchecked { value in
                guard !value.finished else { return nil }
                value.finished = true
                return value.buffers
            }
        }

        let rendered: [AVAudioPCMBuffer] = await withCheckedContinuation { continuation in
            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength > 0 {
                    state.withLockUnchecked { value in
                        if !value.finished { value.buffers.append(pcm) }
                    }
                } else if let done = take() {
                    // A zero-length buffer marks the end of the sentence.
                    continuation.resume(returning: done)
                }
            }
            // Not every system voice sends that end marker. A sentence this
            // short renders in well under a second, so after a pause take
            // what has arrived.
            Task.detached {
                var seen = -1
                for _ in 0..<60 {
                    try? await Task.sleep(for: .milliseconds(250))
                    let count = state.withLockUnchecked { $0.finished ? -2 : $0.buffers.count }
                    if count == -2 { return }
                    if count > 0, count == seen { break }
                    seen = count
                }
                if let done = take() {
                    continuation.resume(returning: done)
                }
            }
        }
        withExtendedLifetime(synthesizer) {}
        return rendered
    }
}

/// Records what would have been spoken, and says nothing.
@MainActor
private final class SilentSpeaker: InterpreterSpeaking {
    private(set) var spoken: [String] = []

    func speak(
        _ text: String,
        languageCode: String,
        engine: SpeechVoiceEngine,
        onStart: @escaping @MainActor (SpeechVoiceEngine) -> Void
    ) async throws {
        spoken.append("\(languageCode): \(text)")
        onStart(engine)
    }

    func stop() {}
}

/// The real translation service, with the warm-ups a held button asks for
/// either passed on or dropped. Dropping them shows what a turn costs
/// without them.
@available(iOS 26.0, macOS 26.0, *)
@MainActor
private final class SelfTestTranslator: InterpreterTranslating {
    private let service: InterpreterTranslationService
    /// Whether a held button keeps the model warm in this run.
    let keepsWarmWhileHeld: Bool
    /// Set by the run for the length of a hold.
    var isHoldingButton = false
    private(set) var warmUps = 0

    init(service: InterpreterTranslationService, keepsWarmWhileHeld: Bool) {
        self.service = service
        self.keepsWarmWhileHeld = keepsWarmWhileHeld
    }

    func assetState() async -> InterpreterAssetState {
        await service.assetState()
    }

    var offersTwoModels: Bool { service.offersTwoModels }

    func warm(_ direction: TranslationDirection, model: InterpreterTranslationModel) async {
        // The warm-up when the screen opens always happens, as in the app.
        guard keepsWarmWhileHeld || !isHoldingButton else { return }
        warmUps += 1
        await service.warm(direction, model: model)
    }

    func translate(
        _ text: String,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) async throws -> String {
        try await service.translate(text, direction: direction, model: model)
    }
}

/// No permission prompt, no shared audio session, no history: the run must
/// not leave traces in the person's app or wait on a system dialog.
@MainActor
private final class SelfTestEnvironment: InterpreterEnvironment {
    let microphonePermission: InterpreterPermissionState
    var voiceEngine: SpeechVoiceEngine = .system
    var translationQuality: InterpreterTranslationQuality = .automatic

    init(microphonePermission: InterpreterPermissionState) {
        self.microphonePermission = microphonePermission
    }

    func requestMicrophonePermission() async -> Bool { false }
    func stopOtherAudio() async {}
    func beginConversationAudio() async throws {}
    func endConversationAudio() {}
    func record(source: String, translation: String, direction: TranslationDirection) {}
}

// MARK: - The run

@available(iOS 26.0, macOS 26.0, *)
@MainActor
private enum InterpreterSelfTest {
    private static var failures: [String] = []

    private static func note(_ line: String) {
        print("SELFTEST \(line)")
    }

    private static func expect(_ condition: Bool, _ what: String) {
        note("\(condition ? "ok  " : "FAIL") \(what)")
        if !condition {
            failures.append(what)
        }
    }

    static func run(audible: Bool, probesMiniMax: Bool, keepsWarm: Bool, opensMicrophone: Bool) async {
        note("begin audible=\(audible) minimax=\(probesMiniMax) keepsWarm=\(keepsWarm) microphone=\(opensMicrophone)")
        let provisioner = SpeechModelProvisioner()
        let service = InterpreterTranslationService()
        let translator = SelfTestTranslator(service: service, keepsWarmWhileHeld: keepsWarm)

        await checkAssets(provisioner: provisioner, translator: service)
        await checkTranslation(service)
        await checkSynthesizedTurn(
            .englishToChinese,
            sentence: "Where is the nearest train station? I need to buy two tickets to Shanghai.",
            sourceMustContain: ["train station", "shanghai"],
            translationMustContain: ["火车站", "上海"],
            provisioner: provisioner,
            translator: translator,
            audible: audible
        )
        await checkSynthesizedTurn(
            .chineseToEnglish,
            sentence: "请问最近的火车站在哪里？我想买两张去上海的票。",
            sourceMustContain: ["火车站", "上海"],
            translationMustContain: ["station", "shanghai"],
            provisioner: provisioner,
            translator: translator,
            audible: audible
        )
        await checkShortPress(provisioner: provisioner, translator: translator)
        if opensMicrophone {
            await checkMicrophoneLifecycle(provisioner: provisioner)
        } else {
            note("skip microphone lifecycle: not asked for (pass --microphone)")
        }
        if probesMiniMax {
            await InterpreterMiniMaxProbe.run(note: note)
        }

        note(failures.isEmpty ? "RESULT pass" : "RESULT fail (\(failures.count)): \(failures.joined(separator: " | "))")
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func checkAssets(
        provisioner: SpeechModelProvisioner,
        translator: InterpreterTranslationService
    ) async {
        for identifier in ["en-US", "zh-CN"] {
            let state = await provisioner.assetState(for: Locale(identifier: identifier))
            expect(state == .ready, "speech asset \(identifier) is ready (was \(state))")
        }
        let pair = await translator.assetState()
        expect(pair == .ready, "translation pair is ready (was \(pair))")
    }

    private static func checkTranslation(_ translator: InterpreterTranslationService) async {
        let clock = ContinuousClock()
        expect(translator.offersTwoModels, "this Mac has both translation models")

        let samples: [(String, TranslationDirection)] = [
            ("Could you help me? I am looking for a pharmacy that is still open.", .englishToChinese),
            ("太感谢了。这个多少钱？可以刷卡吗？", .chineseToEnglish),
        ]
        for model in InterpreterTranslationModel.allCases {
            for (text, direction) in samples {
                let warmStart = clock.now
                await translator.warm(direction, model: model)
                let warmUp = (clock.now - warmStart).interpreterMilliseconds
                let start = clock.now
                do {
                    let translated = try await translator.translate(text, direction: direction, model: model)
                    let elapsed = (clock.now - start).interpreterMilliseconds
                    expect(!translated.isEmpty, "translate \(model.rawValue) \(direction.label): warm-up \(warmUp) ms, then \(elapsed) ms -> \(translated)")
                } catch {
                    expect(false, "translate \(model.rawValue) \(direction.label) threw \(error)")
                }
            }
        }
    }

    /// One whole turn through the real coordinator and services, with
    /// synthesized speech standing in for the person and the microphone.
    private static func checkSynthesizedTurn(
        _ direction: TranslationDirection,
        sentence: String,
        sourceMustContain: [String],
        translationMustContain: [String],
        provisioner: SpeechModelProvisioner,
        translator: SelfTestTranslator,
        audible: Bool
    ) async {
        note("turn \(direction.label): \(sentence)")
        let rendered = await SynthesizedSpeechCapture.render(text: sentence, languageCode: direction.sourceSpeechCode)
        guard let capture = SynthesizedSpeechCapture(buffers: rendered) else {
            expect(false, "speech could be synthesized for \(direction.sourceSpeechCode)")
            return
        }
        note("synthesized \(capture.duration.interpreterMilliseconds) ms of audio at \((try? capture.inputFormat().sampleRate) ?? 0) Hz")

        let transcriber = PushToTalkTranscriptionService(provisioner: provisioner) { capture }
        let silent = SilentSpeaker()
        let speaker: any InterpreterSpeaking = audible ? InterpreterSpeechOutput() : silent
        let coordinator = SpeechTranslationCoordinator(
            transcriber: transcriber,
            translator: translator,
            speaker: speaker,
            environment: SelfTestEnvironment(microphonePermission: .notRequired)
        )

        coordinator.activate()
        guard await wait(seconds: 20, until: { coordinator.canStartTurn }) else {
            expect(false, "the coordinator became ready (readiness \(coordinator.readiness))")
            coordinator.deactivate()
            return
        }

        var states: [String] = []
        var partials = 0
        var lastTranscript = ""
        let watcher = Task { @MainActor in
            while !Task.isCancelled {
                let name = stateName(coordinator.state)
                if states.last != name { states.append(name) }
                if case .listening(_, let text) = coordinator.state, text != lastTranscript {
                    lastTranscript = text
                    partials += 1
                }
                try? await Task.sleep(for: .milliseconds(5))
            }
        }

        // Let the translation model rest first, as it does while two people
        // take their time between turns. It answers late after about five
        // idle seconds.
        try? await Task.sleep(for: .seconds(6))
        let warmUpsBefore = translator.warmUps
        translator.isHoldingButton = true
        coordinator.pressDown(direction)
        // Hold for as long as the sentence lasts, plus a breath.
        try? await Task.sleep(for: capture.duration + .milliseconds(300))
        coordinator.pressUp()
        translator.isHoldingButton = false
        let finished = await wait(seconds: 30) {
            switch coordinator.state {
            case .idle, .error: return true
            default: return false
            }
        }
        watcher.cancel()

        expect(finished, "the turn finished (state \(coordinator.state))")
        if case .error(let error) = coordinator.state {
            expect(false, "the turn ended without an error: \(error.message)")
        }
        note("states: \(states.joined(separator: " > "))")
        note("partial transcripts while held: \(partials)")
        expect(states.contains("listening") && states.contains("finalizing") && states.contains("translating"),
               "the turn passed through listening, finalizing and translating")
        expect(partials >= 1, "at least one partial transcript arrived while the button was held")

        if let turn = coordinator.turns.last {
            note("source: \(turn.sourceText)")
            note("translation (\(turn.translatedWith.rawValue) model): \(turn.translatedText)")
            note("model touched \(translator.warmUps - warmUpsBefore) time(s) while the button was held")
            let timings = turn.timings
            note("""
                timings: press→live \(timings.pressToLive ?? -1) ms, held \(timings.held ?? -1) ms, \
                release→transcript \(timings.releaseToTranscript ?? -1) ms, \
                transcript→translation \(timings.transcriptToTranslation ?? -1) ms, \
                release→speech \(timings.releaseToSpeech ?? -1) ms
                """)
            let source = turn.sourceText.lowercased()
            let translation = turn.translatedText.lowercased()
            for fragment in sourceMustContain {
                expect(source.contains(fragment), "the transcript contains \"\(fragment)\"")
            }
            for fragment in translationMustContain {
                expect(translation.contains(fragment), "the translation contains \"\(fragment)\"")
            }
            if !audible {
                expect(silent.spoken.count == 1 && silent.spoken[0].hasPrefix(direction.targetSpeechCode),
                       "the reply was handed to the speaker in \(direction.targetSpeechCode)")
            }
        } else {
            expect(false, "a turn was recorded")
        }
        coordinator.deactivate()
        // Let the teardown and model release finish before the next step.
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// A press shorter than the minimum hold: real recognizer, real teardown,
    /// nothing translated.
    private static func checkShortPress(
        provisioner: SpeechModelProvisioner,
        translator: SelfTestTranslator
    ) async {
        let rendered = await SynthesizedSpeechCapture.render(text: "Hello there.", languageCode: "en-US")
        guard let capture = SynthesizedSpeechCapture(buffers: rendered) else {
            expect(false, "speech could be synthesized for the short press")
            return
        }
        let silent = SilentSpeaker()
        let coordinator = SpeechTranslationCoordinator(
            transcriber: PushToTalkTranscriptionService(provisioner: provisioner) { capture },
            translator: translator,
            speaker: silent,
            environment: SelfTestEnvironment(microphonePermission: .notRequired)
        )
        coordinator.activate()
        guard await wait(seconds: 20, until: { coordinator.canStartTurn }) else {
            expect(false, "the coordinator became ready for the short press")
            coordinator.deactivate()
            return
        }
        coordinator.pressDown(.englishToChinese)
        try? await Task.sleep(for: .milliseconds(120))
        coordinator.pressUp()
        let settled = await wait(seconds: 10) { coordinator.state == .idle }
        expect(settled && coordinator.hint == .holdToSpeak, "a 120 ms press returns to idle with the hold hint")
        expect(coordinator.turns.isEmpty && silent.spoken.isEmpty, "a 120 ms press translates and speaks nothing")
        coordinator.deactivate()
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// The real microphone, if the app is already allowed to use it: open,
    /// listen to the room for a second, finalize, and open-then-cancel. The
    /// room is expected to be quiet; what matters is that every step returns.
    private static func checkMicrophoneLifecycle(provisioner: SpeechModelProvisioner) async {
        guard AVAudioApplication.shared.recordPermission == .granted else {
            note("skip microphone lifecycle: permission is \(AVAudioApplication.shared.recordPermission.rawValue), and the self-test never prompts")
            return
        }
        let service = PushToTalkTranscriptionService(provisioner: provisioner)
        let clock = ContinuousClock()
        await service.prepare(for: .englishToChinese)
        do {
            let pressed = clock.now
            try await service.begin(direction: .englishToChinese) { _ in }
            let live = clock.now
            try await Task.sleep(for: .seconds(1))
            let released = clock.now
            let transcript = try await service.finish()
            let done = clock.now
            note("microphone: press→live \((live - pressed).interpreterMilliseconds) ms, release→transcript \((done - released).interpreterMilliseconds) ms, heard \(transcript.count) characters")
            expect(true, "the real microphone opened, finalized and returned")
        } catch {
            expect(false, "the real microphone turn completed (\(error))")
        }
        do {
            try await service.begin(direction: .chineseToEnglish) { _ in }
            try await Task.sleep(for: .milliseconds(150))
            let cancelStart = clock.now
            await service.cancel()
            note("microphone: cancel returned in \((clock.now - cancelStart).interpreterMilliseconds) ms")
            expect(true, "the real microphone opened and cancelled cleanly")
        } catch {
            expect(false, "the real microphone cancel path completed (\(error))")
        }
        await service.releaseResources()
    }

    private static func wait(seconds: Int, until condition: @MainActor () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private static func stateName(_ state: PipelineState) -> String {
        switch state {
        case .idle: return "idle"
        case .preparingModels: return "preparing"
        case .listening: return "listening"
        case .finalizingTranscript: return "finalizing"
        case .translating: return "translating"
        case .speaking: return "speaking"
        case .error: return "error"
        }
    }
}

// MARK: - MiniMax timing probe

/// Times one short MiniMax request two ways — streamed, and whole — to learn
/// how the stream is framed and how much sooner its first audio arrives.
/// Uses the key already stored in the app; the key is never printed.
@MainActor
private enum InterpreterMiniMaxProbe {
    static func run(note: (String) -> Void) async {
        let key = AIModelSettings.shared.apiKey(for: .minimax).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            note("minimax: no API key stored; probe skipped")
            return
        }
        let preferences = AppPreferences.shared
        let text = "请问最近的火车站在哪里？我想买两张去上海的票。"
        let configuration = preferences.miniMaxSpeechConfiguration(languageCode: "zh-CN")
        guard let endpoint = configuration.region.t2aEndpoint else {
            note("minimax: no endpoint for the selected region")
            return
        }
        note("minimax: host \(endpoint.host() ?? "?"), model \(configuration.model)")

        await streamed(text: text, configuration: configuration, endpoint: endpoint, key: key, note: note)
        await whole(text: text, configuration: configuration, key: key, note: note)
    }

    private static func streamed(
        text: String,
        configuration: MiniMaxSpeechConfiguration,
        endpoint: URL,
        key: String,
        note: (String) -> Void
    ) async {
        let body: [String: Any] = [
            "model": configuration.model,
            "text": text,
            "stream": true,
            "language_boost": configuration.languageBoost.rawValue,
            "output_format": "hex",
            "stream_options": ["exclude_aggregated_audio": true],
            "voice_setting": [
                "voice_id": configuration.voiceID,
                "speed": configuration.speed,
                "vol": configuration.volume,
                "pitch": configuration.pitch,
            ],
            "audio_setting": [
                "sample_rate": configuration.sampleRate,
                "bitrate": configuration.bitrate,
                "format": configuration.format,
                "channel": configuration.channelCount,
            ],
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let headersAt = (clock.now - start).interpreterMilliseconds
            let http = response as? HTTPURLResponse
            note("minimax stream: HTTP \(http?.statusCode ?? -1), content-type \(http?.value(forHTTPHeaderField: "Content-Type") ?? "?"), headers after \(headersAt) ms")

            var lines = 0
            var audioChunks = 0
            var audioBytes = 0
            var firstAudioAt: Int?
            var firstLineShape: String?
            var finalShape: String?
            for try await line in bytes.lines {
                guard !line.isEmpty else { continue }
                lines += 1
                // Describe the framing without printing audio: the prefix
                // before the JSON, then the JSON's keys.
                let prefix = line.prefix(while: { $0 != "{" })
                let json = String(line.dropFirst(prefix.count))
                guard let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] else {
                    if firstLineShape == nil { firstLineShape = "unparsed line of \(line.count) characters, prefix \"\(prefix)\"" }
                    continue
                }
                let data = object["data"] as? [String: Any]
                let audio = data?["audio"] as? String ?? ""
                let status = data?["status"] as? Int
                if firstLineShape == nil {
                    firstLineShape = "prefix \"\(prefix)\", keys \(object.keys.sorted()), data keys \((data ?? [:]).keys.sorted())"
                }
                if !audio.isEmpty, status != 2 {
                    audioChunks += 1
                    audioBytes += audio.count / 2
                    if firstAudioAt == nil { firstAudioAt = (clock.now - start).interpreterMilliseconds }
                }
                if status == 2 {
                    let extra = object["extra_info"] as? [String: Any] ?? [:]
                    let base = object["base_resp"] as? [String: Any] ?? [:]
                    finalShape = "final audio \(audio.count / 2) bytes, extra_info \(extra.filter { $0.key.hasPrefix("audio") }), base_resp \(base)"
                } else if let base = object["base_resp"] as? [String: Any], let code = base["status_code"] as? Int, code != 0 {
                    finalShape = "error base_resp \(base)"
                }
            }
            let total = (clock.now - start).interpreterMilliseconds
            note("minimax stream: first line: \(firstLineShape ?? "none")")
            note("minimax stream: \(lines) lines, \(audioChunks) audio chunks, \(audioBytes) audio bytes, first audio after \(firstAudioAt.map(String.init) ?? "never") ms, complete after \(total) ms")
            note("minimax stream: \(finalShape ?? "no final chunk seen")")
        } catch {
            note("minimax stream: failed after \((clock.now - start).interpreterMilliseconds) ms: \(error.localizedDescription)")
        }
    }

    private static func whole(
        text: String,
        configuration: MiniMaxSpeechConfiguration,
        key: String,
        note: (String) -> Void
    ) async {
        let identity = MiniMaxSpeechCacheIdentity(text: text, languageCode: "zh-CN", configuration: configuration)
        let clock = ContinuousClock()
        let start = clock.now
        do {
            // The client alone: nothing is cached or added to the library.
            let result = try await MiniMaxAudioClient().synthesize(identity: identity, apiKey: key)
            note("minimax whole: \(result.audioData.count) bytes, \(result.durationMilliseconds ?? -1) ms of audio, complete after \((clock.now - start).interpreterMilliseconds) ms")
        } catch {
            note("minimax whole: failed after \((clock.now - start).interpreterMilliseconds) ms: \(error.localizedDescription)")
        }
    }
}

#endif
