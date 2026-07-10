# SwiftMandarin Codebase Audit and Recommendations

**Audit date:** 2026-07-10

**Audited branch:** `jul-07-2026-step-change-overhaul`

**Base commit:** `c34963e`

**Scope:** The application target, all Swift source files, App Intents, Xcode project settings, entitlements, assets, localization, persistence, import/export, release/privacy documentation, and the tracked macOS distribution artifact.

## Executive summary

SwiftMandarin has grown into a broad language-learning product rather than a narrow translation utility. It now has a credible five-tab iOS shell, a macOS sidebar and menu-bar experience, translation and OCR, vocabulary with FSRS scheduling, multiple practice modes, Reader, conversations, workbook grading, statistics, AI-provider configuration, and App Intents. Several older architectural recommendations are already implemented.

The next step should not be another independent feature silo. The main opportunity is to make the existing features behave as one learning system. At present, translation direction, backend selection, history policy, learning activity, navigation, word details, and cancellation are implemented differently in different entry points. This creates user-visible contradictions and makes the app harder to test and extend.

The highest-priority work is:

1. Close the release and privacy gaps: add a privacy manifest, correct cloud/off-device consent, minimize macOS entitlements, fix signing/notarization, and stop tracking internal session logs.
2. Establish one resolved translation request and outcome model for text, live speech, photo, screenshot, menu-bar, and Shortcut flows.
3. Make long-running work cancellable and latest-request-wins so old OCR, speech, grading, or AI work cannot repopulate dismissed views.
4. Unify navigation and learning events so Reader, Conversation, Workbook, Practice, OCR, vocabulary, Home, and Stats share one source of truth.
5. Replace dead settings and misleading success states with behavior that is either implemented end to end or not exposed.
6. Add automated tests and CI. The project currently has no test target or CI workflow, despite persistence, language-routing, AI, and platform branches that are easy to regress.

No runtime source code was changed as part of this audit.

## Audit method and confidence

The audit covered all 90 Swift files (approximately 33,000 lines), project configuration, release artifacts, and current documentation. Existing `RECOMMENDATIONS.md` and `EXECPLAN2.md` were treated as leads, not as current truth; every included issue below was rechecked against the current code.

Build evidence:

- macOS Debug, unsigned: **passed** with Xcode beta.
- iOS Simulator Debug: **passed** when run in isolation with Xcode beta.
- visionOS Simulator Debug: **failed**. The first compiler error is `TranslationSession` being unavailable on visionOS at `SwiftMandarin/Intents/ShortcutHelpers.swift:81`.
- Automated tests: **none exist**; the Xcode project contains only the application target.

The audit did not exercise real camera/microphone permissions, live AI credentials, actual provider billing/rate limits, VoiceOver on hardware, App Store upload, or notarization submission. Findings that depend on overlap timing or device UI behavior are marked **validation needed**.

Severity used in this document:

- **Release gate:** can block distribution, violate a user privacy choice, leak sensitive data, or contradict a supported-platform claim.
- **P1:** high-impact correctness, data integrity, privacy, or trust problem.
- **P2:** material reliability, performance, accessibility, or product-cohesion problem.
- **P3:** polish, documentation, or lower-frequency inconsistency.

## Priority index

| ID | Priority | Finding | Recommended owner |
|---|---|---|---|
| RG-01 | Release gate | Required privacy manifest is absent | Platform/release |
| RG-02 | Release gate | visionOS is advertised but does not compile | Platform/architecture |
| RG-03 | Release gate | Tracked DMG is ad-hoc signed, unnotarized, and over-entitled | Release engineering |
| RG-04 | Release gate | Agent/session transcripts and logs are tracked and referenced by Xcode | Repository/security |
| RG-05 | Release gate | Shortcut backend and history behavior can violate explicit user choices | Translation/privacy |
| RG-06 | Release gate | LAN and permission disclosures are incomplete and not localized | Platform/privacy |
| C-01 | P1 | Visible translation direction can disagree with the operation performed | Translation |
| C-03/C-04 | P1 | Screenshot, photo, and workbook pipelines can publish stale results | Concurrency/state |
| C-05 | P1 | Keychain replacement can destroy the old key and report false success | Security/settings |
| C-06 | P1 | Lossy persistence recovery can overwrite the last-known-good backup | Persistence |
| C-12/C-13 | P1 | Activity, history, and statistics are incorrectly coupled | Learning architecture |
| C-18/C-19 | P1 | Navigation ownership and app-wide language identity are fragmented | Navigation/UI |
| C-20 | P1 | Settings expose numerous controls with no consumers | Settings/product |
| Q-01 | P1 | No tests or CI protect core and platform behavior | Quality |

## Release and privacy gates

### RG-01 — Add and validate `PrivacyInfo.xcprivacy`

**Evidence:** No `PrivacyInfo.xcprivacy` exists, while `UserDefaults` is used extensively, including `SwiftMandarin/Models/PersistentCodableStore.swift:62-69` and `:93-98`.

Apple identifies `UserDefaults` as a required-reason API and requires the app bundle to declare an approved reason in a privacy manifest. See [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) and [TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).

**Recommendation:**

- Add a target-member `PrivacyInfo.xcprivacy` with the accurate approved reason for app-only defaults access.
- Audit accessed APIs and collected-data declarations for the app and `ollama-swift` dependency instead of copying a generic manifest.
- Generate and inspect the archive privacy report as a release gate.
- Add a CI check that the manifest is present, valid, and bundled.

**Acceptance:** A clean archive contains the manifest, its privacy report matches actual behavior, and App Store validation produces no missing-required-reason warning.

### RG-02 — Either support visionOS deliberately or remove the claim

**Evidence:** `SUPPORTED_PLATFORMS` includes `xros` in `SwiftMandarin.xcodeproj/project.pbxproj:360-367` and `:433-440`, and `README.md:418` advertises visionOS. A real generic visionOS Simulator build fails at `SwiftMandarin/Intents/ShortcutHelpers.swift:81` because `TranslationSession` is explicitly unavailable on visionOS.

