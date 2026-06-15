# Language-Direction Audit & Optimization Plan

**Date:** 2026-06-13 · **Scope:** whole app (19.6k lines Swift, 11-agent parallel audit + completeness critic)

## The Goal

The app must tailor itself to the **interface language**, treating it as the user's native language:

| Interface language | User is… | AI explanations | Saved-words headline (big) | Secondary (small) | Pinyin | TTS emphasis |
|---|---|---|---|---|---|---|
| **中文 (zh-Hans)** | Native Mandarin speaker **learning English** | **In Mandarin** | **English text** | Mandarin gloss | Hidden (native reads characters) | **English** |
| **English** | Native English speaker **learning Mandarin** | **In English** | **Chinese characters** | English definition | Shown, tone-colored | **Mandarin** |

Today the app is hardwired to the second row everywhere, regardless of interface language.

## Verified Findings (file:line)

### A. Core architecture gap
- **Nothing links `LocalizationManager.language` to presentation or AI.** `AppPreferences.learnerMode` exists but defaults to `.englishToMandarin` unconditionally (`AppPreferences.swift:175`) and is never synced with the interface language. No shared "which text is primary" abstraction exists; ~40 call sites each hardcode Chinese-first.
- `SavedTerm.chinese` is really a *headword* field: photo-extraction and workbook flows can store **English** text in it (e.g. `PhotoTranslateView.swift:1280` flips term/meaning). Display logic must detect each side's actual language by content (CJK detection), not trust field names.

### B. AI explanations — every provider path assumes "English-speaking learner"
- `AIWordExplanationService.swift:234` system prompt: "Explain Chinese words for English-speaking learners."
- `:25–96` FoundationModels `@Generable` guides: "definition … in English".
- `:479,623` user prompts: "Explain the Chinese word: …" (Ollama + cloud).
- `:488–558` Ollama JSON schema: "definition in English".
- `:660–676` cloud JSON instructions: "clear English definition".
- `:286,1203` example/collocation filtering checks only the `.chinese` field — breaks when the explained word is English.
- Cache keys (`:255,473,620`) ignore explanation language — stale cross-language hits after a toggle.
- `extractVocabulary` (`:776`) puts "meaning" in "the OTHER language" relative to the passage instead of the user's native language.
- `gradeWorkbook` (`:865–887`) never states which language explanations/summary should be in, and hardcodes English `fullSentence`.

### C. Saved-words database UI (VocabularyView.swift)
- Row `:480–493`: Chinese headline at 22–48 pt, pinyin subheadline, English definition `.caption` secondary — fixed.
- Detail sheet `:569`, macOS inspector `:868`: Chinese at 80/64 pt always.
- Speak buttons `:423,648,948`: `speakChinese(term.chinese)` only (wrong voice if headword is English).
- `:783,1052`: missing-definition fetch hardcodes `translateToEnglish`.
- AI-explain entry points pass `term.chinese` unconditionally.
- Toolbar labels say "Chinese font size".

### D. Learning surfaces
- `LearnView.swift:408–436`: flashcard front is always Chinese 72 pt + pinyin + Chinese TTS; English only on the back.
- `PhrasesView.swift:76–132`: Chinese headline rows + detail; Chinese-only TTS.
- `RubyTextView.swift:256,319` `WordDetailPopover`: Chinese 56 pt headline, Mandarin TTS primary.
- `EnglishRubyTextView.swift:85–200` `EnglishWordDetailSheet`: layout fits zh-native users but never inverts for en UI; some labels need catalog coverage.
- `TranslateView.swift:725–786`: result-section prominence ("ENGLISH" vs "CHINESE…") is direction-driven, not native-language-driven.
- `HistoryTabView.swift:300`: source-first rows, fixed.

### E. Photo / screenshots / grading
- `PhotoTranslateView.swift:556`: extracted-vocab list shows term big/meaning small, fixed; `:1268` save flips so the **Chinese** side is always the headword — backwards for zh-native users.
- `ScreenshotTranslationStore.swift:101`: default target language `.english` regardless of user (translation-for-comprehension should target the native language).
- `WorkbookGradingView.swift:651,741`: read-aloud hardcodes English voice (right for zh users, wrong for en users grading Chinese workbooks).

### F. Intents
- `ShortcutEntities.swift:25,87`: Siri result cards always title Chinese.
- `GetRandomPhraseIntent.swift:38,42`: always speaks/copies Chinese.
- `GetLearningStatsIntent.swift:62`: hardcoded English stat labels (not in catalog).
- `TranslateScreenshotsIntent.swift:43`: static `.english` default target.

### G. Knock-on breakage if B ships without this
- `LearningActivity.swift:90` `PartOfSpeechCategory.categorize()` matches English substrings only — Mandarin AI output ("名词/动词/…") would bucket everything to "other" and silently break the Stats POS chart.

### Not changing (audited, deliberately rejected)
- `Text("Settings")`-style literals flagged as "hardcoded English": they already resolve through `Localizable.xcstrings` (557 bilingual keys, verified in the prior localization iteration). No work needed.
- CSV/JSON export column order: swapping per language would break import round-trips. Format stays stable; it's data, not UI.
- `LearnerMode.displayName` mixed-language strings: intentionally shown in their own language emphasis.
- `AIProviderConfigView` test-connection prompt: internal connectivity check, not user-facing content.
- Live speech translation direction logic: correctly driven by the explicit conversation direction; only its word-detail popover inherits the popover fix.

## Plan (dependency-ordered)

1. **Foundations** — `LocalizationManager`: `nativeIsChinese`/`learningIsChinese`; sync `learnerMode` on language change + derive first-launch default. `SavedTerm` display extension: content-detected `chineseSide`/`englishSide`, `headline`/`gloss` per interface language, `showsPinyin`. `SpeechService.speakAuto` (CJK→zh voice, else en). Chinese POS patterns in `categorize()`. Localized `TranslationDirection.placeholder`.
2. **AI explanation service** — parameterize explanation language (= interface language) and word language (content-detected) through all three provider paths, second `@Generable` struct for the zh-explanation direction, fix filtering + cache keys, native-language `meaning` in `extractVocabulary`, native-language explanations + learning-language `fullSentence` in `gradeWorkbook`.
3. **AI explanation view** — orientation-aware example/synonym/collocation rendering (learning-language text prominent, native gloss secondary, pinyin only for Chinese text), TTS via `speakAuto`.
4. **Saved-words UI** — row/detail/inspector headline swap, pinyin visibility, speak/copy/translate-fetch direction, AI-explain passes the headword, "Headword size" labels.
5. **Learning surfaces** — flashcard front = learning language; phrases rows/detail; `WordDetailPopover` + `EnglishWordDetailSheet` orientation; TranslateView section prominence; history rows.
6. **Photo/screenshot/grading** — extracted-vocab display + save headword = learning-language side; screenshot default target = native language; grading read-aloud via `speakAuto`.
7. **Intents** — entity display representation swap, random-phrase speak/copy, localized stat labels, screenshot target "App language" default.
8. **Localization & verification** — new catalog keys with zh-Hans translations; zero-warning builds (macOS + iOS); adversarial review workflow over the diff; handoff.md update.
