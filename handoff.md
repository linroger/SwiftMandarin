# Handoff.md - SwiftMandarin iOS Redesign

**Last Updated (UTC):** 2026-02-11T12:00:00Z
**Status:** In Progress
**Current Focus:** Testing and Validation Phase

## 1) Request & Context

- **User's request:** Rebuild the MandarinKit app as SwiftMandarin - a clean multiplatform Mandarin-English translation app with focus on iOS 26 and iPadOS 26 redesign.

- **Key problems identified in previous version:**
  1. iPhone UI doesn't take up the whole screen - black bars on top/bottom
  2. Massive waste of space for title/settings area
  3. Not native-feeling on iOS
  4. Cross-platform code created messy conditional compilation

- **Target devices:**
  - Primary: iPhone 14 Pro (iOS 26)
  - Secondary: iPad Pro M4 13 inch (iPadOS 26)
  - Tertiary: macOS 26

- **Operational constraints:**
  - Single multiplatform target
  - iOS 26+ / iPadOS 26+ / macOS 26+ minimum deployment
  - Must use Apple's native Translation Framework
  - Must follow Apple Human Interface Guidelines (WWDC 2025)
  - Must adopt Liquid Glass design system

## 2) Requirements → Acceptance Checks (Traceable)

| Requirement | Acceptance Check | Expected Outcome | Evidence |
|-------------|------------------|------------------|----------|
| R1: Full-screen UI on iPhone | Launch on iPhone 14 Pro | Content fills entire screen, no black bars | Pending |
| R2: Compact, space-efficient translate view | Measure UI element sizes | No wasted space on title/settings | Pending |
| R3: Native iOS feel | Compare with Apple apps | Tab bar, gestures, interactions feel native | Pending |
| R4: Liquid Glass effects | Enable on iOS 26 | Glass effects render on controls, tab bar | Code complete |
| R5: Translation works | Translate "Hello" EN→ZH | Returns "你好" with pinyin | Pending runtime test |
| R6: Tappable Chinese words | Tap word in output | Shows popover with pinyin, definition | Code complete |
| R7: Vocabulary saving | Save term from popover | Term appears in Vocabulary tab | Code complete |
| R8: Flashcard learning | Start learning session | Cards display, ratings work | Code complete |
| R9: iPad sidebar/tab adaptation | Run on iPad | sidebarAdaptable shows sidebar in landscape | Code complete |

## 3) Plan & Decomposition

### Critical Path Narrative
Start with core services and models (shared across platforms), then build iOS-first UI that maximizes screen usage. The iPhone is the primary target - if it looks great on iPhone, iPad and Mac adaptations are simpler.

### Architecture Decisions

**Navigation Pattern:**
- iOS: `TabView` with `.tabViewStyle(.sidebarAdaptable)` 
  - iPhone: Bottom tab bar (5 tabs max)
  - iPad landscape: Sidebar that morphs from floating tab bar
  - iPad portrait: Floating tab bar at top
- macOS: `NavigationSplitView` with sidebar

**Tab Structure (iOS):**
1. **Translate** - Primary function, default tab
2. **Vocabulary** - Saved terms
3. **Learn** - Flashcards with spaced repetition
4. **Phrases** - Quick phrase collections
5. **More** - History, Statistics, Settings

**Key iOS 26 Design Principles (from HIG research):**
1. **Liquid Glass** - Standard components adopt automatically; use sparingly on custom views
2. **Full-screen content** - Content should extend to edges with proper safe area handling
3. **Tab bar at bottom** - Quick access to 5 key areas
4. **No navigation bar titles eating space** - Use inline/large title judiciously
5. **Scroll edge effects** - Content scrolling under controls gets blur treatment

## 4) To-Do & Progress Ledger

### Completed Tasks
- [x] Read MandarinKit.md codebase documentation (12,627 lines) — completed
- [x] Research Apple HIG, Liquid Glass, TabView sidebarAdaptable — completed
- [x] Explore current SwiftMandarin project — completed; clean template
- [x] Create Models folder with SavedTerm, LearningCard, TranslationHistory, TranslationDirection — **completed**
- [x] Create Services folder with PinyinConverter, ChineseTextAnalyzer, SpeechService, ClipboardService — **completed**
- [x] Implement iOS TabView navigation structure with sidebarAdaptable — **completed**
- [x] Create TranslateView with full-screen design — **completed**
- [x] Create VocabularyView with search, sort, export — **completed**
- [x] Create LearnView with flashcards and spaced repetition — **completed**
- [x] Create PhrasesView with categories — **completed**
- [x] Create MoreView with History, Settings, About — **completed**
- [x] Apply Liquid Glass effects (.glassEffect(), .buttonStyle(.glass)) — **completed**
- [x] Fix all compilation errors for multiplatform support — **completed**
- [x] Remove template Item.swift file — **completed**