There are additional platform assumptions that will need attention after the first compile failure:

- `SwiftMandarin/Intents/TranslateScreenshotsIntent.swift:62-96` treats every non-iOS platform as AppKit/`NSImage`, which is not true on visionOS.
- `SwiftMandarin/ContentView.swift:40-44` uses the iOS tab shell for every non-macOS platform, while `SwiftMandarin/Models/AppRouteStore.swift:28-58` routes only `os(iOS)` through the matching tab vocabulary.
- Several camera and Translation framework branches use `#if os(iOS)` where `canImport(UIKit)` or explicit visionOS handling is required.

**Recommendation:** Choose one of two honest paths:

1. Remove `xros` and the README claim until there is a native product design; or
2. Create explicit iOS/macOS/visionOS adapters, omit unavailable App Intents, provide a visionOS route shell, and add a visionOS CI build.

**Acceptance:** All advertised platforms compile in CI and every advertised Shortcut maps to an available feature on that platform.

### RG-03 — Replace the tracked development DMG with a real release pipeline

**Evidence:** The tracked `dist/SwiftMandarin-2.0-macOS.dmg` contains an arm64-only, ad-hoc-signed app with no TeamIdentifier, no notarization ticket, and `get-task-allow=true`. `SwiftMandarin.xcodeproj/project.pbxproj:376-400` also forces an Apple Development identity and enables a large set of Release entitlements not present in `SwiftMandarin/SwiftMandarin.entitlements:5-12`, including contacts, calendars, location, Bluetooth, USB, Apple Events, incoming networking, and broad folder access.

**Impact:** Gatekeeper/publisher-trust friction, unnecessary attack surface around an app holding API keys, App Review scrutiny, and conflicting entitlement sources.

**Recommendation:**

- Make the entitlement file the reviewed source of truth and reduce it to capabilities actually used.
- Archive with Developer ID Application, hardened runtime, and `get-task-allow=false`.
- Notarize and staple; verify with `codesign`, `spctl`, and `stapler` in the release workflow.
- Decide whether Intel is supported. Publish a universal artifact or label Apple-silicon-only support accurately.
- Publish binary releases outside Git rather than committing DMGs.

### RG-04 — Remove tracked internal transcripts and logs

**Evidence:** `.gitignore:5-8` ignores only nested `SwiftMandarin/logs/` and `SwiftMandarin/.claude/`. Root `logs/` and `.claude/` remain tracked. At audit time, 68 tracked session/log files totaled roughly 59 MiB, and `SwiftMandarin.xcodeproj/project.pbxproj:14-29` and `:72-85` referenced prompt/tool/chat logs in the Xcode project navigator. They are not members of the resources build phase.

**Impact:** Repository bloat and potential disclosure of prompts, commands, local paths, or confidential context. If the repository is published, Git history preserves removed secrets unless it is rewritten.

**Recommendation:**

- Remove the Xcode project references and the root logs/agent transcripts from the Git index.
- Ignore root-level `logs/`, `.claude/`, Derived Data, and local audit artifacts.
- Run a real secret scan without printing discovered values; rotate exposed credentials if any are found.
- If the repository has been shared, evaluate a coordinated history scrub.
- Keep only intentionally written, low-sensitivity project handoff summaries.

### RG-05 — Make off-device processing and history retention honor the same policy everywhere

**Evidence:**

- `SwiftMandarin/Intents/TranslateTextIntent.swift:18-19`, `TranslateClipboardIntent.swift:15-16`, and `SpeakTranslationIntent.swift:19-20` expose a “Use Apple Intelligence” Boolean.
- On systems before the Apple Translation path is available, `SwiftMandarin/Intents/ShortcutHelpers.swift:63-73` can still route to configured AI, and `:101-108` treats any provider as AI. The effective provider can be cloud-backed through `SwiftMandarin/Services/AIWordExplanationService.swift:508-531`.
- The in-app translator honors “Save Translations to History” at `SwiftMandarin/Views/TranslateView.swift:1201-1206`, but `TranslateTextIntent.swift:42-47` and `TranslateClipboardIntent.swift:44-49` always save.
- The microphone purpose string says speech is transcribed on-device (`SwiftMandarin.xcodeproj/project.pbxproj:333` and `:406`), while the iOS 17 fallback in `SwiftMandarin/Services/SpeechRecognitionService.swift:581-590` can use Apple server recognition when on-device recognition is unsupported.
- `PRIVACY.md` describes cloud transfer mostly as translation, explanation, OCR cleanup, and grading; Reader prompts, conversations, generated stories/questions, and word-identification input should also be described explicitly.

**Recommendation:** Create an explicit execution policy with separate fields such as `allowCloud`, `allowAppleService`, `saveHistory`, and `recordLearningActivity`. Do not infer cloud permission from “AI available.” Show the provider and off-device state before or alongside execution, and return a clear unavailable result instead of silently broadening consent.

### RG-06 — Add the missing local-network and localized permission disclosures

**Evidence:** Ollama accepts a LAN host in `SwiftMandarin/Models/AIModelSettings.swift:386-387` and `:614-617`, but the generated Info.plist has no `NSLocalNetworkUsageDescription`. Apple states that apps connecting directly to local hosts should provide this description: [NSLocalNetworkUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription).

Camera, photo, microphone, and speech purpose strings are injected as English-only build settings at `SwiftMandarin.xcodeproj/project.pbxproj:328-333`; there is no `InfoPlist.xcstrings`.

**Recommendation:** Add localized English and Simplified Chinese permission strings, including an accurate local-network purpose. Test allow, deny, Settings recovery, and LAN reconnect on physical devices.

## Correctness, integrity, and concurrency

### C-01 — Resolve translation direction once and carry it through the entire result

