//
//  InterpreterTranslationService.swift
//  SwiftMandarin
//
//  On-device translation between English and Chinese for the Interpreter,
//  through Apple's Translation framework.
//
//  Two things about that framework shape this file:
//
//  - `TranslationSession(installedSource:target:)` translates only when the
//    languages are already installed. It cannot ask for a download. So this
//    service only reports whether they are installed (`assetState`); the
//    download itself is requested by the Interpreter screen, from a
//    `.translationTask`, which is the only place the system allows it.
//  - The framework's objects are not `Sendable`. Every one of them is
//    created, used and dropped inside a single worker task that takes
//    requests from a stream, so none ever crosses an isolation boundary, and
//    the sessions it has warmed stay warm between turns.
//
//  Measured on the development Mac (scripts/probe-interpreter.sh
//  translation and translation-behaviour): the first translation in a
//  process took 0.7–1.5 s, later ones 20–70 ms with the low-latency
//  strategy and 265–580 ms with the high-fidelity one. A translation that
//  has started cannot be cancelled, and the system runs one at a time, even
//  across sessions and strategies. Hence one worker, the explicit strategy,
//  and `warm`, which a turn calls while its button is held.
//
//  Nothing here leaves the device.
//

import Foundation
import Translation

/// The worker's side of the conversation: plain Sendable requests in, plain
/// Sendable answers out.
@available(iOS 26.0, macOS 26.0, *)
nonisolated private enum TranslationWorker {

    /// What `LanguageAvailability` said, reduced to what the service needs:
    /// the state of each model for English ⇄ Chinese, both ways.
    struct Availability: Sendable {
        enum Pair: Sendable { case installed, needsDownload, unsupported }
        /// The traditional model; on releases with one model, that model.
        var fast: Pair
        /// The fluent model. `.unsupported` on releases without it.
        var natural: Pair

        /// Either model can translate, so a turn can go ahead.
        var isUsable: Bool { fast == .installed || natural == .installed }

        var installedModels: Set<InterpreterTranslationModel> {
            var models: Set<InterpreterTranslationModel> = []
            if fast == .installed { models.insert(.fast) }
            if natural == .installed { models.insert(.natural) }
            return models
        }

        static let unknown = Availability(fast: .unsupported, natural: .unsupported)
    }

    enum Job: Sendable {
        case availability(reply: CheckedContinuation<Availability, Never>)
        /// `lowLatency` is `nil` on releases that offer no choice of model.
        case translate(text: String, direction: TranslationDirection, lowLatency: Bool?,
                       reply: CheckedContinuation<String, any Error>)
    }

    private struct SessionKey: Hashable {
        let direction: TranslationDirection
        let lowLatency: Bool?
    }

    /// Serves jobs one at a time until the stream ends. The sessions live in
    /// this function's frame and nowhere else.
    static func run(_ jobs: AsyncStream<Job>) async {
        var sessions: [SessionKey: TranslationSession] = [:]
        for await job in jobs {
            switch job {
            case .availability(let reply):
                reply.resume(returning: await availability())
            case .translate(let text, let direction, let lowLatency, let reply):
                let key = SessionKey(direction: direction, lowLatency: lowLatency)
                do {
                    let translated = try await translate(text, key: key, sessions: &sessions)
                    reply.resume(returning: translated)
                } catch {
                    reply.resume(throwing: interpreterError(from: error))
                }
            }
        }
    }

    private static func translate(
        _ text: String,
        key: SessionKey,
        sessions: inout [SessionKey: TranslationSession]
    ) async throws -> String {
        let session = sessions[key] ?? makeSession(for: key)
        sessions[key] = session
        do {
            return try await session.translate(text).targetText
        } catch {
            // A missing language pack will not fix itself; anything else is
            // worth one more attempt with a fresh session, which is what
            // recovers a session the system has invalidated.
            if isPermanent(error) { throw error }
            let fresh = makeSession(for: key)
            sessions[key] = fresh
            return try await fresh.translate(text).targetText
        }
    }

    private static func makeSession(for key: SessionKey) -> TranslationSession {
        let source = key.direction.sourceLanguage
        let target = key.direction.targetLanguage
        if #available(iOS 26.4, macOS 26.4, *), let lowLatency = key.lowLatency {
            return TranslationSession(
                installedSource: source,
                target: target,
                preferredStrategy: lowLatency ? .lowLatency : .highFidelity
            )
        }
        return TranslationSession(installedSource: source, target: target)
    }

    /// Asks the system what is installed. A "not installed" is asked about
    /// once more after a moment: on one cold start here the first answer for
    /// the traditional model was "not installed" for languages that were
    /// installed, and that translated a second later. A wrong "not
    /// installed" puts a Download banner in front of someone who has nothing
    /// to download.
    private static func availability() async -> Availability {
        let first = await currentAvailability()
        guard !first.isUsable else { return first }
        try? await Task.sleep(for: .milliseconds(400))
        return await currentAvailability()
    }

    private static func currentAvailability() async -> Availability {
        let english = TranslationDirection.englishToChinese.sourceLanguage
        let chinese = TranslationDirection.englishToChinese.targetLanguage

        func pair(_ checker: LanguageAvailability) async -> Availability.Pair {
            let forward = await checker.status(from: english, to: chinese)
            let backward = await checker.status(from: chinese, to: english)
            if forward == .installed, backward == .installed { return .installed }
            if forward == .unsupported || backward == .unsupported { return .unsupported }
            return .needsDownload
        }

        if #available(iOS 26.4, macOS 26.4, *) {
            return Availability(
                fast: await pair(LanguageAvailability(preferredStrategy: .lowLatency)),
                natural: await pair(LanguageAvailability(preferredStrategy: .highFidelity))
            )
        }
        return Availability(fast: await pair(LanguageAvailability()), natural: .unsupported)
    }

    private static func isPermanent(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        switch interpreterError(from: error) {
        case .translationLanguagesMissing, .translationUnsupported: return true
        default: return false
        }
    }

    private static func interpreterError(from error: any Error) -> InterpreterError {
        if let known = error as? InterpreterError { return known }
        if TranslationError.notInstalled ~= error {
            return .translationLanguagesMissing
        }
        if TranslationError.unsupportedLanguagePairing ~= error
            || TranslationError.unsupportedSourceLanguage ~= error
            || TranslationError.unsupportedTargetLanguage ~= error {
            return .translationUnsupported
        }
        // Translation errors are opaque without their domain and code.
        let nsError = error as NSError
        return .translationFailed(reason: "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))")
    }
}

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class InterpreterTranslationService: InterpreterTranslating {

    /// One model in one direction: what a session, and a warm-up, is for.
    private struct Route: Hashable {
        let direction: TranslationDirection
        let model: InterpreterTranslationModel
    }

    private let jobs: AsyncStream<TranslationWorker.Job>.Continuation
    private let worker: Task<Void, Never>
    /// The models the system last reported as installed, both ways.
    private var installedModels: Set<InterpreterTranslationModel> = []
    /// Warm-ups that are queued or running. A second request for the same
    /// route adds nothing while the first has yet to finish.
    private var warming: Set<Route> = []

    init() {
        let (stream, continuation) = AsyncStream<TranslationWorker.Job>.makeStream()
        jobs = continuation
        worker = Task.detached(priority: .userInitiated) {
            await TranslationWorker.run(stream)
        }
    }

    deinit {
        jobs.finish()
    }

    /// Ready when either model is installed: a turn needs one translation,
    /// and whichever model is there can give it.
    func assetState() async -> InterpreterAssetState {
        let availability = await withCheckedContinuation { (reply: CheckedContinuation<TranslationWorker.Availability, Never>) in
            if case .terminated = jobs.yield(.availability(reply: reply)) {
                reply.resume(returning: .unknown)
            }
        }
        installedModels = availability.installedModels
        if availability.isUsable { return .ready }
        if availability.fast == .needsDownload || availability.natural == .needsDownload {
            return .needsDownload
        }
        return .unsupported
    }

    var offersTwoModels: Bool {
        installedModels.count == 2
    }

    /// Translates one word and discards the result. That is the whole of it:
    /// the system loads a model when it is asked to translate, and lets it go
    /// again after a few idle seconds or when the other model is used.
    func warm(_ direction: TranslationDirection, model: InterpreterTranslationModel) async {
        let route = Route(direction: direction, model: model)
        guard warming.insert(route).inserted else { return }
        defer { warming.remove(route) }
        let word = direction == .englishToChinese ? "Hello" : "你好"
        _ = try? await translate(word, direction: direction, model: model)
    }

    func translate(
        _ text: String,
        direction: TranslationDirection,
        model: InterpreterTranslationModel
    ) async throws -> String {
        let lowLatency = prefersLowLatency(for: model)
        let translated = try await withCheckedThrowingContinuation { (reply: CheckedContinuation<String, any Error>) in
            let job = TranslationWorker.Job.translate(
                text: text,
                direction: direction,
                lowLatency: lowLatency,
                reply: reply
            )
            if case .terminated = jobs.yield(job) {
                reply.resume(throwing: CancellationError())
            }
        }
        // The low-latency model leaves a space after Chinese punctuation.
        return TranscriptAssembler.normalize(translated)
    }

    /// Which strategy a model means on this release. `nil` where the system
    /// offers no choice. A request for a model that is not installed gets
    /// the one that is.
    private func prefersLowLatency(for model: InterpreterTranslationModel) -> Bool? {
        guard #available(iOS 26.4, macOS 26.4, *) else { return nil }
        let hasNatural = installedModels.contains(.natural)
        let hasFast = installedModels.contains(.fast)
        switch model {
        case .fast: return hasFast || !hasNatural
        case .natural: return !hasNatural
        }
    }
}
