# Push-to-talk interpreter (English ⇄ Mandarin speech-to-speech) — implementation plan

**Created (UTC):** 2026-11-18T17:51Z
**Branch:** `nov-19-2026-push-to-talk-speech-translation`
**Base:** `main` at `b78a8f6`
**Status:** Approved on 2026-11-18 with the seven defaults of §2, and built. §11 lists where the build departs from this plan and why. Sections 1 to 10 are the plan as it was approved.

The key words MUST, MUST NOT, SHOULD and MAY are used as described in RFC 2119.

## 1. Outcome

A new screen, **Interpreter** (对话翻译), for a spoken conversation between an English speaker and a Mandarin speaker. It has two hold-to-speak buttons, **Hold for English** and **按住说中文**. While a button is held the app shows the live transcript. On release it finalizes the transcript, translates it on the device, and speaks the translation aloud. The voice that speaks is selectable: Apple's on-device voice or a MiniMax AI voice.

The pipeline is three stages in sequence: microphone → `SpeechAnalyzer` + `SpeechTranscriber` (Speech) → `TranslationSession` (Translation) → `AVSpeechSynthesizer` or MiniMax T2A (speech out). Everything except the optional MiniMax voice runs on the device and works offline.

## 2. Decisions that need your call

I will use the default in each row unless you say otherwise.

| # | Decision | Default | Alternative |
|---|---|---|---|
| 1 | OS floor | Keep the app's iOS 17.0 floor. Gate the feature with `@available(iOS 26.0, macOS 26.0, *)`; older iOS shows a "requires iOS 26" state. | Raise `IPHONEOS_DEPLOYMENT_TARGET` to 26.0, which drops iOS 17–25 for the whole app. |
| 2 | Swift mode | The target stays in Swift 5 mode. Every new pipeline file MUST compile under `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`, proven by a script. This is the repo's existing convention. | Move the whole target to Swift 6 (51,000 lines; a separate project). |
| 3 | Name and entry points | "Interpreter" / "对话翻译". Reached from the Study hub, a Translate toolbar button, and the macOS sidebar: the same three places AI Chat uses. The existing Voice Translation sheet stays as it is. | A different name, or replacing the Voice Translation sheet. |
| 4 | Default voice | Apple's voice, unless AI Audio is already on and a MiniMax key exists, in which case MiniMax. | Always Apple, or always MiniMax. |
| 5 | Translation quality | "Natural" where the device offers it (the Apple Intelligence model, which the default initializer already uses on this Mac), with a "Fast" switch. Phase 7 replaces the switch's default with an adaptive rule (§5, row H). | "Fast" by default. |
| 6 | MiniMax streaming playback | Build it in Phase 7 only if the Phase 0 live probe shows first audio at least 300 ms sooner than today's non-streaming request. | Skip it, or build it regardless. |
| 7 | Issues found in existing Live Speech code (§3.5) | Record them as follow-ups; do not fix them on this branch. | Fix them here as separate commits. |

## 3. Phase 1 findings (inspection — done)

### 3.1 The brief versus the repository

| The brief says | The repository has | Consequence |
|---|---|---|
| iOS 26.0+ and macOS 26.0+ | iOS 17.0, macOS 26.2, visionOS 26.2 (`project.pbxproj`) | Decision 1. |
| Swift 6 strict concurrency | `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` | Decision 2. New files state their isolation explicitly (`@MainActor`, `nonisolated`) so they compile the same with and without the MainActor default, and import every module whose members they use. |
| Add the `Info.plist` keys and the audio-input entitlement | Info.plist is generated. `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` are set in both configurations. `SwiftMandarin.entitlements` has `device.audio-input` and `network.client`. | No project-file edit. Phase 2 verifies the built product. |
| `Package.swift`, test target | One app target, a file-system-synchronized `SwiftMandarin/` group, one package dependency (ollama-swift), no XCTest target. Tests are Swift 6 contract runners under `scripts/`, run by `init.sh`. | New files join the target automatically. New checks follow the `scripts/test-*.sh` pattern. |
| Build a TTS wrapper that retains one `AVSpeechSynthesizer` | `SpeechService` owns the app's single synthesizer. It is the documented single playback router, and already has MiniMax routing, a persistent MP3 cache, and fallback to the system voice. | Extend `SpeechService`. Do not add a second synthesizer. |
| Configure `AVAudioSession` in the feature | `AudioSessionCoordinator` is the only code allowed to activate the session. `scripts/test-audio-session-transitions.sh` fails if any other file does. | Add a profile and a "pin" to the coordinator (§4.5). |
| Toolchain not stated | Xcode 27.2 (27B52), Swift 6.4.2, iOS and macOS 27.2 SDKs, macOS 27.3 host | OS 27-only Speech APIs exist in the SDK and need `#available(iOS 27.0, macOS 27.0, *)`. |

### 3.2 What already exists and how this feature uses it

| Existing piece | Use here |
|---|---|
| `TranslationDirection` (`Models/TranslationDirection.swift`) | The direction type for the two buttons. It already carries the `en-US` / `zh-CN` speech codes and the `en` / `zh-Hans` translation languages. |
| `SpeechRecognitionService` | Not reused for capture: it is tap-to-toggle and built around one shared recorder. Its permission helpers are reused, and it and the new service stop each other. |
| `AudioSessionCoordinator`, `SourceAudioActivityCoordinator` | Session ownership, and the bridge for interruptions and route loss. |
| `SpeechService` | Speech output for both engines. |
| `MiniMaxAudioClient`, `MiniMaxSpeechPipeline`, `GeneratedSpeechRepository`, `AppPreferences.aiAudio*`, `AIModelSettings.apiKey(for: .minimax)` | The MiniMax voice: model, voices, speed, region, Keychain key, cache-first synthesis. |
| `AIAudioRuntimeState`, `AIAudioStatusBanner` | The existing banner already reports MiniMax failures and fallback to the system voice. |
| `WordTranslationService`, `AIWordExplanationService.translateWithProvider` | The pattern for installed-session translation with an AI-provider fallback. |
| `TranslationHistoryStore.add(source:target:direction:)` | Completed turns join History, as spoken translations from Voice Translation already do. |
| Design system (`smPageBackground`, `smCardSurface`, the `glass…Compat` helpers, `HeroActionRow`, `SMEmptyState`) | Screen styling, Liquid Glass on OS 26. |
| `AppTab`, `StudyRoute`, `AppRouteStore.openStudy(route:)`, `MacOSContentView.hosted` | Navigation entry points. |
| `Localizable.xcstrings` (English source, zh-Hans) | Every new string, in both languages. |