**Evidence:** The selector, labels, and speech voices read `sharedState.direction` in `SwiftMandarin/Views/TranslateView.swift:221-265`, `:495-503`, and `:623-631`. The actual translation independently detects input direction at `:918-955` and does not update the visible direction. `inputLanguageMismatch` and the redundant follow-up translation path at `:655-665` and `:732-755` further split the state. Live speech repeats the pattern in `SwiftMandarin/Views/Components/LiveSpeechTranslationView.swift:51-64`, `:525-560`, and `:731-759`.

**Impact:** A correct translation can carry the wrong source/target label, use the wrong TTS voice, show a misleading swap state, or trigger a second unnecessary translation.

**Recommendation:** Introduce a `ResolvedTranslationRequest` containing normalized source text, detected/selected source and target languages, direction origin (`manual` or `detected`), backend policy, and request ID. Produce a `TranslationOutcome` with provider, off-device status, warnings, history/activity effects, and timing. Use these types across text, live speech, photo, screenshots, menu bar, and App Intents.

If auto-detect is retained, make it visible and undoable: “Detected English; translating to Chinese.” If the selector is authoritative, do not silently override it.

### C-02 — Never return source text as a successful translation

**Evidence:** “Use Translation” in `SwiftMandarin/Views/Components/LiveSpeechTranslationView.swift:661-676` returns the transcript whenever `translatedText` is empty, including error and not-ready states.

**Impact:** A caller can receive untranslated source text as if the translation succeeded.

**Recommendation:** Disable the action until a successful outcome exists. Preserve errors with retry/setup actions; never substitute the transcript without explicitly labeling it “Use original.”

### C-03 — Make screenshot processing owned, cancelable, and latest-run-wins

**Evidence:** `SwiftMandarin/Models/ScreenshotTranslationStore.swift:162-202` runs an async stitch/OCR/translation pipeline, but `clear()` and `reset()` at `:205-219` only reset visible state. An old run can repopulate cleared results or race a new run. `SwiftMandarin/Intents/TranslateScreenshotsIntent.swift:85-88` and `:116-119` launch fire-and-forget work; a second invocation can replace pending images while re-entry is refused.

The store also concatenates blocks using `§§§` and assumes the translator preserves it (`ScreenshotTranslationStore.swift:269-297`). If the delimiter changes, missing translations silently fall back to source text.

**Recommendation:** Retain one processing task, cancel it on clear/reset, attach a run UUID, and check cancellation/identity after every await. Translate structured blocks by stable IDs or as separate requests and fail visibly on cardinality mismatch.

### C-04 — Apply the same latest-run rule to Photo and Workbook

**Evidence:**

- The Photo file importer and re-recognition flows start untracked tasks at `SwiftMandarin/Views/PhotoTranslateView.swift:239-247` and `:412-420`. Vocabulary extraction launches another untracked task at `:556-573`, applies its result at `:1274-1303` without validating the current source, and `clearAll` at `:1345-1367` does not cancel that work.
- A canceled old image-processing task can also set the shared `isProcessing` false while a newer task is active (`PhotoTranslateView.swift:883-938`).
- Workbook grading and question generation launch untracked tasks and remain dismissible at `SwiftMandarin/Views/WorkbookGradingView.swift:118-121`, `:375-385`, `:585-637` and `WorkbookQuestionBankView.swift:248-251`, `:313-325`, `:381-405`.

**Impact:** Stale OCR/vocabulary can overwrite newer images, progress can disappear prematurely, and dismissed workbook work can later write photos, history, activity, or generated questions.

**Recommendation:** Create a small `PhotoPipelineController`/operation model with one current source ID, owned task, explicit phases, and durable background intent only when the UI says the operation will continue. Use the same operation primitive for grading and generation.

### C-05 — Use transactional Keychain replacement

**Evidence:** `SwiftMandarin/Services/KeychainHelper.swift:24-41` deletes an existing item before adding its replacement. `SwiftMandarin/Models/AIModelSettings.swift:423-431` ignores the Boolean result and updates its in-memory mirror regardless.

**Impact:** An add failure destroys the valid old credential while Settings appears to show the new credential until relaunch.

**Recommendation:** Use `SecItemUpdate`, fall back to add only on `errSecItemNotFound`, propagate `OSStatus`, and change observable state only after success. Add a failure-injection test.

### C-06 — Do not replace the last-known-good backup with partially corrupt data

**Evidence:** `SwiftMandarin/Models/PersistentCodableStore.swift:21-26` and `:38-48` tolerate corrupt collection elements by dropping them. `loadData` at `:61-80` then copies the original primary payload into `.backup` even after lossy recovery.

**Impact:** A row disappears silently and the backup no longer represents a known-good state.

**Recommendation:** Return decode diagnostics including dropped indices/count. Never promote a partially recovered primary to backup. Preserve the prior backup, save salvaged data separately, and show the user an actionable recovery report.

### C-07 — Replace the speech Boolean with a lifecycle state machine

**Evidence:** In `SwiftMandarin/Services/SpeechRecognitionService.swift:235-301`, `isRecording` remains false through authorization, model loading, and engine startup awaits. `stopRecording` at `:308-313` can run during that window. Because the actor is reentrant, overlapping starts can replace the stored engine or a stopped local engine can later publish `isRecording=true`.

**Confidence:** Validation needed for the exact UI reproduction; the overlapping transition paths exist statically.

**Recommendation:** Model `idle`, `authorizing`, `preparing`, `recording`, `stopping`, and `failed`, use a generation token, and make transitions idempotent. Join Mandarin final segments without unconditional spaces (`SpeechRecognitionService.swift:267-280`, `:333-339`).

### C-08 — Detect image media types correctly and report whether vision was used

**Evidence:** `SwiftMandarin/Services/CloudAIService.swift:404-410`, `:547-560`, and `:595-605` infer media type from too little data, causing HEIC/HEIF to be labeled JPEG and generic RIFF files to be labeled WebP. Image cleanup can also fall back to a non-vision model; `AIWordExplanationService.swift:843-855` and `:921-931` request image help, while `CloudAIService.swift:235-239` silently drops images for a non-vision provider.

