# LOOP.md — Autonomous Improvement Loop for SwiftMandarin

> **What this document is.** A self-perpetuating specification for an AI coding agent to run *continuously*, one verified increment at a time, driving SwiftMandarin from its current state toward the idealized, ready‑to‑ship **language‑learning companion** described below. It defines the destination (the North Star), the shape of the finished app (features that exist and features that do *not* yet exist), how every piece integrates into one coherent system, the measurable definition of "done," and — most importantly — the **loop protocol** the agent executes and the **prompt it feeds itself** on every cycle until the app is built.
>
> **How to use it.** An agent (or a human orchestrating one) reads this file, reads `feature_list.json` and `handoff.md`, selects the single highest‑value increment, builds it, verifies it end‑to‑end, records the result, and re‑prompts itself. Repeat until the **Ready‑to‑Ship checklist** is fully green. This file is the *contract*; `feature_list.json` is the *work‑list*; `handoff.md` is the *narrative log*.

---

## 0. TL;DR — The Loop in One Breath

```
LOAD  LOOP.md + feature_list.json + handoff.md
  └─▶ ORIENT   (what is broken? what is closest to shipping? what is highest value?)
      └─▶ SELECT   one increment via the Selection Function
          └─▶ DESIGN   the smallest slice that fully delivers it
              └─▶ IMPLEMENT   (respect the Invariants; never break a build)
                  └─▶ VERIFY   (build → runtime → scenario → visual)
                      └─▶ INTEGRATE + RECORD   (feature_list ✓, handoff.md, commit)
                          └─▶ IDEATE (periodically)   (append net‑new features)
                              └─▶ RE‑PROMPT self  ──▶ (loop)
STOP when the Ready‑to‑Ship checklist is 100% green and no P0/P1 remain.
```

The loop is **evidence‑driven** (a passing build proves compilation, not correctness — every increment is exercised), **incremental** (one feature from failing to passing per cycle, always shippable at the boundary), and **generative** (it keeps inventing and appending new high‑value features so the backlog never runs dry before the vision is met).

---

## 1. North Star — The Idealized End State

**SwiftMandarin is the single companion a learner opens every day to acquire the *other* language — Mandarin for English speakers, English for Mandarin speakers — by turning everything they encounter into personalized, spaced, multi‑modal practice, and by producing input and feedback that meet them exactly at their level.**

Three sentences that must remain true of the finished app:

1. **Capture anything, learn from everything.** Any text the learner meets — typed, photographed, screenshotted, pasted, spoken, read, or chatted — can become a saved item and a scheduled review in one tap, with a tutor‑grade explanation attached.
2. **One brain schedules it all.** A single spaced‑repetition + knowledge‑graph engine models what the learner knows (characters → words → grammar → collocations → pronunciation) and decides the next best action across *all* activities, not just flashcards.
3. **Input and output, both scored.** The app both *feeds* comprehensible input tuned to the learner's level and *listens* to their production (speaking, writing, typing) and scores it, converting mistakes back into targeted practice.

Everything below serves these three sentences. If a proposed feature does not advance capture → schedule → practice → produce → reflect, it is polish, not a pillar.

---

## 2. First‑Principles Model — What a Language Companion *Is*

Strip away the current screens and a language‑acquisition tool is a single closed loop run by the learner, thousands of times:

```
        ┌───────────────────────────────────────────────────────────┐
        │                     THE LEARNER'S LOOP                      │
        │                                                             │
   (1) ENCOUNTER ─▶ (2) UNDERSTAND ─▶ (3) SAVE ─▶ (4) SCHEDULE       │
        │  a new word/                explain it   into one SRS +     │
        │  phrase/sentence            (tutor)      knowledge graph    │
        │                                              │              │
        │                                              ▼              │
   (7) REFLECT ◀─ (6) PRODUCE ◀─────────────── (5) STUDY             │
        stats,        speak / write /            recall it via        │
        error model,  converse — and be          the right modality   │
        forecast      *scored*, mistakes ─▶ back to (3)               │
        │                                                             │
        └──▶ the app then SERVES the next best input ──▶ (1) again    │
        └───────────────────────────────────────────────────────────┘
```