### 3.3 API facts checked against the installed SDK

Source: the `.swiftinterface` files for Speech, Translation and `_Translation_SwiftUI`, and the AVFAudio headers, in the iOS 27.2 SDK of Xcode 27.2.

**Speech** (OS 26+, not on watchOS)

- `SpeechTranscriber(locale:transcriptionOptions:reportingOptions:attributeOptions:)`. Reporting options are `.volatileResults`, `.alternativeTranscriptions`, `.fastResults`. Also `isAvailable`, `supportedLocale(equivalentTo:)`, `installedLocales`, and `results`, whose elements have `text` (an `AttributedString`), `range`, `resultsFinalizationTime` and `isFinal`.
- `DictationTranscriber(locale:preset:)`, with presets such as `.progressiveShortDictation`, and the same result shape.
- `SpeechAnalyzer` is an actor: `init(modules:options:)`, `prepareToAnalyze(in:)`, `start(inputSequence:)`, `finalizeAndFinishThroughEndOfInput()`, `finalizeAndFinish(through:)`, `cancelAndFinishNow()`, `setContext(_:)`, `bestAvailableAudioFormat(compatibleWith:)` and a `considering:` variant.
- `SpeechAnalyzer.Options(priority:modelRetention:)` with `.whileInUse`, `.lingering`, `.processLifetime`, and `SpeechModels.endRetention()`.
- `AssetInventory.status(forModules:)` returns `.unsupported`, `.downloading`, `.supported` or `.installed`. `assetInstallationRequest(supporting:)` returns an optional request with `progress` and `downloadAndInstall()`. Also `reserve(locale:)`, `release(reservedLocale:)` and `maximumReservedLocales`.
- `AnalysisContext.contextualStrings` and `SpeechDetector` exist.
- OS 27 only: `AnalyzerInputConverter`, `CaptureInputSequenceProvider`, `AssetInputSequenceProvider`. The `AnalyzerInput.buffer` getter is deprecated in 27.

**Translation**

- `LanguageAvailability().status(from:to:)` returns `.installed`, `.supported` or `.unsupported` (iOS 18).
- `TranslationSession(installedSource:target:)`, `isReady`, `canRequestDownloads`, `cancel()` and `TranslationError.notInstalled` are iOS and macOS 26.0.
- `TranslationSession.Strategy` (`.lowLatency`, `.highFidelity`) is iOS and macOS 26.4, with `init(installedSource:target:preferredStrategy:)`, `Configuration(source:target:preferredStrategy:)` and `LanguageAvailability(preferredStrategy:)`. Per Apple's documentation, low latency uses the traditional models and high fidelity uses Apple Intelligence for more fluent output.
- `prepareTranslation()` asks for the language download without translating.
- `.translationTask(_:action:)` (iOS 18) and a `preferredStrategy:` overload (26.4) come from the SwiftUI overlay.
- The whole framework is marked unavailable on visionOS.

**AVFAudio**

- `.allowBluetoothHFP` is available back to iOS 1.0 in this SDK (it replaces the deprecated `.allowBluetooth`), so it compiles at the iOS 17 floor.
- `.bluetoothHighQualityRecording` is iOS 26.0+.
- `setAllowHapticsAndSystemSoundsDuringRecording(_:)` is iOS 13+.

**Measured on this Mac** (macOS 27.3, two read-only command-line probes; nothing was downloaded or recorded)

| Question | Result |
|---|---|
| Is `SpeechTranscriber` available? | Yes; 45 supported locales. |
| What does `supportedLocale(equivalentTo:)` return? | `en-US` → `en-US`. `zh-CN`, `zh-Hans-CN` and `zh_CN` → `zh-CN`. |
| Are the speech models installed? | `installedLocales` contains `en-US` and `zh-CN`, yet `AssetInventory.status(forModules:)` for a volatile-results transcriber reports `.supported` for both, with no reserved locales. Readiness MUST therefore be decided by `status(forModules:)` with the real module configuration, not by `installedLocales`. |
| What audio format does the analyzer want? | 16 kHz, mono, Int16, for both locales. |
| How many locales can an app reserve? | `maximumReservedLocales` is 5. |
| Is `DictationTranscriber` usable as a fallback? | `en-US` and `zh-CN` are installed for it. |
| Is the translation pair installed? | Yes, in both directions and under every identifier spelling tried (`en`/`zh-Hans`, `en-US`/`zh-Hans-CN`, `en-US`/`zh-CN`). The app's existing `en` / `zh-Hans` identifiers are kept. |
| Which strategy is the device default? | Not `.lowLatency`, so high fidelity. Both strategies are installed. |
| How long does one sentence take to translate? | `.lowLatency`: 20–50 ms warm. `.highFidelity` and the default initializer: 265–520 ms warm. The first call in the process took 0.7 s (low latency) to 1.5 s (default). The two strategies gave slightly different wording; high fidelity read more naturally on the three test sentences. |
| Which voices are installed? | `en-US`: 28 default, 1 enhanced. `zh-CN`: 9, all default quality. |

### 3.4 MiniMax facts

Read from MiniMax's API reference on 2026-11-18, combined with this repo's live probes from 2026-07-21.