**Recommendation:** Inspect full magic signatures or normalize uploads to bounded JPEG/PNG. Return execution metadata such as `usedImage`, model, provider, token/cost estimate, and fallback reason. The UI should say “text-only cleanup” when the image was not actually examined.

### C-09 — Validate semantic AI output before caching it

**Evidence:** `SwiftMandarin/Services/AIWordExplanationService.swift:740-756` and `:1480-1494` accept `{}` as an explanation because every field defaults, then cache an empty result. `SwiftMandarin/Services/WordIdentificationService.swift:136-152` caches an empty array after a failed reconstruction, preventing retries for that passage during the session.

**Recommendation:** Define minimum semantic invariants, cache only validated outcomes, and key transient failures by provider/model with a short TTL. Provide retry and raw-response diagnostics that do not expose API keys.

### C-10 — Add rate-limit coordination and bounded retries

**Evidence:** `SwiftMandarin/Services/CloudAIService.swift:270-287` and `:343-360` fail immediately on transient 429/5xx responses. Concurrent batch work continues scheduling after failures (`SwiftMandarin/Models/BatchExplanationController.swift:195-205`).

**Recommendation:** Add bounded exponential backoff with jitter, honor `Retry-After`, and pause new work per provider after repeated rate limits. Preserve cancellation and distinguish retryable, configuration, authentication, and content errors.

### C-11 — Require TLS for credential-bearing custom endpoints

**Evidence:** `SwiftMandarin/Models/AIModelSettings.swift:434-447` accepts arbitrary base URLs. `SwiftMandarin/Services/CloudAIService.swift:231-242` and `:378-389` send bearer or API-key headers to the resulting host.

**Recommendation:** Require HTTPS for cloud providers. Permit HTTP only for explicit loopback/local modes; treat LAN HTTP as a separate, warned opt-in and never reuse a valuable public-provider credential. Confirm when a credential’s destination host changes.

## Data, learning, and product cohesion

### C-12 — Decouple history retention from learning activity

**Evidence:** `SwiftMandarin/Models/TranslationHistory.swift:75-94` records a translation activity when adding history. The in-app text and photo flows therefore stop counting activity when automatic history is disabled (`TranslateView.swift:1201-1206`; `PhotoTranslateView.swift:1063-1107`). Shortcuts always save history, while screenshot translation records neither history nor activity.

**Impact:** Statistics depend on a privacy/storage preference rather than actual practice, and identical actions produce different results depending on entry point.

**Recommendation:** Introduce a typed append-only learning-event ledger. Record an event independently from optional content retention. Derive daily totals, streaks, weak skills, and Home recommendations from events.

The event should include activity type, duration/attempt count, source feature, direction, related item IDs, correctness/reveal use, and privacy-safe metadata. It should not duplicate private source text unless the user chose to retain it.

### C-13 — Count the learning the app actually supports

**Evidence:** `SwiftMandarin/Models/LearningActivity.swift:10-35` and `:234-274` track words, reviews, translations, and questions. Reader and Conversation do not record activity. Practice views record one generic review completion per round (`QuizView.swift:287-290`, `DictationView.swift:380-383`, `TonePairDrillView.swift:303-306`), conflating a practice round with an FSRS review.

**Recommendation:** Add distinct events for reading time/paragraphs, speaking/listening turns, tone pairs, dictation attempts, workbook answers, generated-question answers, OCR study, vocabulary capture, and actual scheduled-card reviews. Preserve first-attempt accuracy and reveal/retry count; Dictation currently allows eventual correction to count as fully correct (`DictationView.swift:324-383`).

### C-14 — Make “Bilingual” a real content policy or remove it

**Evidence:** `LearnerMode.bilingual` exists in `SwiftMandarin/Models/AppPreferences.swift:19-25`, but `learningLanguageIsChinese` collapses it to one Boolean (`:65-81`), and most features derive direction from `LocalizationManager.learningIsChinese`. `:208-219` merely preserves the current UI direction when bilingual is selected.

**Impact:** The label promises balanced two-way learning without mixed decks, bidirectional sessions, or per-feature direction behavior.

**Recommendation:** Define independent interface language and learning-direction policy. A genuine bilingual mode should balance directions by skill/session and show direction on every saved item and exercise. Otherwise rename it to the actual behavior.

### C-15 — Provide a complete, versioned backup rather than calling CSV/JSON a backup

**Evidence:** CSV export omits UUID and sort order (`SwiftMandarin/Services/VocabularyImportExportService.swift:192-225`), always skips row zero as a header (`:301-336`), and recreates UUID-based learning identities. Neither CSV nor current JSON preserves all SRS/activity data. Workbook, Reader, Conversation, referenced images, and preferences are separate stores.

Malformed inputs can also become blank vocabulary: tolerant decoding in `SwiftMandarin/Models/SavedTerm.swift:46-57` combined with import at `VocabularyImportExportService.swift:284-351` accepts `{}` and reports no row-level error.

**Recommendation:** Distinguish portable vocabulary export from complete app backup. Create a versioned archive with IDs, order, cards/SRS history, activity events, Reader, conversations, workbook metadata/images, and safe preferences. Exclude credentials by default. Validate required headwords and return row-indexed import errors.

### C-16 — Bound growing stores and move large decoding off the MainActor

**Evidence:** File-backed singleton initialization decodes synchronously in `SwiftMandarin/Models/PersistentCodableStore.swift:118-130`, including `WordExplanationCacheStore.swift:322-327`, `ReaderStore.swift:340-344`, and `ConversationStore.swift:233-236`. Conversations cap session count but not messages (`ConversationStore.swift:160-169`), and every cloud turn sends full history (`ConversationService.swift:192-203`, `:240-253`). Workbook bank/history rewrites whole arrays in `UserDefaults` and is not transactional with image files (`WorkbookBank.swift:183-241`, `:318-415`).

