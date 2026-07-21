# Live MiniMax audio catalog and batch audio plan

**Created (UTC):** 2026-07-20T22:07:52Z
**Status:** Implemented and release-verified; Git delivery pending
**Branch:** `codex/minimax-audio-catalog-batch`
**Base:** `origin/main` at `4879c53b81d86f8142b26e4a4ba915916a9cd1f9`

## Task brief

Update AI Audio so Settings exposes the current MiniMax speech models plus the account's live Mandarin and English system voices; correct the Mandarin preview that can currently speak with English language behavior; and let Batch AI Analysis optionally synthesize and persist pronunciation audio for every processed term. Preserve the existing global `SpeechService` router, Keychain-only credential handling, persistent generated-audio library, system-speech fallback, and Multimodal workflow. The result MUST build and remain adaptive on macOS, iPhone/iOS, and iPadOS 27 Golden Gate.

## Source-backed API facts

- MiniMax's current recommended T2A family is `speech-2.8-hd` and `speech-2.8-turbo`. T2A continues to accept the older compatible `speech-2.6-*`, `speech-02-*`, and `speech-01-*` identifiers; Settings labels those separately instead of implying that every accepted identifier is current.
- `POST /v1/get_voice` is the supported live voice-catalog boundary and returns system, cloned, and generated voices.
- A credential-safe live probe against the configured mainland region returned 303 system voices: 26 standard-prefix Mandarin voices, 2 documented Mandarin prefix exceptions, and 6 English voices.
- `GET /v1/models` returned no speech models for this account. It cannot satisfy runtime speech-model discovery, so the app uses a versioned documented model catalog and preserves a valid custom/current selection.
- `POST /v1/t2a_v2` accepts `language_boost`; Mandarin and English synthesis MUST send `Chinese` and `English` respectively instead of `auto`.

## Requirements and acceptance criteria

1. Settings can refresh MiniMax voices from the selected region without exposing the API key, clearly showing loading, offline/last-known, empty, and error states.
2. Mandarin and English voice pickers show friendly names and exact IDs, filter reliably by language, retain a selected custom/cloned/generated voice, and never silently replace a still-valid selection.
3. The model picker presents the two latest Speech 2.8 models first, groups the six older compatible 2.6/02/01 models separately, and preserves a nonempty existing/custom model if the bundled catalog changes.
4. Mandarin preview and every Mandarin AI Audio request send `language_boost: Chinese`; English requests send `language_boost: English`.
5. Existing audio generated under the ambiguous `auto` cache identity cannot masquerade as corrected language-specific audio; the new language boost participates in the cache key/schema.
6. Batch AI Analysis has an explicit, default-off “Generate MiniMax audio” option with cost/privacy copy and availability feedback.
7. When enabled, batch processing synthesizes each term's source/headword pronunciation without playback, uses the selected language-specific configuration, persists through the existing generated-audio pipeline, reuses cache hits, respects cancellation and bounded concurrency, and never discards a successful explanation because audio failed.
8. Batch progress and completion report explanation and audio outcomes separately, including cached/generated/skipped/failed audio, without exposing learning text or credentials in logs.
9. All new UI is native SwiftUI, keyboard/VoiceOver accessible, localized in English and Simplified Chinese, and adaptive on macOS, iPhone, and iPad.
10. Deterministic contracts, secret/hygiene checks, live MiniMax catalog/TTS probes, and clean macOS/iOS/iPadOS 27 builds pass before delivery.

## Invariants and interfaces

- API credentials remain only in Keychain and transient memory; they MUST NOT enter UserDefaults, source, tests, documentation, logs, catalog caches, generated-audio metadata, or exports.
- `SpeechService` remains the single playback router. Catalog fetching and batch synthesis MUST NOT bypass persistence rules or introduce a second playback owner.
- Voice refresh is latest-request-wins. A late response for an old region/key cannot overwrite a newer catalog.
- A failed refresh retains the last successful catalog and current selections; offline behavior remains usable.
- Language selection is explicit and deterministic from the source language. UI labels and voice names never determine request language.
- Batch audio is opt-in and paid. Cache hits avoid duplicate requests, identical in-flight requests coalesce, and cancellation stops pending network work without corrupting saved files.
- Explanation success and audio success are independent result dimensions. Partial audio failure is visible but does not roll back explanation data.
- iPadOS uses the same iOS target and MUST use adaptive layouts without device idiom branching unless a platform API requires it.

