//
//  InterpreterSimulatorStandIns.swift
//  SwiftMandarin
//
//  Stand-ins for the two stages of the Interpreter that the iOS Simulator
//  cannot run. Measured with scripts/probe-interpreter.sh simulator on the
//  iOS 27.2 simulator: `SpeechTranscriber.isAvailable` is false and it
//  supports no locales, `DictationTranscriber` offers no audio format, and
//  the Translation framework reports English ⇄ Chinese as unsupported.
//
//  Both stand-ins label their output in words, while the button is held as
//  well as afterwards, so nothing here can be mistaken for a real transcript
//  or a real translation. Speech output is
//  real in the Simulator, so the screen, the state machine, the audio
//  session and the voices can all be exercised there. A scripted run that
//  must stay quiet launches the app with `-InterpreterSimulatorMuted`.
//  Nothing here opens the microphone, so the Simulator build never asks for
//  it; the permission flow is covered by the contract checks and on devices.
//
//  This whole file compiles only for the Simulator. Device and macOS builds
//  contain none of it.
//

#if targetEnvironment(simulator)

import Foundation

/// "Hears" a fixed sentence, a word at a time, for as long as the button is
/// held, and returns the whole sentence on release.
@MainActor
final class SimulatorScriptedTranscriber: InterpreterTranscribing {
    static let label = "[Simulator Mock Transcript]"

    private static let scripts: [TranslationDirection: [String]] = [
        .englishToChinese: ["Where", "is", "the", "nearest", "train", "station?"],
        .chineseToEnglish: ["请问", "最近的", "火车站", "在", "哪里？"],
    ]

    private var words: [String] = []
    private var typing: Task<Void, Never>?
    private var generation = 0
    private var isOpen = false

    func assetState(for direction: TranslationDirection) async -> InterpreterAssetState {
        .simulatorMock
    }

    func installAssets(onProgress: @escaping @MainActor (Double?) -> Void) async throws {}

    func prepare(for direction: TranslationDirection) async {}

    func begin(
        direction: TranslationDirection,
        onUpdate: @escaping @MainActor (TranscriptSnapshot) -> Void
    ) async throws {
        generation += 1
        let mine = generation
        typing?.cancel()
        words = Self.scripts[direction] ?? []
        isOpen = true

        let script = words
        typing = Task { [weak self] in
            for count in 1...max(script.count, 1) {
                try? await Task.sleep(for: .milliseconds(350))
                guard let self, !Task.isCancelled, self.generation == mine else { return }
                onUpdate(TranscriptSnapshot(volatile: "\(Self.label) \(Self.sentence(script.prefix(count)))"))
            }
        }
    }

    func finish() async throws -> String {
        guard isOpen else { throw CancellationError() }
        isOpen = false
        typing?.cancel()
        typing = nil
        return "\(Self.label) \(Self.sentence(words[...]))"
    }

    func cancel() async {
        generation += 1
        isOpen = false
        typing?.cancel()
        typing = nil
    }

    func releaseResources() async {}

    private static func sentence(_ words: ArraySlice<String>) -> String {
        TranscriptAssembler.normalize(words.joined(separator: " "))
    }
}

/// Returns a labeled, fixed translation for the scripted sentences, and the
/// labeled source text for anything else.
@MainActor
final class SimulatorMockTranslator: InterpreterTranslating {
    static let label = "[Simulator Mock Translation]"

    private static let canned: [String: String] = [
        "Where is the nearest train station?": "请问最近的火车站在哪里？",
        "请问最近的火车站在哪里？": "Where is the nearest train station?",
    ]

    func assetState() async -> InterpreterAssetState {
        .simulatorMock
    }

    var offersTwoModels: Bool { false }

    func warm(_ direction: TranslationDirection, model: InterpreterTranslationModel) async {}

    func translate(
        _ text: String,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) async throws -> String {
        let spoken = text
            .replacingOccurrences(of: SimulatorScriptedTranscriber.label, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(Self.label) \(Self.canned[spoken] ?? spoken)"
    }
}

/// The app's environment, minus the microphone permission. The scripted
/// transcriber never opens the microphone, so asking for it here would be
/// asking for something the Simulator build does not use.
@MainActor
final class SimulatorInterpreterEnvironment: InterpreterEnvironment {
    private let base: any InterpreterEnvironment

    init(base: any InterpreterEnvironment) {
        self.base = base
    }

    var microphonePermission: InterpreterPermissionState { .notRequired }

    func requestMicrophonePermission() async -> Bool { true }

    func stopOtherAudio() async {
        await base.stopOtherAudio()
    }

    func beginConversationAudio() async throws {
        try await base.beginConversationAudio()
    }

    func endConversationAudio() {
        base.endConversationAudio()
    }

    var voiceEngine: SpeechVoiceEngine { base.voiceEngine }

    var translationQuality: InterpreterTranslationQuality { base.translationQuality }

    func record(source: String, translation: String, direction: TranslationDirection) {
        base.record(source: source, translation: translation, direction: direction)
    }
}

/// Speaks through the app's speech router, exactly as a device does — unless
/// the app was launched with `-InterpreterSimulatorMuted`. Then a reply takes
/// about as long as a voice would and makes no sound, so the screen can be
/// driven from a script without playing audio on the Mac.
@MainActor
final class SimulatorSpeechOutput: InterpreterSpeaking {
    nonisolated static let mutedArgument = "-InterpreterSimulatorMuted"

    private let router: any InterpreterSpeaking
    private let isMuted: Bool
    private var mutedReply: Task<Void, any Error>?

    /// - Parameter router: what speaks when the run is not muted.
    init(router: any InterpreterSpeaking) {
        self.router = router
        self.isMuted = ProcessInfo.processInfo.arguments.contains(Self.mutedArgument)
    }

    func speak(
        _ text: String,
        languageCode: String,
        engine: SpeechVoiceEngine,
        onStart: @escaping @MainActor (SpeechVoiceEngine) -> Void
    ) async throws {
        guard isMuted else {
            try await router.speak(text, languageCode: languageCode, engine: engine, onStart: onStart)
            return
        }
        mutedReply?.cancel()
        // Roughly a voice's pace, and never so brief that the "speaking"
        // state cannot be seen.
        let length = Duration.milliseconds(max(1_200, text.count * 90))
        let reply = Task { try await Task.sleep(for: length) }
        mutedReply = reply
        onStart(engine)
        // Stopping cancels the wait, which ends the reply the way the router
        // ends a stopped one: by throwing `CancellationError`.
        try await reply.value
    }

    func stop() {
        guard isMuted else {
            router.stop()
            return
        }
        mutedReply?.cancel()
        mutedReply = nil
    }
}

#endif