**Recommendation:** Move growing/queryable data to SwiftData or SQLite with schema migrations and indexed queries. Load asynchronously. Apply conversation token budgets with recent turns plus a rolling summary. Store workbook metadata and images transactionally and add orphan cleanup.

### C-17 — Connect grammar content to grammar detection

**Evidence:** The rich `GrammarPoint` library in `SwiftMandarin/Models/GrammarPoint.swift:116-155` has no active caller. Photo grammar instead uses substring heuristics in `SwiftMandarin/Services/EnglishTextAnalyzer.swift:339-402`, including patterns such as `ing` and `ed` that can match inside unrelated words.

**Recommendation:** Build one token/POS-aware grammar matcher that returns stable `GrammarPoint` IDs, and reuse those explanations/examples in Photo, Reader, saved-word context, and generated practice.

## UI, navigation, settings, and accessibility

### C-18 — Use one navigation stack per tab or window

**Evidence:** `SwiftMandarin/Views/StudyHubView.swift:34-57` and `MoreView.swift:35-58` push destinations that create their own `NavigationStack`, including `LearnView.swift:79-165`, `PracticeHubView.swift:22-46`, `ConversationView.swift:23-44`, `ReaderView.swift:31-63`, `VocabularyView.swift:70-326`, `PhrasesView.swift:33-70`, and `HistoryTabView.swift:42-154`.

**Impact:** Split path ownership risks fragile back behavior, duplicate navigation chrome, inconsistent deep links, and poor restoration; those runtime symptoms need UI validation on each platform. The competing ownership is confirmed. More also duplicates learning destinations already owned by Study (`MoreView.swift:16-28`, `:63-86`).

**Recommendation:** One stack owns each tab/window; feature roots are stack-agnostic content. Extend the shared router with typed destinations such as `openWord(id:)`, `startReview(cardID:)`, `openReader(documentID:)`, and `openConversation(id:)`. Keep Study as the learning workspace and make More settings/data/help only.

### C-19 — Do not rebuild the entire app to change language

**Evidence:** `.id(localizationManager.currentLanguage)` at `SwiftMandarin/SwiftMandarinApp.swift:34-46` changes the root identity. `SwiftMandarin/Models/LocalizationManager.swift:158-176` applies the same identity-reset pattern to localized surfaces.

**Impact:** Study paths, quiz/review state, Reader position, drafts, photo work, conversations, and presented sheets can reset when the interface language changes.

**Recommendation:** Propagate locale and observed strings through the environment without changing the application tree identity. Persist truly session-critical state and add a test that changes language during each major workflow.

### C-20 — Implement or remove dead settings

Repository-wide reference tracing found no effective consumers for these controls in `SwiftMandarin/Views/MacOSSettingsView.swift` and `MoreView.swift`:

- Launch at Login, Show Dock Icon, Global Hotkey (`MacOSSettingsView.swift:55-58`, `:89-109`)
- Auto-Speak (`MacOSSettingsView.swift:208`, `:231-235`; `MoreView.swift:252`, `:273`)
- Chinese Font, Word Borders, Compact Mode (`MacOSSettingsView.swift:264-267`, `:299-314`); word borders remain unconditional at `RubyTextView.swift:163-176`
- Review Reminders, Reminder Time, Show Streak, Auto-Advance, Show Hints (`MacOSSettingsView.swift:363-368`, `:382-401`)
- Ollama Context Length is stored in `AIModelSettings.swift:601-609`, but the option builder is not used by `OllamaService.swift:71-87`, `:186-190`, or `:249-253`.

**Recommendation:** Centralize typed preferences and maintain a setting-to-consumer parity test. Remove or disable controls until their complete behavior exists. Reminders require permission, scheduling, rescheduling, cancellation, and an in-app status—not just a stored time.

### C-21 — Fix destructive actions and false success feedback

**Evidence:**

- Vocabulary “Clear All” immediately calls `savedTermsStore.clear()` without confirmation/undo (`SwiftMandarin/Views/VocabularyView.swift:170-175`, `:240-245`). Learn progress reset is immediate at `LearnView.swift:116-127`.
- `SaveVocabularyTermIntent.swift:56-66` reports “Saved” even when `SavedTerm.swift:156-164` skips a duplicate.
- macOS export shows success before the asynchronous save panel/write completes (`VocabularyImportExportService.swift:249-266`; `VocabularyView.swift:1469-1481`; `MacOSSettingsView.swift:456-462`).
- Shortcut vocabulary extraction is fire-and-forget (`ShortcutHelpers.swift:138-160`), but the intent returns success immediately.
- Menu-bar “Open SwiftMandarin” only calls `NSApp.activate()` (`MenuBarTranslateView.swift:276-284`) and cannot recreate a closed `WindowGroup`.

**Recommendation:** Use typed results (`inserted`, `duplicate`, `canceled`, `failed`), await side effects before reporting success, and add a shared undo center. Give the main window an ID and use `openWindow(id:)` before activation.

### C-22 — Complete accessibility semantics before adding more visual complexity

High-confidence issues include:

- Quiz and Tone Pair auto-advance after roughly one second regardless of the dead preference, without sufficient VoiceOver result time (`QuizView.swift:131-171`, `:255-271`; `TonePairDrillView.swift:166-201`, `:265-288`).
- Flashcard flipping is an `onTapGesture` over overlapping faces rather than a semantic action (`LearnView.swift:303-327`, `:565-635`).
- Phrases, History, and Vocabulary use tap gestures for primary rows instead of `Button`/`NavigationLink` semantics (`PhrasesView.swift:33-44`; `HistoryTabView.swift:63-87`; `VocabularyView.swift:385-406`).
- Live speech pulse animation lacks Reduce Motion handling and clear Start/Stop Listening semantics (`LiveSpeechTranslationView.swift:344-400`).
- AI capability badges announce only “Supported/Not supported,” not the capability (`AIProviderConfigView.swift:264-309`).
- Fixed horizontal action bars are likely to overflow at accessibility sizes (`RubyTextView.swift:359-424`; `VocabularyView.swift:756-826`; `PhrasesView.swift:160-208`; `DictationView.swift:228-256`).
- Reader’s text-size setting does not resize the active ruby paragraph (`ReaderSessionView.swift:47-50`, `:174-206`; fixed fonts at `RubyTextView.swift:230-235` and `EnglishRubyTextView.swift:17-24`).