- `POST /v1/t2a_v2` accepts `stream: true`. Streamed audio is hex only. Each chunk has `data.audio` and `data.status` (1 while synthesizing, 2 when complete). By default the final chunk repeats the whole audio; `stream_options.exclude_aggregated_audio: true` turns that off.
- `audio_setting.format` accepts `mp3`, `pcm`, `flac`, `wav`, `pcmu_raw`, `pcmu_wav` and `opus`. `force_cbr` applies to streamed MP3.
- The model list (`speech-2.8-hd`, `speech-2.8-turbo`, and the 2.6, 02 and 01 families) matches the app's catalog. `language_boost` accepts `Chinese` and `English`, which the app already sends.
- A WebSocket endpoint exists (`task_start`, `task_continue`, `task_finish`), plus a bidirectional variant for text that arrives token by token.
- A US-West host is documented for lower time to first audio.
- Not stated on the pages read: the exact framing of the HTTP stream, and which formats are allowed when streaming. Phase 0 settles both with one live request.
- The mainland documentation now lists `api.minimax.cn`. The app uses `api.minimaxi.com`, which passed live probes in July. Phase 0 re-checks it; nothing changes unless it fails.

### 3.5 Issues noticed in existing code (outside this feature)

Found by reading; none was reproduced.

1. `SpeechRecognitionService.swift:719-728`: `ModernSpeechEngine.stop()` cancels the task that reads `transcriber.results` as soon as `finalizeAndFinishThroughEndOfInput()` returns, instead of letting it end on its own. Final results still in transit can be dropped.
2. `SpeechRecognitionService.swift:348-353`: finalized segments are joined with a space in every language, which puts spaces inside Chinese transcripts.
3. `SpeechRecognitionService.swift:219-227`: readiness is judged by `installedLocales`. Given the probe result above, the install request may be skipped when it is needed.
4. `SUPPORTED_PLATFORMS` lists visionOS, but Translation is unavailable there and existing code uses it unguarded, so a visionOS build would not compile. This is inferred from the SDK interface; I did not build it.

## 4. Design

### 4.1 Files

New files, all under `SwiftMandarin/` unless a path says otherwise:

| File | Contents |
|---|---|
| `Models/InterpreterModels.swift` | `PipelineState`, `UserFacingError`, `InterpreterTurn`, `InterpreterReadiness`, `SpeechVoiceEngine`, `TranslationQuality`, per-turn timings. Sendable values. |
| `Models/TranscriptAssembler.swift` | Finalized segments plus one replaceable volatile tail. Pure. |
| `Services/InterpreterPipeline.swift` | The protocols the coordinator depends on: transcriber, translator, speaker, audio-session lease, clock. |
| `Services/SpeechTranslationCoordinator.swift` | The `@Observable @MainActor` state machine. Depends only on the protocols and models, so it runs against fakes. |
| `Services/SpeechModelProvisioner.swift` | `AssetInventory` status, install with progress, reservation, and the choice between `SpeechTranscriber` and `DictationTranscriber`. |
| `Services/PushToTalkTranscriptionService.swift` | `AVAudioEngine` tap → `AsyncStream<AnalyzerInput>` → `SpeechAnalyzer`. Prewarm, begin, finish, cancel. |
| `Services/InterpreterTranslationService.swift` | `LanguageAvailability`, installed sessions per direction and strategy, download preparation, AI-provider fallback, Simulator mock. |
| `Services/InterpreterAdapters.swift` | Thin production bindings to `SpeechService`, `AudioSessionCoordinator` and `TranslationHistoryStore`. |
| `Views/InterpreterView.swift` | The screen: readiness banner, conversation, hold buttons, voice menu, and the `.translationTask` host. |
| `Views/Components/HoldToSpeakButton.swift` | Press-and-release gesture, keyboard hold, accessibility toggle. |
| `scripts/test-interpreter.sh`, `scripts/interpreter-checks/InterpreterChecksRunner.swift` (repo root) | Contract and scenario checks, and the Swift 6 type-check for iOS and macOS. |
| Phase 7 only: `Services/MiniMaxStreamingSpeechClient.swift`, `Services/MP3FrameParser.swift`, `Services/StreamingSpeechPlayer.swift` | Streaming synthesis and progressive playback. |

Changed files:

| File | Change |
|---|---|
| `Services/AudioSessionCoordinator.swift` | A `.speechConversation` profile, and `pin` / `unpin`. |
| `Services/SpeechService.swift` | A per-request `SpeechVoiceEngine`. `speakAndWait` completes through a continuation instead of a 50 ms poll. The voice cache refreshes when installed voices change. |
| `Services/AudioCaptureService.swift`, `Services/SpeechRecognitionService.swift` | One-line hooks so the audio features stop each other and session loss reaches the interpreter. |
| `Models/AppPreferences.swift` | `interpreterVoiceEngine`, `interpreterTranslationQuality`. |
| `ContentView.swift`, `Views/StudyHubView.swift`, `Models/AppRouteStore.swift`, `Views/TranslateView.swift` | `AppTab.interpreter`, `StudyRoute.interpreter`, the sidebar item, the hub row, the toolbar button. |
| `Views/AIAudioSettingsView.swift` | An "Interpreter voice" section. |
| `Localizable.xcstrings` | New strings with zh-Hans translations. |
| `init.sh`, `scripts/test-audio-session-transitions.sh`, `feature_list.json`, both READMEs, `handoff.md`, `agent-progress.txt` | Harness and documentation. |

`SpeechTranslationCoordinator` and `PipelineState` keep the names from the brief. The other types use the "Interpreter" prefix so they are not confused with the existing `LiveSpeechTranslationView`.

### 4.2 One turn, step by step