The app's job is to make each arrow **frictionless, personalized, and measured**. The current codebase implements most *nodes* as separate screens; the idealized app implements the *arrows* — the integrations between them — so the whole thing behaves as one loop rather than a toolbox of features. **The primary engineering theme of this LOOP is integration, not just addition.**

---

## 3. The Integrated Architecture — How the Pieces Fit Together

### 3.1 What exists today (ground truth, 90 Swift files, ~33k LOC)

| Layer | Components (real files) | Role in the loop |
|---|---|---|
| **Capture** | `TranslateView`, `PhotoTranslateView` + `PhotoTextRecognitionService`, `ScreenshotStitchingService` + `TranslatedScreenshotOverlayView`, `ClipboardService`, `CameraScannerView` | Node (1)/(2): bring text in, translate it |
| **Understand** | `CloudAIService`, `OllamaService`, `AIWordExplanationService`, `WordIdentificationService`, `WordExplanationCacheStore`, `ChineseTextAnalyzer`, `EnglishTextAnalyzer`, `PinyinConverter`, `RubyTextView`/`EnglishRubyTextView`, `GrammarPoint` | Node (2): segment, gloss, explain, romanize |
| **Save** | `SavedTermsStore`/`SavedTerm`, `PhrasesView`, `TranslationHistoryStore`, `VocabularyImportExportService` | Node (3): persist items |
| **Schedule + Study** | `LearningCard` + `LearningProgressStore`, `SRSEngine` (FSRS‑4.5), `LearnView`, `PracticeStore`, `QuizView`, `DictationView`, `TonePairDrillView`, `PracticeHubView`, `StudyHubView` | Nodes (4)/(5): FSRS scheduling + recall drills |
| **Produce** | `ConversationView` + `ConversationService`/`ConversationStore`, `SpeechRecognitionService`, `SpeechService`, `WorkbookGradingView` + vision grading | Node (6): output + (partial) scoring |
| **Read (input)** | `ReaderView`, `ReaderSessionView`, `ReaderStore`, `StoryGenerationService` | Serves input at level (known‑% coverage) |
| **Reflect** | `StatsView`, `LearningActivity`/`LearningActivityStore`, `HistoryTabView`, tone‑confusion matrix | Node (7): metrics + error signal |
| **Shell / cross‑cutting** | `ContentView` (iOS tabs + macOS sidebar), `HomeView` (daily dashboard), `AppRouteStore`, `LocalizationManager` (runtime bilingual), `AppPreferences`, `AIModelSettings`, `KeychainHelper`, `DesignSystem`, `CompatModifiers` (Liquid Glass), `Intents/`, `MenuBarTranslateView` | Orchestration, routing, theming, platform reach |

### 3.2 The integration gaps to close (the through‑lines)

The finished app connects these islands. Priority integrations, each a first‑class LOOP objective:

1. **Unify scheduling into one engine.** Today `LearningProgressStore`/`SRSEngine` schedules flashcards; `PracticeStore` schedules drills separately; Reader and Conversation don't feed the scheduler at all. **Ideal:** every exposure — reading a word in `ReaderView`, using it correctly in `ConversationView`, answering it in any drill — is a review event against one item‑level memory model. Reading *is* reviewing.
2. **One capture funnel.** Every text surface (translate, photo, screenshot, clipboard, reader tap, conversation message) exposes the *same* "save + explain + schedule" action, producing the same rich item. No dead‑end text anywhere in the app.
3. **One item model, many item types.** Generalize the SRS item from "vocabulary card" to a `StudyItem` protocol covering **words, characters, sentences (cloze), grammar points, collocations, and pronunciation targets** — all scheduled by the same engine, all surfaced by the same Home "next best action."
4. **One error model.** Generalize the tone‑confusion matrix into a **personal error model** (which characters/tones/grammar the learner confuses) that steers drill selection, Reader difficulty, and Conversation scenarios.
5. **Home as the daily orchestrator.** `HomeView` should compute and present the single next best action from the unified engine (due reviews, an i+1 reading, a scored conversation, a weak‑spot drill), not just static cards.

