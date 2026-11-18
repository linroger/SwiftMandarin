#if AUDIO_SESSION_CHECKS
import Foundation

private struct CheckFailure: Error {
    let message: String
}

private enum InjectedBackendError: Error, Sendable, Equatable {
    case activationFailed
}

private enum BackendOutcome: Sendable {
    case success
    case activationFailure
    case activationReturnedFalse
    case deactivationReturnedFalse
}

private enum BackendEvent: Sendable, Equatable {
    case activationStarted(AudioSessionProfile)
    case activationSucceeded(AudioSessionProfile)
    case activationFailed(AudioSessionProfile)
    case deactivationStarted
    case deactivationSucceeded
    case deactivationFailed
}

/// A deliberately reentrant backend: held calls suspend inside the actor so
/// the coordinator tests prove that its explicit FIFO tail, rather than actor
/// isolation by itself, prevents overlapping AVAudioSession transitions.
private actor ControllableAudioSessionBackend: AudioSessionBackend {
    private var events: [BackendEvent] = []
    private var activationOutcomes: [BackendOutcome]
    private var deactivationOutcomes: [BackendOutcome]
    private var holdsActivations: Bool
    private var holdsDeactivations: Bool
    private var pendingActivations: [CheckedContinuation<BackendOutcome, Never>] = []
    private var pendingDeactivations: [CheckedContinuation<BackendOutcome, Never>] = []

    init(
        holdsActivations: Bool = false,
        holdsDeactivations: Bool = false,
        activationOutcomes: [BackendOutcome] = [],
        deactivationOutcomes: [BackendOutcome] = []
    ) {
        self.holdsActivations = holdsActivations
        self.holdsDeactivations = holdsDeactivations
        self.activationOutcomes = activationOutcomes
        self.deactivationOutcomes = deactivationOutcomes
    }

    func activate(profile: AudioSessionProfile) async throws {
        events.append(.activationStarted(profile))
        let outcome: BackendOutcome
        if holdsActivations {
            outcome = await withCheckedContinuation { continuation in
                pendingActivations.append(continuation)
            }
        } else if activationOutcomes.isEmpty {
            outcome = .success
        } else {
            outcome = activationOutcomes.removeFirst()
        }

        switch outcome {
        case .success:
            events.append(.activationSucceeded(profile))
        case .activationFailure:
            events.append(.activationFailed(profile))
            throw InjectedBackendError.activationFailed
        case .activationReturnedFalse:
            events.append(.activationFailed(profile))
            throw AudioSessionTransitionError.activationReturnedFalse
        case .deactivationReturnedFalse:
            preconditionFailure("A deactivation outcome was supplied to activate(profile:)")
        }
    }

    func deactivate() async throws {
        events.append(.deactivationStarted)
        let outcome: BackendOutcome
        if holdsDeactivations {
            outcome = await withCheckedContinuation { continuation in
                pendingDeactivations.append(continuation)
            }
        } else if deactivationOutcomes.isEmpty {
            outcome = .success
        } else {
            outcome = deactivationOutcomes.removeFirst()
        }

        switch outcome {
        case .success:
            events.append(.deactivationSucceeded)
        case .deactivationReturnedFalse:
            events.append(.deactivationFailed)
            throw AudioSessionTransitionError.deactivationReturnedFalse
        case .activationFailure, .activationReturnedFalse:
            preconditionFailure("An activation outcome was supplied to deactivate()")
        }
    }

    func resumeNextActivation(with outcome: BackendOutcome = .success) {
        precondition(!pendingActivations.isEmpty, "No held activation is pending")
        pendingActivations.removeFirst().resume(returning: outcome)
    }

    func resumeNextDeactivation(with outcome: BackendOutcome = .success) {
        precondition(!pendingDeactivations.isEmpty, "No held deactivation is pending")
        pendingDeactivations.removeFirst().resume(returning: outcome)
    }

    func snapshot() -> [BackendEvent] {
        events
    }
}

private func waitUntil(
    _ description: String,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(2))
    }
    throw CheckFailure(message: "Timed out waiting for \(description)")
}

@MainActor
private struct TransitionChecks {
    private(set) var checksRun = 0

