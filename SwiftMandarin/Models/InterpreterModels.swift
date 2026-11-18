//
//  InterpreterModels.swift
//  SwiftMandarin
//
//  Value types for the push-to-talk Interpreter: the pipeline's state, the
//  errors it can surface, what is ready to use, and one finished turn.
//
//  Everything here is a Sendable value with no dependency on SwiftUI or on
//  the app's observable singletons, so the coordinator that drives these
//  types can be compiled and exercised on its own by
//  `scripts/test-interpreter.sh`.
//

import Foundation

// MARK: - Choices

/// Which voice speaks a reply.
///
/// This is a per-request choice, separate from the app-wide AI Audio switch:
/// the Interpreter can use Apple's on-device voice while the rest of the app
/// reads aloud through MiniMax, or the other way round.
nonisolated enum SpeechVoiceEngine: String, CaseIterable, Codable, Identifiable, Sendable {
    /// `AVSpeechSynthesizer`: on-device, offline, free.
    case system
    /// MiniMax text-to-speech: the translated text is sent to MiniMax.
    case miniMax

    var id: String { rawValue }
}

/// One of the device's two translation models, where it has two (iOS and
/// macOS 26.4 with the fluent model installed). A device with one model uses
/// it for both.
///
/// Measured on the development Mac (scripts/probe-interpreter.sh
/// translation-behaviour). The natural model takes about 265 ms for one
/// sentence and 480 ms for two, and reads a sentence in the light of the one
/// before it. The fast model takes 20–70 ms and translates each sentence on
/// its own. Either one answers several hundred milliseconds late on its
/// first call after the other was used, and the natural one also after a
/// few seconds of rest, which is why a turn keeps its model warm while the
/// button is held.
nonisolated enum InterpreterTranslationModel: String, CaseIterable, Codable, Sendable {
    case natural
    case fast
}

/// The Interpreter's translation setting.
nonisolated enum InterpreterTranslationQuality: String, CaseIterable, Codable, Identifiable, Sendable {
    /// The natural model, unless it proves too slow on this device; then the
    /// fast one for the rest of the visit to the screen.
    case automatic
    /// Always the natural model.
    case natural
    /// Always the fast model.
    case fast

    var id: String { rawValue }
}

// MARK: - Presses

/// One press of one input: a finger or the pointer on a hold button, or the
/// Space bar. The coordinator hands one back when it takes a press, and the
/// input hands it back to end that press.
///
/// A direction alone cannot say whose press it is. Two inputs can be down
/// for the same button at once, and an input can still be down after its
/// press was ended some other way. With this, each can end only what it
/// started.
nonisolated struct InterpreterPress: Hashable, Sendable {
    let id: UUID
    let direction: TranslationDirection

    init(direction: TranslationDirection) {
        id = UUID()
        self.direction = direction
    }
}

// MARK: - Pipeline state

/// Where one turn of the conversation is. Exactly one of these holds at any
/// moment; `SpeechTranslationCoordinator` is the only writer.
nonisolated enum PipelineState: Equatable, Sendable {
    /// Nothing in progress. A press starts a turn.
    case idle
    /// Speech or translation assets are being installed. `progress` is the
    /// fraction complete when the system reports one.
    case preparingModels(progress: Double?)
    /// The button is held and the microphone is (or is about to be) live.
    case listening(direction: TranslationDirection, liveTranscript: String)
    /// The button was released; the recognizer is finishing its last words.
    case finalizingTranscript
    /// The final transcript is being translated.
    case translating(sourceText: String)
    /// The translation is being spoken.
    case speaking(sourceText: String, translatedText: String)
    /// Something failed. The value says what, and how to recover.
    case error(UserFacingError)

    /// Whether a turn is underway, from press to the end of the reply.
    var isBusy: Bool {
        switch self {
        case .idle, .error, .preparingModels: return false
        case .listening, .finalizingTranscript, .translating, .speaking: return true
        }
    }

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }
}