### 3.3 The data spine

```
Capture surfaces ─▶  StudyItem (word|char|sentence|grammar|collocation|pronunciation)
                         │           ▲
                         ▼           │ review events (from EVERY activity)
                 KnowledgeGraph ─▶ UnifiedScheduler (FSRS) ─▶ NextBestAction
                         │                                        │
                         ▼                                        ▼
                 PersonalErrorModel ─────────────────────▶ Home / Reader / Practice / Conversation
```

Persistence stays local‑first (`PersistentCodableStore`) with an added **CloudKit sync** layer so the graph follows the learner across iPhone, iPad, Mac, and Watch.

---

## 4. The Idealized Feature Set

Features are grouped by pillar. **[EXISTS]** = present today (improve/integrate). **[NEW]** = does not exist yet; invent and build it. Each carries a one‑line rationale tied to the learner's loop. These seed `feature_list.json`; the loop also *appends* more during the IDEATE step.

### 4.1 Capture & Understand
- **[EXISTS] Universal "Save + Explain" action** on every text surface — unify into one component; guarantee no dead‑end text.
- **[EXISTS] Tutor‑grade word cards** — expand `AIWordExplanationService` output to always include: character breakdown (radicals + mnemonics), pinyin with tone colors, part of speech, register/formality, 2–3 example sentences at the learner's level, common mistakes, measure words, frequency rank, HSK/CEFR level, synonyms/antonyms.
- **[NEW] Sentence mining with automatic cloze.** Turn any captured sentence into a cloze‑deletion card (hide the target word); the sentence context becomes the review. This is the highest‑leverage way to convert real encounters into practice.
- **[NEW] Live AR translate.** Point the camera and see the world (menus, signs, subtitles) translated in place with tap‑to‑save; evolve the existing screenshot overlay into a live camera overlay.
- **[NEW] Document & subtitle import.** Drop in an article, ePub, PDF, or `.srt`; it becomes a graded Reader text with per‑word known‑% coverage and one‑tap mining.

### 4.2 The Unified Brain (Schedule + Model)
- **[NEW] `StudyItem` protocol + unified scheduler.** One FSRS engine over words, characters, sentences, grammar, collocations, and pronunciation targets.
- **[NEW] Knowledge graph.** Characters compose words; words fill grammar frames; items link by radical, semantic field, and confusion. Drives "learn 好 unlocks 你好, 好吃, …" and prerequisite ordering.
- **[NEW] Cross‑activity review credit.** Reading, conversing, and quizzing all emit review events into the scheduler. Reading is reviewing.
- **[EXISTS] Personal error model.** Generalize the tone‑confusion matrix to all item types; expose "your weak spots" and auto‑generate drills for them.
- **[NEW] Review forecast + workload smoothing.** A calendar of upcoming due load; smooth spikes so daily effort stays humane.

### 4.3 Study & Recall (input‑side practice)
- **[EXISTS] FSRS flashcards** (`LearnView`) — keep; feed from vocabulary by default.
- **[EXISTS] Quiz / Dictation / Tone drills** — draw from the learner's own vocabulary; tone drill shows the actual word in each candidate tone (done).
- **[NEW] Handwriting / stroke‑order practice.** A canvas that validates stroke order and shape, with radical decomposition and mnemonics — closes the *writing* modality.
- **[NEW] Cloze & sentence‑construction drills.** Rebuild a scrambled sentence; fill the blank; choose the right measure word — grammar practice, not just vocab.
- **[NEW] Grammar SRS.** `GrammarPoint` items scheduled like words, each with pattern, examples, and a mini‑drill.

