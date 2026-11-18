//
//  InterpreterAdapters.swift
//  SwiftMandarin
//
//  Binds the Interpreter's protocols to the rest of the app: the speech
//  router, the audio-session coordinator, preferences and history. Kept thin
//  on purpose — the decisions live in `SpeechTranslationCoordinator`, which
//  the checks exercise without any of this.
//

import AVFAudio
import Foundation

/// The app's single speech router, as the Interpreter's voice. Going through
/// `SpeechService` keeps one owner of speech playback for the whole app: the
/// same synthesizer, the same MiniMax cache, the same fallback rules.
@MainActor
final class InterpreterSpeechOutput: InterpreterSpeaking {
    func speak(
        _ text: String,
        languageCode: String,
        engine: SpeechVoiceEngine,
        onStart: @escaping @MainActor (SpeechVoiceEngine) -> Void
    ) async throws {
        try await SpeechService.speakAndWait(
            text,
            languageCode: languageCode,
            engine: engine,
            onStart: onStart
        )
    }

    func stop() {
        SpeechService.stop()
    }
}

/// Permissions, the shared audio session, preferences and history.
@MainActor
final class InterpreterAppEnvironment: InterpreterEnvironment {
    /// Identifies the Interpreter's hold on the audio session.
    private let sessionOwner = AudioSessionOwner()

    var microphonePermission: InterpreterPermissionState {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .undetermined
        @unknown default: return .undetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await SpeechRecognitionService.shared.checkMicrophoneAuthorization()
    }

    func stopOtherAudio() async {
        SourceAudioActivityCoordinator.shared.stopSourceAudioForSpeech()
        await SpeechRecognitionService.shared.stopRecording()
        SpeechService.stop()
    }

    /// Holds the session in one record-and-play configuration for the whole
    /// conversation, so neither a press nor a reply waits on an activation.
    func beginConversationAudio() async throws {
        // The object that hears about interruptions and route changes, and
        // passes them on to the Interpreter, starts listening when it is
        // first used. Use it now, so that a call arriving before the first
        // press is not missed.
        _ = SourceAudioActivityCoordinator.shared
        try await AudioSessionCoordinator.shared.pin(.speechConversation, owner: sessionOwner)
    }

    func endConversationAudio() {
        AudioSessionCoordinator.shared.unpin(sessionOwner)
    }

    var voiceEngine: SpeechVoiceEngine {
        AppPreferences.shared.interpreterVoiceEngine
    }

    var translationQuality: InterpreterTranslationQuality {
        AppPreferences.shared.interpreterTranslationQuality
    }

    func record(source: String, translation: String, direction: TranslationDirection) {
        // The same switch the Translate screen honours ("Save Translations to
        // History"), which defaults to on.
        let saves = UserDefaults.standard.object(forKey: "saveToHistoryAutomatically") as? Bool ?? true
        guard saves else { return }
        TranslationHistoryStore.shared.add(source: source, target: translation, direction: direction)
    }
}

/// The one coordinator every Interpreter screen shares. The microphone, the
/// audio session and the speech router are app-wide, so two windows must
/// show the same conversation rather than fight over them.
@available(iOS 26.0, macOS 26.0, *)
@MainActor
enum InterpreterRuntime {
    /// The coordinator, if any screen has opened the Interpreter yet.
    private(set) static var liveCoordinator: SpeechTranslationCoordinator?

    static var coordinator: SpeechTranslationCoordinator {
        if let liveCoordinator { return liveCoordinator }
        let made = makeCoordinator()
        liveCoordinator = made
        return made
    }

    private static func makeCoordinator() -> SpeechTranslationCoordinator {
        #if targetEnvironment(simulator)
        // The Simulator has no on-device recognizer and no translation
        // models, so labeled stand-ins keep the screen and the speech output
        // testable there. See InterpreterSimulatorStandIns.swift.
        return SpeechTranslationCoordinator(
            transcriber: SimulatorScriptedTranscriber(),
            translator: SimulatorMockTranslator(),
            speaker: SimulatorSpeechOutput(router: InterpreterSpeechOutput()),
            environment: SimulatorInterpreterEnvironment(base: InterpreterAppEnvironment())
        )
        #else
        let transcriber = PushToTalkTranscriptionService(provisioner: SpeechModelProvisioner())
        let coordinator = SpeechTranslationCoordinator(
            transcriber: transcriber,
            translator: InterpreterTranslationService(),
            speaker: InterpreterSpeechOutput(),
            environment: InterpreterAppEnvironment()
        )
        transcriber.onInterruption = { [weak coordinator] message in
            coordinator?.audioSessionLost(message: message)
        }
        return coordinator
        #endif
    }
}

/// What the app's other audio features call so that they and the Interpreter
/// never record or play over each other. Safe on every OS version, and never
/// creates the Interpreter just to tell it something.
@MainActor
enum InterpreterAudioBridge {
    /// Another feature is about to record or speak: a held Interpreter press
    /// gives up the microphone.
    static func otherAudioWillStart() {
        if #available(iOS 26.0, macOS 26.0, *) {
            InterpreterRuntime.liveCoordinator?.cancelCapture()
        }
    }

    /// The system took the audio session away (a call, a disconnected
    /// headset).
    static func audioSessionLost(message: String) {
        if #available(iOS 26.0, macOS 26.0, *) {
            InterpreterRuntime.liveCoordinator?.audioSessionLost(message: message)
        }
    }
}
