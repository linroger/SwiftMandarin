//
//  AudioSessionCoordinator.swift
//  SwiftMandarin
//
//  Ordered ownership for the process-wide iOS audio session.
//

import Foundation
import os.log

#if os(iOS)
import AVFAudio
#endif

/// The four session configurations currently used by SwiftMandarin. Keeping
/// profile selection here makes category configuration and activation one
/// ordered transition instead of two independently interleavable operations.
nonisolated enum AudioSessionProfile: Sendable, Equatable {
    case spokenPlayback
    case sourcePreview
    case clipRecording
    case liveRecognition
}

/// Created before an asynchronous acquisition begins, so a synchronous stop
/// can enqueue release even while activation is still pending.
nonisolated struct AudioSessionOwner: Sendable, Hashable {
    fileprivate let id: UUID

    init() {
        id = UUID()
    }

    #if AUDIO_SESSION_CHECKS
    init(id: UUID) {
        self.id = id
    }
    #endif
}

nonisolated enum AudioSessionTransitionError: LocalizedError, Sendable {
    case activationReturnedFalse
    case deactivationReturnedFalse

    var errorDescription: String? {
        switch self {
        case .activationReturnedFalse:
            return String(localized: "The audio player could not start.")
        case .deactivationReturnedFalse:
            return "The audio session could not be deactivated."
        }
    }
}

/// Injectable boundary used by the deterministic transition contracts. The
/// production backend is the only type allowed to touch AVAudioSession.
nonisolated protocol AudioSessionBackend: Sendable {
    func activate(profile: AudioSessionProfile) async throws
    func deactivate() async throws
}

/// Serializes category changes, activation, and deactivation across speech,
/// source preview/recording, and live recognition. Actor isolation alone is
/// insufficient because an actor can re-enter while an AVFAudio async method
/// is suspended; the explicit task tail preserves FIFO completion ordering.
@MainActor
final class AudioSessionCoordinator {
    static let shared = AudioSessionCoordinator()

    private let backend: any AudioSessionBackend
    private let log = Logger(
        subsystem: "com.rogerlin.SwiftMandarin",
        category: "AudioSession"
    )
    private var transitionTail: Task<Void, Never> = Task {}
    private var currentOwner: AudioSessionOwner?
    private var currentProfile: AudioSessionProfile?

    private init() {
        backend = SystemAudioSessionBackend()
    }

    #if AUDIO_SESSION_CHECKS
    init(testing backend: any AudioSessionBackend) {
        self.backend = backend
    }
    #endif

    /// Activates `profile` in FIFO order and makes `owner` current only after
    /// the backend reports success. Cancellation of the awaiting caller does
    /// not cancel the system transition; callers must reconcile their owner
    /// token after this returns and release a request that became stale.
    func acquire(_ profile: AudioSessionProfile, owner: AudioSessionOwner) async throws {
        let previous = transitionTail
        let operation = Task { @MainActor [backend] () -> Result<Void, any Error> in
            await previous.value
            do {
                try await backend.activate(profile: profile)
                self.currentOwner = owner
                self.currentProfile = profile
                return .success(())
            } catch {
                return .failure(error)
            }
        }
        transitionTail = Task { @MainActor in
            _ = await operation.value
        }

        try await operation.value.get()
    }

    /// Enqueues a nonblocking release. Only the owner that is current when its
    /// FIFO turn arrives may deactivate, so late delegate callbacks and old
    /// stop operations cannot shut down a newer recorder/player/synthesizer.
    func release(_ owner: AudioSessionOwner) {
        let previous = transitionTail
        transitionTail = Task { @MainActor [backend, log] in
            await previous.value
            guard self.currentOwner == owner else { return }

            // Logical ownership ends even if the platform reports a cleanup
            // error. The next queued acquisition must still be able to recover.
            self.currentOwner = nil
            self.currentProfile = nil
            do {
                try await backend.deactivate()
            } catch {
                log.error(
                    "Audio session deactivation failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    #if AUDIO_SESSION_CHECKS
    func waitForPendingTransitions() async {
        let pending = transitionTail
        await pending.value
    }

    var testingCurrentOwner: AudioSessionOwner? {
        currentOwner
    }

    var testingCurrentProfile: AudioSessionProfile? {
        currentProfile
    }
    #endif
}

nonisolated private struct SystemAudioSessionBackend: AudioSessionBackend {
    #if os(iOS)
    private let compatibilityQueue = DispatchQueue(
        label: "com.rogerlin.SwiftMandarin.audio-session-transitions",
        qos: .userInitiated
    )
    #endif

    func activate(profile: AudioSessionProfile) async throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()

        // Category setters have no asynchronous counterpart. Moving this
        // configuration off MainActor also keeps it adjacent to activation;
        // the coordinator prevents another profile from interleaving here.
        try await performOnCompatibilityQueue {
            try profile.configure(session)
        }

        if #available(iOS 27.0, *) {
            let activated = try await session.activate(options: [])
            guard activated else {
                throw AudioSessionTransitionError.activationReturnedFalse
            }
        } else {
            // The deployment target is iOS 17. Legacy setActive is blocking,
            // so it must run on the same private non-main serial queue.
            try await performOnCompatibilityQueue {
                try session.setActive(true)
            }
        }
        #else
        _ = profile
        #endif
    }

    func deactivate() async throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 27.0, *) {
            let deactivated = try await session.deactivate(
                options: [.notifyOthersOnDeactivation]
            )
            guard deactivated else {
                throw AudioSessionTransitionError.deactivationReturnedFalse
            }
        } else {
            try await performOnCompatibilityQueue {
                try session.setActive(
                    false,
                    options: [.notifyOthersOnDeactivation]
                )
            }
        }
        #endif
    }

    #if os(iOS)
    private func performOnCompatibilityQueue(
        _ operation: @escaping @Sendable () throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            compatibilityQueue.async {
                do {
                    try operation()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    #endif
}

#if os(iOS)
nonisolated private extension AudioSessionProfile {
    func configure(_ session: AVAudioSession) throws {
        switch self {
        case .spokenPlayback:
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
            )
        case .sourcePreview:
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.duckOthers]
            )
        case .clipRecording:
            try session.setCategory(
                .record,
                mode: .measurement,
                options: []
            )
        case .liveRecognition:
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker]
            )
        }
    }
}
#endif