### 4.4 Produce & Be Scored (output‑side practice)
- **[NEW] Pronunciation scoring & shadowing.** Record the learner; visualize their pitch contour against the native tone contour; score per‑syllable tone accuracy; loop until close. Uses `SpeechRecognitionService` + a new tone‑contour analyzer.
- **[EXISTS] AI conversation** (`ConversationView`) — add **scenario role‑plays** ("order food," "job interview") and **turn‑level scoring** (vocabulary reach, grammar, tone, fluency), surfacing corrections as new cards.
- **[NEW] Guided writing / composition coach.** Prompt the learner to write; the AI grades, corrects, and rewrites at a higher register, mining errors into cards.
- **[EXISTS] Workbook grading** — integrate results into the error model and scheduler.

### 4.5 Serve Input (comprehensible input at level)
- **[EXISTS] Graded Reader + story generation** — keep; feed difficulty from the knowledge graph (known‑% target ≈ i+1).
- **[NEW] "For You" input feed.** An endless, personalized stream of micro‑content (sentences, dialogues, short stories, culture notes) generated at the learner's exact level from their known words + weak spots; every item is tap‑to‑save. This is the daily‑engagement engine.
- **[NEW] Curriculum / goal planner.** Set a goal (HSK 4, "travel to Chengdu," "read 活着"); the app generates a path, tracks mastery toward it, and biases the feed and scheduler.

### 4.6 Reflect
- **[EXISTS] Stats** — evolve into a mastery dashboard: words by state, retention rate, tone accuracy over time, streak, forecast, goal progress, weak‑spot list.
- **[NEW] Weekly review digest.** A generated summary: what you learned, where you slipped, what's next.
- **[NEW] Milestones & certificates.** Celebrate 100/500/1000 mastered items, HSK band completion.

### 4.7 Reach, Platform & Delight (cross‑cutting, ship‑blockers where noted)
- **[NEW] CloudKit sync** across devices *(ship‑relevant once multi‑device is promised)*.
- **[NEW] Widgets + Live Activities + Lock Screen** — word of the day, due count, streak, review CTA.
- **[NEW] Apple Watch app** — flashcards and tone drills on the wrist.
- **[EXISTS] App Intents / Siri / Shortcuts** (`Intents/`) — deepen: "quiz me," "translate this," "what's due," "add word."
- **[EXISTS] Menu‑bar translate** (`MenuBarTranslateView`) — keep as a fast‑capture surface.
- **[EXISTS] On‑device / offline AI** (`OllamaService`) — add Apple Foundation Models + on‑device Speech for a fully offline path.
- **[EXISTS] Runtime bilingual UI** (`LocalizationManager`) — maintain **en ⇄ zh‑Hans parity on every new string** (a hard Invariant).
- **[EXISTS] Liquid Glass design system** — keep both platforms coherent; grow `DesignSystem` rather than one‑off styling.
- **[NEW] Accessibility pass** — Dynamic Type, VoiceOver labels, Reduce Motion, contrast — as a standing quality gate, not a feature.
- **[NEW] Onboarding placement test** — a short adaptive assessment that seeds the knowledge graph so day one is already personalized.

---

## 5. Definition of "Ready to Ship" — the Loop's Termination Condition

The loop **stops** only when *all* of the following hold. This is the objective function; keep it visible.

**A. Correctness & stability**
- [ ] Both platforms **BUILD SUCCEEDED with 0 warnings** (macOS + iOS Simulator).
- [ ] Every feature in `feature_list.json` has `passes: true` with captured evidence.
- [ ] Zero open **P0/P1** issues. No placeholders, no `TODO` in shipping paths, no dead code.
- [ ] No feature regressions: previously‑passing features still pass (re‑verified).

