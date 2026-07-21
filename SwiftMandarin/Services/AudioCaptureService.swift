//
//  AudioCaptureService.swift
//  SwiftMandarin
//
//  Records short audio clips for the Multimodal tab and previews app-owned
//  recordings/imports. Source audio remains local and is never sent to
//  MiniMax; transcription is handled separately by Apple's Speech framework.
//

import Foundation
import Observation
import UniformTypeIdentifiers
@preconcurrency import AVFAudio
@preconcurrency import AVFoundation

nonisolated enum AudioCaptureError: LocalizedError {
    case microphoneNotAuthorized
    case recorderCouldNotStart
    case noActiveRecording
    case emptyRecording
    case unsupportedFile
    case fileTooLarge(maximumMegabytes: Int)
    case audioTooLong(maximumSeconds: Int)
    case fileAccessFailed(String)
    case previewFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphoneNotAuthorized:
            #if os(iOS)
            return String(localized: "Microphone access is required to record audio. Enable it in Settings, or import an audio file instead.")
            #else
            return String(localized: "Microphone access is required to record audio. Enable it in System Settings, or import an audio file instead.")
            #endif
        case .recorderCouldNotStart:
            return String(localized: "The audio recorder could not start. Check that another app is not using the microphone and try again.")
        case .noActiveRecording:
            return String(localized: "There is no recording to stop.")
        case .emptyRecording:
            return String(localized: "The recording did not contain any audio. Please record again.")
        case .unsupportedFile:
            return String(localized: "Choose a playable audio file such as M4A, MP3, WAV, AIFF, or CAF.")
        case .fileTooLarge(let maximumMegabytes):
            return String.localizedStringWithFormat(
                String(localized: "This audio file is too large. Choose a file smaller than %lld MB."),
                Int64(maximumMegabytes)
            )
        case .audioTooLong(let maximumSeconds):
            return String.localizedStringWithFormat(
                String(localized: "This audio is too long. Choose or record a clip no longer than %lld seconds."),
                Int64(maximumSeconds)
            )
        case .fileAccessFailed(let message):
            return String(localized: "The audio file could not be prepared:") + " " + message
        case .previewFailed(let message):
            return String(localized: "The audio preview could not start:") + " " + message
        }
    }
}

nonisolated enum AudioInputSource: Sendable, Equatable {
    case recording
    case importFile
}

/// Metadata for an app-owned temporary audio file. The original security-
/// scoped import is never retained; `url` always points into the app's temp
/// directory and can therefore be used safely by asynchronous recognition.
nonisolated struct PreparedAudioFile: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let displayName: String
    let byteCount: Int64
    let duration: TimeInterval?
    let source: AudioInputSource

    init(
        id: UUID = UUID(),
        url: URL,
        displayName: String,
        byteCount: Int64,
        duration: TimeInterval?,
        source: AudioInputSource
    ) {
        self.id = id
        self.url = url
        self.displayName = displayName
        self.byteCount = byteCount
        self.duration = duration
        self.source = source
    }
}