    mutating func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        checksRun += 1
        guard condition() else {
            throw CheckFailure(message: message)
        }
    }

    mutating func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String
    ) throws {
        try expect(actual == expected, "\(message). Expected \(expected), got \(actual)")
    }

    mutating func runFIFOActivationCheck() async throws {
        let backend = ControllableAudioSessionBackend(holdsActivations: true)
        let coordinator = AudioSessionCoordinator(testing: backend)
        let firstOwner = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let secondOwner = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        let first = Task { @MainActor in
            try await coordinator.acquire(.spokenPlayback, owner: firstOwner)
        }
        try await waitUntil("the first held activation") {
            await backend.snapshot() == [.activationStarted(.spokenPlayback)]
        }

        let second = Task { @MainActor in
            try await coordinator.acquire(.clipRecording, owner: secondOwner)
        }
        for _ in 0..<20 {
            await Task.yield()
        }
        try expectEqual(
            await backend.snapshot(),
            [.activationStarted(.spokenPlayback)],
            "A second acquisition does not enter the backend while the first is suspended"
        )

        await backend.resumeNextActivation()
        try await first.value
        try await waitUntil("the second held activation") {
            await backend.snapshot() == [
                .activationStarted(.spokenPlayback),
                .activationSucceeded(.spokenPlayback),
                .activationStarted(.clipRecording),
            ]
        }
        await backend.resumeNextActivation()
        try await second.value

        try expectEqual(
            await backend.snapshot(),
            [
                .activationStarted(.spokenPlayback),
                .activationSucceeded(.spokenPlayback),
                .activationStarted(.clipRecording),
                .activationSucceeded(.clipRecording),
            ],
            "Acquisitions complete in submission order"
        )
        try expectEqual(
            coordinator.testingCurrentOwner,
            secondOwner,
            "The last successful FIFO acquisition owns the session"
        )

        coordinator.release(secondOwner)
        await coordinator.waitForPendingTransitions()
    }

    mutating func runFailureRecoveryChecks() async throws {
        let backend = ControllableAudioSessionBackend(
            activationOutcomes: [.activationFailure, .activationReturnedFalse]
        )
        let coordinator = AudioSessionCoordinator(testing: backend)
        let firstOwner = AudioSessionOwner()
        let secondOwner = AudioSessionOwner()
        let recoveredOwner = AudioSessionOwner()

        checksRun += 1
        do {
            try await coordinator.acquire(.sourcePreview, owner: firstOwner)
            throw CheckFailure(message: "An injected backend activation failure was swallowed")
        } catch InjectedBackendError.activationFailed {
            // Expected.
        }
        try expect(
            coordinator.testingCurrentOwner == nil,
            "A failed activation does not publish an owner"
        )

        checksRun += 1
        do {
            try await coordinator.acquire(.clipRecording, owner: secondOwner)
            throw CheckFailure(message: "A false async activation result was swallowed")
        } catch AudioSessionTransitionError.activationReturnedFalse {
            // Expected.
        }
        try expect(
            coordinator.testingCurrentOwner == nil,
            "A false-equivalent activation does not publish an owner"
        )

        try await coordinator.acquire(.liveRecognition, owner: recoveredOwner)
        try expectEqual(
            coordinator.testingCurrentOwner,
            recoveredOwner,
            "The FIFO tail remains usable after thrown activation failures"
        )
        coordinator.release(recoveredOwner)
        await coordinator.waitForPendingTransitions()
    }

    mutating func runDeactivationFailureRecoveryCheck() async throws {
        let backend = ControllableAudioSessionBackend(
            deactivationOutcomes: [.deactivationReturnedFalse]
        )
        let coordinator = AudioSessionCoordinator(testing: backend)
        let retiredOwner = AudioSessionOwner()
        let replacementOwner = AudioSessionOwner()

        try await coordinator.acquire(.spokenPlayback, owner: retiredOwner)
        coordinator.release(retiredOwner)
        await coordinator.waitForPendingTransitions()
        try expect(
            coordinator.testingCurrentOwner == nil,
            "A false-equivalent deactivation still retires logical ownership"
        )

        try await coordinator.acquire(.sourcePreview, owner: replacementOwner)
        try expectEqual(
            coordinator.testingCurrentOwner,
            replacementOwner,
            "A later acquisition recovers after a deactivation error"
        )
        coordinator.release(replacementOwner)
        await coordinator.waitForPendingTransitions()
    }

    mutating func runStaleOwnerReleaseCheck() async throws {
        let backend = ControllableAudioSessionBackend()
        let coordinator = AudioSessionCoordinator(testing: backend)
        let oldOwner = AudioSessionOwner()
        let currentOwner = AudioSessionOwner()

        try await coordinator.acquire(.spokenPlayback, owner: oldOwner)
        try await coordinator.acquire(.clipRecording, owner: currentOwner)
        coordinator.release(oldOwner)
        await coordinator.waitForPendingTransitions()

        let eventsBeforeCleanup = await backend.snapshot()
        try expect(
            !eventsBeforeCleanup.contains(.deactivationStarted),
            "A stale release never deactivates a newer owner's session"
        )
        try expectEqual(
            coordinator.testingCurrentOwner,
            currentOwner,
            "A stale release preserves the current owner"
        )

        coordinator.release(currentOwner)
        await coordinator.waitForPendingTransitions()
    }

    mutating func runReleaseBeforeAcquireOrderingCheck() async throws {
        let backend = ControllableAudioSessionBackend(holdsDeactivations: true)
        let coordinator = AudioSessionCoordinator(testing: backend)
        let firstOwner = AudioSessionOwner()
        let secondOwner = AudioSessionOwner()

        try await coordinator.acquire(.spokenPlayback, owner: firstOwner)
        coordinator.release(firstOwner)
        let second = Task { @MainActor in
            try await coordinator.acquire(.liveRecognition, owner: secondOwner)
        }

        try await waitUntil("the held deactivation") {
            await backend.snapshot().contains(.deactivationStarted)
        }
        try expectEqual(
            await backend.snapshot(),
            [
                .activationStarted(.spokenPlayback),
                .activationSucceeded(.spokenPlayback),
                .deactivationStarted,
            ],
            "A queued acquisition waits for the preceding release to finish"
        )

        await backend.resumeNextDeactivation()
        try await second.value
        try expectEqual(
            await backend.snapshot(),
            [
                .activationStarted(.spokenPlayback),
                .activationSucceeded(.spokenPlayback),
                .deactivationStarted,
                .deactivationSucceeded,
                .activationStarted(.liveRecognition),
                .activationSucceeded(.liveRecognition),
            ],
            "Deactivation completes before the next activation starts"
        )

        coordinator.release(secondOwner)
        try await waitUntil("the cleanup deactivation") {
            await backend.snapshot().filter { $0 == .deactivationStarted }.count == 2
        }
        await backend.resumeNextDeactivation()
        await coordinator.waitForPendingTransitions()
    }

    mutating func runSameOwnerReleaseReacquireCheck() async throws {
        let backend = ControllableAudioSessionBackend(holdsDeactivations: true)
        let coordinator = AudioSessionCoordinator(testing: backend)
        let owner = AudioSessionOwner()

        try await coordinator.acquire(.spokenPlayback, owner: owner)
        coordinator.release(owner)
        let reacquire = Task { @MainActor in
            try await coordinator.acquire(.spokenPlayback, owner: owner)
        }

        try await waitUntil("same-owner held deactivation") {
            await backend.snapshot().contains(.deactivationStarted)
        }
        try expectEqual(
            await backend.snapshot().filter {
                if case .activationStarted = $0 { return true }
                return false
            }.count,
            1,
            "A same-owner reacquisition cannot bypass a queued release"
        )

        await backend.resumeNextDeactivation()
        try await reacquire.value
        try expectEqual(
            coordinator.testingCurrentOwner,
            owner,
            "The same owner becomes current only after its queued release completes"
        )

        coordinator.release(owner)
        try await waitUntil("same-owner cleanup deactivation") {
            await backend.snapshot().filter { $0 == .deactivationStarted }.count == 2
        }
        await backend.resumeNextDeactivation()
        await coordinator.waitForPendingTransitions()
    }

    mutating func runCancelledStaleReconciliationCheck() async throws {
        let backend = ControllableAudioSessionBackend(holdsActivations: true)
        let coordinator = AudioSessionCoordinator(testing: backend)
        let cancelledOwner = AudioSessionOwner()
        let replacementOwner = AudioSessionOwner()

        let cancelled = Task { @MainActor in
            do {
                try await coordinator.acquire(.spokenPlayback, owner: cancelledOwner)
                try Task.checkCancellation()
            } catch {
                coordinator.release(cancelledOwner)
                throw error
            }
        }
        try await waitUntil("the cancellable activation") {
            await backend.snapshot() == [.activationStarted(.spokenPlayback)]
        }
        cancelled.cancel()

        // Queue the replacement before the cancelled caller can reconcile its
        // now-stale token. Its eventual release must not deactivate replacement.
        let replacement = Task { @MainActor in
            try await coordinator.acquire(.sourcePreview, owner: replacementOwner)
        }
        await backend.resumeNextActivation()
        try await waitUntil("the replacement activation") {
            await backend.snapshot().contains(.activationStarted(.sourcePreview))
        }
        await backend.resumeNextActivation()

        checksRun += 1
        do {
            try await cancelled.value
            throw CheckFailure(message: "The cancelled caller did not reconcile cancellation")
        } catch is CancellationError {
            // Expected.
        }
        try await replacement.value
        await coordinator.waitForPendingTransitions()

        let eventsBeforeCleanup = await backend.snapshot()
        try expect(
            !eventsBeforeCleanup.contains(.deactivationStarted),
            "A cancelled stale caller cannot deactivate its replacement"
        )
        try expectEqual(
            coordinator.testingCurrentOwner,
            replacementOwner,
            "Replacement ownership survives stale cancellation reconciliation"
        )

        coordinator.release(replacementOwner)
        await coordinator.waitForPendingTransitions()
    }

    /// A pinned session is configured once and then left alone: owners come
    /// and go inside it without an activation, a category change or a
    /// deactivation between them.
    mutating func runPinnedSessionChecks() async throws {
        let backend = ControllableAudioSessionBackend()
        let coordinator = AudioSessionCoordinator(testing: backend)
        let conversation = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        )
        let reply = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        )

        try await coordinator.pin(.speechConversation, owner: conversation)
        let pinnedEvents = await backend.snapshot()
        try expectEqual(
            pinnedEvents,
            [.activationStarted(.speechConversation), .activationSucceeded(.speechConversation)],
            "Pinning activates the pinned profile once"
        )
        try expectEqual(coordinator.testingPinnedProfile, .speechConversation, "The pin is recorded")

        try await coordinator.acquire(.spokenPlayback, owner: reply)
        try expectEqual(coordinator.testingCurrentOwner, reply, "An owner is still recorded while pinned")
        try expectEqual(coordinator.testingCurrentProfile, .spokenPlayback, "The owner's own profile is still recorded")
        coordinator.release(reply)
        await coordinator.waitForPendingTransitions()
        let eventsAfterReply = await backend.snapshot()
        try expectEqual(
            eventsAfterReply,
            pinnedEvents,
            "A reply inside a pinned session neither reconfigures nor deactivates it"
        )
        try expect(coordinator.testingCurrentOwner == nil, "The reply's ownership ended")

        // A second reply, and a recorder, change nothing either.
        let recorder = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
        )
        try await coordinator.acquire(.liveRecognition, owner: recorder)
        coordinator.release(recorder)
        try await coordinator.acquire(.spokenPlayback, owner: reply)
        coordinator.release(reply)
        await coordinator.waitForPendingTransitions()
        let eventsAfterMoreOwners = await backend.snapshot()
        try expectEqual(
            eventsAfterMoreOwners.count,
            2,
            "Any number of owners pass through a pinned session untouched"
        )

        // Pinning again, as after an interruption, reactivates.
        try await coordinator.pin(.speechConversation, owner: conversation)
        let eventsAfterRepin = await backend.snapshot()
        try expectEqual(
            Array(eventsAfterRepin.suffix(2)),
            [.activationStarted(.speechConversation), .activationSucceeded(.speechConversation)],
            "Pinning again reactivates the session"
        )

        // Someone else cannot end the pin.
        coordinator.unpin(reply)
        await coordinator.waitForPendingTransitions()
        try expectEqual(coordinator.testingPinnedProfile, .speechConversation, "Only the pin's owner can end it")

        coordinator.unpin(conversation)
        await coordinator.waitForPendingTransitions()
        try expect(coordinator.testingPinnedProfile == nil, "Unpinning ends the pin")
        let eventsAfterUnpin = await backend.snapshot()
        try expectEqual(
            Array(eventsAfterUnpin.suffix(2)),
            [.deactivationStarted, .deactivationSucceeded],
            "Unpinning an idle session deactivates it"
        )

        // After the pin, the ordinary rules are back.
        try await coordinator.acquire(.spokenPlayback, owner: reply)
        coordinator.release(reply)
        await coordinator.waitForPendingTransitions()
        let eventsAfterPin = await backend.snapshot()
        try expectEqual(
            Array(eventsAfterPin.suffix(4)),
            [
                .activationStarted(.spokenPlayback),
                .activationSucceeded(.spokenPlayback),
                .deactivationStarted,
                .deactivationSucceeded,
            ],
            "Without a pin an owner activates and deactivates as before"
        )
    }

    /// Unpinning while a reply is still playing must not cut it off: the
    /// reply's own release ends the session.
    mutating func runUnpinWhileOwnedCheck() async throws {
        let backend = ControllableAudioSessionBackend()
        let coordinator = AudioSessionCoordinator(testing: backend)
        let conversation = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        )
        let reply = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!
        )

        try await coordinator.pin(.speechConversation, owner: conversation)
        try await coordinator.acquire(.spokenPlayback, owner: reply)
        coordinator.unpin(conversation)
        await coordinator.waitForPendingTransitions()
        let eventsWhileOwned = await backend.snapshot()
        try expect(
            !eventsWhileOwned.contains(.deactivationStarted),
            "Unpinning does not deactivate a session a feature is still using"
        )
        try expectEqual(coordinator.testingCurrentOwner, reply, "The reply keeps the session after the pin ends")

        coordinator.release(reply)
        await coordinator.waitForPendingTransitions()
        let eventsAfterLastRelease = await backend.snapshot()
        try expectEqual(
            Array(eventsAfterLastRelease.suffix(2)),
            [.deactivationStarted, .deactivationSucceeded],
            "The last owner's release deactivates the session"
        )
    }

    /// A pin that cannot activate is not recorded, and the caller hears why.
    mutating func runPinFailureCheck() async throws {
        let backend = ControllableAudioSessionBackend(activationOutcomes: [.activationFailure])
        let coordinator = AudioSessionCoordinator(testing: backend)
        let conversation = AudioSessionOwner(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        )
        do {
            try await coordinator.pin(.speechConversation, owner: conversation)
            throw CheckFailure(message: "A failed activation must fail the pin")
        } catch InjectedBackendError.activationFailed {
            // Expected.
        }
        try expect(coordinator.testingPinnedProfile == nil, "A failed pin is not recorded")

        try await coordinator.pin(.speechConversation, owner: conversation)
        try expectEqual(coordinator.testingPinnedProfile, .speechConversation, "A later pin recovers")
        coordinator.unpin(conversation)
        await coordinator.waitForPendingTransitions()
    }

    mutating func runMacOSNoOpProfileCheck() async throws {
        #if os(macOS)
        let coordinator = AudioSessionCoordinator.shared
        let profiles: [AudioSessionProfile] = [
            .spokenPlayback,
            .sourcePreview,
            .clipRecording,
            .liveRecognition,
            .speechConversation,
        ]

        for profile in profiles {
            let owner = AudioSessionOwner()
            try await coordinator.acquire(profile, owner: owner)
            try expectEqual(
                coordinator.testingCurrentProfile,
                profile,
                "The macOS no-op backend accepts \(profile)"
            )
            coordinator.release(owner)
            await coordinator.waitForPendingTransitions()
            try expect(
                coordinator.testingCurrentOwner == nil,
                "The macOS no-op backend releases \(profile)"
            )
        }
        #endif
    }
}

@main
private struct AudioSessionTransitionChecksRunner {
    static func main() async {
        var checks = TransitionChecks()
        do {
            try await checks.runFIFOActivationCheck()
            try await checks.runFailureRecoveryChecks()
            try await checks.runDeactivationFailureRecoveryCheck()
            try await checks.runStaleOwnerReleaseCheck()
            try await checks.runReleaseBeforeAcquireOrderingCheck()
            try await checks.runSameOwnerReleaseReacquireCheck()
            try await checks.runCancelledStaleReconciliationCheck()
            try await checks.runPinnedSessionChecks()
            try await checks.runUnpinWhileOwnedCheck()
            try await checks.runPinFailureCheck()
            try await checks.runMacOSNoOpProfileCheck()
            let count = checks.checksRun
            print("Audio-session transition checks passed (\(count)/\(count))")
        } catch let failure as CheckFailure {
            fputs("Audio-session transition check failed: \(failure.message)\n", stderr)
            exit(1)
        } catch {
            fputs("Audio-session transition checks failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
#endif