**B. The three North‑Star sentences are literally true**
- [ ] Any text surface → save + explain + schedule in one action (capture funnel closed).
- [ ] One scheduler drives Home's "next best action" across ≥3 activity types (flashcard, reading, conversation/drill).
- [ ] At least one *scored production* path exists (pronunciation or conversation scoring) that mines mistakes back into cards.

**C. Experience quality**
- [ ] Home surfaces a genuinely useful next action for a new user *and* a 7,000‑word power user.
- [ ] Design is coherent (one design system), cards are visible on macOS, content is width‑constrained on wide windows, tone colors correct everywhere.
- [ ] Accessibility: Dynamic Type + VoiceOver + Reduce Motion verified on core flows.
- [ ] Localization parity: no user‑visible string without an en + zh‑Hans entry; placeholders validated.

**D. Reach (scope‑gated — only the ones the product promises)**
- [ ] Widgets/Intents/offline/sync/Watch: each either shipped *or* explicitly deferred with rationale in `handoff.md`.

**E. Trust**
- [ ] Secrets only in Keychain; no keys in code or logs. Inputs validated at trust boundaries. Privacy copy accurate.

> When A–E are all checked and `feature_list.json` is fully green, the loop emits a **Release Candidate** summary and halts. Until then, it keeps looping.

---

## 6. The Agentic Loop — Loop Engineering

### 6.1 Design principles (why the loop is shaped this way)

1. **Externalized memory over internal memory.** Assume the agent forgets everything between cycles. State lives in files: `LOOP.md` (spec), `feature_list.json` (backlog + pass flags), `handoff.md` (narrative + evidence), git history. Never rely on conversation memory to survive a cycle.
2. **One increment per cycle; always shippable at the seam.** Take exactly one feature/bug from failing → passing, end‑to‑end, before touching anything else. The repo builds and runs at every cycle boundary.
3. **Invariants are sacred.** A fixed set of guardrails (§6.2) must hold after *every* cycle. Breaking one is a P0 that pre‑empts all feature work.
4. **Evidence beats optimism.** A green build is necessary, not sufficient. Every increment climbs the Verification Ladder (§6.5). "Done" requires an artifact.
5. **Convergent selection, divergent ideation.** Most cycles *converge* (finish backlog items). Periodically the loop *diverges* (IDEATE) to append net‑new features — so the app keeps growing toward the North Star instead of stalling at a thin MVP. Ideation is bounded so scope can't explode past the vision.
6. **Smallest reversible step first.** Prefer changes that are easy to review and revert. Order work by risk and dependency: fix breakage → close regressions → high‑value integration → new features → polish.
7. **No silent truncation.** If a cycle defers, caps, or skips, it says so in `handoff.md`. Silence reads as "done" when it isn't.

### 6.2 Invariants (must hold after every cycle — verify before recording done)

- **Build:** both platforms compile; **0 warnings**. Broken build ⇒ immediate P0, fix before anything else.
- **Xcode project:** the target uses a **file‑system‑synchronized group** — *never* hand‑edit `project.pbxproj` to add files; new `.swift` files are picked up automatically. (`grep -c "in Sources" *.pbxproj` must stay at its expected baseline.)
- **Concurrency:** respect `-default-isolation=MainActor` / SWIFT_APPROACHABLE_CONCURRENCY; a bare `nonisolated async` does *not* hop off main — use `Task.detached` for real off‑main work; keep stores `@Observable @MainActor`.
- **Platforms:** every feature works on **iOS 17+ and macOS**; gate newer APIs (iOS 26 Liquid Glass) through `CompatModifiers`.
- **Bidirectional bilingual:** every feature works for *both* directions (English‑native learning Mandarin, and Mandarin‑native learning English) via `LocalizationManager.learningIsChinese`.
- **Localization parity:** every new user‑visible string added to `Localizable.xcstrings` with **en + zh‑Hans**, placeholders validated; never mutate existing keys carelessly.
- **Design coherence:** reuse `DesignSystem` (`SMCard`, `smCardSurface`, `SMTheme`, tone colors) — no bespoke one‑off card/color styling.
- **Data safety:** persistence changes are backward‑compatible (tolerant decoders); never lose user vocabulary/history. Secrets in Keychain only.
- **No regressions:** a change that makes a `passes: true` feature fail is not "done" — it's a new bug to fix in the same cycle.