/// Copies and validates audio selected through a security-scoped file picker.
/// All expensive file work is kept off the main actor.
nonisolated enum AudioInputFileStore {
    static let maximumFileSize = 100 * 1_024 * 1_024
    static let maximumDurationSeconds: TimeInterval = 60

    private static let supportedExtensions: Set<String> = [
        "aac", "aif", "aiff", "caf", "m4a", "mp3", "wav"
    ]

    static func importAudio(from sourceURL: URL) async throws -> PreparedAudioFile {
        let originalName = sourceURL.lastPathComponent.isEmpty
            ? String(localized: "Imported Audio")
            : sourceURL.lastPathComponent
        let copiedURL: URL

        do {
            let hasScopedAccess = sourceURL.startAccessingSecurityScopedResource()
            let copyTask = Task.detached(priority: .userInitiated) {
                try copyValidatedAudio(from: sourceURL)
            }
            copiedURL = try await withTaskCancellationHandler {
                defer {
                    if hasScopedAccess {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                let url = try await copyTask.value
                do {
                    try Task.checkCancellation()
                } catch {
                    remove(url)
                    throw error
                }
                return url
            } onCancel: {
                copyTask.cancel()
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AudioCaptureError {
            throw error
        } catch {
            throw AudioCaptureError.fileAccessFailed(error.localizedDescription)
        }

        do {
            return try await inspectOwnedAudio(
                at: copiedURL,
                displayName: originalName,
                source: .importFile
            )
        } catch {
            remove(copiedURL)
            throw error
        }
    }

    static func prepareRecording(at url: URL) async throws -> PreparedAudioFile {
        do {
            return try await inspectOwnedAudio(
                at: url,
                displayName: String(localized: "Recorded Audio.m4a"),
                source: .recording
            )
        } catch {
            remove(url)
            throw error
        }
    }

    static func remove(_ url: URL) {
        // Every URL accepted here was created in our dedicated temp folder.
        // The containment check prevents an accidental caller from deleting an
        // arbitrary user-selected file.
        let folder = temporaryFolder.standardizedFileURL.path
        let candidate = url.standardizedFileURL.path
        guard candidate.hasPrefix(folder + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAllTemporaryFiles() {
        guard let candidates = try? FileManager.default.contentsOfDirectory(
            at: temporaryFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for candidate in candidates {
            remove(candidate)
        }
    }

    static var temporaryFolder: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftMandarinAudioInput", isDirectory: true)
    }

    private static func copyValidatedAudio(from sourceURL: URL) throws -> URL {
        let values = try sourceURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .fileSizeKey,
            .contentTypeKey
        ])
        guard values.isRegularFile == true else {
            throw AudioCaptureError.unsupportedFile
        }

        let size = values.fileSize ?? 0
        guard size > 0 else { throw AudioCaptureError.emptyRecording }
        guard size <= maximumFileSize else {
            throw AudioCaptureError.fileTooLarge(maximumMegabytes: maximumFileSize / 1_024 / 1_024)
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        let declaredType = values.contentType ?? UTType(filenameExtension: fileExtension)
        let isAudioType = declaredType?.conforms(to: .audio) == true
        guard isAudioType || supportedExtensions.contains(fileExtension) else {
            throw AudioCaptureError.unsupportedFile
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: temporaryFolder, withIntermediateDirectories: true)
        let safeExtension = supportedExtensions.contains(fileExtension) ? fileExtension : "audio"
        let destination = temporaryFolder
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(safeExtension)

        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
            let destinationHandle = try FileHandle(forWritingTo: destination)
            var copiedByteCount = 0
            defer {
                try? sourceHandle.close()
                try? destinationHandle.close()
            }

            while true {
                try Task.checkCancellation()
                guard let chunk = try sourceHandle.read(upToCount: 1_024 * 1_024),
                      !chunk.isEmpty else { break }
                copiedByteCount += chunk.count
                guard copiedByteCount <= maximumFileSize else {
                    throw AudioCaptureError.fileTooLarge(
                        maximumMegabytes: maximumFileSize / 1_024 / 1_024
                    )
                }
                try destinationHandle.write(contentsOf: chunk)
            }
            try Task.checkCancellation()
            try destinationHandle.synchronize()
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
        let copiedSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard copiedSize > 0 else {
            try? fileManager.removeItem(at: destination)
            throw AudioCaptureError.emptyRecording
        }
        guard copiedSize <= maximumFileSize else {
            try? fileManager.removeItem(at: destination)
            throw AudioCaptureError.fileTooLarge(maximumMegabytes: maximumFileSize / 1_024 / 1_024)
        }
        return destination
    }

    private static func inspectOwnedAudio(
        at url: URL,
        displayName: String,
        source: AudioInputSource
    ) async throws -> PreparedAudioFile {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw AudioCaptureError.unsupportedFile }

        let byteCount = Int64(values.fileSize ?? 0)
        guard byteCount > 0 else { throw AudioCaptureError.emptyRecording }
        guard byteCount <= Int64(maximumFileSize) else {
            throw AudioCaptureError.fileTooLarge(maximumMegabytes: maximumFileSize / 1_024 / 1_024)
        }

        let asset = AVURLAsset(url: url)
        guard (try? await asset.load(.isPlayable)) == true else {
            throw AudioCaptureError.unsupportedFile
        }

        guard let loadedDuration = try? await asset.load(.duration) else {
            throw AudioCaptureError.unsupportedFile
        }
        let seconds = CMTimeGetSeconds(loadedDuration)
        guard seconds.isFinite, seconds > 0 else {
            throw AudioCaptureError.emptyRecording
        }
        // A small tolerance avoids rejecting a recorder deadline that lands a
        // fraction of a second late while still honoring Apple Speech's
        // documented one-minute recognition-task boundary.
        guard seconds <= maximumDurationSeconds + 1 else {
            throw AudioCaptureError.audioTooLong(
                maximumSeconds: Int(maximumDurationSeconds)
            )
        }

        return PreparedAudioFile(
            url: url,
            displayName: displayName,
            byteCount: byteCount,
            duration: seconds,
            source: source
        )
    }
}

/// A narrow ownership bridge for the app's single iOS audio session. Source
/// recording/preview and read-aloud are mutually exclusive, and only the
/// engine that currently owns audio activity may deactivate the session.
@MainActor
final class SourceAudioActivityCoordinator {
    static let shared = SourceAudioActivityCoordinator()

    private weak var service: AudioCaptureService?
    #if os(iOS)
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    #endif

    var hasActiveSourceAudio: Bool {
        service?.hasActiveAudio == true
    }

    func acquire(_ service: AudioCaptureService) {
        if let existing = self.service, existing !== service {
            existing.stopForExclusiveAudioHandoff()
        }
        self.service = service
    }

    func release(_ service: AudioCaptureService) {
        guard self.service === service else { return }
        self.service = nil
    }

    func stopSourceAudioForSpeech() {
        service?.stopForSpeechPlayback()
    }

    private init() {
        #if os(iOS)
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawValue) == .began else { return }
            Task { @MainActor [weak self] in
                await self?.handleAudioSessionLoss(
                    message: String(localized: "Audio was interrupted by another app. Please try again.")
                )
            }
        }
        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let rawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: rawValue) == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in
                await self?.handleAudioSessionLoss(
                    message: String(localized: "Audio stopped because the playback or recording device was disconnected.")
                )
            }
        }
        #endif
    }

    private func handleAudioSessionLoss(message: String) async {
        service?.handleAudioSessionLoss(message: message)
        SpeechService.handleAudioSessionLoss(message: message)
        await SpeechRecognitionService.shared.handleAudioSessionLoss(message: message)
    }
}