**Recommendation:** Test VoiceOver, keyboard/focus, Dynamic Type accessibility sizes, Reduce Motion, iPad split view, and narrow macOS windows. Honor manual progression under VoiceOver, announce correctness, hide inactive card faces, use semantic controls, and drive layout from available width rather than device idiom (`StatsView.swift:42-57`, `:473-480`, `:740-780`).

### C-23 — Surface scanner, import, and image failures

**Evidence:** `SwiftMandarin/Views/Components/CameraScannerView.swift:55-67`, `:136-150`, and `:197-245` uses `try?` and largely silent failure paths; icon-only actions lack complete labels. Photo import/drop and workbook file-load errors can be ignored (`PhotoTranslateView.swift:239-247`, `:518-535`; `WorkbookGradingView.swift:502-543`). Missing/corrupt workbook photos show a perpetual spinner (`WorkbookGradingHistoryView.swift:300-369`).

**Recommendation:** Use shared loading/success/empty/failed state components with retry, Open Settings, skip/remove, and per-file error details. Never use a spinner as the terminal invalid-data state.

### C-24 — Complete localization, platform parity, and honest labels

**Evidence:**

- The catalog has 905 keys; 69 lack Simplified Chinese values. Some are intentionally bilingual content, but visible error/action strings remain untranslated, including “Read aloud” and several generated-question parsing errors.
- `PhotoTranslateView.swift:17-35` and `:443-452` emits hard-coded Chinese labels such as `英文` and `未知` in dynamic UI.
- Camera scanner source strings are Chinese and map to Chinese in both locales (`CameraScannerView.swift:179-289` and corresponding catalog entries).
- App Shortcut trigger phrases in `SwiftMandarinShortcutsProvider.swift:13-99` are English-only.
- macOS advertises a Live Scanner Shortcut (`SwiftMandarinShortcutsProvider.swift:48-56`), but `PhotoTranslateView.swift:827-832` only opens it on iOS and `CameraScannerView.swift:261-289` is an unavailable placeholder elsewhere.
- Vocabulary sort direction always says Oldest/Newest even for alphabetic/pinyin sorting (`VocabularyView.swift:149-165`, `:202-218`).
- Home’s “Practice this word” opens generic review rather than the displayed word (`HomeView.swift:283-308`, `:348-354`).

**Recommendation:** Add localization and platform-capability CI checks. Omit unavailable App Shortcuts per platform. Make labels describe the action actually performed. Dates should use the selected app locale, not only the system locale.

## App Intents and import/export details

These are narrower than the architectural work above but should be fixed as part of the same quality pass:

1. **Stable entities:** `Phrase` creates a fresh UUID in `PhrasesView.swift:247-255`, while `PhraseEntity` copies it and later rebuilds the static graph (`ShortcutEntities.swift:90-121`). Saved Shortcut references cannot resolve after relaunch. Use deterministic IDs and relaunch tests.
2. **Composable entities:** expose vocabulary/phrase fields with App Intents `@Property` and consider Spotlight/`IndexedEntity`, so Shortcut output can feed later actions.
3. **Real files on iOS:** `VocabularyView.swift:1502-1505` shares a string rather than a JSON/CSV file. Use `Transferable`/`FileDocument` with filename, UTType, format, and optional AI analysis. The unused `VocabularyExportDocument` at `VocabularyImportExportService.swift:518-528` always declares JSON and needs redesign.
4. **Documentation parity:** README claims TXT import/export (`README.md:154-165`, `:256-258`), but `VocabularyExportFormat` supports only JSON/CSV (`VocabularyImportExportService.swift:19-38`) and the `.plainText` picker path cannot parse TXT. Implement a specified format or remove the claim and picker type.
5. **Input limits:** clamp and declare the vocabulary lookup range, and limit screenshot file count, total bytes, decoded pixels, and output dimensions before MainActor decoding (`TranslateScreenshotsIntent.swift:55-75`, `:94-106`).
6. **Useful results:** Shortcut dialogs should include source/target, provider/off-device state, saved/duplicate/failed counts, and next actions such as Open Translator, Save, or Start Review.

## Recommended cohesive product architecture

The following design would eliminate multiple findings at once.

### 1. Translation coordinator

Create one coordinator used by Translate, Photo, live speech, screenshots, menu bar, Reader lookups, and App Intents.

```text
Input + explicit policy
  -> normalize and resolve direction
  -> choose a permitted capable backend
  -> execute with cancellation/retry
  -> validate outcome
  -> independently record activity and optional history
  -> return provider/privacy/timing metadata
```

The coordinator should not own UI presentation. It should expose typed progress and outcomes that each platform surface renders consistently.

### 2. Learning item plus provenance

Saved vocabulary needs durable context, not only a headword pair. Add provenance such as:

- source feature (`translation`, `photo`, `screenshot`, `reader`, `conversation`, `workbook`, `phrase`)
- source object ID and optional sentence/paragraph context
- direction and detected language
- first-seen and most-recent-seen dates
- related correction/grammar point/audio evidence
- privacy level controlling whether source text is retained

This supports a single Word Inspector and lets the learner return to the place where a word mattered.

### 3. Learning-event ledger

Use immutable typed events as the integration seam. Derive Home totals, streaks, Stats, weak skills, and recommendations instead of having each feature mutate a few counters. Keep events lightweight and separate private content from activity metadata.

### 4. One review inbox