### 6.3 The externalized work‑list — `feature_list.json`

On its **first run**, if `feature_list.json` is absent, the loop bootstraps it from §4 (every `[EXISTS]`/`[NEW]` item becomes an entry with `passes: false`). Schema per entry:

```json
{
  "id": "feature_unified_scheduler",
  "pillar": "brain",
  "priority": "P1",
  "status_note": "one FSRS engine over all StudyItem types",
  "steps": [
    "Introduce StudyItem protocol (word|char|sentence|grammar|collocation|pronunciation)",
    "Route LearningProgressStore + PracticeStore through one scheduler",
    "Emit review events from Reader and Conversation",
    "Home 'next best action' reads from the unified scheduler",
    "Verify: read a word in Reader → its due date advances"
  ],
  "evidence": null,
  "passes": false
}
```

Rules: only flip `passes` to `true` with captured evidence; never delete or water down entries to make progress look better; add new entries freely during IDEATE.

### 6.4 The iteration protocol (one cycle)

1. **ORIENT.** Read `handoff.md` (last state, known breakage), `git log --oneline -15`, and `feature_list.json`. Confirm the Invariants still hold (quick build if in doubt). If anything is broken, the selected increment *is* the fix.
2. **SELECT.** Apply the Selection Function (§6.6) to choose exactly one increment.
3. **DESIGN.** Specify the smallest slice that *fully* delivers it: files to touch, data/model changes, UI, the invariants it must preserve, and the concrete acceptance check + evidence artifact.
4. **IMPLEMENT.** Production‑grade, minimal surface area, explicit error handling, reuse `DesignSystem`. Keep the project building throughout.
5. **VERIFY.** Climb the Verification Ladder (§6.5). Reproduce the user scenario; capture before/after evidence.
6. **INTEGRATE + RECORD.** Flip `passes: true` with evidence in `feature_list.json`; append a dated entry to `handoff.md` (what changed, why, checks, artifacts); `git commit` one coherent change with a descriptive message. Push if the workflow calls for it.
7. **IDEATE (every N cycles, or when a pillar completes).** Run the Completeness Critic (§6.7): what is missing to reach the North Star? Append new `feature_list.json` entries. Bounded — a handful of high‑value ideas, not a dump.
8. **RE‑PROMPT.** Emit the self‑reprompt (§7) and begin the next cycle.

### 6.5 Verification Ladder (climb as high as the change warrants)

1. **Compile** — both platforms build, 0 warnings.
2. **Runtime launch** — app boots on the target platform without crash (macOS is the reliable runtime surface here; the iOS Simulator shares the same view/model code).
3. **Scenario** — drive the actual user flow the feature claims (open the screen, tap through, observe the externally visible behavior matches the acceptance check). Prefer the power‑user data set (thousands of saved words) so scale bugs surface.
4. **Visual** — screenshot the before/after for any UI change; confirm design‑system coherence, tone colors, macOS card visibility, width constraints, light/dark.

A feature that only reaches rung 1 is **not** done; note the ceiling reached and why in `handoff.md`.

### 6.6 Selection Function — pick the next increment

Score each candidate and take the max; break ties by smaller blast radius:

```
score = (northStarAlignment × userImpact × confidence) / effort
```

with a strict **priority gate** applied first:

1. **Broken build / failing Invariant** → always first (P0).
2. **Regression** (a `passes:true` feature now failing) → next.
3. **Integration through‑lines** (§3.2) → weighted heavily; they multiply the value of everything else.
4. **High‑impact NEW features** aligned to the three North‑Star sentences.
5. **Polish / accessibility / localization debt.**
6. **Speculative ideas** only after the above are drained.

