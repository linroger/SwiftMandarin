# MiniMax AI Audio and Multimodal Translation Plan

**Created (UTC):** 2026-07-20T19:55:55Z

**Branch:** `codex/minimax-ai-audio`

**Base:** `origin/main` at `329ad5fbf59edab83d208b4edb6a4e38b4bdbf47`

**Approval:** The user explicitly requested implementation, live API research/testing, and complete integration across every speech action. This document is the implementation contract for that request.

## Task brief

Add an opt-in AI Audio mode that routes every existing read-aloud action through MiniMax text-to-speech, saves the resulting MP3 files in app-owned persistent storage, reuses identical cached speech, and makes saved audio playable, manageable, and exportable. The existing system speech synthesizer remains the default and the deliberate fallback when AI Audio is disabled or a MiniMax request cannot complete.

Rename the Photo tab to Multimodal without changing its stable route identity. Extend that tab with audio recording and audio-file import. A learner can transcribe the selected audio into the existing editable text area or choose Translate Audio, which performs transcription and translation as a single visible action while still preserving the intermediate transcript for correction and study.

MiniMax's current public API documentation exposes TTS, long-form TTS, voice cloning/design, voice management, and related file operations, but no supported general-purpose uploaded-audio transcription or speech-translation endpoint. Therefore MiniMax MUST be used for generated speech, while audio transcription MUST use Apple's Speech framework and direct audio translation MUST compose transcription with the app's existing text-translation path. The deprecated MiniMax Realtime/GroupId interface MUST NOT be used.

## Requirements and acceptance criteria

1. **Settings-controlled routing.** AI Audio is off by default, is independently toggleable in both macOS and iOS AI settings, and uses the existing MiniMax Keychain credential without requiring MiniMax to be the selected text provider.
2. **Complete speech coverage.** `SpeechService` remains the single public speech router. All current `speak`, `speakAuto`, language-specific, slow-playback, App Intent, and preview callers automatically follow the AI Audio setting without per-view network code.
3. **Safe fallback and cancellation.** A new speech request cancels prior synthesis/playback. Disabled, missing-key, over-limit, transport, API, decode, persistence, and playback failures produce a useful status and fall back once to system speech; secrets and request authorization headers are never logged.
4. **Strict MiniMax contract.** Synchronous non-streaming `POST /v1/t2a_v2` uses Bearer authorization, `speech-2.8-turbo` by default, mono 32 kHz 128 kbps MP3, strict HTTP/application-status validation, `data.status == 2`, nullable-data handling, and strict hexadecimal decoding. Text must be non-empty and under 10,000 characters.
5. **Persistent, reusable audio.** Cache identity includes a schema version plus normalized text, language, endpoint region, model, voice, speed, volume, pitch, sample rate, bitrate, and format; SHA-256 makes it deterministic. MP3 data is written atomically under Application Support and replayed without another API call when the identity matches.
6. **Export and management.** A generated-audio library shows source text, language, date, model/voice, duration/size when known, play/stop, export, individual delete, and clear-all. Export writes a real local MP3 through the platform file exporter; it never exposes a temporary service URL.
7. **Multimodal audio input.** The Photo tab's visible name and navigation title become Multimodal while its `AppTab.photo` raw value and routes remain stable. It accepts microphone recording and common audio files, allows English, Simplified Chinese, or Traditional Chinese recognition, previews the selected recording, and clearly reports permissions/progress/errors.
8. **Two audio outcomes.** Transcribe to Editor fills the existing `TextEditor` and runs the same language analysis as typed/OCR text. Translate Audio first fills that editor, then invokes the existing English-to-Chinese or Chinese-to-English translation flow, so the transcript stays editable and inspectable.
9. **Privacy and disclosure.** The UI states that enabled AI Audio sends spoken text to MiniMax. Audio transcription uses Apple Speech; imported/recorded audio is not uploaded to MiniMax. The API key remains Keychain-only. The user-provided credential MUST NOT appear in source, fixtures, docs, shell command text, logs, commits, or final output.
10. **Cross-platform quality.** iOS Simulator and macOS Debug builds pass without new source diagnostics; deterministic contract/storage tests pass; a credential-backed live TTS smoke test validates both Mandarin and English where an existing Keychain entry is available; export and cached replay are scenario-tested.

## Architecture and interfaces

### Settings

- Extend `AppPreferences` with persisted AI Audio enablement, API region, TTS model, Mandarin voice, and English voice.
- Reuse `AIModelSettings.apiKey(for: .minimax)` / `setAPIKey` so there is one Keychain item (`apikey.minimax`) shared with MiniMax text features.
- Add one shared `AIAudioSettingsSection` to `AISettingsTab` and `AISettingsDetailView`. It owns no secret persistence itself; bindings write through `AIModelSettings`.

### Synthesis, storage, and playback

