# Handoff.md — SwiftMandarin: Bilingual + Multi-Provider AI Overhaul

**Last Updated (UTC):** 2026-06-04
**Status:** Complete (build-verified on macOS + iOS; runtime test pending user secrets/GUI)
**Current Focus:** Four-part overhaul — (A) fix photo OCR Chinese gibberish/language lock, (B) multi-provider cloud AI with API-fetched model lists, (C) photo→AI cleanup toggle, (D) make the app fully bilingual (dual narration + learner-mode toggle).

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
- 2026-06-04: Created. Full codebase read + 9-agent comprehension workflow; root causes verified; plan set.
- 2026-06-04: Implemented all five groups. Both platforms build green; detector logic verified 9/9. Status → ready for review/runtime test. Did NOT commit (awaiting user go-ahead).
