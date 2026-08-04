# Handoff.md — SwiftMandarin: Bilingual + Multi-Provider AI Overhaul

**Last Updated (UTC):** 2026-07-27
**Status:** In Progress (iter 28 — translation study notes, transcription repair, AI transcription; see Iteration 28)
**Prior Status:** In Progress (iter 27 — structured AI translation output; see Iteration 27)
**Prior Status:** In Progress (iter 16 — step-change overhaul on branch `jul-07-2026-step-change-overhaul`: RECOMMENDATIONS.md + Home dashboard + FSRS + Reader + AI conversation + UI overhaul)
**Current Focus (latest):** Photo-tab workbook expansion — direct camera capture, a review-question **database** (bank), AI **review-question generation**, **grading history** with the original scanned photos, **analytics** integration (graded questions in the contribution heatmap), and a decluttered **More** tab. Plus a 43-agent codebase audit written to `EXECPLAN2.md` (132 findings, 23 confirmed). See Updates iter 11.
**Prior Focus:** Interface-language-driven tailoring: when the UI is 中文 the user is treated as a native Mandarin speaker learning English (AI explanations written in Mandarin; saved words show ENGLISH as the big headline with Mandarin small; English TTS emphasis) and vice versa for English UI. Full audit + plan: docs/language-direction-audit.md (11-agent parallel map + completeness critic, 2026-06-13).
**Prior Focus:** Full-app audit + overhaul: 18 verified bug fixes, integration wins (unified history/stats, pinyin position, provider test connection), zero-warning builds, bilingual READMEs — see Updates iter 8 (2026-06-10).
**Prior Focus:** Full UI localization (English ⇄ 中文) with a runtime in-app language toggle — see Updates iter 5 (2026-06-07).
**Prior Focus:** Four-part overhaul — (A) fix photo OCR Chinese gibberish/language lock, (B) multi-provider cloud AI with API-fetched model lists, (C) photo→AI cleanup toggle, (D) make the app fully bilingual (dual narration + learner-mode toggle).

## 1) Request & Context
- **A — Photo OCR bug:** Photo upload "often produces gibberish," "cannot switch languages," "stuck on detecting English, can't read Mandarin."
- **B — Provider expansion:** Add OpenAI, Claude (Anthropic), Deepseek, Doubao, Qwen, Kimi, Zhipu, Minimax. Pull each provider's available models via API.
- **C — Deep AI integration:** A settings toggle that routes an uploaded photo to an AI model for cleanup/structuring, returning cleaned text into the app.
- **D — Bilingual:** App must serve English-speakers-learning-Mandarin AND Mandarin-speakers-learning-English (and both). Add English narration alongside Mandarin for the selected word, and a settings toggle that flips the app between English-centric and Mandarin-centric, adapting features.

**Environment:** Xcode 26.3, iOS/macOS/visionOS **26.2** deploy targets, Swift 5 mode, single target `SwiftMandarin`, sandboxed (`ENABLE_APP_SANDBOX=YES`), generated Info.plist. One SPM dep: `ollama-swift 1.8.0`. State = `@Observable @MainActor` singletons over UserDefaults JSON. No Keychain, no network entitlement yet.

## 2) Verified Root Causes (from full-codebase read + 9-agent comprehension workflow)
**A (compounding 4-stage failure):**
1. `PhotoTextRecognitionService.swift:204` — `recognitionLanguages = ["en-US","en-GB","zh-Hans","zh-Hant"]` English-first; `automaticallyDetectsLanguage` never set; no per-call override → genuinely "cannot switch languages."
2. `:207` — `usesLanguageCorrection = true` unconditionally → English autocorrect mangles Chinese into Latin gibberish.
3. `:45-72` (+ dup in `PhotoTranslateView:601`, `CameraScannerView:123`) — English-centric cleaner joins with spaces / English punctuation regex → corrupts spaceless Chinese.
4. `PhotoTranslateView:573-598` — language detection runs AFTER OCR on already-garbled text; non-Chinese falls back to English; `TextRecognitionResult.language` hardwired `nil`.
Secondary: `CameraScannerView:40` `.text()` no language hint; `VNImageRequestHandler` ignores orientation; `Character.isChineseCharacter` misses ranges.

**B:** `AIProvider` enum has only `.appleIntelligence`/`.ollama`; `AIModelSettings` Ollama-shaped, no API key storage; `OllamaService` (third-party `Ollama.Client`) can't reach cloud (hardcoded `/api/*`, no auth header). Exhaustive switches at `AIModelSettings:124,134`, `AIWordExplanationService:395,411`, `MacOSSettingsView:280`, `MoreView:471`; availability hardcoded in `ShortcutHelpers:95`, `AIWordExplanationView:27`.

**C:** Seam = `PhotoTranslateView.loadAndProcessImage` between `recognizeText(from:)` (`:508`) and `sourceText = result.cleanedText` (`:512`). No toggle, no image-capable provider today.

**D:** Narration single-language (`WordDetailPopover:272` Chinese only; `EnglishWordDetailSheet:184` English only). No learner-mode concept; defaults hardcoded English-first (`TranslationDirection`, `TranslationState`).

## 3) Plan & Decomposition
**Group 1 — Foundations:** entitlements network.client; `KeychainHelper`; `AppPreferences` (LearnerMode, PhotoScanLanguage, dualNarration); extend `AIProvider` + per-provider metadata + per-provider config/keys in `AIModelSettings` (generalized switches via `default:`); `CloudAIService` (URLSession; OpenAI-compatible + Anthropic; listModels w/ fallback; chat; vision; translate).
**Group 2 — OCR (A):** robust CJK-ratio-first detector + widened CJK in `ChineseTextAnalyzer`; parameterized recognition + Chinese-aware clean + language populated + orientation in `PhotoTextRecognitionService`; `.text(languages:)` in `CameraScannerView`; scan-language override UI + AI-cleanup hook + Chinese-aware processing in `PhotoTranslateView`.
**Group 3 — AI routing (B/C):** cloud dispatch + `cleanupRecognizedText` + tolerant JSON in `AIWordExplanationService`; cloud availability in `ShortcutHelpers`, `AIWordExplanationView`.
**Group 4 — Settings UI (B/C/D):** shared `AIProviderConfigView`; wire into `MacOSSettingsView` + `MoreView`; add learner-mode + photo-cleanup toggles.
**Group 5 — Narration (D):** dual narration in `WordDetailPopover` + `EnglishWordDetailSheet`.

## 4) Requirements → Acceptance Checks
| Req | Check | Evidence |
|---|---|---|
| A | Scan Chinese textbook → Chinese chars recognized, not gibberish; manual 中文/English/Auto switch works | macOS build + manual |
| B | Settings shows 10 providers; entering key + Refresh lists models from API | build + manual |
| C | Toggle ON → photo OCR text cleaned by AI before display | build + manual |
| D | Word detail shows both 朗读中文 + Read English; learner-mode toggle flips defaults | build + manual |
| All | `xcodebuild` macOS Debug succeeds, zero errors | pending |

## 5) Decisions
- Cloud clients via **URLSession** (no new SPM deps). All Chinese providers are OpenAI-compatible; Anthropic uses `/v1/messages` + `x-api-key`.
- API keys in **Keychain** (generic password), never UserDefaults.
- Exhaustive `AIProvider` switches converted to use `default:` (cloud) so future providers don't break compilation.
- `live model list` falls back to curated `defaultModels` per provider when the `/models` endpoint is absent/blocked.
- Learner mode adjusts defaults (direction, scan language) and is additive — never removes capability; dual narration always offered when both languages available.

## 6) Progress Ledger
- [x] G1 foundations — entitlements `network.client`; `KeychainHelper`; `AppPreferences`; extended `AIProvider` (10 providers) + per-provider keys/models in `AIModelSettings`; `CloudAIService` (URLSession, OpenAI + Anthropic, vision, model listing).
- [x] G2 OCR (A) — robust CJK-ratio detector + widened CJK in `ChineseTextAnalyzer`; parameterized recognition language + Chinese-aware cleaning + language carried + EXIF orientation in `PhotoTextRecognitionService`; `.text(languages:)` + language-aware cleaning in `CameraScannerView`; scan-language menu + "重新识别" + AI-cleanup hook + Chinese-aware processing in `PhotoTranslateView`.
- [x] G3 AI routing (B/C) — cloud dispatch + `generateExplanationWithCloud` + `cleanupRecognizedText` + tolerant JSON in `AIWordExplanationService`; `isAnyProviderAvailable` in `ShortcutHelpers` + `AIWordExplanationView`.
- [x] G4 settings UI (B/C/D) — shared `AIProviderConfigView`; wired into macOS `AISettingsTab` + iOS `AISettingsDetailView`; generalized `statusColor` switches (`default:` cloud); learner-mode + dual-narration sections; AI-photo-cleanup toggles.
- [x] G5 narration (D) — dual-language narration in `WordDetailPopover` (中文 + EN) and `EnglishWordDetailSheet` (English + 中文).
- [x] build green — macOS Debug ✅, iOS Simulator Debug ✅ (only 2 pre-existing warnings). Logic check: 9/9 detector+cleaning assertions pass.

## 8) Verification Summary
- `xcodebuild -scheme SwiftMandarin -destination 'platform=macOS' -configuration Debug` → **BUILD SUCCEEDED**.
- `xcodebuild ... -destination 'generic/platform=iOS Simulator' ...` → **BUILD SUCCEEDED**.
- Standalone Swift check of `detectLanguageRobust` + Chinese whitespace cleaning: **9/9 passed** (pure/traditional/mixed Chinese → chinese; English/English-dominant → english; despacing preserves Latin spaces).
- Learner-mode → direction wiring confirmed via `TranslateView.applyDefaultDirectionIfNeeded()` reading the `defaultDirection` UserDefaults key updated by `LearnerMode.didSet`.
- Not yet runtime-tested with a live cloud API key or a real Chinese photo (requires user secrets / GUI). Behavior reasoned + compile-verified.