Prefer increments that are (a) independently verifiable, (b) low‑risk/reversible, (c) unblock other items. Avoid large speculative refactors with no single feature goal.

### 6.7 Completeness Critic (the IDEATE step's engine)

Periodically ask, from first principles, *not* constrained by the current codebase:

- Which arrow of the learner's loop (§2) is still high‑friction or unmeasured?
- What would a world‑class tutor do that the app can't yet?
- What input modality (speaking, writing, listening, reading) is under‑served?
- What does a power user with 7,000 words lack that a beginner doesn't?
- What integration would make two existing features worth more together than apart?
- What would make the learner open the app *tomorrow*?

Turn the strongest answers into `feature_list.json` entries. This is the mechanism by which the loop "keeps thinking of new features," bounded so the backlog trends toward the North Star rather than sprawling.

### 6.8 Stop, escalate, and safety

- **Stop (success):** Ready‑to‑Ship (§5) fully green ⇒ emit a Release Candidate summary in `handoff.md` and halt.
- **Escalate (blocked):** if an increment needs a human decision (product scope, credentials, an irreversible action, a paid API), record the question in `handoff.md`, pick the next unblocked increment, and continue — don't stall the loop.
- **Guard against thrash:** if the same increment fails verification twice, shrink its scope or swap to a smaller adjacent win; never loop on an identical failing action.
- **Never fake progress:** do not flip `passes` without evidence; do not delete/soften features to "finish."

---

## 7. The Self‑Reprompt — literal prompt the loop feeds itself each cycle

Paste this to start the loop; the agent re‑emits it (updated) at the end of every cycle. It is intentionally self‑contained so a fresh‑context agent can resume from files alone.

```
You are the autonomous build loop for SwiftMandarin. Work one verified increment, then re-prompt yourself.

CONTEXT (read these first, every cycle):
  1. LOOP.md            — the spec: North Star, integrated architecture, feature set,
                          Ready-to-Ship checklist, Invariants, and this loop protocol.
  2. feature_list.json  — the backlog with pass flags. If missing, bootstrap it from
                          LOOP.md §4 (every item → passes:false).
  3. handoff.md         — the running narrative: last state, known breakage, evidence.
  4. git log --oneline -15 — recent history.

DO, THIS CYCLE:
  1. ORIENT. Summarize current state in 3 lines. Confirm the Invariants (LOOP.md §6.2)
     hold; if any is broken, that fix IS this cycle's increment.
  2. SELECT one increment via the Selection Function (LOOP.md §6.6). State it and why.
  3. DESIGN the smallest slice that fully delivers it: files, model/UI changes, the
     acceptance check, and the evidence artifact you will capture.
  4. IMPLEMENT it. Respect every Invariant. Keep both platforms building with 0 warnings.
     Reuse DesignSystem. Add en+zh-Hans for every new string. Never edit project.pbxproj
     to add files. Never break a currently-passing feature.
  5. VERIFY up the ladder (LOOP.md §6.5): build → launch → drive the real user scenario
     (use the power-user data set) → screenshot before/after for UI. Capture evidence.
  6. RECORD: flip the item to passes:true WITH evidence in feature_list.json; append a
     dated entry to handoff.md (what/why/checks/artifacts); commit one coherent change.
  7. Every few cycles, or when a pillar completes, run the Completeness Critic
     (LOOP.md §6.7) and append new high-value features to feature_list.json.
  8. Check the Ready-to-Ship checklist (LOOP.md §5). If 100% green with no P0/P1, emit a
     Release Candidate summary and STOP. Otherwise, re-emit this prompt and loop.

RULES: one increment per cycle; always shippable at the boundary; evidence beats
optimism; externalize all state to files; escalate blockers in handoff.md and keep going;
never fake progress. Think from first principles about features that would help the learner
even if they don't exist yet — but finish and verify one thing before starting the next.
```

