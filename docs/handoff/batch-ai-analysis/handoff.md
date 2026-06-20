# Handoff.md — Batch AI Word Analysis

**Last Updated (UTC):** 2026-06-21
**Status:** In Progress
**Current Focus:** Implement background batch AI word-analysis + AI-analysis import/export, and iron out existing edges.

## 1) Request & Context
- **User's request:** Batch-run the existing AI word-analysis over saved vocabulary with user-customizable parallelism. Process only words NOT yet analyzed; persist results. Per-word "rerun analysis with current model" button in the word detail view. Batch runs in the **background** (navigate away freely); batch controls + batch size live in the **settings menu**; **progress bar with a live count of successful analyses** and a **Cancel button** once running; progress persists & stays live when leaving/returning to settings. Make AI analysis **importable/exportable** in CSV/JSON vocab files. Also "iron out edges and issues."
- **Environment:** SwiftUI iOS 17+ / macOS. `@Observable @MainActor` singleton stores persisted via `PersistentCodableStore` (UserDefaults+JSON). Bilingual (Localizable.xcstrings, zh-Hans). Build target iOS 17.0.
- **Non-goals:** Not adding AI analysis to the static Phrases catalog. Not changing the AI provider/network layer.

## 2) Key architecture facts (verified by reading source)
- **AI analysis already persists** in `WordExplanationCacheStore` (MRU, max 400, key = normalized word + `directionToken`). `AIWordExplanationView` reads/writes it; `AIWordExplanationService` only holds an in-memory cache.
- Analyzed word for a term = **`term.headlineText`**, pinyin = `term.pinyin`, context = `term.glossText`. Persistent key ignores context → batch must store with same `(headlineText, directionToken)`.
- `directionToken = ExplanationDirection.current(forWord: word).cacheToken`.
- `generateExplanationWithProvider(for:pinyin:context:)` is the unified entry (Apple/Ollama/cloud); `@MainActor` but network suspends → N concurrent calls overlap = real parallelism.
- Settings: iOS `MoreView`→`AISettingsDetailView`; macOS `MacOSSettingsView`→`AISettingsTab`. Stores injected into WindowGroup and macOS Settings scene in `SwiftMandarinApp`.
- `parseImportData`/`importTerms` are internal only → safe to refactor. CSV cols: Chinese,Pinyin,Definition,Part of Speech,Date Added,Mastered.

## 3) Plan
1. `BatchExplanationController` singleton — background `Task` + bounded-concurrency `TaskGroup`, progress counters, cancel; unprocessed = cache miss for current direction.
2. `AIModelSettings.batchConcurrency` (1…10, default 3). `WordExplanationCacheStore.merge`/`explanations(forWords:)`. `SavedTerm.aiCacheCandidateWords`.
3. `BatchAIAnalysisView`/`Controls` (progress bar + live count + cancel + batch size); wire into `MoreView` (live badge) + macOS `AISettingsTab`; clearer "Regenerate" button in `AIWordExplanationView`.
4. Import/export: versioned envelope JSON (lossless `aiExplanations`) + CSV AI columns (human `AI Definition`/`AI Examples` + `AI Data` base64 lossless). Include-AI toggle. Backward compatible.
5. zh-Hans strings; clean iOS+macOS build (0 warnings); adversarial review workflow; fix; finalize.

## 4) To-Do
- [x] BatchExplanationController — `Models/BatchExplanationController.swift`
- [x] settings + cache helpers — `batchConcurrency`, `merge`, `explanations(forWords:)`, `aiCacheCandidateWords`
- [x] Batch UI + MoreView/macOS wiring + rerun button — `Views/Components/BatchAIAnalysisView.swift`
- [x] import/export AI analysis — envelope JSON + CSV AI columns + include toggle
- [x] localize (23 + 6 zh-Hans keys) + clean iOS & macOS build (0 warnings) + audit + fixes

## Status: COMPLETE (pending commit on user request)

### Verification
- **macOS build:** `xcodebuild -scheme SwiftMandarin -destination platform=macOS` → BUILD SUCCEEDED, 0 errors, 0 warnings.
- **iOS build:** `-destination 'platform=iOS Simulator,name=iPhone 17'` → BUILD SUCCEEDED, 0 errors, 0 warnings.
- **Round-trip logic test** (standalone `xcrun swift`): 4/4 PASS — multi-line quoted CSV field, CRLF boundary, base64 AI-data round-trip, envelope/legacy-array disambiguation.

### Parallel audit (51 confirmed issues across 8 dimensions) — triage
Fixed (in feature path / high-value / low-risk):
- **batchConcurrency lacked init** (my bug) — initialized in `AIModelSettings.init()` (clamped, default 3). *Caught by the audit before first build.*
- **AIWordExplanationView stale state across words** — `sheet(item:)` reuses the view instance; `.task(id:)` now keys on `word`+direction (`currentKey`) and resets; also shows the *generating* provider for cached results (`shownProviderName`/`displayedProvider`).
- **CSV multi-line quoted fields broke round-trip** — added quote-aware `splitCSVRecords`; uses `Character.isNewline` (handles the `\r\n` grapheme, which a literal `\n`/`\r` compare misses).
- **Export-sheet localization gaps** — `FormatCard` descriptions, `ExportActionRow` (→ LocalizedStringKey), success-overlay messages now localized; zh-Hans added.

Deferred (pre-existing, outside feature scope; documented for a follow-up pass):
- 7× "unconditional `import Translation`" — FALSE POSITIVE (weak-linked; both platforms build clean).
- Untracked `DispatchQueue.main.asyncAfter` in RubyTextView/EnglishRubyTextView/TranslateView copy-feedback (SwiftUI @State post-teardown mutation is a no-op, not UB).
- `inspector(isPresented: .constant(...))`, TranslationHistory dedup normalization, in-memory vs persistent AI cache key divergence, vision-model nil fallback, various silent-catch/force-unwrap error-UX, FeatureRow/About descriptions unlocalized, MACOSX_DEPLOYMENT_TARGET=26.2.

## 5) Decisions (added)
- Concurrency proven real: services are `@MainActor` but suspend at `await session.data` → N child tasks overlap on the network. Verified by reading CloudAIService/OllamaService.
- Batch is benign under same-headword collisions (idempotent store; second write wins) — no dedup lock added (avoids complexity/risk).

## 5) Decisions
- Engine = `@Observable @MainActor` singleton (matches every store) → progress survives teardown, observable anywhere. Concurrency via `withTaskGroup` sliding window of N.
- Skip-already-analyzed = per-term cache lookup for current direction (same lookup the detail view does).
- CSV lossless via base64(compact-JSON) column (line-splitting CSV parser can't hold raw JSON); JSON via versioned envelope.

## 10) Updates
- 2026-06-21: Created; full codebase read; architecture verified; implementation started.