## 10) Updates
- 2026-06-15 (iter 11 — Photo-tab workbook suite, analytics, More declutter, full audit): Implemented a cohesive workbook study loop inside the **Photo tab** (entry points in its toolbar `Menu` under a *Workbook* section: Grade Workbook / Review Bank / Grading History) plus an app-wide audit. **New data layer** (`Models/WorkbookBank.swift`): `WorkbookQuestion` (Codable, tolerant `init(from:)`), `WorkbookQuestionBankStore` (`@Observable @MainActor`, content-dedup, newest-first, `PersistentCodableStore` key `workbookQuestionBank`); `GradedSession` + `WorkbookGradingHistoryStore` (key `workbookGradingHistory`); and `WorkbookImageStore` — a **file-backed** image store under `Application Support/WorkbookImages/` (scanned photos are too large for UserDefaults JSON, so only file IDs persist in JSON; deleting a session deletes its photos; all methods nonisolated, called off-main). **Camera capture** (`Views/Components/CameraImagePicker.swift`): `UIImagePickerController(.camera)` wrapper → JPEG `Data` (iOS-only; macOS stub). `WorkbookGradingView` upload sections gained a prominent **拍照 · Camera** button shown only when `CameraImagePicker.isAvailable` (hidden on macOS/Simulator via `cameraAction(for:)` returning nil → `.fullScreenCover`); captured images flow through the existing `downscaledJPEG`. **Grade flow** now snapshots inputs, saves the original scans to disk in a detached Task (off-main), then on MainActor builds a `GradedSession`, `WorkbookGradingHistoryStore.shared.add`, and `LearningActivityStore.shared.recordQuestionsGraded(count)`; results show a *Saved to grading history* note. Per-question **加入题库 · Add to Bank** + results **全部加入题库 · Add all** (uses content-dedup; `isInBank` reflects prior saves). **Bank UI** (`Views/WorkbookQuestionBankView.swift`): filter (All/Workbook/Generated), read-aloud, swipe-delete (filter→store id mapping), clear-all; **Generator** (`ReviewQuestionGeneratorView`): count stepper + subject tag + custom instructions → `AIWordExplanationService.generateReviewQuestions(from:count:customInstructions:)` (new; native/learning-language aware, prioritizes wrong/vocab items, tolerant JSON + repair retry, routes Apple Intelligence/Ollama/cloud text model), generated cards with reveal-answer/read-aloud/save(+all). **History UI** (`Views/WorkbookGradingHistoryView.swift`): session list (score ring, date, photo count) → `GradedSessionDetailView` (score, summary, original photos in a horizontal scroll → `fullScreenCoverCompat` viewer that's `.fullScreenCover` on iOS / `.sheet` on macOS, read-only graded cards, add-all-to-bank); async image load via `Task.detached { WorkbookImageStore.load }` then decode on MainActor (Sendable-safe). **Analytics** (`Models/LearningActivity.swift`): `DailyActivity.questionsGraded` with a **tolerant custom `init(from:)`** (CodingKeys + `decodeIfPresent` defaults) so older saved heatmap payloads don't `keyNotFound`-wipe — directly mitigates audit issue #1; `activityScore += questionsGraded`; `recordQuestionsGraded(_:)` + `totalQuestionsGraded`; `StatsView` per-day heatmap detail shows a graded-questions count and the Overview grid gains a **Questions Graded** tile. **More declutter** (`Views/MoreView.swift` rewritten): compact header + **Quick Setup** (language + learner mode) + Settings split into focused screens (`GeneralSettingsView`/`AISettingsDetailView`/`TranslationSettingsView`/`DisplaySettingsView`/`DataManagementView`) instead of one long form; removed the **redundant** in-More `HistoryView`/`HistoryRow` (the History tab is canonical) — resolves audit quick-win #4. **Localization**: workbook UI uses bilingual literals (`中文 · English`); added 4 catalog keys with `zh-Hans` (`Questions Graded`/`Display & Pinyin`/`Quick Setup`/`About & Support`) via a text-insertion script preserving Xcode's format, re-validated as JSON (625 keys). **Audit → `EXECPLAN2.md`**: a 43-agent workflow (13 subsystem finders → adversarial verification → synthesis) produced **132 findings** (29 high/54 medium/49 low), **23 confirmed**, **6 refuted**, **86 suggestions**, plus architecture/workflow recommendations. Notable confirmed P0s documented (NOT fixed this session — outside the feature scope, risky without runtime tests): history records the UI-toggle direction not the detected one (`TranslateView`), audio tap captures a non-Sendable `AVAudioPCMBuffer` per-buffer Task + converter re-feeds the same buffer, schema-evolution data-loss across all stores, iOS-17 8-tab system-More collision, screenshot-stitch `bytesPerRow` mismatch, CSV multiline round-trip loss, SR scheduling dead code. **Verification**: `xcodebuild` macOS Debug ✅ and iOS-Simulator Debug ✅ — zero errors (both). Then a 2-phase adversarial review workflow over the diff. NOTE: new `.swift` files auto-included via the synchronized file group (no pbxproj edits); `grep -c "in Sources" project.pbxproj` should stay 0. NOTE: the new workbook features are intentionally Photo-tab-only per the request; analytics is the one cross-tab touchpoint (Stats), also per the request.
- 2026-06-13 (iter 10 — native-language tailoring by interface language): The interface language now doubles as the user's NATIVE language and re-orients the whole app: 中文 UI → native Mandarin speaker learning English (AI explanations written in 简体中文; saved words / phrases / flashcards / popovers show the ENGLISH side as the big headline with the Mandarin gloss small; pinyin hidden — it's a learner aid, not native furniture; TTS leads with English); English UI → the historic English-speaker-learning-Chinese behavior, unchanged. Audit: 11-agent parallel map + completeness critic over all 19.6k lines → docs/language-direction-audit.md (findings incl. critic-caught gaps: Ollama/cloud prompt paths, missing LocalizationManager↔learnerMode link, Chinese-POS stats breakage; plus deliberate rejections — `Text("…")` literals already localize via catalog, CSV column swap would break import round-trips). **Core abstraction:** `LocalizationManager.nativeIsChinese`/`learningIsChinese` + `AppLanguage.persisted` (nonisolated snapshot for App Intents); language toggle now syncs `AppPreferences.learnerMode` (and first-launch learnerMode derives from UI language); `SavedTerm.chineseSide/englishSide/headlineText/glossText/showsPinyin` — sides are CONTENT-DETECTED (`String.containsCJK`, new in ChineseTextAnalyzer.swift) because the `chinese` headword field can hold English (photo/grading flows); `SpeechService.speakAuto` picks the voice by content. **AI explanations (all 3 provider paths):** `ExplanationDirection` (wordIsChinese from content, explainInChinese from UI language, cacheToken so language toggles never serve stale cross-language cache); FoundationModels @Generable structs re-guided direction-neutral (ExampleSentence.sentence/pinyin/translation, RelatedWord.word, Collocation.phrase); Ollama schema + cloud JSON instructions parameterized; decoder accepts new keys with legacy chinese/english fallback; example/collocation word-filtering now checks the right field; `extractVocabulary` meanings in the user's native language; `gradeWorkbook` explanations/summary in native language, fullSentence/vocab term in the learning language (`spokenEnglish`→`spokenSentence`, spoken via speakAuto). **UI:** VocabularyView row/sheet/inspector headline-swap + conditional pinyin + direction-aware translate-fetch (translate(headword, sourceIsChinese: headword.containsCJK)) + alphabetical sort on the visible headword + "headword font size" labels; AIWordExplanationView renders sentence/pinyin-if-any/translation + per-example speakAuto button; LearnView flashcards quiz the learning language on the front (incl. saved-term side mapping); PhrasesView rows/detail flip + localized category headers (LocalizedStringKey(category.name) — keys existed); WordDetailPopover headline/definition/TTS-order/copy flip; EnglishWordDetailSheet inverts for English UI (Chinese headline + pinyin, Mandarin TTS first); TranslateView showEnglishFirst forced in 中文 UI; HistoryTabView rows learning-language-first (entry extension with direction-derived sides); TranslatedScreenshotOverlayView speakAuto. **Storage:** workbook `saveVocabItem` and photo `saveExtractedVocab` now key the saved entry on the LEARNING-language term (was: forced-Chinese headword — backwards for 中文 users and silently DROPPED English-passage items lacking CJK; English terms no longer translated-to-Chinese just to make a key); `ScreenshotTranslationStore.targetLanguage` defaults to the native language (set in init — comprehension aid). **Intents:** SavedTermEntity/PhraseEntity display titles = learning-language side (via AppLanguage.persisted, content-detected); GetRandomPhraseIntent speaks/copies the learning side; GetLearningStatsIntent labels localized (4 new %lld keys); TranslateScreenshotsIntent gained `.appLanguage` default target case. **Guards:** PartOfSpeechCategory.categorize matches Chinese POS labels (名词/动词/形容词/副词/代词/介词/连词/叹词/量词/助词 + traditional variants, compounds checked first) so Mandarin AI output doesn't bucket to "Other" in Stats; TranslationDirection.placeholder localized. **Catalog:** +11 keys with zh-Hans (612 total): Read the full sentence aloud, headword font size ×2, stats ×4, Enter English text…/输入中文… (en), Translate into your native language, screenshots-target description. NOTE (recurring): Xcode re-added ~105 duplicate Sources entries to pbxproj while open — reverted via git checkout; check `grep -c "in Sources" project.pbxproj` (should be 0) before committing. `IPHONEOS_DEPLOYMENT_TARGET` 26.2 → **17.0** (macOS/visionOS stay 26.2); both platforms build with zero errors/warnings. Strategy: compiler-driven (lower target → fix every availability error) + targeted runtime fallbacks, then a 30-agent adversarial review (13 confirmed / 13 refuted) over the diff. **API availability map learned:** `.translationTask` + `TranslationSession.Configuration` = iOS 18/macOS 15; the standalone `TranslationSession(installedSource:target:)` init = **iOS 26/macOS 26** (not 18!); SpeechAnalyzer/SpeechTranscriber/AssetInventory + FoundationModels + Liquid Glass (`.glass`, `.glassEffect`) = 26; `Tab` builder + `.sidebarAdaptable` + typed `supportedContentTypes` @Parameter = 18; SF Symbol `character.book.closed.fill.zh` = 18 (replaced with `character.book.closed.fill`). **Mechanisms:** (1) `Views/Components/CompatModifiers.swift` — `glassEffectCompat/glassEffectCapsuleCompat/glassButtonStyleCompat` (material/.bordered fallbacks) + `TranslationConfigurationBox` (version-counted `Any?` box because iOS-18-only types can't be stored properties at target 17) + `TranslationTaskHost` (@available 18, mounted via `.background { if #available }`, owns `.translationTask`; identity is stable because the availability condition is constant — and a ViewModifier alternative can't compile since its closure type would name `TranslationSession`). (2) TranslateView/PhotoTranslateView/LiveSpeechTranslationView: box + host + `guard #available` in `triggerTranslation()` with AI-provider fallbacks (`startAITranslation()` tracked task; `translateSentencesWithAIFallback()` per-sentence tolerant, partial-history; `performAIFallbackTranslation` reuses debounce task slot) — all fallback tasks cancel-before-replace and in clearAll(). (3) `SpeechRecognitionService` rewritten around a private `SpeechRecognitionEngine` protocol: `ModernSpeechEngine` (@available 26, the old SpeechAnalyzer code) + `LegacySpeechEngine` (SFSpeechRecognizer, cumulative partials → single final on stop with 300 ms endAudio grace, `isFinal`-beats-error rule, on-device preferred but server fallback possible for zh on old hardware — documented). Public API unchanged. (4) Services (`WordTranslationService`, `ScreenshotTranslationStore.translateText`, `ShortcutHelpers.translateWithRetry`) gate on 26 → `translateWithProvider` fallback, which now throws an actionable localized "configure an AI provider" error when nothing is configured. (5) FoundationModels: `@available(26)` on @Generable structs + `guard #available` in all LanguageModelSession paths. (6) ContentView: iOS 18 `Tab`+sidebarAdaptable vs iOS 17 classic `.tabItem`/.tag (8 tabs → system More overflow). (7) `TranslateScreenshotsIntent` images param dropped supportedContentTypes (typed variant is 18-only, legacy variant deprecation-warns on macOS). (8) About screen text/icon updated; 3 new catalog keys (zh-Hans). READMEs: requirements iOS 17+, per-version feature matrix (EN+zh). **iOS-17 user model:** translation features all work via configured AI provider (clear error guiding to Settings → AI otherwise); 18–25 get Apple translation in the three main views but AI fallback for word-taps/screenshot/Shortcuts (standalone session init is 26-only); 26+ unchanged. NOTE: only the iOS 26.3 simulator runtime is installed locally — the port is compile-verified at target 17 but not runtime-tested on an iOS 17 device/simulator. Also: Xcode (open during the session) re-added 4 duplicate Sources entries to the pbxproj; removed again — close Xcode or re-check `grep "in Sources" project.pbxproj` before committing pbxproj changes.
- 2026-06-10 (iter 8 — full audit + ship-ready overhaul): Ran a 58-agent audit workflow (12 subsystem/dimension finders → 45 adversarial verifications → synthesis): 113 raw findings, 18 confirmed bugs, 27 refuted. **Bug fixes:** (1) `gradeWorkbook` no longer silently returns "0/0" — decoded-but-empty results now throw a localized, actionable error; (2) `cleanupRecognizedText` returns `String?` (nil = no usable provider) and `PhotoTranslateView` shows an orange notice when cleanup was skipped/failed plus a purple "AI cleaned" badge with one-tap **Use original text** revert (raw OCR kept in `rawOCRText`); (3) `SpeechRecognitionService.stopRecording()` made idempotent (`wasRecording` guard) and called from BOTH error paths — recognition-stream failure and `audioEngine.start()` throw — so the mic tap/audio session can no longer leak after a mid-session failure; `!Task.isCancelled` guard prevents normal-stop cancellation from being reported as failure; (4) `TextRecognitionResult` honors an explicit user scan language (中文/English) instead of always re-detecting — auto-detect only for auto/bilingual; (5) PhotoTranslateView onChange Tasks stored + cancel-before-replace + `Task.isCancelled` checks (no more stale-result races on rapid photo swaps); clearAll cancels both; (6) all four UserDefaults JSON stores (terms/history/progress/activity) now load/save via new `Models/PersistentCodableStore.swift` — decode failures are os.log'd, a last-known-good snapshot lives at `<key>.backup`, restore promotes the backup (no more silent data wipes); (7) `DailyActivity` date keys use a cached `en_US_POSIX` + Gregorian formatter (was locale-sensitive → corrupt keys on non-Gregorian/localized-digit locales; local-time day boundary deliberately kept — no data migration needed); `LearningProgressStore.recordReview` rolls the daily counter past midnight; (8) `SavedTermsStore` dedup/contains normalize zero-width chars (U+200B/C/D, FEFF) + trim; `update()` returns Bool, both VocabularyView callers guard on it; (9) `PinyinConverter.convert` returns "" for non-CJK input (English grading vocab no longer shows fake "pinyin" echo); (10) live-speech "Use Translation" now passes (transcript, translation) — TranslateView sets BOTH sides via `preserveCurrentTranslationDuringSourceUpdate` and records history via `handleCompletedTranslation`; (11) TranslateView AI-progress text shows the actual provider (was hardcoded "Apple Intelligence"); mic button got accessibilityLabel + .help; (12) qwen3-vl-plus typo fixed; Anthropic default models reordered newest-first (sonnet-4-6 default, vision default claude-sonnet-4-6); (13) dead code removed: `Item.swift` (SwiftData template), unused `AppTab.title`. **Project-file surgery (the hidden build-breaker):** session hook logs had been committed under `SwiftMandarin/logs/` and a second session folder collided in CpResource ("Multiple commands produce post_tool_use.json") — untracked via `git update-index --force-remove`, moved out, gitignored (`SwiftMandarin/logs/`), AND a `PBXFileSystemSynchronizedBuildFileExceptionSet` (id A7C0FFEE…01) now excludes `logs` + `MandarinKit.md` from the target. Also emptied the Sources phase of 149 duplicate legacy entries (sync group supplies all sources; kills 28 "Skipping duplicate build file" warnings), removed 43 legacy SOURCE_ROOT file refs + their group children, dropped `handoff.md in Resources` (dev log no longer ships in the app bundle); pbxproj 67KB→19KB. **Zero-warning hygiene:** filled `INFOPLIST_KEY_NSMicrophoneUsageDescription`/`NSSpeechRecognitionUsageDescription` (were empty strings — latent iOS crash); removed 5 spurious `try await` on non-throwing `TranslationSession(installedSource:target:)` inits; `supportedContentTypes: [.image]` (+ UniformTypeIdentifiers import) replaces deprecated `supportedTypeIdentifiers`; `@preconcurrency import AVFAudio`; StatsView pieChartsRow per-platform layout (no never-executed branch); `_ =` on Set.insert in WorkbookGradingView; var→let ×3. **Integration/features:** photo translations (both directions) write `TranslationHistoryStore` (gated on `saveToHistoryAutomatically`; add() already records stats activity) — so History + heatmap now count photo & speech work; HistoryTabView gained a direction filter (toolbar menu, EN→中/中→EN), a "No Matches" empty state with Clear Filter, and a clear-all `confirmationDialog`; `AIProviderConfigView` gained per-provider **Test Connection** (tiny round-trip chat, green/red result row) + Vision/JSON-mode capability badges + a footer explaining vision fallback; the dead `pinyinPosition` setting is now real — `RubyWordView` renders above/below/inline and honors `showPinyin`/`toneColors`, `PunctuationView` ghost-aligns correspondingly, and iOS Settings gained the same Picker (was macOS-only); `TranslationDirection.source/targetLanguageName` localize via `String(localized:)` ("English"/"Chinese" keys); EnglishTextAnalyzer's 15 grammar-point strings localized (en keys + zh values, previously hardcoded Chinese); all 6 workbook-grading error strings wrapped in `String(localized:)`. **Catalog:** +47 keys with reviewed zh-Hans values (608 total; script-verified: 0 existing keys altered, 0 placeholder mismatches, 0 alpha keys missing zh-Hans). NOTE: CLI `xcodebuild` does NOT auto-extract new literals into .xcstrings — new user-facing strings must be added to the catalog manually (the +47 were). Catalog was re-sorted by Python's key sort (Xcode may cosmetically re-sort on next GUI save; content verified intact). **Docs:** README.md updated (new features, EN⇄中文 switcher links) + new full `README.zh-Hans.md`. **Verification:** macOS + iOS Simulator Debug builds — BUILD SUCCEEDED, **zero errors, zero warnings** (previously ~15). A second adversarial review workflow (27 agents) ran over the final diff before commit: 9 confirmed / 14 refuted; applied — isProcessing cleared on every cancelled early-return in processImageData + processText cancellation guards; symmetric photo/text task cancellation; `stopRecording(notifyDelegate:)` so didFinish is suppressed after didFail; `remove(chinese:)` uses normalizedKey. Declined (with reasons) — "rawOCRText should be fullText" (cleanedText IS the correct no-AI baseline for revert; comment clarified), init-time redundant save() (pre-existing, harmless), todayReviewedCount backup (ephemeral daily counter), ZWJ-dedup-blocks-legit-variants (intentional OCR-noise prevention); README "100%" softened to "fully bilingual" (6 remaining keys are pure format strings). Audit-refuted claims worth remembering: the "466 missing English translations" claim is FALSE (en is the source language — keys ARE the English), saved terms DO flow into Learn (vocabularyCards derives live from SavedTermsStore), WorkbookGradingView sheet IS `.localizedSurface()`-wrapped.
- 2026-06-04: Created. Full codebase read + 9-agent comprehension workflow; root causes verified; plan set.
- 2026-06-04: Implemented all five groups. Both platforms build green; detector logic verified 9/9. Committed + pushed to origin/april-14-2026-ollama (4981a25).
- 2026-06-04 (iter 3 — Workbook Grading): New tucked-away feature in the Photo tab. `CloudAIService.chat` now accepts multiple images. `AIWordExplanationService.gradeWorkbook(workbookImages:answerImages:customInstructions:)` picks a vision-capable provider, sends all images + a grading system prompt (plus optional custom instructions), and returns a structured `GradingResult` (`score`, `summary`, per-question `GradedQuestion` with correct/incorrect + `vocab` for wrong answers). New `WorkbookGradingView`: two multi-image PhotosPickers (workbook / answers), custom-prompt field, grade button (gated on a vision provider), per-question ✓/✗ cards, and save-wrong-vocab (per-item + all) to the vocab book. Images downscaled via ImageIO. Entry point = Photo tab toolbar menu. Both platforms build green; grading JSON decode verified 7/7.
- 2026-06-06 (iter 4 — brand icons + single-line labels): Replaced SF-Symbol AI-provider glyphs with real brand marks. Added 10 vector SVG imagesets to `Assets.xcassets` named `brand-<provider.rawValue>` (apple, ollama, openai → monochrome `template-rendering-intent`; anthropic=claude-color, deepseek, doubao=volcengine-color, qwen, kimi, zhipu=chatglm-color, minimax → full-color `original`), each with `preserves-vector-representation`. New `AIProvider.brandAssetName` + `brandAssetIsMonochrome` (in `AIModelSettings.swift`). New shared `ProviderIcon` view (`Views/Components/ProviderIcon.swift`) renders the asset (color marks `.original`, mono marks `.template` so they adopt fg/tint and adapt to light/dark) and falls back to the SF Symbol via `UIImage/NSImage(named:)` existence check. Rewired every provider-icon site: `MacOSSettingsView`, `MoreView` (provider list), `TranslateView` (3 AI buttons), `AIWordExplanationView` (generate button, badge header, quick button) — removed now-dead `currentProviderIcon`/`providerIcon` string props. Verified via `assetutil` that all 10 compiled into `Assets.car` with vectors preserved and correct template modes (apple=template, qwen=original). Second fix: new `.fitSingleLine(_:)` View modifier (`Views/Components/SingleLineFit.swift` = `lineLimit(1)` + `minimumScaleFactor(0.7)` + `truncationMode(.tail)`) applied to 17 wrap-prone iOS labels (bilingual provider-name buttons, long Chinese action buttons like 保存所有错题词汇到词汇本, the photo scan-language menu label, provider list/detail rows, API-key section header) so they shrink-to-fit one line then ellipsize instead of wrapping. Both platforms build green (macOS + iOS Simulator, BUILD SUCCEEDED, 0 errors).
- 2026-06-07 (iter 7 — fix: modal/sheet surfaces were not localized): User reported the workbook grading interface stayed in English even with the app language set to Mandarin. Root cause: SwiftUI `.sheet`/`.fullScreenCover`/`.popover` content is hosted in a fresh context that does NOT inherit the root window's `\.locale` environment, so the chosen app language never reached presented surfaces. Fix: new `.localizedSurface()` View modifier (`LocalizationManager.swift` = `.environment(\.locale, loc.locale)` + `.id(loc.language)`) applied to the root view inside ALL 16 modal presentation closures (PhotoTranslateView ×5 incl. the workbook grader, TranslateView ×3, VocabularyView ×4, LiveSpeechTranslationView ×2, PhrasesView ×1, LearnView ×1). Also fixed the grader's two `uploadSection` headers, which were passed through a `String` parameter (verbatim, never localized) — the parameter is now `LocalizedStringKey` and the bilingual keys "作业页面 · Workbook pages" / "单独答案（可选）· Separate answers (optional)" were added to the catalog (en/zh split). (The grade button's ternary already resolved to a `LocalizedStringKey` and localized fine.) Catalog: 559 keys, 0 gaps, 0 placeholder errors. Both platforms build green. NOTE for future work: any new sheet/popover must apply `.localizedSurface()` to its content.
- 2026-06-07 (iter 6 — workbook grader: English read-aloud + richer wrong-answer vocab): Three enhancements to `WorkbookGradingView` / `gradeWorkbook`. (1) **Read the full English sentence per question:** `GradedQuestion` gained a `fullSentence: String` field (tolerant decode, defaults "") plus a `spokenEnglish` computed fallback (full sentence → else question + correct answer). The grading system prompt now asks the model for `fullSentence` (a clean, speakable complete English sentence — fill-in-the-blanks filled in) and the JSON shape includes it. Each `GradedQuestionCard` shows a "Full sentence" row with an inline speaker button (and a fallback speaker in the header when no full sentence was returned) that calls `SpeechService.speakEnglish(...)`. (2) **Where wrong answers are saved:** they go to `SavedTermsStore.shared` (the Vocabulary tab / 词汇本, persisted to UserDefaults key `savedTerms`) via `saveVocabItem`. (3) **Pair correct + wrong in saved vocab:** `saveVocabItem(_:question:)` now appends the correct answer and the student's wrong answer to the saved `definition` as "✓ <correct>  ✗ <wrong>" (skipping the correct answer when it just repeats the key/definition), so the saved card shows both what to learn and what was missed. Also localized the card's answer labels (`你的答案`/`正确答案` were verbatim `Text(String)` → now `LocalizedStringKey` "Your answer"/"Correct answer") and added catalog entries for all new strings (Your answer, Correct answer, Full sentence, Read sentence aloud, + the language-toggle strings App Language/Language/footer that the build auto-extracted from iter 5). Catalog: 557 keys, 0 coverage gaps, 0 placeholder errors. Both platforms build green.
- 2026-06-07 (iter 5 — full UI localization + in-app language toggle): Made the app a true bilingual product with a runtime English ⇄ 中文 switch. **Mechanism:** new `Models/LocalizationManager.swift` — an `@Observable @MainActor` singleton (`AppLanguage` enum: `.english`/`.chinese`) persisted to UserDefaults, plus a `Bundle` subclass (`LanguageOverrideBundle`, installed once via `object_setClass(Bundle.main, …)`) whose `localizedString(forKey:value:table:)` redirects to the user-selected `.lproj`. This is the standard, App-Store-safe in-app-language technique and means the app's many `Text("…")` string literals (already auto-extracted into `Localizable.xcstrings`) switch language live without a relaunch or device-language change. `SwiftMandarinApp` injects `.environment(\.locale, …)` and keys the root via `.id(localization.language)` so the whole tree re-resolves on switch (note: a language switch resets in-tab navigation state — acceptable for a deliberate, rare action). **Toggle UI:** a "Language" `Picker` (English / 中文) added to iOS `MoreView → SettingsView` and macOS `GeneralSettingsTab`. **Catalog:** completed `Localizable.xcstrings` to 100% bilingual coverage — added 206 Chinese translations for English-source keys, 76 English translations for Chinese-source keys (11 of which were auto-split from bilingual `中文 · English` keys), preserving every format placeholder (`%@`, `%lld`, positional `%1$lld`/`%2$@`, `${token}`, `\n`). All 252 comments and 262 pre-existing Chinese translations preserved unchanged. Compiled `zh-Hans.lproj` grew 262→544 entries, `en.lproj` 7→83 (Chinese-source keys now resolve to English so English mode is clean). **Tab bar fix:** `AppTab` gained a `titleKey: LocalizedStringKey` (tab titles were plain `String` → rendered verbatim and would not switch); `ContentView` tab/sidebar now use it; added missing `Photo` key. **QA:** ran a 10-batch + 1-consistency-critic verification workflow over all 549 catalog entries to catch mistranslations, wrong-language leftovers, and placeholder breakage; corrections applied through a placeholder-safety guard that rejects any change altering the source key's placeholder set. Both platforms build green (macOS + iOS Simulator, BUILD SUCCEEDED).
- 2026-06-04 (iter 2 — structured output linkage): (1) `TranslateView` AI-translate buttons now fire for ANY available provider (were Apple-Intelligence-only), so cloud/Ollama responses are actually used. (2) Added `AIProvider.supportsJSONResponseFormat`; `CloudAIService` only sends `response_format: json_object` where supported (OpenAI/DeepSeek/Kimi/Qwen) and relies on prompt+tolerant extraction elsewhere — prevents API errors on Doubao/Zhipu/MiniMax/Anthropic. (3) New structured feature: `AIWordExplanationService.extractVocabulary(fromPhotoText:imageData:sourceIsChinese:)` returns typed `ExtractedVocabItem`s; surfaced in `PhotoTranslateView` as an "AI 提取重点词汇" button + list + save-to-vocab. Both platforms build green; structured JSON parsing verified 5/5 (plain/fenced/prose/empty/garbage).
- 2026-06-26 (iter 12 — audit-fix branch `jun-26-2026-audit-fixes`): Committed pending work + merged `jun-12-2026-ios17-compat` → `main` (merge `66bed52`, pushed), then implemented the 13 P0–P2 findings from the latest audit on a fresh branch. **P0-1 logs/privacy:** reverted an Xcode-introduced `project.pbxproj` regression that dropped the `logs` exclusion from the file-system-synchronized exception set (would bundle local prompt/tool transcripts into `SwiftMandarin.app`), removed stray `SwiftMandarin/logs` & `SwiftMandarin/.claude` from the source folder, and added `SwiftMandarin/.claude/` to `.gitignore`. **P0-2 history direction** (`TranslateView`): `triggerAITranslation`/`performTranslation` now record the *content-detected* direction (`containsChinese`) instead of the UI toggle, and the stale guard no longer checks the toggle (session is already configured from the detected direction). **P0-3 speech audio** (`SpeechRecognitionService`): the modern engine's tap now converts/deep-copies and yields **synchronously** inside the tap (no unstructured `Task`), with a one-shot `AVAudioConverter` input block (`.haveData` once → `.noDataNow`) and a general `copyBuffer` (audioBufferList memcpy) — fixes use-after-reuse, frame reordering, and converter re-reads. **P1-1 persistence** (`PersistentCodableStore`): added `FailableDecodable` + resilient array/dict `load` overloads (one corrupt row is skipped, not the whole store) and tolerant `init(from:)` on `TranslationHistoryEntry`/`SavedTerm`/`CardProgress`. **P1-2 OCR off-main + P1-3 stride** (`PhotoTextRecognitionService`, `ScreenshotStitchingService`): Vision `perform` and the pixel-overlap scan now run via `Task.detached`; `getPixelData` returns `(bytes, bytesPerRow)` and the comparison indexes with the *rendered* stride (not `CGImage.bytesPerRow`). **P1-4 routing** (`LearnView`/`PhotoTranslateView`): each view clears only the pending action it owns. **P1-5 screenshot intent**: fixed the `ParameterSummary` interpolation and added a `guard !state.isProcessing` re-entry guard. **P2-1** guarded all `Ollama.Model.ID` force-unwraps; **P2-2** reasoning-model request bodies (o-series → `max_completion_tokens` + no temperature; `deepseek-reasoner` → `max_tokens` + no temperature); **P2-3** learner-mode ↔ app-language now sync bidirectionally (`.bilingual` preserved, loop-safe); **P2-4** sessions route through `getCardsForReview`, card IDs namespaced `builtin:`/`vocab:<uuid>` with migration of legacy progress keys, `CardProgress` gains `interval`/`lapse`; **P2-5** version/build derived from `Bundle` via new `AppConfig`, multi-provider credit string (localized), real `PRIVACY.md` + GitHub links (App Store links fall back to the repo until a numeric ID exists). **Verification:** iOS Simulator + macOS Debug both **BUILD SUCCEEDED, 0 warnings**. A 7-area adversarial-review workflow (+verification skeptics) found one confirmed P1: a bare `nonisolated async` does NOT run off-main under this project's `SWIFT_APPROACHABLE_CONCURRENCY` (SE-0461) — fixed by switching OCR to `Task.detached` (matching stitching). Also corrected the DeepSeek token-param family split and two hygiene nits. Not yet runtime-tested on device (requires GUI / live API keys); changes are compile-verified and reasoned.
- 2026-06-27 (iter 13 — AI word/phrase identification in the AI-translate flow, branch `jun-27-2026-ai-word-identification`): User asked that the AI-translate feature have the AI identify the words/phrases in the given text input. Implemented AI-powered segmentation that feeds the existing interactive "tap words for details" ruby view, replacing Apple's `NLTokenizer` (which segments Chinese poorly) when a translation comes from an AI provider; falls back to local segmentation when no provider is configured or the call fails. **New** `Services/WordIdentificationService.swift`: `IdentifiedWord` (Codable/Identifiable/Hashable, tolerant `init(from:)` — only `word` required, mirrors `ExtractedVocabItem`) + `IdentifiedWordsResponse`; `@Observable @MainActor` service `identifyWords(in:)` routes through `AIModelSettings.effectiveProvider` (Apple Intelligence `LanguageModelSession` / Ollama `chat` / Cloud `chat(jsonMode:true)`), parses `{"words":[…]}` via `AIWordExplanationService.extractJSONObject`, caches by exact source text. **Coverage guard:** the concatenated words must reconstruct the source (whitespace-stripped) or the result is discarded (→ empty → local fallback), so a model that drops/adds/paraphrases a character never renders Chinese that differs from the actual translation. **`ChineseTextAnalyzer`**: added `PartOfSpeech(aiLabel:)` mapping English/Chinese POS labels (e.g. "verb"/"动词") to the enum. **`RubyTextView`**: added `RubySegment.init(aiWord:)` (pinyin falls back to `PinyinConverter`; meaning kept in `translation`), an optional `aiSegments:` param (defaults `nil` → unchanged local path for all other call sites), an Equatable `aiSegmentsToken` so async AI results re-segment even when `chineseText` is unchanged, and `WordDetailPopover` now prefers the AI meaning for a Chinese segment (skips a redundant lookup). **`TranslateView`**: `startWordIdentification(for:)` (cancellable, generation-guarded) runs after a completed AI translation (`triggerAITranslation`) and after a spoken translation; passes `aiSegments` to the ruby view; shows an "Identifying words…" spinner; resets on source edit / clear / swap; the Apple Translation path (`performTranslation`) clears `aiSegments` so it always uses local segmentation (no surprise AI cost). **i18n:** added key "Identifying words…" (zh-Hans "正在识别词语…"), catalog 724 keys, JSON valid. **Verification:** iOS Simulator + macOS Debug both **BUILD SUCCEEDED, 0 warnings**. An adversarial review found one real P2 (spinner could stick ON in the input-language-mismatch + AI-translate path because an early `return` skipped the spinner-off) — fixed by always clearing the spinner for the current generation and gating only the segment assignment; the review also prompted the coverage guard above. Not runtime-tested on device (needs a live provider/key); compile-verified + reasoned.
- 2026-06-27 (iter 14 — batch AI analysis count stuck at 400 + vocab font sizes, branch `jun-27-2026-ai-word-identification`): User: the Settings → Batch AI Analysis "processed" count was stuck at 400 even after analyzing ~6000 words; with 7200 saved words they want to process only the new ~1200, not reprocess. **Root cause:** `WordExplanationCacheStore` capped itself at `maxEntries = 400` with MRU tail-eviction, so as a batch ran past 400 the oldest analyses were silently discarded — the persistent cache (and thus the "analyzed" count = saved − uncached) could never exceed 400, and the older results were genuinely lost (only ≤400 ever persisted). **Fix (`WordExplanationCacheStore.swift`):** removed the cap entirely; persistence moved from a UserDefaults blob to a JSON file in Application Support (`word-explanation-cache.json`), written **off the main thread** via a coalesced + throttled single-writer (`scheduleSave` → `writeTask`/`needsWrite` loop, `Self.writeThrottle = 10s`, trailing write guaranteed) so a multi-thousand-word batch doesn't re-encode the growing file per word on the main actor; `lookupIndex` is now maintained **incrementally** (via `upsert`) instead of a full rebuild per mutation (was the other latent O(n²)); added a second `normalizedWordIndex` set + `hasAnyExplanation(forWords:)` so the export count is O(terms) not O(terms×entries) (the cap removal made the old per-term scan ~18× worse); one-time migration adopts the legacy UserDefaults cache into the file and only deletes the UserDefaults keys when the file write succeeds (no data-loss window). Made `CachedWordExplanation` + `WordExplanationResult`/`ExampleSentenceResult`/`RelatedWordResult`/`CollocationResult` `Sendable` (needed to snapshot across to the background write). Added `PersistentCodableStore.appSupportFileURL` (nonisolated) + `loadArrayFromFile`; made its `log` nonisolated. **`BatchExplanationController.start`** now sorts the pending queue newest-added first (`dateAdded` desc) so the just-added words are analyzed before the older backlog (user can cancel once the new ones finish). **Caveat (communicated):** the ~5600 results evicted by the old cap are unrecoverable (never persisted), so the app legitimately shows them as needing analysis; after this fix progress is permanent, so a one-time backfill sticks and only genuinely-new words are queued thereafter. **Font (`VocabularyView.swift`, user request):** bumped the vocabulary-list Chinese headword default size 22→26 (2 steps) and made the pinyin scale with it (`.system(size: chineseFontSize * 0.7)`) instead of a fixed `.subheadline`, so enlarging the character (A+) also enlarges the pinyin and tone marks. **Verification:** iOS Simulator + macOS Debug both **BUILD SUCCEEDED, 0 warnings**. Adversarial review (separate agent) confirmed the coalesced-writer correctness, index integrity, Sendable, and migration; its P1 (write amplification) and P2s (migration delete-before-confirm, export scan, print-vs-Logger) were all fixed. Known minor: no explicit flush on app-background, so a mid-batch kill loses ≤10s of words (cache is regenerable). Not device-tested (needs live provider/key).
- 2026-06-27 (iter 14b — font targeting + fix dead font slider): Correcting iter 14's font change (wrong target). The Settings "Text Size" slider was bound to `@AppStorage("fontSize")`, a key NOTHING in the app reads (only referenced in MandarinKit.md docs) — so it did nothing. Rebound both sliders (`MacOSSettingsView` + `MoreView` → renamed "Vocabulary Text Size", range 14–40 step 2, pt label via `Text(verbatim:)`) to `vocabularyChineseFontSize`, the key the vocab list actually uses (and that the list's A−/A+ steppers already drive) — so the slider now works and all three controls share one value. Vocab LIST default lowered 26→20 (one size below the original 22, per request). Vocab DETAIL view (`VocabularyDetailView`) headword 80→92 and pinyin `.title`→`.largeTitle` (bigger, per request). Added catalog key "Vocabulary Text Size"/"词汇文字大小" (725 keys). Both platforms BUILD SUCCEEDED, 0 warnings.
- 2026-06-28 (iter 15 — Quotio provider, branch `jun-28-2026-quotio-provider`): Added Quotio as an AI provider. Quotio is a local "CLI Proxy API Server" that is OpenAI-compatible (`GET /v1/models`, `POST /v1/chat/completions`, `Authorization: Bearer`). Verified live against `http://localhost:8320/v1` with key `quotio-local-CCC656AC`: `/v1/models` returns the standard `{"data":[{id,object,created,owned_by}]}` list (80+ models across openai/anthropic/iflow/qwen/github-copilot/antigravity backends), and `gpt-5-mini` chat returns the standard `choices[].message.content` shape (some upstream models 401 when their CLI auth isn't configured in the proxy — a proxy-config matter, not ours). (The hosted docs at quotio.dev/docs are a JS app the fetcher couldn't render, so integration was driven by the verified live API.) **Change (one file, `AIModelSettings.swift`):** added `case quotio = "quotio"` and the required exhaustive-switch arms — displayName "Quotio", description, SF-symbol icon `point.3.connected.trianglepath.dotted` (no brand asset → ProviderIcon falls back to it), `isCloud` (default true), `apiStyle` .openAICompatible (default), `defaultBaseURL` `http://localhost:8320/v1`, `chatPath` `/chat/completions` (default), `modelsPath` `/models` (→ live listing + Refresh works), curated `defaultModels` (gpt-5-mini first = default), `supportsVision`=false and `defaultVisionModel`=nil (proxy vision is backend-dependent; don't auto-route image tasks), `supportsJSONResponseFormat`=false (prompt-driven JSON + tolerant parse, since the proxy fronts many models), `apiKeyURL`→docs. No `CloudAIService` changes needed — it's generic over `isCloud`+`apiStyle`, builds the URLs/auth and parses `{data:[…]}` automatically; the provider appears in pickers via `AIProvider.allCases`. Local HTTP works the same way the existing Ollama-localhost feature does (no ATS exception needed). iOS Simulator + macOS Debug both **BUILD SUCCEEDED, 0 warnings**. The user enters the key in Settings → AI (stored in Keychain as `apikey.quotio`).
- 2026-06-28 (iter 15b — fix Kimi provider): User reported Kimi not working. **Root cause:** Kimi's coding model (`kimi-for-coding`, display "K2.7 Code"; `kimi-k2.7` is an accepted alias) is **thinking-only** and rejects any temperature ≠ 1 — it returns `400 invalid_request_error: "invalid temperature: only 1 is allowed for this model"`. The app's `CloudAIService.openAIBody` sent `temperature: 0.3` for every non-reasoning model, and Kimi isn't matched by `isReasoningModel`, so **every Kimi request 400'd**. Verified via curl with key `sk-kimi-…` against `https://api.kimi.com/coding/v1`: with `temperature:0.3` → 400; omitting temperature → works (`"I like learning Chinese."`, finish=stop; reasoning is returned separately in `reasoning_content`, answer in `message.content` which the app already reads). **Fix:** `openAIBody` gained `allowsCustomTemperature` (default true); `chat()` passes `provider != .kimi`, so Kimi sends `max_tokens` only and the model uses its default temperature (1). Also discovered Kimi's `GET /coding/v1/models` **now works** (returns the single `kimi-for-coding` model, `supports_image_in:true`), so re-enabled live listing: `modelsPath` for `.kimi` → `/models` (was `nil` on an outdated 401 assumption), and `defaultModels` → `["kimi-for-coding", "kimi-k2.7"]`. iOS + macOS both BUILD SUCCEEDED, 0 warnings.
- 2026-07-08 (iter 16 review + fixes): Adversarial review workflow (7 lens finders → per-finding skeptic verifiers) ran over the whole overhaul diff; some verifiers hit the Fable-5 usage cap but the finders + enough verifiers completed → 12 confirmed findings (1 refuted: "stability uses post-review difficulty" — code was correct). Applied fixes: (P2×3, consolidated) **due-count inflation** — `LearningProgressStore.pendingReviewCount(from:)` now counts due-with-history + `min(unseen, remaining new-card budget)` instead of the whole never-studied backlog; HomeView + StudyHubView both use it (badge now matches the session `getCardsForReview` builds, and "All caught up" is reachable); made it read-only (no reset) so it's safe in a view body, added `refreshDailyCounters()` called from HomeView onAppear/scene-active. (P2) **TTS ducking never released** — added `SpeechSessionReleaser: AVSpeechSynthesizerDelegate` (didFinish/didCancel → `AVAudioSession.setActive(false, .notifyOthersOnDeactivation)`) so background audio un-ducks after a speaker tap. (P2) **Dictation "Slow" was normal speed** — added `SpeechService.speakAutoSlow` (content-aware voice, rate×0.6) and wired the tortoise button to it. (P2) **duplicate startReview push** — removed MoreView's pendingAction watcher (Study hub owns iOS review routing; macOS selects .learn directly), dropping the now-unused routeStore env. (P3) **welcome sheet re-presented on swipe** — sheet `onDismiss` now sets `hasCompletedWelcome` so any dismissal sticks. (P3) **arrow keys skip grading/relearn** — clamped LearnView nav (no wrap) + `recordReview` re-presents the first pending relearn card if advancing would otherwise complete the session with cards unpassed. (P3) **stale daily counters after midnight** — `refreshDailyCounters()` accessor; stats sheet calls it onAppear. (P3) **Reader single-CJK misdetection** — `ReaderStore.isPredominantlyChinese` (≥20% CJK of letter chars) replaces `containsCJK` for content-language routing + coverage. (P3) **Home Stats/See-All dumped on hub root** — new `AppRouteStore.openStudy(route:)` + `.openStudyRoute(String)` pending kind + StudyRoute raw values → StudyHubView deep-links to Stats/Vocabulary. **Remaining P1 under evidence-based review:** nested NavigationStack (StudyHubView pushes views that own their own NavigationStack) — this is the SAME pattern already shipping in MoreView→LearnView across prior iterations, so testing on iOS simulator before any 7-file refactor. macOS build stayed green throughout.
- 2026-07-08 (iter 16 progress): Study workflow completed — 22 agents, 10 subsystem maps, 140 raw ideas → 104 deduped recommendations in 10 themes + 12 critic additions → **RECOMMENDATIONS.md** (1,580 lines) written at repo root. User added mid-flight requirements (all folded into scope): vocab detail view must show ALL AI-explanation sections expanded by default (AIWordExplanationView expandedSections init); swipe left/right between prev/next word in vocab detail on iOS + iPadOS/macOS equivalents (toolbar chevrons + ⌘←/→); dual-perspective (EN↔中) audit of all surfaces. Foundation laid centrally: `Views/Components/DesignSystem.swift` (SMTheme/SMCard/SMSectionHeader/StatTile/GoalRing/StreakBadge/QuickActionButton/HeroActionRow/TagChip/SMProgressBar/SMEmptyState/CelebrationBurst), AppTab gains home/reader/study/practice/conversation cases, iOS tabs → Home·Translate·Photo·Study·More, macOS sidebar sections (Home; Translate: translate/photo; Study: learn/practice/conversation/reader; Library: vocabulary/phrases/history/stats), new `Views/StudyHubView.swift` (hub + startReview pendingAction handling w/ initial:true), AppRouteStore default tab .home + iOS triggerReview→.study, MoreView gains reader/practice/conversation routes. Wave-1 implementation workflow launched (6 parallel agents, strict file ownership): srs-engine (FSRS-4.5 SRSEngine + CardProgress migration + LearnView 4-button/relearn-queue/forecast), reader (ReaderStore/ReaderView/ReaderSessionView/StoryGenerationService), conversation (ConversationStore/View/Service + CloudAIService.chatTurns), practice (PracticeHub/Quiz/Dictation/TonePairDrill/PracticeStore), home-design (HomeView/WelcomeView + LearningActivity streak fixes + StatsView heatmap alignment), polish (expanded sections + prev/next nav + regenerate/availability/tone-color/TTS-session/draft-persist/history/workbook fixes + MenuBarTranslateView). NOTE: `dailyGoal` UserDefaults key is written as Double by the macOS slider — normalize reads via double(forKey:). Pending after wave 1: central integration (MenuBarExtra scene, settings wiring for ttsRate/dailyGoal, Home continue-reading card), xcstrings localization sweep, build loop both platforms, adversarial + dual-perspective review.
- 2026-07-07 (iter 16 T0 — step-change overhaul kickoff, branch `jul-07-2026-step-change-overhaul`): Request: study the whole codebase with parallel subagents; write an exhaustive `RECOMMENDATIONS.md` (improvements + first-principles new features + UI redesign); then overhaul the app on a new branch — "a whole step change in the look, feel, features, and functions," not iterative tweaks. Baselines verified first: macOS Debug + iOS Simulator Debug both BUILD SUCCEEDED, 0 warnings (DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer required — CLT-only default). Launched a 22-agent workflow (10 subsystem mappers → 10 ideation lenses: pedagogy/UX-redesign/AI-native/Apple-platform/gamification/immersion-reading/listening-speaking/data-interop/a11y-i18n/architecture-perf → CPO synthesis + completeness critic). Implementation constraints re-confirmed from prior iters: new .swift files auto-include (synchronized group; pbxproj untouched, `grep -c "in Sources"` must stay 0), new user-facing strings need manual `Localizable.xcstrings` zh-Hans entries, every new sheet/popover needs `.localizedSurface()`, iOS 17.0 floor (Liquid Glass/FoundationModels = 26-only, `Tab` builder = 18-only → CompatModifiers or availability gates), keys in Keychain. Entry updated with results as phases complete.
- 2026-06-28 (iter 15c — Kimi Test Connection 404 / URL version doubling): Kimi's coding host serves BOTH styles at the same host — OpenAI `…/coding/v1/chat/completions` (base `…/coding/v1`) and Anthropic `…/coding/v1/messages` (base `…/coding`). Verified via curl: both work at the correct URL; the OpenAI default base + Anthropic API Format yields `…/coding/v1/v1/messages` → 404 (doubled `/v1`). Added `CloudAIService.buildURL(base:path:)` used by both `chat()` and `listModels()`: when the path starts with `/v1` and the base ends with `/v1`, it drops the base's `/v1` so the version segment isn't duplicated (safe — only triggers on that exact overlap; api.anthropic.com and `…/anthropic` bases are unaffected). So Kimi now works whether the user leaves API Format on OpenAI Compatible (default, base `…/coding/v1`) or switches to Anthropic with the same default base. Recommended config for the user: API Format = OpenAI Compatible, base `https://api.kimi.com/coding/v1`, model `kimi-for-coding` (or `kimi-k2.7`). iOS + macOS both BUILD SUCCEEDED, 0 warnings.

## Iteration 17 — Current-Code Recommendations Audit (2026-07-10)

**Last Updated (UTC):** 2026-07-10T11:35:14Z
**Status:** Complete
**Current Focus:** Audit complete. `CODEX_RECOMMENDATIONS.md` is the source-anchored output; no recommendation has been implemented by this audit.

### Request & Context

- The user asked for a careful, full-codebase study and a new root-level `CODEX_RECOMMENDATIONS.md` covering confirmed issues, errors, bugs, product/UI enhancements, new features, and opportunities to connect the app's subsystems into a more coherent experience.
- Existing `RECOMMENDATIONS.md`, `EXECPLAN2.md`, prior handoff entries, and screenshots provide historical leads. The live checkout is the source of truth; older findings MUST be re-checked before inclusion.
- The worktree already contains user-owned modifications in `PracticeStore.swift`, `PinyinConverter.swift`, `LearnView.swift`, `TonePairDrillView.swift`, and session logs. This audit MUST NOT edit, stage, revert, or otherwise disturb them.
- Scope boundary: create the requested recommendation document and update this continuity record. Do not implement recommendations, create issues, commit, push, or modify product code.

### Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R17.1: Study the whole app | Inventory every tracked Swift source, project configuration, localization catalog, tests (if any), and relevant current documentation | Audit coverage spans app shell, UI, models, services, intents, persistence, concurrency, privacy/security, accessibility, localization, and platform behavior | Repository inventory and coverage matrix in `CODEX_RECOMMENDATIONS.md` |
| R17.2: Identify real problems | Re-open every high-impact candidate in the current file and trace its callers/data flow; distinguish confirmed, probable, and validation-needed items | No stale finding is presented as confirmed | File/line references and confidence labels |
| R17.3: Recommend improvements | Synthesize practical UI, feature, architecture, integration, testing, and product improvements tied to current capabilities | Recommendations are prioritized, non-duplicative, and explain user impact plus an implementation direction | Prioritized sections and phased roadmap |
| R17.4: Preserve repository state | Compare `git status` before and after | Only `CODEX_RECOMMENDATIONS.md` and this required handoff update are newly changed by this audit | Final `git status --short` |
| R17.5: Validate deliverable | Check Markdown structure, local code-reference targets, duplicate finding IDs, and fresh platform builds | Document is self-contained; references resolve; build results are reported accurately | Validation script output and `xcodebuild` exit codes |

### Plan & Progress Ledger

- [x] Read the existing continuity record, recent history, worktree status, and prior audit documents.
- [x] Establish the audit-only scope and protection for pre-existing dirty files.
- [x] Map the live architecture and inspect all source areas with parallel specialist review.
- [x] Reproduce or statically prove high-risk findings and run fresh macOS/iOS build gates.
- [x] Write `CODEX_RECOMMENDATIONS.md` with an executive summary, prioritized findings, cohesion opportunities, feature/UI enhancements, quality strategy, and phased roadmap.
- [x] Run an independent evidence review, verify all paths/line anchors, and record final results here.

### Findings, Decisions, Assumptions

- **Finding:** No `feature_list.json`, `agent-progress.txt`, or `init.sh` exists, but this established repository already uses the much richer root `handoff.md` as its continuity harness. Because the present task is a read-only audit rather than a feature implementation shift, no parallel feature-spec harness will be introduced.
- **Decision:** Existing audits are evidence sources, not copy sources. A recommendation is included only if it remains observable in the current checkout or is clearly labeled as an idea/validation gap.
- **Decision:** A successful build proves compilation, not runtime correctness. Findings about live services, camera/microphone behavior, or on-device frameworks will retain explicit runtime-validation notes when they cannot be exercised safely without credentials or GUI interaction.
- **Assumption:** The current branch intentionally targets both iOS and macOS from one target. This will be checked against `project.pbxproj` and conditional compilation before platform-specific recommendations are finalized.
- **Finding:** A generic visionOS Simulator build fails because `TranslationSession` is unavailable at `ShortcutHelpers.swift:81`; the document treats advertised visionOS support as a release gate rather than assuming support from project settings.
- **Finding:** Fresh isolated macOS and iOS Simulator Debug builds pass on the final shared working-tree snapshot when `DEVELOPER_DIR` points to `/Applications/Xcode-beta.app/Contents/Developer`.
- **Concurrent-work note:** Iteration 18 modified `DesignSystem.swift`, `HomeView.swift`, and the other user-owned Swift files while this audit was active. The audit did not author, stage, revert, or otherwise modify those runtime changes.

### Scenario-Focused Resolution Tests

- **Audit scenario:** Starting from the current dirty worktree, review without changing runtime files; produce one new recommendations document; confirm the original dirty files have identical diffs afterward.
- **Current verdict:** Passed for the audit scope. The only audit-authored files are the requested `CODEX_RECOMMENDATIONS.md` and this Iteration 17 continuity update. Runtime/log changes visible in `git status` belong to the pre-existing/concurrent project work.

### Verification Summary

- Initial repository state captured with `git status --short`, branch name, recent history, file inventory, and existing audit-document inventory.
- Memory registry search returned no entry for this repository, so no prior Codex memory facts are being used as evidence.
- All 90 Swift files plus project configuration, App Intents, entitlements, assets, localization, persistence/import/export, privacy/release documents, and the tracked DMG were reviewed.
- Every Swift file/line anchor in `CODEX_RECOMMENDATIONS.md` resolves to an existing file and stays within its line count. Finding IDs were checked for duplicate headings, JSON catalogs/assets parse successfully, and Markdown whitespace checks pass.
- Final macOS build: passed (`xcodebuild`, generic macOS, Debug, unsigned, isolated Derived Data).
- Final iOS Simulator build: passed (`xcodebuild`, generic iOS Simulator, Debug, unsigned, isolated Derived Data).
- visionOS Simulator build: failed as documented at `ShortcutHelpers.swift:81` because `TranslationSession` is unavailable on visionOS.
- Independent evidence review corrected priority-index traceability, Xcode-log wording, Photo task anchors, workbook review wording, and nested-navigation confidence before delivery.

### Remaining Work & Next Steps

- No audit work remains. If implementation is requested, begin with Phase 0 release/privacy safety and take one source-anchored item through tests and acceptance evidence at a time.

### Updates to This File

- 2026-07-10T11:02:45Z: Added Iteration 17 audit brief, acceptance matrix, scope protections, plan, and initial evidence.
- 2026-07-10T11:35:14Z: Completed the full source/platform audit, added `CODEX_RECOMMENDATIONS.md`, recorded build and visionOS evidence, incorporated independent review corrections, and marked the audit complete.

## Iteration 18 — Home redesign, real tone-drill syllables, vocab-linked practice (2026-07-10)

Branch: `jul-07-2026-step-change-overhaul`. Four user-reported issues addressed and verified on a running build.

**R1 — "The homescreen is very very ugly."** Root causes (from the user's macOS screenshot): content hugged the far-left with a vast empty void (no width cap/centering); cards were **invisible on macOS** because `SMTheme.cardFill` (`controlBackgroundColor`) ≈ `windowBackgroundColor` with no border/shadow, so every panel read as loose floating text; the empty goal ring looked broken; no color/focal point.
  - `DesignSystem.swift`: added `SMTheme.contentMaxWidth` (700), `SMTheme.cardStroke` (platform separator) + `cardShadow`, and a shared `View.smCardSurface()` (fill + hairline border + soft shadow). `SMCard`, `StatTile`, and `HeroActionRow` now use it, so cards read as distinct panels on every platform. `GoalRing` gained `trackColor` / `progressStyle` params so it renders on a colored surface.
  - `HomeView.swift`: replaced the flat greeting + `Today` card with one **gradient hero** (greeting + bilingual flavor + streak pill + white-on-gradient goal ring + white "Review now" CTA with due badge + goal-gear). Content column is capped at `contentMaxWidth` and centered (`.frame(maxWidth:700).frame(maxWidth:.infinity)`), killing the left-hug void. `continueReadingSlot` and `termChip` now use `smCardSurface`.
  - **Evidence:** macOS screenshot `scratchpad/home_macos_after2.png` — blue hero, elevated cards, centered column, "Review now 25" (real due count). Before: user's screenshot (flat gray, left-hugging).

**R2 — Tone drill only ever showed "mā/mǎ".** The four answer options rendered static "ma" exemplars, so the drill felt disconnected from the spoken word.
  - `PinyinConverter.swift`: added `baseSyllable(_:)` (strip to plain letters, preserving ü) and `applyTone(_:to:)` (re-place a tone mark by the standard a>e>ou>last-vowel rule).
  - `TonePairDrillView.swift`: `ToneQuestion` now carries `baseSyllables`; `exemplarText` renders each option in the **actual word's** syllables under that candidate tone (falls back to "ma" only if counts can't be paired). `makeRound` segments once so tones and base syllables stay index-aligned.
  - **Evidence:** `scratchpad/tone_drill.png` — word 他家 with options `tā·jiā` / `tá·jiá` / `tà·jiá` / `tá·jiā`, tone-colored. No more "ma".

**R3/R4 — Flashcards & practice should draw from the vocab list, not a fixed hardcoded set.**
  - `LearnView.swift`: default `cardSource` is now `.vocabulary` (was `.combined`); `reloadSessionCards` falls back to the starter deck only when the user has **no** saved words, so learners study their own list by default and newcomers still get content.
  - `PracticeStore.swift`: `toneDrillPool()` now prefers vocabulary-derived tone candidates and mixes in the built-in deck only when fewer than `minimumVocabularyForSoloPool` (4) exist. (Quiz/Dictation already used `practicePool()`, which prefers vocab.)
  - **Evidence:** Practice hub subtitle "…turn your saved words into instinct"; the tone drill above drew 他家 (a saved word) with the built-in deck no longer padding a 7k-word list.

**Builds:** macOS `platform=macOS` and iOS `platform=iOS Simulator` (iPhone 17 Pro) both **BUILD SUCCEEDED**. Runtime verified by launching the macOS Debug build against real user data (7,213 words). Not yet committed — awaiting user go-ahead.

- 2026-07-10T23:16:00Z: Added Iteration 18 (Home hero redesign, visible macOS cards, real tone-drill syllables, vocab-default flashcards/tone pool). Both platforms clean; verified on running macOS build.

## Iteration 19 — Native vocabulary-detail paging and 2027 UI alignment (2026-07-13)

**Last Updated (UTC):** 2026-07-13T10:25:50Z

**Status:** Complete

**Current Focus:** This slice is delivered; the next bounded slice is adaptive `StatsView` layout in GitHub issue #4.

### 1) Request & Context

- **User request:** Continue improving the cross-platform app; on iOS, allow left/right swipes between adjacent vocabulary items in detail; update the UI for current iOS and macOS 27 Golden Gate design guidance.
- **Operational constraints:** Work from clean `main` commit `6c3d9aa` in isolated branch/worktree `codex/vocab-detail-swipe-modernization`; preserve the dirty primary worktree and the separate autonomous-loop bootstrap worktree. Build with `/Applications/Xcode-beta.app` (Xcode 27.0 / Swift 6.4) without changing global `xcode-select` or preferences.
- **Scope boundary:** This is one vertical slice: vocabulary list/detail navigation and the shared compatibility helpers it directly needs. It does not authorize an unbounded rewrite of every app screen.
- **Design authority:** Apple’s 2027 SwiftUI guidance says system SwiftUI controls automatically gain the refined Liquid Glass appearance; custom glass should be sparse and restricted to the controls/navigation layer. The new toolbar visibility/minimization APIs are beta and MUST be availability-gated.
- **Existing behavior:** `TermDetailSheet` already has a June 2026 high-priority `DragGesture`, toolbar chevrons, and a count. This is a partial implementation, not a completed acceptance result: its recognizer can preempt vertical scrolling before its end-only direction check, it has no native page tracking, and the sheet item’s identity changes with selection.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check (scenario steps) | Expected Outcome | Evidence to Capture |
|---|---|---|---|
| R19.1: Native adjacent paging | Open a middle row from a filtered/sorted vocabulary list; swipe left, then right | Detail settles on the exact next item and returns to the original; the sheet stays presented | Simulator interaction + selected ID/position evidence |
| R19.2: Gesture coexistence | Vertically scroll a long AI explanation, then perform horizontal swipes | Vertical reading remains smooth; horizontal paging is deliberate and follows the finger | Simulator interaction / video or screenshots |
| R19.3: Safe boundaries and mutations | Open first/last items; invoke both directions; master/update a term; remove the selected term from the store | No wraparound, crash, empty fabricated term, stale page state, or incorrect list order | Regression checks + scenario log |
| R19.4: Accessible alternatives | Use previous/next controls, VoiceOver labels, and hardware shortcuts | Every paging action is available without a touch gesture; disabled states are announced | Accessibility/source audit + simulator check |
| R19.5: 2027 platform UI | Run on iOS 27 and macOS 27; inspect navigation, toolbars, content surfaces, resizing, dark mode | System Liquid Glass appears in controls/navigation; content remains legible and semantic; crowded actions adapt | Screenshots + Apple-guidance mapping |
| R19.6: Backward compatibility | Build against iOS 17 and macOS 26.2 deployment floors using Xcode 27 | Availability gates compile and fallbacks remain present | iOS/macOS build logs, zero new warnings |
| R19.7: Reviewable delivery | Review diff, localizations, docs, tests; commit and push one branch | Cohesive commit, no unrelated files, clean branch | Git diff/status and remote branch SHA |

### 3) Plan & Decomposition

- **Critical path:** First prove the current implementation and SDK constraints, then separate stable presentation identity from page selection, then adopt native paging, then polish only the affected controls. This orders the work around gesture and state risks before cosmetic changes.
- [x] Read current handoff/history, `LOOP.md`, recommendations, vocabulary/store/navigation code, and relevant skills.
- [x] Create isolated branch/worktree and capture the Xcode 27 / SDK 27 environment.
- [x] Verify the current partial swipe implementation and research current Apple primary guidance.
- [x] Complete clean baseline iOS/macOS builds.
- [x] Implement stable native paging and per-page async state isolation.
- [x] Apply adaptive toolbar/action/content polish and current-platform compatibility gates.
- [x] Add deterministic regression checks and localization/accessibility coverage.
- [x] Run build, scenario, visual, and independent review gates; resolve findings.
- [x] Commit, push, and record the exact next slice.

### 4) To-Do & Progress Ledger

- [x] Branch `codex/vocab-detail-swipe-modernization` created from `main@6c3d9aa`; evidence: `git worktree add` succeeded.
- [x] Xcode environment confirmed: Xcode 27.0 build 27A5194q, iOS SDK 27.0, macOS SDK 27.0, Swift 6.4.
- [x] Current source traced: `VocabularyView` owns selection, iOS sheet receives `filteredTerms`, and the detail uses end-only high-priority drag arbitration.
- [x] Product changes complete: stable detail-session identity, exact visible-order snapshot, previous/current/next native page window, independent per-word state, adaptive controls, and accessible alternatives.
- [x] Regression evidence complete: deterministic helper checks (18/18), real iOS vertical + horizontal gestures, boundaries, toolbar navigation, dismissal, and 7,000-word stress scenario.
- [x] Three independent reviews completed; all Critical/Important implementation findings were resolved and re-reviewed.
- [x] Remaining work reconciled without duplicates and filed as GitHub issues [#4](https://github.com/linroger/SwiftMandarin/issues/4) and [#5](https://github.com/linroger/SwiftMandarin/issues/5).
- [x] Final clean gates and version-control delivery on `codex/vocab-detail-swipe-modernization`.

### 5) Findings, Decisions, Assumptions

- **Finding:** Apple officially names the release macOS 27 Golden Gate; the installed SDK and Apple release notes confirm it, so this is not a speculative codename.
- **Finding:** Xcode 27’s refreshed Liquid Glass look is automatic for standard SwiftUI controls. Apple explicitly advises against using Liquid Glass in the content layer and recommends system toolbars, sparse important actions, and adaptive overflow/visibility behavior.
- **Decision:** Use a system page-style `TabView`, but expose only the previous/current/next terms. The Xcode 27 ID-bound horizontal `ScrollView` let its selected ID and rendered offset diverge on initial non-first selection, while an unbounded page-style `TabView` stalled with 7,000 words. The three-page window preserves native gesture arbitration and stable initial selection with constant page-view cost.
- **Decision:** Keep the existing iOS 17 and macOS 26.2 deployment floors. New 2027 APIs will refine behavior only when available.
- **Finding:** No beta-only Xcode 27 API was needed. Standard `NavigationStack`, toolbars, menus, page-style `TabView`, semantic backgrounds, and native buttons adopt the current Liquid Glass control treatment while keeping content out of the decorative glass layer.
- **Assumption falsified and replaced with evidence:** Cross-axis gesture arbitration was not assumed. A headless iOS 27 UI scenario scrolled the current detail vertically, restored it, paged left and right, and then used the toolbar; all visible-state assertions passed.

### 6) Issues, Mistakes, Recoveries

- **Existing symptom → root cause:** Swipe code exists but may feel absent/unreliable → a high-priority drag recognizer claims drags before checking direction only in `onEnded` → replace it with system paging and retain explicit alternatives.
- **Regression guardrail:** Navigation will be keyed by stable term IDs and boundary behavior will be checked independently of UI rendering.
- **Runtime mistake → detection → recovery:** The first native `ScrollView` implementation set `visibleTermID` to the tapped middle term, but Xcode 27 rendered page one. The UI test detected the counter/pixel mismatch. Delaying the binding and adding `ScrollViewReader.scrollTo` still left the rendered offset stale, so that implementation was rejected.
- **Performance mistake → detection → recovery:** A full page-style `TabView` fixed initial selection and gestures, but the 7,000-word stress run took about 60 seconds to report an idle event and created every detail page. The pager was windowed to three terms; the retained repeat log proves the former 60-second stall is gone, the complete stress UI case finishes in 20.08 seconds, and adjacent paging succeeds. Earlier interactive `ps` samples were not retained, so approximate app-RSS numbers are deliberately omitted from the final evidence claim.
- **Review finding → fix:** Preloaded neighbor pages could auto-translate empty glosses. Automatic translation is now keyed and gated by `isCurrent`; changing pages cancels the structured task, and manual work is canceled when its page ceases to be current.
- **Review finding → fix:** The vocabulary page and `AIWordExplanationView` both owned same-axis scroll views. The explanation now has a reusable embedded mode, so vocabulary detail/inspector screens have exactly one vertical scroll owner while the standalone AI sheet remains independently scrollable.
- **Review finding → fix:** macOS Copy All displayed feedback on the neighboring Copy button. Per-action cancellable feedback now updates only the invoked control.
- **Runtime-harness mistakes → recovery:** The transient test wrapper initially used zsh's read-only `status` variable, then exposed a Swift 6 actor-isolation error and a duplicate Study-button query. The wrapper now uses a non-reserved exit variable, main-actor test methods, and `firstMatch`; the final scenario passed. The transient project was removed after evidence capture.
- **Guardrail added:** `VocabularyPaging` centralizes order-preserving de-duplication, bounded neighbor selection, constant-size page windows, and missing-ID reconciliation; `scripts/test-vocabulary-paging.sh` validates 18 deterministic cases, including a 7,000-ID session.

### 7) Scenario-Focused Resolution Tests

- **Current reproduction:** Open a vocabulary detail with long vertically scrollable content. The current `highPriorityGesture(DragGesture)` competes with the vertical `ScrollView`; the view does not track the finger like a page and discoverability depends on tiny toolbar symbols.
- **Change applied:** The sheet now has a stable session ID and snapshots the current filtered/sorted term IDs. A native page-style container hosts only previous/current/next pages, each with its own vertical scroll view and term-specific translation/copy tasks. System bottom-toolbar controls expose previous/count/next, while Done remains in the top confirmation slot.
- **Post-change behavior:** Opening the middle of a three-word ordered list displayed the middle term; vertical scrolling did not change pages; a left swipe displayed the next term; a right swipe returned; the previous toolbar button reached the first term; both terminal controls disabled at their respective bounds; Done returned to the Vocabulary screen.
- **Mutation coverage:** Store resolution and ID-reconciliation paths were verified by source review and deterministic helpers. The retained UI scenario does not claim to exercise mastering, definition updates, or deletion; those mutations belong in the durable UI target tracked by issue #5.
- **Verdict:** Resolved on the iOS 27 iPhone 17 Pro simulator, including the Study → Vocabulary route that previously exposed the nested-navigation failure.

### 8) Verification Summary

- Source and history inspection complete. The earlier nested-`NavigationStack` defect remains fixed on `main` and must not be reintroduced.
- Official Apple sources and installed SwiftUI interfaces confirm the 2027 automatic design refresh plus `visibilityPriority`, `ToolbarOverflowMenu`, `topBarPinnedTrailing`, and `toolbarMinimizeBehavior` APIs. No beta-only API has yet been added.
- Baseline iOS Simulator Debug build passed with `** BUILD SUCCEEDED **` and no `warning:`/`error:` lines in `/tmp/SwiftMandarin-vocab-baseline-ios.log`.
- Baseline macOS Debug build passed with `** BUILD SUCCEEDED **` and no `warning:`/`error:` lines in `/tmp/SwiftMandarin-vocab-baseline-macos.log`.
- Production-diff iOS Simulator Debug build passed with `** BUILD SUCCEEDED **` and no compiler warnings/errors in `/tmp/SwiftMandarin-vocab-production-ios.log`.
- Production-diff macOS Debug build passed with `** BUILD SUCCEEDED **` and no compiler warnings/errors in `/tmp/SwiftMandarin-vocab-production-macos.log`.
- Final stable-snapshot iOS Simulator Debug build passed with `** BUILD SUCCEEDED **`, 0 `warning:` diagnostics, and 0 `error:` diagnostics in `/tmp/SwiftMandarin-vocab-final2-ios.log`.
- Final stable-snapshot macOS arm64 Debug build passed with `** BUILD SUCCEEDED **`, 0 `warning:` diagnostics, and 0 `error:` diagnostics in `/tmp/SwiftMandarin-vocab-final2-macos.log`.
- Deterministic paging checks passed 18/18 via `scripts/test-vocabulary-paging.sh`, including first/middle/last windows and a 7,000-ID constant-window case; `jq empty SwiftMandarin/Localizable.xcstrings` and `git diff --check` passed.
- Headless iOS UI acceptance passed with 0 failures in `/tmp/SwiftMandarin-vocab-uiqa-production2.log`. It covered Study navigation, selected-page identity, vertical scrolling, left/right swipes, previous control, both boundary states, and Done dismissal.
- A fresh post-review iOS UI acceptance passed with 0 failures in `/tmp/SwiftMandarin-vocab-uiqa-final.log` after installing the newly built app. It repeated selected identity, vertical scrolling, left/right swipes, toolbar navigation, boundaries, and dismissal after the performance/refactor changes.
- The 7,000-word windowed-pager stress acceptance passed with 0 failures in `/tmp/SwiftMandarin-vocab-uiqa-large-windowed2.log`; it proves prompt presentation without the former 60-second idle stall and successful adjacent paging. The temporary synthetic-data hook and temporary UI test project were removed before production builds.
- The standalone UI harness emits an expected App Intents metadata message because it does not link AppIntents, plus an iOS 27 simulator duplicate `UIAccessibilityLoaderWebShared` runtime warning. Neither warning is emitted by app source compilation; final app builds are assessed separately.
- Independent correctness, UI/accessibility, and performance/test reviewers found no remaining Critical or Important implementation issue after fixes. Minor recommendations addressed in the slice include resolving the visible term list once per render, localized sort titles, Dynamic Type scaling, a fixed macOS inspector header, and a contextual macOS position label.
- `README.md` and `README.zh-Hans.md` document swipe/Previous/Next continuous browsing in the vocabulary detail flow.

### Repeated-Workflow Packaging Review (last 30 days)

| Workflow | Evidence / confidence | Form | Decision |
|---|---|---|---|
| Cross-platform Swift feature slice with Xcode builds, runtime acceptance, review, and handoff | Recurred across June/July iterations; high confidence | Extend existing | Already covered by `source-command-build-test-deploy-v2` and the separate bootstrap agent-loop worktree; do not create a duplicate global skill. This slice adds only the narrow reusable `scripts/test-vocabulary-paging.sh`. |
| Broad Swift codebase audit and recommendation roadmap | `CODEX_RECOMMENDATIONS.md` plus multiple prior audits; high confidence | Extend existing | Existing codebase-research/review skills and project recommendation docs are adequate; no duplicate asset created. |
| Durable simulator regression tests for critical UI flows | Temporary harnesses were needed repeatedly in this slice and earlier work; high confidence | Project feature | Missing and valuable, but too broad for this one-feature commit; filed as issue #5 rather than creating an overlapping ad-hoc global skill. |
| Scheduled app-quality monitor | No stable cadence or external signal specified; low confidence | Skip | More evidence is required before an automation would have a trustworthy stopping/reporting condition. |

### 9) Remaining Work & Next Steps

- No implementation work remains in this slice. GitHub issue #5 tracks the durable unit/UI test target and CI needed to make the temporary simulator acceptance permanently repeatable.
- **Exact next-session prompt:** “Work only on GitHub issue #4: refactor `StatsView` to respond to available width rather than device idiom. Begin from the latest main branch, preserve existing analytics behavior, verify iPhone portrait/landscape, iPad half/full Split View, narrow/wide macOS windows, and accessibility text sizes, then run both platform builds and update `handoff.md` with evidence.”

### 10) Updates to This File (append-only)

- 2026-07-13T08:51:49Z: Created Iteration 19 task brief, traceability matrix, constrained plan, initial findings, and baseline evidence record immediately before product edits.
- 2026-07-13T08:58:00Z: Recorded green Xcode 27 baseline builds for generic iOS Simulator and macOS; no compiler warnings or errors were found in either filtered log.
- 2026-07-13T09:58:15Z: Recorded implementation, the rejected ID-bound ScrollView and unbounded TabView attempts, the three-page-window recovery, 13/13 deterministic checks, clean production builds, passing gesture/boundary/dismissal UI acceptance, and the passing 7,000-word stress gate.
- 2026-07-13T10:15:53Z: Recorded independent-review fixes (translation gating, single scroll ownership, native mastery semantics, per-action macOS copy feedback, adaptive/accessibility refinements), corrected stress-test evidence to retained-log claims, expanded the paging suite to 18/18, recorded the fresh post-review UI pass and transient-harness recoveries, filed issues #4/#5, and added the repeated-workflow packaging decision plus exact next-session prompt.
- 2026-07-13T10:25:50Z: Recorded final stable-snapshot Xcode 27 builds (both platforms, zero source diagnostics), three clean adversarial re-reviews, bilingual README updates, complete delivery state, and the bounded issue #4 continuation prompt.

## Iteration 20 — Xcode build-graph repair and paging-runner isolation (2026-07-13)

**Last Updated (UTC):** 2026-07-13T15:42:22Z

**Status:** Complete

**Current Focus:** This compiler/build-graph repair is complete; only the account-holder's Personal Team profile renewal remains for physical-device installation.

### 1) Request & Context

- **User request:** Resolve duplicate Compile Sources warnings, the `SwiftMandarinApp.swift` `@main`/top-level-code error, the provisioning timeout, and missing profile reported from the primary checkout.
- **Constraints:** Preserve the Iteration 19 feature, automatic signing identity, and unrelated primary-worktree files. Apple-account/profile issuance cannot be bypassed in source.
- **Scope boundary:** This follow-up hardens the standalone paging check against accidental app-target inclusion. The valid committed project already uses synchronized source membership; generated local duplicate entries were removed in the primary checkout.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R20.1: App target has one entry point | Build iOS Simulator, unsigned generic iOS, and macOS | No `@main` or top-level-code error | Retained xcodebuild logs |
| R20.2: No duplicate sources | Inspect project and build logs | Empty explicit Sources phase; no duplicate warning | Project validation + logs |
| R20.3: Runner is isolated | Execute checks with the opt-in flag; typecheck without it | 18/18 pass when enabled; inert when disabled | Script and compiler output |
| R20.4: Signing diagnosis is actionable | Audit settings, identities, profiles, and Xcode activity | Source correctness separated from Personal Team renewal | Diagnostic record |

### 3) Plan & Decomposition

- [x] Reproduce the original failure and trace every compiler input.
- [x] Remove generated explicit project membership in the primary checkout.
- [x] Replace top-level `main.swift` with a conditional declaration-only runner.
- [x] Run deterministic, structural, localization, iOS, and macOS gates.
- [x] Complete independent review and final hygiene checks.
- [x] Prepare one narrow follow-up changeset for `codex/vocab-detail-swipe-modernization`.

### 4) To-Do & Progress Ledger

- [x] `scripts/test-vocabulary-paging.sh` now opts into `VocabularyPagingChecksRunner` with `VOCABULARY_PAGING_CHECKS`.
- [x] All 18 paging checks pass; disabled-runner typecheck passes.
- [x] iOS Simulator, unsigned generic iOS, and macOS builds pass with zero compiler warnings/errors.
- [x] Independent reviewer found no Critical or Important issue and confirmed the new runner must be staged with the old runner's deletion.

### 5) Findings, Decisions, Assumptions

- **Finding:** The `SwiftMandarin` synchronized folder already supplies app sources. Explicit additions duplicated three app files and compiled the standalone top-level runner into the app.
- **Decision:** Keep the project's explicit Sources phase empty and make the external runner declaration-only and compile-gated as defense in depth.
- **Finding:** Automatic signing is correctly set to team `X8AD8YC886` and bundle ID `linroger022.SwiftMandarin`; the matching development certificate is valid through 2026-08-12. The seven-day Personal Team profile expired on 2026-07-13, and Xcode's online renewal timed out.

### 6) Issues, Mistakes, Recoveries

- A first guard wrapped top-level statements in `#if`, but Swift's `-parse-as-library` parser still rejected their source form. The runner was renamed and execution moved into a conditional `@main` declaration; both enabled and disabled checks pass.
- The open primary Xcode session automatically added the renamed runner to Compile Sources. This became an adversarial proof: all three builds still passed because the guard was effective. The generated membership was removed again.

### 7) Scenario-Focused Resolution Tests

- **Before:** The primary build exited 65, named `scripts/vocabulary-paging-checks/main.swift` as top-level code, and reported three duplicate source entries.
- **After:** All three unsigned/local platform builds succeed without those diagnostics; the project graph remains the synchronized-source design.
- **Verdict:** Compiler regression resolved. Physical iOS installation still requires Xcode to renew the Personal Team profile.

### 8) Verification Summary

- `scripts/test-vocabulary-paging.sh`: 18/18 passed.
- Disabled runner: `swiftc -parse-as-library -typecheck` passed.
- `plutil`, both localization catalogs, staged/unstaged diff hygiene: passed.
- `/tmp/SwiftMandarin-primary-fixed-ios-simulator.log`: build succeeded, zero source diagnostics.
- `/tmp/SwiftMandarin-primary-fixed-ios-device-unsigned.log`: build succeeded, zero source diagnostics.
- `/tmp/SwiftMandarin-primary-fixed-macos.log`: build succeeded, zero source diagnostics.
- Fresh branch-snapshot iOS Simulator and macOS builds passed in `/tmp/SwiftMandarin-branch-final-ios-simulator.log` and `/tmp/SwiftMandarin-branch-final-macos.log`; both contain one success marker and zero warning/error/duplicate/top-level matches.
- Independent review found no Critical or Important issue. It separately verified the disabled runner alone and beside an app `@main`, confirmed the app does not define `VOCABULARY_PAGING_CHECKS`, and confirmed the explicit Sources phase is empty.

### 9) Remaining Work & Next Steps

- No source-code work remains in this repair. Git history and the delivery response carry the follow-up commit/remote metadata.
- For a physical iPhone, refresh/re-authenticate Xcode Settings → Accounts, keep Roger Lin (Personal Team) with automatic signing, unlock/trust the intended device with Developer Mode enabled, and retry so Xcode can register it and issue a fresh seven-day profile.

### 10) Updates to This File (append-only)

- 2026-07-13T15:26:56Z: Added the failure trace, runner hardening, clean build evidence, corrected certificate/profile diagnosis, and remaining delivery gate.
- 2026-07-13T15:42:22Z: Recorded two clean branch-snapshot builds, passing final hygiene, and an independent review with no Critical or Important findings; marked implementation complete pending the immediate commit/push action.

## Iteration 21 — Smooth, completion-safe iOS vocabulary paging (2026-07-14)

**Last Updated (UTC):** 2026-07-13T17:53:45Z

**Status:** Complete

**Current Focus:** Delivered on `codex/vocab-swipe-smoothness`; only an optional physical-device ProMotion trace remains outside the completed software acceptance gates.

### 1) Request & Context

- **User request:** The vocabulary detail swipe is not smooth and can stop halfway through, leaving adjacent pages simultaneously visible. Diagnose the supplied runtime messages and make paging feel continuous and reliable.
- **Visual evidence:** The supplied iPhone screenshot shows word 1,012 of 1,445 with the outgoing and incoming detail pages each occupying part of the viewport after the gesture should have settled.
- **Operational constraints:** Work from `f818a5a` on isolated branch `codex/vocab-swipe-smoothness`; preserve the open prior worktree's unstaged string-catalog/project changes; keep the pager bounded for thousand-word libraries; retain vertical detail scrolling, toolbar navigation, accessibility actions, deletion reconciliation, and iOS 17 compatibility.
- **Scope boundary:** Console messages are fixed only when code tracing ties them to this interaction. An unavailable optional Ollama server and unrelated OS/framework diagnostics are not reasons to broaden this slice.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check (scenario steps) | Expected Outcome | Evidence to Capture |
|---|---|---|---|
| R21.1: Every horizontal gesture settles | Open a middle item; perform slow, short, reversed, fast, and repeated left/right drags | The content follows the finger and always returns to one full page or completes on one full adjacent page; never remains split | Simulator screenshots plus visible headword/counter geometry assertions |
| R21.2: No transition-time identity churn | Observe state/page composition across a completed swipe | Page-controller children remain stable until UIKit reports transition completion | Source invariant plus runtime geometry stability |
| R21.3: Vertical gestures remain vertical | Scroll the long AI explanation and start diagonally biased vertical drags | No unintended page turn and no blocked vertical scrolling | Simulator acceptance run |
| R21.4: Large libraries stay responsive | Open and page inside a synthetic list of at least 1,445, preferably 7,000, terms | Presentation and adjacent paging remain bounded without constructing the full library's detail views | Stress run and source/performance evidence |
| R21.5: Alternatives and mutations remain safe | Use Previous/Next, first/last bounds, mastery/edit/delete/current-term reconciliation | Correct item/count, disabled bounds, no stale or fabricated page | Regression checks and UI assertions |
| R21.6: Scoped diagnostics are understood | Map each supplied console line to app code, configuration, or OS framework | Pager-caused per-frame state warnings are removed or explained; unrelated noise is documented accurately | Warning triage and filtered runtime log |
| R21.7: Cross-platform delivery remains healthy | Run deterministic checks plus iOS Simulator and macOS builds | Zero build errors and no new compiler warnings | Retained logs and clean diff checks |

### 3) Plan & Decomposition

- **Critical path:** First reproduce the split state and trace selection/page-window timing; then stabilize the transition model without reintroducing all-page eagerness; finally validate real gestures, large data, vertical scrolling, mutations, builds, and review.
- [x] Inspect the screenshot, current branch/history, prior paging evidence, and applicable SwiftUI/performance/debug workflows.
- [x] Confirm the rolling-window `TabView` mutates its controllers inside the native interactive transaction.
- [x] Implement and compile one stable, bounded paging architecture.
- [x] Run helper checks, real simulator gesture acceptance, stress/mutation scenarios, and both platform builds.
- [x] Complete two independent review passes, update evidence, commit as `e9ab7c5`, and push `codex/vocab-swipe-smoothness` to origin.

### 4) To-Do & Progress Ledger

- [x] Isolated branch/worktree created from `f818a5a` to avoid the open Xcode session rewriting project membership.
- [x] User screenshot inspected at original resolution; the failure is a real split page, not a static content-clipping issue.
- [x] Three independent read-only investigations agreed on the same transition-time child mutation and classified the supplied warnings.
- [x] Final production policy checks pass 25/25; iOS Simulator, generic iOS device, and macOS builds succeed without matched compiler warnings/errors.
- [x] Three-term real-gesture suite passes canceled, slow, fast, repeated, boundary, toolbar, vertical, and live-mastery scenarios with stable centered geometry.
- [x] The 1,445-term screenshot-scale suite passes completed/canceled and alternating gestures with the same geometry gate.
- [x] Final read-only review reports no actionable findings after the deletion/cancellation and causal-test corrections.

### 5) Findings, Decisions, Assumptions

- **Root cause:** `visibleTermID` drove both `TabView` selection and its `[previous,current,next]` child membership. During B → C, the children changed from `[A,B,C]` to `[B,C,D]` before UIKit finished settling, reindexing the active controllers and permitting the screenshot's split offset.
- **Amplifier:** The same selection change immediately wrote parent `selectedTerm`, forcing the covered 1,445-row vocabulary view to filter/sort, while all three pages instantiated full cached AI-analysis trees.
- **Decision:** Use an O(1) `UIPageViewController` data source with lazily hosted adjacent SwiftUI pages. Commit the selected ID only from UIKit's completed-transition delegate; canceled gestures never mutate selection.
- **Decision:** Preload normal neighbor content but gate heavyweight AI cache loading/layout to the settled page. Explicitly inject the saved-terms store and custom locale into each manually created `UIHostingController` root.
- **Warning triage:** NavigationRequestObserver and Liquid Glass multiple-update messages corroborate transition-time state churn. Ollama localhost refusal is optional-provider configuration; PointerUI/public-settings messages are framework noise; unsafeForcedSync needs a backtrace; the ProvidesDialog mismatch is a real but unrelated App Intent defect.
- **Preservation decision:** The prior worktree's localization/project diffs predate this slice and will not be staged or rewritten here.

### 6) Issues, Mistakes, Recoveries

- **Prior test gap:** The old UI acceptance asserted only that the destination headword existed and was hittable, which remains true in the supplied half-page state. The new test MUST assert centered geometry and stability over multiple samples.
- **Implementation review catch:** Manually hosted SwiftUI pages do not inherit the representable's environment. The design now passes `SavedTermsStore` and `locale` into every hosted root.
- **Performance review catch:** Publishing an `isTransitioning` binding from `willTransitionTo` would itself invalidate the toolbar/sheet at gesture start. Transition state remains coordinator-local; only a completed selection reaches SwiftUI.
- **Compile failure → recovery:** The first build found that a local `host` binding in both page-data-source methods shadowed the `host(for:)` factory, producing “cannot call value of non-function type.” Renaming the local to `currentHost` restored the intended factory call; all subsequent iOS and macOS builds pass.
- **Final-review catch → recovery:** A store mutation is intentionally deferred while UIKit is settling. If the visible term was deleted during a gesture that then canceled, refreshing cached roots was insufficient because UIKit still retained the deleted host. Both touch and programmatic cancellation paths now reconcile against UIKit's actual visible controller, replace any deleted controller immediately, publish the surviving ID, prune the cache, and assert the post-transition three-host bound.
- **Regression-test correction:** The first deletion checks composed existing helpers and therefore would have passed before the coordinator repair. The exact post-transition precedence is now a production model rule (`visible → request → settled → current → first survivor`) used by the coordinator and covered across surviving/deleted/empty matrices. Cache pruning likewise consumes a tested live-ID window; the fast suite now passes 25/25.

### 7) Scenario-Focused Resolution Tests

- **Repro steps:** Open a vocabulary detail near the middle of a large library and drag horizontally far enough to begin a page change, including a slow release near the threshold.
- **Pre-change behavior:** The outgoing and incoming pages can remain side by side, with oversized headwords and actions clipped at both viewport edges; the toolbar counter may already reflect the incoming selection.
- **Change applied:** Replace the rolling-window `TabView` with a lazily populated native page controller whose child set stays stable through the interaction and whose selection commits only after completion.
- **Post-change behavior:** Canceled drags spring fully back; completed drags settle on exactly one adjacent page; parent selection updates only after UIKit completion; neighbor AI trees are inactive; cache retention remains current ± 1.
- **Verdict:** Resolved. The final three-term test sampled every destination headword three times after each gesture (≤2-point drift, center within 2%/8 points) and passed in 107.434 seconds. The 1,445-term stress case passed the same assertions in 73.514 seconds.

### 8) Verification Summary

- **Fast policy checks:** `scripts/test-vocabulary-paging.sh` passes 25/25, including post-transition visible/requested/settled/current/fallback precedence, empty sessions, and live bounded cache IDs.
- **Final builds:** iOS Simulator (`/tmp/SwiftMandarin-smooth-pager-final3-ios.log`), generic iOS device with signing disabled (`/tmp/SwiftMandarin-smooth-pager-final-device.log`), and macOS (`/tmp/SwiftMandarin-smooth-pager-final3-macos.log`) each report `BUILD SUCCEEDED`; filtered output contains no compiler warnings/errors.
- **Real gesture acceptance:** `/tmp/SwiftMandarin-smooth-pager-final3-uiqa.xcresult` passes the 3-term suite in 107.434 seconds; `/tmp/SwiftMandarin-smooth-pager-large-uiqa-3.xcresult` passes the 1,445-term suite in 73.514 seconds. Both assert centered, stable pixels rather than mere element existence.
- **Additional motion probe:** Three measured alternating-swipe iterations completed successfully in `/tmp/SwiftMandarin-smooth-pager-hitch.xcresult`; Xcode exported no numeric hitch samples for this simulator run, so it is not presented as physical 120 Hz frame-pacing evidence.
- **Visual artifact:** `/tmp/SwiftMandarin-smooth-pager-final-centered.png` shows a single centered page after the final repeated-swipe run.
- **Runtime diagnostics:** The only `NavigationRequestObserver` line occurred 0.49 seconds after tapping the Study tab and roughly 10 seconds before the first pager drag; none occurred during 17+ pager gestures. The final run emitted no `glassEffect()` repeated-frame, `unsafeForcedSync`, or `ProvidesDialog` line. One `localhost:11434` probe remains the separately scoped optional Ollama configuration behavior.
- **Review:** The final independent review traced deletion/cancellation, failed programmatic transition, empty-session, pruning, and precedence paths and reported no actionable findings.
- **Hygiene:** `git diff --check`, the project plist lint, localization JSON parse, and duplicate-source scan pass; the project graph and catalog remain untouched.

### 9) Remaining Work & Next Steps

- No pager implementation or delivery work remains. Commit `e9ab7c5` is pushed on `origin/codex/vocab-swipe-smoothness`.
- Recommended release validation: run Instruments/Core Animation on a 120 Hz physical iPhone after provisioning is available, plus a short VoiceOver/Reduce Motion pass. Simulator geometry, behavior, and all compile gates already pass.
- Separate follow-ups, not blockers for this repair: avoid automatic Ollama localhost probing on iPhone and correct App Intent `ProvidesDialog` signatures. GitHub issue lookup was attempted twice but the API TLS handshake timed out, so no potentially duplicate issue was created blindly.

### 10) Updates to This File (append-only)

- 2026-07-13T16:15:22Z: Created Iteration 21 with screenshot-backed criteria, confirmed root cause, isolated-worktree recovery, environment/performance review guardrails, scoped warning triage, and pending compile/runtime gates.
- 2026-07-13T17:08:00Z: The first 1,445-term fixture attempt stopped before app launch because Swift 6 rejected a module-scope inferred array whose element type was declared `private` in the temporary seed utility. The harness type was made internal; no production source was implicated or changed by this failure.
- 2026-07-13T17:14:00Z: The large-library fixture initially remained at three terms because CoreSimulator's preferences daemon still held the old domain; reseeding while the simulator was shut down made the 1,445-term fixture deterministic. The next run opened the correct centered `词1443` page, but the harness expected `1445` instead of the localized counter label `1,445`; the expectation was corrected before replaying gestures.
- 2026-07-13T16:52:20Z: Recorded the initial compiler-detected name-shadowing mistake and its narrow correction before rerunning the iOS build.
- 2026-07-13T17:21:00Z: Independent final review found the deleted-current-term plus canceled-swipe seam. The coordinator now reconciles the controller UIKit actually leaves visible after every cancellation, replaces stale deleted content, and prunes/asserts bounded cache state.
- 2026-07-13T17:31:00Z: The post-review three-term replay passed every swipe/geometry assertion, then the added live-mastery mutation step failed before interaction because XCUITest classifies a button-styled SwiftUI `Toggle` as `Switch`, not `Button`. The selector was corrected and the acceptance run restarted; production behavior was not implicated.
- 2026-07-13T17:38:00Z: Re-review accepted the production mutation repair but rejected the first regression check as insufficiently causal. Extracted and adopted the exact post-transition resolver plus live cache-window policy, expanded the survivor/deletion/empty matrix, and passed all 25 fast checks.
- 2026-07-13T17:50:13Z: Final exact-binary replay passed 107.434 seconds of geometry-checked gestures and live mutation; 1,445-term stress, three platform builds, policy checks, hygiene, warning timing, screenshot inspection, and independent review all pass. Marked Iteration 21 complete pending only commit/push delivery.
- 2026-07-13T17:53:45Z: Committed the verified repair as `e9ab7c5` and pushed `codex/vocab-swipe-smoothness` to origin; the worktree was clean immediately after delivery.

## Iteration 22 — Merge smooth vocabulary paging to main (2026-07-14)

**Last Updated (UTC):** 2026-07-13T18:10:15Z

**Status:** Complete

**Current Focus:** Merge commit `2c669f1` is delivered to `origin/main`; this closing record documents the verified remote result.

### 1) Request & Context

- **User request:** Merge the committed and pushed smooth-paging branch into `main` and resolve any conflicts.
- **Preservation constraint:** The primary `/Users/rogerlin/XCode-Projects/SwiftMandarinShortcuts` main worktree contains staged, unstaged, and untracked user/Xcode changes. Those bytes and index entries MUST remain untouched.
- **Integration strategy:** Fetch current remote refs, prepare a no-fast-forward merge from `origin/main` in `/Users/rogerlin/XCode-Projects/SwiftMandarinShortcuts-main-merge`, run merge-sensitive gates, then push the resulting commit directly to `origin/main`.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R22.1: Integrate the verified branch | Inspect merge parents and ancestry | Main contains all commits through `c8d3736` | `git merge-base --is-ancestor` and merge commit parents |
| R22.2: Resolve conflicts safely | Run the merge with `--no-commit` and inspect unmerged paths | No unresolved paths; any conflict is resolved without weakening the tested pager | `git diff --name-only --diff-filter=U` |
| R22.3: Preserve live user work | Compare the primary worktree status before and after integration | Its staged, unstaged, and untracked paths remain present and are never stashed/reset | Recorded status snapshots |
| R22.4: Keep main releasable | Run policy, project hygiene, iOS Simulator, generic iOS, and macOS builds | All gates pass without new source diagnostics | Retained logs and command output |
| R22.5: Deliver remotely | Push the verified merge commit to `origin/main` and fetch/verify | Remote main equals the merge commit and contains the feature tip | Remote SHA and ancestry checks |

### 3) Plan & Progress

- [x] Read the current handoff, fetch `origin`, and audit every worktree and branch tip.
- [x] Confirm `origin/main` is `6c3d9aa`, the feature tip is `c8d3736`, and main is the direct merge base.
- [x] Prepare a no-fast-forward, no-commit merge in the isolated integration worktree.
- [x] Confirm Git reports an automatic clean merge and zero unmerged paths.
- [x] Run deterministic checks, project hygiene, and all platform builds against the exact merge tree.
- [x] Create merge commit `2c669f1`, push `HEAD:main`, and verify its remote SHA and feature ancestry. Temporary integration cleanup follows the closing documentation commit.

### 4) Findings & Decisions

- **Finding:** There is no repository-level content conflict because all four feature commits descend directly from the current `origin/main` tip. A no-fast-forward merge is retained to make the requested integration event explicit and reviewable.
- **Decision:** Do not merge in the checked-out primary `main` worktree. Its local changes overlap the pager paths and Xcode project/catalog state; stashing or switching its base would introduce needless risk.
- **Conflict result:** Git completed the merge calculation automatically and stopped before commit as requested. `git diff --name-only --diff-filter=U` returned no paths, so no manual conflict choice was necessary.

### 5) Verification & Remaining Work

- **Completed:** Remote refs fetched; ancestry checked; clean isolated merge tree created; primary worktree left untouched.
- **Policy/hygiene:** `scripts/test-vocabulary-paging.sh` passes 25/25; staged diff hygiene, project plist validation, localization JSON parsing, empty explicit Sources membership, and runner-exclusion checks all pass.
- **Builds:** iOS Simulator (`/tmp/SwiftMandarin-main-merge-ios-simulator.log`), unsigned generic iOS device (`/tmp/SwiftMandarin-main-merge-ios-device.log`), and macOS (`/tmp/SwiftMandarin-main-merge-macos.log`) each report `BUILD SUCCEEDED` with no filtered error/warning/duplicate/top-level-code diagnostic.
- **Tree parity:** Every production, user-facing documentation, and test path matches verified feature tip `c8d3736`; the only intentional tree delta is this Iteration 22 merge record in `handoff.md`.
- **Merge commit:** `2c669f102ff020b1d5d76dba77fadfdd147e65ad` has parents `6c3d9aa` (prior main) and `c8d3736` (verified feature tip), so the feature remains first-class ancestry rather than a squash.
- **Remote delivery:** A normal non-force push advanced `origin/main` from `6c3d9aa` to `2c669f1`; local `origin/main` resolves to the same SHA and contains `c8d3736` as an ancestor.
- **Preservation:** The primary dirty main worktree was never stashed, reset, checked out, or written during integration. Its Xcode-generated explicit Sources regression and untracked `InfoPlist.xcstrings` remain excluded from remote main.
- **Remaining:** No source, conflict, build, or remote-delivery work remains. Remove only the clean temporary integration worktree/branch after this record is committed and pushed.

### 6) Updates

- 2026-07-13T18:04:13Z: Created the main-integration record after fetching remote refs, preserving the dirty primary worktree, and preparing a conflict-free no-commit merge in a dedicated worktree.
- 2026-07-13T18:08:29Z: Passed all 25 policy checks, merge hygiene, and clean iOS Simulator, unsigned iOS device, and macOS builds against the exact staged merge tree; only commit/push/remote verification remains.
- 2026-07-13T18:10:15Z: Created two-parent merge commit `2c669f1`, pushed it normally to `origin/main`, verified the remote SHA and feature ancestry, and marked main integration complete.

## Iteration 23 — Tutor-grade AI explanation prompt (2026-07-21)

**Last Updated (UTC):** 2026-07-20T19:04:21Z

**Status:** Complete

**Current Focus:** Merge commit `a0b09dc` is delivered to `origin/main`; this record closes the verified AI prompt slice.

### 1) Request & Context

- **User request:** Make AI translations and explanations more useful, thorough, detailed, engaging, easy to understand, and pleasurable to read; specifically explain what individual characters mean and how they reveal the essence of a word.
- **Operational constraints:** The primary worktree contains staged vocabulary-paging/UI work. That work MUST remain intact and MUST NOT be included in this slice's edits or verification claims.
- **Scope boundary:** Rich pedagogy belongs to the structured word-explanation flow. Plain AI translation remains translation-only because photo, live speech, Reader, history, TTS, screenshots, and Shortcuts consume it as raw target-language text.
- **Plan:** `docs/handoff/ai-explanation-quality/PLANS.md` records the approved prompt design, invariants, risks, and checks.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R23.1: Character-aware semantic explanation | Generate/inspect the Chinese prompt contract | It accounts for every character/morpheme, assigns an honest semantic/phonetic/grammatical/other role, and bridges the parts to the modern whole-word sense | Deterministic prompt check |
| R23.2: Engaging but rigorous prose | Inspect field roles and style guardrails | Answer-first, concrete, warm, scan-friendly prose; no repetition, filler, or invented etymology | Contract assertions + review |
| R23.3: Sense-aware usefulness | Inspect requests with/without context | Context/pinyin selects the intended sense; default is the common modern sense | Prompt-payload assertions |
| R23.4: Provider parity | Trace Apple, Ollama, and cloud paths | All three use the shared teacher/request contract and reinforced schemas | Source assertions + build |
| R23.5: Preserve consumers and data | Review output model/cache and plain translation methods | Existing result/cache shape remains decodable; translation still returns only target text | Diff review + builds |
| R23.6: Cross-platform safety | Build iOS Simulator and macOS | Both builds succeed with no new source diagnostics | Retained build logs |

### 3) Plan & Decomposition

- [x] Capture the dirty baseline, recent history, continuity files, prompt call graph, and output contracts.
- [x] Deploy parallel read-only reviews for provider mapping, UI/decoder constraints, and language-pedagogy quality.
- [x] Implement one pure shared prompt builder and route every explanation provider through it.
- [x] Add credential-free deterministic prompt checks.
- [x] Run focused checks, iOS/macOS builds, and independent diff review; fix findings.
- [x] Record final evidence and residual live-model validation needs.

### 4) To-Do & Progress Ledger

- [x] Confirmed `AIWordExplanationService` is clean at baseline; its three explanation routes are safe to edit without overwriting the staged paging implementation.
- [x] Confirmed `AIWordExplanationView` and `VocabularyView` contain staged paging work; avoid UI/schema expansion unless source evidence makes it necessary.
- [x] Production prompt implementation: shared explanation and translation builders, reinforced typed/Ollama/cloud field guidance, safer exact-headword filtering, bounded arrays, and semantic response validation.
- [x] Deterministic verification: 75 prompt/JSON/matcher checks plus 15 provider-wiring checks pass; both target builds succeed.

### 5) Findings, Decisions, Assumptions

- **Finding:** The app has two different AI contracts. `translate` must return only a target-language string, while `generateExplanationWithProvider` returns the rich `WordExplanationResult` displayed as a multi-section tutor card.
- **Finding:** Apple Intelligence uses one short instruction block, while Ollama/cloud share another; all provider schemas use broad descriptions such as “cultural/contextual nuance,” so character composition and engaging pedagogy are not currently guaranteed.
- **Decision:** Keep the stable structured result shape. Put direct translation plus semantic essence in `definition`; put character-by-character composition and the literal-to-modern bridge in `nuances`; sharpen the distinct jobs of the remaining fields.
- **Decision:** Treat context/headword/pinyin as untrusted data and delimit them in a JSON payload rather than interpolating raw context into imperative prose.
- **Finding:** The value called `context` is often a saved native-language gloss (`term.glossText`), not an attested encounter sentence. The payload now names it `senseHintOrContext`, and the teacher contract forbids quoting it or inventing a scene around it.
- **Decision:** Preserve the nine-field stored result shape. The direct translation + semantic essence belongs in `definition`; synchronic character/morpheme contributions and the bridge to the lexicalized whole belong in `nuances`.
- **Decision:** Optional synonyms, antonyms, collocations, examples, and grammar may be empty when uncertain. The old Foundation Models minima were removed because completeness pressure encouraged fabricated relations and filler.
- **Decision:** Cap retained output at 3 contexts/examples, 2 synonyms/collocations, and 1 antonym. Exact anchors use case-insensitive token boundaries for English (`Charge` matches `charge`, while `running` is not itself an exact `run` anchor) and exact character sequences for Chinese. Once a generated set has one exact anchor, natural inflected or separated forms of the same lexeme are retained.
- **Decision:** Cross-language definitions lead with the closest natural translation; same-language directions instead require a non-circular plain-language definition and paraphrased example/collocation glosses.
- **Finding:** Tolerant cloud decoding previously allowed `{}` to be cached. Every provider now validates substantive `definition` and `nuances` fields before caching. This preserves the honest uncertainty path: malformed or unidentified items explain what cannot be established in those two fields while other unsupported content remains empty.
- **Assumption:** A credential-free prompt-contract check plus both platform builds is proportionate implementation evidence. Actual prose quality across models still needs a live-provider sample run; no model generation was used as proof in this slice.

### 6) Issues, Mistakes, Recoveries

- **Prompt-builder interpolation mistake → detection → recovery:** The first standalone typecheck warned that prompt variables were unused; source inspection showed the initial patch had dropped Swift interpolation backslashes. The strings were corrected, a warning-free standalone typecheck was rerun, and the production prompt suite now asserts interpolated language names and JSON payload values.
- **Independent pedagogy review → prompt contradictions → recovery:** Review found that exact-headword-everywhere wording blocked natural English inflections and Chinese separable forms, that a naive character rule could invent meanings for phonetic/function elements, and that same-language directions could produce circular “translations.” The final contract uses one exact anchor plus natural forms, classifies every Chinese component by its honest role, handles particles grammatically, and switches same-language fields to definitions/paraphrases.
- **Independent implementation review → schema/validator fixes:** Review found unconditional Chinese-style wording in provider schemas, a strict completeness threshold that rejected the prompt's honest uncertainty fallback, and temporary `String`/`Ollama.Value` inference build errors. Direction-aware schema descriptions, two irreducible teaching fields, and explicit `Ollama.Value` annotations resolved all three; fresh builds passed.
- **Inherited project-file regression → isolation:** Initial builds in the primary worktree reported duplicate Compile Sources entries for `VocabularyPaging.swift`, `VocabularyView.swift`, and `AIWordExplanationView.swift`. The unstaged Xcode-generated `project.pbxproj` diff caused them and remains excluded. Fresh builds on current `origin/main` plus the AI commit emit no warning or error.
- **Build-report wrapper mistake → retained-log recovery:** The first parallel wrapper used zsh's read-only `status` variable after both `xcodebuild` processes had finished, so the wrappers exited before printing their results. Direct inspection of the complete retained logs confirmed one `BUILD SUCCEEDED` marker and zero warning/error lines for each platform; the implementation did not fail or change.

### 7) Scenario-Focused Resolution Tests

- **Chinese scenario:** `学习 (xuéxí)` with a sense hint or encounter context must request a natural translation, the core idea, `学` and `习` contributions, the compositional bridge, real usage decisions, one exact anchor plus useful natural forms, and an accurate memory cue without claiming folk etymology.
- **English scenario:** An English headword must produce explanations in Simplified Chinese when that is the interface language, keep pinyin fields empty, and discuss genuine word parts only when they clarify meaning.
- **Post-change behavior:** The generated Chinese contract explicitly accounts for each Han character/bound morpheme, giving a core meaning only to semantically active parts and naming phonetic, transliterated, grammatical, fossilized, or uncertain roles honestly. It then requires a scan-friendly parts-to-whole bridge and useful contrast; English uses genuine morphology only when helpful. Both directions use safely JSON-encoded inputs and a warm, answer-first, anti-filler style.
- **Verdict:** Contract and build verification passed; live prose sampling remains pending provider/device availability.

### 8) Verification Summary

- `scripts/test-ai-prompt-contracts.sh`: 75/75 prompt, language-direction, same-language non-circularity, JSON round-trip, translation-invariant, character-role, schema, and exact-anchor checks passed; 15/15 provider-wiring/semantic-validation checks passed.
- Standalone `swiftc -parse-as-library -typecheck SwiftMandarin/Services/AIExplanationPromptBuilder.swift`: passed with no diagnostics.
- Clean-feature iOS Simulator Debug build: `** BUILD SUCCEEDED **` in `/tmp/SwiftMandarin-ai-feature-ios.log`; zero warning/error lines.
- Clean-feature macOS Debug build: `** BUILD SUCCEEDED **` in `/tmp/SwiftMandarin-ai-feature-macos.log`; zero warning/error lines.
- Current pager regression suite: `scripts/test-vocabulary-paging.sh` passes 25/25 on the combined tree.
- Project/localization hygiene: project plist lint, localization `jq empty`, empty explicit Sources membership, runner exclusion, and `git diff --check` all pass.
- `git diff --check`: passed.
- Independent Swift/integration and adversarial language-pedagogy reviews found no remaining Critical or Important issue after their findings were resolved.
- Delivery: feature commits `4033e7b` and `f8f06cb` were pushed on `origin/codex/ai-translation-explanations`; two-parent merge `a0b09dcd2d738da16e09cb4a7fc6c438eddc2cab` was pushed normally to `origin/main`, and remote ancestry checks confirm both feature commits are included.

### 9) Remaining Work & Next Steps

- No implementation work remains for this slice.
- Live-provider quality sampling remains valuable; deterministic checks prove the prompt and wiring, not the factual quality of any model's prose. Previously cached explanations intentionally remain compatible and unchanged; use the existing Regenerate action to obtain a new explanation under this prompt.
- No commit, merge, or delivery work remains. The primary dirty worktree's stale pager index, generated project diff, and unrelated untracked InfoPlist catalog remain preserved locally and excluded from main.

### 10) Updates to This File (append-only)

- 2026-07-20T17:42:19Z: Created the AI prompt brief, acceptance matrix, plan, scope protections, initial findings, and scenario checks before production edits.
- 2026-07-20T17:59:59Z: Recorded shared prompt implementation, output guardrails, 69 passing deterministic checks, two successful platform builds, the recovered interpolation mistake, inherited warning boundary, and pending final reviews.
- 2026-07-20T18:17:42Z: Resolved all final-review findings, added role-aware character teaching, same-language non-circular definitions, exact-anchor-plus-natural-form behavior, scan-friendly output, compatible uncertainty validation, and direction-aware provider schemas; recorded 90 passing checks and fresh green iOS/macOS builds; marked Iteration 23 complete.
- 2026-07-20T18:59:05Z: Replayed the isolated AI implementation onto current `origin/main` as `4033e7b`, preserving the primary worktree and the newer merged pager implementation; clean-branch verification and delivery follow.
- 2026-07-20T19:02:25Z: Passed 75/75 prompt checks, 15/15 provider-wiring checks, 25/25 pager checks, project/localization hygiene, and clean iOS/macOS builds on the exact feature tree; only commit, push, merge, and remote verification remain.
- 2026-07-20T19:04:21Z: Pushed the two feature commits, created and pushed two-parent merge `a0b09dc` to `origin/main`, verified remote SHA and feature ancestry, and marked Iteration 23 complete; the primary dirty worktree remains untouched.

## Iteration 24 — MiniMax AI Audio and Multimodal translation (2026-07-21)

**Last Updated (UTC):** 2026-07-20T21:44:47Z

**Status:** Complete

**Current Focus:** MiniMax AI Audio and Multimodal audio input are implemented, verified, and delivered to remote `main`.

### 1) Request & Context

- **User request:** Add a Settings-toggleable MiniMax AI Audio mode; route every speak/audio action through it when enabled; save generated audio persistently and make it exportable; research and test MiniMax audio; rename Photo to Multimodal; and let users record or upload audio for transcription into the existing editor or direct translation.
- **Operational constraints:** The primary checkout remains intentionally dirty on `codex/ai-prompt-source`. All Iteration 24 edits occur in isolated worktree `/tmp/swiftmandarin-minimax-audio.fCBqXb/worktree`, branch `codex/minimax-ai-audio`, based on clean `origin/main` commit `329ad5f`. The primary checkout MUST NOT be reset, stashed, switched, or included.
- **Secret boundary:** The user supplied a credential for testing. It MUST NOT be repeated, written into source/docs/tests/build settings/logs, included in shell command text, or committed. The existing Keychain service already contains an `apikey.minimax` item and is the only permissible credential source for live testing.
- **Plan:** `docs/handoff/minimax-ai-audio/PLANS.md` is the detailed approved architecture and verification contract.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R24.1: Toggleable global AI Audio | Toggle in macOS/iOS AI Settings; invoke representative speak actions from Translate, vocabulary, drills, photo, conversation, and App Intents | Enabled routes through one MiniMax-backed `SpeechService`; disabled uses current system voice | Source call graph + UI/runtime scenarios |
| R24.2: Strict, safe MiniMax TTS | Exercise success, malformed hex, application error, missing key, cancellation, and over-limit input | Only fully valid responses play/persist; failures are actionable, secret-safe, and fall back once | Deterministic client checks + live smoke |
| R24.3: Persistent cache | Generate, replay, relaunch, and replay offline | Same settings/text reuse one non-empty Application Support MP3 with no duplicate paid call | Cache metadata/file evidence |
| R24.4: Exportable library | Open library, play, export, inspect exported file, delete, clear | Valid MP3 opens outside the app; file and metadata lifecycle stay consistent | UI scenario + file inspection |
| R24.5: Multimodal audio input | Record and import English/Mandarin audio; choose Transcribe to Editor | Permission/progress/errors are clear and final transcript fills the existing editor and analysis flow | Simulator/macOS scenario |
| R24.6: One-action audio translation | Choose Translate Audio for both language directions | Transcript becomes editable source text before the existing translation result appears | UI/state scenario + history check |
| R24.7: Honest provider boundary | Inspect network paths and privacy copy | MiniMax receives only TTS text; Apple Speech handles audio transcription; no deprecated GroupId API | Source audit + docs |
| R24.8: Cross-platform delivery | Run deterministic checks, secret scan, iOS Simulator and macOS builds | All gates pass with no new source diagnostics and no credential bytes in the tree/history | Retained logs + hygiene output |

### 3) Plan & Decomposition

- [x] Preserve the dirty primary checkout and create an isolated feature worktree from current remote main.
- [x] Research current official MiniMax international/mainland APIs, voices, models, response semantics, limits, errors, pricing, and persistence implications.
- [x] Confirm current MiniMax public APIs do not support general uploaded-audio transcription; choose Apple Speech → existing translation for the audio-input flow.
- [x] Map the central `SpeechService`, all speak call sites, Keychain/provider settings, Photo editor/translation seams, Speech framework, entitlements, and export patterns.
- [x] Implement strict synthesis, persistence/cache, central routing/playback, and credential-free tests.
- [x] Implement shared AI Audio settings, library management, playback, and export.
- [x] Implement record/import transcription and direct translation in Multimodal.
- [x] Run live/keyless/runtime/build/review gates, resolve implementation findings, push the feature branch, and deliver a verified two-parent merge to remote `main`.

### 4) Findings, Decisions, Assumptions

- **API finding:** Current MiniMax TTS is `POST /v1/t2a_v2` with Bearer auth. Non-streaming `output_format: hex` returns MP3 bytes in `data.audio`; success requires HTTP 2xx, `base_resp.status_code == 0`, non-null data, `data.status == 2`, and strict non-empty hex decoding.
- **Model decision:** Default interactive speech to `speech-2.8-turbo` for lower latency/cost; expose `speech-2.8-hd` as a quality option. Default output is mono MP3, 32 kHz, 128 kbps.
- **Voice decision:** Use a small documented cross-region set rather than a stale 300-voice catalog. Initial defaults are `Chinese (Mandarin)_News_Anchor` and `English_Graceful_Lady`.
- **Transcription finding:** Neither the complete current documentation index nor the file-upload contract provides general STT/audio translation. The old Realtime GroupId interface is historical and MUST NOT anchor a new feature.
- **Architecture decision:** Keep every current call site behind `SpeechService`; no view gets direct MiniMax network logic. Stable `AppTab.photo` identity is preserved while visible labels become Multimodal.
- **Fallback decision:** AI Audio remains opt-in. Missing configuration or a failed request records a visible status and performs one local system-speech fallback so existing learning actions remain usable.
- **Security finding:** A matching MiniMax Keychain entry already exists. Live tests can read it internally without printing it; no pasted credential needs to enter a command or file.
- **Persistence decision:** Generated speech is keyed by normalized text plus all synthesis-affecting settings. Matching clips replay from Application Support before the Keychain is consulted, so a previously generated clip remains available offline. Concurrent matching requests coalesce into one paid synthesis operation.
- **Recovery decision:** A malformed saved-audio index is transactionally replaced and cache-shaped orphaned files are reconciled. A valid index from a future schema is never mutated implicitly; the UI presents the typed error and offers an explicit destructive clear.
- **Concurrency decision:** Speech and Multimodal pipelines use request identities and exact player/utterance ownership. Cancelled or superseded image, audio-copy, transcription, translation, and playback work cannot overwrite a newer user action.
- **Session decision:** A single source-audio coordinator prevents recording and imported-audio preview from competing across windows. Interruption and route-change errors remain visible and interrupted recordings remain recoverable.

### 5) Scenario-Focused Resolution Tests

- **TTS scenario:** Enable AI Audio, speak a short Mandarin word and English sentence, validate/play persisted MP3s, repeat both to prove cache reuse, then disable networking and replay.
- **Fallback scenario:** Remove/withhold a test credential or inject an API failure and confirm a clear status plus exactly one system-speech fallback.
- **Multimodal scenario:** Record and import audio, preview it, transcribe each language into the editor, edit the transcript, and run normal analysis; repeat with Translate Audio to prove one-action composition.
- **Export scenario:** Export a generated record through Files/Finder, open the copy outside SwiftMandarin, then delete the library record and verify its private cached file disappears without deleting the exported copy.
- **Post-change behavior:** The Settings toggle switches the app-wide `SpeechService` between system speech and MiniMax speech; every existing speak surface and App Intent remains behind that router. Generated MP3s persist in an app-private library with replay, share/export, delete, and clear controls. The visible Photo label is now Multimodal, where recorded or imported audio can be previewed, transcribed into the existing editor, or transcribed and translated through the existing translation pipeline.
- **Verdict:** Resolved. Production implementation, strict offline contracts, a live MiniMax synthesis, cache/recovery behavior, localization/privacy checks, and both target builds pass.

### 6) Issues, Mistakes, Recoveries

- **Shell invocation mistake → immediate correction:** The first final contract invocation explicitly launched the zsh runner with `bash`, so zsh's `${0:A:h:h}` path modifier was interpreted as an unbound shell variable. The runner itself was unchanged; invoking it with its declared `#!/bin/zsh` shell immediately passed all 101 checks. The retained success command is `zsh scripts/test-minimax-audio-contracts.sh`.
- **Stale async write risk → request ownership:** Review found that cancelled photo/audio work could still commit after a newer user action. Synchronous request IDs now guard every input preparation, recognition, transcription, and translation state write, including Clear and Retry paths.
- **Hidden/corrupt library risk → explicit recovery:** Review found that decoding an unsupported future index or malformed index could hide files or accidentally mutate unknown data. Future schemas are now read-only until explicit Clear; malformed v1 data uses transactional rollback and orphan reconciliation.
- **Fallback/offline usability risk → cache-first routing:** Review found that requiring a credential before cache lookup made saved clips unusable offline. The router now resolves a matching persisted clip before reading Keychain and asks for a key only on cache miss.
- **Clear-versus-generation race → coordinated destructive barrier:** Final review found that a generation already queued in `repository.save` could recreate a clip after Clear All. The shared pipeline now blocks new speech, retains every cancelled task handle, awaits all generation completion, and only then clears persisted audio. A delayed-response regression scenario proves no MP3 appears after clear returns and that later generation still works.
- **Preview setup failure → audio-session cleanup:** Final review found that iOS playback-session activation could succeed before player decoding failed, leaving other audio ducked because no player/URL marked ownership. The failure path now always deactivates the preview session and notifies other audio.
- **Final transcript plus stream-end error → transcript wins:** Apple Speech may deliver a valid final transcript and an error together. File transcription now accepts a nonempty final result before evaluating the companion error, matching the established live-recognition invariant.
- **Cancel then repeat → separate retiring generations:** Retaining a cancelled task in the joinable map fixed Clear All but briefly allowed an immediate same-text replay to inherit cancellation. Cancelled tasks now move to a non-joinable retiring set that Clear All can still drain; the next tap always creates fresh synthesis.
- **Invalid iOS recording options → physical-device-safe session:** Final SDK-header review found `.duckOthers` invalid for the record-only category and `.notifyOthersOnDeactivation` invalid during activation. Recording now uses `.record`/`.measurement` with no options and reserves notification for deactivation.
- **Downstream translation ownership → awaited parent result:** Translate Audio now retains its progress and Cancel control through the parent-owned translation. Cancellation invalidates the exact translation request; success or failure returns to the audio pane instead of leaving a stale “continuing” message.
- **Growing import → bounded during copy:** File metadata is no longer the only 100 MB guard. The chunked importer tracks cumulative bytes and aborts/removes the temporary copy immediately if the source grows past the limit.

### 7) Verification Summary

- Remote main and isolated branch baseline recorded at `329ad5f`; the dirty primary status was captured and remains untouched.
- Official MiniMax global/mainland API overview, T2A HTTP contract, system voice lists, error codes, pricing/rate limits, file upload, and documentation index were reviewed. No current public STT endpoint was found.
- Existing Keychain metadata confirms `linroger022.SwiftMandarin.secrets` / `apikey.minimax` exists; its value was never displayed.
- Source audit confirms all production read-aloud actions already call `SpeechService`, so central routing can cover the app without per-view API integrations.
- Keychain-backed live MiniMax TTS passed for both supported learning languages against `https://api.minimaxi.com/v1/t2a_v2`: Mandarin decoded to a 39,156-byte MP3 with a matching reported size and 2,340 ms duration; English decoded to a 63,924-byte MP3 with a matching reported size and 3,888 ms duration. `file` identified both as 128 kbps, 32 kHz, mono MPEG Layer III, and `afplay` decoded/played both successfully. The smoke harness printed only status/size/duration/format and never the credential or authorization header.
- The production `MiniMaxAudioClient` live smoke synthesized and strictly decoded a 48,948-byte MP3 in 2,952 ms. The file is 128 kbps, 32 kHz, mono MPEG Layer III and played successfully through `afplay`.
- `zsh scripts/test-minimax-audio-contracts.sh` passes 111/111 deterministic checks against production request/response decoding and persistence code, including endpoint/auth/body shape, application failures, strict hex decoding, cache identity, concurrent coalescing, cancel-then-repeat, save/reload, malformed-index recovery, future-schema immutability, coordinated in-flight clear, and explicit reset.
- Fresh macOS Debug build on Xcode 27 beta: `** BUILD SUCCEEDED **` in `/tmp/SwiftMandarin-minimax-macos-final-latest.log`, with zero `warning:` and zero `error:` lines.
- Fresh generic iOS Simulator Debug build on Xcode 27 beta: `** BUILD SUCCEEDED **` in `/tmp/SwiftMandarin-minimax-ios-final-latest.log`, with zero `warning:` and zero `error:` lines.
- `git diff --check`, localization JSON parsing, Xcode project/entitlement plist lint, credential-pattern scan, and unexpected audio-artifact scan all pass. No credential or generated audio was found in the repository tree.
- Exact merged-tree verification repeated 111/111 contracts plus fresh macOS and iOS Simulator builds in `/tmp/SwiftMandarin-minimax-merge-macos.log` and `/tmp/SwiftMandarin-minimax-merge-ios.log`; both contain one success marker and zero warning/error lines.
- Delivery: feature commit `713bc5530e98fa982b6e3b507cf8620f9cc83b64` is pushed on `origin/codex/minimax-ai-audio`; two-parent merge `34cfb41471b5df349edfdd72c0739201046628ef` is pushed on `origin/main` with parents `329ad5f` and `713bc55`.

### 8) Remaining Work & Next Steps

- No implementation, verification, merge, or feature-delivery work remains for this slice.
- The credential pasted into chat should be rotated before production use because chat exposure cannot be undone, even though the implementation and Git tree never stored it.

### 9) Updates to This File

- 2026-07-20T19:55:55Z: Created Iteration 24 with isolated-worktree protections, secret boundary, source-backed API findings, traceable requirements, architecture decisions, and pending implementation/verification ledger.
- 2026-07-20T20:02:30Z: Completed live Mandarin and English MiniMax TTS calls from the existing Keychain credential, strictly decoded and atomically saved both MP3s, matched service-reported byte counts, validated their media format, and played them with the system decoder without exposing the key.
- 2026-07-20T21:24:43Z: Completed the global MiniMax router, persistent/exportable library, Multimodal recording/import/transcription/translation flow, strict persistence and concurrency hardening, privacy/localization work, 101 deterministic checks, production-client live synthesis, and warning-free macOS/iOS builds; marked implementation complete pending isolated Git delivery.
- 2026-07-20T21:33:21Z: Resolved final review findings for in-flight generation versus Clear All, iOS preview-session cleanup, and final-transcript/error ordering; expanded the deterministic suite to 106 checks and reran warning-free incremental builds on both targets.
- 2026-07-20T21:40:59Z: Completed the last adversarial pass: separated retiring from joinable generations, added deterministic cancel-then-repeat coverage, corrected physical-device recording options, bounded growing imports during copy, and extended audio-operation ownership through translation completion; 111 checks and both warning-free builds pass.
- 2026-07-20T21:44:47Z: Pushed feature commit `713bc55`, created and verified two-parent merge `34cfb41` in a second clean worktree, repeated 111 contracts and fresh warning-free builds on the exact merge, pushed remote `main`, and marked Iteration 24 complete.

## Iteration 25 — Live MiniMax audio catalog and batch audio (2026-07-21)

**Last Updated (UTC):** 2026-07-21T00:06:03Z

**Status:** Complete

**Current Focus:** No feature work remains; preserve the verified delivery record and address the separate credential/log-history security follow-up only with explicit coordination.

### 1) Request & Context

- **User request:** Pull the latest MiniMax speech models, Mandarin voices, and English voices; repair the Mandarin preview that currently sounds English; generate MiniMax audio during the batch AI translation/analysis feature; and support macOS, iOS, and iPadOS 27 Golden Gate.
- **Operational constraint:** The primary checkout at `/Users/rogerlin/XCode-Projects/SwiftMandarinShortcuts` contains unrelated staged, unstaged, and untracked user work. This slice is isolated in `/tmp/swiftmandarin-audio-catalog.4jzfw2/worktree` on `codex/minimax-audio-catalog-batch`, based on clean `origin/main` commit `4879c53`; the primary checkout MUST NOT be stashed, reset, switched, or edited.
- **Secret boundary:** Live research uses the existing Keychain credential internally. The credential pasted into chat MUST NOT be repeated, placed in commands/files/logs/tests, or committed, and it should be rotated after testing.
- **Detailed plan:** `docs/handoff/minimax-audio-catalog-batch/PLANS.md` defines the architecture, invariants, risks, and evidence contract.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R25.1: Current speech catalog | Refresh Settings against the selected MiniMax region and inspect model/voice choices | Latest Speech 2.8 HD/Turbo appear first; six older compatible 2.6/02/01 models are clearly separated; live friendly Mandarin/English voices and the last public offline snapshot remain usable | Contract tests + redacted live counts + UI scenario |
| R25.2: Correct Mandarin/English preview | Inspect request JSON and synthesize both preview phrases | Mandarin sends `Chinese`; English sends `English`; corrected cache identities cannot reuse old `auto` audio | Request fixtures + live MP3 validation |
| R25.3: Safe catalog state | Exercise slow/failed/empty refresh, region change, custom voice, relaunch | Latest request wins; prior catalog and valid selection survive; no credential is persisted | Deterministic state tests + secret scan |
| R25.4: Batch audio | Enable the batch option and process mixed/new/cached terms | Explanations complete; each eligible term gains persistent no-playback audio; cache hits avoid duplicate calls | Controller/store contracts + scenario |
| R25.5: Failure and cancellation safety | Inject TTS failures, cancel at each paid-work boundary, delete/clear cache during review or generation, and replace the MiniMax key | Completed explanation/audio remains visible; ambiguous/systemic synthesis errors fail closed; stale work cannot republish deleted audio or expand reviewed charges | Regression fixtures |
| R25.6: Native cross-platform UX | Exercise settings and batch controls on Mac, iPhone, and iPad | Adaptive, localized, accessible controls with understandable cost/privacy/progress/error states | UI review + screenshots/hierarchy when available |
| R25.7: Platform delivery | Build macOS, generic iOS, iPhone Simulator, and iPad Simulator with Xcode 27 | All builds succeed with no new source warnings/errors | Retained build logs |

### 3) Plan & Progress

- [x] Preserve the dirty primary checkout and create an isolated branch/worktree from current remote main.
- [x] Review official current MiniMax T2A, model release, voice-management, and async batch documentation.
- [x] Run a credential-safe live catalog probe: 303 system voices, including 26 Mandarin and 6 English; `/v1/models` exposes no speech models.
- [x] Identify the immediate preview defect: production requests hard-code `language_boost: auto`, and cache schema v1 omits intended language boost.
- [x] Implement strict live catalog/client/store contracts and settings UI.
- [x] Implement explicit language boost and cache schema migration.
- [x] Implement opt-in persistent batch audio with independent outcomes.
- [x] Complete deterministic, live, build, UI, security, and independent review gates.
- [x] Commit, push, integrate into remote main, and verify remote ancestry without touching the primary checkout.

### 4) Findings, Decisions, Assumptions

- **Finding:** `POST /v1/get_voice` is the official live catalog endpoint. The configured mainland account returned HTTP 200 with MiniMax status 0 and 303 system voices; 26 IDs begin `Chinese (Mandarin)_`, 2 documented exceptions (`Arrogant_Miss` and `Robot_Armor`) are also Mandarin, and 6 begin `English_`. The production classifier therefore exposes 28 Mandarin and 6 English choices.
- **Finding:** `GET /v1/models` returned eight text models and zero speech models. Production code cannot honestly “pull” speech models from that endpoint.
- **Decision:** Refresh voices live and cache only their public metadata. Present Speech 2.8 HD/Turbo as the latest family and group the accepted 2.6/02/01 identifiers as older compatible models, while preserving a nonempty custom/existing model selection.
- **Finding:** `MiniMaxAudioClient` currently sends `language_boost: auto` for every language. The configuration chooses a Mandarin voice for `zh`, but the language itself is not forced and does not participate in cache identity.
- **Decision:** Derive the API language boost from the explicit source language (`Chinese` for `zh`, `English` otherwise), serialize it in each request, add it to cache identity, and bump the generated-audio schema.
- **Assumption:** “Batch AI translate” refers to the existing user-facing Batch AI Analysis flow for saved terms. This is the only batch AI feature exposed in Settings/More and already has bounded concurrency; the implementation will extend it rather than create a competing batch screen.
- **Decision:** Batch audio is default-off and persists headword/source pronunciation without playback through the existing generated-speech pipeline. Explanation and audio are separate result dimensions, but every ambiguous synthesis failure stops further paid audio starts; already completed results remain resumable from cache.
- **Review finding and resolution:** Manual Advanced Voice ID entry originally marked every value custom, which let a known English system ID waive the Mandarin mismatch guard. Catalog provenance now wins for account-created voices, recognized system prefixes remain validated, and four dedicated provenance checks prevent regression.
- **Review finding and resolution:** Replacing the shared MiniMax key now invalidates all regional in-flight responses, removes old private voice names, and reclassifies retained public data as an offline snapshot even for accounts with zero private voices. It can no longer claim that an old-credential catalog is live.
- **Security finding outside this feature diff:** The existing repository history tracks 57 root `logs/` files that may contain historical credentials; `.gitignore` currently covers only `SwiftMandarin/logs/`. GitHub issue creation was attempted but both available authentication paths returned HTTP 401. Remediation requires rotating affected keys, ignoring `/logs/`, removing those paths from the index, and coordinating a history rewrite if they were pushed. This feature does not delete or rewrite that user-owned history without explicit authority.
- **Platform constraint:** The production target remains on the repository's pre-existing Swift 5 language setting. The entire new non-UI contract slice compiles under Swift 6 with complete strict concurrency and warnings-as-errors; a repository-wide language-mode migration remains a separate change because current unrelated sources emit Swift 6 diagnostics.

### 5) Scenario-Focused Resolution Tests

- **Catalog scenario — resolved:** Live decoding returned 303 system voices and exposed 28 recognized Mandarin plus 6 English choices. Deterministic runs cover latest-request-wins region changes, failed refresh retention, account-voice privacy, zero-private-voice accounts, offline reload, and shared-key replacement.
- **Language scenario — resolved:** Production request fixtures and live calls prove Mandarin sends `Chinese` and English sends `English`; both live outputs decode as 128 kbps, 32 kHz mono MP3. Schema-v2 identities reject legacy `auto` cache hits, and known wrong-language system IDs are blocked before any paid request.
- **Batch scenario — resolved:** Deterministic runs cover opt-in preflight, exact deduplication and character counts, cache resume/revalidation, one-start-per-second pacing, provider/audio configuration snapshots, key changes, already-cancelled callers, coordinated Clear All, generation epochs, persistence recovery, cancellation, and fail-closed HTTP/transport/response errors.
- **Platform scenario — resolved:** Fresh named-destination Xcode 27 builds pass for macOS, iPhone 17 Pro/iOS 27, and iPad Pro 13-inch/iPadOS 27. The latest feature build also launched on both simulators; the iPhone and iPad screenshots render the adaptive tab/home surfaces, including the Multimodal label.

### 6) Verification Summary

- Official MiniMax release/model docs confirm Speech 2.8 as the latest family; T2A accepts eight exposed identifiers, with 2.6/02/01 presented as older compatible families.
- Official voice-management docs confirm `/v1/get_voice` and its system/cloned/generated response groups.
- The credential-safe live probe confirmed 303/26/6 catalog counts and that the general models endpoint cannot supply speech models. No credential or authorization value was printed or written.
- Production implementation now includes a strict actor-isolated Get Voice client, per-region public system-catalog cache, latest-request-wins observable state, friendly language-scoped pickers with advanced custom IDs, truthful documented model tiers, and no-fallback MiniMax previews.
- Every T2A identity now snapshots an explicit `Chinese` or `English` language boost. The boost is encoded in the request and cache schema v2, so no legacy `auto` clip can satisfy the corrected identity; known cross-language system-voice mismatches are blocked in Settings.
- Batch planning now builds independent, deduplicated analysis and audio queues. Audio is opt-in, supports learning-language or bilingual scope, performs an exact cache-miss/character preflight, revalidates that plan before paid work, persists without playback through the shared pipeline, starts at most one request per second, fails closed on synthesis errors, and retains completed explanations/audio for a safe retry.
- `zsh scripts/test-minimax-audio-contracts.sh` passes 191/191 credential-free production contracts. The script compiles the feature's non-UI production slice using Swift 6, complete strict concurrency, and warnings-as-errors before checking strict T2A/catalog decoding, both explicit languages, manual/account voice provenance and key/region invalidation, pre-network mismatch rejection, schema-v2 identity, regional/key catalog invalidation, exact batch preflight/revalidation/pacing/failure policy, persistence/coalescing/cancellation, and coordinated Clear All.
- A live production-client smoke test returned 303 system voices, 28 classified Mandarin voices, and 6 English voices. Explicit-Chinese synthesis returned a valid 71,412-byte MP3 (4,356 ms); explicit-English synthesis returned a valid 83,508-byte MP3 (5,112 ms). `file` and `afinfo` identify both as 128 kbps, 32 kHz, mono MP3 and match MiniMax's durations. The harness read the Keychain internally and printed no credential or authorization data.
- Fresh exact-tree Xcode 27 Debug builds each contain one `BUILD SUCCEEDED` marker and zero `warning:`/`error:` diagnostics: `/tmp/SwiftMandarin-audio-catalog-final4-macos.log`, `/tmp/SwiftMandarin-audio-catalog-final4-iphone27.log`, and `/tmp/SwiftMandarin-audio-catalog-final4-ipad27.log`.
- The latest built app installed and launched on the iPhone 17 Pro and iPad Pro 13-inch simulators. Runtime captures are `/tmp/swiftmandarin-audio-catalog-final-iphone27-loaded.png` and `/tmp/swiftmandarin-audio-catalog-final-ipad27-loaded.png`.
- `zsh init.sh`, localization JSON parsing, `git diff --check`, and the targeted new-key Simplified Chinese audit pass. Independent reviewers' paid-request, cancellation, persistence, configuration-snapshot, catalog-provenance, wrong-language, adaptive-layout, and localization findings were addressed and converted into regression checks.
- Feature commit `170af655cd1b5c323decebe438d66ff0220c39e5` is pushed on `origin/codex/minimax-audio-catalog-batch`. Two-parent merge `335e8c90285a3293d2f4355854ed5c4ac328dafd` has parents `4879c53` and `170af65` and is pushed on `origin/main`.
- The exact uncommitted merge tree passed `zsh init.sh` (191/191 strict contracts) and fresh Xcode 27 builds for macOS, iPhone 17 Pro/iOS 27, and iPad Pro 13-inch/iPadOS 27. `/tmp/SwiftMandarin-audio-catalog-merge-{macos,iphone27,ipad27}.log` each contains one success marker and zero warning/error diagnostics; final secret, audio-artifact, localization, plist, duplicate-Sources, and diff gates also passed before the merge commit was created.

### 8) Remaining Work & Next Steps

- No implementation, verification, or Git delivery work remains for this feature. The feature branch and remote main contain the verified commits above; the primary dirty checkout was not changed.
- Separate security follow-up remains: rotate chat-exposed and historically logged credentials, then remediate the already tracked root logs with explicit history-rewrite coordination. This is not silently folded into the feature commit.

### 8) Updates

- 2026-07-20T22:07:52Z: Created the Iteration 25 continuity record after official research and live endpoint probes; recorded the model-endpoint limitation, 303/26/6 voice counts, root preview defect, bounded architecture, and traceable acceptance plan before production edits.
- 2026-07-20T22:41:50Z: Completed the live/public-cached voice catalog, documented model tiers, language-scoped Settings pickers, honest no-fallback previews, schema-v2 explicit-language T2A, exact bilingual batch preflight and persistent generation, English/Chinese localization and privacy/README updates; recorded 151 passing contracts, a live 303/28/6 catalog result, two validated explicit-language MP3s, and preliminary green macOS/generic-iOS builds pending final named-device and review gates.
- 2026-07-20T23:50:46Z: Closed the first final-review cycle by adding paid-work fail-closed behavior, immutable provider/audio snapshots, cache/key revalidation, cancellation and Clear All epochs, truthful key-scoped catalog state, adaptive/VoiceOver UI, and the missing Simplified Chinese strings. The strict suite reached 187 passing checks and the named three-platform Xcode 27 matrix was green.
- 2026-07-20T23:59:30Z: Resolved all review findings through paid-work fail-closed semantics, immutable provider/audio snapshots, cache/key revalidation, cancellation and Clear All epochs, truthful credential-scoped catalog state, key/region-scoped manual/account voice provenance, adaptive/VoiceOver UI, and six missing Simplified Chinese strings. Expanded the strict contract suite to 191 checks; `init.sh`, localization/diff checks, live bilingual MP3 validation, simulator launches, and clean macOS/iPhone/iPadOS 27 builds pass. The final independent review found no remaining feature-blocking issue, all four feature-list scenarios are passing, and only isolated Git delivery remains.
- 2026-07-21T00:06:03Z: Pushed feature commit `170af65`, created two-parent merge `335e8c9` in a fresh isolated worktree, repeated 191 contracts and warning-free macOS/iPhone/iPadOS 27 builds on the exact merge tree, completed hygiene gates, pushed the merge normally to remote main, and marked Iteration 25 complete. The primary dirty checkout remained untouched.

## Iteration 26 — Async AVAudioSession transitions (2026-07-21)

**Last Updated (UTC):** 2026-07-21T15:02:36Z

**Status:** Complete

**Current Focus:** Commit and push the verified isolated feature branch; do not integrate it into remote main without a separate explicit instruction.

### 1) Request & Context

- **User report:** Xcode's AVAudioSession Hang Risk diagnostic identifies synchronous activation/deactivation reached from `SpeechService.swift`, including repeated warnings during the new MiniMax playback paths.
- **Operational constraint:** The primary checkout at `/Users/rogerlin/XCode-Projects/SwiftMandarinShortcuts` contains unrelated staged, unstaged, and untracked work. This fix is isolated in `/private/tmp/swiftmandarin-audio-session-fix.X9Q3Gj/worktree` on `codex/async-audio-session`, based on clean `origin/main` commit `bd8acb1`; the primary checkout MUST NOT be edited, stashed, reset, or switched.
- **Platform contract:** The app deploys to iOS 17 but is built with Xcode 27. On iOS 27, `AVAudioSession.activate(options:) async throws -> Bool` and `deactivate(options:) async throws -> Bool` MUST be used and their Boolean results checked. Earlier iOS releases require an ordered non-main compatibility path. macOS has no `AVAudioSession` work.
- **Lifecycle invariant:** A local utterance or generated-audio player MUST begin only after its own activation succeeds and only while its request still owns speech playback. A stale activation/deactivation MUST NOT start replaced audio or deactivate recording, source playback, recognition, or newer speech.

### 2) Requirements → Acceptance Checks

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|---|---|---|---|
| R26.1: No main-actor blocking transition | Inspect/guard production speech source and exercise an injected transition backend | `SpeechService` contains no synchronous `setActive`; activation work does not block MainActor | Source guard + deterministic event trace |
| R26.2: Playback waits for activation | Block fake activation, request local and generated playback, then release it | Neither engine starts early; event order is activation completion before playback | Deterministic contract |
| R26.3: Request ownership survives suspension | Stop A or replace A with B while A activation is pending | A never starts late; B remains the sole playback owner | Cancellation/replacement contracts |
| R26.4: Safe idle deactivation | Vary synthesizer/player/generation/pending-start/source activity and repeat release | Busy states do not deactivate; idle release is idempotent and notifies other audio | Idle truth-table contract |
| R26.5: Safe cross-feature handoff | Queue speech release, then start recording/source/recognition ownership before it executes | Old speech work cannot deactivate the new owner; transitions finish in ownership order | Handoff contract + integration review |
| R26.6: Cross-platform delivery | Run strict contracts and fresh Xcode 27 builds for Mac, iPhone 17 Pro, and iPad Pro | All checks/builds pass with no new source warnings/errors | Retained logs and command output |

### 3) Plan & Progress

- [x] Preserve the dirty primary checkout and create a clean isolated branch from current remote main.
- [x] Trace every speech activation/deactivation call and confirm the Xcode 27 Swift API/availability contract.
- [x] Identify cancellation, replacement, and source-handoff races introduced by unstructured async conversion.
- [x] Implement an ordered audio-session transition boundary with iOS 27 async APIs and a non-main legacy fallback.
- [x] Make both local and MiniMax playback await request-owned activation; track/cancel pending starts.
- [x] Route speech, source preview/recording, and recognition through the same owner-token ordering boundary.
- [x] Add deterministic regression checks and a production-source guard.
- [x] Run strict contracts, platform builds, final diff/security review, then update delivery artifacts.

### 4) Findings, Decisions, Assumptions

- **Finding:** `SpeechService` is `@MainActor`; its synchronous `setActive(true)` and `setActive(false, options:)` calls therefore exactly match the reported hang-risk diagnostic.
- **Finding:** Xcode 27 introduces separate async activation/deactivation methods and option types. The new calls can throw or return `false`, so both outcomes require handling. `setCategory` has no corresponding async replacement or hang annotation and remains configuration performed before activation.
- **Finding:** `AudioCaptureService` starts recording/source playback immediately after calling `SpeechService.stop()`. An uncoordinated asynchronous speech release could complete after the new session activates and shut it down.
- **Decision:** Do not hide synchronous calls in arbitrary tasks. Session transitions will share one ordering/ownership boundary, and every suspended playback start will reconcile its request token before touching an engine.
- **Decision:** Centralize all four profiles, not only the two reported speech call sites. The session is process-wide; leaving capture or recognition on independent synchronous mutations would allow a delayed release to cut off a newer owner and would retain the same hang risk in adjacent audio features.
- **Implementation:** A MainActor façade synchronously appends each transition to an explicit task tail. The tail prevents actor reentrancy from interleaving category and activation. A pre-created owner token lets synchronous stop enqueue behind a still-pending activation; stale release becomes a no-op after ownership changes.
- **Compatibility:** On iOS 27, the backend awaits the new AVFAudio methods and guards both `throws` and `false`. On iOS 17–26, category and legacy activation/deactivation run on a private serial dispatch queue. On macOS the backend performs no platform session mutation.
- **Assumption:** The reported diagnostic is the acceptance focus, but the fix MUST preserve the surrounding recording, recognition, and imported-audio flows because they share the process-wide iOS session.

### 5) Issues, Mistakes, Recoveries

- **Rejected approach:** Fire-and-forget `Task { await deactivate() }` from existing synchronous cleanup sites. It removes the immediate warning but creates a stale-deactivation race with recording/source playback and can make the interval before playback look idle. The ownership and handoff contracts above are the guardrail.
- **Review recovery:** Independent reviews found subtle stale-player cleanup, stop-during-recognition-start, final-transcript flush, interruption cleanup, and intentional-cancellation presentation risks. Cleanup is now request/player-specific, recognition startup and callbacks have separate ownership identities, interruption paths await teardown, and cancelled microphone startup does not surface a false error banner.

### 6) Scenario-Focused Resolution Tests

- **Baseline reproduction:** The user-reported path was reproduced statically: both warned methods called synchronous `setActive` from `@MainActor`.
- **Post-change source scenario:** Direct `setActive` calls now exist only in the iOS 17–26 compatibility backend. `SpeechService`, `AudioCaptureService`, and `SpeechRecognitionService` contain none; their I/O starts await a profile acquisition.
- **Deterministic transition scenario:** `scripts/test-audio-session-transitions.sh` passes 27/27 checks across FIFO ordering, activation/deactivation failure handling, stale and same-owner release/reacquire, cancellation/replacement, and all four macOS profiles. Its production guard confirms there are exactly two direct `setActive` calls, both inside the private-queue iOS 17–26 backend.
- **Final platform scenario:** Fresh exact-tree Xcode 27 Debug builds for macOS, iPhone 17 Pro/iOS 27, and iPad Pro 13-inch/iPadOS 27 each succeed with zero `warning:` or `error:` diagnostics. The built iPhone and iPad apps install and launch on their named simulators.
- **Verdict:** R26.1–R26.6 are resolved. Real-device route changes, interruptions, Bluetooth devices, and Thread Performance Checker runs remain useful release QA, but no synchronous session activation/deactivation path remains on the main actor in the production source.

### 7) Verification Summary

- Xcode 27 beta SDK headers, generated symbol graph, and a Swift 6 complete-concurrency probe confirm exact async signatures, iOS 27 availability, distinct activation/deactivation option types, and meaningful Boolean results.
- `zsh init.sh` passes 191/191 MiniMax contracts, 27/27 audio-session transitions, iOS 27 API/source guards, and the project smoke checks.
- The audio harness compiles its production coordinator with Swift 6 complete strict concurrency and warnings-as-errors, then type-checks it against the iOS 27 SDK with an iOS 17 deployment target.
- `/tmp/SwiftMandarin-audio-session-final2-macos.log`, `/tmp/SwiftMandarin-audio-session-final2-iphone.log`, and `/tmp/SwiftMandarin-audio-session-final2-ipad.log` each contain `BUILD SUCCEEDED` and no `warning:` or `error:` diagnostics.
- Simulator launch evidence: bundle `linroger022.SwiftMandarin` launched as PID 73229 on iPhone 17 Pro and PID 73230 on iPad Pro 13-inch.
- Two independent final reviews found no P0/P1 issue or commit blocker after the request/owner, interruption, recognition-flush, stale-cleanup, and cancellation fixes.
- `git diff --check`, `jq empty feature_list.json`, executable-script mode, direct-call inspection, and unexpected-audio-artifact checks pass.

### 8) Remaining Work & Next Steps

- No implementation or automated verification work remains for R26.1–R26.6. Create and push the isolated feature commit; remote-main integration is intentionally excluded until explicitly requested.
- Recommended device QA before App Store release: rerun the original Thread Performance Checker scenario on physical iPhone/iPad hardware and exercise Bluetooth, interruption, and route-change handoffs. These hardware checks are not substitutes for the deterministic ownership suite and do not block this source-level fix.
- Separate security follow-up remains unchanged from Iteration 25: rotate chat-exposed and historically tracked credentials, then coordinate removal/history remediation of the already tracked root logs. The current feature does not modify those base-branch files.

### 9) Updates

- 2026-07-21T14:27:39Z: Created Iteration 26 before production edits; recorded the reported warning, SDK contract, lifecycle invariants, isolated-worktree boundary, race analysis, implementation plan, and traceable acceptance checks.
- 2026-07-21T14:40:50Z: Completed the first production slice: one FIFO four-profile transition coordinator, async iOS 27 and non-main legacy backends, request/owner reconciliation across speech/capture/recognition, and preliminary clean macOS/iPhone builds. Started deterministic test implementation and two independent concurrency/integration reviews.
- 2026-07-21T15:02:36Z: Closed R26.1–R26.6 after 27 deterministic transitions, the full 191-contract project suite, exact API/source guards, warning-free macOS/iPhone/iPadOS 27 builds, named-simulator launches, hygiene checks, and two blocker-free final reviews. Marked `bug_async_av_audio_session` passing and the isolated branch ready for Git delivery.

## Iteration 27 — Structured AI translation output (2026-07-27)

### 1) Request & Context

- **User's request:** a screenshot showing a translation surface filled with rambling, first-person, partly repetitive model prose where clean target-language text belongs, plus: "read through the codebase, especially the parts related to the AI features and translations, and fix this issue, perhaps by having the AI return a structured output which the app can parse."
- **Scope boundary:** the AI provider paths only. Apple's on-device `Translation` API (iOS 18+/macOS 15+) already returns clean text and is untouched; so are the explanation, grading, conversation, story, and word-identification flows, which already use structured output.

### 2) Verified Root Cause

Translation was the one AI feature in the app with **no output contract at all**. `AIWordExplanationService.translateWithProvider` → `translate` / `OllamaService.translate` / `CloudAIService.translate` each took a `String` and returned the model's completion verbatim, trimmed. Three consequences, all of which reached the learner:

1. **No slot for the answer.** A model that decided to summarize, outline, or annotate the passage instead of translating it had nowhere else to put that text. The old prompt asked for "ONLY the translation" in prose and nothing enforced it.
2. **Chain-of-thought leakage.** `CloudAIService.parseOpenAIContent` returned `message.content` untouched. Thinking models on OpenAI-compatible gateways (DeepSeek, Qwen, Zhipu, Kimi, MiniMax, Doubao and their Ollama equivalents) interleave reasoning as `<think>…</think>` — matched, opener-dropped, or never closed when truncated. All three variants were displayed, spoken by `SpeechService`, and written to `TranslationHistoryStore`. A brace inside a chain of thought also corrupted `AIWordExplanationService.extractJSONObject`, which every structured feature relies on.
3. **Truncation.** `CloudAIService.translate` hard-coded `maxTokens: 2048`, which cuts a Reader paragraph, scanned page, or pasted article mid-sentence.

The same shape applied to `cleanupRecognizedText`: its free-form completion becomes `sourceText` for the entire photo pipeline, so a "Here is the corrected text:" preface plus a summary was adopted as the learner's source material.

Every affected surface — Translate, Photo/Multimodal, Reader, Live Speech, menu-bar translate, screenshot overlay, and the Shortcuts intents — funnels through those three provider methods, so all of them shared the single defect.

### 3) Change

- **New `SwiftMandarin/Services/AIResponseParsing.swift`** (Foundation-only, so the harness can exercise it without a model or credentials):
  - `AIResponseSanitizer` — reasoning-tag removal for matched pairs, stray closers, and stray openers, across ASCII `<think>` and MiniMax `◁think▷`, plus code-fence and wrapping-quote removal.
  - `AIStructuredResponse` — balanced, string-aware JSON object scanning (braces and quotes inside the answer never end the object early), with a salvage pass for envelopes truncated mid-string or written with unescaped line breaks.
  - `AITranslationResponseParser` / `AITextCleanupResponseParser` — the ladder from strict parse → salvage → sanitized free-form, and rejection of machine data with no answer in it.
- **`AITranslationPromptBuilder`** gained an ANSWER SCOPE section (translate, never summarize/outline/analyze; never answer a question the source asks; never emit reasoning) and a `jsonOutputContract` describing `{"translation": "…"}`.
- **`AIOutputBudget.tokens(forSourceLength:)`** replaces the fixed 2048 ceiling, scaling to 8192.
- **Provider wiring:** Apple Intelligence uses `@Generable TranslationOutput` / `CleanedTextOutput` guided generation; Ollama uses schema-constrained `generateStructured`; cloud requests the JSON envelope with `jsonMode: true`. All three parse through the shared parser. Both `CloudAIService.chat` and `chatTurns` now route content through `answerText(from:)`, so reasoning stripping protects every structured feature, not just translation.
- **`AIProviderConfigView.testConnection`** raised from 32 to 512 max tokens: with a response that is nothing but reasoning now treated as empty, the old ceiling would have failed the check on a healthy connection.

### 4) Decisions

- **Envelope over bare string, everywhere.** Matches the pattern `ConversationService`, `GradingResult`, and `ExtractedVocabResponse` already use. A named field means commentary is discarded by construction rather than by pattern-matching prose.
- **Parse ladder consults the untouched response too.** `AIStructuredResponse.envelopeValue` prefers a strict parse of the reasoning-free text, then a strict parse of the original, then salvages. That ordering is what lets a legitimate answer *containing* `<think>` (translating a sentence about the tag) survive intact instead of being truncated by the sanitizer.
- **Label and note stripping runs only on the free-form fallback.** Inside the envelope those patterns are far more likely to be genuine content — a source line reading `翻译：…` really does translate to `Translation: …`.
- **No degenerate-repetition collapsing.** Considered, because the screenshot appears to show repeated fragments, but rejected: any heuristic that rewrites repeated content risks damaging a legitimate refrain, and the structured contract addresses the cause rather than that symptom.
- **A response with no answer fails loudly.** `AITranslationResponseError.noTranslation` (localized, with a zh-Hans entry) is shown instead of the model's prose.

### 5) Requirements → Acceptance Checks

| Requirement | Check | Evidence |
|---|---|---|
| R27.1 Commentary around the answer is discarded | Envelope parse with prose before/after, fenced envelope, brace in surrounding prose | `test-ai-prompt-contracts.sh` — 9 envelope cases |
| R27.2 Chain-of-thought never reaches the UI | Matched pair, stray closer, unclosed opener, MiniMax brackets, case/attributes, multiple pairs | 8 sanitizer cases |
| R27.3 Answer content is not damaged | Braces/quotes in the value, ordinary prose containing "think", `<think>` inside a valid answer, quotes inside a sentence, mid-passage note-like line, label word without a colon | 6 preservation cases |
| R27.4 Damaged envelopes still yield the answer | Truncated mid-string, unescaped line break inside the JSON string | 2 salvage cases |
| R27.5 Non-compliant models keep working | Bare string, English/Chinese/markdown labels, wrapping quotes, trailing notes | 9 free-form cases |
| R27.6 A commentary-only response is an error, not a result | Empty, whitespace, reasoning-only, analysis object, echoed request payload | 5 rejection cases |
| R27.7 Long passages are not truncated | Budget scales 2048 → 6512 → 8192 | 3 budget cases |
| R27.8 All three providers are wired the same way | Per-provider grep assertions for guided generation, schema, envelope contract, and parser use | 22/22 wiring checks |

### 6) Verification Summary

- `zsh scripts/test-ai-prompt-contracts.sh`: **124/124** prompt + response-parsing checks, **22/22** provider-wiring checks. The runner now compiles the production parser with `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`, matching the MiniMax harness.
- `zsh init.sh`: **191/191** MiniMax contracts, **27/27** audio-session transitions, **124/124 + 22/22** AI contracts, project smoke checks — all pass. The AI contract script is now part of `init.sh` so this fix stays guarded.
- Xcode 27 Debug builds: macOS and generic iOS Simulator both `BUILD SUCCEEDED` with **zero** `warning:` or `error:` diagnostics.
- **Mutation testing** (the checks are not vacuous): returning the raw completion from `CloudAIService.translate` → "Expected the cloud translation to parse its response through the shared parser; found 0". Emptying the reasoning-tag list → "A matched reasoning pair is removed; expected Good morning. but got `<think>`Weigh the register first.`</think>`Good morning." Removing the salvage rungs → "A truncated envelope yields the partial answer instead of raw JSON; expected … but got `{"translation":"…`". All three restored and re-verified green.
- `python3 -m json.tool` passes on `SwiftMandarin/Localizable.xcstrings` and `feature_list.json`.

### 8) Remaining Work & Next Steps

- **Live provider QA is not done** and cannot be from here: no API keys were used and no request was sent to any provider. Worth exercising before release — a thinking model (Qwen/Zhipu/Kimi/MiniMax) translating a long article, a truncation at the new 8192 ceiling, and the Apple Intelligence path on a device with Apple Intelligence enabled.
- **Screen attribution is inferred, not confirmed.** The screenshot's resolution did not allow identifying which surface produced it. The fix is at the shared provider choke point, so Translate, Photo, Reader, Live Speech, menu bar, screenshot overlay, and Shortcuts are all covered regardless — but if the reported symptom persists on one specific screen, that screen has a second, separate cause worth investigating.
- Other free-form AI surfaces deliberately left alone because they already parse structured output: explanations, grading, review-question generation, conversation, story generation, word identification, vocabulary extraction.
- The credential-rotation follow-up from Iterations 25–26 is unchanged and untouched by this work.

### 8) Updates

- 2026-07-27: Created Iteration 27. Audited the AI/translation paths, identified the missing output contract as the shared root cause, implemented the structured envelope across all three providers plus OCR cleanup, added 42 response-parsing checks and 7 wiring assertions, mutation-tested them, and verified clean macOS/iOS builds and a green `init.sh`. Marked `bug_ai_translation_structured_output` passing.

## Iteration 28 — Translation study notes, transcription repair, AI transcription (2026-07-27)

### 1) Request & Context

Three asks in one message, following Iteration 27:

1. **Explain the translation.** "For the AI translation, perhaps have the AI provide an explanation of the translation to help users understand it, perhaps including what the major important characters or phrases mean, as part of the structured output. Write a prompt … that works for both long and short inputs, and doesn't include easy characters."
2. **Audio transcription doesn't work.**
3. **Add a feature for AI transcription and translation.**

### 2) Change 1 — Study notes in the same envelope

Iteration 27 gave translation a one-field envelope. That envelope now carries two more fields, so the explanation costs **no extra round trip** on the AI translation path:

```json
{"translation": "…", "explanation": "…", "keyTerms": [{"term","reading","meaning","note"}]}
```

- `AITranslationContext` (Foundation-only) carries the direction *and* the learner's native language, because notes must read natively whichever way the translation runs. `AITranslationContext.current(sourceIsChinese:)` in the service layer reads `LocalizationManager.nativeIsChinese`.
- `AITranslationPromptBuilder.studyNotesContract(for:)` is the new prompt. Two rules carry the user's requirements:
  - **Scale** — "A short or easy source gets none. A sentence or short paragraph gets about two to four. A long passage gets at most eight, chosen from across the whole text rather than the opening lines… Never pad the list to reach a number." One prompt is therefore correct for a two-word lookup and a full article.
  - **Skip easy items** — for Chinese: "pronouns, numbers, dates, weekdays, particles and function words such as 的, 了, 是, 在, 有, 不, 很, 也, 就, 会, 能, greetings, and the ordinary high-frequency nouns, verbs, and adjectives of daily life"; the English branch names function words and everyday vocabulary instead. Plus "Prefer the whole word, set phrase, chengyu, or collocation over a single character."
  - `explanation` is constrained to *why this rendering is right* — idiom, clause order, omitted subject, aspect/measure word, register, pun, cultural reference — with the exact source words quoted, and an explicit "return an empty string rather than inventing a difficulty."
- All three providers carry it: Apple Intelligence via `@Generable TranslationOutput` + `TranslationKeyTerm`, Ollama via an extended schema, cloud via the prompt contract. `AITranslationResponseParser.result(from:)` returns `AITranslationResult`; a damaged response still yields the translation and simply loses the optional notes.
- Key terms are capped at 8, deduplicated, and rows with no term or no meaning are dropped — a row that teaches nothing is worse than a shorter list.
- **UI:** new `TranslationNotesView` (collapsible, one-tap save to vocabulary) on **Translate** and on **Multimodal**'s Chinese→English card. On the AI path the notes arrive automatically; on Apple's on-device Translation path — which returns none — an explicit **Explain this translation** button fetches them, so the free on-device path never silently bills a provider.

### 3) Change 2 — Why transcription didn't work

`AudioTranscriptionService` had three defects, all of which produced "it just doesn't work":

1. **On-device forced with no fallback.** `if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }`. That property says the *recognizer* can work offline; it does **not** promise the locale's assets are installed. On a device without the Chinese (or any) dictation model downloaded, every attempt failed or returned nothing, and there was no server pass to fall back to. Now: on-device is attempted first, and `.recognitionFailed`, `.emptyTranscript`, and `.timedOut` all retry through Apple's service.
2. **Availability checked one instruction after construction.** `SFSpeechRecognizer(locale:)` reports `isAvailable == false` for a short window while Speech resolves the locale, so a perfectly good recognizer was rejected outright. Now polled for up to 3 seconds.
3. **No timeout.** Speech can accept a URL request and never call back, leaving the spinner forever. Now a 120 s deadline resolves the exactly-once gate with `.timedOut`.

Also: `addsPunctuation = true` (a transcript is used as editor text and translation input), and Speech's opaque errors now carry their domain and code — the only way to tell a missing on-device asset from a network failure. Usage descriptions and the `com.apple.security.device.audio-input` entitlement were already correct and were not the cause.

### 4) Change 3 — AI transcription and translation

- `AIProvider.supportsAudioTranscription` + `defaultTranscriptionModels` + `transcriptionPath` for the providers documented to serve OpenAI's `POST /audio/transcriptions`: **OpenAI, Qwen, Quotio**. Because base URL and model are both user-editable, any other OpenAI-compatible ASR gateway is reachable through Quotio; a provider that turns out not to serve the route answers with its own HTTP error, surfaced verbatim rather than hidden.
- `CloudAIService.transcribeAudio(provider:model:audioURL:languageCode:)` builds the multipart request by hand (no third-party dependency) and reads the transcript from `{"text": …}`, DashScope-style `output.text` / `output.sentence[]`, or `results[]`.
- `AudioTranscriptionEngine` (`appleSpeech` | `aiProvider`) persists in `AIModelSettings`, defaulting to Apple Speech. Routing lives in `AudioTranscriptionService.transcribe(audioURL:language:engine:)` so every audio surface shares one preference and neither engine silently substitutes for the other — switching to AI uploads the recording, and that stays an explicit choice.
- **UI:** engine picker + editable model field in the Multimodal audio pane, an engine-specific privacy notice, and — after an Apple Speech failure with a provider configured — **Retry with AI** / **Retry & Translate** buttons, so a learner whose language has no dictation model is not left at a dead end. "Translate Audio" then runs AI transcription → AI translation end to end.

### 5) Decisions

- **Notes ride in the translation envelope, not a second call.** The AI path pays nothing extra. The on-device path gets an explicit button rather than an automatic second (billed) request.
- **Notes are allowed to be empty.** The prompt says an easy passage gets none, so `hasNotes == false` is a correct result; `TranslationNotesView` renders nothing rather than an empty-state placeholder.
- **Free-form label/note stripping is *not* applied to OCR cleanup** (carried over from Iteration 27) and, for the same reason, key-term rows are filtered but never rewritten.
- **No silent engine substitution for audio.** Apple → AI is offered on failure, never automatic: the two engines differ in where the audio goes and who bills for it.
- **`testConnection` raised 32 → 512 max tokens** (Iteration 27 follow-through): with a reasoning-only response now treated as empty, 32 tokens would fail the check on a healthy connection.

### 6) Requirements → Acceptance Checks

| Requirement | Check | Evidence |
|---|---|---|
| R28.1 Notes ride in the same structured response | Envelope with explanation + keyTerms parses into one result | `test-ai-prompt-contracts.sh` — 6 result cases |
| R28.2 The prompt scales to input length | Contract asserts "A short or easy source gets none" / "A long passage gets at most eight" / "across the whole text" / "Never pad the list" | 4 prompt assertions |
| R28.3 Easy characters are excluded | Contract asserts the elementary-skip rule and the named Chinese function words; the English branch must not carry the Chinese list | 4 prompt assertions |
| R28.4 Notes follow the learner's native language | Chinese-source context says "in English"; English-source context says "in Simplified Chinese (简体中文)" and asks for no pinyin | 4 prompt assertions |
| R28.5 Malformed note lists degrade safely | Cap at 8; blank / meaningless / duplicate rows dropped; alias field names accepted; notes survive reasoning stripping | 12 parser assertions |
| R28.6 Transcription no longer dead-ends | No forced `requiresOnDeviceRecognition = true`; two server-fallback passes; a `.timedOut` deadline exists | 3 wiring assertions |
| R28.7 AI transcription exists end to end | Service routes to the cloud client; exactly one multipart client | 2 wiring assertions |
| R28.8 Notes reach real screens | `TranslationNotesView` on both translation surfaces; both request the notes-bearing translation | 2 wiring assertions |

### 7) Verification Summary

- `zsh init.sh`: **191/191** MiniMax, **27/27** audio-session, **161/161** AI prompt + parsing, **29/29** provider wiring — all pass.
- Xcode 27 Debug builds: macOS and generic iOS Simulator both succeed with **zero** `warning:` / `error:` diagnostics.
- **Mutation testing:** forcing `requiresOnDeviceRecognition = true` → "Transcription forces on-device recognition with no fallback (1 site(s))". Removing `TranslationNotesView` from one surface → "Expected translation notes on both the Translate and Multimodal surfaces; found 1". Both restored and re-verified green.
- The rendered prompt was dumped and read end to end (not only asserted on fragments) to confirm the scale and skip rules read as intended for both directions.
- 20 new user-facing strings added to `Localizable.xcstrings` with zh-Hans translations; catalog and `feature_list.json` both parse.

### 8) Remaining Work & Next Steps

- **No live provider or device call was made** — no API keys were used, and Apple Speech was not exercised on real hardware. Before release: (a) transcribe a Chinese clip on a device *without* the zh dictation model installed and confirm the server fallback carries it; (b) run AI transcription against OpenAI and against Qwen — **Qwen's `/audio/transcriptions` support is asserted from documentation, not verified here**, and if it 404s the fix is a base-URL/model change, not code; (c) confirm the notes panel on a long article with a thinking model.
- The Reader and Live Speech surfaces reuse `translateWithProvider` and so still show translation only. Adding `TranslationNotesView` there is a small, mechanical follow-up if wanted.
- Iteration 25–26's credential-rotation follow-up is unchanged and untouched.

### 9) Updates

- 2026-07-27: Created Iteration 28. Added study notes to the translation envelope with a length-scaling, easy-vocabulary-excluding prompt; diagnosed and repaired the three transcription defects; added an AI transcription engine with an OpenAI-compatible multipart client and an engine picker. 38 new prompt/parser checks and 7 new wiring assertions, mutation-tested; clean macOS/iOS builds and a green `init.sh`.

## Iteration 29 — Chinese-speaker-learning-English as a true mirror (2026-08-05)

### 1) Request & Context

> "study the whole codebase. study the logic of the english speaker learning mandarin. i want the logic in reverse for the chinese speaker learning english mode in the settings. change all aspects to be tailored to this, including prompt instructions for the language reversal, explanations in mandarin, and audio generated in english for the chinese speaker learning english mode. these should only be activated in the chinese speaker learning english. dont change the mode for the english speaker learning mandarin, which is already perfect, but implement the reverse mode throughout the app for the chinese speaker learning english, including in the vocab list, where the english work should be in the main font, and the chinese word should be in the smaller font. also make sure the interface language is changed throughout the app once the user changes to chinese speaker learning english."

Constraint that shaped every decision: **the English-speaker mode is finished and must not change.** The safe form of almost every edit was therefore *additive* — a new branch taken only when `learningIsChinese == false`, or a literal turned into a localization key whose key text is the old literal (so English output is byte-identical and only the 中文 rendering is new).

### 2) What was already there, and what actually wasn't

A 9-agent parallel audit read the whole codebase (333 findings, 33 critical). The result was more nuanced than "reverse mode is missing": Iteration 8's language-direction work had already made `SavedTerm.headlineText/glossText/showsPinyin`, `PracticeItem`, `ConversationService`, `StoryGenerationService`, `BatchAudioPlanner`, `LearnView`, `PhrasesView`, `DictationView`, and `QuizView` correctly bidirectional. The reverse mode was not absent; it was **half-applied**, and the half that was missing followed a pattern — the *text* had been swapped everywhere, but the *learner aids*, *prompt contracts*, *defaults*, and *interface strings* attached to that text had not.

Concretely:

1. **The AI prompt told the model to give a Mandarin speaker nothing to pronounce with.** `AIExplanationPromptBuilder` said, for an English headword: `"All pinyin fields must be empty strings because the headword is English."` A Chinese learner therefore received an English word with no reading at all, while an English learner received pinyin with tone marks — the single most useful scaffold, present in one direction and explicitly forbidden in the other. The English word-building contract was five prohibitive lines against the Chinese branch's sixteen teaching lines. Worse, `AIExplanationPromptChecksRunner.swift:100` **asserted the defect** (`expectContains(englishTeacher, "pinyin fields must be empty")`), so it was locked in.
2. **The tappable reader was Chinese-only.** `TranslateView.interactiveTranslationView` rendered `RubyTextView` unconditionally under a hard-coded `"CHINESE (TAP WORDS FOR DETAILS)"` header, with the English shown as flat, untappable text. `EnglishRubyTextView` — the exact mirror component — already existed and was used by ReaderSessionView and PhotoTranslateView, but never here. `WordIdentificationService` was Mandarin-only end to end: its prompt segmented 中文, demanded pinyin, and glossed in English regardless of the learner.
3. **A first-launch Mandarin speaker opened Translate pointing the wrong way.** `AppPreferences.init()` assigns `learnerMode` directly, so its `didSet` — the only writer of the shared `defaultDirection` key — never ran at launch. Every reader then fell back to its own `TranslationDirection.englishToChinese` literal, and `TranslationState.direction` was hard-coded to the same.
4. **Mandarin-only affordances were shown to native Mandarin readers**: the whole Pinyin Display settings group on both platforms, the Chinese-font picker, the pinyin sort order in Vocabulary, and pinyin ruby over every Chinese word.
5. **~155 user-facing strings never reached the string catalog**, because they were raw Swift `String`s: every error message in the speech, cloud-AI, and import/export services; the Stats screen's stat labels; the About screen; the nine section headings of the AI explanation card. Plus 69 catalog keys with no zh-Hans translation.

### 3) The change

**A shared vocabulary for the mirror.** `SwiftMandarin/Models/LearningContext.swift` (new) is a pure, `Sendable`, Foundation-only value holding one fact — `learningIsChinese` — and projecting it onto the questions call sites kept re-deriving: `primary(chinese:english:)` / `secondary(chinese:english:)`, `showsPinyinAffordances`, `interactiveReaderIsChinese`, and `mirrored`. It exists because re-deriving the swap inline is what let the text reverse while the pinyin affordance stayed pinned to the original audience.

**Prompts (`AIExplanationPromptBuilder`, `AIWordExplanationService`, `WordIdentificationService`).** The `pinyin` slot is now the *pronunciation* slot: pinyin with tone marks for a Chinese item, **IPA between slashes with primary stress** (`/kəˈmɪt/`) for an English one — stated in the teacher contract, the cloud JSON schema, the Ollama schema, and every `@Guide` on the Foundation Models path (those are compile-time literals, so they were rewritten direction-neutrally rather than branched). The English word-building contract now mirrors the Chinese one line for line: one compact line per real prefix/root/suffix/compound-half/particle, a localized "Together:" bridge, the word family the learner gets for free, and irregular inflections — instead of "do not split an English word into arbitrary letters." `AITranslationContext.readingDescription` gained the same treatment, so English key terms in translation study notes carry IPA instead of an explicitly empty field. `WordIdentificationService` became direction-parameterized: English segmentation keeps phrasal verbs and idioms together as one dictionary entry (the mirror of keeping 学习 intact), asks for IPA, uses an English POS inventory, and glosses in the learner's native language — with the cache re-keyed by direction so switching modes re-glosses instead of serving back the old language.

**Vocabulary list.** `renderedHeadwordFontSize` sizes the headword by *its own script* — Han characters carry more detail per glyph, so an English headword steps down to 0.85× (0.6× in the 96 pt detail view) to look equally weighted at the same slider position; the storage keys keep their old names so existing preferences survive. `SavedTerm` gained `showsPhonetic` and `headwordReading`; the `looksLikeIPA` guard (`ChineseTextAnalyzer.swift`) stops a term saved while learning Mandarin from rendering "xuéxí" under the headword "study". The `headlineText` fallback no longer promotes the raw `chinese` field into the large font for a one-sided entry. The Pinyin sort option is filtered out of the menu and ignored if persisted. `normalizedKey` now folds case, so "Charge" and "charge" stop duplicating.

**Reader and defaults.** `TranslateView` splits into `studiedLanguagePane` / `nativeLanguagePane(prominent:)`: a Mandarin speaker gets the tappable `EnglishRubyTextView` on top with 中文 plain beneath, and word identification is skipped entirely (English boundaries are unambiguous locally, so the model call would buy nothing). `TranslationDirection.persistedDefault` derives the fallback from the persisted interface language and is now used by all four readers; `AppPreferences.init()` seeds `defaultDirection` when absent, without overwriting an explicit choice.

**Interface language.** Hard-coded strings in 17 files were routed through the catalog using their existing English text as the key, so English rendering is unchanged. 149 zh-Hans translations were added: 57 for the previously-untranslated bilingual and English keys, 89 for the newly-created ones, plus 5 for the new direction-aware headings. Catalog coverage went from 1141/1210 to **1290/1301** — the 11 remaining are punctuation and format scaffolding (`""`, `" "`, `"→ %@"`, `"%lld/%lld"`) that correctly need none.

### 4) Decisions

- **Never change what English mode renders.** For a bilingual key like `"作业 · Workbook"` this meant adding a zh-Hans value of `"作业"` rather than re-keying to English: 中文 mode becomes pure Chinese while English mode keeps the exact string it had. For English literals it meant keeping the literal as the key.
- **IPA reuses the `pinyin` field rather than adding a phonetics column.** The wire format, the response structs, the explanation cache, and `SavedTerm` all keep their shape; only the field's *description* is direction-aware. Adding an IPA column would have meant a schema migration for an aid the model can already produce.
- **Hide Mandarin-only features rather than invent English counterparts.** Tone drills, the tone-color legend, the pinyin position picker, and the Chinese-font picker are hidden for a native Mandarin reader. Building a stress-drill counterpart is a product decision, not a reversal.
- **The pure core is testable; the live accessor is compiled out of the runner.** `LearningContext.current` sits behind `#if !LEARNING_DIRECTION_CHECKS` so the mirror invariants can be asserted without dragging in `LocalizationManager`.
- **Literals were hoisted out of ternaries.** `Text(cond ? "A" : "B")` is ambiguous between `Text`'s localizing and verbatim initializers, and Xcode's extractor does not reliably catalog it — so each is now an explicitly typed `LocalizedStringKey` property.

### 5) Requirements → Acceptance Checks

| Requirement | Check | Evidence |
|---|---|---|
| R29.1 Prompts explain English headwords in Mandarin | English-direction contract names 简体中文 as the explanation language and omits the Chinese decomposition rules | `test-ai-prompt-contracts.sh` |
| R29.2 The reverse direction gets a pronunciation, not an empty field | English contract requests IPA + primary stress; the old "pinyin fields must be empty" assertion is inverted; the Chinese branch must not request IPA | 12 new prompt assertions |
| R29.3 Audio follows the studied language | Batch `.bothLanguages` queues the studied language first; scope label no longer names Mandarin | `test-minimax-audio-contracts.sh` (191/191) |
| R29.4 English word large, Chinese word small | Headword sized by its own script at 2 sites; the English pronunciation line renders at 3 sites | `test-learning-direction.sh` wiring checks |
| R29.5 The tappable reader mirrors | Translate consults `interactiveReaderIsChinese` and offers `EnglishRubyTextView` | wiring checks |
| R29.6 Pinyin ruby is a learner aid only | `RubyWordView` gates ruby on `showPinyin && learningIsChinese` | wiring check |
| R29.7 A Mandarin speaker opens on 中→EN | All four readers of the default direction use `persistedDefault` | wiring check |
| R29.8 The two modes are genuine mirrors | Every accessor differs between directions and equals its mirrored counterpart; primary/secondary swap and remain exhaustive | 28 assertions in `LearningDirectionChecksRunner` |
| R29.9 The interface renders in 中文 | Catalog coverage 1290/1301; every remaining gap is punctuation or format scaffolding | catalog audit |

### 6) The bug the verification pass found — `String(localized:)` never followed the toggle

An adversarial review of the finished change caught something that would have quietly undone most of it, and it is the most important thing in this iteration to remember.

`LocalizationManager` switches language by re-classing `Bundle.main` and overriding the ObjC method `localizedString(forKey:value:table:)`. SwiftUI's `Text("…")` and `NSLocalizedString` both call that method — which is why view literals have always followed the in-app toggle. **`String(localized:)` does not.** It resolves through Foundation's own machinery, which never sees the override, so every string assembled in a model or service followed the *device* language instead.

This was verified empirically rather than argued, with a standalone binary that installs the same override against real `en.lproj` / `zh-Hans.lproj` resources:

```
Bundle.main.localizedString : 陈述句     ← override honored
NSLocalizedString           : 陈述句     ← override honored
String(localized:)          : Declarative ← override BYPASSED
```

It was a pre-existing app-wide flaw (~184 call sites before this change), not something the localization pass introduced — but the pass added ~110 more and documented several of them as "resolves through the string catalog so it follows the in-app toggle", which was false. The canonical symptom: an English-language device with the app set to 中文 — precisely the reverse-mode user, since the app only defaults to 中文 on a Chinese device — would read `TranslateView`'s language chips and placeholder in English while every neighbouring literal on the same screen was Chinese.

The fix keeps `String(localized:)`'s ergonomics (interpolation, Xcode extraction) and simply names the bundle: `String(localized: "…", bundle: .appLanguage)`, where `Bundle.appLanguage` returns the installed override. That was applied to all **294** call sites. `LocalizedStringResource` has the same flaw and no `Bundle` parameter, so the two enums using it (`BatchAudioScope`, `MiniMaxAPIRegion`) became `LocalizedStringKey`, which SwiftUI resolves through the override.

Two supporting changes fell out of it. The `Bundle` override machinery moved from `LocalizationManager.swift` into its own Foundation-only `LanguageBundleOverride.swift`, because several files that now resolve strings are compiled standalone by the contract runners and could not drag in SwiftUI and `AppPreferences`. And `test-learning-direction.sh` gained two guards — one that fails when any `String(localized:)` omits the bundle, one that catches `comment:` written before `bundle:` (an argument-order *build* error, which is how the bulk rewrite first broke `SRSEngine`). Both are mutation-tested.

### 7) Verification Summary

- `zsh init.sh`: **191/191** MiniMax audio, **27/27** audio-session, **173/173** AI prompt + parsing (was 161), **29/29** provider wiring, **28/28** learning-direction mirror, **8/8** direction wiring. All green; the new suite is wired into `init.sh`.
- **Full-app type-check, views included.** Xcode is not installed here (Command Line Tools only), so `xcodebuild` cannot run — but the two things it supplies are both recoverable. The `Ollama` SwiftPM dependency was compiled from the checkout Xcode had already resolved into DerivedData, and the project's real build settings were restated on the command line (`-swift-version 5`, `-default-isolation MainActor`, `-target arm64-apple-macos26.2`, `MemberImportVisibility`). Against that, all 112 Swift files — every SwiftUI view body included — type-check with **zero** errors; the only diagnostics left are 26 instances of the SwiftUI macro plugin being absent, which is an environment artifact and nothing else. A `swiftc -parse` sweep is also clean.
- **Mutation testing.** Un-routing one `String(localized:)` → "A String(localized:) call bypasses the in-app language override (1 site(s))". Inverting `comment:`/`bundle:` → "passes comment: before bundle: (1 site(s))". Both restored and re-verified green.
- The string catalog is edited by a script that reproduces Xcode's serialization byte for byte (verified by a round-trip self-test), so the diff is the added translations rather than a reformat of all 315 KB. Every added translation was checked for format-specifier compatibility with its key — which caught `"%lld word%@ ready to export"`, whose Chinese translation was consuming the English plural-suffix argument and dropping a stray Latin "s" into Chinese text.

### 8) Remaining Work & Next Steps

- **No `xcodebuild` and no device run.** The full-app type-check above covers the macOS slice with the project's real settings, so the remaining uncovered surface is the iOS-only `#if os(iOS)` code — Command Line Tools ship no iOS SDK. Those regions were read by hand; the only substantial one is `VocabularyView`'s iOS detail session, which is expression-for-expression the same shape as the macOS inspector that does type-check. First action on a machine with Xcode: build macOS + iOS Debug.
- **No live model call.** The IPA contract is asserted against the rendered prompt, not against a real provider's output. Worth confirming with one cloud provider and one Ollama model that an English headword actually comes back with `/…/` in the pronunciation field.
- **Mandarin-only features are hidden, not mirrored.** Tone drills have no English counterpart (a stress- or minimal-pair drill would be the analogue), `LearningDeck.cards` is a 15-card Mandarin starter deck whose English side serves as the reverse-mode deck, and `LearningCard.exampleSentence` is Chinese-only. `GrammarKnowledgeBase` (`Models/GrammarPoint.swift`) is a complete Chinese-explanations-of-English-grammar dataset that **nothing in the app references** — it is the ready-made content for a reverse-mode grammar surface.
- `LearnerMode.bilingual` still leaves the interface language at whatever it was, because `syncLearnerMode` deliberately preserves an explicit bilingual choice. That mode has no defined native language, which is a product question rather than a bug.

### 9) Updates

- 2026-08-05: Created Iteration 29. Audited the codebase with 9 parallel readers, then made the Chinese-speaker-learning-English mode a true mirror: IPA-for-pinyin in every prompt contract, an English tappable reader, script-aware headword sizing in the vocabulary list, direction-derived defaults, Mandarin-only affordances gated, and ~150 zh-Hans translations taking catalog coverage to 1289/1300. Added `LearningContext` plus a 36-assertion contract suite wired into `init.sh`; inverted the prompt check that had locked in the missing-pronunciation defect.
- 2026-08-05 (same session, after adversarial verification): Fixed the two defects that review found. (a) `String(localized:)` never followed the in-app language toggle — proved with a runnable experiment, then routed all 294 call sites through `Bundle.appLanguage` and added two mutation-tested guards so it cannot regress; the override machinery moved to its own Foundation-only file so the contract runners can still compile standalone. (b) Every save path discarded the IPA the reverse-mode prompts ask for, making `showsPhonetic` unreachable — the model-supplied reading is now kept for English headwords. Also: `EnglishWordDetailSheet` stored the two sides swapped in reverse mode (duplicate rows), `ScreenshotTranslationStore` never re-derived its target language after a mode switch, and four catalog defects (a Chinese translation consuming an English plural argument, four Chinese-keyed errors with no English localization, a stale marker, and a `Learning` key shared between an SRS state and a Settings tab).