/// A failure in words the person can act on, with at most one way forward.
nonisolated struct UserFacingError: Equatable, Sendable, Identifiable {
    /// The single action offered beside the message.
    enum Recovery: Equatable, Sendable {
        case none
        /// A permission was denied; only the system's Settings can change it.
        case openSettings
        /// Speech or translation assets are missing.
        case downloadModels
        /// The same turn can be attempted again.
        case retry
    }

    let id: UUID
    let message: String
    let recovery: Recovery

    init(id: UUID = UUID(), message: String, recovery: Recovery) {
        self.id = id
        self.message = message
        self.recovery = recovery
    }

    /// Two errors that read the same are the same to the person looking at
    /// the screen, whatever their identity.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message && lhs.recovery == rhs.recovery
    }
}

/// Everything that can go wrong in a turn, before it is put into words.
/// Services throw these; the coordinator turns them into `UserFacingError`.
nonisolated enum InterpreterError: Error, Equatable, Sendable {
    case requiresNewerSystem
    case microphoneDenied
    case speechRecognitionDenied
    case noMicrophoneInput
    case speechUnsupported(language: String)
    case speechAssetsMissing
    case speechAssetInstallFailed(reason: String)
    case tooManyReservedLocales
    case captureFailed(reason: String)
    case recognitionFailed(reason: String)
    case recognitionTimedOut
    case translationUnsupported
    case translationLanguagesMissing
    case translationFailed(reason: String)
    case translationTimedOut
    case speechOutputFailed(reason: String)
    case audioInterrupted(reason: String)

    var userFacing: UserFacingError {
        switch self {
        case .requiresNewerSystem:
            return UserFacingError(
                message: String(localized: "The Interpreter needs iOS 26 or macOS 26 or later.", bundle: .appLanguage),
                recovery: .none
            )
        case .microphoneDenied:
            return UserFacingError(
                message: String(localized: "The Interpreter needs the microphone. Allow microphone access in Settings and try again.", bundle: .appLanguage),
                recovery: .openSettings
            )
        case .speechRecognitionDenied:
            return UserFacingError(
                message: String(localized: "The Interpreter needs speech recognition. Allow it in Settings and try again.", bundle: .appLanguage),
                recovery: .openSettings
            )
        case .noMicrophoneInput:
            return UserFacingError(
                message: String(localized: "No microphone input is available. Connect or enable a microphone and try again.", bundle: .appLanguage),
                recovery: .retry
            )
        case .speechUnsupported(let language):
            return UserFacingError(
                message: String.localizedStringWithFormat(
                    String(localized: "This device cannot recognize %@ speech on its own.", bundle: .appLanguage),
                    language
                ),
                recovery: .none
            )
        case .speechAssetsMissing:
            return UserFacingError(
                message: String(localized: "The speech models for English and Chinese need to be downloaded first.", bundle: .appLanguage),
                recovery: .downloadModels
            )
        case .speechAssetInstallFailed(let reason):
            return UserFacingError(
                message: String.localizedStringWithFormat(
                    String(localized: "The speech models could not be downloaded: %@", bundle: .appLanguage),
                    reason
                ),
                recovery: .downloadModels
            )
        case .tooManyReservedLocales:
            // No button: the one Settings page this screen can open is the
            // microphone's, and nothing can be removed there.
            return UserFacingError(
                message: String(localized: "This device has reached its limit of downloaded speech languages. Remove one in Settings, then try again.", bundle: .appLanguage),
                recovery: .none
            )
        case .captureFailed(let reason):
            return UserFacingError(
                message: String.localizedStringWithFormat(
                    String(localized: "The microphone could not start: %@", bundle: .appLanguage),
                    reason
                ),
                recovery: .retry
            )
        case .recognitionFailed(let reason):
            return UserFacingError(
                message: String.localizedStringWithFormat(
                    String(localized: "Speech recognition stopped: %@", bundle: .appLanguage),
                    reason
                ),
                recovery: .retry
            )
        case .recognitionTimedOut:
            return UserFacingError(
                message: String(localized: "Speech recognition took too long to finish. Please try again.", bundle: .appLanguage),
                recovery: .retry
            )
        case .translationUnsupported:
            return UserFacingError(
                message: String(localized: "This device cannot translate between English and Chinese on its own.", bundle: .appLanguage),
                recovery: .none
            )
        case .translationLanguagesMissing:
            return UserFacingError(
                message: String(localized: "The English and Chinese translation languages need to be downloaded first.", bundle: .appLanguage),
                recovery: .downloadModels
            )
        case .translationFailed(let reason):
            return UserFacingError(
                message: String.localizedStringWithFormat(
                    String(localized: "Translation failed: %@", bundle: .appLanguage),
                    reason
                ),
                recovery: .retry
            )
        case .translationTimedOut:
            return UserFacingError(
                message: String(localized: "Translation took too long. Please try again.", bundle: .appLanguage),
                recovery: .retry
            )
        case .speechOutputFailed(let reason):
            return UserFacingError(
                message: String.localizedStringWithFormat(
                    String(localized: "The translation could not be spoken: %@", bundle: .appLanguage),
                    reason
                ),
                recovery: .retry
            )
        case .audioInterrupted(let reason):
            return UserFacingError(message: reason, recovery: .retry)
        }
    }
}

