//
//  InterpreterProbe.swift
//  SwiftMandarin
//
//  Measurement tool for the push-to-talk interpreter. It is not a pass/fail
//  check and is not part of init.sh: it reports what the machine it runs on
//  can do and how long each pipeline stage takes there, so the numbers in
//  docs/handoff/push-to-talk-interpreter/PLANS.md can be re-measured.
//
//  Inert unless compiled with -D INTERPRETER_PROBE. Run it through
//  scripts/probe-interpreter.sh.
//

#if INTERPRETER_PROBE

@preconcurrency import AVFAudio
import CoreMedia
import Foundation
import os
import Speech
import Translation

@main
struct InterpreterProbe {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first ?? "capabilities" {
        case "capabilities":
            await capabilities()
        case "translation":
            await translationTiming()
        case "translation-behaviour":
            await translationBehaviour()
        case "speech":
            await speech(arguments: Array(arguments.dropFirst()))
        default:
            print("usage: probe capabilities | translation | translation-behaviour | speech <locale> <audio-file> [--dictation] [--fast-results] [--unpaced] [--context word,word]")
            exit(2)
        }
    }

    // MARK: - Shared helpers

    static func milliseconds(_ duration: Duration) -> Int {
        let parts = duration.components
        return Int(parts.seconds) * 1_000 + Int(parts.attoseconds / 1_000_000_000_000_000)
    }

    /// Speech and Translation errors are opaque without their domain and code.
    static func describe(_ error: any Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription) (\(nsError.domain) \(nsError.code))"
    }

    // MARK: - capabilities

    /// What the Speech and Translation frameworks report here. Read-only:
    /// nothing is installed, reserved or recorded.
    static func capabilities() async {
        print("== Speech ==")
        print("SpeechTranscriber.isAvailable:", SpeechTranscriber.isAvailable)
        print("speech authorization (0 undetermined, 1 denied, 2 restricted, 3 authorized):",
              SFSpeechRecognizer.authorizationStatus().rawValue)

        let supported = await SpeechTranscriber.supportedLocales
        let installed = await SpeechTranscriber.installedLocales
        print("SpeechTranscriber.supportedLocales count:", supported.count)
        print("SpeechTranscriber.installedLocales:",
              installed.map { $0.identifier(.bcp47) }.sorted())

        let dictationSupported = await DictationTranscriber.supportedLocales
        let dictationInstalled = await DictationTranscriber.installedLocales
        print("DictationTranscriber.supportedLocales count:", dictationSupported.count)
        print("DictationTranscriber.installedLocales:",
              dictationInstalled.map { $0.identifier(.bcp47) }.sorted())

        print("AssetInventory.maximumReservedLocales:", AssetInventory.maximumReservedLocales)
        let reserved = await AssetInventory.reservedLocales
        print("AssetInventory.reservedLocales:", reserved.map { $0.identifier(.bcp47) }.sorted())

        for identifier in ["en-US", "zh-CN", "zh-Hans-CN", "zh_CN"] {
            let requested = Locale(identifier: identifier)
            let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: requested)
            let dictationResolved = await DictationTranscriber.supportedLocale(equivalentTo: requested)
            print("locale \(identifier): speech ->",
                  resolved?.identifier(.bcp47) ?? "nil",
                  "| dictation ->",
                  dictationResolved?.identifier(.bcp47) ?? "nil")

            if let resolved {
                let transcriber = SpeechTranscriber(
                    locale: resolved,
                    transcriptionOptions: [],
                    reportingOptions: [.volatileResults],
                    attributeOptions: []
                )
                let status = await AssetInventory.status(forModules: [transcriber])
                let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
                print("   speech asset status:", String(describing: status),
                      "| analyzer format:", format.map { String(describing: $0) } ?? "nil")
            }
            if let dictationResolved {
                let dictation = DictationTranscriber(locale: dictationResolved, preset: .progressiveShortDictation)
                let status = await AssetInventory.status(forModules: [dictation])
                print("   dictation asset status:", String(describing: status))
            }
        }

        print("== Translation ==")
        let availability = LanguageAvailability()
        let languages = await availability.supportedLanguages
        let relevant = languages
            .map { $0.maximalIdentifier }
            .filter { $0.hasPrefix("en") || $0.hasPrefix("zh") }
            .sorted()
        print("supportedLanguages (en/zh, maximal):", relevant)

        let pairs: [(String, String)] = [
            ("en", "zh-Hans"), ("zh-Hans", "en"),
            ("en-US", "zh-Hans-CN"), ("zh-Hans-CN", "en-US"),
            ("en-US", "zh-CN"), ("zh-CN", "en-US"),
        ]
        for (source, target) in pairs {
            let status = await availability.status(
                from: Locale.Language(identifier: source),
                to: Locale.Language(identifier: target)
            )
            print("status \(source) -> \(target):", String(describing: status))
        }

        if #available(macOS 26.4, iOS 26.4, *) {
            print("preferredStrategy == lowLatency:", availability.preferredStrategy == .lowLatency)
            let strategies: [(String, TranslationSession.Strategy)] = [
                ("lowLatency", .lowLatency), ("highFidelity", .highFidelity),
            ]
            for (name, strategy) in strategies {
                let scoped = LanguageAvailability(preferredStrategy: strategy)
                let status = await scoped.status(
                    from: Locale.Language(identifier: "en"),
                    to: Locale.Language(identifier: "zh-Hans")
                )
                print("strategy \(name) en -> zh-Hans:", String(describing: status))
            }
        }

        print("== Voices ==")
        for code in ["en-US", "zh-CN"] {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == code }
            let summary = Dictionary(grouping: voices, by: { $0.quality.rawValue })
                .map { "quality \($0.key): \($0.value.count)" }
                .sorted()
            print("\(code): \(voices.count) voices —", summary.joined(separator: ", "))
        }
    }

    // MARK: - translation

    static let englishSentences = [
        "Where is the nearest train station?",
        "Could you help me? I am looking for a pharmacy that is still open.",
        "Thank you so much. How much does this cost, and can I pay by card?",
    ]
    static let chineseSentences = [
        "请问最近的火车站在哪里？",
        "你能帮我一下吗？我在找一家还开着的药店。",
        "太感谢了。这个多少钱？可以刷卡吗？",
    ]

    /// How long on-device translation takes for interpreter-sized sentences,
    /// per strategy, first pass and warm pass. Uses installed languages only.
    static func translationTiming() async {
        let english = Locale.Language(identifier: "en")
        let chinese = Locale.Language(identifier: "zh-Hans")

        print("== default strategy ==")
        await timeTranslation(label: "default en->zh-Hans", sentences: englishSentences) {
            TranslationSession(installedSource: english, target: chinese)
        }
        await timeTranslation(label: "default zh-Hans->en", sentences: chineseSentences) {
            TranslationSession(installedSource: chinese, target: english)
        }

        if #available(macOS 26.4, iOS 26.4, *) {
            print("== lowLatency ==")
            await timeTranslation(label: "lowLatency en->zh-Hans", sentences: englishSentences) {
                TranslationSession(installedSource: english, target: chinese, preferredStrategy: .lowLatency)
            }
            await timeTranslation(label: "lowLatency zh-Hans->en", sentences: chineseSentences) {
                TranslationSession(installedSource: chinese, target: english, preferredStrategy: .lowLatency)
            }
            print("== highFidelity ==")
            await timeTranslation(label: "highFidelity en->zh-Hans", sentences: englishSentences) {
                TranslationSession(installedSource: english, target: chinese, preferredStrategy: .highFidelity)
            }
            await timeTranslation(label: "highFidelity zh-Hans->en", sentences: chineseSentences) {
                TranslationSession(installedSource: chinese, target: english, preferredStrategy: .highFidelity)
            }
        }
    }

    static func timeTranslation(
        label: String,
        sentences: [String],
        makeSession: () -> TranslationSession
    ) async {
        let clock = ContinuousClock()
        let session = makeSession()
        var first: [Int] = []
        var outputs: [String] = []
        for sentence in sentences {
            let start = clock.now
            do {
                let response = try await session.translate(sentence)
                first.append(milliseconds(clock.now - start))
                outputs.append(response.targetText)
            } catch {
                print("  \(label) FAILED:", describe(error))
                return
            }
        }
        var warm: [Int] = []
        for sentence in sentences {
            let start = clock.now
            _ = try? await session.translate(sentence)
            warm.append(milliseconds(clock.now - start))
        }
        print("  \(label): first pass \(first) ms | warm pass \(warm) ms")
        for output in outputs {
            print("     ·", output)
        }
    }

    // MARK: - translation-behaviour

    /// The questions the latency optimizations depend on, answered by
    /// measurement: is a translation repeatable, does it use the sentence
    /// before, can it be cancelled, and what do two at once cost each other.
    /// Uses installed languages only.
    static func translationBehaviour() async {
        guard #available(macOS 26.4, iOS 26.4, *) else {
            print("translation-behaviour needs a release that offers a choice of strategy (26.4 or later)")
            return
        }
        let english = Locale.Language(identifier: "en")
        let chinese = Locale.Language(identifier: "zh-Hans")
        let clock = ContinuousClock()

        // Each of these runs in a task of its own, with a session of its own:
        // sessions are not Sendable and never leave the task that made them.
        @Sendable func timed(
            _ texts: [String],
            from source: Locale.Language,
            to target: Locale.Language,
            strategy: TranslationSession.Strategy,
            startAt: ContinuousClock.Instant? = nil
        ) async -> [(text: String, output: String, milliseconds: Int)] {
            let session = TranslationSession(installedSource: source, target: target, preferredStrategy: strategy)
            _ = try? await session.translate(source == english ? "Hello" : "你好")
            // Warming a session takes a different time for each model, so
            // concurrent runs agree on a moment to start rather than on a delay.
            if let startAt { try? await Task.sleep(until: startAt, clock: clock) }
            var rows: [(text: String, output: String, milliseconds: Int)] = []
            for text in texts {
                let start = clock.now
                do {
                    let output = try await session.translate(text).targetText
                    rows.append((text, output, milliseconds(clock.now - start)))
                } catch {
                    rows.append((text, "FAILED: \(describe(error))", milliseconds(clock.now - start)))
                }
            }
            return rows
        }

        let strategies: [(String, TranslationSession.Strategy)] = [
            ("lowLatency", .lowLatency), ("highFidelity", .highFidelity),
        ]

        print("== repeatable? the same sentence three times ==")
        for (name, strategy) in strategies {
            let sentence = "Could you help me? I am looking for a pharmacy that is still open."
            let rows = await timed([sentence, sentence, sentence], from: english, to: chinese, strategy: strategy)
            let distinct = Set(rows.map(\.output)).count
            print("  \(name): \(distinct) distinct output(s), \(rows.map(\.milliseconds)) ms")
            for output in Set(rows.map(\.output)).sorted() { print("     ·", output) }
        }

        print("== context? two sentences together, then each alone ==")
        let pairs: [(Locale.Language, Locale.Language, String, String)] = [
            (chinese, english, "我昨天去了商店。", "买了很多东西。"),
            (chinese, english, "我妹妹下周来看我。", "很久没见了。"),
            (english, chinese, "I met Alex at the bank.", "It was closed, so we left."),
            (english, chinese, "My sister lost her passport.", "Can you help her?"),
        ]
        for (name, strategy) in strategies {
            for (source, target, first, second) in pairs {
                let joiner = source == english ? " " : ""
                let rows = await timed([first + joiner + second, first, second], from: source, to: target, strategy: strategy)
                print("  \(name): together \(rows[0].milliseconds) ms | alone \(rows[1].milliseconds) + \(rows[2].milliseconds) ms")
                print("     · together:", rows[0].output)
                print("     · alone:   ", rows[1].output, "|", rows[2].output)
            }
        }

        print("== a longer text: does time grow with its sentences? ==")
        let growing = [
            "Where is the nearest train station?",
            "Where is the nearest train station? I need to buy two tickets to Shanghai.",
            "Where is the nearest train station? I need to buy two tickets to Shanghai. Is there a bus that goes there?",
        ]
        for (name, strategy) in strategies {
            let rows = await timed(growing, from: english, to: chinese, strategy: strategy)
            print("  \(name): 1, 2, 3 sentences took \(rows.map(\.milliseconds)) ms")
        }

        // One task, one session per model, so every call below is made the
        // same way and only the order and the pauses differ.
        print("== switching models: what does a call cost right after the other model? ==")
        do {
            let sentence = "Could you help me? I am looking for a pharmacy that is still open."
            let fluent = TranslationSession(installedSource: english, target: chinese, preferredStrategy: .highFidelity)
            let quick = TranslationSession(installedSource: english, target: chinese, preferredStrategy: .lowLatency)
            _ = try? await quick.translate("Hello")
            _ = try? await fluent.translate("Hello")
            var line: [String] = []
            for step in ["H", "H", "L", "L", "H", "H", "L", "H", "L", "L", "H"] {
                let start = clock.now
                _ = try? await (step == "H" ? fluent : quick).translate(sentence)
                line.append("\(step) \(milliseconds(clock.now - start))")
            }
            print("  H = highFidelity, L = lowLatency, in this order: \(line.joined(separator: ", ")) ms")

            print("== one word: how long is the shortest possible call? ==")
            var words: [String] = []
            for step in ["H", "H", "H", "L", "L", "L", "H"] {
                let start = clock.now
                _ = try? await (step == "H" ? fluent : quick).translate("Hello")
                words.append("\(step) \(milliseconds(clock.now - start))")
            }
            print("  \(words.joined(separator: ", ")) ms")

            print("== what warms a model that was just displaced? a word or a short sentence, then the sentence ==")
            for (name, session, other) in [("lowLatency", quick, fluent), ("highFidelity", fluent, quick)] {
                for (label, warmUp) in [("one word", "Hello"), ("a short sentence", "How are you today?")] {
                    _ = try? await other.translate(sentence)
                    var start = clock.now
                    _ = try? await session.translate(warmUp)
                    let warm = milliseconds(clock.now - start)
                    start = clock.now
                    _ = try? await session.translate(sentence)
                    let first = milliseconds(clock.now - start)
                    start = clock.now
                    _ = try? await session.translate(sentence)
                    print("  \(name) after the other model, warmed with \(label): warm-up \(warm) ms, the sentence \(first) ms, the sentence again \(milliseconds(clock.now - start)) ms")
                }
            }

            print("== cooling: the same sentence after a pause with nothing running ==")
            for (name, session) in [("highFidelity", fluent), ("lowLatency", quick)] {
                _ = try? await session.translate(sentence)
                var pauses: [String] = []
                for pause in [0, 1, 2, 3, 4, 6, 10, 20] {
                    try? await Task.sleep(for: .seconds(pause))
                    let start = clock.now
                    _ = try? await session.translate(sentence)
                    pauses.append("\(pause) s: \(milliseconds(clock.now - start))")
                }
                print("  \(name) after a pause of \(pauses.joined(separator: ", ")) ms")
            }

            print("== does one word wake a cooled model? pause 8 s, one word, then the sentence ==")
            for (name, session) in [("highFidelity", fluent), ("lowLatency", quick)] {
                _ = try? await session.translate(sentence)
                try? await Task.sleep(for: .seconds(8))
                var start = clock.now
                _ = try? await session.translate("Hello")
                let word = milliseconds(clock.now - start)
                start = clock.now
                _ = try? await session.translate(sentence)
                print("  \(name): the word took \(word) ms, the sentence after it \(milliseconds(clock.now - start)) ms")
            }
        }

        print("== cancellable? cancel a high-fidelity translation 80 ms in ==")
        do {
            let long = growing[2]
            let solo = await timed([long], from: english, to: chinese, strategy: .highFidelity)
            let startedAt = OSAllocatedUnfairLock<ContinuousClock.Instant?>(initialState: nil)
            let task = Task { () -> (String, Int) in
                let session = TranslationSession(installedSource: english, target: chinese, preferredStrategy: .highFidelity)
                _ = try? await session.translate("Hello")
                let start = clock.now
                startedAt.withLock { $0 = start }
                do {
                    let output = try await session.translate(long).targetText
                    return ("finished: \(output)", milliseconds(clock.now - start))
                } catch {
                    return ("threw: \(describe(error))", milliseconds(clock.now - start))
                }
            }
            while startedAt.withLock({ $0 }) == nil {
                try? await Task.sleep(for: .milliseconds(5))
            }
            try? await Task.sleep(for: .milliseconds(80))
            task.cancel()
            let (outcome, took) = await task.value
            print("  uncancelled: \(solo[0].milliseconds) ms | cancelled at 80 ms: returned after \(took) ms, \(outcome)")
        }

        print("== two at once: what does each cost the other? ==")
        do {
            let sentence = "Could you help me? I am looking for a pharmacy that is still open."
            let other = "Thank you so much. How much does this cost, and can I pay by card?"
            let long = growing[2]
            let alone = await timed([sentence], from: english, to: chinese, strategy: .highFidelity)
            let fastAlone = await timed([sentence], from: english, to: chinese, strategy: .lowLatency)
            print("  alone: highFidelity \(alone[0].milliseconds) ms, lowLatency \(fastAlone[0].milliseconds) ms")

            for round in 1...3 {
                // Both sessions are warm well before the shared start.
                let together = clock.now + .seconds(3)
                async let first = timed([sentence], from: english, to: chinese, strategy: .highFidelity, startAt: together)
                async let second = timed([other], from: english, to: chinese, strategy: .highFidelity, startAt: together)
                let (a, b) = await (first, second)
                print("  round \(round): two highFidelity started together took \(a[0].milliseconds) ms and \(b[0].milliseconds) ms")
            }
            for round in 1...3 {
                let slowStart = clock.now + .seconds(3)
                async let slow = timed([long], from: english, to: chinese, strategy: .highFidelity, startAt: slowStart)
                async let fast = timed([sentence], from: english, to: chinese, strategy: .lowLatency, startAt: slowStart + .milliseconds(100))
                let (s, f) = await (slow, fast)
                print("  round \(round): lowLatency started 100 ms into a highFidelity translation took \(f[0].milliseconds) ms (the highFidelity one took \(s[0].milliseconds) ms)")
            }
            for round in 1...3 {
                let fastStart = clock.now + .seconds(3)
                async let fast = timed([sentence], from: english, to: chinese, strategy: .lowLatency, startAt: fastStart)
                async let slow = timed([sentence], from: english, to: chinese, strategy: .highFidelity, startAt: fastStart + .milliseconds(5))
                let (f, s) = await (fast, slow)
                print("  round \(round): lowLatency first took \(f[0].milliseconds) ms, then highFidelity 5 ms later took \(s[0].milliseconds) ms")
            }
        }
    }

    // MARK: - speech

    /// Runs `SpeechAnalyzer` over an audio file as if it were a live
    /// microphone: the file is fed in 100 ms pieces at real-time pace, then
    /// the input ends the way a button release ends it. Prints every result
    /// and the stage timings, twice, so the second pass shows warm behaviour.
    ///
    /// Unlike the other two commands this one may install the locale's
    /// speech assets, because analysis cannot run without them.
    static func speech(arguments: [String]) async {
        guard arguments.count >= 2 else {
            print("usage: probe speech <locale> <audio-file> [--dictation] [--fast-results] [--unpaced] [--context word,word]")
            exit(2)
        }
        let requested = Locale(identifier: arguments[0])
        let url = URL(fileURLWithPath: arguments[1])
        let useDictation = arguments.contains("--dictation")
        let fastResults = arguments.contains("--fast-results")
        let paced = !arguments.contains("--unpaced")
        // Words to tell the recognizer to expect, to see whether that changes
        // what it hears.
        var contextualStrings: [String] = []
        if let flag = arguments.firstIndex(of: "--context"), flag + 1 < arguments.count {
            contextualStrings = arguments[flag + 1].split(separator: ",").map(String.init)
        }

        print("speech authorization (0 undetermined, 1 denied, 2 restricted, 3 authorized):",
              SFSpeechRecognizer.authorizationStatus().rawValue)

        for pass in ["first pass", "second pass"] {
            if useDictation {
                guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: requested) else {
                    print("DictationTranscriber does not support \(arguments[0])")
                    return
                }
                let module = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
                await analyze(label: "dictation \(locale.identifier(.bcp47)), \(pass)",
                              module: module, url: url, paced: paced, contextualStrings: contextualStrings) { $0.text }
            } else {
                guard SpeechTranscriber.isAvailable,
                      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
                    print("SpeechTranscriber does not support \(arguments[0]) here")
                    return
                }
                let module = SpeechTranscriber(
                    locale: locale,
                    transcriptionOptions: [],
                    reportingOptions: fastResults ? [.volatileResults, .fastResults] : [.volatileResults],
                    attributeOptions: []
                )
                await analyze(label: "speech \(locale.identifier(.bcp47))\(fastResults ? " fastResults" : ""), \(pass)",
                              module: module, url: url, paced: paced, contextualStrings: contextualStrings) { $0.text }
            }
        }
    }

    static func analyze<Module: SpeechModule>(
        label: String,
        module: Module,
        url: URL,
        paced: Bool,
        contextualStrings: [String] = [],
        text: @escaping @Sendable (Module.Result) -> AttributedString
    ) async {
        print("== \(label) ==")
        let clock = ContinuousClock()

        let status = await AssetInventory.status(forModules: [module])
        print("  asset status:", String(describing: status))
        if status != .installed {
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    let start = clock.now
                    try await request.downloadAndInstall()
                    print("  downloadAndInstall:", milliseconds(clock.now - start), "ms")
                }
            } catch {
                print("  asset installation failed:", describe(error))
                return
            }
            print("  asset status after install:",
                  String(describing: await AssetInventory.status(forModules: [module])))
        }

        let createStart = clock.now
        let analyzer = SpeechAnalyzer(
            modules: [module],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        )
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
            print("  no analyzer format available")
            return
        }
        print("  analyzer created, format \(analyzerFormat.sampleRate) Hz:",
              milliseconds(clock.now - createStart), "ms")
        if !contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = contextualStrings
            do {
                try await analyzer.setContext(context)
                print("  context set: \(contextualStrings)")
            } catch {
                print("  setContext failed:", describe(error))
            }
        }

        do {
            let prepareStart = clock.now
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            print("  prepareToAnalyze:", milliseconds(clock.now - prepareStart), "ms")
        } catch {
            print("  prepareToAnalyze failed:", describe(error))
            return
        }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            print("  cannot read audio file:", describe(error))
            return
        }
        let sourceFormat = file.processingFormat
        guard let converter = AVAudioConverter(from: sourceFormat, to: analyzerFormat) else {
            print("  cannot convert \(sourceFormat) to \(analyzerFormat)")
            return
        }
        let seconds = Double(file.length) / sourceFormat.sampleRate
        print("  source \(sourceFormat.sampleRate) Hz, \(String(format: "%.2f", seconds)) s of audio, paced: \(paced)")

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let pressed = clock.now
        let resultsTask = Task {
            var count = 0
            do {
                for try await result in module.results {
                    count += 1
                    let string = String(text(result).characters)
                    let start = String(format: "%.2f", result.range.start.seconds)
                    let length = String(format: "%.2f", result.range.duration.seconds)
                    print("    +\(milliseconds(clock.now - pressed)) ms",
                          result.isFinal ? "FINAL   " : "volatile",
                          "range \(start)+\(length)s", string.debugDescription)
                }
            } catch {
                print("    results failed:", describe(error))
            }
            return count
        }

        do {
            let startCall = clock.now
            try await analyzer.start(inputSequence: stream)
            print("  start(inputSequence:) returned:", milliseconds(clock.now - startCall), "ms")
        } catch {
            print("  start failed:", describe(error))
            continuation.finish()
            await analyzer.cancelAndFinishNow()
            _ = await resultsTask.value
            return
        }

        let chunkFrames = AVAudioFrameCount(sourceFormat.sampleRate / 10)
        while file.framePosition < file.length {
            guard let chunk = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkFrames) else { break }
            do {
                try file.read(into: chunk, frameCount: chunkFrames)
            } catch {
                print("  read failed:", describe(error))
                break
            }
            guard chunk.frameLength > 0 else { break }
            if let converted = convert(chunk, with: converter, to: analyzerFormat) {
                continuation.yield(AnalyzerInput(buffer: converted))
            }
            if paced {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }

        let released = clock.now
        print("  -- input ended (release) at +\(milliseconds(released - pressed)) ms --")
        continuation.finish()
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            print("  finalizeAndFinishThroughEndOfInput returned:",
                  milliseconds(clock.now - released), "ms after release")
        } catch {
            print("  finalize failed:", describe(error))
        }
        let count = await resultsTask.value
        print("  results stream ended:", milliseconds(clock.now - released),
              "ms after release, \(count) results")
    }

    /// One-shot conversion of a chunk. The input block hands the source over
    /// exactly once and then reports that no more data is available, so the
    /// converter keeps its resampler state between chunks without re-reading.
    static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, output.frameLength > 0 else { return nil }
        return output
    }
}

#endif