Unify due vocabulary, workbook mistakes, conversation corrections, Reader unknown words, dictation misses, tone weaknesses, and generated questions in a “Today” session. The scheduler can still use different scoring rules per item type, but the user should have one next action.

### 5. One Word Inspector

Replace separate word-detail implementations in Ruby text, English text, Library, Phrases, and OCR. On iPhone it can be a sheet; on iPad/macOS it can be a persistent inspector. Include translation, pinyin/pronunciation, audio, save/mastery, source context, AI explanation, and next/previous navigation.

### 6. Capability and privacy center

Show per-feature provider routing, whether data leaves the device, whether an image was actually used, and the fallback chain. Allow distinct policies for text translation, vision/OCR cleanup, conversations, generation, and explanations. This is more useful than a provider list alone and prevents silent capability degradation.

## UI and information-architecture improvements

1. **Keep the five primary tabs, clarify their jobs.** Translate is immediate text/speech work; Photo is a Capture workspace; Study owns Review, Practice, Immerse, and Library; Stats is progress and next actions; More is settings/data/help.
2. **Make Capture modes explicit.** Replace workbook/scanner actions hidden in menus with a visible mode selector: Translate Image, Live Scanner, Screenshot Overlay, Grade Workbook. Show unavailable modes per platform instead of opening dead surfaces.
3. **Make Home a real next-best-action surface.** Recommend due review, a weak skill, unfinished Reader, or a conversation follow-up. The current recent-save chips should open the shared Word Inspector (`HomeView.swift:455-502`) rather than looking interactive but doing nothing.
4. **Make Stats actionable.** Tapping a day, skill, or weak area should open filtered History, Library, or the correct practice. Include Reader, Conversation, tone, dictation, OCR, and workbook activity once the event ledger exists.
5. **Unify translation actions.** The standard and AI buttons in `TranslateView.swift:404-490` and `:573-616` make engine selection dominate the workflow. Prefer one Translate action with a provider/backend chip, clear privacy status, and explainable fallback.
6. **Use adaptive layouts.** Prefer `ViewThatFits`, adaptive grids, and width-based breakpoints over device-idiom checks. Add persistent inspectors and sidebar detail on iPad/macOS where space allows.
7. **Add consistent setup states.** Reader, Conversation, word explanation, Workbook grading, and question generation all present different missing-AI messages. Use one capability-aware `AIAvailabilityCard` with Open Settings, exact missing capability, provider status, and retry.
8. **Add shared undo and error presentation.** Vocabulary, conversations, Reader documents, history, and workbook sessions should use the same undo/error model. Reserve confirmations for truly irreversible reset operations.

## High-value feature enhancements

These features build on existing assets instead of creating new disconnected silos.

### F-01 — Captured-to-learned workflow

Every translation, OCR block, Reader selection, conversation correction, and workbook miss should offer “Save key words and add to today’s practice.” Preserve the originating sentence/image/document link when the user opts in.

### F-02 — Conversation correction recap

At the end of a conversation, show corrected sentences, recurring grammar issues, pronunciation/listening opportunities, and actions to create cloze cards or a focused practice set. Feed outcomes back into the learning-event ledger.

### F-03 — Reader driven by the learner’s vocabulary

Generate or recommend texts using due/difficult words, show known/unknown coverage, and suggest a related conversation after reading. Cache coverage by document revision plus vocabulary revision; current synchronous recomputation in `ReaderStore.swift:133-165` should move off-main.

### F-04 — Workbook mistakes in FSRS

`WorkbookBank.swift:216-220` defines a mutator for the existing `timesReviewed` field (`:45-48`), but repository-wide search finds no caller, so review UI never updates the persisted count. Record answer/reveal outcomes and graduate worthwhile workbook questions into the same review inbox and scheduling engine used by vocabulary.

### F-05 — Pronunciation and shadowing practice

Combine existing TTS, speech recognition, tone-pair practice, and conversation scenarios into short shadowing sessions. Score transcript match, tone/pinyin targets where reliable, hesitation/retry count, and self-assessment without presenting probabilistic scores as clinical truth.

### F-06 — Personal learning search

Provide one search across vocabulary, phrases, translations, Reader documents, conversation corrections, workbook questions, and grammar points. Filters should include source, language direction, mastery, due status, and date.

### F-07 — Complete backup and optional sync

After the versioned backup model exists, add optional user-controlled sync (for example, CloudKit) with conflict rules and clear exclusions for credentials/private source images. Backup/restore should exist and be tested before sync.

### F-08 — Offline/readiness indicator

Show which operations are available now: Apple Translation installed languages, on-device speech availability, local Ollama reachability, configured cloud providers, vision capability, and network state. Do not wait until the user has completed a long input flow to reveal a missing backend.

### F-09 — Mac-native productivity

Add a reliable global hotkey only if the setting is implemented, Commands-menu equivalents, multiwindow Reader/Conversation, menu-bar recent translations, drag/drop with error reporting, and keyboard navigation. These should reuse shared routes and outcomes rather than add Mac-only state.

## Quality strategy

### Q-01 — Add test targets and CI before broadening the platform matrix

The Xcode project has no unit/UI test target, test plan, shared test scheme, or CI workflow. Start with deterministic, high-risk boundaries:

**Unit tests**

- FSRS scheduling, due/new selection, and migration
- language detection and resolved translation direction
- Pinyin conversion and Chinese/English segment joining
- JSON/CSV import, multiline/escaped fields, headerless data, validation errors, and complete-backup migration
- partial persistence recovery and backup preservation
- cloud URL construction, TLS policy, provider capabilities, image media types, and retry classification
- Keychain upsert failure behavior using an injected store
- App Intent entity ID stability and user-policy routing
- screenshot run identity, delimiter/cardinality failure, and overlap geometry at 1x/2x/3x
- AI response semantic validation and cache keys

**Integration/UI tests**

