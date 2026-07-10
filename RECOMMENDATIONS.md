# RECOMMENDATIONS — SwiftMandarin Step-Change Overhaul

**Date:** 2026-07-07 · **Branch:** `jul-07-2026-step-change-overhaul`

This document is the product of a systematic, multi-agent study of the entire SwiftMandarin codebase (~25,400 lines, 72 Swift files): **10 parallel subsystem mappers** read every file; **10 expert ideation lenses** (language-acquisition pedagogy, product/UX redesign, AI-native features, Apple-platform integration, motivation design, immersion reading, speech technology, data interoperability, accessibility/i18n, and architecture/performance) generated **140 raw proposals** from first principles; a synthesis pass deduplicated them into **104 recommendations across 10 themes**; and a completeness critic swept for gaps against competitor capability (Pleco, Anki, DuChinese, HelloChinese, Duolingo).

Ratings: **Impact** 1–5 (5 = transformative for users) · **Effort** S/M/L/XL.

---

## Executive summary: from toolbox to learning companion

SwiftMandarin today is an excellent *toolbox* — strong bilingual translation, OCR, workbook grading, a 10-provider AI stack, and clean bilingual UI. What it is **not yet** is a *learning companion*: it opens into a blank text field, hides its learning loop three taps deep, schedules reviews with a buggy home-grown SM-2 variant, has no concept of level or progression, no presence outside its icon, and keeps years of learner data in device-local UserDefaults.

The step change is a re-centering of the app around the **daily learning loop**:

1. **A purposeful front door** — a Home tab that answers "what should I do right now": streak, goal ring, due reviews, word of the day, continue-reading, quick actions.
2. **A trustworthy scheduler** — a pure, modern FSRS-based SRS engine with an in-session relearn queue, interval previews, and daily new-card budgets.
3. **Comprehensible input at your level** — an immersive Reader with tap-to-define ruby text, AI-generated graded stories built from *your own* vocabulary, and coverage analysis.
4. **Output practice, finally** — an AI conversation partner for voice roleplay, plus dictation, cloze/quiz, and tone drills.
5. **A coherent 2026 design language** — cards, goal rings, Liquid Glass surfaces, honest empty states, and an information architecture built around learner verbs.

### Flagship set (the coherent overhaul)

- **Today Home Tab: Open with Purpose**
- **Information Architecture Reset: Tabs Around Learner Verbs**
- **First-Run Onboarding That Configures the Whole App**
- **FSRS-5 Scheduler as a Pure, Tested SRS Engine**
- **Today's Mix: One-Tap Interleaved Daily Session**
- **HSK 3.0 Lexicon: Badges, Coverage Map, and Gap Decks**
- **Immersive Reader Mode**
- **AI Graded Reader Studio**
- **Karaoke Read-Along with Synced Word Highlighting**
- **AI Conversation Partner: Voice Roleplay**
- **Pronunciation Coach: Speak-and-Score**
- **Home & Lock Screen Widget Suite with Control Center Actions**
- **Due-Aware Review Notifications with Lock-Screen Grading**
- **Streaming AI via a Unified ProviderClient**
- **Sync-Ready Persistence Foundation (App Group + Indexed Store)**

### Implemented in this overhaul branch

The following subset ships on `jul-07-2026-step-change-overhaul` (chosen to be buildable in a single target with zero new entitlements; widgets/sync/notifications need new targets or capabilities and remain roadmap):

| Area | What ships |
|---|---|
| Home | New **Home tab** (default): greeting, streak, daily-goal ring, due-review card, word of the day, continue reading, quick actions, weekly activity |
| Navigation | New IA: iOS tabs **Home · Translate · Photo · Study · More**; Study hub (Review, Practice, Conversation, Reader, Library); macOS sidebar sections |
| SRS | **FSRS-4.5-class scheduler** (`SRSEngine`), in-session relearn queue, per-button interval previews, new-card daily budget, legacy SM-2 migration |
| Reader | **Reader mode**: text library, immersive tap-to-define reading with ruby text, unknown-word awareness, per-text progress, read-aloud, **AI Story Studio** (graded stories from your vocabulary) |
| Conversation | **AI Conversation Partner**: scenario roleplay, pinyin + translation reveal per bubble, voice input, corrections, TTS |
| Practice | **Practice hub**: multiple-choice vocabulary quiz with smart distractors, **dictation** (listen → type → diff), **tone-pair drills** |
| Vocabulary | Detail view shows **all AI-explanation sections expanded by default** (definition, nuance & context, grammar usage, synonyms/antonyms, collocations); **swipe left/right (and ⌘-arrow / toolbar arrows on iPad & macOS) to move to the previous/next word** without leaving the detail view |
| Bilingual parity | Dual-perspective audit (English speaker learning 中文 **and** Mandarin speaker learning English): every new surface adapts headline language, pinyin visibility, TTS order, and AI output language to the interface language |
| Polish | Per-syllable tone coloring in ruby text, TTS voice/speed controls + audio-session fix, streak correctness at midnight, heatmap week alignment, regenerate-explanation fix, cloud-provider availability fixes, translation draft persistence, history filter/reorder fixes, workbook re-grade fix, haptics default fix, macOS menu-bar quick translate |
| Onboarding | First-run welcome flow configuring language direction, daily goal, and AI |

Everything else below is the prioritized roadmap.

---

## Contents