## Increment plan

1. Capture current catalog/settings/client/batch contracts, complete official API and live endpoint research, and record the baseline.
2. Add strict voice-catalog decoding, current model metadata, actor-isolated catalog refresh/cache state, and deterministic contract coverage.
3. Replace free-form primary voice settings with accessible live pickers plus a deliberate custom-ID path and robust loading/error/refresh states.
4. Add explicit language boost to synthesis configuration and cache identity, bump the schema, and verify Mandarin/English request bodies and live output.
5. Extend the batch controller with a default-off audio option, cache-first persistent synthesis, bounded cancellation-aware execution, independent progress/outcomes, and localized UI.
6. Run deterministic checks, live catalog/TTS smoke tests, simulator/device builds for macOS/iOS/iPadOS 27, accessibility/layout scenarios, secret scans, and adversarial code review; resolve every Critical/Important finding.
7. Update continuity artifacts, commit the coherent slice, push it, integrate it into current remote main in an isolated worktree, repeat merge-tree gates, and verify remote ancestry.

## Risks and mitigations

- **Voice catalog drift:** Voice IDs and names can change. Fetch at runtime, persist only public catalog metadata, preserve the last successful result, and expose exact IDs.
- **No speech-model listing endpoint:** Do not scrape documentation or mislabel `/models` as authoritative. Keep versioned, lifecycle-labeled metadata for the latest Speech 2.8 family and older T2A-compatible identifiers, while allowing an existing custom model to remain selectable.
- **Wrong-language cached audio:** Include explicit language boost in cache identity and increment the cache schema so old `auto` clips cannot be reused as corrected previews.
- **Paid batch fan-out:** Default the option off, disclose cost, bound concurrency, reuse the persistent cache, coalesce duplicate terms, and surface counts before/after execution.
- **Partial failure:** Store explanation and audio results independently and summarize failures without erasing successful work.
- **UI density on iPhone/iPad:** Use native `Form`, `Section`, `Picker`, `ProgressView`, and adaptive labels; avoid fixed widths and platform-specific duplicated screens.
- **SDK beta drift:** Verify against the installed Xcode 27 SDK and keep deployment-compatible APIs availability-gated.

## Planned evidence

- Credential-free catalog/client/cache/batch contract output under `/tmp/SwiftMandarin-audio-catalog-*`.
- A redacted live catalog summary proving 303/26/6 counts and a live Mandarin TTS result with `language_boost: Chinese`.
- Fresh macOS, generic iOS, iPhone Simulator, and iPad Simulator build logs under `/tmp/SwiftMandarin-audio-catalog-*`.
- UI screenshots or accessibility hierarchy captures for macOS, iPhone, and iPad settings/batch states when simulator automation permits.
- Localization parse, plist/project lint, `git diff --check`, secret scan, audio-artifact scan, and independent architecture/UI/code review findings.

## Completed outcome

- Settings now fetches the selected account's live `/v1/get_voice` catalog, displays 28 recognized Mandarin and 6 English system voices from the tested mainland response, retains only public system metadata offline, and purges credential-scoped account voices when the shared Keychain key changes.
- Speech 2.8 HD/Turbo are labeled **Latest**; 2.6/02/01 identifiers are explicitly grouped as **Older Compatible Models**. The app does not pretend that MiniMax's general `/models` response is a speech catalog.
- Mandarin and English requests serialize explicit `Chinese` and `English` language boosts. Schema-v2 cache identities prevent old `auto` clips from satisfying corrected requests, and both picker selections and manually entered recognized system IDs are checked for wrong-language assignment.
- Batch AI Analysis can preflight, generate, persist, resume, replay, and export cache-first MiniMax audio without automatic playback. The run snapshots provider/audio settings, paces request starts, revalidates cache and credential state before paid work, and fail-closes on ambiguous synthesis failures while retaining already completed explanations and audio.
- The credential-free Swift 6 strict-concurrency contract slice passes 191/191. Live production probes returned 303 system voices and valid explicit-Chinese/explicit-English 128 kbps, 32 kHz mono MP3s. Fresh Xcode 27 builds pass for macOS, iPhone 17 Pro/iOS 27, and iPad Pro 13-inch/iPadOS 27 with zero warning/error diagnostics.