### Remaining Tasks
- [ ] Test on iPhone 14 Pro simulator/device — pending
- [ ] Test on iPad Pro M4 simulator/device — pending
- [ ] Verify Translation API integration — pending
- [ ] Polish animations and transitions — pending
- [ ] App icon and branding — pending

## 5) Findings, Decisions, Assumptions

### Key Findings from Research

**Liquid Glass (iOS 26):**
- Standard SwiftUI components (TabView, NavigationStack, toolbars) adopt Liquid Glass automatically
- Use `.glassEffect()` modifier sparingly on custom views
- Use `.buttonStyle(.glass)` for glass-styled buttons
- `GlassEffectContainer` for combining multiple glass effects

**TabView sidebarAdaptable:**
- iOS: Bottom tab bar
- iPadOS: Top floating tab bar that morphs to sidebar
- macOS/tvOS: Always shows sidebar
- Limit to 5 main tabs for tab bar; use TabSection for hierarchy

**Translation Framework:**
- `TranslationSession` for programmatic translation
- `LanguageAvailability` to check/download language packs
- Works offline when language packs downloaded

### Decisions Made

1. **Use TabView not NavigationSplitView for iOS** - Tab bar is more ergonomic for iPhone, puts navigation at thumb reach
2. **5 tabs: Translate, Vocabulary, Learn, Phrases, More** - Balances functionality with tab bar space
3. **Settings in sheet, not separate tab** - Common iOS pattern, accessed from More or gear button
4. **Full-width input/output areas** - No padding waste on translate view
5. **Pinyin always visible** - Core learning feature, not hidden behind toggle
6. **Use @Observable macro** - Modern Swift approach instead of ObservableObject for iOS 17+
7. **Platform conditionals for unavailable APIs** - #if os(iOS) for navigationBarTitleDisplayMode, insetGrouped list style

### Assumptions

1. User has iOS 26+ installed (Liquid Glass requires iOS 26)
2. Translation language packs can be downloaded on first use
3. UserDefaults sufficient for data persistence (used for terms, history, progress)
4. Apple Intelligence/FoundationModels available on target devices

## 6) Issues, Mistakes, Recoveries

### Issue 1: @MainActor + ObservableObject Conflict
- **Symptom:** Type does not conform to ObservableObject error
- **Root cause:** @MainActor on class prevents @StateObject initialization
- **Fix:** Changed to @Observable macro with @State in App
- **Guardrail:** Use @Observable for iOS 17+ apps

### Issue 2: Duplicate PartOfSpeech.color Extension
- **Symptom:** Invalid redeclaration of 'color'
- **Root cause:** Extension in TranslateView duplicated one in ChineseTextAnalyzer
- **Fix:** Removed duplicate extension from TranslateView.swift
- **Guardrail:** Check for existing extensions before adding

### Issue 3: macOS Unavailable APIs
- **Symptom:** 'insetGrouped' is unavailable in macOS, 'navigationBarTitleDisplayMode' unavailable
- **Root cause:** iOS-specific APIs used without platform checks
- **Fix:** Added #if os(iOS) conditionals around platform-specific modifiers
- **Guardrail:** Test build for all platforms during development

### Issue 4: AnalyzedWord Property Name Mismatch
- **Symptom:** ForEach using \.word but property is .text
- **Root cause:** Model uses 'text', code referenced 'word'
- **Fix:** Changed all word.word to word.text
- **Guardrail:** Match property names between model and usage

### Issue 5: ReviewQuality Switch Not Exhaustive
- **Symptom:** Switch must be exhaustive error
- **Root cause:** Enum has 6 cases but switch only handled 5
- **Fix:** Added missing .difficult case to all switches
- **Guardrail:** Use default case or verify all enum cases covered

## 7) Scenario-Focused Resolution Tests

### Test 1: Full-Screen Translation
- **Repro steps:** Launch app on iPhone 14 Pro → Go to Translate tab → Enter text
- **Expected:** Input field and output area use full width, no black bars
- **Post-change behavior:** TBD - requires device testing
- **Verdict:** Pending

### Test 2: Word Tap for Details
- **Repro steps:** Translate "Hello" to Chinese → Tap "你好" in output
- **Expected:** Sheet shows pinyin "nǐ hǎo", part of speech, save button
- **Post-change behavior:** Code complete with WordChip and WordDetailSheet
- **Verdict:** Pending runtime test