// MARK: - Readiness

/// Whether one downloadable asset — a speech model or the translation pair —
/// can be used right now.
nonisolated enum InterpreterAssetState: Equatable, Sendable {
    /// Not checked yet.
    case unknown
    case ready
    /// Supported by the device but not installed.
    case needsDownload
    case downloading(progress: Double?)
    /// The device cannot do this at all.
    case unsupported
    /// The iOS Simulator has no real model; a labeled stand-in is used.
    case simulatorMock

    /// A turn can proceed with this asset.
    var isUsable: Bool {
        self == .ready || self == .simulatorMock
    }
}

nonisolated enum InterpreterPermissionState: Equatable, Sendable {
    /// Not checked yet.
    case unknown
    case granted
    /// The system has not asked yet; the first press asks.
    case undetermined
    case denied
    /// This build does not need the permission.
    case notRequired

    var allowsCapture: Bool {
        self == .granted || self == .notRequired
    }
}

/// What the Interpreter needs before the first press, and what it has.
nonisolated struct InterpreterReadiness: Equatable, Sendable {
    var microphone: InterpreterPermissionState = .unknown
    var speechRecognition: InterpreterPermissionState = .unknown
    var englishSpeech: InterpreterAssetState = .unknown
    var chineseSpeech: InterpreterAssetState = .unknown
    var translation: InterpreterAssetState = .unknown

    /// The speech asset for the language a direction listens to.
    func speech(for direction: TranslationDirection) -> InterpreterAssetState {
        switch direction {
        case .englishToChinese: return englishSpeech
        case .chineseToEnglish: return chineseSpeech
        }
    }

    /// Every asset is in place. Permissions are separate: the system asks for
    /// those on the first press.
    var assetsAreUsable: Bool {
        englishSpeech.isUsable && chineseSpeech.isUsable && translation.isUsable
    }

    /// Something can be fixed with the Download button.
    var needsDownload: Bool {
        [englishSpeech, chineseSpeech, translation].contains(.needsDownload)
    }

    var isDownloading: Bool {
        [englishSpeech, chineseSpeech, translation].contains { state in
            if case .downloading = state { return true }
            return false
        }
    }

    /// The device cannot run part of the pipeline at all.
    var hasUnsupportedAsset: Bool {
        [englishSpeech, chineseSpeech, translation].contains(.unsupported)
    }

    /// A permission was refused, so a press can only explain how to grant it.
    var hasDeniedPermission: Bool {
        microphone == .denied || speechRecognition == .denied
    }

    /// The first check has not finished.
    var isUnknown: Bool {
        [englishSpeech, chineseSpeech, translation].contains(.unknown)
    }
}

// MARK: - Turns

/// How long each stage of one turn took, in milliseconds. `nil` means the
/// stage did not happen or could not be measured.
nonisolated struct InterpreterTurnTimings: Equatable, Sendable {
    /// Press until the microphone was delivering audio.
    var pressToLive: Int?
    /// How long the button was held.
    var held: Int?
    /// Release until the final transcript was known.
    var releaseToTranscript: Int?
    /// Final transcript until the translation was known.
    var transcriptToTranslation: Int?
    /// Translation until speech began.
    var translationToSpeech: Int?
    /// Release until speech began: what the listener waits.
    var releaseToSpeech: Int?
}