1. **Screen appears.** The coordinator checks permissions and readiness (speech assets for both locales, the translation pair), pins the audio session on iOS, prepares one analyzer per direction, and warms both translation sessions.
2. **Press** (touch or mouse down, Space down, or accessibility activation). Any speech stops at once through `SpeechService.stop()`, which calls `stopSpeaking(at: .immediate)`. The engine tap starts and the state becomes `.listening`. The prepared analyzer starts on the stream, which has been buffering since the tap opened.
3. **Hold.** Each result updates the assembler. The screen shows finalized text plus a lighter volatile tail.
4. **Release.** Held under 250 ms: cancel with `cancelAndFinishNow()` and return to `.idle`. Otherwise: remove the tap and stop the engine, finish the input stream, call `finalizeAndFinishThroughEndOfInput()`, and wait for the results task to end by itself (4 s watchdog). An empty transcript returns to `.idle`.
5. **Translate.** The state is `.translating`. The turn is appended to the conversation and, when the existing "Save Translations to History" setting is on, added to History.
6. **Speak.** The state is `.speaking`, using the chosen engine, then `.idle`. While steps 5 and 6 run, the next analyzer for that direction is built and prepared.

### 4.3 State machine

States are exactly those in the brief: `.idle`, `.preparingModels(progress:)`, `.listening(direction:liveTranscript:)`, `.finalizingTranscript`, `.translating(sourceText:)`, `.speaking(sourceText:translatedText:)`, `.error(UserFacingError)`.

| From | Event | To | Effect |
|---|---|---|---|
| `.idle` | Assets missing, user taps Download | `.preparingModels` | Install speech assets with progress; start translation preparation. |
| `.preparingModels` | Finished | `.idle` | Prepare analyzers and sessions. |
| `.idle`, `.error` | Press, everything ready | `.listening` | New turn ID; start capture. |
| `.idle` | Press, something missing | `.idle` | The banner explains what is missing, or the system permission prompt appears. Nothing is recorded. |
| `.listening` | Result | `.listening` | Update the transcript. |
| `.listening` | Release, held ≥ 250 ms | `.finalizingTranscript` | Stop capture; finalize. |
| `.listening` | Release, held < 250 ms | `.idle` | Cancel; "Hold to speak" hint. |
| `.listening` | Scene inactive, window resigns key, screen disappears, session lost | `.idle` | Cancel. |
| `.finalizingTranscript` | Final text is empty | `.idle` | "Didn't catch that" hint. |
| `.finalizingTranscript` | Final text | `.translating` | Translate. |
| `.translating` | Translation | `.speaking` | Append the turn; speak. |
| `.speaking` | Speech finished or stopped | `.idle` | |
| `.finalizingTranscript`, `.translating`, `.speaking` | Press | `.listening` | Stop speech; abandon the previous turn's unfinished work; start capture. |
| Any | Failure | `.error` | Tear down capture; show a message with one recovery action (Open Settings, Download, Retry). |

### 4.4 Invariants

Each of these is a check in the runner or a scripted scenario.

- **I1.** The microphone is open only between press and release, plus a tail of at most 150 ms. After finish, cancel or any failure, the engine is stopped and the tap removed.
- **I2.** Every asynchronous result carries the ID of the turn that started it. A result for a turn that is no longer current is dropped, so a late translation from an abandoned turn is never spoken.
- **I3.** Translation and speech never start for a press under 250 ms or for an empty transcript.
- **I4.** Transcript text is built from finalized segments plus at most one volatile tail. A later result for the same audio range replaces the earlier one. Raw results are never appended with `+=`.
- **I5.** On a normal release the results task is not cancelled. It ends because the analyzer finished.
- **I6.** Only `AudioSessionCoordinator` touches `AVAudioSession`, and all of that code is inside `#if os(iOS)`.
- **I7.** `SpeechService` remains the only owner of speech playback.
- **I8.** MiniMax receives only the final, committed translation of a turn, never speculative text. The API key stays in Keychain and transient memory and is never logged.
- **I9.** Each `TranslationSession` is used from one isolation domain. Non-Sendable framework objects do not cross actors.
- **I10.** A new press always wins.

### 4.5 Audio session: one configuration for the whole conversation (iOS)

Today each feature acquires the session for one operation and releases it, which deactivates it. For push-to-talk that would put a session activation between the press and the microphone opening, and a category switch between the translation and the spoken reply.

The coordinator gains a pin. `pin(.speechConversation, owner:)` activates the session and holds it. While pinned, `acquire` from any feature keeps the pinned configuration and `release` does not deactivate. `unpin` deactivates when nobody else is using the session. The Interpreter pins while it is on screen and the scene is active, and unpins when it leaves or the app goes to the background.

The `.speechConversation` profile is `.playAndRecord`, mode `.spokenAudio`, options `.defaultToSpeaker` and `.allowBluetoothHFP`, as the brief specifies, plus `.bluetoothHighQualityRecording` on iOS 26 and later, with haptics allowed during recording. `.defaultToSpeaker` is what keeps the reply on the loudspeaker instead of the earpiece. The profile deliberately omits `.duckOthers`: other apps' audio should pause while the Interpreter is open, not keep playing quietly into the microphone. macOS has no `AVAudioSession`; the backend is already a no-op there.

### 4.6 Voice option: Apple or MiniMax

- **Setting.** `AppPreferences.interpreterVoiceEngine`, either `.system` or `.miniMax`. It is set from a Voice menu on the Interpreter screen and from a new section in AI Audio settings. It applies only inside the Interpreter; the app-wide AI Audio switch keeps governing every other screen.
- **Apple voice.** `AVSpeechSynthesizer` through `SpeechService`, using the highest-quality installed voice (premium, then enhanced, then default). On-device, offline, free. On this Mac `zh-CN` has only default-quality voices, so the screen shows a one-line tip about downloading a better system voice when that is the case.
- **MiniMax voice.** Uses the model, voices, speed and region already configured in AI Audio. The text of the translation is sent to MiniMax, which the menu states. Synthesis is cache-first, so a phrase that was spoken before plays at once and costs nothing.
- **Failure.** If MiniMax fails, or no key exists, the reply falls back to the Apple voice when the existing "fall back to system speech" preference is on, and the existing banner says so. With fallback off, the turn shows the error and a Retry.
- **Replay.** Each turn's replay button uses the engine that spoke it.

