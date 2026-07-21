# SwiftMandarin implementation plans

## Active slice: Live MiniMax audio catalog and batch audio

**Created (UTC):** 2026-07-20T22:07:52Z

**Branch:** `codex/minimax-audio-catalog-batch`

**Base:** `origin/main` at `4879c53b81d86f8142b26e4a4ba915916a9cd1f9`

The implementation contract, API findings, concurrency boundaries, acceptance scenarios, and planned evidence for this slice are recorded in [`docs/handoff/minimax-audio-catalog-batch/PLANS.md`](docs/handoff/minimax-audio-catalog-batch/PLANS.md). This slice refreshes the live MiniMax voice catalog, presents the latest Speech 2.8 models ahead of the older compatible 2.6/02/01 families, forces the correct MiniMax language boost for Mandarin and English, invalidates ambiguous legacy audio cache identities, and optionally generates persistent MiniMax pronunciation audio during Batch AI Analysis.

The live mainland MiniMax account currently returns 303 system voices: 26 have the standard Mandarin prefix, two documented Mandarin exceptions are recognized explicitly, and 6 are English (28 Mandarin choices total). Its general `/v1/models` response contains no speech models, so production code MUST NOT treat that endpoint as an authoritative speech-model catalog. Models use the current documented T2A catalog, while voices refresh from `/v1/get_voice` and retain the last successful public system catalog for offline settings use.

## Active slice: MiniMax AI Audio and Multimodal translation

**Created (UTC):** 2026-07-20T19:55:55Z

**Branch:** `codex/minimax-ai-audio`

**Base:** `origin/main` at `329ad5fbf59edab83d208b4edb6a4e38b4bdbf47`

The approved implementation contract, architecture, invariants, risks, acceptance checks, and planned evidence for this cross-cutting feature are recorded in [`docs/handoff/minimax-ai-audio/PLANS.md`](docs/handoff/minimax-ai-audio/PLANS.md). The bounded slice adds settings-controlled MiniMax persistent TTS behind the existing global speech router, an exportable generated-audio library, and Apple Speech-backed recording/import transcription plus one-action translation in the renamed Multimodal tab.

MiniMax's current public documentation does not expose a supported general uploaded-audio transcription or audio-translation endpoint. The implementation therefore uses MiniMax only for text-to-speech and composes Apple Speech transcription with the app's existing text-translation pipeline for audio input.

## Active slice: Native vocabulary-detail paging and 2027 UI alignment

**Created (UTC):** 2026-07-13T08:51:49Z

**Branch:** `codex/vocab-detail-swipe-modernization`

**Base:** `main` at `6c3d9aa`

**Approval:** The user explicitly requested implementation. This plan constrains that directive to one verifiable product slice.

### Task brief

The iOS vocabulary detail must let a learner move through the exact filtered and sorted list they opened by swiping left for the next word and right for the previous word. The interaction must feel like native paging, coexist with vertical reading, remain bounded at the first and last item, and expose equivalent controls to VoiceOver, keyboards, pointers, iPad, and Mac users. The affected vocabulary list/detail UI should adopt the system component hierarchy and refined Liquid Glass behavior of the 2027 Apple releases while retaining the app's iOS 17 and macOS 26.2 deployment floors.

The current code is a partial implementation: it installs a high-priority `DragGesture` over a vertical `ScrollView`, filters direction only after the gesture ends, and manually swaps one page. This can preempt vertical scrolling and system gestures, gives no drag-following feedback, and makes the feature hard to discover. The sheet's presentation identity is also the selected term, even though paging changes that identity.

### Success criteria