- selected/detected direction drives labels, TTS, history, and outcomes consistently
- history opt-out and cloud opt-out across UI, menu bar, and Shortcuts
- clear/dismiss/new-input cancellation for Photo, screenshots, speech, and Workbook
- deep links and one-stack navigation restoration
- language change during each active workflow without state loss
- export/import round trip and complete backup restore
- menu-bar reopen after all main windows are closed
- permissions deny/retry flows
- VoiceOver/manual review progression and accessibility-size layout

**CI matrix**

- iOS minimum deployment target
- current iOS Simulator
- current macOS
- visionOS only if it remains advertised
- Debug strict-concurrency checking, then incremental Swift 6 mode adoption
- localization missing-value/stale-key check
- privacy-manifest validation and archive privacy report
- Release archive entitlement diff, signing, architecture, and notarization checks
- dependency and secret scans

### Q-02 — Split the largest feature files around stateful operations

Several views/services are too large to review safely: `VocabularyView.swift` (~1,700 lines), `AIWordExplanationService.swift` (~1,580), `PhotoTranslateView.swift` (~1,470), `TranslateView.swift` (~1,300), and `StatsView.swift` (~1,100).

Do not split files only by visual section. Extract around stable responsibilities:

- coordinator/state machine
- persistence repository
- pure formatting/transformation
- reusable content view
- platform adapter

Keep one owner for each asynchronous operation and one source of truth for each piece of state.

### Q-03 — Move toward Swift 6 concurrency checking deliberately

The project uses a Swift 6.2-era toolchain but sets `SWIFT_VERSION = 5.0` in `project.pbxproj:362-365` and `:435-438`; audio frameworks are imported with `@preconcurrency` in `SpeechRecognitionService.swift:11-14`. Enable complete checking in Debug, resolve warnings module by module, add explicit `Sendable`/isolation boundaries, and only then switch language mode.

## Documentation and repository corrections

1. Current app version/build is 3.0/3 in the Xcode project, while the README and tracked DMG say 2.0.
2. README says “Ten Providers,” while the current code includes eleven, including Quotio.
3. README contains both FSRS and SM-2 descriptions; the current scheduler is FSRS-based.
4. README claims a direct App Store URL while `SwiftMandarin/AppConfig.swift:36-57` has no App Store ID and Rate/Share fall back to GitHub. Hide or relabel those actions until the actual ID exists.
5. README claims MIT licensing and links a license, but no `LICENSE` file exists. Add the actual license before public distribution.
6. README claims TXT import/export that is not implemented.
7. “Fully bilingual” should be enforced by a catalog/permission/Shortcut localization gate, not treated as an untested statement.
8. Clarify that Swift 6.2 is the toolchain while the project remains in Swift 5 language mode.

## Recommended implementation sequence

### Phase 0 — Release safety

1. Remove tracked transcripts/logs and scan history.
2. Add the privacy manifest and accurate/localized permission disclosures.
3. Fix Shortcut cloud/history policy and plaintext endpoint validation.
4. Remove visionOS support claims or make the target compile.
5. Minimize entitlements and establish signed/notarized Release artifacts.
6. Correct README/version/license/App Store claims.

### Phase 1 — Core trust and data integrity

1. Implement `ResolvedTranslationRequest`, `TranslationOutcome`, and one translation coordinator.
2. Add task ownership/run identity to screenshot, photo, speech, grading, and generation flows.
3. Fix Keychain upsert and partial-recovery backup handling.
4. Separate activity events from history retention.
5. Add the first unit/integration targets and CI gates alongside these fixes.

### Phase 2 — Cohesive learning system

1. Introduce learning item provenance and the event ledger.
2. Unify navigation, routes, and Word Inspector.
3. Build the Today/Review inbox across feature types.
4. Make Stats and Home derive actionable recommendations from events.
5. Create complete backup/restore and migrate growing stores.

### Phase 3 — UI quality and differentiated features

1. Accessibility and responsive-layout pass.
2. Capture workspace and consistent capability/error/setup states.
3. Reader-to-conversation and conversation-to-practice loops.
4. Pronunciation/shadowing, universal learning search, optional sync, and Mac productivity.

## Previously reported concerns that are no longer current

The following older concerns were explicitly rechecked and should not be carried forward as open bugs:

- Home is now the default landing surface and iOS has a coherent five-tab shell.
- FSRS scheduling is live, persisted, and used for due/new sessions; it is not a dead SM-2 path.
- The speech audio tap now copies/converts buffers synchronously rather than reusing unsafe buffers (`SpeechRecognitionService.swift:439-487`).
- OCR runs Vision off the MainActor and honors image orientation (`PhotoTextRecognitionService.swift:244-306`).
- Screenshot pixel indexing uses the rendered-buffer stride (`ScreenshotStitchingService.swift:296-309`, `:361-388`).
- Multiline quoted CSV records are parsed across physical lines (`VocabularyImportExportService.swift:301-308`, `:354-389`).
- Ollama model IDs are guarded rather than force-unwrapped.
- OpenAI reasoning models omit unsupported temperature and use the appropriate token field.
- AI explanation cache keys and requests account for direction.
- `showInMenuBar` and maximum history size have real consumers.
- Several destructive History/Settings flows already use confirmation.
- Celebration animation already respects Reduce Motion.

## Definition of done for the next audit

A follow-up audit should be able to demonstrate all of the following with artifacts:

- Every advertised platform builds in CI.
- A signed/notarized Release archive has a reviewed minimal entitlement set and bundled privacy manifest.
- Cloud/history choices are honored by every entry point.
- Translation labels, speech, history, and backend metadata share one resolved direction/outcome.
- Clearing, dismissing, or replacing input prevents stale async work from mutating state.
- Activity and statistics include all major learning modes independently of history retention.
- Every exposed setting has a tested consumer.
- Critical persistence/import/export and App Intent behavior has automated regression coverage.
- VoiceOver, Dynamic Type, Reduce Motion, iPad split view, and narrow macOS layouts have recorded acceptance results.
- Documentation, package version, license, supported platforms, and distribution artifacts agree with the shipped product.