### 4.7 Simulator

Reports from other developers say neither `SpeechTranscriber` nor the Translation framework works in the iOS Simulator. Phase 0 confirms what the iOS 27.2 simulator reports.

- Translation in the Simulator returns `[Simulator Mock Translation] …`, behind `#if targetEnvironment(simulator)`.
- Speech in the Simulator uses `DictationTranscriber` if it works there. If it does not, a scripted transcript labeled `[Simulator Mock Transcript]` stands in, again Simulator-only.
- Speech output is real in the Simulator.
- Device and macOS builds contain neither mock. The real end-to-end run happens on macOS, where all three frameworks are real.

## 5. Optimizations

The stages run in sequence, so the delay the listener feels is their sum. Each row shrinks or hides one stage. Rows marked Phase 2–4 are part of the first build because they shape the design. Rows marked Phase 7 are measured experiments: each is kept only if it meets the rule stated in its row.

| # | Optimization | Stage | Effect | Phase |
|---|---|---|---|---|
| A | Check and install everything when the screen opens, not on the first press. | First use | The first press works immediately. | 2 |
| B | Pin the iOS audio session while the screen is open (§4.5). | Press → mic live; translation → speech | No session activation or category switch inside a turn. | 4 |
| C | Open the mic tap before the analyzer starts; audio queues in the stream. | Press → mic live | The first word is not lost while the analyzer starts. | 3 |
| D | Keep one prepared analyzer per direction (`prepareToAnalyze(in:)`, model retention) and rebuild it during the reply. | Press → first partial | No model load on press. | 3 |
| E | One warm-up translation per direction on entry. | First turn | Measured: the first call costs 0.7–1.5 s; later calls 0.02–0.5 s. | 4 |
| F | Choose the translation strategy explicitly on OS 26.4+. | Release → translation | Measured: `.lowLatency` 20–50 ms, `.highFidelity` 265–520 ms. This Mac's default is high fidelity. | 4 |
| G | Translate speculatively while the button is held, show it as a live preview, and reuse it when the final transcript matches exactly. | Release → translation | The translation is often finished at release. It is on-device, so it costs nothing. Keep if at least 30% of test turns reuse it. | 7 |
| H | Adaptive quality: at release run both strategies; wait at most 350 ms for high fidelity, otherwise speak the low-latency result. | Release → translation | The natural translation when it is quick, never a long wait. | 7 |
| I | Cache-first MiniMax (exists today). | Translation → speech | Repeated phrases play at once at no charge. | 4 |
| J | MiniMax streaming synthesis played as chunks arrive. The stream is MP3, so the finished clip still lands in the existing cache. | Translation → first audio | First audio after the first chunks instead of after the whole clip. Decision 6 sets the rule. | 7 |
| K | Open the HTTPS connection to MiniMax at press time when that voice is selected. | Translation → first audio | Removes connection setup from the request. Keep if it saves at least 100 ms. | 7 |
| L | `speakAndWait` by continuation; a press during speech stops it immediately. | End of reply; next press | No polling. Interrupting a reply is instant. | 4 |
| M | A short tail after release: capture until the next tap callback, 150 ms at most. | Last word | The final syllable is not cut off. | 3 |
| N | `.fastResults` on the transcriber. | Release → final transcript | Apple documents it as faster and less accurate. Adopt only if it is at least 150 ms faster with no new errors on the test phrases. | 7 |
| O | Seed `AnalysisContext.contextualStrings` with the learner's saved vocabulary. | Recognition accuracy | Better recognition of words the learner has saved. Keep only if the test phrases improve. | 7 |

**Latency targets.** These are targets to measure against, not results. Every turn records its timestamps (press, mic live, release, final transcript, translation, first audio, end of speech) through `os_signpost`, and the self-test prints them.

| Stage | Target |
|---|---|
| Press → microphone live | ≤ 100 ms |
| Release → final transcript | ≤ 400 ms |
| Final transcript → translation | ≤ 50 ms fast; ≤ 350 ms natural; about 0 on a speculative hit |
| Translation → first audio | ≤ 150 ms Apple; ≤ 500 ms MiniMax streaming or cached; ≤ 1.5 s MiniMax non-streaming |
| Release → first audio, in total | ≤ 0.9 s with the Apple voice |

**Considered and not planned.**

- WebSocket synthesis: it helps when text arrives token by token, and here the translation arrives whole.
- Sending text to MiniMax before the turn is final: speculative requests would be billed.
- Keeping the microphone open before the press to capture a pre-roll: a privacy cost for a small gain.
- OS 27's `CaptureInputSequenceProvider` and `AnalyzerInputConverter`: the `AVAudioEngine` path is required for OS 26 anyway, and one capture path is easier to verify.
- Running two transcribers at once to detect the language automatically, a hands-free mode with `SpeechDetector`, and a face-to-face layout: larger features that can follow.

## 6. Phases

Phase numbers follow the brief. Phase 1, the inspection, is §3 and is done. Phase 0 and Phase 7 are additions: the first settles unknowns before code depends on them, the second holds the measured optimizations.

Each phase ends with the app building for iOS and macOS, `zsh init.sh` passing, the evidence recorded in `handoff.md`, and one commit pushed to this branch. Nothing merges to `main` until you say so. Sizes are relative: S is under an hour of work, M one to three, L more.