1. Opening any vocabulary row presents the selected word without introducing a nested app-level navigation stack.
2. A native horizontal page swipe settles on the adjacent item in the current filtered/sorted order; vertical scrolling continues to work normally.
3. Paging cannot move before the first or after the last item, and list/store changes never display a fabricated empty term.
4. Previous/next buttons and a localized position indicator remain available without relying on the gesture; hardware keyboard shortcuts work where supported.
5. Changing pages cancels or isolates term-specific asynchronous state so a translation or copied state from one word cannot appear on another.
6. The vocabulary surfaces use system navigation/toolbars for the Liquid Glass control layer, standard content materials for content, semantic colors, adaptive spacing, Dynamic Type-safe controls, Reduce Motion-aware behavior, and complete VoiceOver labels.
7. The app builds with Xcode 27 for both an iOS Simulator destination and macOS with zero new warnings; the core navigation logic has deterministic regression checks and the user flow is scenario-tested.

### Completed outcome

The slice now uses a stable detail session and a native page-style `TabView` bounded to the previous/current/next terms. Review-driven hardening ensures only the visible page auto-translates, embedded AI explanations do not create nested vertical scrollers, mastery uses native toggle semantics, macOS copy feedback is action-specific, and the affected learner text participates in capped Dynamic Type scaling. Deterministic paging coverage is 18/18, fresh iOS/macOS Xcode 27 builds pass, a fresh iPhone runtime scenario passes, and the 7,000-word stress scenario no longer exhibits the rejected unbounded pager's stall.

### Invariants and interfaces

- `StudyHubView` remains the owner of the iOS `NavigationStack`; `VocabularyView` MUST NOT add another app-level stack.
- Page identity is `SavedTerm.id`, never an array offset. The selected ID MUST either exist in the visible ordered terms or close the presentation safely.
- The detail presentation has a stable session identity. Moving between words MUST NOT dismiss and recreate the modal merely because the selected term changed.
- The pager consumes `filteredTerms` in display order. It MUST NOT silently switch to the full store while a search or sort is active.
- Liquid Glass belongs to controls and navigation. Vocabulary content cards use standard semantic surfaces, not decorative custom glass.
- New Xcode 27-only toolbar behavior MUST be availability-gated; the iOS 17/macOS 26.2 fallback remains fully usable.

### Increment plan

1. Capture baseline source/build evidence and verify current Apple 2027 guidance plus installed SDK signatures.
2. Introduce a stable detail-presentation session and deterministic adjacent-item navigation model.
3. Replace the high-priority manual drag with a native page-style container windowed to previous/current/next, containing independent vertical detail pages.
4. Move paging affordances into system toolbars, simplify crowded vocabulary toolbar actions, and make detail actions adaptive and accessible.
5. Add regression checks for boundaries, visible-order preservation, missing selections, and presentation identity; update English and Simplified Chinese localization entries.
6. Run iOS/macOS builds, scenario interaction and visual checks, diff review, and independent adversarial review. Resolve all Critical/Important findings before commit.
7. Update `handoff.md`, commit only this slice, push the branch, and leave the next prioritized slice explicit.

### Risks and rollback

- **Large vocabulary performance:** thousands of entries make an unbounded page-style `TabView` expensive. Keep only previous/current/next pages in the native page controller and verify it with a 7,000-word synthetic library.
- **Nested gesture conflict:** cross-axis nested scrolling can regress if custom drag recognizers remain. Remove the custom high-priority recognizer and rely on the system pager.
- **Sheet identity churn:** selecting a neighboring term can re-present an item-driven sheet. Use a stable presentation-session item separate from the mutable selected term.
- **SDK beta drift:** Xcode 27 APIs are preliminary. Keep them optional and availability-gated; standard SwiftUI components provide the fallback.
- **Shared store mutation:** mastering or updating a word can refresh `orderedTerms`. Reconcile by ID and dismiss safely if the selected term disappears.

### Planned evidence

- Baseline and final `xcodebuild` logs under `/tmp/SwiftMandarin-vocab-*`.
- Deterministic regression-check output recorded in `handoff.md`.
- iOS Simulator screenshots before/after and a recorded swipe scenario when simulator automation permits it.
- `git diff --check`, localization catalog parse, source review findings, and final clean branch status.