### Test 3: iPad Sidebar Adaptation
- **Repro steps:** Launch on iPad Pro in landscape → Observe tab bar behavior
- **Expected:** Tab bar morphs into sidebar
- **Post-change behavior:** TabView uses .sidebarAdaptable style
- **Verdict:** Pending device test

### Test 4: Flashcard Learning Session
- **Repro steps:** Go to Learn tab → Tap card → Review with quality rating
- **Expected:** Card flips, shows translation, rating buttons work
- **Post-change behavior:** LearnView complete with FlashcardView and spaced repetition
- **Verdict:** Pending runtime test

### Test 5: Vocabulary Management
- **Repro steps:** Save term from translation → Go to Vocabulary → Search/sort/export
- **Expected:** Term appears, search works, export produces valid output
- **Post-change behavior:** VocabularyView complete with all features
- **Verdict:** Pending runtime test

## 8) Verification Summary

| Check | Status | Evidence |
|-------|--------|----------|
| Build succeeds | ✅ Complete | xcodebuild success |
| Models created | ✅ Complete | SavedTerm, LearningCard, TranslationHistory, TranslationDirection |
| Services created | ✅ Complete | PinyinConverter, ChineseTextAnalyzer, SpeechService, ClipboardService |
| Tab navigation | ✅ Complete | ContentView with TabView sidebarAdaptable |
| TranslateView | ✅ Complete | Full-screen design with word analysis |
| VocabularyView | ✅ Complete | Search, sort, export functionality |
| LearnView | ✅ Complete | Flashcards with glass effect |
| PhrasesView | ✅ Complete | Categories with 50+ phrases |
| MoreView | ✅ Complete | History, Settings, About |
| Liquid Glass | ✅ Complete | .glassEffect(), .buttonStyle(.glass) applied |
| iPhone full-screen UI | Pending | Requires device testing |
| Translation API works | Pending | Requires runtime test |
| iPad sidebar works | Pending | Requires device testing |

## 9) Remaining Work & Next Steps

**Immediate:**
1. Run on iPhone 14 Pro simulator to verify full-screen layout
2. Run on iPad Pro simulator to verify sidebar behavior
3. Test translation functionality end-to-end
4. Verify all interactions work as designed

**Follow-up (Future Session):**
1. Add app icon and branding
2. Implement AI-enhanced features (FoundationModels)
3. Add widgets and App Intents
4. Performance optimization
5. Accessibility audit

## 10) Updates to This File

- 2026-02-11 00:00: Created handoff.md with comprehensive iOS redesign plan
  - Documented requirements from previous MandarinKit codebase analysis
  - Researched HIG, Liquid Glass, sidebarAdaptable TabView
  - Created 18-step implementation plan
  - Defined acceptance criteria and test scenarios

- 2026-02-11 12:00: Major implementation update
  - Created all Models: SavedTerm, TranslationDirection, TranslationHistory, LearningCard
  - Created all Services: PinyinConverter, ChineseTextAnalyzer, SpeechService, ClipboardService
  - Implemented all Views: TranslateView, VocabularyView, LearnView, PhrasesView, MoreView
  - Applied Liquid Glass effects (.glassEffect(), .buttonStyle(.glass))
  - Fixed 5 build issues (see Issues section)
  - Build now succeeds for all platforms
  - Ready for device testing

## Files Created/Modified

### Models (SwiftMandarin/Models/)
- `TranslationDirection.swift` - EN↔ZH direction enum
- `SavedTerm.swift` - Vocabulary term model + store
- `TranslationHistory.swift` - History entry + store
- `LearningCard.swift` - Flashcard + progress + store

### Services (SwiftMandarin/Services/)
- `PinyinConverter.swift` - Chinese→pinyin with tone colors
- `ChineseTextAnalyzer.swift` - Word segmentation, POS tagging
- `SpeechService.swift` - Text-to-speech
- `ClipboardService.swift` - Cross-platform clipboard

### Views (SwiftMandarin/Views/)
- `TranslateView.swift` - Main translation with word analysis
- `VocabularyView.swift` - Saved terms with search/sort/export
- `LearnView.swift` - Flashcards with spaced repetition
- `PhrasesView.swift` - Phrase categories (50+ phrases)
- `MoreView.swift` - History, Settings, About

### App
- `SwiftMandarinApp.swift` - App entry with @Observable stores
- `ContentView.swift` - TabView with sidebarAdaptable

### Removed
- `Item.swift` - Xcode template file (not needed)