**Phase 0 — Probes and baseline (S).**
Record baseline builds and `init.sh`. Commit the two capability probes as a guarded script so the numbers can be re-measured. Probe the iOS 27.2 simulator (§4.7). Run `SpeechAnalyzer` in the macOS app on `say`-generated English and Mandarin clips to learn the result shapes, whether speech-recognition authorization is required in addition to the microphone, and the cold and prepared start times. Make one credential-safe MiniMax streaming request to learn the framing and the time to first audio.
*Evidence:* probe output in `handoff.md`; any plan change recorded with its reason.

**Phase 2 — Permissions, entitlements, provisioning (M).**
Verify the usage strings and entitlement in the built iOS and macOS products. Build `SpeechModelProvisioner` and the readiness model: resolve locales with `supportedLocale(equivalentTo:)`, pick `SpeechTranscriber` or fall back to `DictationTranscriber`, decide readiness with `AssetInventory.status(forModules:)`, install with progress, reserve both locales, map errors (unsupported, too many reserved locales, download failed).
*Evidence:* contract checks against a fake asset boundary; a macOS run log showing each readiness state.

**Phase 3 — Streaming speech-to-text (L).**
Build `TranscriptAssembler` and `PushToTalkTranscriptionService`: prewarm, begin, finish, cancel, the tail, the watchdog, forced teardown, the `DictationTranscriber` adapter, and the hooks that stop other audio features. No sample rate is hardcoded: the input format is read from `inputNode.outputFormat(forBus: 0)` once the session is active, the target format comes from `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:considering:)`, and `AVAudioConverter` bridges the two. The tap and converter code is lifted from the proven `ModernSpeechEngine` tap (format guard, owned buffer copies, one-shot converter input).
*Evidence:* assembler checks (replacement by range, ordering, Chinese and English joins, empty input); a macOS self-test on the two clips printing transcript and timings; a cancel run showing the engine stopped.

**Phase 4 — Translation and speech (L).**
Build `InterpreterTranslationService`: the installed-session path with the chosen strategy, error mapping (`notInstalled` leads to the download banner), `prepareTranslation()` inside `.translationTask`, the AI-provider fallback, the Simulator mock, the warm-up. Extend `SpeechService` (engine override, continuation, voice cache). Add the session profile and pin. Add the two preferences and the settings section.
*Evidence:* extended audio-session checks for the pin; a macOS scenario showing `speakAndWait` returns when speech ends and that cancelling stops speech; a MiniMax turn replayed from cache; a fallback turn with the key removed.

**Phase 5 — Coordinator and screen (L).**
Build `SpeechTranslationCoordinator` against the protocols, then `InterpreterView` and `HoldToSpeakButton`. The screen has the readiness banner with its one-tap download, a scrollable conversation of turn cards (source transcript, translation, replay), and the two hold buttons, each with a distinct look while recording, processing and speaking. The gesture is `DragGesture(minimumDistance: 0)` tracked with `@GestureState`, so finger drift does not end the press and a cancelled gesture does. Space works as hold-to-speak on macOS and with an iPad keyboard. VoiceOver gets start and stop as a toggle, because a hold gesture is not reliably usable with it. Add the entry points, localization and History.
*Evidence:* scenario checks for every row of §4.3 against fakes; simulator screenshots on iPhone and iPad; macOS screenshots; an accessibility dump of the two buttons.

**Phase 6 — Build and verification (M).**
`xcodebuild` for the iOS Simulator, a generic iOS device (compile only, to cover the non-simulator branches) and macOS, with no warnings in new or changed files. The Swift 6 type-check for both platforms. The macOS end-to-end self-test in both directions. An independent review of the diff. README updates in both languages. A written device checklist for you (§7).
*Evidence:* build logs, check output, self-test output, review findings and fixes.

**Phase 7 — Measured optimizations (M to L).**
Rows G, H, J, K, N and O from §5, one commit each, each kept or dropped by its rule. J is the largest: a streaming client, an MP3 frame parser, progressive decoding through `AVAudioConverter`, and a player node, all behind `SpeechService`. If progressive MP3 decoding proves unreliable, the fallback is a PCM stream with a session-scoped replay file, which gives up cache reuse.
*Evidence:* before and after timings from the self-test for each row.

## 7. Verification

| Requirement from the brief | Check | Evidence |
|---|---|---|
| A. Deterministic direction per button | Scenario: each button starts capture with its own locale and speaks in the other language. | Runner output. |
| B.1 Speech models checked and downloaded with progress | Provisioner checks against a fake; a real run on macOS. | Runner output; run log. |
| B.2 Translation status, download prompt, installed-only session | A translation-service scenario per status; a real macOS run. | Runner output; screenshot of the banner. |
| B.2 Simulator guard | Simulator run shows the labeled mock and a full turn. | Simulator screenshot. |
| C.1 Live capture, no hardcoded sample rate, format conversion | Self-test on clips at two sample rates. | Self-test output. |
| C.2 Volatile results handled without naive appending | Assembler checks. | Runner output. |
| C.3 Clean termination; no hang; micro-tap and empty guards | Scenarios for release, micro-tap, empty transcript and watchdog; the self-test completes. | Runner and self-test output. |
| D. One synthesizer, continuation bridge, best voice, barge-in | `SpeechService` scenario on macOS; a source check that no second `AVSpeechSynthesizer` exists. | Scenario log; check output. |
| E.1–E.2 `AVAudioSession` only on iOS, loudspeaker routing | The existing transition script extended for the pin; an iOS type-check. Loudspeaker routing itself needs a device. | Script output; device checklist. |
| E.3 Permissions and sandbox | Built `Info.plist` and entitlements inspected; a first-run permission prompt on macOS. | Command output; screenshot. |
| E.4 Press-and-release gesture, scene and window cancellation, Space | Scenarios for cancellation; a manual macOS run with mouse and Space. | Runner output; screen recording or log. |
| §4 State machine and screen | Scenario per transition; screenshots. | Runner output; screenshots. |
| Voice option (Apple or MiniMax) | Turns with each engine; a cache replay; a fallback. | Run logs. |
| Builds; Swift 6 isolation | `xcodebuild` for three destinations; strict type-check. | Logs. |
| Optimizations | Timings before and after each kept row. | Self-test output. |

