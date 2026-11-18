//
//  SpeechModelProvisioner.swift
//  SwiftMandarin
//
//  Decides which on-device recognizer the Interpreter uses for a language,
//  whether its model is ready, and installs it when it is not.
//
//  What was measured before writing this (scripts/probe-interpreter.sh):
//
//  - `SpeechTranscriber.installedLocales` is not a readiness test. On a Mac
//    whose list contained `en-US` and `zh-CN`, `AssetInventory.status` for
//    the same locales still said `.supported`: the files were on disk but
//    not yet assigned to the process. Only `AssetInventory.status(forModules:)`
//    with the module that will actually run answers "can I start now".
//  - In that state `downloadAndInstall()` returns at once, with no download,
//    and the status becomes `.installed`. So when the files are already on
//    disk the provisioner claims them itself; only a real download waits for
//    the person to ask.
//  - `SpeechTranscriber` delivers partial results about every four seconds
//    unless `.fastResults` is set, and about every second with it. A held
//    button rarely lasts four seconds, so the live transcript needs it.
//  - Speech-recognition authorization was `.notDetermined` throughout and
//    analysis still ran: these recognizers need the microphone only.
//

import Foundation
import Speech

/// The recognizer chosen for one language.
///
/// `SpeechTranscriber` is the general-purpose model and the first choice.
/// `DictationTranscriber` is the fallback for hardware that cannot run it.
@available(iOS 26.0, macOS 26.0, *)
nonisolated enum InterpreterSpeechModule: Sendable {
    case speech(SpeechTranscriber)
    case dictation(DictationTranscriber)

    var module: any SpeechModule {
        switch self {
        case .speech(let transcriber): return transcriber
        case .dictation(let transcriber): return transcriber
        }
    }

    /// Whether the model's files are on this device already, assigned to the
    /// app or not.
    func isOnDisk(for locale: Locale) async -> Bool {
        let installed: [Locale]
        switch self {
        case .speech: installed = await SpeechTranscriber.installedLocales
        case .dictation: installed = await DictationTranscriber.installedLocales
        }
        let wanted = locale.identifier(.bcp47)
        return installed.contains { $0.identifier(.bcp47) == wanted }
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class SpeechModelProvisioner {

    /// Builds the recognizer for `requested`, or `nil` when this device has
    /// no recognizer for that language at all.
    ///
    /// The locale is resolved by the framework rather than compared as a
    /// string: `zh-CN`, `zh_CN` and `zh-Hans-CN` are one language to it.
    /// Every caller goes through here, so the module whose status is checked
    /// is configured exactly like the module that later runs.
    func makeModule(for requested: Locale) async -> InterpreterSpeechModule? {
        await resolve(requested)?.module
    }

    /// The recognizer for `requested`, with the locale the framework
    /// resolved the request to.
    private func resolve(_ requested: Locale) async -> (module: InterpreterSpeechModule, locale: Locale)? {
        if SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) {
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: []
            )
            return (.speech(transcriber), locale)
        }
        if let locale = await DictationTranscriber.supportedLocale(equivalentTo: requested) {
            return (.dictation(DictationTranscriber(locale: locale, preset: .progressiveShortDictation)), locale)
        }
        return nil
    }

    /// How long assigning files that are already on the device may take.
    /// Measured, it returns at once.
    private static let claimDeadline: Duration = .seconds(3)

    /// Whether the recognizer for `requested` can start now.
    ///
    /// When the model's files are already on the device but not yet assigned
    /// to the app, this assigns them — it is instant and downloads nothing —
    /// so the person is only ever asked to download what is really missing.
    func assetState(for requested: Locale) async -> InterpreterAssetState {
        guard let (module, locale) = await resolve(requested) else { return .unsupported }
        switch await AssetInventory.status(forModules: [module.module]) {
        case .installed:
            return .ready
        case .unsupported:
            return .unsupported
        case .downloading:
            return .downloading(progress: nil)
        case .supported:
            guard await module.isOnDisk(for: locale) else { return .needsDownload }
            // If this does not return promptly the files were not all there,
            // and it has turned into a download nobody asked for. Stop
            // waiting on it and report what the system says is happening.
            do {
                try await withInterpreterDeadline(
                    Self.claimDeadline,
                    clock: SystemInterpreterClock(),
                    timeoutError: .speechAssetsMissing
                ) { [self] in
                    try await self.install([module], onProgress: { _ in })
                }
                return .ready
            } catch InterpreterError.speechAssetsMissing {
                switch await AssetInventory.status(forModules: [module.module]) {
                case .installed: return .ready
                case .downloading: return .downloading(progress: nil)
                default: return .needsDownload
                }
            } catch {
                return .needsDownload
            }
        @unknown default:
            return .needsDownload
        }
    }

    /// Installs the models for every locale in `locales` that is not ready,
    /// as one request so the person sees one progress figure.
    func install(
        locales: [Locale],
        onProgress: @escaping @MainActor (Double?) -> Void
    ) async throws {
        var modules: [InterpreterSpeechModule] = []
        for locale in locales {
            guard let module = await makeModule(for: locale) else {
                throw InterpreterError.speechUnsupported(language: Self.displayName(for: locale))
            }
            if await AssetInventory.status(forModules: [module.module]) != .installed {
                modules.append(module)
            }
        }
        guard !modules.isEmpty else { return }
        try await install(modules, onProgress: onProgress)
    }

    private func install(
        _ modules: [InterpreterSpeechModule],
        onProgress: @escaping @MainActor (Double?) -> Void
    ) async throws {
        let speechModules = modules.map(\.module)
        let request: AssetInstallationRequest?
        do {
            request = try await AssetInventory.assetInstallationRequest(supporting: speechModules)
        } catch {
            throw Self.installError(from: error)
        }
        // Nothing left to install: another request finished it meanwhile.
        guard let request else { return }

        onProgress(nil)
        let progress = request.progress
        // `Progress` is observable only through KVO; a short poll is simpler
        // and is cancelled on every exit, so it cannot outlive the install.
        let monitor = Task { @MainActor in
            while !Task.isCancelled, !progress.isFinished, !progress.isCancelled {
                onProgress(progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { monitor.cancel() }

        do {
            try await request.downloadAndInstall()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.installError(from: error)
        }
        try Task.checkCancellation()

        guard await AssetInventory.status(forModules: speechModules) == .installed else {
            throw InterpreterError.speechAssetInstallFailed(
                reason: String(localized: "The download finished, but the speech model is still not available.", bundle: .appLanguage)
            )
        }
        onProgress(1)
    }

    private static func installError(from error: any Error) -> InterpreterError {
        if let speechError = error as? SFSpeechError, speechError.code == .tooManyAssetLocalesAllocated {
            return .tooManyReservedLocales
        }
        // Speech errors are opaque without their domain and code.
        let nsError = error as NSError
        return .speechAssetInstallFailed(
            reason: "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))"
        )
    }

    /// A language name for messages, in the app's own interface language.
    static func displayName(for locale: Locale) -> String {
        let isChinese = locale.language.languageCode?.identifier == "zh"
        return isChinese
            ? String(localized: "Chinese", bundle: .appLanguage)
            : String(localized: "English", bundle: .appLanguage)
    }
}