### 7.1 Running it in practice

- **Manual / supervised:** feed the prompt, review each cycle's commit + evidence, feed it again.
- **Timed loop:** schedule the prompt on an interval (e.g. a recurring `/loop`) so it self‑paces cycles; each firing resumes from files.
- **Session harness:** treat each cycle as one "shift" — bearings from `handoff.md` + `git log`, one feature failing→passing, clean exit (builds, tests, committed), notes for the next shift. `feature_list.json` + `handoff.md` are the cross‑session memory.

---

## 8. Seed Backlog (initial `feature_list.json` contents, abbreviated)

The loop expands this on first run. Ordered by the Selection Function's default gate.

**Integration through‑lines (do first — they compound):**
1. `feature_universal_capture_action` — one "save + explain + schedule" action on every text surface (P1).
2. `feature_study_item_protocol` — generalize the SRS item beyond vocabulary (P1).
3. `feature_unified_scheduler` — one FSRS engine over all item types; cross‑activity review credit (P1).
4. `feature_home_next_best_action` — Home computes the single best next action from the unified engine (P1).
5. `feature_personal_error_model` — generalize the tone‑confusion matrix to all item types (P2).

**High‑value new pillars:**
6. `feature_pronunciation_scoring` — record → pitch contour vs native → per‑tone score → shadow loop (P1).
7. `feature_sentence_mining_cloze` — any sentence → automatic cloze card (P1).
8. `feature_for_you_feed` — endless personalized i+1 micro‑content, tap‑to‑save (P2).
9. `feature_handwriting_practice` — stroke‑order canvas + radical breakdown (P2).
10. `feature_grammar_srs` — schedule `GrammarPoint` items with mini‑drills (P2).
11. `feature_conversation_scoring` — scenario role‑plays + turn‑level scoring → mistakes to cards (P2).
12. `feature_curriculum_planner` — goal → generated path → mastery tracking (P2).
13. `feature_writing_coach` — guided composition with AI grading + error mining (P3).

**Reach & platform (scope‑gate before building):**
14. `feature_cloudkit_sync` (P2 if multi‑device promised) · 15. `feature_widgets_live_activities` (P2) · 16. `feature_watch_app` (P3) · 17. `feature_deep_app_intents` (P2) · 18. `feature_offline_foundation_models` (P3).

**Standing quality gates (re‑verified continuously, not "finished"):**
19. `gate_zero_warnings_both_platforms` · 20. `gate_localization_parity` · 21. `gate_accessibility` · 22. `gate_design_coherence` · 23. `gate_no_regressions`.

**Recently shipped (keep green):** Home hero redesign + visible macOS cards; tone drill renders the real word per tone; flashcards/practice default to the learner's vocabulary. See `handoff.md` Iteration 18 and `RECOMMENDATIONS.md` / `CODEX_RECOMMENDATIONS.md` for the full audit these draw from.

---

## 9. Relationship to the other docs

- **`LOOP.md` (this file)** — the *destination and the loop*: where the app is going and how the agent walks there autonomously.
- **`RECOMMENDATIONS.md`** — the exhaustive first‑principles improvement catalog (feeds the backlog).
- **`CODEX_RECOMMENDATIONS.md`** — the independent audit (defects/verification, feeds P0–P2 entries).
- **`handoff.md`** — the *journal*: per‑cycle narrative, decisions, and evidence (the loop's working memory).
- **`feature_list.json`** — the *checklist*: the machine‑readable backlog with pass flags (the loop's task queue).

> The loop is finished when a learner can open SwiftMandarin, capture anything they meet, trust one brain to schedule it, practice it in every modality, produce language and be corrected, and watch a clear picture of their growing mastery — on every Apple device, in either direction, online or off. Until then: **orient, select, build, verify, record, re‑prompt.**