- `MiniMaxAudioClient` is an actor-backed URLSession client with injected session support for deterministic tests and a typed error taxonomy.
- `MiniMaxSpeechConfiguration` is a Sendable value snapshot assembled on the main actor before the request. Network code never reaches observable settings singletons directly.
- `GeneratedSpeechStore` is the main-actor observable metadata index. Audio bytes live in `Application Support/GeneratedAudio`; metadata is a tolerant Codable payload. File writes are atomic and performed off the main actor.
- `SpeechService` continues to expose the existing synchronous call surface. It either performs current local synthesis or starts one cancellable async MiniMax operation, persists/reuses the MP3, and plays it with `AVAudioPlayer`.
- `SpeechService.stop()` cancels in-flight network work, stops persisted-file playback, stops `AVSpeechSynthesizer`, and releases the iOS audio session.

### Multimodal audio input

- `AudioCaptureService` records AAC/M4A to a temporary app file and previews it. It owns the recorder/player and permission lifecycle.
- `AudioTranscriptionService` uses `SFSpeechURLRecognitionRequest`, preferring on-device recognition when supported. It takes an explicit source locale and returns one final transcript or a typed error.
- `MultimodalAudioInputView` handles recording/import UI and returns `(transcript, action)` to `PhotoTranslateView`; it does not duplicate text analysis or translation logic.
- File import copies security-scoped input into an app temporary file before access ends, validates non-empty audio and a bounded size, and cleans superseded temporary recordings.

## Invariants

- API keys MUST remain Keychain-only and MUST never be interpolated into diagnostics.
- A MiniMax HTTP 2xx response is not success unless `base_resp.status_code == 0`, `data.status == 2`, and strict hex decoding yields non-empty bytes.
- A persisted record MUST never reference a missing/empty file; failed writes MUST NOT update metadata.
- Identical in-flight/cache identities MUST not create duplicate paid requests or duplicate library rows.
- The system synthesizer MUST remain available as the no-network default and one-shot failure fallback.
- `AppTab.photo.rawValue` MUST remain `photo` so saved navigation and App Intent routes do not break.
- Audio translation MUST preserve the transcript in the editor before translation begins.
- Imported/recorded source audio MUST NOT be sent to MiniMax under the current API contract.

## Increment plan

1. Capture baseline source/build state, official MiniMax contract, all speech call sites, settings seams, Photo-tab editor/translation seams, entitlements, and existing Apple Speech infrastructure.
2. Implement pure MiniMax request/response, strict hex decoding, deterministic cache identity, persistent file/metadata storage, and focused credential-free checks.
3. Integrate cancellable persistent MiniMax playback behind `SpeechService`; retain local fallback and prove every current speech call site flows through the router.
4. Add shared AI Audio settings, privacy disclosure, connection/test action, generated-audio library, playback, deletion, and file export.
5. Add audio capture/import/transcription components; embed them in `PhotoTranslateView`, rename visible Photo surfaces to Multimodal, and compose direct translation with existing handlers.
6. Run deterministic checks, secret scans, localization/project hygiene, iOS/macOS builds, Keychain-backed live TTS smoke tests, cached-offline replay, export, and UI scenarios.
7. Complete independent architecture/UI/code reviews, resolve all Critical/Important findings, update the root handoff, commit the bounded feature, push it, merge it into `main`, and verify remote ancestry without touching the dirty primary checkout.

## Risks and mitigations

- **Paid duplicate requests:** deterministic cache IDs, tap cancellation, and in-flight coalescing prevent repeated charges for identical synthesis.
- **Main-thread I/O:** networking and audio-file writes remain outside the main actor; only observable metadata and playback state update on it.
- **Region/key mismatch:** expose Mainland China and International endpoints and keep their choice independent from the selected text provider.
- **Voice catalog drift:** ship a small documented Mandarin/English default set and allow manual voice IDs rather than embedding hundreds of stale choices.
- **Unsupported transcription promise:** label the pipeline accurately in privacy copy and implementation docs; Apple Speech performs transcription because current MiniMax public APIs do not.
- **Large/unsupported audio:** validate file size and format, surface actionable errors, and avoid retaining superseded temporary files.
- **Long TTS input:** synchronous speak actions enforce MiniMax's under-10,000-character contract and deliberately fall back to system speech; async book narration is outside this slice.
- **Sandbox export:** use a user-selected file exporter and change the macOS sandbox entitlement from read-only to read-write only if the build/runtime requires it.

## Planned evidence

- Official MiniMax documentation URLs and dated API-contract notes in `handoff.md`.
- A deterministic MiniMax audio test script covering request encoding, application-error handling, strict hex decoding, cache identity, and metadata/file consistency.
- `rg` audit showing no direct production synthesizer/playback bypass outside the central services.
- iOS Simulator and macOS build logs under `/tmp/SwiftMandarin-minimax-audio-*`.
- Keychain-backed live smoke output containing status, byte count, format, duration, and cache result only—never the credential or Authorization header.
- Exported MP3 inspection plus relaunch/offline cached-replay evidence.
- `git diff --check`, plist/catalog validation, project-source membership checks, and secret-pattern scans.