**What I cannot verify on this Mac.** A physical iPhone is needed for loudspeaker routing, Bluetooth input, haptics while recording, the microphone indicator turning off between presses, interruption by a phone call, the real Translation download prompt on iOS, and real iPhone timings. Phase 6 delivers a short checklist for these, and I will say plainly in the final report that they were not run.

## 8. Risks

| Risk | Mitigation |
|---|---|
| The Simulator cannot run the real speech or translation models. | Labeled mocks there; the real pipeline is exercised on macOS; the device checklist covers iPhone. |
| `SpeechService` has more than sixty call sites, and its completion logic changes. | The public API stays source-compatible. The existing scripts keep passing. A scenario covers `speakAndWait`, cancellation and App Intent use. |
| The pin interacts badly with interruptions. | Session loss already reaches every audio feature through one bridge; the interpreter joins it and re-pins on the next press. Covered by coordinator checks with the fake backend. |
| An app may reserve only 5 speech locales. | The error is mapped to a clear message. The app uses at most three (`en-US`, `zh-CN`, `zh-TW`). |
| Translation reports `.installed` but fails at run time (reported by other developers). | One retry through the `.translationTask` session, then the AI-provider fallback if configured, then an error with Retry. |
| Two retained speech models use memory. | Retention ends when the screen closes (`SpeechModels.endRetention()`); footprint is measured in Phase 6. |
| Swift 6 strictness against non-Sendable framework types. | Confine them to one isolation domain, use `@preconcurrency` imports as the existing audio code does, and prove it with the strict type-check. |
| Progressive MP3 decoding is fiddly. | It is isolated in Phase 7 behind a measured rule, with a documented fallback. |
| MiniMax cost and privacy. | The engine is opt-in, the menu says what is sent, synthesis is cache-first, and nothing speculative is sent. |

## 9. Not in this plan

- Fixes for the four issues in §3.5 (Decision 7).
- Moving the target to Swift 6 mode, raising the deployment target, or repairing the visionOS build.
- An App Intent or Siri phrase for the Interpreter.
- Pinyin and word-by-word study inside turns; an "Open in Translate" action is the natural follow-up.
- Automatic language detection, hands-free mode, and a face-to-face layout.

## 10. Sources