1. [A New Front Door: Home, Navigation & First-Run Experience](#a-new-front-door-home-navigation-first-run-experience)
2. [Modern SRS & the Daily Study Loop](#modern-srs-the-daily-study-loop)
3. [Curriculum, Progress & Motivation](#curriculum-progress-motivation)
4. [Immersive Reader & Comprehensible Input](#immersive-reader-comprehensible-input)
5. [Speaking & Listening Lab](#speaking-listening-lab)
6. [AI Tutor Everywhere](#ai-tutor-everywhere)
7. [Platform Presence & Ambient Capture](#platform-presence-ambient-capture)
8. [Data Ownership, Sync & Backup](#data-ownership-sync-backup)
9. [Accessibility & Inclusive Mandarin](#accessibility-inclusive-mandarin)
10. [Engineering Foundation & Performance](#engineering-foundation-performance)
11. [Completeness-critic additions](#completeness-critic-additions)
12. [Codebase health: defects & debt found during the study](#codebase-health-defects--debt-found-during-the-study)


## 1. A New Front Door: Home, Navigation & First-Run Experience

> The app currently opens into a blank text editor and buries its learning loop three taps deep. Restructuring around a purposeful home screen, verb-based tabs, real onboarding, and consistent interactions converts a translation utility into a daily learning practice — the perceptual core of the step change.

### Today Home Tab: Open with Purpose
**Impact 5/5 · Effort Large (1–2 weeks)**

A new first tab replacing Translate as the landing screen: hero streak ring with today's goal, a 'Continue' card resuming the last activity, Word of the Day, a 'Due now: 12 cards' pill launching straight into review, recent saves, and three large quick actions (Translate, Scan, Speak) deep-linking via AppRouteStore.

*Why:* Category-defining learning apps open into 'what should I do right now'; all the data (streak, due counts, history, drafts) already exists in stores but nothing surfaces it.

*Integration:* New AppTab rendered first in ContentView; reads LearningActivityStore, LearningProgressStore, TranslationHistoryStore, SavedTermsStore; quick actions reuse AppRouteStore pending-action plumbing.

### Information Architecture Reset: Tabs Around Learner Verbs
**Impact 5/5 · Effort Large (1–2 weeks)**

Restructure iOS tabs to Today, Translate, Scan, Learn, Library: Scan merges Photo + Workbook Grading behind a mode switcher, Learn promotes flashcards out of More→Learning Tools, Library merges Vocabulary + History, Settings moves to a toolbar gear, and the More tab dies. macOS sidebar mirrors the same five sections.

*Why:* The core review loop is three taps deep inside a settings hub — the current IA says translation utility, not learning app; the merge also fixes the dropped cold-launch Siri intent.

*Integration:* Rework AppTab enum and ContentView platform splits; MoreRoute destinations become toolbar-sheet routes; AppRouteStore tab cases updated.

### First-Run Onboarding That Configures the Whole App
**Impact 5/5 · Effort Medium (days)**

Three skippable screens: (1) 'Who are you?' cards setting LearnerMode, UI language, and default direction in one tap with live preview; (2) 'Try it' — a sample translation teaching the signature tap-a-word interaction, ending with saving the first word; (3) daily goal picker and notification priming.

*Why:* Learner mode — the setting that reorients the entire app — is hidden in More→Quick Setup, and the tap-a-word interaction is completely undiscoverable; first-run is where retention is won.

*Integration:* fullScreenCover gated by a hasOnboarded flag in ContentView; writes AppPreferences.learnerMode and LocalizationManager.language; reuses RubyTextView, WordDetailPopover, SavedTermsStore.

### One Adaptive Translate Button
**Impact 4/5 · Effort Medium (days)**

Collapse the three duplicated Apple/AI button clusters into a single prominent 'Translate' action that routes automatically, with a small engine/direction chip for override, an inline 'Retry with other engine' link after results, and a 'Set up translation' path when no provider is configured.

*Why:* Users shouldn't choose infrastructure — two engines across three button locations is six ways to do one thing, and the silent direction auto-detection actively confuses.

*Integration:* Refactor TranslateView's triplicated clusters into one TranslateActionBar wrapping existing triggerTranslation/startAITranslation; setup path deep-links to AIProviderConfigView.

### Launchpad Empty States
**Impact 3/5 · Effort Small (hours)**

Every empty state becomes a starting point: Vocabulary offers starter packs and a pre-filled sample translation; Learn's misleading 'No cards due. Great job!' becomes 'Start with 10 new cards' (wiring the unused getDueCards path); History and Scan teach their gestures with ghosted examples.

*Why:* First sessions currently dead-end — a new user opening Learn is told there is nothing to do despite unlearned cards; empty states are each feature's real onboarding surface.

*Integration:* Replace placeholders in VocabularyView, LearnView, HistoryTabView, PhotoTranslateView; starter packs reuse PhraseCategory data plus SavedTermsStore.add.

### TipKit Progressive Feature Discovery
**Impact 3/5 · Effort Small (hours)**

Contextual TipKit tips reveal hidden depth exactly when relevant: tap-a-word after the first translation, the tone-color legend (currently unexplained), flashcard review after saving five words, and the AI-cleanup revert badge after a photo OCR — each shown once, precondition-gated, synced across devices.

*Why:* The dense feature set (tap-to-learn, tone colors, SRS, workbook grading) is undiscoverable from a five-tab shell; TipKit is the native zero-maintenance answer.

*Integration:* popoverTip/TipView modifiers in TranslateView, RubyTextView, VocabularyView, PhotoTranslateView; Tips.configure in app init; events donated from existing handlers.

### Unified Progressive-Disclosure Word Card
**Impact 4/5 · Effort Medium (days)**

One WordCard component with three disclosure tiers (Glance / Detail / AI Deep Dive) replaces the four near-duplicate detail surfaces, adapting its container automatically (bottom sheet on iPhone, popover on iPad, inspector on Mac) and fixing whole-word tone coloring with per-syllable colors everywhere.

*Why:* The same 'learn this word' moment currently looks and behaves four different ways, and the biggest learner-facing inaccuracy (whole-word tone coloring) lives in the most-used one.

*Integration:* New shared WordCard replaces WordDetailPopover, EnglishWordDetailSheet, TermDetailSheet, TermDetailInspector at their call sites; uses PinyinConverter.coloredPinyin and presentationDetents.

### Universal Undo Layer
**Impact 4/5 · Effort Medium (days)**

Every destructive action (delete term, clear history, clear vocabulary, remove workbook session) executes immediately and shows a 5-second 'Deleted 你好 · Undo' glass toast backed by in-memory store snapshots; confirmation alerts disappear except for full Reset Progress, and macOS registers NSUndoManager so Cmd-Z works.

*Why:* The app mixes one-tap irreversible destruction (Clear All has no confirmation) with alert friction elsewhere; undo is both safer and faster — the platform-native answer.

*Integration:* Shared @Observable UndoCenter injected via environment; snapshot/restore helpers on SavedTermsStore, TranslationHistoryStore, LearningProgressStore, WorkbookGradingHistoryStore.

### Liquid Glass Adoption Pass
**Impact 3/5 · Effort Medium (days)**

Systematic iOS 26 Liquid Glass adoption: minimizing glass tab bar for full-bleed reading, interactive glassEffect on the mic and save actions, a floating GlassEffectContainer capsule that morphs into the word-detail sheet, bottom-aligned search, and tone-colored pinyin on glass chips — with pre-26 fallbacks.

*Why:* The material-backed cards and stock chrome read as iOS 17; morphing glass makes tap-a-word — the signature interaction — feel physical and premium.

*Integration:* Availability-gated modifiers on ContentView's TabView, TranslateView actions, RubyTextView chips, and Library search, following the existing CompatModifiers pattern.

### Seamless Language Flip with Preserved State
**Impact 3/5 · Effort Medium (days)**

Replace the whole-tree .id(language) rebuild with scoped locale-driven relocalization plus a brief cross-fade, preserving navigation paths, scroll positions, tab selection, and in-progress drafts; the learner-mode picker gains a live preview, and any silent direction rewrite surfaces an inline Undo notice.

*Why:* Language switching is a headline feature of this bilingual-household app, yet today it dumps users to root, wipes their draft, and secretly changes settings — the app's most jarring moment.

*Integration:* Scope relocalization via the locale environment and an observable localization token in L(); persist MoreView path, TranslationState draft, and selected tab via SceneStorage.

<sub>Merged proposals: Live language flip without losing your place; Replace whole-tree language rebuild with scoped locale updates</sub>

### iPad Three-Column Study Desk with Drag-to-Save
**Impact 4/5 · Effort Large (1–2 weeks)**

On regular-width iPad, Translate and Scan adopt a canvas layout: source text left, interactive ruby output center, and a persistent right inspector showing the tapped word's detail above the vocabulary list — with word chips draggable into the vocabulary pane to save, finally giving RubyWordView's existing .draggable payload a drop target.

*Why:* iPad currently gets stretched iPhone layouts; a spatial reading-plus-reference layout is what studying actually looks like on a big screen.

*Integration:* Size-class branch in TranslateView/PhotoTranslateView; inspector reuses WordDetailPopover content and SavedTermsStore.


## 2. Modern SRS & the Daily Study Loop

> The scheduler is the pedagogical heart of the app and currently has documented correctness bugs, zero tests, and a burial-ground UX. Replacing it with a tested FSRS engine, one smart daily session, active-recall card types, and honest pacing controls turns flashcards from a toy into a trustworthy learning system.

### FSRS-5 Scheduler as a Pure, Tested SRS Engine
**Impact 5/5 · Effort Large (1–2 weeks)**

Extract scheduling from CardProgress into a pure, property-tested SRSEngine and upgrade it to FSRS-5: difficulty/stability/retrievability per card, user-set desired retention, in-session relearn requeue for 'Again' cards, interval-based mastery, and a one-time migration converting existing review history so no progress is lost. Fixes the known defects: broken graduation steps, unused lapse counter, and relearns lost between sessions.

*Why:* FSRS empirically beats SM-2 by 20-30% fewer reviews for equal retention, and a pure tested engine makes the learning loop trustworthy — the single highest-leverage learning-science fix in the app.

*Integration:* New Models/SRSEngine.swift consumed by CardProgress.recordReview and LearningProgressStore.getCardsForReview; LearnView gains the relearn queue; persists via existing PersistentCodableStore with a migrating decoder.

<sub>Merged proposals: FSRS-5 Scheduler with In-Session Relearn Queue; Extract a pure, tested SRS engine and fix scheduling correctness</sub>

### Legible, Celebratory Review Sessions
**Impact 4/5 · Effort Medium (days)**

Make the SRS visible and the finish line rewarding: every rating button shows its projected interval ('Good · 6d'), 'Again' cards visibly slide to the back of the queue, a progress bar tracks the session, and completion celebrates with a streak flame, count-ups, mastery particle bursts, gold Library badges, and haptics.

*Why:* The current session hides the scheduler and drops failed cards silently; making the algorithm legible and the finish celebratory is what turns a flashcard screen into a habit.

*Integration:* Rating buttons call engine.preview(quality:) for interval labels; requeue is an in-session array append; completion screen extends the existing session-complete state.

<sub>Merged proposals: Review sessions that feel earned: interval previews, requeue, celebration; Show the next interval on every rating button</sub>

### Today's Mix: One-Tap Interleaved Daily Session
**Impact 5/5 · Effort Medium (days)**

A single prominent 'Start Today's Session' entry composes the correct session automatically: due reviews first, a capped number of new cards, 'Again' cards requeued at the end, and tone-drill/cloze questions interleaved every ~8 cards — with estimated time shown up front, a 'Quick 10' variant, and adaptive composition on heavy-lapse days. Finishing marks the day complete on the heatmap.

*Why:* Interleaving beats blocked practice, and decision fatigue over the current Source × Mode matrix is why streaks die; one correct default gives every visit a clear beginning and end.

*Integration:* New session composer over LearningProgressStore.getDueCards (currently unused) plus drill and cloze sources; replaces LearnView's mode pickers as the default entry; exposed to StartReviewIntent.

<sub>Merged proposals: Today's Mix: One Interleaved Daily Session; Daily Mix: one-tap smart session sized to your goal</sub>

### Daily Goal Ring and New-Card Budget
**Impact 5/5 · Effort Medium (days)**

An Apple-Watch-style ring driven by the existing activityScore units, with presets (Casual 10 / Regular 25 / Serious 50), fills live across the app and snaps closed with a haptic on completion; a hard new-card daily budget prevents the classic Anki overload spiral (50 new cards Monday, 400 reviews Friday). Wires the currently-inert macOS dailyGoal setting on both platforms.

*Why:* The app already counts every event but gives users no target — the most proven retention primitive — and unbudgeted new cards are the classic reason SRS users quit.

*Integration:* Reads DailyActivity.activityScore from LearningActivityStore; goalTarget in AppPreferences replaces the dead @AppStorage key; ring views in StatsView hero and LearnView header; budget enforced in the session composer.

<sub>Merged proposals: Daily Goal, New-Card Budget, and Due Reminders; Daily Goal Ring (wire up the dead dailyGoal setting)</sub>

### Four-Skill Card Facets with Voice-Graded Recall
**Impact 5/5 · Effort Large (1–2 weeks)**

Each vocabulary item expands into up to four independently scheduled facets: Recognition (see hanzi), Listening (audio-first, hanzi hidden), Recall (type pinyin with tone numbers), and Production (speak the Chinese, checked against SpeechRecognitionService — a match auto-fills the flip and pre-selects 'Good'). Facet ids extend the existing namespace ('vocab:<UUID>#listen') so each skill has its own SRS state.

*Why:* Recognizing 你好 on a card doesn't mean you can hear it or say it — skill-specific retrieval is a core testing-effect finding, and voice-graded production doubles the pedagogical value of every session.

*Integration:* Extend LearningCard id namespacing and LearnView with facet-specific fronts; typing validation via PinyinConverter tone-number mode; speaking check via SpeechRecognitionService; scheduling reuses CardProgress per facet id.

<sub>Merged proposals: Four-Skill Card Facets: Recognition, Listening, Recall, Production; Speak-the-answer flashcards: SRS reviews graded by voice</sub>

### Context Cloze Cards from AI Example Sentences
**Impact 4/5 · Effort Medium (days)**

Flashcard fronts show a cached AI example sentence with the target word blanked ('我想___一杯咖啡') instead of the bare headword, rotating across reviews so cards never become memorized shapes; words without cached examples fall back to classic fronts, with batch generation ('Generate sentences for 214 words') riding the existing BatchExplanationController and packs exporting inside the v2 JSON envelope.

*Why:* Context-based retrieval transfers to real reading far better than isolated-word recall, and the sentences, cache, batching, and rendering all already exist — a near-pure recombination win.

*Integration:* LearnView card front reads WordExplanationCacheStore examples; toggle in Learning settings; backfill via BatchExplanationController; export via VocabularyImportExportService.

<sub>Merged proposals: Cloze Cards From Cached AI Example Sentences; Context Cards: AI example-sentence packs for every saved word</sub>

### AI Quiz Mode: Cloze with Smart Distractors
**Impact 4/5 · Effort Medium (days)**

A 'Quiz' study mode where one AI call batch-generates a natural cloze sentence per due word plus three genuinely confusable distractors (near-synonyms, same-radical characters, similar pinyin); wrong picks get a one-line explanation, results feed the same recordReview scheduling path, and questions cache per word until it levels up.

*Why:* Recognition-only flashcards plateau, and smart distractors are precisely what LLMs do better than any hand-built quiz engine — slotting directly into the existing SRS with no new data model.

*Integration:* New StudyMode in LearnView; batch JSON generation mirrors BatchExplanationController's bounded-concurrency pattern; grading writes through LearningProgressStore.recordReview.

### Dictation Practice (听写): Hear It, Write It
**Impact 4/5 · Effort Medium (days)**

A listening-first study mode: the app speaks a saved term or phrase with text hidden, the user types the hanzi (or tone-number pinyin), and submissions are diffed character-by-character — with replay count factored into the ReviewQuality grade so dictation flows straight into the scheduler.

*Why:* Dictation trains listening and character recall simultaneously — the classic exercise every Chinese schoolchild does — and the app has all the pieces but no listening-first review path today.

*Integration:* New StudyMode case in LearnView with a text-entry card face; grades call LearningProgressStore.recordReview; uses SpeechService with rate control.

### Leech Rescue: AI Mnemonics and Confusable Drills
**Impact 4/5 · Effort Medium (days)**

Cards with 4+ lapses are flagged as leeches in a 'Struggling Words' section (the persisted-but-unused lapse counter finally earns its keep); one tap generates a keyword-method mnemonic stored on the card back, and detected confusable pairs (买/卖) get short side-by-side fill-the-blank disambiguation drills.

*Why:* 20% of cards consume 80% of review time and Anki just suspends them; active remediation with mnemonics and contrastive drills turns the worst time sink into targeted learning.

*Integration:* Reads CardProgress.lapse; mnemonic generation via AIWordExplanationService cloud path cached in WordExplanationCacheStore; new section and drill sheet in LearnView.

### One-Tap Sentence Mining with i+1 Detection
**Impact 5/5 · Effort Large (1–2 weeks)**

Everywhere a sentence appears (Translate output, OCR results, live speech transcripts, Reader), a long-press or 'Mine this sentence' action analyzes it against the known-word set: exactly one unknown word (i+1) offers a one-tap cloze card with pinyin, translation, audio, and source attribution; multi-unknown sentences let the user pick the target. Mined sentences become a SentenceCard type reviewed alongside vocab, and term detail views list all mined sentences containing them.

*Why:* Sentence mining is how serious learners (Refold/AJATT) actually acquire vocabulary — the app already surfaces rich authentic sentences and currently discards them.

*Integration:* Context menu in RubyTextView plus buttons on TranslateView/PhotoTranslateView/LiveSpeechTranslationView; uses ChineseTextAnalyzer segmentation + known-set check; new SentenceCard ('sentence:<UUID>') rendered by LearnView.

### Smart 'What to Learn Next' Recommender
**Impact 4/5 · Effort Medium (days)**

A 'Suggested Words' feed ranking the 10 highest-value unknown words by frequency rank, HSK-band adjacency, and component overlap with known characters, each with a one-tap 'Add to deck' and a 'Why this word?' explanation ('#89 most frequent; you already know both characters').

*Why:* Self-directed learners save random words and miss the high-frequency core; frequency-plus-prior-knowledge ranking is a simple algorithm with outsized acquisition ROI that supplies daily sessions with optimal new cards.

*Integration:* Ranking service over the HSK lexicon + LearningProgressStore known set + decomposition table; UI in VocabularyView and the Today's Mix completion screen; adds flow through SavedTermsStore.add.

### Gentle Comeback Flow with Backlog Forgiveness
**Impact 4/5 · Effort Medium (days)**

Returning after 4+ inactive days shows a calm welcome instead of a wall of 90 overdue cards: a 10-card Comeback Session of the strongest due cards, plus one-tap 'Reschedule the rest' spreading the backlog over 7 days (adjusting nextReviewDate, never deleting progress), with the old streak framed as a record to beat.

*Why:* The overdue avalanche is the classic SRS churn moment; explicit debt forgiveness protects the value of every other retention feature.

*Integration:* Lapse detected from LearningActivityStore dateKeys on scenePhase foreground; backlog spreading mutates CardProgress.nextReviewDate; comeback sheet presented from LearnView.


## 3. Curriculum, Progress & Motivation

> The app has zero notion of level, no map of what to learn next, and swallows every achievement silently. An HSK/frequency lexicon, a known-word model, honest proficiency metrics, and adult-appropriate motivation mechanics (shields, quests, recaps, records) convert a notebook of random words into a course with a visible destination.

### HSK 3.0 Lexicon: Badges, Coverage Map, and Gap Decks
**Impact 5/5 · Effort Large (1–2 weeks)**

Bundle a compact HSK 3.0 + frequency dataset (~11k entries, a few hundred KB): every term, tapped word, and popover shows an HSK band and frequency rank badge; a 'Your Level' screen shows per-band coverage bars ('HSK 1: 132/150 known') with one-tap gap decks ('Add all 18 missing HSK-1 words to flashcards'); unknown-word lists sort by frequency; and the same dictionary supplies word-level pinyin readings, fixing the documented polyphone problem (银行 háng). Crossing a band triggers a milestone moment.

*Why:* Learners need a map of where they are and what to learn next — frequency-ordered acquisition is the highest-ROI vocabulary strategy, HSK is the canonical Mandarin ladder, and one bundled file upgrades five other features.

*Integration:* Bundled lexicon service consulted by SavedTerm, WordDetailPopover, RubySegment, PinyinConverter fallback, and LearnView deck builders; Levels card in StatsView; gap decks feed SavedTermsStore.add.

<sub>Merged proposals: HSK 3.0 / Frequency Tagging and Coverage Map; HSK Level Progress: a map of the mountain; HSK level & frequency badges on every word</sub>

### Known-Word Knowledge Model (LingQ-Style Word States)
**Impact 5/5 · Effort Medium (days)**

A per-word knowledge ledger — New (blue), Learning (yellow), Known, Ignored — visible as highlights in Reader and OCR results, cyclable with one tap, and auto-promoted by app behavior (saving marks Learning, SRS proficiency marks Known), with a bulk 'mark all visible known' seeding flow for intermediate learners.

*Why:* This is the core mechanic that made LingQ a category: the app finally knows what YOU know, unlocking coverage analysis, graded content ranking, and honest progress metrics.

*Integration:* New WordKnowledgeStore (file-backed PersistentCodableStore, normalizedKey reuse); hooks in SavedTermsStore.add, LearningProgressStore.recordReview, RubyTextView/Reader rendering, and WordDetailPopover.

### Text Coverage Analyzer: 'Can I Read This?'
**Impact 4/5 · Effort Small (hours)**

Paste, share, or pick any text for an instant comprehension report — '87% known · 42 unknown words · estimated level: intermediate' — with unknown words listed by in-text frequency, save/mark-known buttons, 'Save top 10', and a difficulty gauge mapping coverage to readability (98%+ extensive, 90-95% study text, <90% too hard).

*Why:* Turns the eternal learner question 'is this text right for me?' into a one-tap answer and converts any text into a prioritized study list — cheap once the knowledge model exists.

*Integration:* Pure function over ChineseTextAnalyzer.segmentWords + WordKnowledgeStore + SavedTermsStore; sheet from Reader toolbar, PhotoTranslateView results, and the Learn hub.

### AI Placement Test and Living Level Profile
**Impact 4/5 · Effort Medium (days)**

A 3-minute adaptive onboarding quiz (~15 escalating items) binary-searches to an estimated HSK band stored as a LearnerProfile that thereafter updates passively from SRS mastery, quiz accuracy, and workbook scores — the single shared answer every generative feature (stories, lessons, conversation difficulty) reads instead of guessing, with a level-trend chart in Stats.

*Why:* All generation features need one consistent answer to 'how good is this user?', and a visibly rising level is itself a powerful retention metric.

*Integration:* Onboarding sheet + LearnerProfile via PersistentCodableStore; recomputed from LearningProgressStore/WorkbookGradingHistoryStore aggregates; read by all AI prompt builders.

### Proficiency & Forecast Dashboard
**Impact 4/5 · Effort Medium (days)**

StatsView's headline becomes an estimated known-word count and mapped HSK level ('≈ HSK 3, 61% toward HSK 4'), a 30-day retention forecast from FSRS retrievability decay ('stop today vs keep reviewing'), and a 14-day due-load forecast bar chart — today's bar tappable to start the session, with annotations like 'Reviewing today keeps tomorrow light' and week-over-week deltas.

*Why:* Learners persist when they can see proficiency growing, not translation counts; FSRS makes retention mathematically forecastable, and the due forecast makes spaced repetition legible.

*Integration:* Swift Charts sections in StatsView computed from LearningProgressStore card states + HSK frequency ranks; retrievability function reused from the SRS engine; forecast strip repeated in LearnView's header and completion screen.

<sub>Merged proposals: Proficiency Estimate and Retention Forecast Dashboard; Review Forecast: show the SRS's future</sub>

### Character Decomposition, Radicals & AI Mnemonic Stories
**Impact 4/5 · Effort Large (1–2 weeks)**

Word detail sheets gain a 'Character breakdown' section from a bundled IDS decomposition table (~9k characters): components with glossed semantic radicals ('妈 = 女 woman + 马 mǎ horse — the horse gives the sound'), phonetic-series links to characters you already know, an optional AI-generated one-line mnemonic image cached permanently and shown on flashcard backs, plus a 100-radical mini-course as its own SRS deck.

*Why:* Component awareness is the strongest predictor of character-learning speed (Heisig-method mnemonics roughly double retention), and it converts the isolated word list into an interconnected knowledge graph.

*Integration:* Bundled IDS/radical JSON + lookup service; new sections in WordDetailPopover and AIWordExplanationView cached in WordExplanationCacheStore; radical deck uses the 'radical:' id namespace on existing LearningCard/CardProgress.

<sub>Merged proposals: Character Decomposition and Radical Insight; Character Stories: AI mnemonics and component breakdowns</sub>

### Streak Freeze Shields, Earned Not Bought
**Impact 4/5 · Effort Small (hours)**

Every 7 consecutive active days earns a Streak Shield (max 2 banked) that is consumed automatically on a zero-activity day — the heatmap cell renders a shield glyph, the streak survives, and a quiet post-hoc note appears once in Stats. No purchases, no begging notifications.

*Why:* Streak anxiety is the top reason adults abandon streak systems; a transparent earned freeze converts one bad day from 'I quit' into 'the system had my back'.

*Integration:* Extends LearningActivityStore with shieldsEarned/consumed; currentStreak treats shielded dateKeys as active; ContributionCell renders a shield variant.

### Weekly Quests from Your Own Weak Spots
**Impact 4/5 · Effort Large (1–2 weeks)**

Every Monday, three quests generate from real user data ('Clear 30 due reviews', 'Save 8 new verbs — your least-collected POS', 'Grade one workbook page'), shown as progress cards in Stats and a chip in Learn; completing all three banks a Streak Shield and XP. Quests never require paid AI calls and expire quietly.

*Why:* Quests add mid-horizon structure between the daily goal and HSK levels, and personal-data-driven quests feel like coaching rather than gamification.

*Integration:* New QuestStore generating from LearningActivityStore, LearningProgressStore, and DailyActivity.wordsByPartOfSpeech; progress updated in the four existing record* entry points.

### XP and Proficiency Levels with Visible Math
**Impact 3/5 · Effort Medium (days)**

activityScore events grant XP on the same weights (no second economy), driving a gentle level curve with learning-themed names (Beginner → Reader → Conversationalist); '+12 XP' toasts show a one-line breakdown and an info popover exposes the exact formula — no mystery numbers, and lifetime XP back-fills instantly by summing persisted DailyActivity scores.

*Why:* Streaks reward showing up; XP rewards volume and gives lapsed-streak users a progress vector that never resets — while fixing the current invisible activity weighting.

*Integration:* Derived from summed DailyActivity scores; badge components in the Learn hub header and StatsView hero; toast in LearnView completion.

### Milestone Moments and a Personal Records Shelf
**Impact 3/5 · Effort Medium (days)**

Crossing thresholds (7/30/100-day streaks, 100/500 words, first mastered card, best-day score, HSK band completion) triggers one tasteful full-screen moment with falling hanzi confetti; Stats gains a Records row (Best day, Longest streak, Most reviews, Largest session) with set dates and a new-record shimmer.

*Why:* The app currently swallows every achievement silently; records give competitive-with-self adults a bar to beat that survives streak breaks.

*Integration:* MilestoneEvaluator inside the four LearningActivityStore.record* calls; records computed from the existing activities dictionary; celebration presented from ContentView via an event queue.

### Shareable Milestone and Word Cards
**Impact 3/5 · Effort Medium (days)**

Milestones, weekly recaps, and any single vocabulary word render as beautiful 1080×1350 share images via ImageRenderer — large hanzi headline, tone-colored pinyin, stat line, heatmap strip, small app mark — shared through standard ShareLink with nothing auto-posted.

*Why:* Word-of-mouth is the only free acquisition channel a solo dev gets, and Chinese characters plus the existing tone-color renderer make these cards distinctive rather than generic stat screenshots.

*Integration:* ImageRenderer over a ShareCardView reusing PinyinConverter.coloredPinyin and heatmap cells; ShareLink buttons on milestones, StatsView, and term detail.

### Monday Recap: Your Week in Mandarin
**Impact 4/5 · Effort Medium (days)**

A swipeable weekly recap sheet: words saved vs last week with deltas, accuracy trend, most productive day, the hardest word of the week (most 'Again' ratings) with one-tap re-study, next week's forecast, quest results, and one editable intention — dismissable in two swipes, archived under Stats.

*Why:* Weekly reflection converts raw counters into felt progress — answering 'am I actually improving?' — and the store's weeklyTotals/weeklyWordsByPOS APIs are already built and currently dead code.

*Integration:* Uses existing unused LearningActivityStore.weeklyTotals/weeklyWordsByPOS plus per-card ReviewQuality history; presented from ContentView on week rollover.

### Reading Stats: Volume and Comprehension Over Time
**Impact 3/5 · Effort Small (hours)**

Reader sessions record characters read, unique/new words seen, words marked known, and minutes spent; a fifth event type joins the heatmap so reading days count toward the streak, and Stats gains cumulative volume milestones ('you've read the length of one novel') plus a comprehension trend line (average coverage 84% → 91%).

*Why:* Immersion progress is invisible day-to-day, which kills motivation; volume-read and known-word growth are the metrics immersion learners actually trust and screenshot.

*Integration:* Extend DailyActivity with charactersRead/minutesRead (tolerant decoder handles new fields); Reader posts to LearningActivityStore; chart cards reuse existing Swift Charts patterns.

### Speaking & Listening Analytics
**Impact 3/5 · Effort Medium (days)**

A Stats section with a per-tone accuracy bar chart from pronunciation checks, a 4×4 tone-confusion heatmap from minimal-pair drills ('you hear tone 2 as tone 3 41% of the time'), trouble-initials chips, and practice minutes — every weak spot deep-linking into the matching drill pre-configured to target it.

*Why:* Once speaking features exist, diagnostics-that-launch-drills turn raw stats into a coaching system and a daily reason to return.

*Integration:* New event types on LearningActivityStore/DailyActivity; Swift Charts sections in StatsView; deep-links via AppRouteStore pendingAction into drill views.


## 4. Immersive Reader & Comprehensible Input

> The app's strongest asset — tappable ruby text with segmentation and TTS — is trapped inside short translation outputs. A dedicated Reader with AI-generated i+1 stories, karaoke read-along, and frictionless import of articles, books, and subtitles is the single biggest category shift available: from translator to LingQ/DuChinese-class immersion tool.

### Immersive Reader Mode
**Impact 5/5 · Effort Large (1–2 weeks)**

A full-screen, chrome-free reading surface for any long or translated text: paginated book-like prose (not chips) with adjustable font, per-word or per-screen pinyin toggle, night mode, tap-a-word detail cards that don't break flow, sentence TTS, chunked off-main segmentation so 10,000-character texts stay smooth, persistent reading position, and an exit summary ('Read 240 characters, saved 6 words') that feeds the heatmap.

*Why:* Reading is the app's strongest machinery crammed inside utility screens; a dedicated immersive mode turns pasted articles, menus, and OCR results into study sessions — a genuinely differentiating flagship surface most other ideas plug into.

*Integration:* Launched from TranslateView/PhotoTranslateView and as the Reader/Library root; composes ChineseTextAnalyzer, RubyTextView, PinyinConverter, WordDetailPopover, SavedTermsStore; new ReaderDocumentStore on PersistentCodableStore's file-backed path.

<sub>Merged proposals: Immersive Reader mode: full-screen study of any text; Reader Mode: full-screen immersive reading for long text</sub>

### AI Graded Reader Studio
**Impact 5/5 · Effort Large (1–2 weeks)**

'New Story' generates a 100-600 character story or dialogue constrained to the user's known words plus a controlled 3-8 due/new target words, at chosen topic, genre, length, and formality; it opens in Reader with target words highlighted, full TTS with word highlighting, 2-3 AI comprehension questions afterward, SRS review credit for embedded due words, and a persistent re-readable story shelf whose level rises with the user's mastery distribution.

*Why:* Comprehensible input at exactly i+1 density is the holy grail of acquisition and impossible without AI — no competitor generates readers personalized to the learner's exact known-word inventory; this makes the user's own vocab data the engine of infinite content.

*Integration:* Prompt built from WordKnowledgeStore/LearningProgressStore + HSK lexicon via the existing provider routing in JSON mode; rendering reuses Reader, RubyTextView, SpeechService; stories persisted as ReaderDocuments; entry cards on the Learn hub and Reader library.

<sub>Merged proposals: AI Graded Reader: Stories From Your Own Vocabulary; Graded Reader Studio: stories generated at the user's exact level; AI graded stories from YOUR vocabulary (n+1 generator)</sub>

### Karaoke Read-Along with Synced Word Highlighting
**Impact 4/5 · Effort Medium (days)**

A play button on any Chinese text reads it aloud while the currently spoken word highlights in real time and auto-scrolls (AVSpeechSynthesizer willSpeakRangeOfSpeechString mapped to RubySegment ranges), with 0.5x-1.2x rate control, pause/resume, tap-to-jump playback, per-sentence repeat for shadowing, enhanced-voice preference, and tap-the-pinyin to drill a single syllable; tapping a highlighted word pauses and opens its detail.

*Why:* Listening-while-reading is the highest-bandwidth immersion mode (DuChinese's signature) and a proven technique for tonal-language acquisition; the segments and TTS already exist — the delegate wiring is the missing 20% that delivers 80% of the experience.

*Integration:* SpeechService becomes an @Observable TTS controller publishing spoken-range events; RubyTextView/Reader add a highlightedRange binding; works in Translate output, photo results, phrases, flashcards, and Reader.

<sub>Merged proposals: Karaoke read-aloud: synced word highlighting + slow mode; Karaoke read-along: word-by-word highlight during TTS + tap-a-syllable playback; Read-Along Mode: Synchronized Word Highlighting with Learner Speech Controls</sub>

### Share Extension and Web Article Import
**Impact 5/5 · Effort Large (1–2 weeks)**

One share extension makes SwiftMandarin the system-wide destination for Chinese text: select text in Safari/WeChat/Books and get an in-place translation sheet with tappable pinyin and save-to-vocabulary; share an image to run the OCR pipeline; share a URL (or paste one in Reader) to fetch the page, strip boilerplate, and file the article into the Reader library with its coverage badge ('92% known') computed automatically.

*Why:* Learners encounter Chinese in other apps constantly and today the only path is copy/paste; meeting text where it lives is the difference between a utility and an ambient learning layer over the whole phone.

*Integration:* New share extension target sharing OCR/pinyin/store code via App Group + shared framework; URL path uses URLSession + lightweight DOM extraction feeding ReaderDocumentStore; translation via TranslationSession or Keychain-shared AI keys.

<sub>Merged proposals: Share Extension: Translate From Any App; Web article import + share extension</sub>

### Document Library: PDF, EPUB, and TXT Import
**Impact 4/5 · Effort Extra-large (multi-week)**

A persistent Library screen importing .txt, .pdf (PDFKit extraction), and .epub (chapter-parsed) via fileImporter or drag-drop, each showing cover, coverage percentage, and reading progress; long books are chaptered with saved positions, and scanned PDFs route page-by-page through the existing Vision OCR pipeline.

*Why:* Graded readers and native novels are the backbone of intermediate immersion; a library makes SwiftMandarin the place a learner reads their first real Chinese book instead of chopping it into clipboard chunks.

*Integration:* ReaderDocumentStore extended with file-backed documents in Application Support; PDFKit + Foundation zip/XML parsing (no new dependencies); scanned path reuses PhotoTextRecognitionService.

### Subtitle & Lyrics Study Mode (.srt/.lrc)
**Impact 4/5 · Effort Medium (days)**

Import subtitle or lyrics files for a line-by-line study view: each cue is a card with tappable ruby Chinese, on-demand translation, TTS, per-line looping for shadowing, a timestamp-driven 'follow along' mode for watching alongside the show, one-tap sentence mining, and whole-file coverage analysis before committing to an episode.

*Why:* TV, film, and music are the most motivating immersion content and every serious learner has subtitle files — no mainstream iOS app serves this workflow.

*Integration:* Simple .srt/.lrc parsers feed the same cue-list UI pattern as PhotoTranslateView's sentence cards; fileImporter entry in the Reader library; reuses RubyTextView, WordTranslationService, sentence mining.

### Graded Discover Feed: RSS Ranked by Your Comprehension
**Impact 4/5 · Effort Large (1–2 weeks)**

A Discover section with curated learner-appropriate Chinese feeds plus user-added RSS URLs; articles fetch in the background and each row shows a live coverage badge ('94% known — good fit'), with the feed sorted by fit so the top is always readable-but-stretching, opening directly in Reader.

*Why:* Solves the intermediate learner's biggest problem — 'what should I read today?' — by combining commodity RSS with the app's unique asset: knowing the user's vocabulary. This is the daily-use retention engine for reading.

*Integration:* XMLParser-based RSS client + the web-article extractor; coverage via the analyzer; article cache in Application Support; Discover section in the Reader library.

### Clipboard-Watch Reading (Pleco-Style)
**Impact 3/5 · Effort Small (hours)**

On macOS, a background pasteboard watcher pops a compact floating reader window whenever Chinese text is copied anywhere; on iOS, a scenePhase-active check with UIPasteboard.detectPatterns shows a 'Read copied text?' banner (avoiding the paste prompt until confirmed) plus a 'Read Clipboard' App Intent — every snippet landing in Reader history.

*Why:* This is Pleco's killer loop — copy in any app, define instantly — inserting SwiftMandarin into existing reading habits with near-zero engineering risk on macOS.

*Integration:* macOS: NSPasteboard.changeCount timer + auxiliary window; iOS: scenePhase hook in ContentView + detectPatterns; new App Intent alongside TranslateClipboardIntent.

### Pre-Read Warmup and Post-Read Review Loop
**Impact 3/5 · Effort Medium (days)**

Opening a text with unknown words offers a 30-second swipeable preview deck of the 5-10 most frequent ones; finishing shows the most-tapped words with one-tap flashcard adds, and SRS words that appeared untapped record a passive-exposure 'Good' review — closing the loop so reading feeds SRS and SRS words get scheduled into future reading.

*Why:* Pre-teaching vocabulary measurably boosts comprehension, and counting in-context encounters as SRS exposure makes reviews reflect real usage — a virtuous cycle flashcard-only competitors lack.

*Integration:* Warmup sheet built from the coverage analyzer's unknown list; post-read summary hooks Reader's tap log; passive exposure calls LearningProgressStore.recordReview with a new quality path.


## 5. Speaking & Listening Lab

> Speaking practice is the number-one unmet need in self-study apps, and tones are Mandarin's hardest skill — yet the app already owns dual-engine speech recognition, TTS, pinyin tone analysis, and an audio tap. Composing them into conversation practice, pronunciation scoring, tone training, shadowing, and eyes-free review converts a dictionary into a tutor.

### AI Conversation Partner: Voice Roleplay
**Impact 5/5 · Effort Extra-large (multi-week)**

Pick a scenario (ordering food, taxi, job interview, free chat) and difficulty, then hold a spoken conversation with an AI persona: it speaks via TTS, the user replies by voice, transcripts render as tappable ruby text, a collapsible coach strip offers gentle corrections and more natural phrasings, due/weak SavedTerms are deliberately woven in, and a post-session report lists new words, corrections, and one-tap saves to vocabulary and SRS.

*Why:* Speaking practice is the single feature that converts a dictionary/flashcard utility into a daily-habit product, and every building block already exists: dual-engine STT, TTS, ruby rendering, word popovers, SRS, and an 11-provider chat client.

*Integration:* New Practice surface in the Learn hub; composes SpeechRecognitionService, SpeechService, RubyTextView, WordDetailPopover, SavedTermsStore, LearningProgressStore, and a new multi-turn chat method on CloudAIService; sessions recorded in LearningActivityStore.

### Pronunciation Coach: Speak-and-Score
**Impact 5/5 · Effort Large (1–2 weeks)**

A 'Say it' button on any word, flashcard, phrase, or sentence records the user, aligns the recognition transcript syllable-by-syllable against the target (green matched / yellow right-sound-wrong-tone / red missed), plays reference and attempt back to back per red syllable, adds AI coaching text ('you said zhu4 instead of zhu3 — third tone dips then rises'), and feeds scores into the Production facet's SRS rating with streak-style 'perfect readings in a row'.

*Why:* Output practice with feedback is the missing half of language apps — learners plateau because nothing ever tells them their third tone is wrong — and the recognition round-trip needs zero new ML given PinyinConverter and the existing on-device STT.

*Integration:* New PronunciationScorer composing SpeechRecognitionService + PinyinConverter + ChineseTextAnalyzer; entry points in WordDetailPopover, LearnView card backs, PhrasesView, and the graded reader; results into CardProgress and LearningActivityStore.

<sub>Merged proposals: Speak-and-Score Pronunciation Practice; Pronunciation Coach with per-syllable tone feedback; Pronunciation Check: per-syllable pass/fail scoring via recognition round-trip</sub>

### Tone Lab: Live Pitch-Contour Visualizer
**Impact 5/5 · Effort Extra-large (multi-week)**

A dedicated practice screen where canonical Mandarin tone contours draw as reference bands and the user's own fundamental-frequency trace draws live over them (on-device YIN/autocorrelation F0 extraction from the existing AVAudioEngine tap, normalized to a one-time voice calibration), with per-syllable fit scores in the app's tone colors and animated replays.

*Why:* Tones are invisible in every mainstream app; nothing on the App Store does live contour overlay well — this is the category-defining feature that makes the tone-color system physically meaningful.

*Integration:* New ToneLabView reachable from word detail sheets and the Learn hub; reuses the speech engine's tap infrastructure for buffers; canonical contours keyed off PinyinConverter.Tone; scores feed the per-tone accuracy store.

### Echo Compare: A/B Your Voice vs Native
**Impact 4/5 · Effort Medium (days)**

A 3-beat loop on any word or sentence: the app speaks it, auto-records the user's repetition, then plays native TTS and the user's take back-to-back at matched loudness with stacked RMS waveforms for visual rhythm comparison, a repeat button, and a heart to save 'my best' take on that term.

*Why:* Self-comparison is the cheapest high-value pronunciation feedback — no scoring model needed — and the recording plumbing, TTS, and waveform surfaces already exist in pieces.

*Integration:* New EchoCompareView from WordDetailPopover, PhraseDetailSheet, and LearnView; reuses SpeechRecognitionService's audio engine for capture and SpeechService for playback; recordings stored like WorkbookImageStore files.

### Shadowing Mode over Any Text
**Impact 5/5 · Effort Large (1–2 weeks)**

From any translation, OCR passage, story paragraph, or history entry, a per-sentence loop: play TTS with word highlighting at chosen speed → auto-record the user's repetition → optional instant recognition check with character-level diff coloring and a percentage → advance; controls include repeat, slow down, 'loop until 90%', and a blind mode hiding hanzi to force listening, with session summaries logging minutes practiced to the heatmap.

*Why:* Shadowing is the technique serious learners pay tutors for, and the app owns both halves (TTS and STT) plus the perfect content source — the learner's own translations and photographed texts.

*Integration:* New ShadowingSessionView from TranslateView, PhotoTranslateView, Reader, and HistoryTabView; composes SpeechService, SpeechRecognitionService, NLTokenizer sentence splitting, and the PronunciationScorer; new record type in LearningActivityStore.

<sub>Merged proposals: Shadowing Studio: listen, repeat, and see your diff; Shadowing Mode: sentence-by-sentence listen–repeat over any text</sub>

### Adaptive Tone-Pair and Minimal-Pair Drills
**Impact 4/5 · Effort Medium (days)**

Rapid-fire ear training: the app speaks a syllable or two-syllable word from the user's vocabulary and the user picks what they heard among tone-only or confusable-initial variants (mā/má/mǎ/mà; zh/ch/sh vs z/c/s, n/l); wrong answers replay both contrasts back to back, and a persisted confusion matrix adaptively oversamples the weakest contrasts (2-3 vs 3-2 are systematically hardest). Two-minute, 20-question sessions record to the heatmap.

*Why:* Tone perception must precede tone production and is trainable with minimal pairs (proven in L2 phonology research); TTS synthesizes every syllable on demand so the feature needs zero recorded assets and zero network.

*Integration:* New drill mode under the Learn hub; words from SavedTermsStore + HSK lexicon; tones via PinyinConverter.detectTone; audio via SpeechService; confusion matrix persisted via PersistentCodableStore.

<sub>Merged proposals: Tone-Pair Trainer (Listening Discrimination Drills); Minimal-Pair Tone Drills with an adaptive confusion matrix</sub>

### Listen Mode: Hands-Free, Eyes-Free Audio Review
**Impact 5/5 · Effort Large (1–2 weeks)**

A podcast-style player over due cards and phrases — Chinese → configurable recall pause → English → next — with MPRemoteCommandCenter and Now Playing so it runs screen-locked, in the car, or over AirPods; an optional voice-graded variant transcribes the user's spoken answer and records real SRS grades with earcons and haptics, fully driveable with VoiceOver or screen off, plus a Shortcut for alarm/CarPlay automation.

*Why:* This unlocks the dead time (commute, chores) where language apps win or lose daily engagement, and doubles as a flagship accessibility story: blind and dyslexic users get a complete review loop with zero visual dependency.

*Integration:* New ListenModeView + AudioSessionController (background-audio entitlement); queue from LearningProgressStore.getCardsForReview and phrase data; voice grading composes SpeechRecognitionService and text analyzers; completion writes recordReview.

<sub>Merged proposals: Listen Mode: hands-free audio review with lock-screen controls; Eyes-Free Audio Review Sessions</sub>

### AI Listening Quizzes
**Impact 4/5 · Effort Large (1–2 weeks)**

The AI generates a 3-6 sentence micro-story constrained to the user's vocabulary at inferred difficulty, reads it aloud with text hidden, asks 2-4 multiple-choice comprehension questions from the same JSON payload, then reveals the transcript as tappable ruby text with one-tap saves — wrong answers replay the relevant sentence, and quizzes bank for later review.

*Why:* Comprehensible listening input tailored to exactly the learner's known vocabulary is what graded audio courses charge for; the app can generate it with its existing multi-provider stack and grade it with existing question-bank machinery.

*Integration:* New method on AIWordExplanationService (same tolerant-JSON pattern as generateReviewQuestions); playback via SpeechService; transcript via RubyTextView; results into WorkbookQuestionBankStore and LearningActivityStore.

### Speech Studio: Rates, Voices, and Slow Replay Everywhere
**Impact 4/5 · Effort Small (hours)**

A Speech settings section with a 0.3x-1.2x rate slider, one-tap Slow mode, and a voice picker showing Enhanced/Premium zh/en voices with previews; every speaker icon in the app gains long-press half-speed replay with a tortoise micro-animation, zh-TW text routes to zh-TW voices, and each utterance configures its own AVAudioSession so volume is deterministic after recording.

*Why:* Learners overwhelmingly need slow, high-quality audio; the current TTS uses the default voice at default rate with zero configuration — one small change upgrades every listening touchpoint at once and unblocks every other audio feature.

*Integration:* Extend SpeechService with rate/voice params and an AVAudioSession strategy; new Speech section in settings on both platforms; long-press gesture added at existing speaker call sites.

### Interactive Pinyin Sound Map
**Impact 3/5 · Effort Medium (days)**

A zoomable initials × finals grid of all ~410 valid Mandarin syllables, each tappable in any tone via TTS, with mouth-position tips for hard initials (ü, zh/ch/sh, q/x), example words drawn from the user's vocabulary, and cells tinted by the user's pronunciation-check accuracy once that data exists — a personal coverage and weakness map.

*Why:* Beginners lack a systematic mental map of Mandarin's syllable inventory; every serious course starts here, no translation app offers it, and TTS makes the entire audio set free.

*Integration:* New view under the Learn hub; static syllable table + SpeechService playback; cross-links to SavedTermsStore and PronunciationScorer accuracy.


## 6. AI Tutor Everywhere

> The app treats AI as a lookup tool; these ideas make it a teacher. A personalized daily lesson, writing correction with a longitudinal error profile, Socratic homework tutoring, sentence anatomy on every translation, and a camera that answers questions about the world convert every existing surface from an answer machine into a lesson.

### Daily Smart Lesson (On-Device First)
**Impact 5/5 · Effort Large (1–2 weeks)**

Each morning one generation call assembles a 5-minute lesson from the user's weak data (lapsed cards, wrong workbook answers): a mini-dialogue using those words, cloze sentences, multiple-choice questions, and one AI-graded production prompt — generated free, offline, and privately via the Foundation Models @Generable path on Apple Intelligence devices with cloud-provider fallback, cached for offline replay, and writing completions back into the SRS and heatmap.

*Why:* Turns three disconnected data silos (SRS lapses, workbook mistakes, saved vocab) into one personalized daily ritual — the retention mechanic every successful learning app is built on, and doing it on-device is something subscription competitors structurally cannot match.

*Integration:* New LessonGeneratorService using the existing FoundationModels path in AIWordExplanationService with cloud JSON-mode fallback; reads LearningProgressStore + WorkbookGradingHistoryStore + SavedTermsStore; card at the top of the Learn hub; completion writes recordReview.

<sub>Merged proposals: Daily Smart Lesson generated from your weak words; On-Device Daily Micro-Lesson (Foundation Models)</sub>

### Sentence Workshop: AI Writing Correction
**Impact 4/5 · Effort Medium (days)**

A composer (optionally seeded with prompts like 'use 虽然...但是') where the AI returns a structured critique: corrected sentence, tap-to-explain inline error annotations (word order, missing measure word, aspect particle misuse), naturalness score, and alternative phrasings — with errors tagged to a taxonomy that accumulates into a 'Your common mistakes' panel ('you drop 了 in completed actions — 6 times').

*Why:* Output practice with feedback is entirely absent from the app and rare in the market; the error-taxonomy accumulation turns one-off corrections into a longitudinal weakness profile the Daily Lesson can draw from.

*Integration:* New Learn hub entry; single JSON-mode chat via the provider router; annotations render with AttributedString over ruby components; error stats persisted via PersistentCodableStore.

### Homework Tutor: Socratic Chat on Graded Questions
**Impact 4/5 · Effort Medium (days)**

Every wrong answer in workbook grading gains an 'Ask the tutor' chat scoped to that question — the AI already has the question, the child's answer, the correct answer, and the original scan; it guides with questions rather than restating answers, offers hints on request, ends with a similar practice question, and gives parents an 'Explain to me' adult summary, with transcripts attached to the GradedSession.

*Why:* Grading says what is wrong; tutoring makes the app why-focused — transforming the workbook feature from a checker parents use into a teacher kids use, with the vision context already routed and stored.

*Integration:* Button on question cards in WorkbookGradingView and GradedSessionDetailView; multi-turn chat through CloudAIService with the stored WorkbookImageStore scan; transcript appended in WorkbookGradingHistoryStore.

### 'Why?' Button: AI Sentence Anatomy
**Impact 4/5 · Effort Medium (days)**

After any translation, a 'Why?' button redraws the sentence as tappable grammatical chunks mapped to their English counterparts with connecting-line UI, plus 1-2 named grammar patterns ('把-construction') each with a one-line rule and second example; detected patterns accumulate in a personal 'Grammar encountered' list, replacing the false-positive-prone substring heuristics.

*Why:* Converts every translation from an answer into a lesson — the core differentiator versus Google Translate — while retiring the heuristic grammar detection that flags 'red' as past tense.

*Integration:* Button in TranslateView output and HistoryTabView context menu; one JSON-mode call through the provider router; chunk rendering reuses FlowLayout/RubyTextView; pattern list via PersistentCodableStore.

### Live Camera Tutor: Visual Q&A on the World
**Impact 4/5 · Effort Large (1–2 weeks)**

Extends the photo pipeline from 'translate this text' to 'teach me about this scene': snap anything and ask by voice or text ('how do I ask for this without peanuts?'), with vision-model answers rendered as tappable, saveable ruby Chinese, image-grounded follow-ups, and a 'Name 5 things in this photo in Chinese' quick action turning any scene into vocabulary.

*Why:* The app already routes images to vision models but only in fixed pipelines; open-ended visual Q&A makes the camera a tutor for the real-world moments learners actually need language help.

*Integration:* New mode in the Scan tab; reuses CameraImagePicker/PhotosPicker, workbook image downscaling, CloudAIService vision chat, RubyTextView + WordDetailPopover, SavedTermsStore.

### Semantic Vocabulary Search and AI Collections
**Impact 3/5 · Effort Medium (days)**

The vocabulary search box understands meaning ('food words', '关于旅行') via on-device NLEmbedding similarity with AI re-rank fallback, and an AI clustering pass organizes the whole vocabulary into named thematic collections ('Restaurant', 'School') shown as filter chips that double as study decks — cram 'Restaurant' before dinner.

*Why:* A vocabulary of hundreds of words is currently a flat sort-by-date list; semantic organization makes it navigable and, via topic decks, actionable exactly when needed.

*Integration:* NLEmbedding computed lazily per SavedTerm and cached; clustering via one JSON-mode call; collection chips in VocabularyView; deck filter added to LearnView CardSource.


## 7. Platform Presence & Ambient Capture

> A habit app that is invisible between launches loses the habit. The streak, due counts, and camera routes all exist but have zero presence outside the icon. Widgets, actionable notifications, Live Activities, Spotlight, a camera lens overlay, and a real Mac menu-bar translator put the app on every surface Apple offers — the cheapest daily re-engagement available.

### Home & Lock Screen Widget Suite with Control Center Actions
**Impact 5/5 · Effort Large (1–2 weeks)**

The app's first extension target: small streak-flame widget with today's due count and goal ring, medium Word of the Day (from the user's weakest cards, with interactive hear/flip buttons), Lock Screen inline/circular due-count widgets, plus iOS 18 ControlWidgets and Action-button bindings for 'Scan with Camera', 'Start Review', and 'Translate Clipboard' — all deep-linking through a URL scheme onto the existing AppRouteStore pending-action system, refreshing at midnight and after each session.

*Why:* Widgets are the single highest-leverage retention surface on iOS and the data plus App Intents already exist — only the surfaces (and the App Group) are missing; camera-to-translation becomes one physical button press.

*Integration:* New widget extension target; requires the App Group and shared-suite store migration; onOpenURL in ContentView maps URLs to AppRouteStore.trigger; controls wrap OpenCameraScannerIntent, StartReviewIntent, TranslateClipboardIntent unchanged.

<sub>Merged proposals: Streak & Word-of-the-Day Widget Suite; Streak and Word-of-the-Day widgets plus a scanner Control; Home Screen widgets: streak, due count, word of the day; App Group data layer plus streak and due-review widgets; Control Center & Action Button Controls</sub>

### Due-Aware Review Notifications with Lock-Screen Grading
**Impact 5/5 · Effort Medium (days)**

Wires the currently dead reviewReminders/reminderTime settings: at the chosen hour, at most one notification fires and only when cards are actually due ('14 cards due — about 4 minutes'), deep-linking into review; long-press reveals an actual due card with 'Show Answer' then 'Got it'/'Again' actions that record real SRS reviews without opening the app, plus an optional 9pm 'streak at risk' nudge only when today's score is zero and the streak is 3+ days.

*Why:* The app has an SRS but no way to tell users when the algorithm wants them back — the core loop is broken outside the app — and content-conditional nudges with lock-screen micro-reviews are the tasteful, genuinely rare version.

*Integration:* New ReminderService scheduling from LearningProgressStore.getDueCards; taps route through AppRouteStore.triggerReview; notification action handler writes CardProgress via the App Group store; replaces the inert settings on both platforms.

<sub>Merged proposals: Due-review notifications that only fire when reviews are actually due; Actionable Due-Review Notifications (Rate From Lock Screen)</sub>

### Review Live Activity + Streak Defense
**Impact 4/5 · Effort Medium (days)**

Two ActivityKit uses: an in-session Live Activity showing cards-left and accuracy in the Dynamic Island so swiped-away sessions pulse for tap-to-resume; and 'Streak Defense' — if the day's activity is still zero after a user-set evening hour, a Lock Screen countdown appears ('14-day streak ends in 3h 12m — 5 cards keep it alive') with a Start Review button.

*Why:* Streaks are the app's core motivator but only visible inside the Stats tab; the countdown makes losing the streak viscerally concrete at the exact moment intervention works.

*Integration:* ActivityKit in the widget extension; LearnView start/rate/end drive updates; Streak Defense scheduled via BGAppRefreshTask reading LearningActivityStore; the button reuses StartReviewIntent.

### Lens Mode: Live Camera Translation Overlay
**Impact 5/5 · Effort Large (1–2 weeks)**

Point the camera at a menu or sign and translations render in place as rounded chips anchored to each text block's bounding box over the frozen frame — Google Lens style, fully on-device OCR plus Apple Translation, using the RecognizedTextBlock.boundingBox geometry the app already captures but discards; tapping a chip shows pinyin ruby and saves words, and iOS 26's RecognizeDocumentsRequest fixes reading-order scrambling on stitched screenshots.

*Why:* This is the flagship 'show your friends' feature: all the hard parts (OCR, bounding boxes, block translation, ruby rendering) exist and have simply never been composed spatially.

*Integration:* Extends CameraScannerSheet with a capture-and-overlay mode; reuses PhotoTextRecognitionService and ScreenshotTranslationStore's per-block translation — the data model already stores both text and geometry.

### Spotlight-Indexed Vocabulary
**Impact 4/5 · Effort Medium (days)**

Every saved term is indexed with Core Spotlight (plus IndexedEntity on iOS 18): swipe down on the Home Screen, type '苹果', 'píngguǒ', or 'apple', and the saved card appears with pinyin and definition, opening straight to the term detail; phrasebook entries and grammar points index too, with deletion cleanup and a one-time backfill.

*Why:* A personal dictionary you can't search from the system is half a dictionary — this makes the user's vocabulary feel installed into iOS itself, and IndexedEntity feeds Apple Intelligence surfaces going forward.

*Integration:* Hook SavedTermsStore.add/remove/update to CSSearchableIndex; conform SavedTermEntity to IndexedEntity; tap-through via onContinueUserActivity routed through AppRouteStore.

### Handoff + Universal Deep Links
**Impact 3/5 · Effort Small (hours)**

NSUserActivity broadcasting from key screens (mid-translation, term detail, in-progress review) so work continues seamlessly between iPhone and Mac, alongside a swiftmandarin:// URL scheme with onOpenURL mapped onto AppRouteStore's pending-action system — the uniform deep-link vocabulary that widgets, notifications, Spotlight, and Shortcuts all need.

*Why:* Cheap, pure-native polish multi-device owners feel immediately, and the URL routing is required infrastructure for five other ideas on this list — one small PR unlocks a platform.

*Integration:* userActivity modifiers on TranslateView/LearnView/term detail; onContinueUserActivity + onOpenURL in ContentView translating payloads into AppRouteStore.trigger.

### macOS Menu Bar Translator, Global Hotkey & Command Palette
**Impact 4/5 · Effort Large (1–2 weeks)**

Make the four dead macOS settings real: a MenuBarExtra translate palette (type or auto-grab selection, instant translation with pinyin, Cmd-S to save), a recordable global hotkey summoning it from any app, an NSServices right-click 'Translate with SwiftMandarin' entry, launch-at-login via SMAppService and dock-icon policy — plus a Cmd-K command palette in the main window for fuzzy-matched navigation, vocabulary/history search, and actions like 'Start review'.

*Why:* Four settings toggles currently lie to users — the worst trust signal in the app — and a hotkey-summoned translator is the killer Mac workflow that matches how desktop dictionary users (Eudic, Bob) actually work.

*Integration:* MenuBarExtra scene in SwiftMandarinApp gated on the existing showInMenuBar key; palette reuses TranslationState, WordTranslationService, RubyTextView, SavedTermsStore; command palette overlays MacOSContentView driving AppRouteStore.

<sub>Merged proposals: macOS: menu-bar quick translate and a real command palette; macOS Menu Bar Translator + Global Hotkey + Services</sub>

### watchOS Companion: Wrist Flashcards + Complications
**Impact 4/5 · Effort Extra-large (multi-week)**

A minimal Apple Watch app: a stack of due cards (tap to flip, crown or big buttons to rate), on-watch TTS, 5-card glanceable sessions, streak/due-count complications, and a Smart Stack widget surfacing at the habitual review time, syncing reviews back via WatchConnectivity or CloudKit.

*Why:* Spaced repetition thrives on many tiny sessions and the wrist is the lowest-friction surface that exists; no Mandarin app has a credible watch experience — a durable moat and App Store feature bait.

*Integration:* New watchOS target sharing LearningCard/CardProgress/ReviewQuality via a shared package; WCSession transfers due-card snapshots and results; complications read App Group streak data.

### Study Focus Filter
**Impact 2/5 · Effort Small (hours)**

A SetFocusFilterIntent so SwiftMandarin appears in system Focus settings: a 'Study' Focus can switch Learn to due-review mode, force full Chinese immersion (English glosses hidden until tapped), and prioritize review notifications, while a 'Work' Focus silences streak-defense nudges — configured natively in the Focus settings screen.

*Why:* Small effort, high 'this app gets the platform' signal — and immersion-on-Focus is a genuinely novel behavior where the phone itself shifts you into Chinese mode on your study schedule.

*Integration:* One SetFocusFilterIntent writing to AppPreferences flags; ReminderService and the Live Activity scheduler read the active filter state before firing.


## 8. Data Ownership, Sync & Backup

> Every store is device-local UserDefaults today: a Mac+iPhone learner has two divergent vocabularies, and losing a phone means losing years of SRS history. Sync, real backups, and lossless interop with Anki and Pleco are what make the app trustworthy enough to be someone's primary multi-year learning system.

### CloudKit Sync Across Devices
**Impact 5/5 · Effort Extra-large (multi-week)**

Silent iCloud sync via CKSyncEngine for vocabulary, CardProgress, translation history, workbook data, and streak/activity — a word saved on iPhone appears on the Mac in seconds, with field-wise conflict rules (newest-edit wins for term fields, max-merge for counters, earlier nextReviewDate on conflict), full offline queueing, a subtle sync-status row, and no account UI beyond the user's iCloud.

*Why:* Reviewing on Mac then seeing stale due counts on iPhone breaks the SRS contract; sync is the number-one category gap versus Anki/Pleco and the prerequisite for the app being someone's primary learning system.

*Integration:* Fronted by the repository protocols from the persistence foundation; records keyed by existing UUIDs/dateKeys; stores already funnel mutations through singleton methods, giving clean sync hook points; requires CloudKit entitlement.

<sub>Merged proposals: CloudKit Sync for Vocabulary, SRS, and History; iCloud Sync for Vocabulary, SRS Progress, and Activity (CloudKit); CloudKit sync for vocabulary and SRS progress</sub>

### Instant Streak Continuity via iCloud Key-Value Store
**Impact 3/5 · Effort Small (hours)**

Before full CloudKit lands, NSUbiquitousKeyValueStore mirrors small high-value state — streak, 14 days of activity counters, learner mode, language, display prefs (never API keys) — so the Mac shows the iPhone's streak within minutes, with per-day-max counter merges; KVS surviving reinstalls also fixes 'reinstall shows Best streak 0'.

*Why:* Full sync is an XL project; the streak is the emotionally load-bearing datum and fits in 1MB of KVS with near-zero infrastructure.

*Integration:* KVS adapter observed by LearningActivityStore (merge on didChangeExternallyNotification) and AppPreferences/LocalizationManager; requires only the iCloud KVS entitlement.

### Complete Backup System: One-Tap Archive + Rotating Snapshots
**Impact 5/5 · Effort Medium (days)**

A 'Back Up Everything' button produces a single .smbackup zip (manifest + all six stores, AI cache, workbook JPEGs, preferences) restorable with preview and Replace/Merge options; alongside it, silent daily rotating snapshots (7 daily + 4 weekly, size-capped) with a browser in Manage Data, and automatic snapshot-before-destroy hooks turning Clear All and Reset Progress from irreversible into undoable.

*Why:* Today only vocabulary exports — SRS history, streaks, and scans are unrecoverable on device loss — and the one-tap unconfirmed destructive buttons make silent snapshots the highest-value-per-line safety feature in the app.

*Integration:* New BackupService enumerating PersistentCodableStore keys plus Application Support files, triggered from scenePhase and destructive-action hooks; surfaced in DataManagementView and macOS DataSettingsTab.

<sub>Merged proposals: One-Tap Full Backup Archive (.smbackup) with Restore; Automatic Rotating Local Backups with Snapshot Browser</sub>

### Anki .apkg Export with SRS State Mapping
**Impact 4/5 · Effort Large (1–2 weeks)**

Export vocabulary (and optionally the question bank) as a genuine Anki package: zipped SQLite collection with a bilingual note type, tone-colored pinyin via CSS, and each card's SRS state translated into Anki scheduling fields (ease maps directly given the shared SM-2 lineage; nextReviewDate → due, reviewCount → reps) so cards arrive in AnkiMobile already scheduled, not as new.

*Why:* Anki is the lingua franca of language learners; lossless export with preserved scheduling removes the biggest lock-in objection and makes SwiftMandarin the capture front-end for serious users.

*Integration:* New AnkiExportService (SQLite3 C API + libcompression) fed by SavedTermsStore, LearningProgressStore, and WordExplanationCacheStore; third format card in VocabularyView's ExportSheet.

### Universal Deck Import: Anki, Pleco XML, and TSV
**Impact 4/5 · Effort Large (1–2 weeks)**

The import picker accepts .apkg (with a drag-to-assign field-mapping sheet for arbitrary note types), Pleco flashcard XML, and tab-separated lists, showing a 20-term parse preview and duplicate count before committing; imported Anki scheduling data seeds CardProgress so previously-studied words aren't treated as brand new.

*Why:* Switchers arrive with years of data in Anki and Pleco and today can only re-type; import converts the largest pool of committed Mandarin learners into users in one session.

*Integration:* Extends VocabularyImportExportService.detectFormat with apkg/XML/TSV parsers; reuses normalizedKey dedupe and the merge-AI-analyses path; new FieldMappingSheet before commit.

### Merge-Aware Import with Conflict Preview
**Impact 3/5 · Effort Medium (days)**

All imports route through a merge screen — New / Updated (old-vs-new diff with per-row keep-mine/take-theirs) / Identical — with bulk accepts, field-wise SRS conflict merging (max counters, latest due date, conservative ease), an automatic pre-merge snapshot, and nothing mutating until confirmed.

*Why:* Two-device users syncing by file exchange currently get silent duplicate-or-skip behavior; deterministic previewable merge is also exactly the conflict logic CloudKit will need — built and user-tested early.

*Integration:* New MergePlan model computed by VocabularyImportExportService/BackupService; MergePreviewSheet on all import entry points; batch-apply methods on SavedTermsStore and LearningProgressStore.

### Lossless CSV/JSON Round-Trip
**Impact 3/5 · Effort Small (hours)**

CSV export gains id, sortOrder, mastery, dateAdded, and SRS columns; import matches rows by UUID so re-importing updates in place instead of duplicating and SRS history survives the trip; headers are detected by content rather than blindly skipping row 0, and per-row parse failures surface in a visible skipped-rows report.

*Why:* The current CSV path actively destroys data — fresh UUIDs sever all SRS history, headerless files lose row one, bad rows vanish silently; round-trip fidelity is cheap prerequisite trust for every other export feature.

*Integration:* Modify the VocabularyImportExportService CSV writer/parser and join LearningProgressStore records by 'vocab:<UUID>' on both sides.

### Pleco Flashcard XML Export
**Impact 3/5 · Effort Small (hours)**

Export vocabulary as Pleco-compatible flashcard XML with categories mirroring part-of-speech or mastery status, adding a diacritic→tone-number pinyin mode to PinyinConverter (nǐ → ni3) since Pleco expects numbered pinyin; the file imports directly via Pleco's Import Cards screen.

*Why:* Pleco is the dictionary nearly every serious learner owns; one-tap export positions SwiftMandarin as a companion rather than a competitor to the incumbent.

*Integration:* XML writer in VocabularyImportExportService; tone-number converter added to PinyinConverter (detection tables already exist); new format option in the ExportSheet.

### Unified Export Center
**Impact 3/5 · Effort Medium (days)**

One 'Export Data' screen listing every dataset — Vocabulary, Translation History, Question Bank, Grading History, Activity Log, AI Cache — each with format picker, record count, and estimated size, plus 'Export All' producing the full archive; kills the current situation where only vocabulary exports, and only saves to file on macOS.

*Why:* Users own their data but five of six stores are currently unexportable; consolidation also fixes the iOS/macOS export asymmetry called out in the app map.

*Integration:* New ExportCenterView under Manage Data on both platforms; per-store Codable→CSV serializers alongside VocabularyImportExportService; ShareLink + fileExporter.

### Data Health Dashboard
**Impact 3/5 · Effort Medium (days)**

A screen showing per-store storage, counts, and detected issues with one-tap fixes: orphaned CardProgress records inflating due counts, near-duplicate vocabulary with side-by-side merge, unreferenced workbook images, and stale AI-cache entries — each fix taking an automatic snapshot first.

*Why:* Known integrity leaks already exist (orphaned progress, OCR-variant duplicates); making hygiene visible and fixable keeps multi-year datasets and the stats that motivate users trustworthy.

*Integration:* DataHealthService cross-references SavedTermsStore UUIDs vs LearningProgressStore keys, session image IDs vs the WorkbookImages directory, and the AI cache index; new screen under Manage Data.

### Printable PDF Study Sheets
**Impact 4/5 · Effort Medium (days)**

Generate paginated worksheet PDFs from vocabulary and the question bank: large hanzi with tone-colored pinyin, optional 田字格 tracing grids of faded characters, quiz sheets with separate answer keys, and fold-in-half self-test layouts — with options for hiding pinyin/meanings and sizing, shared to print in three taps.

*Why:* Workbook grading proves this app serves paper-based learners (kids, tutoring); closing the loop back to paper is a differentiator no competing translator app has.

*Integration:* ImageRenderer over SwiftUI page views reusing PinyinConverter.coloredPinyin; entry points in VocabularyView's overflow menu and the question bank toolbar.

### Graded Session PDF Reports for Parents & Teachers
**Impact 4/5 · Effort Medium (days)**

A Share button on graded sessions produces a one-page PDF report — date, score badge, per-question table with explanations, scan thumbnails, and a words-to-review list — plus a date-range variant exporting multi-session progress with a score-over-time mini chart.

*Why:* Workbook grading is inherently a parent/tutor workflow but results are trapped in the app; a shareable report makes SwiftMandarin the communication artifact between child, parent, and teacher.

*Integration:* Reads GradedSession + WorkbookImageStore JPEGs; ImageRenderer-based PDF composer shared with study sheets; ShareLink on GradedSessionDetailView and grading history.


## 9. Accessibility & Inclusive Mandarin

> Red/green tone colors fail ~8% of male users in a tone-learning app; the signature ruby reading surface is unusable with VoiceOver; Taiwan, Hong Kong, and heritage learners are excluded entirely. Fixing tone encoding, screen-reader support, Traditional Chinese, and motion/type compliance is both an equity obligation and an underserved-market opportunity no competitor addresses well.

### Color-Blind-Safe, Per-Syllable Tone System
**Impact 5/5 · Effort Medium (days)**

Replace single-color-per-word tinting with per-syllable coloring from one shared palette, plus a Tone Marking setting with three modes: Classic, Color-blind-safe (Okabe-Ito palette distinguishable under deuteranopia/protanopia), and Shapes (tone-contour glyphs ˉ ˊ ˇ ˋ · or underlines) so tone is never encoded by hue alone — with a tappable legend and the two divergent palettes collapsed into one source of truth.

*Why:* Red/green tone colors are indistinguishable for ~8% of male users — in a tone-learning app that is a core-feature failure — and per-syllable coloring also fixes the existing bug where 中国 renders entirely first-tone red.

*Integration:* PinyinConverter.Tone gains palette variants and glyph output; RubyWordView renders coloredPinyin instead of its local pinyinColor; new @AppStorage key in Display & Pinyin settings on both platforms.

### VoiceOver-Native Ruby Text with Bilingual Speech
**Impact 4/5 · Effort Medium (days)**

Each word chip becomes one combined accessibility element speaking the hanzi with a zh-CN speech-language attribute then the gloss in the UI language, with a custom 'Words' rotor for word-by-word flicking, custom actions (Speak, Save, Details), and sentence-container summaries — applied to ruby views, history rows, and vocabulary rows alike.

*Why:* The interactive reading surface — the app's centerpiece — is currently unusable with VoiceOver: plain buttons reading pinyin gibberish in an English voice; correct language switching is the single biggest blocker for blind Mandarin learners.

*Integration:* accessibilityElement(children: .combine), AttributedString speech attributes, and accessibilityCustomActions on RubyWordView/PunctuationView; rotor on RubyTextView; helpers reused in VocabularyRow and HistoryTabView.

### Traditional Chinese (zh-Hant) as a First-Class Script
**Impact 5/5 · Effort Large (1–2 weeks)**

A zh-Hant UI language plus a Simplified/Traditional/Both character-set preference converting every displayed headword via a bundled OpenCC-style table ('Both' shows 学/學 stacked), script-aware segmentation instead of hardcoded .simplifiedChinese, and zh-TW voice/locale routing for TTS and recognition — with terms stored canonically so switching is instant and lossless.

*Why:* OCR and speech recognition already support Traditional but the learning surface doesn't — excluding Taiwan, Hong Kong, and heritage learners, one of the largest underserved Mandarin demographics no mainstream competitor serves bidirectionally.

*Integration:* New AppLanguage case in LocalizationManager; ScriptConversionService consulted by RubySegment, SavedTerm, LearningCard, PhrasesView; ChineseTextAnalyzer takes detected script; SpeechService gains zh-TW routing.

### Zhuyin (Bopomofo) Annotation Mode
**Impact 3/5 · Effort Medium (days)**

An annotation-system picker — Pinyin, Zhuyin, or Both — rendering ㄅㄆㄇ beside or above characters with the same tone-marking modes, generated fully offline via a ~410-entry syllable lookup over the existing pinyin output, honored in popovers, flashcards, and export columns, alongside a tone-number output mode for copy/export.

*Why:* Zhuyin is the phonetic system taught in Taiwan and preferred by many heritage learners; paired with zh-Hant this makes SwiftMandarin the only app serving both romanization cultures.

*Integration:* PinyinConverter gains toZhuyin and tone-number output; RubySegment exposes annotation per active system; new @AppStorage key read by RubyTextView and settings.

### Dynamic Type and AX-Size Compliance Pass
**Impact 4/5 · Effort Medium (days)**

Audit every custom surface at AX5: ruby chips scale via @ScaledMetric, the six-button rating row reflows via ViewThatFits, flashcards grow and scroll instead of truncating, stat grids reflow to one column, minimumScaleFactor hacks become wrapping, the vocabulary font slider becomes a Dynamic Type offset, and toolbar icons adopt the large-content viewer.

*Why:* Language learners skew toward older adults and children — the groups most likely to use large text — and fixed-point fonts currently degrade exactly where CJK glyph legibility matters most.

*Integration:* Touches RubyTextView/RubyWordView, LearnView ratingButtons, StatsView grids, fitSingleLine, and VocabularyView's slider — mostly @ScaledMetric, ViewThatFits, and dynamicTypeSize breakpoints with no data-model changes.

### Accessible Heatmap with Audio Graphs and List View
**Impact 3/5 · Effort Medium (days)**

Every ContributionCell gains a spoken label and value with drag-to-scrub announcements, AXChartDescriptor enables Apple's audio-graph sonification on the heatmap and donut charts, a 'View as list' toggle renders the same data as a grouped weekly list, and columns align to true calendar weeks so the M/W/F labels stop lying.

*Why:* The Stats tab is currently 100% invisible to VoiceOver — excluding blind users from their own progress data, the app's main motivation loop — and audio graphs are a delightful low-cost differentiator.

*Integration:* Labels, drag gesture, and AXChartDescriptorRepresentable on ContributionHeatmap in StatsView; list alternative reuses existing activitiesForLastDays data.

### Reduce Motion and Reduce Transparency Compliance
**Impact 3/5 · Effort Small (hours)**

Honor accessibilityReduceMotion everywhere motion is decorative — the 3D flashcard flip becomes a crossfade, pulsing mic rings become a static state glyph, matchedGeometry and chart pops become instant — and swap material backgrounds for solid fills under Reduce Transparency, preserving all state legibility through non-motion cues.

*Why:* Vestibular-disorder users physically cannot use the flashcard flip — the app's core review interaction — today; this is the cheapest full-compliance win available.

*Integration:* Environment reads in LearnView's flip, LiveSpeechTranslationView's mic button, StatsView animations, and shared materials, with a small MotionPreference helper keeping branching consistent.

### Tone Haptics: Feel the Four Tones
**Impact 3/5 · Effort Medium (days)**

Distinct CoreHaptics patterns encode each tone kinesthetically — sustained buzz, rising ramp, dip-then-rise, sharp falling transient, soft neutral tick — playing alongside TTS on word taps and optionally before flashcard reveals as a recall cue, with a 'feel each tone' demo; the work also fixes the shipped hapticFeedback default-mismatch bug by centralizing haptics in one service.

*Why:* Tones become perceivable through a third channel — essential for color-blind and blind learners and a genuinely novel memory hook; no Mandarin app ships tone haptics.

*Integration:* New HapticsService (CHHapticEngine with UIImpactFeedbackGenerator fallback) called from RubyWordView, WordDetailPopover, and LearnView; tone data from PinyinConverter.detectTone.

### Full Keyboard-Driven Review and Focusable Reading
**Impact 3/5 · Effort Small (hours)**

Complete keyboard control for LearnView (Space flips, 1-6 grade, all in the iPad shortcut HUD and macOS menus), focusable ruby chips so Tab/arrows traverse words and Return opens details — making reading usable via Full Keyboard Access and Switch Control — plus Return/Cmd-C equivalents on list rows and a shortcuts help sheet.

*Why:* The app has partial macOS keyboard support proving intent, but review — its highest-frequency loop — still requires pointing; Full Keyboard Access users cannot complete a session today.

*Integration:* keyboardShortcut modifiers on LearnView's existing rating buttons and flip; FocusState ring styling on RubyWordView; extends the pattern established in VocabularyView.

### One-Handed Reachability Layout
**Impact 2/5 · Effort Small (hours)**

An Off/Left/Right handedness setting restructures iPhone layouts for thumb reach: Translate's action cluster becomes a floating bottom-corner stack, the rating row anchors to the bottom edge with 'Good' nearest the thumb, swipe-up replaces top-of-screen reaches, and sheets default to medium detent.

*Why:* Learners use this app one-handed constantly — on trains, holding a workbook, photographing pages — and current layouts scatter frequent controls across the full screen height.

*Integration:* New @AppStorage handedness key; a ReachabilityContainer modifier repositions existing button clusters in TranslateView, LearnView, and PhotoTranslateView with no logic changes.

### String Catalog Hardening + Localized, Parameterized Siri
**Impact 3/5 · Effort Medium (days)**

Migrate to a String Catalog with stable keys and proper format/plural strings, wrap the hardcoded Chinese chrome so it follows the language toggle, add the zh-Hant table, and localize all App Shortcut phrases into zh-Hans/zh-Hant with parameterized variants ('用SwiftMandarin翻译剪贴板') plus SwiftUI snippet views and @Property-annotated entities for Shortcuts power users — gated by a pseudo-localization build scheme catching truncation before release.

*Why:* Half the target audience is Chinese-native yet Siri is English-only and several screens show untranslatable hardcoded text; fragile English-sentence keys silently orphan translations with every copy edit.

*Integration:* Converts Localizable tables consumed by LanguageOverrideBundle/L(); localized phrases in SwiftMandarinShortcutsProvider; @Property on SavedTermEntity/PhraseEntity; SnippetView on GetLearningStatsIntent; new pseudo-loc scheme.

<sub>Merged proposals: String Catalog Hardening: Stable Keys, zh-Hant Strings, Pseudo-Localization Gate, Localized Siri; Siri That Speaks Chinese: Localized, Parameterized App Shortcuts</sub>


## 10. Engineering Foundation & Performance

> Whole-array UserDefaults writes, main-thread NLP, five copy-pasted provider switches, four divergent caches, 1,500-line god-views, and zero tests throttle every flagship idea above. These enabling investments — done once — unlock widgets, sync, streaming AI, smooth 120Hz reading, and safe iteration for a small team.

### Sync-Ready Persistence Foundation (App Group + Indexed Store)
**Impact 5/5 · Effort Extra-large (multi-week)**

Move the six whole-array UserDefaults blobs to a versioned, App Group-hosted store (SwiftData models or per-store files behind repository protocols) with schemaVersion migration chains, debounced atomic writes, snapshot fallbacks, and indexed queries — vocabulary search returns per keystroke over 10,000+ terms, toggling mastered no longer re-serializes everything, and the same data becomes readable by widgets and extensions.

*Why:* Every flagship idea (sync, widgets, share extension, big banks, backups) is throttled by full-dictionary UserDefaults rewrites on every event and the absence of any migration story — this is the enabling investment, done once.

*Integration:* Wrap stores behind protocols; extend PersistentCodableStore with a file/SwiftData-backed schema-versioned mode; one-time v1→v2 migrator at launch; App Group entitlement added.

<sub>Merged proposals: SwiftData migration with indexed instant search; Migrate Core Stores off UserDefaults to Versioned File Store (Sync-Ready Foundation)</sub>

### Streaming AI via a Unified ProviderClient
**Impact 5/5 · Effort Large (1–2 weeks)**

Extract one ProviderClient protocol (complete + stream variants) collapsing the five copy-pasted provider switches, then add SSE streaming to CloudAIService (OpenAI deltas and Anthropic events) and wire the unused OllamaService.chatStream: explanations render token-by-token, translations type themselves out, grading shows live progress, every AI surface gains a working Cancel instead of a blind 180-second spinner, and 429/5xx retry/backoff lives once.

*Why:* Streaming is the largest perceived-latency win in the app and prerequisite plumbing for the conversation partner and tutor chat, while the protocol makes every future provider or feature a one-file change and fixes the broken Regenerate cache-bypass in one place.

*Integration:* New Services/ProviderClient.swift with AppleIntelligence/Ollama/Cloud conformances; AsyncThrowingStream chat on CloudAIService; consumed by AIWordExplanationView, TranslateView's AI path, WorkbookGradingView, and BatchExplanationController.

<sub>Merged proposals: ProviderClient protocol plus SSE streaming for AI responses; Streaming AI responses across the app</sub>

### Off-Main NLP Pipeline with Pinyin Cache
**Impact 4/5 · Effort Medium (days)**

Move segmentation and pinyin conversion into a TextAnalysisActor with an NSCache keyed by word (CFStringTransform currently runs per segment on every re-render) and content-stable segment IDs instead of fresh UUIDs — pasting a long article renders with a brief shimmer instead of freezing scrolling, and display-preference flips stop causing full ForEach identity churn.

*Why:* Segmentation and transform run synchronously on the main actor with no caching — the documented cause of jank on long texts and the direct blocker to smooth 120Hz reading (and to the Reader).

*Integration:* RubyTextView.updateSegments becomes an async .task calling the actor; PinyinConverter gains a static NSCache; RubySegment.id derived from (text, offset) with no caller API change.

### Decompose God-Views into Feature Modules
**Impact 4/5 · Effort Large (1–2 weeks)**

Split the four 1,000+ line views (VocabularyView 1544, PhotoTranslateView 1476, TranslateView 1226, StatsView 1102) into feature folders with @Observable view models receiving protocol-typed dependencies via init instead of .shared singletons, extracting the duplicated components (translate buttons ×3, term-detail near-duplicates, workbook styles) — enabling #Preview coverage with mocks and shrinking body recomputation.

*Why:* 9,700 lines across 12 view files with singleton access makes the app untestable, unpreviewable, and prone to whole-tab recomputation — this is the enabling refactor for tests, previews, and every other idea.

*Integration:* New feature folders under Views/; store protocols in Models; SwiftMandarinApp keeps concrete singletons and injects them via environment keys.

### Unified Actor-Based AI Cache
**Impact 4/5 · Effort Medium (days)**

Consolidate the four divergent caches (two explanation caches with inconsistent keys, the non-thread-safe translation dict, the per-passage identification cache) into one AICacheActor with LRU capping, a canonical key scheme, and atomic disk persistence — Regenerate actually regenerates, word-tap lookups survive relaunch, failed segmentations become retryable instead of cached-empty, and batch results flush on backgrounding.

*Why:* Inconsistent cache keys cause the visible Regenerate bug, the translation cache is a data race waiting to happen, and cache misses cost real API money — one actor fixes correctness, thread safety, and cost simultaneously.

*Integration:* AICacheActor replaces WordExplanationCacheStore internals; WordTranslationService and WordIdentificationService delegate to it; scenePhase.background flush hook in SwiftMandarinApp.

### ImagePipeline Actor: Off-Main Decode and Smart Uploads
**Impact 4/5 · Effort Medium (days)**

One actor owning all image work: workbook photo decode/downscale off the main actor (picking 10 photos stops freezing the UI), strip-based screenshot stitching cutting memory from O(4·W·H) to O(4·W·300) while fixing the point/pixel scale bug, 1568px JPEG recompression before base64 vision uploads, and an NSCache of thumbnails so history lists stop decoding full-size JPEGs for 80pt cells.

*Why:* Image handling is the app's biggest memory and main-thread hazard; one actor fixes freezes, a real stitching correctness bug, memory spikes, and upload latency together.

*Integration:* Services/ImagePipeline.swift; WorkbookGradingView's loading delegates to it; ScreenshotStitchingService takes cropped strips; AI image paths call pipeline.prepareForUpload.

### Test Target + CI Quality Gate from Zero
**Impact 4/5 · Effort Medium (days)**

Add a swift-testing unit target covering the algorithmic core that keeps breaking silently — SRS scheduling, tone detection, repairJSON with adversarial fixtures, import/export round-trips (including the UUID-regeneration bug), language detection, and the filtered-onMove index mapping — plus a GitHub Actions workflow building iOS + macOS and running tests on every push.

*Why:* The map documents at least eight pure-logic bugs a 200-line test file would have caught; for a solo developer CI is the only reviewer and the prerequisite for the ambitious refactors.

*Integration:* New SwiftMandarinTests target; .github/workflows/ci.yml with xcodebuild test; pure types (PinyinConverter, repairJSON, SRSEngine) already have no UI dependencies.

### Typed SettingsStore
**Impact 3/5 · Effort Small (hours)**

A single @Observable SettingsStore declaring every preference key once with type and default, replacing ~30 ad-hoc @AppStorage declarations and raw UserDefaults lookups — mechanically fixing the shipped hapticFeedback default-mismatch bug, unifying divergent iOS/macOS settings surfaces, and forcing the dead macOS controls to be either wired or removed.

*Why:* Default-mismatch bugs between @AppStorage and raw reads are live today, and two platforms redeclare the same keys with copy-pasted defaults; a central registry eliminates the whole bug class permanently.

*Integration:* Models/SettingsStore.swift injected via environment; views migrate @AppStorage properties incrementally; haptic reads switch to store.hapticFeedback.

### Lazy Store Hydration with Signpost Instrumentation
**Impact 3/5 · Effort Medium (days)**

Instrument launch with os_signpost intervals per store, then hydrate lazily: only TranslationState loads before first frame while History, Vocabulary, Stats, and workbook stores load async on first tab visit with skeleton rows, and Stats derivations (currently materialized three times per body over 365 days) cache — cold launch drops measurably for the heaviest users.

*Why:* Launch cost grows linearly with user data under the current design — the most engaged users get the worst launches — and signposts make the win measurable rather than speculative.

*Integration:* Add async load() to each store called from tab .task instead of init; OSSignposter in PersistentCodableStore.load; StatsView computes activitiesForLastDays once and passes down.

### Instant Pinyin-Aware Search Index
**Impact 4/5 · Effort Small (hours)**

A precomputed in-memory index of normalized fields per term (diacritic-stripped pinyin, tone-number pinyin, lowercase definition tokens) searched off-main with 100ms debounce — find 中国 by typing 'zhongguo', 'zhong1guo2', or 'china' within a frame at 10k terms, with true pinyin collation replacing code-point sorting, also powering pinyin-aware history search.

*Why:* Search is the highest-frequency interaction in a vocabulary app and currently runs raw String.contains in the view body with Unicode-order sorting — degrading exactly as the user succeeds; deliverable independently of the SwiftData migration.

*Integration:* SearchIndex struct owned by SavedTermsStore, rebuilt incrementally on add/remove; VocabularyView.filteredTerms and HistoryTabView delegate via .task(id: query).


## Completeness-critic additions

A final adversarial pass asked: *what did every lens miss?* These additions cover gaps versus competitor capability and unaddressed weaknesses in the subsystem maps.

### Handwriting Input & Stroke-Order Writing Practice
**Impact 5/5 · Effort Extra-large (multi-week) · core-learning**

A PencilKit/finger canvas for writing hanzi: (1) handwriting lookup — draw an unknown character and get candidates via on-device recognition (Vision/MLKit-style zh handwriting model or scribble-to-text), feeding the existing word-detail flow; (2) writing practice — animated stroke-order playback (Hanzi Writer / makemeahanzi stroke data, bundled JSON) with trace-over grading (stroke count, order, direction tolerance) as a fourth card facet in Learn. Wrong strokes flash red; completed characters earn the SRS 'write' skill credit.

*Why:* Every serious competitor (Pleco, HelloChinese, Skritter, Duolingo) has handwriting; the idea list covers decomposition and dictation but nothing lets users physically write characters or look one up by drawing — a defining Mandarin-app capability, especially on iPad with Apple Pencil.

*Integration:* New canvas component used by WordDetailPopover (lookup), LearnView (writing facet, extends CardProgress), and VocabularyView term detail; stroke data bundled like the phrasebook.

### Bundled Offline Dictionary (CC-CEDICT) with Multi-Sense Entries
**Impact 5/5 · Effort Large (1–2 weeks) · core-learning**

Ship a CC-CEDICT-derived on-device dictionary (SQLite/FTS): tap any word and instantly see all senses, correct word-level pinyin (fixing 银行/行走 polyphones), traditional/simplified forms, classifier hints, and compound words containing the character — no network, no AI cost, zero latency. Search supports hanzi, fuzzy tone-insensitive pinyin (ni3hao / nihao / nǐhǎo), and English gloss. AI explanation becomes an enrichment layer on top rather than the only lookup path.

*Why:* Pleco's core value is the offline dictionary; SwiftMandarin's lookups currently depend on Apple Translation or paid AI and return one machine gloss. This fixes the polyphone pinyin bug class and makes the app fully usable offline.

*Integration:* New DictionaryService consulted by WordDetailPopover, RubySegment pinyin generation (PinyinConverter word-level pre-pass), WordTranslationService cache-miss path, and a searchable Dictionary screen.

### Manual Term Creation, Full Editing, Tags & Decks
**Impact 4/5 · Effort Medium (days) · vocabulary-management**

An 'Add Word' button and full edit sheet for saved terms: edit hanzi, pinyin, definition, part of speech, and notes (today only the definition can be replaced, and only via a fetched translation). Add user tags and deck/folder grouping (e.g. 'Lesson 3', 'Restaurant trip'), with deck-scoped review sessions in Learn and deck filters in Vocabulary. Allow multiple senses of the same headword (the current dedupe silently blocks a second sense).

*Why:* Anki and Pleco treat manual entry, editing, and deck organization as table stakes; no existing idea addresses that SwiftMandarin literally cannot create or correct a term by hand — OCR/AI mistakes are permanent.

*Integration:* SavedTerm gains tags/deck fields (tolerant decoder handles migration); VocabularyView toolbar '+' and edit sheet; LearnView CardSource extended with deck selection; export formats carry the new fields.

### English-Side Parity: Tappable English Words, IPA & Fixed Chinese-Only Chrome
**Impact 4/5 · Effort Medium (days) · bilingual-parity**

Make the English half of every translation as interactive as the Chinese half for the app's declared Chinese-native learner mode: tappable English words in TranslateView output (EnglishRubyTextView already exists but is only wired into the photo tab), IPA phonetic transcription and syllable stress in EnglishWordDetailSheet, English-side TTS with per-word highlight, and localization of the sheet's hardcoded Chinese section headers so both audiences can use both pipelines. English flashcard fronts get audio-first and spelling facets.

*Why:* LearnerMode promises a bilingual app, but the map shows English output is inert text and English detail views have untranslated Chinese chrome — half the target audience gets a second-class product, and no themed idea addresses it.

*Integration:* Reuse EnglishRubyTextView/EnglishTextAnalyzer inside TranslateView's output pane; extend EnglishWordDetailSheet; String(localized:) the hardcoded strings; IPA from a small bundled lexicon.

### Mandarin Grammar Point Library (Chinese Grammar Wiki-Style)
**Impact 4/5 · Effort Large (1–2 weeks) · curriculum**

The app's only grammar content is 14 hardcoded English-grammar points for Chinese kids; learners of Mandarin get nothing. Ship a structured Mandarin grammar library (把/被 constructions, 了 usage, 的/得/地, measure words, comparisons with 比, resultative complements...), organized by HSK level, each with pattern template, examples with ruby text, and common mistakes. Detected patterns in any translated/read sentence surface as tappable grammar chips linking into the library; each point is SRS-trackable like vocabulary.

*Why:* HelloChinese and DuChinese teach grammar in context; the 'Why?' AI button explains ad hoc but nothing gives learners a browsable, level-organized Mandarin grammar curriculum — a glaring asymmetry given GrammarKnowledgeBase already exists for the other direction.

*Integration:* Extend GrammarKnowledgeBase with a JSON-backed zh corpus and direction awareness; pattern matcher runs on RubyTextView segments; chips in TranslateView/reader link to detail views; optional grammar cards in LearnView.

### Audio & Podcast Import: Transcribe, Read Along, Study
**Impact 3/5 · Effort Large (1–2 weeks) · listening**

Import an audio file (or share one from Podcasts/Files) and the app transcribes it with the existing SpeechAnalyzer/SFSpeechRecognizer stack into a timestamped transcript, rendered as tappable ruby text synced to playback — tap a sentence to replay it, slow it to 0.75x, save words, or send a passage to shadowing practice. Long recordings are chunked with progress; transcripts are saved to the document library for re-study.

*Why:* The reader theme covers text, subtitles (.srt), and web articles but real-world listening material — podcasts, teacher recordings, voice memos — has no path in. The speech-recognition engine is already built; this is DuChinese-style listening for the user's own audio.

*Integration:* SpeechRecognitionService gains a file-based transcription mode (AVAudioFile feed instead of mic tap); output flows into the proposed Document Library and existing RubyTextView/shadowing surfaces.

### Spatial Translation Overlay on Photos & Stitched Screenshots
**Impact 3/5 · Effort Medium (days) · photo-ocr**

Show the photo, not just extracted text: the photo tab displays the selected image with tappable highlight boxes over each OCR block (geometry Vision already returns but the app discards), and TranslatedScreenshotOverlayView earns its name by drawing translations positioned over the stitched image at each block's boundingBox — Google-Lens style for static images — with a slider to fade between original and translated. Tap a region to hear it, copy it, or open word-by-word study.

*Why:* The map notes bounding boxes are captured and thrown away and users never even see their selected image; 'Lens Mode' covers live camera only. Static-image overlay is the OCR UX every translation app ships (Google Translate, Apple Live Text).

*Integration:* PhotoTranslateView keeps selectedImageData + RecognizedTextBlock geometry for an interactive preview; TranslatedScreenshotOverlayView renders TranslatedTextBlock.boundingBox positions in a Canvas/ZStack over the stitched image.

### Matching-Pairs & Speed-Tile Mini-Games
**Impact 3/5 · Effort Medium (days) · study-loop**

Two lightweight game modes over the user's own due/weak vocabulary: (1) Match — a grid pairing hanzi↔meaning, hanzi↔pinyin, or audio↔hanzi against a gentle timer, with streak multipliers; (2) Speed Tiles — hear a word, tap the right tile among distractors drawn from confusables. Sessions are 60–90 seconds, count as SRS reviews at reduced weight, feed the activity heatmap, and appear as a 'Quick Game' card in the daily mix for low-energy moments.

*Why:* HelloChinese and Duolingo retain users with sub-2-minute game loops; the SRS theme covers quizzes and cloze but nothing playful and fast. Games convert dead time into reviews and soften the grind for the app's grade-school workbook users.

*Integration:* New game views draw cards from LearningProgressStore.getCardsForReview and SavedTermsStore; results call recordReview with a game-source flag; entry points in LearnView and the proposed Today tab.

### AI Token Usage & Cost Meter
**Impact 3/5 · Effort Medium (days) · ai-transparency**

Track the usage blocks both wire formats already return (currently discarded): per-request tokens, rolled up per provider, per feature (explanations, grading, batch, OCR cleanup), per day. A Settings dashboard shows estimated spend using a small editable price table, and batch analysis shows a pre-run estimate ('~1,200 words ≈ 850K tokens ≈ $1.30') with an optional monthly soft cap that warns before expensive runs. Vision-grading requests display size before sending.

*Why:* This is a BYO-API-key app where a batch run over thousands of words or a 10-image grading call spends real money invisibly; no themed idea gives users any cost visibility or guardrails — a trust and bill-shock issue unique to this architecture.

*Integration:* CloudAIService/OllamaService parse and report usage to a new UsageStore (PersistentCodableStore); BatchExplanationController and WorkbookGradingView show estimates; dashboard added under Settings → AI.

### Game Center: Achievements, Friend Streaks & Weekly Leaderboards
**Impact 3/5 · Effort Medium (days) · motivation**

Adopt GameKit: achievements for milestones the app already tracks (first 100 words, 30-day streak, HSK band coverage, 1,000 reviews), an opt-in weekly XP leaderboard among Game Center friends, and a friend-streak view. Uses Apple's built-in identity and UI — no accounts, no backend, no moderation burden. Achievement unlocks reuse the proposed milestone-moment celebrations.

*Why:* Duolingo's retention engine is social accountability; the motivation theme is entirely solo (quests, XP, shareable cards). Game Center delivers competitor-grade social pressure for near-zero infrastructure, which matters for a solo-developer app.

*Integration:* GKLocalPlayer auth behind an opt-in toggle in Settings; LearningActivityStore record* calls report to GKLeaderboard/GKAchievement; access point shown on the Stats screen.

### Family Profiles for Shared Devices
**Impact 3/5 · Effort Large (1–2 weeks) · households**

Multiple named profiles on one device (avatar picker at launch or in Settings): each profile gets its own vocabulary, SRS progress, streaks, workbook bank, and learner mode, so a parent studying Mandarin and a child doing graded English workbooks stop polluting each other's stats and review queues. A parent view surfaces the child's grading history and weekly summary. Profiles are a namespace prefix over the existing stores, so migration is mechanical.

*Why:* The workbook-grading feature explicitly targets grade 1–6 children while translation/SRS targets adults — the map's data model forces them to share one progress record on the family iPad. No themed idea addresses multi-user at all.

*Integration:* PersistentCodableStore keys gain a profile prefix; store singletons reload on profile switch (mirroring the existing .id(language) rebuild pattern); profile picker in Settings/More.

### visionOS Baseline Pass for the Declared xros Target
**Impact 2/5 · Effort Medium (days) · platform**

The project already lists visionOS in SUPPORTED_PLATFORMS and device family 7, but no idea audits it — meaning users may install a broken or ugly compatibility build. Do a baseline pass: verify navigation, translate, vocabulary, and Learn render correctly in a volumetric-free window; gate camera/mic features behind capability checks; adopt glass-background ornaments for the flashcard rating bar; and either polish the target or remove it from SUPPORTED_PLATFORMS deliberately.

*Why:* Shipping a platform you never test is worse than not shipping it; a flashcard/reading app is actually a strong ambient Vision Pro use case, and the decision (invest or drop) is currently being made by omission.

*Integration:* Audit existing #if os(iOS)/canImport(UIKit) branches (CameraScannerView, PhotoViewer, haptics) for visionOS behavior; add availability gates and a small ornament layer to LearnView.


## Codebase health: defects & debt found during the study

The subsystem mappers read every file and recorded concrete weaknesses. These are not features — they are correctness, UX, and architecture issues worth fixing regardless of roadmap direction. Items marked **[fixed in overhaul]** ship on this branch.


### Speech

**Weaknesses found:**
- TTS is bare-bones: AVSpeechSynthesisVoice(language:) picks the system default voice — no voice picker, no enhanced/premium voice preference, no rate/pitch control (learners typically want slow playback), no zh-TW voice (transcript TTS passes selectedLanguage.rawValue so zh-TW works there, but speakChinese hardcodes zh-CN), and no per-word highlight via synthesizer delegate. **[fixed in overhaul]**
- No AVAudioSession handling in SpeechService: on iOS, TTS during/after recording depends on the leftover .playAndRecord/.measurement session (measurement mode and receiver routing can make playback quiet or odd); SpeechRecognitionService deactivates the session on stop but TTS never configures its own. **[fixed in overhaul]**
- downloadModelIfNeeded's progress observation is a polling Task that is never cancelled if downloadAndInstall throws, and AssetInventory allocation is never released; failures collapse to a generic .modelNotInstalled losing the underlying reason.
- First-time model download happens inline inside startRecording with no UI affordance beyond a small percent pill — the user taps the mic and nothing records, potentially for minutes, with no cancel button.
- LiveSpeechTranslationView duplicates state (local transcript mirrors speechService.completeTranscript via onChange) — an avoidable sync channel; transcriptSection renders finalTranscript while triggerTranslation uses transcript (complete incl. partial), so displayed text and translated text can diverge.
- speechService.error set by onStreamError is never surfaced in the view — a mid-session recognition failure silently stops the pulse animation with no message (the view only shows errors from startRecording throws and translation failures).
- Legacy engine finals: SFSpeechRecognizer restarts within one session produce cumulative text, but SpeechRecognitionService concatenates finals with spaces — wrong for Chinese (spaces between CJK runs) and RubyTextView receives space-joined finals; also the ~60s SFSpeech task limit means long dictation on iOS 17 errors or truncates with no auto-restart.
- Language pill is free-form but direction is inferred only by isChineseCharacter scan; speaking English while selectedLanguage is Chinese yields garbage recognition with no mismatch hint; zh-TW recognition output is still routed to zh-CN TTS and simplified-oriented pinyin lookup.
- No pause/resume, no audio level metering (waveform bars are random heights, not real levels), no elapsed-time indicator, no haptics on start/stop. **[fixed in overhaul]**
- Live-speech translations are never saved to history (HistoryTabView) unless the user routes them through 'Use Translation'; 'Use Translation' is enabled while translation is still pending and silently substitutes the transcript for the translation when translatedText is empty.
- ClipboardService.copy on macOS reports failure but no caller checks the result; no copy buttons at all inside LiveSpeechTranslationView (WordDetailPopover onCopy is a no-op {} here).
- SpeechService.speak with an unavailable languageCode yields a nil voice and falls back to the user's default locale voice silently — English default voice may attempt to read Chinese text.
- Modern engine's stop() awaits finalizeAndFinishThroughEndOfInput then cancels recognitionTask — trailing finalized results may be dropped if cancellation wins the race; error path only prints to stdout.
- toggleRecording in the view duplicates SpeechRecognitionService.toggleRecording (dead code in the service for this flow); delegate protocol appears unused by this view (relies on @Observable) — two overlapping notification mechanisms.

**Improvement opportunities noted by the mapper:**
- Add a TTS settings surface: voice picker (AVSpeechSynthesisVoice.speechVoices() filtered by zh/en, prefer .enhanced quality), adjustable rate with a 'slow' toggle for learners, and persist choices; route zh-TW text to a zh-TW voice.
- Give SpeechService an iOS audio-session strategy (.playback, .duckOthers, .spokenAudio mode) activated per utterance so TTS volume/routing is deterministic regardless of prior recording.
- Use AVSpeechSynthesizer delegate willSpeakRangeOfSpeechString to highlight the currently spoken word in RubyTextView — high-value for a language-learning app.
- Surface speechService.error in LiveSpeechTranslationView (banner or alert) and add a retry; today mid-session failures are invisible.
- Replace the polled download-progress Task with progress observation tied to the download's lifetime (cancel on throw), release AssetInventory allocations, propagate the underlying download error text, and add an explicit pre-download screen with cancel before first recording.
- Join Chinese final segments without spaces (check .containsCJK on both sides) in SpeechRecognitionService.onFinalResult so RubyTextView segmentation and translation input aren't polluted by spurious spaces.
- Auto-restart the legacy SFSpeechRecognizer task on the ~1-minute limit (detect final+isStopping==false, restart request) to support long dictation on iOS 17.
- Drive the waveform bars from real audio power (installTap already has the buffer; compute RMS and publish a level) instead of CGFloat.random.
- Auto-save completed voice translations to translation history, and disable 'Use Translation' until translatedText is non-empty (or label the fallback behavior).
- Remove the local transcript mirror: bind the view directly to speechService.completeTranscript and translate from the same string the transcript card displays.
- Auto-detect spoken language mismatch (e.g., selectedLanguage == .chinese but transcript has zero CJK after N chars) and offer a one-tap 'Switch to English?' hint.
- Add copy buttons on the transcript/translation cards using ClipboardService (currently absent in this view), and wire WordDetailPopover's onCopy.
- Deduplicate toggle logic (use service.toggleRecording) and drop the unused SpeechRecognitionDelegate path if nothing implements it, or fold it into the closure API.

### text-analysis

**Weaknesses found:**
- Tone-coloring bug for learners: RubyWordView.pinyinColor (RubyTextView.swift:226-241) colors the WHOLE multi-syllable word one color chosen by fixed priority (tone-1 diacritics checked first), so e.g. 中国 zhōngguó shows entirely red despite the 2nd-tone second syllable — misleading tone feedback in the primary reading view **[fixed in overhaul]**
- Duplicated, divergent tone logic: RubyWordView reimplements detection with contains() and uses system .red/.orange/.green/.blue, while PinyinConverter.Tone uses custom Color(red:...) values — the ruby view and detail sheets show different tone palettes
- CFStringTransform pinyin has no polyphone/context handling: characters like 行/长/了/得 get one dictionary reading regardless of the word, and there is no tone-sandhi handling (不/一); AI segments mitigate this only when present
- NLTagger .lexicalClass is weakly supported for Chinese, so most Chinese words land on PartOfSpeech.unknown — chip borders are mostly the meaningless .secondary color in the local-fallback path
- Segmentation always forces .simplifiedChinese even though detectLanguage recognizes traditional Chinese, degrading traditional-text segmentation
- EnglishTextAnalyzer grammar heuristics are substring-based and noisy: contains("ed") flags 'red'/'need' as simple past, contains("est ") flags 'best', the -ing check flags 'This ring is...' — false grammar lessons surface to learners; detectSentenceType also re-runs analyzeWords, duplicating work
- RubySegment/AnalyzedWord ids are fresh UUID()s on every re-segmentation, causing ForEach identity churn; segmentation and per-word pinyin conversion run synchronously on the main thread in onAppear/onChange with no caching — jank on long texts
- aiSegmentsToken hashes only segment texts, so AI updates that refine pinyin or meanings without changing word boundaries never trigger updateSegments
- Hardcoded Chinese UI strings in EnglishWordDetailSheet (词形变化, 原形, 词性说明, 单词详情, 保存到词汇本, 正在翻译...) bypass the string catalog, so English-UI users see untranslated Chinese chrome
- RubyTextView's englishMeaning parameter is stored but never used in the body (dead API); print() debug logging left in WordDetailPopover.fetchWordDetails; redundant MainActor.run inside an already-MainActor .task
- PinyinConverter.segment only splits on whitespace/apostrophes, so AI-supplied unspaced pinyin ("nǐhǎo") is treated as one syllable and gets one color; includeToneMarks=false strips diacritics with no tone-number alternative, losing tone info entirely
- PunctuationView's ghost line (a transparent caption-sized space) only approximates pinyin row height and ignores the 'inline' position, so baseline alignment can drift when pinyin shrinks via minimumScaleFactor(0.7)
- No accessibility treatment: each chip is a plain Button whose VoiceOver label concatenates diacritic pinyin and hanzi with no combined element or spoken-language hints

**Improvement opportunities noted by the mapper:**
- Replace RubyWordView.pinyinColor with Text(PinyinConverter.coloredPinyin(fromPinyin: segment.pinyin)) to get per-syllable tone coloring and a single shared palette — a small diff fixing the biggest learner-facing inaccuracy
- Add a word-level pinyin lexicon (e.g. bundled CC-CEDICT subset) consulted before the character-level .mandarinToLatin transform, fixing polyphones like 银行/行走; keep transform as fallback
- Cache pinyin per word (static [String: String] or NSCache) since PinyinConverter.convert runs applyingTransform on every RubySegment init and every re-render/re-segmentation
- Give segments stable identity (word text + character offset) instead of UUID(), and move segmentWithPartsOfSpeech into a background task for long passages
- Include pinyin and meaning in aiSegmentsToken (or make RubySegment Equatable and observe the array) so asynchronous AI refinements to readings/meanings actually re-render
- Pass detected script (simplified vs traditional) into tokenizer/tagger setLanguage instead of hardcoding .simplifiedChinese
- Rewrite detectGrammarPoints/detectSentenceType with word-boundary regex or the already-computed POS tags (pass words in rather than re-analyzing) to kill 'red'->past-tense false positives
- Wrap EnglishWordDetailSheet's hardcoded Chinese strings in String(localized:) so they follow the existing language toggle like the grammar-point labels already do
- Add tone-number output mode to PinyinConverter (ni3 hao3) instead of only strip-diacritics, useful for copy/export and input-method practice
- Derive PunctuationView's ghost line height from the actual pinyin font metrics (or use a custom alignment guide) and handle the 'inline' position; add .accessibilityElement(children: .combine) with a spoken label on RubyWordView
- Remove the unused englishMeaning parameter from RubyTextView and the leftover print() in fetchWordDetails; drop the redundant MainActor.run blocks
- Apply tone-sandhi display rules (不 bú before 4th tone, 一 yí/yì) as an optional learner toggle, and surface a tone-color legend since colors are otherwise unexplained in the reading view

### stats-activity

**Weaknesses found:**
- Heatmap weekday labels are wrong: activitiesForLastDays slices sequential days into groups of 7 by array index with no alignment to calendar weekdays, so row 0 is always (today - N + 1) not Sunday — the hard-coded M/W/F gutter labels mislabel almost every cell (StatsView.swift:911, 921-925) **[fixed in overhaul]**
- currentStreak is a computed property over Date(): the displayed streak goes stale at midnight (or shows yesterday-anchored streak all day) until some activity mutates the store and triggers @Observable invalidation — no day-rollover refresh (TimelineView/scenePhase) **[fixed in overhaul]**
- longestStreak is only a high-water mark updated during record* calls and lives in plain UserDefaults outside the backed-up store; it is never recomputed from history, so restore/reinstall shows 0 Best streak despite intact activity data (LearningActivity.swift:396-408) **[fixed in overhaul]**
- 14-day bar chart labels the x-axis with abbreviated weekday only, so two bars share identical 'Mon'/'Tue' labels with no date disambiguation (StatsView.swift:383-394)
- Heatmap cells are 6-10pt on iPhone with tap-only interaction and no accessibility labels — hard to hit precisely, invisible to VoiceOver, and no drag-to-scrub
- activitiesForLastDays is recomputed three times per body evaluation (heatmap, contributionMaxScore, averageDailyReviews), each doing N calendar math + dict lookups on every render of a 180/365-day range
- Triplicated POS color mapping: posColorScale KeyValuePairs, colorForPartOfSpeech switch, and PartOfSpeechCategory.color String — three copies that can drift
- Dead code: masteredCardCount (StatsView.swift:790) never used; weeklyTotals, weeklyWordsByPOS, activitiesForMonth store APIs have no callers anywhere
- Every recorded event rewrites the entire activities dictionary to UserDefaults; unbounded growth over years of daily entries
- iPad/iPhone detection via UIDevice.userInterfaceIdiom rather than size classes, so iPad Split View / Slide Over narrow windows still get wide layouts
- No study-time/duration tracking, no week-over-week or trend insights, no goal setting — 'insights' are raw lifetime counters only; activityScore weighting (words x3) is invisible/unexplained to users
- Heatmap legend swatches sample the log color ramp at linear 0/25/50/75/100% of maxScore, so perceived legend steps are uneven; zero-activity days are still tappable and show an all-zero detail row
- Local-timezone dateKey means timezone travel can split or merge 'days', silently breaking streaks (acknowledged as intentional in a comment but with no mitigation)
- Identical ternary branches for compact vs regular day labels (StatsView.swift:911) — dead conditional; @State selection angles declared mid-file between methods

**Improvement opportunities noted by the mapper:**
- Align heatmap columns to calendar weeks: pad the first column to the first date's actual weekday so the M/W/F gutter labels become truthful, matching GitHub behavior
- Recompute longestStreak from the full activities history in loadActivities() (single backwards scan) instead of trusting the separate UserDefaults int, fixing restore/reinstall loss
- Drive streak display through a midnight-aware source (TimelineView(.everyMinute)/scenePhase change or a cached day-stamped value) so it updates at day rollover
- Memoize activitiesForLastDays per render (compute once in body, pass down) or cache in the store keyed by dateKey(today) and invalidate on mutation
- Add date context to 14-day axis (e.g., .dateTime.day().weekday(.narrow)) or switch to stride-by-2-days labels to remove duplicate weekday ambiguity
- Collapse the three POS color mappings into one Color-valued computed property on PartOfSpeechCategory used by both scale and legend
- Add accessibilityLabel(date + score breakdown) to ContributionCell and a drag gesture over the heatmap grid for scrubbing; enlarge effective hit area beyond visual cell
- Use the already-built weeklyTotals/weeklyWordsByPOS APIs to add a monthly/weekly aggregate chart (or delete them along with masteredCardCount)
- Record session duration and add derived insights: week-over-week delta, most productive weekday, projected streak milestones
- Debounce/coalesce saveActivities during bursts (e.g., grading N questions or bulk-saving words) instead of full-dictionary write per event
- Switch layout branching to @Environment(\.horizontalSizeClass) for correct iPad multitasking behavior
- Surface the activityScore formula in the UI (info popover on the heatmap legend) so 'Less/More' has meaning

### app-shell

**Weaknesses found:**
- Dead settings on macOS: launchAtLogin, showInMenuBar, showDockIcon, globalHotkey (display-only text, no recorder), dailyGoal, showStreak, reviewReminders, reminderTime, autoAdvance, showHints, chineseFont, wordBorders, and compactMode are written by MacOSSettingsView but consumed nowhere (verified by grep) — users toggle switches that do nothing
- @AppStorage("reminderTime") private var reminderTime: Date (MacOSSettingsView.swift:333) — @AppStorage has no native Date support and no Date: RawRepresentable extension exists in the repo; combined with no notification-scheduling code, the whole Notifications section is inert at best
- Default mismatch bug: hapticFeedback @AppStorage default is true, but consumers (TranslateView.swift:1163, VocabularyView.swift:895) read UserDefaults.standard.bool(forKey:) which returns false when unset — haptics are off while the toggle shows on until the user touches it once **[fixed in overhaul]**
- Likely dropped cold-launch intent on iOS: MoreView's .onChange(of: routeStore.pendingAction?.id) has no initial: true, so a startReview pendingAction set before MoreView first renders (Siri launching the app) never pushes LearnView
- .id(localization.language) rebuilds the entire view tree on language toggle — all navigation stacks, scroll positions, and in-progress input are destroyed; MoreView's path resets so the user is dumped back to the hub root
- Settings are duplicated per platform with divergent capability: export/import and maxHistoryEntries exist only on macOS; Clear Cached AI Explanations and AI Photo Cleanup layout only on iOS; same @AppStorage keys re-declared with copy-pasted defaults in two files — classic drift risk
- learnerMode didSet silently overwrites the user's explicit 'Default Direction' Translation setting via UserDefaults.set(...forKey: "defaultDirection") with no UI feedback
- Preference keys are stringly-typed and inconsistently named (snake_case in AppPreferences/LocalizationManager vs camelCase @AppStorage) with no central registry; consumers use raw UserDefaults lookups that bypass @AppStorage defaults
- Localization keys are English sentences (e.g. L("Version"), Text literals) — editing English copy silently orphans the zh-Hans translation; L() interpolations like "\(L("Version")) \(AppConfig.appVersion)" bypass proper format-string localization
- Only en and zh-Hans UI languages despite OCR supporting zh-Hant; no Traditional Chinese UI option
- AppPendingAction.startReview(mode: String, source: String) uses untyped strings for mode/source instead of enums
- No onOpenURL/deep-link handling in the shell — routing is App-Intents-only; no state restoration of selectedTab across launches (always resets to .translate)
- 'Rate App' and 'Share App' currently link to the GitHub repo (appStoreID nil) — confusing for end users who expect the App Store
- LanguageOverrideBundle is @unchecked Sendable and the Bundle.main object_setClass swizzle, while standard, is fragile against future SDK changes and invisible to newcomers reading call sites

**Improvement opportunities noted by the mapper:**
- Wire up or remove the inert macOS settings: SMAppService.mainApp for launchAtLogin, MenuBarExtra scene for showInMenuBar, NSApp.setActivationPolicy for showDockIcon, KeyboardShortcuts-style recorder for globalHotkey, UNUserNotificationCenter scheduling for review reminders — or delete the sections until implemented
- Fix the hapticFeedback default mismatch by reading via `UserDefaults.standard.object(forKey:) as? Bool ?? true` (matching AppPreferences' pattern) or centralizing in AppPreferences
- Add initial: true to MoreView's onChange on pendingAction?.id (or check in .onAppear) so cold-launch Siri review intents aren't dropped
- Extract a shared SettingsKeys namespace (or extend AppPreferences) so iOS and macOS settings surfaces bind the same typed properties instead of duplicating @AppStorage declarations and defaults
- Persist and restore selectedTab (AppRouteStore could back it with UserDefaults/SceneStorage) so the app reopens where the user left off
- Replace the whole-tree .id(language) rebuild with locale-environment-driven updates where possible, or at minimum preserve MoreView's navigation path across a language flip
- Unify the iOS/macOS settings feature set: bring vocabulary export/import and maxHistoryEntries to iOS DataManagementView, and Clear Cached AI Explanations to macOS DataSettingsTab
- Type AppPendingAction.startReview's mode/source as enums shared with the App Intents layer
- Add onOpenURL + a URL scheme mapped onto AppRouteStore.trigger so widgets/links can deep-link, reusing the existing pendingAction plumbing
- Once appStoreID lands, add SKStoreReviewController/requestReview for in-app rating instead of the write-review URL; meanwhile hide Rate/Share rows or label them as GitHub links
- Consider zh-Hant as a third AppLanguage since PhotoScanLanguage already recognizes it
- Move the learnerMode → defaultDirection side effect behind an explicit confirmation or make TranslationSettingsView surface that the value was changed by the mode picker

### vocab-learning

**Weaknesses found:**
- SM-2 deviations that hurt scheduling: reviewCount is a lifetime counter that never resets, so a card failed on reviews 1-2 skips the 1-day/6-day graduation steps entirely and jumps to previousInterval*EF; the persisted `interval` field is write-only (calculateNextReview recomputes from nextReviewDate-lastReviewDate instead of using it); `lapse` is documented as used 'for spaced-repetition scheduling' but never read (LearningCard.swift:143-163) **[fixed in overhaul]**
- A quality<3 ('Again') answer schedules a 10-minute relearn but the session never requeues the card — the user moves on and the card silently comes due mid-session with no way to see it without restarting Due-for-Review **[fixed in overhaul]**
- Mastery level uses lifetime accuracy, so early mistakes permanently cap a card (3 fails then 20 successes ≈ 87% → never 'mastered'); also dead duplicate branches 0..<0.3 and 0.3..<0.5 both map to .learning (LearningCard.swift:133-141) **[fixed in overhaul]**
- Two disconnected 'mastered' concepts: SavedTerm.isMastered (manual checkbox in Vocabulary) and CardProgress.masteryLevel (SRS-derived in Learn) never interact — mastering a word in one place does nothing in the other
- Deleting a SavedTerm orphans its vocab:<UUID> CardProgress forever; orphans inflate the stats sheet's 'Cards Studied' and 'Due for Review' counts; the only cleanup is Reset Progress, which nukes built-in deck history too **[fixed in overhaul]**
- 'Clear All' vocabulary and 'Reset Progress' are one-tap destructive actions with no confirmation dialog and no undo
- 'Due for Review' StudyMode requires an existing progress record with nextReviewDate<=now, so brand-new cards never surface there (and 'Difficult' can never match .new since first review always moves off it) — a new user sees 'No cards due. Great job!' despite 15 unlearned cards; getDueCards (which includes new) is unused by LearnView
- CSV import regenerates term UUIDs (no id column), so re-importing a CSV backup severs all spaced-repetition history; sortOrder also isn't preserved; header row is skipped blindly by index (a headerless file loses its first row) and rows with <3 columns are dropped with no per-row error reporting **[fixed in overhaul]**
- Wrap-around arrow navigation in LearnView lets users cycle past cards without rating; completion only triggers by rating the final card, and progress '(x of y)' can mislead after wrapping
- ExportSheet recomputes generateExportData in the view body for the preview, the ShareLink condition, and aiAnalysisCount queries the AI cache for every term per render — repeated full serialization (incl. base64 of all analyses) on every SwiftUI update; janky with large vocabularies
- Whole-array JSON re-encode to UserDefaults on every single mutation (each mastered toggle) on the main actor — scales poorly; UserDefaults is also loaded wholesale at launch (the file-backed path exists but isn't used for terms/progress)
- Alphabetical/pinyin sorts use raw String < / > (code-point order): not locale-aware, tone-marked pinyin sorts oddly, and Chinese headwords sort by Unicode value rather than pinyin collation (VocabularyView.filteredTerms)
- Grammar keyword matching is naive substring matching: keywords like 's', 'es', 'er', 'ing', 'is', 'are' make findMatchingPoints match nearly any English sentence (GrammarPoint.swift:149-156); the knowledge base is hardcoded (14 points), untracked by SRS, and unrelated to the Mandarin-learning direction
- Duplicate detection only compares the `chinese` headword field, so a legitimate second sense of the same word can never be saved, and saving an already-saved phrase from PhraseDetailSheet silently no-ops yet still dismisses as if it succeeded
- No way to manually add a vocabulary term or edit chinese/pinyin/partOfSpeech fields — only the definition can be replaced, and only via a fetched translation
- filteredCategories in PhrasesView constructs new PhraseCategory instances (fresh UUID ids) on every search keystroke — SwiftUI section identity churn; Phrase ids are also instance-bound UUIDs rather than content-stable
- TermDetailSheet and TermDetailInspector are ~200-line near-duplicates (translation fetch, copy feedback, update-definition logic duplicated verbatim)
- iOS file importer allows .plainText but the parser only accepts JSON/CSV shapes, so .txt selections fail with a generic 'Could not parse file'
- Session card list is a snapshot: cards saved/deleted mid-session or session interruption isn't handled (no session persistence); due-review cap of 20 is hardcoded with no user control

**Improvement opportunities noted by the mapper:**
- Fix the SM-2 lapse path: track a separate 'repetition' counter that resets on quality<3 (restoring 1d/6d graduation after lapses), read the persisted `interval` instead of re-deriving from dates, and use `lapse` to penalize EF or shorten the next interval
- Requeue 'Again'/'Wrong' cards at the end of the current session (Anki-style relearn queue) instead of letting the 10-minute due date fall between sessions
- Include never-reviewed cards in 'Due for Review' (LearningProgressStore.getDueCards already implements the right predicate — wire LearnView's filter to it) and mix N new cards per session with a daily new-card limit
- Purge orphaned vocab: CardProgress entries when a term is removed (hook SavedTermsStore.remove → LearningProgressStore), and scope Reset Progress to the selected CardSource
- Replace lifetime-accuracy mastery with a recent-window or interval-based mastery (e.g. mastered = interval > 21 days), and remove the duplicated 0..<0.3 / 0.3..<0.5 switch branches
- Bridge the two mastered concepts: auto-set SavedTerm.isMastered when its card reaches .mastered, and show the SRS mastery badge in VocabularyRow
- Add an id column (and sortOrder) to CSV export/import so CSV backups round-trip UUIDs and preserve SRS history; detect the header row by content ('Chinese,Pinyin,...') instead of index; collect per-row parse errors into ImportResult.errors
- Add confirmationDialog + brief undo (keep last snapshot in memory) for Clear All and Reset Progress
- Memoize export preview/data in ExportSheet @State keyed on (format, includeAIAnalysis) instead of regenerating in body; compute aiAnalysisCount once onAppear
- Move savedTerms/learningProgress to the existing file-backed Application Support path (PersistentCodableStore.loadArrayFromFile already exists) or SwiftData, and debounce saves off the per-mutation didSet
- Use localizedStandardCompare for alphabetical sort and a diacritic-insensitive comparator for pinyin; optionally sort Chinese by converted pinyin
- Show the projected next interval on each rating button ('Good · 6d') so users understand the scheduler — all inputs are already available at render time
- Word-boundary (regex \b) keyword matching for GrammarKnowledgeBase.findMatchingPoints and removal of bare-suffix keywords ('s', 'es', 'er', 'ing'); consider externalizing the knowledge base to JSON for growth
- Add manual term creation and full field editing (chinese/pinyin/POS) in VocabularyView; SavedTermsStore.update already supports replacement
- Give PhraseCategory a stable name-based id and Phrase a content-hash id to stop identity churn during search; surface 'Already saved' feedback in PhraseDetailSheet (SavedTermsStore.contains is available)
- Extract the shared TermDetail logic (translation fetch, copy feedback, update-definition) into one platform-agnostic component to collapse the sheet/inspector duplication
- Support Anki-compatible export (TSV with fields, or .apkg) and iCloud key-value/CloudKit sync for terms and progress

### photo-ocr

**Weaknesses found:**
- Translation errors are invisible once results exist: errorView renders only when hasResults is false, but triggerChineseTranslation/translateSentences set errorMessage after results are shown — a user tapping 翻译全部 on a failing network sees the spinner stop and nothing else
- Screenshot stitching mixes point and pixel spaces: overlap is computed on CGImage pixels but subtracted from UIImage.size (points) and used in cgImage.cropping; correct only for scale-1 images, silently wrong for any scale-2/3 UIImage
- Delimiter batch translation is fragile: MT engines can mangle or merge the \n§§§\n marker; on count mismatch remaining blocks silently keep the untranslated original with no warning
- ScreenshotTranslationStore OCRs with default .auto scan language, ignoring the user's photoScanLanguage preference the photo tab honors; source language is guessed purely as the opposite of targetLanguage
- TranslationSession(installedSource:target:) (iOS 26 path) assumes the language pack is installed — no availability check or download prompt; failure surfaces as a raw error string
- sortInReadingOrder's rowThreshold is 2% of total normalized height, so on a tall multi-screenshot stitch one 'row' spans many text lines and left-to-right sorting scrambles reading order
- Per-word translation in translateSentences is sequential, un-deduplicated (same lemma retranslated), skips only determiners/particles, and a single throw aborts all remaining sentence and word translations
- English cleanup corrupts real text: '- ' removal merges bullet lists and negative ranges; the \.([A-Z]) regex inserts spaces inside acronyms like U.S.A.; cleanTextForProcessing in PhotoTranslateView duplicates TextRecognitionResult.cleanTextForSentences verbatim
- TranslatedScreenshotOverlayView's image preview is #if canImport(UIKit) only — on macOS the 'Stitched Image' section renders header with no image; despite the name, no spatial overlay is drawn even though bounding boxes are captured and stored
- Overlap detection allocates full-image RGBA buffers (4*W*H per image) though only the top/bottom 300px strips are compared; maxOverlapPixels=300 underestimates larger overlaps (duplicated content), uniform backgrounds falsely match, and fixed iOS chrome (status/tab bars) is never trimmed so it appears mid-stitch
- DataScanner languages are fixed at controller creation; changing the scan-language pref requires closing and reopening the camera sheet; live text joins all items with spaces losing line structure, and the unused scannerError/onTextRecognized indicate dead scaffolding
- Screenshot translations never enter TranslationHistoryStore and all results vanish on Done — inconsistent with the photo tab's history behavior; the stitch/OCR/translate pipeline is not cancellable after the sheet is dismissed
- PhotoTranslateView never previews the selected image, and per-block OCR geometry (boundingBox) is discarded in the photo tab — no way to see or tap what region produced which text
- PhotoTextRecognitionService singleton mutable state (isProcessing/lastResult) is stomped by concurrent recognitions (photo tab and screenshot store share it); NSImage lockFocus in the macOS stitcher is legacy API and the final composite render runs on the main actor

**Improvement opportunities noted by the mapper:**
- Surface translation failures when results are visible: render errorMessage as a dismissible banner inside resultsSection instead of only in the empty-state branch
- Fix stitching scale handling: convert overlap to points via image.scale (or do all math in pixels on CGImages) before computing heights and cropRects
- Replace delimiter batch translation with per-block TranslationSession.translate requests (the batch API accepts arrays on iOS 18+) to eliminate §§§ round-trip corruption and give per-block error handling
- Pass AppPreferences.shared.photoScanLanguage into ScreenshotTranslationStore's recognizeText call, and use LanguageAvailability to check/download packs before creating TranslationSession
- Crop to comparison strips before getPixelData in ScreenshotStitchingService to cut memory from O(W*H) to O(W*300); add fixed-chrome (status/tab bar) trimming before overlap search
- Make rowThreshold in sortInReadingOrder proportional to median block height rather than total stitched height
- Deduplicate word translations by lemma with a local cache, batch them, and wrap each session.translate in do/catch so one failure does not abort the rest
- Delete PhotoTranslateView.cleanTextForProcessing and call TextRecognitionResult.cleanTextForSentences; guard '- ' removal to lowercase-letter continuations to protect bullet lists
- Add an Image(nsImage:) branch for the macOS preview, and a true spatial overlay mode drawing translatedText at boundingBox positions over the stitched image (data already exists in TranslatedTextBlock)
- Record screenshot translations into TranslationHistoryStore (respecting saveToHistoryAutomatically) and support pipeline cancellation from the store when the sheet dismisses
- Show a thumbnail of selectedImageData in the photo tab with tappable OCR block highlights; recreate the DataScanner (or expose a language toggle in the sheet) when photoScanLanguage changes; remove unused scannerError/onTextRecognized scaffolding
- Add progress granularity (e.g., 'translating block 3/12') to ScreenshotProcessingState for long stitched pages

### Workbook grading

**Weaknesses found:**
- Changing customInstructions does not reset didSaveSession (only workbookImages/answerImages have onChange resets at WorkbookGradingView.swift:133-134), so after one grade the user cannot re-grade the same photos with different instructions — the Grade button stays disabled until they remove and re-add an image **[fixed in overhaul]**
- Image decode/downscale likely runs on the main actor: loadDownscaled/loadDownscaledFiles/downscaledJPEG are default-isolated (project defaults to MainActor per WorkbookImageStore comment), so picking 10 photos does ImageIO thumbnailing on the main thread; only the post-grade disk save is detached
- Dead model API: markReviewed/timesReviewed, subjects, and questions(in:) in WorkbookQuestionBankStore are never called from any view — review counts never increment and the subject tag written by the generator is never filterable or even visible in the bank list
- macOS cannot clear or easily delete: the trash toolbar buttons in both WorkbookQuestionBankView and WorkbookGradingHistoryView are #if os(iOS), and List.onDelete has no swipe affordance on macOS, leaving no discoverable delete path
- No cancel button and no progress detail during a potentially long multi-image vision request; the silent 2x retry can double latency and API cost with only a spinner showing
- History detail is read-only for vocab: WorkbookQuestion persists vocabTerm/Reading/Meaning but SessionQuestionCard offers no save-to-vocabulary or per-question add-to-bank action, and there is no re-grade-from-saved-scans action despite the photos being kept
- Upload thumbnails use ForEach(id: \.offset) over image Data (WorkbookGradingView.swift:264), so removing a middle image shifts identities — animation glitches and stale-view risk
- No payload guardrails: Photos picks cap at 10 per pick but repeated picks/files/drops append unbounded images with no total-size or count warning before a maxTokens-8192 request that may truncate or fail
- Whole-array UserDefaults persistence: every bank add/remove re-serializes the entire question list; large banks and histories will bloat UserDefaults and slow saves; no search or pagination in the bank list
- Dedup key (lowercased question+'∣'+answer) treats trivial OCR variance (e.g. '___' vs '____', punctuation) as distinct, letting near-duplicates accumulate in the bank
- The 'Graded successfully, but N scan(s) couldn't be saved' notice reuses the red error box styling, visually contradicting the success it reports
- PhotoViewer has no pinch-to-zoom, which matters for reading dense 1536px workbook scans; thumbnails decode the full stored JPEG for an 80x106 cell with no thumbnail cache
- Bilingual labels are hardcoded '中文 · English' composites rather than locale-driven strings, doubling visual noise and bypassing the localization system
- imageFromData/workbookImage and the errorBox/providerBanner/card styles are copy-pasted between WorkbookGradingView and WorkbookGradingHistoryView

**Improvement opportunities noted by the mapper:**
- Add customInstructions to the didSaveSession reset set (one extra onChange) so users can re-grade with revised instructions — smallest highest-value fix
- Move loadDownscaled/loadDownscaledFiles/downscaledJPEG off the main actor (nonisolated static or Task.detached) to eliminate main-thread ImageIO work when adding many photos
- Wire up the existing dead API: increment timesReviewed when TTS/reveal is used, surface a subject filter menu in WorkbookQuestionBankView using store.subjects and questions(in:), and show/edit the subject tag on rows
- Add a 'Re-grade' action on GradedSessionDetailView that reloads the stored scan IDs into WorkbookGradingView's buckets — the photos are already on disk
- Add per-question 'save vocab' and 'add to bank' buttons on SessionQuestionCard so history is as actionable as the live result screen
- Provide macOS delete affordances: context menus with Delete on bank/history rows and remove the #if os(iOS) around the clear buttons
- Make grading cancellable (store the Task, show a Cancel button) and surface retry attempts ('retrying…') instead of a silent second call
- Switch thumbnail ForEach to a stable identity (wrap Data in an Identifiable struct with UUID) to fix removal glitches
- Cap or warn on total request size (e.g. sum of JPEG bytes / image count) before sending; consider chunking >N pages into multiple grading calls and merging results
- Distinct info styling (orange/secondary) for the partial-scan-save notice vs real errors
- Migrate bank/history from UserDefaults arrays to per-item files or SwiftData once counts grow; at minimum debounce saves during addAllToBank (currently N sequential full-array writes)
- Normalize the dedup key (strip punctuation, collapse whitespace/underscore runs) to catch OCR-variant duplicates
- Add pinch-to-zoom (MagnificationGesture or ScrollView zoom) to PhotoViewer and a small downsampled-thumbnail cache for SessionPhotoThumbnail
- Extract the shared image-decode helper and card/banner styles into a common WorkbookUI helper file
- Add export/share of a graded session (share sheet or PDF) for parents/teachers

### translation-core

**Weaknesses found:**
- History reorder bug: HistoryTabView.onMove passes offsets from filteredEntries but TranslationHistoryStore.move applies them to the full entries array — reordering while a search or direction filter is active moves the wrong rows (HistoryTabView.swift:85-87) **[fixed in overhaul]**
- 'Duplicate' context-menu action is a no-op copy: store.add() first removes any entry with identical source+target, so it just re-dates and moves the entry to the top — and inflates learning stats via recordTranslationMade() on every call (TranslationHistory.swift:79, HistoryTabView.swift:229) **[fixed in overhaul]**
- Language detection is 'any Chinese character present' — a mostly-English sentence containing one Chinese word is treated as Chinese input and translated zh→en; no NLLanguageRecognizer use; the direction toggle is effectively cosmetic since detectedTranslationDirection always overrides it, which can confuse users who deliberately set a direction
- Direction dedup ignores direction: add() removes entries matching source+target regardless of their direction field, so a legitimate opposite-direction pair is silently deleted
- TranslationState draft is in-memory only — typed text and result vanish on app relaunch; history is the only recovery **[fixed in overhaul]**
- Dead/unused state: aiTranslationError is cleared but never set or rendered (errors go to sharedState.translationError), translationContext computed property is unreferenced, draggedEntry in HistoryTabView is never used, .draggable payload (UUID string) has no visible drop target
- WordTranslationService cache is an unbounded, non-thread-safe dictionary on a non-actor class mutated from arbitrary async contexts; @Observable annotation is pointless for it
- preserveCurrentTranslationDuringSourceUpdate uses a Bool flag reset via DispatchQueue.main.async — fragile reentrancy hack; a second onChange within the same runloop tick behaves differently than expected
- performTranslation mutates sharedState.isTranslating outside MainActor.run at the top but wraps later mutations — inconsistent isolation discipline
- The 'Translating…' spinner always shows the 'download language packs' hint even when the failure/slowness has nothing to do with packs; AI-translating copy differs, but Apple-path errors are string-matched on localizedDescription ('language'/'unavailable') which is brittle and locale-dependent
- UI duplication: translate + AI-translate button pairs exist in three places (source section, swap divider, 'Ready to Translate' placeholder) with slightly different styling/logic
- Tap-to-learn quality is engine-dependent: AI translations get AI word boundaries, Apple Translation deliberately drops to local NLTokenizer segmentation — same sentence segments differently depending on which button was tapped
- On iOS 17 the primary 'Translate' button silently routes to the AI provider and is not disabled when no provider is configured, yielding an error instead of guidance; auto-translate debounce would also fire paid AI calls per pause in typing
- History gaps: no pinning/favorites, no date grouping, no export/share of history, search doesn't match pinyin, manual reorder is meaningless since new entries always insert at top; if saveToHistoryAutomatically is off there is no manual 'save this translation' affordance
- English words are not tappable — only the Chinese side gets the interactive treatment, limiting the app for 中文-native users learning English despite showEnglishFirst logic
- restore/reverseTranslate from history never re-trigger translation; reverse-translate lands the user on a stale empty output requiring another tap

**Improvement opportunities noted by the mapper:**
- Fix filtered onMove: map filtered indices back to store indices (or disable reordering while filtered/searched) in HistoryTabView.swift:85
- Make Duplicate genuinely duplicate (bypass dedup, skip recordTranslationMade) or remove the menu item
- Replace containsChinese-only detection with NLLanguageRecognizer (dominantLanguage) and surface an 'auto-detected: Chinese' chip so users understand why the toggle was overridden
- Persist TranslationState (sourceText/translatedText/direction) to UserDefaults so drafts survive relaunch — trivially done via the existing PersistentCodableStore
- Convert WordTranslationService to an actor with an LRU-capped, optionally disk-persisted cache
- Include direction in the history dedup predicate so opposite-direction pairs coexist
- Extract a single TranslateActionButtons component to replace the three duplicated button clusters
- Run startWordIdentification after Apple Translation completions too (it already guards on provider availability), giving consistent word boundaries across engines
- Delete dead code: aiTranslationError, translationContext, draggedEntry, TranslationDirection.toggled()/label/sourceLabel/targetLabel duplicates; move FlowLayout out of TranslateView.swift into a shared layout file since RubyTextView/StatsView are its real consumers
- Add pinyin-aware history search (PinyinConverter already exists) plus date-section grouping and pin/favorite support
- Auto-trigger translation after reverseTranslate (and optionally restore) so the context-menu action completes the round trip
- Gate iOS 17 auto-translate/primary button on aiSettings.isAnyProviderAvailable and show setup guidance instead of a failure alert
- Replace localizedDescription substring matching in performTranslation's catch with typed TranslationError handling
- Add a manual 'save to history' button when saveToHistoryAutomatically is disabled

### ai-stack

**Weaknesses found:**
- Regenerate is broken within a session: AIWordExplanationView's Regenerate calls generateExplanationWithProvider, which checks the service's in-memory explanationCache first and returns the old result instantly — the button claims to 'always bypass the cache' but only bypasses the persistent store **[fixed in overhaul]**
- AIExplainButton disables itself for cloud-only users: its onAppear availability check is `isAppleIntelligenceAvailable || OllamaService.isConnected`, ignoring configured cloud providers; the 'AI Not Available' empty state text likewise only mentions Apple Intelligence and Ollama **[fixed in overhaul]**
- No streaming anywhere in the cloud path (stream:false, 180s request timeout): users stare at an indeterminate spinner for up to minutes on grading/vision responses; OllamaService.chatStream exists but is unused
- effectiveProvider silently falls back to the first available provider in enum declaration order — a user whose selected provider loses its key can unknowingly start spending a different provider's API credits, and the fallback order is arbitrary
- Two overlapping explanation cache layers with inconsistent keys: the service's in-memory cache keys on provider+direction+word+pinyin+context, the persistent store on (normalizedWord, direction) only — same word with different context creates divergent behavior and double bookkeeping
- No 429/5xx retry or backoff in CloudAIService; a rate-limited batch run marches through the remaining queue marking every word failed with no pause, and failures are only surfaced as a single lastErrorMessage line
- Images are sent full-size: no downscale/recompress before base64 (multi-MB photos balloon request bodies, risk provider size limits and slow uploads); media-type sniffing by first byte misidentifies any RIFF file as webp
- extractJSONObject is not the 'balanced' extractor its comment claims — it slices first '{' to last '}', so prose containing a trailing brace or multiple JSON objects corrupts the parse
- Quotio (local proxy) requires a non-empty API key for chat and model refresh even though local proxies typically need none, and supportsVision=false blocks it from grading/vision flows entirely with no per-model override
- Model capability knowledge is hardcoded keyword lists (nonChatModelKeywords, isLikelyVisionModel, defaultModels, defaultVisionModel) that will silently rot as providers ship new model names; 'gemini' is blanket-marked vision-capable
- The per-feature provider switch (appleIntelligence/ollama/cloud) is copy-pasted across five methods (explanations, cleanup, extraction, review questions, word identification) — adding a provider path or feature means touching each one
- WordIdentificationService caches an empty array on reconstruction failure permanently (until app restart), so one flaky model response disables tap-word segmentation for that passage; maxTokens 2048 with no chunking makes long passages likely to truncate and fail the guard
- Ollama contextLength setting is not honored by explanation generation: generateStructured hardcodes reasoningOptions (128k num_ctx) and settings.ollamaOptions is unused in these paths
- 10s write throttle means up to 10s of batch results can be lost if the app is killed; there is no flush on scenePhase/background
- Tolerant decoders default isCorrect to false and strings to "" on type mismatch (e.g. numeric questionNumber), silently degrading grading data; IdentifiedWord.id == word gives duplicate SwiftUI identities for repeated words in a passage
- Vestigial duplicate `import Ollama` at the bottom of AIModelSettings.swift; KeychainHelper.set failures are ignored by setAPIKey (a Keychain error silently loses the key on next launch while the in-memory mirror shows it saved)
- No token/cost usage tracking or per-run spend estimate for batch analysis over thousands of words; no pause/resume or retry-failed-only affordance

**Improvement opportunities noted by the mapper:**
- Fix Regenerate: add a bypassCache/force parameter to generateExplanationWithProvider (and evict the in-memory key) so the button actually re-calls the model
- Fix AIExplainButton and the unavailable empty-state to use AIModelSettings.shared.isAnyProviderAvailable instead of the Apple/Ollama-only check
- Extract a ProviderClient protocol (complete(system:user:images:jsonMode:maxTokens:)) with Apple/Ollama/Cloud conformances to collapse the five duplicated provider switches into one router
- Add streaming to CloudAIService (SSE for OpenAI/Anthropic) and wire chatStream into the explanation view for progressive rendering — biggest perceived-latency win
- Add exponential-backoff retry on HTTP 429/500-503 in CloudAIService.chat, and have BatchExplanationController pause-and-resume on repeated rate-limit failures instead of failing the rest of the queue
- Downscale/JPEG-recompress images (e.g. max 1568px long edge) before base64 encoding in gradeWorkbook/cleanupRecognizedText
- Unify the two explanation caches: make WordExplanationCacheStore the single source of truth and drop the service-level dictionary (or make it a thin read-through of the store)
- Allow empty API keys for localhost base URLs (Quotio/self-hosted proxies) and add a per-provider or per-model 'supports vision' user override so proxy-routed vision models can grade workbooks
- Replace first-{/last-} extraction with a real balanced-brace scanner (string-aware, like repairJSON) and consider OpenAI json_schema / Anthropic tool-use for schema-enforced outputs where available
- Persist WordIdentificationService's cache (same file-store pattern) and distinguish 'failed reconstruction' (retryable) from a genuine empty result instead of caching failure
- Flush WordExplanationCacheStore on scenePhase.background/willTerminate to close the 10s data-loss window
- Make provider fallback explicit: show a banner/toast when effectiveProvider differs from the selected provider, or make fallback opt-in
- Honor settings.contextLength in Ollama structured generation and expose per-feature maxTokens instead of scattered literals (2048/4096/8192)
- Add batch niceties: retry-failed-only button, ETA from rolling per-word latency, and estimated token cost before starting
- Record and display token usage per request (both wire formats return usage blocks that are currently discarded)
- Remove the duplicate trailing `import Ollama` in AIModelSettings.swift and surface KeychainHelper.set failures to the user in setAPIKey

### intents-project

**Weaknesses found:**
- SavedTermEntity/PhraseEntity fields are plain lets with no @Property wrappers, so Shortcuts users receive an opaque entity and cannot extract chinese/pinyin/definition/category in their own workflows — the biggest real-user pain in the subsystem
- saveChinesePhrasesToVocabulary launches an unstructured fire-and-forget Task from the end of perform(); the intent returns immediately and the process can be suspended before batch translation finishes, silently losing vocabulary saves the user toggled on
- 'Use Apple Intelligence' parameter and fallback dialog are misleading: aiIsAvailable() matches any provider (Ollama, cloud keys), not just Apple Intelligence
- On iOS 17-25 with no AI provider configured, every translate intent fails with generic 'Unable to translate' — no guidance to configure a provider (ShortcutHelpers.swift:70-74)
- ShortcutPhraseCategory resolves categories by English display-name string equality ('Greetings' etc., GetRandomPhraseIntent.swift:70-83); renaming/localizing a category silently degrades to the 你好 fallback
- TranslateScreenshotsIntent hands data via mutable ScreenshotTranslationStore.shared.pendingImages global — two rapid invocations race; iOS and macOS branches are ~40 duplicated lines differing only in UIImage/NSImage
- TranslateClipboardIntent reads UIPasteboard from an intent context, triggering the iOS paste-permission prompt each run with no ProgressReportingIntent/ForegroundContinuableIntent mitigation
- GetLearningStatsIntent returns one preformatted String — no numeric fields for Shortcuts logic, no snippet view, no dialog for voice-first Siri use
- SaveVocabularyTermIntent never checks SavedTermsStore.contains(), so repeated runs create duplicate terms (the phrase-segmentation path dedupes, the direct path doesn't); it also near-duplicates ShortcutHelpers.saveToVocabularyIfNeeded with divergent error behavior (throws vs silent return)
- Siri phrases are English-only and none embed parameters (no \(\.$category)-style phrases), so updateAppShortcutParameters() calls (made 3x across SwiftMandarinApp/ContentView) are effectively no-ops; 'Find in SwiftMandarin' is too vague to dictate reliably; zh-Hans users get no localized invocation despite knownRegions including zh-Hans
- No platform surfaces beyond the app: no widgets (no streak/word-of-day widget despite having the data), no ControlWidget, no watch app, no share/action extension for translate-from-share-sheet, no Spotlight IndexedEntity; no App Group entitlement exists to enable them later
- Anachronistic build config: SWIFT_VERSION 5.0 (not 6), macOS target 26.2 vs iOS 17.0 asymmetry, and the sandbox entitlements file is applied to all platforms; LookupVocabularyIntent limit parameter is an unbounded raw Int with no inclusiveRange

**Improvement opportunities noted by the mapper:**
- Add @Property(title:) annotations to SavedTermEntity and PhraseEntity so Shortcuts can access chinese/pinyin/definition/partOfSpeech/category fields — small change, large user payoff
- Await the vocabulary-save work inside perform() (or adopt ForegroundContinuableIntent) so saveToVocabulary can't be dropped by process suspension; return the count of terms saved in the dialog
- Rename the AI toggle to 'Use AI Provider' (or resolve the actual provider name from AIModelSettings) and fix the fallback dialog text to match
- Replace ShortcutPhraseCategory's display-name string matching with a stable id or direct enum mapping on PhraseCategory
- Extract the duplicated iOS/macOS image-decoding in TranslateScreenshotsIntent behind a PlatformImage typealias; pass images through the AppRouteStore payload instead of a shared mutable global
- Ship a WidgetKit extension (streak + word-of-the-day + due-review count) — requires adding an App Group and migrating PersistentCodableStore from UserDefaults.standard to the suite; also unlocks an iOS 18 ControlWidget for 'Open Live Scanner'
- Add a share extension or ShareIntent so users can translate selected text/images from any app's share sheet instead of copy-then-run-clipboard-shortcut
- Return structured stats (an AppEntity with numeric @Property fields, or ReturnsValue<Int> variants) plus a dialog from GetLearningStatsIntent; add a SnippetView for rich display
- Localize AppShortcut phrases into zh-Hans and add parameterized phrases (e.g. 'Get a \(\.$category) phrase in SwiftMandarin') so updateAppShortcutParameters() does real work
- Dedupe SaveVocabularyTermIntent through SavedTermsStore.contains() and unify it with ShortcutHelpers.saveToVocabularyIfNeeded
- Surface a settings-aware error (needsToConfigureProvider) on pre-iOS-26 devices pointing users to AI provider setup
- Constrain LookupVocabularyIntent's limit with inclusiveRange and consider requestValue() prompting when query is empty instead of silently returning []

---

*Produced by a 22-agent parallel study (10 subsystem mappers, 10 ideation lenses, 1 synthesis, 1 completeness critic) on 2026-07-07.*