/// One finished exchange: what was said and what it means.
nonisolated struct InterpreterTurn: Identifiable, Equatable, Sendable {
    let id: UUID
    let direction: TranslationDirection
    let sourceText: String
    let translatedText: String
    let createdAt: Date
    /// The model that translated it.
    let translatedWith: InterpreterTranslationModel
    /// The voice chosen for it and, once it has been spoken, the voice that
    /// spoke it: the system's when MiniMax fell back. Replay uses the same.
    var spokenWith: SpeechVoiceEngine
    var timings: InterpreterTurnTimings
    /// Why the reply was not spoken, when it was not.
    var speechFailure: String?

    init(
        id: UUID = UUID(),
        direction: TranslationDirection,
        sourceText: String,
        translatedText: String,
        createdAt: Date = Date(),
        translatedWith: InterpreterTranslationModel,
        spokenWith: SpeechVoiceEngine,
        timings: InterpreterTurnTimings = InterpreterTurnTimings(),
        speechFailure: String? = nil
    ) {
        self.id = id
        self.direction = direction
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.createdAt = createdAt
        self.translatedWith = translatedWith
        self.spokenWith = spokenWith
        self.timings = timings
        self.speechFailure = speechFailure
    }
}

/// A short, self-clearing note under the buttons for a press that produced
/// nothing. Not an error: nothing failed.
nonisolated enum InterpreterHint: Equatable, Sendable {
    /// The press was shorter than a deliberate hold.
    case holdToSpeak
    /// The button was held but no words were recognized.
    case nothingHeard

    var message: String {
        switch self {
        case .holdToSpeak:
            return String(localized: "Hold the button while you speak, then let go.", bundle: .appLanguage)
        case .nothingHeard:
            return String(localized: "Didn't catch that. Hold the button and try again.", bundle: .appLanguage)
        }
    }
}

// MARK: - Live transcript

/// The transcript while the button is held: text the recognizer has
/// committed to, and a tail it may still rewrite.
nonisolated struct TranscriptSnapshot: Equatable, Sendable {
    var finalized: String
    var volatile: String

    init(finalized: String = "", volatile: String = "") {
        self.finalized = finalized
        self.volatile = volatile
    }

    /// Both parts as one string, for the pipeline state and for translation.
    var text: String {
        TranscriptAssembler.join(finalized, volatile)
    }

    var isEmpty: Bool {
        finalized.isEmpty && volatile.isEmpty
    }
}

// MARK: - Tuning

/// The few numbers that shape a turn, in one place so the checks and the
/// coordinator agree on them.
nonisolated enum InterpreterTuning {
    /// A press shorter than this is treated as a slip, not as speech.
    static let minimumHold: Duration = .milliseconds(250)
    /// How long to keep listening after release so the last syllable is not
    /// cut off by the audio buffer boundary.
    static let releaseTail: Duration = .milliseconds(150)
    /// How long the recognizer may take to deliver its final words after
    /// release before the turn is abandoned.
    static let finalizationTimeout: Duration = .seconds(4)
    /// How long a translation may take before the turn fails.
    static let translationTimeout: Duration = .seconds(12)
    /// How often the turn's translation model is touched while the button is
    /// held. Shorter than the rest after which the natural model answers
    /// late; see `InterpreterTranslationModel`.
    static let translationKeepWarmInterval: Duration = .milliseconds(2_500)
    /// Automatic quality: this many slow natural turns in a row move the
    /// rest of the visit to the fast model.
    static let slowNaturalTurnsBeforeFast = 2

    /// Automatic quality: how long the natural model may take over one turn
    /// before the turn counts as slow. Longer speech is allowed a longer
    /// wait: 400 ms plus a tenth of the time the button was held, and never
    /// less than half a second or more than 1.2 s.
    static func naturalTranslationAllowance(heldMilliseconds: Int?) -> Duration {
        let scaled = 400 + (heldMilliseconds ?? 0) / 10
        return .milliseconds(min(max(scaled, 500), 1_200))
    }
    /// How long a hint stays on screen.
    static let hintDuration: Duration = .seconds(3)
    /// How often to look again while a speech model is still downloading.
    static let downloadPollInterval: Duration = .seconds(2)
}