- Speech, Translation and `_Translation_SwiftUI` `.swiftinterface` files and the AVFAudio headers in the iOS 27.2 SDK of Xcode 27.2 (primary source for every signature in §3.3).
- Apple documentation: [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer), [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber), [TranslationSession](https://developer.apple.com/documentation/translation/translationsession).
- MiniMax: [T2A HTTP reference](https://platform.minimax.io/docs/api-reference/speech-t2a-http), [T2A WebSocket guide](https://platform.minimax.io/docs/guides/speech-t2a-websocket). The WebSocket reference page could not be fetched.
- Simulator limits, as reported by developers: [SpeechTranscriber on Simulator](https://developer.apple.com/forums/thread/802969), [SpeechTranscriber not supported](https://developer.apple.com/forums/thread/806765), [WWDC24 "Meet the Translation API" notes](https://wwdcnotes.com/documentation/wwdc24-10117-meet-the-translation-api/).
- Translation failing although the status is installed: [Apple Developer Forums thread 813109](https://developer.apple.com/forums/thread/813109).

## 11. Changes since approval

Recorded 2026-11-19. Sections 1 to 10 are unchanged. Every change below came from a measurement or from something found while building; the evidence is in `handoff.md`, Iteration 38. The measurements can be repeated with `zsh scripts/probe-interpreter.sh translation-behaviour`, `zsh scripts/probe-interpreter.sh speech`, and `zsh scripts/run-interpreter-selftest.sh` with or without `--no-keep-warm`.

### 11.1 What was measured in Phase 7

| Question | Result on the development Mac |
|---|---|
| Is a translation repeatable? | Yes. The same sentence gave the same text three times, with either model. |
| Does a model use the sentence before? | The natural model does: "I met Alex at the bank. It was closed, so we left." became 银行关门了 together and 它关门了 when the second sentence was translated alone. The fast model translated each sentence the same way either way. |
| Can a translation be cancelled? | No. A natural translation cancelled 80 ms in returned after 578 ms, its full length, and then threw `CancellationError`. |
| Do two translations run at once? | No, not even across sessions and models. Two natural translations started together took 457 and 909 ms. A fast one started 100 ms into a natural one took 679 ms instead of 30. |
| What does changing model cost? | The first call after the other model was used is late: about 200 ms for the natural model (670 instead of 473) and 280 ms for the fast one (310 instead of 30). |
| Does a model go cold? | The natural one does, between 4 and 6 idle seconds: 480 ms after 4 s, 856 ms after 6 s, the same after 20 s. The fast one does not (30 to 40 ms after any pause up to 20 s). |
| What brings it back? | One word. A one-word natural translation takes 186 ms warm and 563 ms cold, and the sentence after it takes the warm 480 ms. |
| How does the live transcript relate to the final one? | Live text arrives in bursts about a second apart and trails the audio by up to a second. At release it lacked the last words in all four measured passes, and an English final adds closing punctuation the live text does not have. The final arrived 44 to 108 ms after the input ended. |
| Do vocabulary hints change recognition? | No. 事倍功半 was heard as 是被公办 with and without `contextualStrings`, by both `SpeechTranscriber` and `DictationTranscriber`; two English place names were misheard identically with and without the hint. |

### 11.2 Changes

| Plan | What was built instead | Why |
|---|---|---|
| §5 row N: `.fastResults` as a Phase 7 experiment. | It is on from the first build. | Without it a press shows no live transcript: one burst after about 4 s in English, nothing until release for a 5 s Mandarin clip. With it, about once a second. |
| §4.5: add `.bluetoothHighQualityRecording`. | Not set. | The SDK header says it works only with the default session mode and adds input latency; the brief's mode is `.spokenAudio`. |
| §3 and Phase 2: ask for speech-recognition permission. | Only the microphone is asked for. | Neither transcriber needs it: authorization stayed `notDetermined` and both analyzed audio. |
| §4.1, Phase 4 and §8: fall back to the configured AI provider when Apple's translation fails. | No such fallback. A failed translation is retried once with a fresh session; under Automatic quality the other model then answers; otherwise the turn shows Try Again. | It would send what was said off the device without the person choosing that, against §1. |
| §4.4 I2: a late result for an abandoned turn is dropped. | It is kept as text and never spoken. | Nothing the person said is lost. |
| §5 row G: translate while the button is held, show a live preview, reuse it when the final transcript matches. | Not built. | Its rule was reuse in at least 30% of test turns; it was 0 of 4, and by construction cannot be high, because the live text at release is missing the last second of speech. A natural translation also cannot be cancelled and holds up every other one, so a stale one would add up to half a second to the real one. Reusing per sentence instead would change what the natural model says. |
| §5 row H: at release run both models and wait at most 350 ms for the natural one. | "Automatic" quality, the default: the natural model for every turn, until it takes longer than its allowance on two turns in a row or fails, after which the rest of the visit uses the fast model. The allowance is 400 ms plus a tenth of the time the button was held, between 0.5 and 1.2 s. | The two cannot race: translations run one at a time, cannot be cancelled, and each change of model costs 0.2 to 0.3 s. Choosing per visit instead of per turn avoids paying that cost on every turn. |
| Not in the plan. | The turn's model is touched with a one-word translation when the button goes down and every 2.5 s while it is held. | The natural model goes cold after about 5 s. In the app, with six seconds of rest before each press, the wait from release to the reply being handed to the voice fell from 1009–1083 ms to 655–752 ms over four runs without it and five with it. The press-time touch also absorbs the cost of a change of model while the person is still speaking. |
| §5 rows J and K, Decision 6: MiniMax streaming playback and a connection opened at press time. | Not built. | Decision 6 made J depend on a measured gain. The account answered every request, streaming or not, with status 1008, "insufficient balance", so nothing could be measured. `zsh scripts/run-interpreter-selftest.sh --minimax` repeats the measurement once the account is topped up. The MiniMax voice itself is built and goes through the existing cache-first path. |
| §5 row O: seed the recognizer with saved vocabulary. | Not built. | Its rule was that test phrases improve; none did (§11.1, last row). |
| §4.7: the Simulator uses `DictationTranscriber` if it works there. | A scripted transcript, labeled, like the translation. The Simulator build does not ask for the microphone, and `-InterpreterSimulatorMuted` makes replies silent for scripted runs. | `DictationTranscriber` offers no audio format in the Simulator. The scripted stand-in never opens the microphone, so asking for it would be asking for something unused. |
| §4.1: the Phase 7 streaming files. | Not created. | Rows J and K above. |
| §6: one commit per phase. | Probes; a hygiene guard found necessary on the way; then the feature with its checks; then documents. | The state machine is pure, so its checks were written before the services, and the kept optimizations changed the seam between them. |
| §4.3: a release ends the turn its button started. | A press is an object (`InterpreterPress`) that the coordinator hands to the input that made it, and the release hands it back. | Matching a release by its button let a second input for the same button, such as Space tapped while the pointer held it, end the first input's turn. Found by the last independent read (`handoff.md` Iteration 38 §6a). |
| §4.5: the conversation's hold on the audio session is taken when the screen opens and given back when it closes. | The same, with every opening and hand-back run one after another on a single chain. | Two in flight at once could be carried out in the wrong order, leaving the session given back under a screen that believed it held it. Found by the same read. |
| §4.3 and I10: a new press always wins, including over a transcript that is still being finalized. | A new press wins over a reply. Over words it waits: a press that lands while the previous press is being finalized, or dismissed as a slip, starts the moment that is done, if its button is still down. The earlier turn is translated and kept as text, and not spoken. | An independent review pointed out that the second speaker pressing just as the first lets go would discard what the first had said. |
| §4.6: each turn's replay uses the engine that was chosen for it. | A turn records the voice that actually spoke it. | A MiniMax reply that fell back to the system voice was labeled MiniMax. |
| §3.3: readiness of the translation pair judged on the traditional model. | Ready when either model is installed; a "not installed" is asked about once more; a request for a model that is absent is served by the one that is there. | On one cold start the system reported the traditional model as not installed while the natural one was installed, and both translated a second later. |
| Phase 5: the hold buttons as an inset at the bottom; system indigo and teal. | A bottom bar the conversation fades out behind, opening on the latest turn; a deeper teal; equal-height buttons that stack at the largest text sizes. | Seen in the Simulator and in the macOS capture: turns sat under the buttons, white text on system teal was about 2.5 to 1, and the key cap made one button taller. |

### 11.3 Targets against measurements

Measured by the self-test on the development Mac, with synthesized speech fed through the real recognizer, the real translation models and the real state machine. The clock stops when the reply is handed to the voice, so the voice's own start-up is not in these numbers.

| Stage | Target (§5) | Measured |
|---|---|---|
| Press to microphone live | ≤ 100 ms | 0 to 73 ms with a prepared recognizer and synthesized audio (the real microphone was not opened; see `handoff.md`) |
| Release to final transcript | ≤ 400 ms | 184 to 316 ms, of which up to 150 ms is the tail |
| Final transcript to translation | ≤ 50 ms fast, ≤ 350 ms natural | Natural: 465 to 498 ms for two sentences (261 ms for one in the probe). Fast: 30 to 70 ms |
| Release to reply handed to the voice | ≤ 0.9 s | 655 to 752 ms with the natural model, over five runs |