/// Main-actor recorder/player used by the Multimodal audio input pane.
@MainActor
@Observable
final class AudioCaptureService: NSObject, AVAudioPlayerDelegate {
    private(set) var isRecording = false
    private(set) var isStartingRecording = false
    private(set) var isStartingPlayback = false
    private(set) var playingURL: URL?
    private(set) var completedRecordingURL: URL?
    private(set) var playbackErrorMessage: String?

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var player: AVAudioPlayer?
    private var recordingStartID: UUID?
    private var playbackStartID: UUID?
    private var recordingSessionOwner: AudioSessionOwner?
    private var playbackSessionOwner: AudioSessionOwner?

    var hasActiveAudio: Bool {
        isRecording || isStartingRecording || isStartingPlayback
            || recorder != nil || playingURL != nil || player?.isPlaying == true
            || recordingSessionOwner != nil || playbackSessionOwner != nil
    }

    func startRecording() async throws {
        guard !isRecording, !isStartingRecording else { return }
        let requestID = UUID()
        recordingStartID = requestID
        completedRecordingURL = nil
        playbackErrorMessage = nil
        isStartingRecording = true
        defer {
            if recordingStartID == requestID {
                recordingStartID = nil
                isStartingRecording = false
            }
        }

        try Task.checkCancellation()
        guard await requestMicrophonePermissionIfNeeded() else {
            throw AudioCaptureError.microphoneNotAuthorized
        }
        try Task.checkCancellation()
        guard recordingStartID == requestID else { throw CancellationError() }

        stopPlayback()
        await SpeechRecognitionService.shared.stopRecording()
        try Task.checkCancellation()
        guard recordingStartID == requestID else { throw CancellationError() }
        SpeechService.stop()

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: AudioInputFileStore.temporaryFolder,
            withIntermediateDirectories: true
        )
        let url = AudioInputFileStore.temporaryFolder
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]
        let sessionOwner = AudioSessionOwner()

        do {
            SourceAudioActivityCoordinator.shared.acquire(self)
            recordingSessionOwner = sessionOwner
            try await AudioSessionCoordinator.shared.acquire(
                .clipRecording,
                owner: sessionOwner
            )
            try Task.checkCancellation()
            guard recordingStartID == requestID,
                  recordingSessionOwner == sessionOwner else {
                AudioSessionCoordinator.shared.release(sessionOwner)
                throw CancellationError()
            }

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw AudioCaptureError.recorderCouldNotStart
            }
            self.recorder = recorder
            recordingURL = url
            isRecording = true
        } catch {
            AudioSessionCoordinator.shared.release(sessionOwner)
            if recordingSessionOwner == sessionOwner {
                recordingSessionOwner = nil
            }
            AudioInputFileStore.remove(url)
            releaseSessionOwnershipIfIdle()
            if error is CancellationError {
                throw error
            }
            if let captureError = error as? AudioCaptureError {
                throw captureError
            }
            throw AudioCaptureError.fileAccessFailed(error.localizedDescription)
        }
    }

    func stopRecording() throws -> URL {
        guard let recorder, let recordingURL else {
            throw AudioCaptureError.noActiveRecording
        }

        recordingStartID = nil
        isStartingRecording = false
        recorder.stop()
        let sessionOwner = recordingSessionOwner
        recordingSessionOwner = nil
        self.recorder = nil
        self.recordingURL = nil
        isRecording = false
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
        releaseSessionOwnershipIfIdle()

        let byteCount = (try? recordingURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard byteCount > 0 else {
            AudioInputFileStore.remove(recordingURL)
            throw AudioCaptureError.emptyRecording
        }
        return recordingURL
    }

    func discardActiveRecording() {
        recordingStartID = nil
        isStartingRecording = false
        let sessionOwner = recordingSessionOwner
        recordingSessionOwner = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let recordingURL {
            AudioInputFileStore.remove(recordingURL)
        }
        recordingURL = nil
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
        releaseSessionOwnershipIfIdle()
    }

    func togglePlayback(of url: URL) async throws {
        if playingURL == url || isStartingPlayback {
            stopPlayback()
            return
        }

        stopPlayback()
        let requestID = UUID()
        let sessionOwner = AudioSessionOwner()
        playbackStartID = requestID
        isStartingPlayback = true
        do {
            await SpeechRecognitionService.shared.stopRecording()
            try Task.checkCancellation()
            guard playbackStartID == requestID else { throw CancellationError() }
            SpeechService.stop()
            playbackErrorMessage = nil
            SourceAudioActivityCoordinator.shared.acquire(self)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.prepareToPlay() else {
                throw AudioCaptureError.previewFailed(
                    String(localized: "The player could not decode this file.")
                )
            }

            playbackSessionOwner = sessionOwner
            try await AudioSessionCoordinator.shared.acquire(
                .sourcePreview,
                owner: sessionOwner
            )
            try Task.checkCancellation()
            guard playbackStartID == requestID,
                  playbackSessionOwner == sessionOwner else {
                AudioSessionCoordinator.shared.release(sessionOwner)
                throw CancellationError()
            }

            self.player = player
            playingURL = url
            playbackStartID = nil
            isStartingPlayback = false
            guard player.play() else {
                self.player = nil
                playingURL = nil
                throw AudioCaptureError.previewFailed(
                    String(localized: "The player could not decode this file.")
                )
            }
        } catch {
            AudioSessionCoordinator.shared.release(sessionOwner)
            if playbackStartID == requestID {
                playbackStartID = nil
                isStartingPlayback = false
            }
            if playbackSessionOwner == sessionOwner {
                playbackSessionOwner = nil
                player = nil
                playingURL = nil
            }
            releaseSessionOwnershipIfIdle()
            if error is CancellationError {
                throw error
            }
            if let captureError = error as? AudioCaptureError {
                throw captureError
            }
            throw AudioCaptureError.previewFailed(error.localizedDescription)
        }
    }

    func stopPlayback() {
        playbackStartID = nil
        let sessionOwner = playbackSessionOwner
        playbackSessionOwner = nil
        isStartingPlayback = false
        player?.stop()
        player = nil
        playingURL = nil
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
        releaseSessionOwnershipIfIdle()
    }

    func stopAll() {
        discardActiveRecording()
        stopPlayback()
        if let completedRecordingURL {
            AudioInputFileStore.remove(completedRecordingURL)
            self.completedRecordingURL = nil
        }
    }

    func stopForSpeechPlayback() {
        if isRecording, let url = try? stopRecording() {
            completedRecordingURL = url
        } else {
            discardActiveRecording()
        }
        stopPlayback()
    }

    func clearPlaybackError() {
        playbackErrorMessage = nil
    }

    func takeCompletedRecordingURL() -> URL? {
        defer { completedRecordingURL = nil }
        return completedRecordingURL
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        let sessionOwner = playbackSessionOwner
        playbackSessionOwner = nil
        self.player = nil
        playingURL = nil
        if !flag {
            playbackErrorMessage = String(localized: "The audio preview stopped before it finished.")
        }
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
        releaseSessionOwnershipIfIdle()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === self.player else { return }
        let sessionOwner = playbackSessionOwner
        playbackSessionOwner = nil
        self.player = nil
        playingURL = nil
        playbackErrorMessage = AudioCaptureError.previewFailed(
            error?.localizedDescription ?? String(localized: "The player could not decode this file.")
        ).localizedDescription
        if let sessionOwner {
            AudioSessionCoordinator.shared.release(sessionOwner)
        }
        releaseSessionOwnershipIfIdle()
    }

    fileprivate func stopForExclusiveAudioHandoff() {
        handleAudioSessionLoss(
            message: String(localized: "Audio stopped because another SwiftMandarin window started using audio.")
        )
    }

    fileprivate func handleAudioSessionLoss(message: String) {
        if isRecording {
            do {
                completedRecordingURL = try stopRecording()
            } catch {
                discardActiveRecording()
                playbackErrorMessage = error.localizedDescription
            }
        } else {
            discardActiveRecording()
        }
        stopPlayback()
        if playbackErrorMessage == nil {
            playbackErrorMessage = message
        }
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func releaseSessionOwnershipIfIdle() {
        guard !hasActiveAudio else { return }
        SourceAudioActivityCoordinator.shared.release(self)
    }
}
