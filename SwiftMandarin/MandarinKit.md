<file_map>
/Users/rogerlin/XCode-Projects/MandarinKit
├── MandarinKit
│   ├── Assets.xcassets
│   │   ├── AccentColor.colorset
│   │   │   └── Contents.json
│   │   ├── AppIcon.appiconset
│   │   │   ├── Contents.json
│   │   │   ├── icon-1024 1.png
│   │   │   ├── icon-1024 2.png
│   │   │   ├── icon-1024 3.png
│   │   │   └── icon-1024 4.png
│   │   └── Contents.json
│   ├── ContentView.swift * +
│   ├── MandarinKitApp.swift * +
│   └── Info.plist
├── MandarinKit-Universal
│   ├── Assets.xcassets
│   │   ├── AccentColor.colorset
│   │   │   └── Contents.json
│   │   ├── AppIcon.appiconset
│   │   │   ├── Contents.json
│   │   │   ├── Icon-20@2x.png
│   │   │   ├── Icon-20@3x.png
│   │   │   ├── Icon-29.png
│   │   │   ├── Icon-29@2x.png
│   │   │   ├── Icon-29@3x.png
│   │   │   ├── Icon-40@2x.png
│   │   │   ├── Icon-40@3x.png
│   │   │   ├── Icon-60@2x.png
│   │   │   ├── Icon-60@3x.png
│   │   │   ├── icon-1024 1.png
│   │   │   ├── icon-1024 2.png
│   │   │   ├── icon-1024 3.png
│   │   │   ├── icon-1024 4.png
│   │   │   ├── icon_128x128.png
│   │   │   ├── icon_128x128@2x.png
│   │   │   ├── icon_16x16.png
│   │   │   ├── icon_16x16@2x.png
│   │   │   ├── icon_256x256.png
│   │   │   ├── icon_256x256@2x.png
│   │   │   ├── icon_32x32.png
│   │   │   ├── icon_32x32@2x.png
│   │   │   ├── icon_512x512.png
│   │   │   └── icon_512x512@2x.png
│   │   └── Contents.json
│   ├── ContentView.swift * +
│   └── MandarinKit_UniversalApp.swift * +
├── Shared
│   ├── Models
│   │   ├── Favorite.swift * +
│   │   ├── LearningCard.swift * +
│   │   ├── LearningDeck.swift * +
│   │   ├── LearningProgress.swift * +
│   │   ├── PhraseCollection.swift * +
│   │   ├── SavedTerm.swift * +
│   │   └── SidebarItem.swift * +
│   ├── Services
│   │   ├── AIService.swift * +
│   │   ├── AnimationHelpers.swift * +
│   │   ├── AppTheme.swift * +
│   │   ├── ChineseTextAnalyzer.swift * +
│   │   ├── ClipboardService.swift * +
│   │   ├── IntelligenceCoach.swift * +
│   │   ├── LiquidGlassHelpers.swift * +
│   │   ├── PinyinConverter.swift * +
│   │   ├── SpeechService.swift * +
│   │   ├── TranslationDirection.swift * +
│   │   ├── TranslationHistoryStore.swift * +
│   │   └── UserPreferences.swift * +
│   └── Views
│       ├── AIEnhancedTermDetail.swift * +
│       ├── AboutView.swift * +
│       ├── AnnotatedChineseText.swift * +
│       ├── AppBackground.swift * +
│       ├── CardContainer.swift * +
│       ├── HistoryView.swift * +
│       ├── InteractiveChineseText.swift * +
│       ├── LearnView.swift * +
│       ├── MobileTranslateView.swift * +
│       ├── MobileViews.swift * +
│       ├── PhraseCollectionView.swift * +
│       ├── SavedTermsView.swift * +
│       ├── SettingsView.swift * +
│       ├── StatisticsView.swift * +
│       └── TranslateView.swift * +
├── docs
│   ├── apple-api-integration-proposals.md *
│   └── cross-platform-architecture.md *
├── .claude
│   └── data
│       └── sessions
│           └── fb369491-c9da-46c5-bb8a-b3ab04005b82.json
├── MandarinKit.xcodeproj
│   ├── project.xcworkspace
│   │   ├── xcuserdata
│   │   │   └── rogerlin.xcuserdatad
│   │   │       └── UserInterfaceState.xcuserstate
│   │   └── contents.xcworkspacedata
│   ├── xcuserdata
│   │   └── rogerlin.xcuserdatad
│   │       └── xcschemes
│   │           └── xcschememanagement.plist
│   ├── agent-progress.txt
│   ├── feature_list.json
│   ├── handoff.md
│   ├── init.sh
│   └── project.pbxproj
├── logs
│   ├── fb369491-c9da-46c5-bb8a-b3ab04005b82
│   │   ├── chat.json
│   │   ├── notification.json
│   │   ├── post_tool_use.json
│   │   ├── pre_tool_use.json
│   │   ├── stop.json
│   │   └── subagent_stop.json
│   ├── session_end.json
│   ├── session_start.json
│   └── user_prompt_submit.json
├── mandarinkit.icon
│   ├── Assets
│   │   └── https___apps.apple.com_us_app_%E6%B2%89%E6%B5%B8%E5%BC%8F%E7%BF%BB%E8%AF%91_id6502333245_Image.png
│   └── icon.json
└── handoff.md *


(* denotes selected files)
(+ denotes code-map available)
</file_map>
<file_contents>
File: /Users/rogerlin/XCode-Projects/MandarinKit/docs/apple-api-integration-proposals.md
```md
# Apple API Integration Proposals for MandarinKit

**Document Version:** 1.0
**Date:** 2026-02-09
**Status:** Draft Proposals

---

## Executive Summary

This document proposes integrations with Apple's native APIs to transform MandarinKit from a basic translation app into an intelligent, deeply integrated macOS Mandarin learning experience. The proposals leverage:

1. **Translation Framework** - Native on-device translation
2. **FoundationModels Framework** - On-device LLM for intelligent features
3. **Natural Language Framework** - Chinese text analysis and tokenization
4. **Apple Intelligence Writing Tools** - Composition assistance
5. **TextKit** - Rich text rendering and interaction

---

## Proposal 1: Native Translation Integration

### Current State
MandarinKit uses a custom `TranslationService` with placeholder implementation.

### Proposed Integration

#### 1.1 Replace Custom Service with Translation Framework

```swift
import Translation

class NativeTranslationService: ObservableObject {
    private var session: TranslationSession?

    func translate(_ text: String, from: Locale.Language, to: Locale.Language) async throws -> String {
        let configuration = TranslationSession.Configuration(
            source: from,
            target: to
        )

        if session == nil {
            session = try await TranslationSession(configuration: configuration)
        }

        let response = try await session!.translate(text)
        return response.targetText
    }
}
```

#### 1.2 Batch Translation for Vocabulary Lists

When users import vocabulary or process long texts, use batch translation:

```swift
func translateVocabularyList(_ words: [String]) async throws -> [TranslationSession.Response] {
    let requests = words.map { TranslationSession.Request(sourceText: $0) }
    return try await session.translations(from: requests)
}
```

#### 1.3 Language Availability Management

Show download status and allow users to manage offline language packs:

```swift
struct LanguageDownloadView: View {
    @State private var availability: LanguageAvailability?

    var body: some View {
        VStack {
            if let status = availability?.status(for: .init(identifier: "zh-Hans")) {
                switch status {
                case .installed:
                    Label("Chinese (Simplified) - Ready", systemImage: "checkmark.circle.fill")
                case .supported:
                    Button("Download Chinese Pack") {
                        // Trigger download
                    }
                case .unsupported:
                    Text("Not available on this device")
                }
            }
        }
        .task {
            availability = LanguageAvailability()
        }
    }
}
```

#### 1.4 Translation Overlay UI

Use Apple's built-in translation presentation for quick lookups:

```swift
Text(selectedText)
    .translationPresentation(isPresented: $showTranslation, text: selectedText)
```

### Benefits
- **Privacy**: All translation happens on-device
- **Performance**: No network latency for translations
- **Reliability**: Works offline after language download
- **Consistency**: Uses same engine as system-wide translation

### Implementation Effort: Medium (2-3 days)

---

## Proposal 2: On-Device LLM Integration (FoundationModels)

### Overview
The FoundationModels framework provides access to Apple's on-device language model for intelligent, context-aware features.

### 2.1 Intelligent Learning Tips

Generate personalized tips based on the user's current flashcard:

```swift
import FoundationModels

class LearningAssistant {
    private let model = SystemLanguageModel.default

    func generateLearningTip(for word: String, pinyin: String, meaning: String) async throws -> String {
        let session = LanguageModelSession()

        let prompt = """
        You are a Mandarin Chinese tutor. Generate a brief, helpful learning tip for this word:

        Word: \(word)
        Pinyin: \(pinyin)
        Meaning: \(meaning)

        Include one of: mnemonic device, usage context, common mistakes to avoid, or related words.
        Keep it under 50 words.
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }
}
```

### 2.2 Example Sentence Generation

Generate contextual example sentences for vocabulary:

```swift
@Generable
struct ExampleSentence {
    @Guide(description: "A natural Chinese sentence using the target word")
    var chinese: String

    @Guide(description: "Pinyin pronunciation with tone marks")
    var pinyin: String

    @Guide(description: "English translation")
    var english: String

    @Guide(description: "Difficulty level: beginner, intermediate, advanced")
    var level: String
}

func generateExamples(for word: String, count: Int = 3) async throws -> [ExampleSentence] {
    let session = LanguageModelSession()

    let prompt = """
    Generate \(count) example sentences using the Chinese word "\(word)".
    Vary the difficulty levels.
    """

    return try await session.respond(to: prompt, generating: [ExampleSentence].self)
}
```

### 2.3 Grammar Explanations

Explain grammar patterns when users encounter them:

```swift
@Generable
struct GrammarExplanation {
    @Guide(description: "Name of the grammar pattern")
    var patternName: String

    @Guide(description: "Simple explanation of the pattern")
    var explanation: String

    @Guide(description: "The general structure/formula")
    var structure: String

    @Guide(description: "Two example sentences demonstrating the pattern")
    var examples: [String]
}

func explainGrammar(in sentence: String) async throws -> GrammarExplanation? {
    let session = LanguageModelSession()

    let prompt = """
    Analyze this Chinese sentence and identify the main grammar pattern:
    "\(sentence)"

    If there's a notable grammar pattern, explain it simply.
    """

    return try await session.respond(to: prompt, generating: GrammarExplanation.self)
}
```

### 2.4 Conversation Practice

Interactive conversation practice using tool calling:

```swift
@Tool
struct CheckPronunciation {
    @Argument(description: "The pinyin to check")
    var pinyin: String

    func call() async throws -> String {
        // Validate pinyin format and tones
        return "Pronunciation feedback..."
    }
}

@Tool
struct LookupWord {
    @Argument(description: "Chinese word to look up")
    var word: String

    func call() async throws -> String {
        // Look up in dictionary
        return "Definition and examples..."
    }
}

class ConversationPractice {
    func startSession(topic: String) async throws -> LanguageModelSession {
        let session = LanguageModelSession(
            instructions: """
            You are a friendly Mandarin conversation partner.
            Speak in simple Chinese appropriate for a learner.
            Gently correct mistakes.
            Keep responses short (1-2 sentences).
            """,
            tools: [CheckPronunciation.self, LookupWord.self]
        )
        return session
    }
}
```

### 2.5 Adaptive Difficulty

Analyze user performance and adjust content:

```swift
@Generable
struct DifficultyAssessment {
    @Guide(description: "Recommended HSK level (1-6)")
    var recommendedLevel: Int

    @Guide(description: "Areas needing focus")
    var focusAreas: [String]

    @Guide(description: "Suggested next topics")
    var nextTopics: [String]
}

func assessProgress(history: [FlashcardResult]) async throws -> DifficultyAssessment {
    let session = LanguageModelSession()

    let historyDescription = history.map {
        "\($0.word): \($0.correct ? "correct" : "incorrect") in \($0.responseTime)s"
    }.joined(separator: "\n")

    let prompt = """
    Based on this learning history, assess the student's level:
    \(historyDescription)
    """

    return try await session.respond(to: prompt, generating: DifficultyAssessment.self)
}
```

### Benefits
- **Privacy**: All processing on-device, no data leaves the Mac
- **Personalization**: Context-aware responses based on user's learning history
- **Engagement**: Dynamic content keeps learning fresh
- **Intelligence**: Goes beyond simple translation to true language understanding

### Implementation Effort: High (5-7 days)

---

## Proposal 3: Chinese Text Analysis (Natural Language Framework)

### Overview
The Natural Language framework provides powerful tools for analyzing Chinese text, essential for a language learning app.

### 3.1 Word Segmentation

Chinese text has no spaces between words. Use NLTokenizer for proper segmentation:

```swift
import NaturalLanguage

class ChineseTextAnalyzer {
    func segmentWords(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.simplifiedChinese)

        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            words.append(String(text[range]))
            return true
        }
        return words
    }
}

// Usage in TranslateView:
// "我喜欢学习中文" -> ["我", "喜欢", "学习", "中文"]
```

### 3.2 Interactive Word Lookup

Make each word in translated text tappable:

```swift
struct InteractiveChineseText: View {
    let text: String
    @State private var words: [(String, Range<String.Index>)] = []
    @State private var selectedWord: String?

    var body: some View {
        FlowLayout {
            ForEach(words, id: \.0) { word, _ in
                WordView(word: word)
                    .onTapGesture {
                        selectedWord = word
                    }
            }
        }
        .popover(item: $selectedWord) { word in
            WordDetailPopover(word: word)
        }
        .onAppear {
            words = segmentWithRanges(text)
        }
    }
}
```

### 3.3 Parts of Speech Tagging

Help users understand sentence structure:

```swift
func analyzePartsOfSpeech(_ text: String) -> [(String, NLTag?)] {
    let tagger = NLTagger(tagSchemes: [.lexicalClass])
    tagger.string = text
    tagger.setLanguage(.simplifiedChinese, range: text.startIndex..<text.endIndex)

    var results: [(String, NLTag?)] = []

    tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                         unit: .word,
                         scheme: .lexicalClass) { tag, range in
        results.append((String(text[range]), tag))
        return true
    }

    return results
}

// Color-code by part of speech in UI:
// Nouns: blue, Verbs: red, Adjectives: green, etc.
```

### 3.4 Language Detection

Auto-detect input language to set translation direction:

```swift
func detectLanguage(_ text: String) -> NLLanguage? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    return recognizer.dominantLanguage
}

// In TranslateView:
func autoDetectAndTranslate(_ text: String) async {
    if let language = detectLanguage(text) {
        if language == .simplifiedChinese || language == .traditionalChinese {
            preferences.translationDirection = .chineseToEnglish
        } else if language == .english {
            preferences.translationDirection = .englishToChinese
        }
    }
    await translate()
}
```

### 3.5 Sentence Complexity Analysis

Rate sentence difficulty for learning progression:

```swift
struct SentenceAnalysis {
    let wordCount: Int
    let uniqueCharacters: Int
    let averageWordLength: Double
    let estimatedHSKLevel: Int
}

func analyzeSentence(_ text: String) -> SentenceAnalysis {
    let words = segmentWords(text)
    let characters = Set(text.filter { !$0.isWhitespace && !$0.isPunctuation })

    return SentenceAnalysis(
        wordCount: words.count,
        uniqueCharacters: characters.count,
        averageWordLength: Double(characters.count) / Double(words.count),
        estimatedHSKLevel: estimateHSKLevel(characters)
    )
}
```

### Benefits
- **Accuracy**: Apple's NLP is optimized for Chinese
- **Interactivity**: Word-level interaction enables deeper learning
- **Insight**: Parts of speech and structure analysis aids comprehension
- **Automation**: Auto-detect language reduces friction

### Implementation Effort: Medium (3-4 days)

---

## Proposal 4: Writing Tools Integration (Apple Intelligence)

### Overview
Apple Intelligence Writing Tools help users compose and refine text. Perfect for language learners writing in Chinese.

### 4.1 Enable Writing Tools on Input

```swift
struct TranslateView: View {
    @State private var inputText = ""

    var body: some View {
        TextEditor(text: $inputText)
            .writingToolsBehavior(.complete)  // Full Writing Tools access
    }
}
```

### 4.2 Custom Writing Suggestions

Integrate with the composition experience:

```swift
TextEditor(text: $inputText)
    .writingToolsBehavior(.limited)  // Only proofreading, not rewriting
    .onWritingToolsCompletion { result in
        // Track what corrections were made for learning insights
        trackWritingCorrections(original: inputText, corrected: result)
    }
}
```

### 4.3 Composition Practice Mode

A dedicated view for writing practice with AI assistance:

```swift
struct WritingPracticeView: View {
    @State private var prompt: String = "Write about your weekend plans"
    @State private var userWriting: String = ""
    @State private var showFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Writing Prompt")
                .font(.headline)
            Text(prompt)
                .padding()
                .background(.secondary.opacity(0.1))
                .cornerRadius(8)

            Text("Your Response (in Chinese)")
                .font(.headline)

            TextEditor(text: $userWriting)
                .writingToolsBehavior(.complete)
                .frame(minHeight: 200)

            Button("Get Feedback") {
                showFeedback = true
            }
            .disabled(userWriting.isEmpty)
        }
        .sheet(isPresented: $showFeedback) {
            WritingFeedbackView(text: userWriting, prompt: prompt)
        }
    }
}
```

### Benefits
- **Native Experience**: Familiar macOS Writing Tools UI
- **Learning Aid**: Helps users improve their Chinese writing
- **Seamless**: No extra UI needed, system-provided

### Implementation Effort: Low (1 day)

---

## Proposal 5: Rich Text Display (TextKit)

### Overview
Enhanced text rendering for beautiful, interactive Chinese text display.

### 5.1 Styled Pinyin Annotations

Use NSAttributedString for precise control over pinyin positioning:

```swift
func createAnnotatedText(chinese: String, pinyin: String) -> NSAttributedString {
    let attributed = NSMutableAttributedString(string: chinese)

    // Ruby annotation for pinyin above characters
    let rubyAnnotation = CTRubyAnnotationCreateWithAttributes(
        .auto,
        .auto,
        .before,
        pinyin as CFString,
        [kCTRubyAnnotationSizeFactorAttributeName: 0.5] as CFDictionary
    )

    attributed.addAttribute(
        kCTRubyAnnotationAttributeName as NSAttributedString.Key,
        value: rubyAnnotation,
        range: NSRange(location: 0, length: chinese.count)
    )

    return attributed
}
```

### 5.2 Interactive Text with Tap Targets

Make specific characters/words tappable:

```swift
struct TappableChineseText: NSViewRepresentable {
    let attributedText: NSAttributedString
    let onTap: (String, NSRange) -> Void

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.textStorage?.setAttributedString(attributedText)

        let tapGesture = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        textView.addGestureRecognizer(tapGesture)

        return textView
    }

    class Coordinator: NSObject {
        let parent: TappableChineseText

        @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
            guard let textView = gesture.view as? NSTextView else { return }
            let point = gesture.location(in: textView)
            let index = textView.characterIndexForInsertion(at: point)

            // Find word at index and call onTap
            if let word = findWord(at: index, in: textView) {
                parent.onTap(word.text, word.range)
            }
        }
    }
}
```

### 5.3 Tone Color Coding

Visual tone indicators through text coloring:

```swift
extension NSAttributedString {
    static func toneColored(_ text: String, pinyin: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString()

        let toneColors: [UIColor] = [
            .systemRed,    // 1st tone (high level)
            .systemGreen,  // 2nd tone (rising)
            .systemBlue,   // 3rd tone (dipping)
            .systemPurple, // 4th tone (falling)
            .systemGray    // 5th tone (neutral)
        ]

        // Parse pinyin for tone numbers and apply colors
        for (char, tone) in zip(text, extractTones(pinyin)) {
            let color = toneColors[tone - 1]
            attributed.append(NSAttributedString(
                string: String(char),
                attributes: [.foregroundColor: color]
            ))
        }

        return attributed
    }
}
```

### Benefits
- **Visual Learning**: Color and positioning aid memory
- **Interactivity**: Tap-to-learn on any word
- **Polish**: Professional, native-feeling text display

### Implementation Effort: Medium (2-3 days)

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)
1. **Natural Language Integration** - Word segmentation, language detection
2. **Translation Framework** - Replace custom service with native API
3. **Writing Tools** - Enable on text inputs

### Phase 2: Intelligence (Week 2)
4. **FoundationModels - Basic** - Learning tips, example sentences
5. **TextKit Enhancement** - Interactive tappable text
6. **Tone coloring** - Visual learning aids

### Phase 3: Advanced (Week 3)
7. **FoundationModels - Advanced** - Grammar explanations, adaptive difficulty
8. **Conversation Practice** - Interactive chat with LLM
9. **Progress Analytics** - AI-powered learning insights

### Phase 4: Polish (Week 4)
10. **Language Pack Management** - Download/manage offline languages
11. **Writing Practice Mode** - Dedicated composition view
12. **Performance Optimization** - Caching, background processing

---

## Technical Requirements

### Minimum macOS Version
- **macOS 26** (Tahoe) for FoundationModels and latest Translation APIs
- Some features available on macOS 14+ with reduced functionality

### Entitlements Required
```xml
<key>com.apple.developer.translation</key>
<true/>
<key>com.apple.developer.foundation-models</key>
<true/>
```

### Privacy Considerations
- All processing happens on-device
- No user data leaves the Mac
- Learning history stored locally only
- Clear data management in Settings

---

## Summary

These proposals transform MandarinKit from a simple translation tool into an intelligent learning companion by leveraging Apple's latest frameworks:

| Feature | API | Effort | Impact |
|---------|-----|--------|--------|
| Native Translation | Translation | Medium | High |
| Word Segmentation | NaturalLanguage | Low | High |
| Learning Tips | FoundationModels | Medium | High |
| Example Sentences | FoundationModels | Medium | High |
| Grammar Explanations | FoundationModels | High | Medium |
| Writing Tools | Apple Intelligence | Low | Medium |
| Interactive Text | TextKit | Medium | High |
| Conversation Practice | FoundationModels | High | High |

**Recommended Priority**: Start with Natural Language (word segmentation) and Translation Framework as they provide immediate, high-impact improvements with moderate effort.

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/docs/cross-platform-architecture.md
```md
# MandarinKit Cross-Platform Architecture Document

**Version**: 1.0
**Date**: 2026-02-10
**Status**: Planning Phase

---

## 1. Executive Summary

This document outlines the comprehensive plan to extend MandarinKit from a macOS-only app to a cross-platform app supporting **iOS 26**, **iPadOS 26**, and **macOS 26**. The goal is to maintain the app's beautiful, native feel on each platform while maximizing code reuse.

### Target Platforms
- **macOS 26+**: Existing platform, sidebar-based navigation
- **iPadOS 26+**: Sidebar-adaptable navigation with Magic Keyboard/Pencil support
- **iOS 26+**: Tab bar navigation optimized for compact screens

### Key Design Principles
1. **Native Feel**: Each platform should feel like a first-party Apple app
2. **Code Reuse**: Maximize shared code through abstraction layers
3. **Liquid Glass**: Embrace Apple's new design language across all platforms
4. **Human Interface Guidelines**: Follow iOS/iPadOS 26 HIG strictly

---

## 2. Current Architecture Analysis

### 2.1 Project Structure
```
MandarinKit/
├── Models/           # ✅ Cross-platform (no changes needed)
│   ├── Favorite.swift
│   ├── LearningCard.swift
│   ├── LearningDeck.swift
│   ├── LearningProgress.swift
│   ├── SavedTerm.swift
│   └── SidebarItem.swift
├── Services/         # ⚠️ Mixed (some need abstraction)
│   ├── AppTheme.swift              # ❌ macOS-specific (NSColor)
│   ├── ChineseTextAnalyzer.swift   # ✅ Cross-platform
│   ├── ClipboardService.swift      # ❌ macOS-specific (NSPasteboard)
│   ├── IntelligenceCoach.swift     # ✅ Cross-platform
│   ├── LiquidGlassHelpers.swift    # ⚠️ Needs iOS/iPadOS availability
│   ├── PinyinConverter.swift       # ✅ Cross-platform
│   ├── SpeechService.swift         # ⚠️ Needs verification
│   ├── TranslationDirection.swift  # ✅ Cross-platform
│   ├── TranslationHistoryStore.swift # ✅ Cross-platform
│   └── UserPreferences.swift       # ✅ Cross-platform
└── Views/            # ⚠️ Mixed (navigation needs redesign)
    ├── AboutView.swift             # ⚠️ Needs platform adaptation
    ├── AnnotatedChineseText.swift  # ✅ Cross-platform
    ├── AppBackground.swift         # ⚠️ Needs verification
    ├── CardContainer.swift         # ✅ Cross-platform
    ├── HistoryView.swift           # ✅ Cross-platform
    ├── InteractiveChineseText.swift # ✅ Cross-platform
    ├── LearnView.swift             # ✅ Cross-platform
    ├── SavedTermsView.swift        # ✅ Cross-platform
    ├── SettingsView.swift          # ❌ macOS-specific (Settings scene)
    └── TranslateView.swift         # ✅ Cross-platform
```

### 2.2 Platform-Specific Code Identified

#### Critical Issues (Must Fix)

1. **ClipboardService.swift** - Uses AppKit's `NSPasteboard`
   ```swift
   import AppKit  // macOS only

   enum ClipboardService {
       static func copy(_ text: String) {
           let pasteboard = NSPasteboard.general  // macOS only
           pasteboard.clearContents()
           pasteboard.setString(text, forType: .string)
       }
   }
   ```
   **Solution**: Platform conditional with `#if os(macOS)` / `#else`

2. **AppTheme.swift** - Uses `NSColor`
   ```swift
   static let backgroundTop = Color(nsColor: .windowBackgroundColor)  // macOS only
   static let cardFill = Color(nsColor: .textBackgroundColor)         // macOS only
   ```
   **Solution**: Use platform-agnostic `Color` or conditional compilation

3. **MandarinKitApp.swift** - Multiple macOS-specific APIs
   ```swift
   NSApplication.shared.orderFrontStandardAboutPanel(...)  // macOS only
   NSApp.keyWindow?.firstResponder?.tryToPerform(...)      // macOS only
   Settings { SettingsView() }                              // macOS Settings scene
   ```
   **Solution**: Conditional compilation and platform-specific app structure

4. **ContentView.swift** - macOS Environment API
   ```swift
   @Environment(\.openSettings) private var openSettings  // macOS only
   ```
   **Solution**: Conditional compilation for settings button

5. **LiquidGlassHelpers.swift** - Only has macOS availability checks
   ```swift
   if #available(macOS 26.0, *) { ... }  // Needs iOS 26, iPadOS 26
   ```
   **Solution**: Add iOS/iPadOS availability checks

---

## 3. Cross-Platform Architecture Design

### 3.1 Navigation Architecture

#### macOS 26 (Current - Maintain)
```
┌─────────────────────────────────────────┐
│  NavigationSplitView                    │
│  ┌─────────┬───────────────────────────┐│
│  │ Sidebar │  Detail View              ││
│  │         │                           ││
│  │ Translate│                          ││
│  │ Vocab    │                          ││
│  │ Learn    │                          ││
│  │ History  │                          ││
│  │         │                           ││
│  │ Settings │                          ││
│  └─────────┴───────────────────────────┘│
└─────────────────────────────────────────┘
```

#### iPadOS 26 (New - Sidebar Adaptable)
```
Portrait:                    Landscape:
┌──────────────────┐        ┌────────────────────────────┐
│    Tab Bar       │        │ Sidebar │  Detail          │
│                  │        │ ─────── │                  │
│   [Content]      │        │Translate│                  │
│                  │        │ Vocab   │                  │
│                  │        │ Learn   │                  │
│                  │        │ History │                  │
│ 🔄 📚 📖 🕐 ⚙️  │        │ Settings│                  │
└──────────────────┘        └────────────────────────────┘
```
Uses `TabView` with `.tabViewStyle(.sidebarAdaptable)` - automatically adapts

#### iOS 26 (New - Tab Bar)
```
┌──────────────────┐
│                  │
│   [Content]      │
│                  │
│                  │
│                  │
├──────────────────┤
│ 🔄  📚  📖  🕐  │
│Trans Vocab Learn His│
└──────────────────┘
Settings in-app as sheet
```

### 3.2 Platform Abstraction Layer

#### ClipboardService Abstraction
```swift
// Services/ClipboardService.swift
enum ClipboardService {
    static func copy(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    static func paste() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}
```

#### AppTheme Abstraction
```swift
// Services/AppTheme.swift
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppTheme {
    static let accent = Color(red: 0.12, green: 0.38, blue: 0.64)
    static let secondaryAccent = Color(red: 0.88, green: 0.49, blue: 0.22)

    #if os(macOS)
    static let backgroundTop = Color(nsColor: .windowBackgroundColor)
    static let backgroundBottom = Color(nsColor: .controlBackgroundColor)
    static let cardFill = Color(nsColor: .textBackgroundColor).opacity(0.92)
    static let border = Color(nsColor: .separatorColor)
    #else
    static let backgroundTop = Color(uiColor: .systemBackground)
    static let backgroundBottom = Color(uiColor: .secondarySystemBackground)
    static let cardFill = Color(uiColor: .tertiarySystemBackground).opacity(0.92)
    static let border = Color(uiColor: .separator)
    #endif

    static let mutedText = Color.secondary
}
```

#### LiquidGlassHelpers Update
```swift
// Services/LiquidGlassHelpers.swift
extension View {
    @ViewBuilder
    func liquidGlassCard(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        #if os(macOS)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay(shape.stroke(AppTheme.border, lineWidth: 1))
        } else {
            fallbackCard(shape: shape)
        }
        #else
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay(shape.stroke(AppTheme.border, lineWidth: 1))
        } else {
            fallbackCard(shape: shape)
        }
        #endif
    }

    @ViewBuilder
    private func fallbackCard(shape: some Shape) -> some View {
        self.background(AppTheme.cardFill, in: shape)
            .overlay(shape.stroke(AppTheme.border, lineWidth: 1))
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false) -> some View {
        #if os(macOS)
        if #available(macOS 26.0, *) {
            applyGlassButton(prominent: prominent)
        } else {
            applyFallbackButton(prominent: prominent)
        }
        #else
        if #available(iOS 26.0, *) {
            applyGlassButton(prominent: prominent)
        } else {
            applyFallbackButton(prominent: prominent)
        }
        #endif
    }

    @ViewBuilder
    private func applyGlassButton(prominent: Bool) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        }
    }

    @ViewBuilder
    private func applyFallbackButton(prominent: Bool) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
```

### 3.3 App Entry Point Architecture

```swift
// MandarinKitApp.swift
import SwiftUI

@main
struct MandarinKitApp: App {
    @StateObject private var historyStore = TranslationHistoryStore()
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacContentView()
                .environmentObject(historyStore)
            #else
            MobileContentView()
                .environmentObject(historyStore)
            #endif
        }
        #if os(macOS)
        .commands {
            macOSCommands
        }

        Settings {
            SettingsView()
        }
        #endif
    }

    #if os(macOS)
    @CommandsBuilder
    private var macOSCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About MandarinKit") {
                NSApplication.shared.orderFrontStandardAboutPanel(options: [...])
            }
        }

        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") {
                NSApp.keyWindow?.firstResponder?.tryToPerform(
                    #selector(NSSplitViewController.toggleSidebar(_:)),
                    with: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }

        CommandMenu("Navigate") { ... }
        CommandMenu("Translation") { ... }
    }
    #endif
}
```

### 3.4 Content View Architecture

#### macOS Content View (Existing, Minor Changes)
```swift
// Views/macOS/MacContentView.swift
#if os(macOS)
struct MacContentView: View {
    @State private var selection: SidebarItem = .translate
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selection: $selection)
        } detail: {
            ZStack {
                AppBackground()
                DetailView(selection: selection)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { notification in
            if let item = notification.object as? SidebarItem {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = item
                }
            }
        }
    }
}
#endif
```

#### Mobile Content View (New)
```swift
// Views/Mobile/MobileContentView.swift
#if os(iOS)
struct MobileContentView: View {
    @State private var selection: SidebarItem = .translate
    @State private var showSettings = false
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    var body: some View {
        TabView(selection: $selection) {
            Tab("Translate", systemImage: "character.bubble", value: .translate) {
                NavigationStack {
                    TranslateView()
                        .navigationTitle("Translate")
                        .toolbar { settingsToolbarItem }
                }
            }

            Tab("Vocabulary", systemImage: "bookmark", value: .vocabulary) {
                NavigationStack {
                    SavedTermsView()
                        .navigationTitle("Vocabulary")
                        .toolbar { settingsToolbarItem }
                }
            }

            Tab("Learn", systemImage: "rectangle.stack", value: .learn) {
                NavigationStack {
                    LearnView()
                        .navigationTitle("Learn")
                        .toolbar { settingsToolbarItem }
                }
            }

            Tab("History", systemImage: "clock", value: .history) {
                NavigationStack {
                    HistoryView(selection: $selection)
                        .navigationTitle("History")
                        .toolbar { settingsToolbarItem }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)  // iPad: sidebar, iPhone: tab bar
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                MobileSettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
            }
        }
    }
}
#endif
```

### 3.5 Settings Architecture

#### macOS Settings (Keep as-is with Settings scene)
- Uses native macOS Settings window
- Accessed via ⌘, keyboard shortcut
- TabView with grouped forms

#### iOS/iPadOS Settings (New - Sheet Presentation)
```swift
// Views/Mobile/MobileSettingsView.swift
#if os(iOS)
struct MobileSettingsView: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        List {
            // General Section
            Section("General") {
                Toggle("Save Translation History", isOn: $preferences.saveTranslationHistory)
                if preferences.saveTranslationHistory {
                    Picker("Max History", selection: $preferences.maxHistoryEntries) {
                        Text("25").tag(25)
                        Text("50").tag(50)
                        Text("100").tag(100)
                    }
                }
            }

            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $preferences.appColorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }

                Picker("Text Size", selection: $preferences.fontSize) {
                    ForEach(FontSizeChoice.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
            }

            // Translation Section
            Section("Translation") {
                Picker("Default Direction", selection: $preferences.translationDirectionRaw) {
                    ForEach(TranslationDirection.allCases) { direction in
                        Text(direction.label).tag(direction.rawValue)
                    }
                }
                Toggle("Show Pinyin", isOn: $preferences.showPinyin)
                Toggle("Show Tone Marks", isOn: $preferences.showToneMarks)
                    .disabled(!preferences.showPinyin)
            }

            // Learning Section
            Section("Learning") {
                Stepper("Daily Goal: \(preferences.dailyGoal) cards",
                       value: $preferences.dailyGoal, in: 5...50, step: 5)
                Toggle("Spaced Repetition", isOn: $preferences.enableSpacedRepetition)
            }

            // Speech Section
            Section("Speech") {
                HStack {
                    Text("Speech Rate")
                    Slider(value: $preferences.speechRate, in: 0.1...1.0)
                }
                Toggle("Auto-Speak Translations", isOn: $preferences.autoSpeak)
            }

            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0")
                        .foregroundStyle(.secondary)
                }
                Link("Rate on App Store", destination: URL(string: "...")!)
                Link("Privacy Policy", destination: URL(string: "...")!)
            }
        }
    }
}
#endif
```

---

## 4. Platform-Specific UI Adaptations

### 4.1 iPhone Optimizations
- **Compact Layout**: Optimize for single-column layouts
- **Bottom Safe Area**: Respect home indicator area
- **Keyboard Handling**: Push content up when keyboard appears
- **Gesture Navigation**: Support swipe-back navigation
- **Dynamic Type**: Support all accessibility text sizes

### 4.2 iPad Optimizations
- **Sidebar Navigation**: Use sidebar in landscape, tab bar in portrait
- **Split View**: Support multitasking side-by-side
- **Keyboard Shortcuts**: Support hardware keyboard shortcuts
- **Pointer Support**: Hover effects for Magic Keyboard/trackpad
- **Apple Pencil**: Text selection and drawing in Learn mode (future)

### 4.3 macOS Optimizations (Existing)
- **Menu Bar**: Full menu bar integration
- **Keyboard Shortcuts**: Comprehensive shortcut support
- **Window Management**: Resizable, multi-window support
- **Settings Window**: Native macOS Settings scene

---

## 5. Implementation Plan

### Phase 1: Project Configuration (Day 1)
1. Add iOS and iPadOS deployment targets to Xcode project
2. Configure build settings for multiplatform
3. Update Info.plist for all platforms
4. Set minimum deployment targets:
   - macOS 26.0
   - iOS 26.0
   - iPadOS 26.0

### Phase 2: Service Layer Abstraction (Day 1-2)
1. Update ClipboardService with platform conditionals
2. Update AppTheme with platform-agnostic colors
3. Update LiquidGlassHelpers with iOS availability
4. Verify SpeechService works cross-platform
5. Test all services on Simulator

### Phase 3: App Entry Point (Day 2)
1. Create platform-conditional app structure
2. Separate macOS commands into conditional block
3. Create MobileContentView with TabView
4. Implement sheet-based settings for iOS

### Phase 4: View Adaptations (Day 3-4)
1. Create MacContentView (extracted from ContentView)
2. Create MobileContentView with sidebarAdaptable TabView
3. Create MobileSettingsView (List-based settings)
4. Adapt TranslateView for compact layouts
5. Adapt LearnView for touch interaction
6. Adapt HistoryView for mobile navigation

### Phase 5: Polish & Testing (Day 5)
1. Test on iPhone simulator (multiple sizes)
2. Test on iPad simulator (portrait/landscape)
3. Test on macOS (existing functionality)
4. Fix any layout issues
5. Verify Liquid Glass effects on all platforms
6. Performance optimization

### Phase 6: Enhancement (Day 6+)
1. Add iPad keyboard shortcuts
2. Add iPad pointer hover effects
3. Implement share sheet for iOS
4. Add Spotlight integration
5. Add widget support (future)

---

## 6. File Changes Summary

### New Files to Create
```
Views/
├── macOS/
│   └── MacContentView.swift      # macOS-specific content view
├── Mobile/
│   ├── MobileContentView.swift   # iOS/iPadOS content view
│   └── MobileSettingsView.swift  # iOS/iPadOS settings
└── Shared/
    └── DetailView.swift          # Shared detail view component
```

### Files to Modify
```
Services/
├── ClipboardService.swift        # Add UIPasteboard support
├── AppTheme.swift                # Add UIColor support
└── LiquidGlassHelpers.swift      # Add iOS availability checks

MandarinKitApp.swift              # Add platform conditionals
ContentView.swift                 # Extract to platform-specific views
```

### Files Unchanged (Cross-Platform Ready)
```
Models/                           # All models are cross-platform
├── Favorite.swift
├── LearningCard.swift
├── LearningDeck.swift
├── LearningProgress.swift
├── SavedTerm.swift
└── SidebarItem.swift

Services/
├── ChineseTextAnalyzer.swift     # Uses Natural Language (cross-platform)
├── IntelligenceCoach.swift
├── PinyinConverter.swift
├── TranslationDirection.swift
├── TranslationHistoryStore.swift
└── UserPreferences.swift

Views/
├── AnnotatedChineseText.swift
├── CardContainer.swift
├── HistoryView.swift
├── InteractiveChineseText.swift
├── LearnView.swift
├── SavedTermsView.swift
└── TranslateView.swift
```

---

## 7. Research References

### Apple Documentation Consulted
- [Liquid Glass Design System](https://developer.apple.com/documentation/swiftui/glasseffect)
- [Translation Framework](https://developer.apple.com/documentation/translation)
- [TabView sidebarAdaptable](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable)
- [UIPasteboard](https://developer.apple.com/documentation/uikit/uipasteboard)
- [Platform Conditional Compilation](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version)
- [Human Interface Guidelines - iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)
- [Human Interface Guidelines - iPadOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados)

### Key APIs
- `glassEffect(_:in:)` - Liquid Glass material
- `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` - Glass buttons
- `TabView` with `.tabViewStyle(.sidebarAdaptable)` - Adaptive navigation
- `#if os(macOS)` / `#if os(iOS)` - Platform conditionals
- `#available(iOS 26.0, macOS 26.0, *)` - Version availability

---

## 8. Success Criteria

### Functional Requirements
- [ ] App builds and runs on macOS 26
- [ ] App builds and runs on iOS 26 (iPhone)
- [ ] App builds and runs on iPadOS 26 (iPad)
- [ ] All features work on all platforms
- [ ] Settings persist across all platforms
- [ ] Translation works on all platforms
- [ ] Learning/flashcards work on all platforms
- [ ] History syncs properly

### Design Requirements
- [ ] Liquid Glass effects render correctly on all platforms
- [ ] Navigation feels native on each platform
- [ ] Settings UI follows platform conventions
- [ ] Touch targets meet HIG minimums (44pt on iOS)
- [ ] Dynamic Type support on iOS/iPadOS
- [ ] Keyboard shortcuts work on iPad with hardware keyboard

### Quality Requirements
- [ ] No compiler warnings
- [ ] No runtime crashes
- [ ] Smooth 60fps animations
- [ ] Memory usage within acceptable limits
- [ ] App size reasonable for App Store

---

*This document will be updated as implementation progresses.*

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/MandarinKit/ContentView.swift
```swift
//
//  ContentView.swift
//  MandarinKit
//
//  Created by Roger Lin on 1/29/26.
//

import SwiftUI

// MARK: - macOS Content View

#if os(macOS)
struct MacContentView: View {
    @State private var selection: SidebarItem = .translate
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selection: $selection)
        } detail: {
            ZStack {
                AppBackground()
                DetailView(selection: $selection)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { notification in
            if let item = notification.object as? SidebarItem {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = item
                }
            }
        }
    }
}

// MARK: - macOS Sidebar View

private struct MacSidebarView: View {
    @Binding var selection: SidebarItem
    @ObservedObject private var progressStore = LearningProgressStore.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                SidebarItemRow(item: item)
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MandarinKit")
        .safeAreaInset(edge: .bottom) {
            Button {
                openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                        .font(.custom("Avenir Next", size: 13))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}
#endif

// MARK: - Mobile Content View (iOS/iPadOS)

#if os(iOS)

/// Tab identifiers for the mobile app
enum MobileTab: Int, CaseIterable, Identifiable {
    case translate = 0
    case vocabulary = 1
    case learn = 2
    case history = 3
    case more = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .translate: return "Translate"
        case .vocabulary: return "Vocabulary"
        case .learn: return "Learn"
        case .history: return "History"
        case .more: return "More"
        }
    }

    var symbol: String {
        switch self {
        case .translate: return "character.bubble"
        case .vocabulary: return "bookmark"
        case .learn: return "rectangle.stack"
        case .history: return "clock"
        case .more: return "ellipsis.circle"
        }
    }
}

struct MobileContentView: View {
    @State private var selectedTab: MobileTab = .translate
    @State private var showSettings = false
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Translate
            Tab(MobileTab.translate.title, systemImage: MobileTab.translate.symbol, value: .translate) {
                NavigationStack {
                    MobileTranslateView()
                        .navigationTitle("Translate")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsToolbarItem }
                }
            }

            // Tab 2: Vocabulary
            Tab(MobileTab.vocabulary.title, systemImage: MobileTab.vocabulary.symbol, value: .vocabulary) {
                NavigationStack {
                    MobileSavedTermsView()
                        .navigationTitle("Vocabulary")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsToolbarItem }
                }
            }

            // Tab 3: Learn
            Tab(MobileTab.learn.title, systemImage: MobileTab.learn.symbol, value: .learn) {
                NavigationStack {
                    MobileLearnView()
                        .navigationTitle("Learn")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsToolbarItem }
                }
            }

            // Tab 4: History
            Tab(MobileTab.history.title, systemImage: MobileTab.history.symbol, value: .history) {
                NavigationStack {
                    MobileHistoryView(selectedTab: Binding(
                        get: { selectedTab.rawValue },
                        set: { selectedTab = MobileTab(rawValue: $0) ?? .translate }
                    ))
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbarItem }
                }
            }

            // Tab 5: More
            Tab(MobileTab.more.title, systemImage: MobileTab.more.symbol, value: .more) {
                NavigationStack {
                    MobileMoreView()
                        .navigationTitle("More")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { settingsToolbarItem }
                }
            }
        }
        .tabViewStyle(.tabBarOnly)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                MobileSettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
        }
    }
}

// MARK: - Mobile More View

struct MobileMoreView: View {
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    var body: some View {
        List {
            Section {
                NavigationLink {
                    MobilePhraseCollectionView()
                        .navigationTitle("Phrases")
                } label: {
                    Label("Quick Phrases", systemImage: "text.bubble")
                }

                NavigationLink {
                    MobileStatisticsView()
                        .environmentObject(historyStore)
                        .navigationTitle("Statistics")
                } label: {
                    Label("Statistics", systemImage: "chart.bar")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("4.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
#endif

// MARK: - Shared Detail View

struct DetailView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        switch selection {
        case .translate:
            TranslateView()
        case .vocabulary:
            SavedTermsView()
        case .phrases:
            PhraseCollectionView()
        case .learn:
            LearnView()
        case .history:
            HistoryView(selection: $selection)
        case .statistics:
            StatisticsView()
        }
    }
}

// MARK: - Sidebar Item Row (Shared)

struct SidebarItemRow: View {
    let item: SidebarItem

    @ObservedObject private var progressStore = LearningProgressStore.shared
    @ObservedObject private var savedTermsStore = SavedTermsStore.shared
    @ObservedObject private var phraseStore = PhraseCollectionStore.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    var body: some View {
        HStack {
            Label(item.title, systemImage: item.symbol)
                .font(.custom("Avenir Next", size: 14))

            Spacer()

            if let badge = badgeText {
                Text(badge)
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var badgeText: String? {
        switch item {
        case .translate:
            return nil
        case .vocabulary:
            let count = savedTermsStore.terms.count
            return count > 0 ? "\(count)" : nil
        case .phrases:
            let count = phraseStore.favoritePhrases.count
            return count > 0 ? "\(count) ★" : nil
        case .learn:
            let dueCount = progressStore.getDueCards(from: LearningDeck.cards).count
            return dueCount > 0 ? "\(dueCount) due" : nil
        case .history:
            let count = historyStore.entries.count
            return count > 0 ? "\(count)" : nil
        case .statistics:
            return nil
        }
    }

    private var badgeColor: Color {
        switch item {
        case .translate: return .blue
        case .vocabulary: return .green
        case .phrases: return .purple
        case .learn: return .orange
        case .history: return .gray
        case .statistics: return .indigo
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private var platformDescription: String {
        #if os(macOS)
        return "Your beautiful Mandarin learning companion for macOS"
        #else
        return "Your beautiful Mandarin learning companion"
        #endif
    }

    private var pages: [(title: String, subtitle: String, symbol: String, color: Color)] {
        [
            ("Welcome to MandarinKit", platformDescription, "character.book.closed.fill", .blue),
            ("Translate Instantly", "Translate between English and Chinese with on-device intelligence", "character.bubble.fill", .green),
            ("Learn with Flashcards", "Master vocabulary with spaced repetition and progress tracking", "rectangle.stack.fill", .purple),
            ("Track Your Progress", "Set daily goals, build streaks, and watch your skills grow", "chart.line.uptrend.xyaxis", .orange)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: pages[index].symbol)
                            .font(.system(size: 80))
                            .foregroundStyle(pages[index].color)

                        VStack(spacing: 12) {
                            Text(pages[index].title)
                                .font(.custom("Avenir Next Demi Bold", size: 28))
                                .multilineTextAlignment(.center)

                            Text(pages[index].subtitle)
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)
                        }

                        Spacer()
                    }
                    .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            .tabViewStyle(.automatic)
            #endif

            // Page indicators and buttons
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppTheme.accent : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .liquidGlassButtonStyle(prominent: true)
                    } else {
                        Button("Get Started") {
                            onComplete()
                        }
                        .liquidGlassButtonStyle(prominent: true)
                    }
                }
            }
            .padding(24)
        }
        #if os(macOS)
        .frame(width: 500, height: 450)
        #endif
    }
}

// MARK: - Previews

#if os(macOS)
#Preview("macOS") {
    MacContentView()
        .environmentObject(TranslationHistoryStore())
}
#else
#Preview("iOS") {
    MobileContentView()
        .environmentObject(TranslationHistoryStore())
}
#endif

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/MandarinKit/MandarinKitApp.swift
```swift
//
//  MandarinKitApp.swift
//  MandarinKit
//
//  Created by Roger Lin on 1/29/26.
//

import SwiftUI

@main
struct MandarinKitApp: App {
    @StateObject private var historyStore = TranslationHistoryStore()
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacContentView()
                .environmentObject(historyStore)
            #else
            MobileContentView()
                .environmentObject(historyStore)
            #endif
        }
        #if os(macOS)
        .commands {
            macOSCommands
        }
        #endif

        #if os(macOS)
        // Settings Scene (macOS only)
        Settings {
            SettingsView()
        }
        #endif
    }

    #if os(macOS)
    @CommandsBuilder
    private var macOSCommands: some Commands {
        // App Commands
        CommandGroup(replacing: .appInfo) {
            Button("About MandarinKit") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "MandarinKit",
                        .applicationVersion: "2.0",
                        .credits: NSAttributedString(
                            string: "A beautiful Mandarin learning companion",
                            attributes: [.font: NSFont.systemFont(ofSize: 11)]
                        )
                    ]
                )
            }
        }

        // View Commands
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") {
                NSApp.keyWindow?.firstResponder?.tryToPerform(
                    #selector(NSSplitViewController.toggleSidebar(_:)),
                    with: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }

        // Navigation Commands
        CommandMenu("Navigate") {
            Button("Translate") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.translate)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Vocabulary") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.vocabulary)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Learn") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.learn)
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("History") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.history)
            }
            .keyboardShortcut("4", modifiers: .command)
        }

        // Translation Commands
        CommandMenu("Translation") {
            Button("Translate") {
                NotificationCenter.default.post(name: .performTranslation, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("Swap Languages") {
                NotificationCenter.default.post(name: .swapLanguages, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Toggle Pinyin") {
                preferences.showPinyin.toggle()
            }
            .keyboardShortcut("p", modifiers: .command)

            Button("Toggle Tone Marks") {
                preferences.showToneMarks.toggle()
            }
            .keyboardShortcut("t", modifiers: .command)
        }
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    // Navigation
    static let navigateTo = Notification.Name("navigateTo")

    // Translation
    static let performTranslation = Notification.Name("performTranslation")
    static let swapLanguages = Notification.Name("swapLanguages")
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/MandarinKit-Universal/ContentView.swift
```swift
//
//  ContentView.swift
//  MandarinKit-Universal
//
//  This file re-exports the shared ContentView components.
//  The actual implementation is in MandarinKit/ContentView.swift
//
//  Created by Roger Lin on 2/10/26.
//

import SwiftUI

// MARK: - macOS Content View

#if os(macOS)
struct MacContentView: View {
    @State private var selection: SidebarItem = .translate
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        NavigationSplitView {
            MacSidebarView(selection: $selection)
        } detail: {
            ZStack {
                AppBackground()
                DetailView(selection: $selection)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { notification in
            if let item = notification.object as? SidebarItem {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = item
                }
            }
        }
    }
}

// MARK: - macOS Sidebar View

private struct MacSidebarView: View {
    @Binding var selection: SidebarItem
    @ObservedObject private var progressStore = LearningProgressStore.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                SidebarItemRow(item: item)
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MandarinKit")
        .safeAreaInset(edge: .bottom) {
            Button {
                openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                        .font(.custom("Avenir Next", size: 13))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}
#endif

// MARK: - Mobile Content View (iOS/iPadOS)

#if os(iOS)
struct MobileContentView: View {
    @State private var selectedTab: Int = 0
    @State private var showSettings = false
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Translate
            NavigationStack {
                MobileTranslateView()
                    .navigationTitle("Translate")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbarItem }
            }
            .tabItem {
                Label("Translate", systemImage: "character.bubble")
            }
            .tag(0)

            // Tab 2: Vocabulary
            NavigationStack {
                MobileSavedTermsView()
                    .navigationTitle("Vocabulary")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbarItem }
            }
            .tabItem {
                Label("Vocabulary", systemImage: "bookmark")
            }
            .tag(1)

            // Tab 3: Learn
            NavigationStack {
                MobileLearnView()
                    .navigationTitle("Learn")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbarItem }
            }
            .tabItem {
                Label("Learn", systemImage: "rectangle.stack")
            }
            .tag(2)

            // Tab 4: History
            NavigationStack {
                MobileHistoryView(selectedTab: $selectedTab)
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbarItem }
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(3)

            // Tab 5: More (Phrases, Statistics)
            NavigationStack {
                MobileMoreView()
                    .navigationTitle("More")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbarItem }
            }
            .tabItem {
                Label("More", systemImage: "ellipsis.circle")
            }
            .tag(4)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                MobileSettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
            }
        }
    }
}

// MARK: - Mobile More View

struct MobileMoreView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    MobilePhraseCollectionView()
                        .navigationTitle("Phrases")
                } label: {
                    Label("Quick Phrases", systemImage: "text.bubble")
                }

                NavigationLink {
                    MobileStatisticsView()
                        .navigationTitle("Statistics")
                } label: {
                    Label("Statistics", systemImage: "chart.bar")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("4.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
#endif

// MARK: - Shared Detail View

struct DetailView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        switch selection {
        case .translate:
            TranslateView()
        case .vocabulary:
            SavedTermsView()
        case .phrases:
            PhraseCollectionView()
        case .learn:
            LearnView()
        case .history:
            HistoryView(selection: $selection)
        case .statistics:
            StatisticsView()
        }
    }
}

// MARK: - Sidebar Item Row (Shared)

struct SidebarItemRow: View {
    let item: SidebarItem

    @ObservedObject private var progressStore = LearningProgressStore.shared
    @ObservedObject private var savedTermsStore = SavedTermsStore.shared
    @ObservedObject private var phraseStore = PhraseCollectionStore.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    var body: some View {
        HStack {
            Label(item.title, systemImage: item.symbol)
                .font(.custom("Avenir Next", size: 14))

            Spacer()

            if let badge = badgeText {
                Text(badge)
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var badgeText: String? {
        switch item {
        case .translate:
            return nil
        case .vocabulary:
            let count = savedTermsStore.terms.count
            return count > 0 ? "\(count)" : nil
        case .phrases:
            let count = phraseStore.favoritePhrases.count
            return count > 0 ? "\(count) ★" : nil
        case .learn:
            let dueCount = progressStore.getDueCards(from: LearningDeck.cards).count
            return dueCount > 0 ? "\(dueCount) due" : nil
        case .history:
            let count = historyStore.entries.count
            return count > 0 ? "\(count)" : nil
        case .statistics:
            return nil
        }
    }

    private var badgeColor: Color {
        switch item {
        case .translate: return .blue
        case .vocabulary: return .green
        case .phrases: return .purple
        case .learn: return .orange
        case .history: return .gray
        case .statistics: return .indigo
        }
    }
}

// MARK: - Previews

#if os(macOS)
#Preview("macOS") {
    MacContentView()
        .environmentObject(TranslationHistoryStore())
}
#else
#Preview("iOS") {
    MobileContentView()
        .environmentObject(TranslationHistoryStore())
}
#endif

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/MandarinKit-Universal/MandarinKit_UniversalApp.swift
```swift
//
//  MandarinKit_UniversalApp.swift
//  MandarinKit-Universal
//
//  Created by Roger Lin on 2/10/26.
//

import SwiftUI

@main
struct MandarinKit_UniversalApp: App {
    @StateObject private var historyStore = TranslationHistoryStore()
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacContentView()
                .environmentObject(historyStore)
            #else
            MobileContentView()
                .environmentObject(historyStore)
            #endif
        }
        #if os(macOS)
        .commands {
            macOSCommands
        }
        #endif

        #if os(macOS)
        // Settings Scene (macOS only)
        Settings {
            SettingsView()
        }
        #endif
    }

    #if os(macOS)
    @CommandsBuilder
    private var macOSCommands: some Commands {
        // App Commands
        CommandGroup(replacing: .appInfo) {
            Button("About MandarinKit") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [
                        .applicationName: "MandarinKit",
                        .applicationVersion: "2.0",
                        .credits: NSAttributedString(
                            string: "A beautiful Mandarin learning companion",
                            attributes: [.font: NSFont.systemFont(ofSize: 11)]
                        )
                    ]
                )
            }
        }

        // View Commands
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Sidebar") {
                NSApp.keyWindow?.firstResponder?.tryToPerform(
                    #selector(NSSplitViewController.toggleSidebar(_:)),
                    with: nil
                )
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }

        // Navigation Commands
        CommandMenu("Navigate") {
            Button("Translate") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.translate)
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Vocabulary") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.vocabulary)
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Learn") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.learn)
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("History") {
                NotificationCenter.default.post(name: .navigateTo, object: SidebarItem.history)
            }
            .keyboardShortcut("4", modifiers: .command)
        }

        // Translation Commands
        CommandMenu("Translation") {
            Button("Translate") {
                NotificationCenter.default.post(name: .performTranslation, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("Swap Languages") {
                NotificationCenter.default.post(name: .swapLanguages, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button("Toggle Pinyin") {
                preferences.showPinyin.toggle()
            }
            .keyboardShortcut("p", modifiers: .command)

            Button("Toggle Tone Marks") {
                preferences.showToneMarks.toggle()
            }
            .keyboardShortcut("t", modifiers: .command)
        }
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    // Navigation
    static let navigateTo = Notification.Name("navigateTo")

    // Translation
    static let performTranslation = Notification.Name("performTranslation")
    static let swapLanguages = Notification.Name("swapLanguages")
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/AboutView.swift
```swift
//
//  AboutView.swift
//  MandarinKit
//
//  Updated About view showcasing all app features
//

import SwiftUI

struct AboutView: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                featureHighlights
                whatsNew
                quickStart
                keyboardShortcuts
                footer
            }
            .padding(28)
        }
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accent)

            VStack(spacing: 8) {
                Text("MandarinKit")
                    .font(.custom("Avenir Next Demi Bold", size: 32))

                Text("Version 2.0")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(.secondary)

                Text("A beautiful Mandarin learning companion for macOS")
                    .font(.custom("Avenir Next", size: preferences.fontSize.headlineSize))
                    .foregroundStyle(AppTheme.mutedText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var featureHighlights: some View {
        CardContainer(title: "Features", systemImage: "sparkles") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                FeatureCard(
                    title: "Translation",
                    description: "On-device Mandarin ↔ English with availability checks",
                    symbol: "character.bubble.fill",
                    color: .blue
                )

                FeatureCard(
                    title: "Spaced Repetition",
                    description: "Smart learning with progress tracking",
                    symbol: "brain.head.profile",
                    color: .purple
                )

                FeatureCard(
                    title: "Flashcards",
                    description: "Create custom cards and manage decks",
                    symbol: "rectangle.stack.fill",
                    color: .green
                )

                FeatureCard(
                    title: "Apple Intelligence",
                    description: "AI coaching tips and practice prompts",
                    symbol: "sparkles",
                    color: .orange
                )

                FeatureCard(
                    title: "Pinyin Support",
                    description: "Tone marks and romanization",
                    symbol: "character.book.closed.fill",
                    color: .teal
                )

                FeatureCard(
                    title: "Daily Goals",
                    description: "Track streaks and learning progress",
                    symbol: "flame.fill",
                    color: .red
                )
            }
        }
    }

    private var whatsNew: some View {
        CardContainer(title: "What's New in 2.0", systemImage: "star.fill") {
            VStack(alignment: .leading, spacing: 12) {
                NewFeatureRow(title: "Dashboard", description: "See your stats and quick actions at a glance")
                NewFeatureRow(title: "Favorites", description: "Save important translations for quick access")
                NewFeatureRow(title: "Custom Flashcards", description: "Create your own vocabulary cards")
                NewFeatureRow(title: "Spaced Repetition", description: "Optimal review intervals for better retention")
                NewFeatureRow(title: "Streak Tracking", description: "Build daily practice habits")
                NewFeatureRow(title: "Comprehensive Settings", description: "Customize every aspect of your experience")
                NewFeatureRow(title: "Keyboard Shortcuts", description: "Power user shortcuts for faster workflow")
            }
        }
    }

    private var quickStart: some View {
        CardContainer(title: "Quick Start", systemImage: "bolt.fill") {
            VStack(alignment: .leading, spacing: 12) {
                QuickStartStep(number: 1, text: "Visit the Dashboard for an overview of your learning")
                QuickStartStep(number: 2, text: "Translate text and save favorites with the ⭐ button")
                QuickStartStep(number: 3, text: "Practice flashcards daily to build your streak")
                QuickStartStep(number: 4, text: "Use Pinyin view for standalone conversion")
                QuickStartStep(number: 5, text: "Customize your experience in Settings (⌘,)")
            }
        }
    }

    private var keyboardShortcuts: some View {
        CardContainer(title: "Keyboard Shortcuts", systemImage: "keyboard") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ShortcutRow(keys: "⌘1-7", action: "Navigate tabs")
                ShortcutRow(keys: "⌘↵", action: "Translate")
                ShortcutRow(keys: "⌘R", action: "Swap languages")
                ShortcutRow(keys: "⌘D", action: "Add to favorites")
                ShortcutRow(keys: "⌘P", action: "Toggle pinyin")
                ShortcutRow(keys: "⌘T", action: "Toggle tone marks")
                ShortcutRow(keys: "⌘K", action: "Speak source")
                ShortcutRow(keys: "⌘L", action: "Speak translation")
                ShortcutRow(keys: "Space", action: "Reveal answer")
                ShortcutRow(keys: "⌘⇧1-3", action: "Rate card")
                ShortcutRow(keys: "⌘←/→", action: "Previous/Next card")
                ShortcutRow(keys: "⌘,", action: "Open Settings")
            }
        }
    }

    private var footer: some View {
        CardContainer(title: "Privacy & Security", systemImage: "lock.shield.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("MandarinKit respects your privacy:")
                    .font(.custom("Avenir Next Demi Bold", size: preferences.fontSize.bodySize))

                VStack(alignment: .leading, spacing: 8) {
                    PrivacyPoint(text: "Translation runs on-device when supported")
                    PrivacyPoint(text: "Apple Intelligence features use on-device models")
                    PrivacyPoint(text: "Your data stays on your Mac")
                    PrivacyPoint(text: "No accounts or sign-ups required")
                }
            }
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let title: String
    let description: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                Text(description)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(AppTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - New Feature Row

private struct NewFeatureRow: View {
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 13))

            Text("—")
                .foregroundStyle(.secondary)

            Text(description)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

// MARK: - Quick Start Step

private struct QuickStartStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.custom("Avenir Next Demi Bold", size: 12))
                .frame(width: 24, height: 24)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(Circle())

            Text(text)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.custom("Menlo", size: 11))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(action)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(AppTheme.mutedText)

            Spacer()
        }
    }
}

// MARK: - Privacy Point

private struct PrivacyPoint: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Text(text)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(AppTheme.mutedText)
        }
    }
}

#Preview {
    AboutView()
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/SettingsView.swift
```swift
//
//  SettingsView.swift
//  MandarinKit
//
//  Comprehensive Settings window with multiple tabs
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            TranslationSettingsTab()
                .tabItem {
                    Label("Translation", systemImage: "character.bubble")
                }

            LearningSettingsTab()
                .tabItem {
                    Label("Learning", systemImage: "book.closed")
                }

            SpeechSettingsTab()
                .tabItem {
                    Label("Speech", systemImage: "speaker.wave.2")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Confirm before clearing history", isOn: $preferences.confirmDestructiveActions)
                Toggle("Save translation history", isOn: $preferences.saveTranslationHistory)

                if preferences.saveTranslationHistory {
                    Picker("Maximum history entries", selection: $preferences.maxHistoryEntries) {
                        Text("25").tag(25)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                    }
                }
            } header: {
                Text("Behavior")
            }

            Section {
                HStack {
                    Text("Total translations")
                    Spacer()
                    Text("\(preferences.totalTranslations)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Cards reviewed")
                    Spacer()
                    Text("\(preferences.totalCardsReviewed)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Current streak")
                    Spacer()
                    Text("\(preferences.currentStreak) days")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Longest streak")
                    Spacer()
                    Text("\(preferences.longestStreak) days")
                        .foregroundStyle(.secondary)
                }

                Button("Reset Statistics") {
                    preferences.resetStats()
                }
                .foregroundStyle(.red)
            } header: {
                Text("Statistics")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Settings Tab

private struct AppearanceSettingsTab: View {
    @ObservedObject private var preferences = UserPreferences.shared

    private let availableFonts: [(name: String, displayName: String)] = [
        // System Fonts
        (".AppleSystemUIFont", "System (Default)"),
        (".AppleSystemUIFontRounded", "System Rounded"),
        (".AppleSystemUIFontSerif", "System Serif"),
        (".AppleSystemUIFontMonospaced", "System Mono"),
        // SF Pro Family
        ("SF Pro Display", "SF Pro Display"),
        ("SF Pro Text", "SF Pro Text"),
        ("SF Pro Rounded", "SF Pro Rounded"),
        // Sans-Serif
        ("Avenir Next", "Avenir Next"),
        ("Helvetica Neue", "Helvetica Neue"),
        // Serif
        ("Georgia", "Georgia"),
        ("Times New Roman", "Times New Roman"),
        ("Palatino", "Palatino"),
        ("Charter", "Charter"),
        ("New York", "New York"),
        ("Baskerville", "Baskerville"),
        ("Hoefler Text", "Hoefler Text")
    ]

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $preferences.appColorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Accent Color", selection: $preferences.accentColorChoice) {
                    ForEach(AccentColorChoice.allCases) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 12, height: 12)
                            Text(color.label)
                        }
                        .tag(color)
                    }
                }
            } header: {
                Text("Theme")
            }

            Section {
                Picker("Text Size", selection: $preferences.fontSize) {
                    ForEach(FontSizeChoice.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }

                Toggle("Use compact layout", isOn: $preferences.useCompactLayout)
            } header: {
                Text("Layout")
            }

            Section {
                Picker("English Translation Font", selection: $preferences.englishTranslationFont) {
                    ForEach(availableFonts, id: \.name) { font in
                        Text(font.displayName)
                            .font(.custom(font.name, size: 14))
                            .tag(font.name)
                    }
                }

                HStack {
                    Text("Font Size")
                    Slider(value: $preferences.englishTranslationFontSize, in: 16...36, step: 1)
                    Text("\(Int(preferences.englishTranslationFontSize))pt")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }

                Text("This font is used for displaying English translations when translating from Chinese to English.")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(.tertiary)
            } header: {
                Text("Translation Font")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chinese")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                        Text("你好")
                            .font(.custom("Avenir Next Demi Bold", size: preferences.fontSize.chineseCharacterSize))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pinyin")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                        Text("nǐ hǎo")
                            .font(.custom("Avenir Next", size: preferences.fontSize.titleSize))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("English Translation")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                        Text("Hello, how are you?")
                            .font(.custom(preferences.englishTranslationFont, size: preferences.englishTranslationFontSize))
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Font Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Translation Settings Tab

private struct TranslationSettingsTab: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section {
                Picker("Default direction", selection: $preferences.translationDirectionRaw) {
                    ForEach(TranslationDirection.allCases) { direction in
                        Text(direction.label).tag(direction.rawValue)
                    }
                }

                Toggle("Auto-translate while typing", isOn: $preferences.autoTranslate)

                if preferences.autoTranslate {
                    HStack {
                        Text("Delay")
                        Slider(value: $preferences.autoTranslateDelay, in: 0.5...3.0, step: 0.5)
                        Text("\(preferences.autoTranslateDelay, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                    }
                }
            } header: {
                Text("Translation")
            }

            Section {
                Toggle("Show pinyin by default", isOn: $preferences.showPinyin)
                Toggle("Show tone marks by default", isOn: $preferences.showToneMarks)
                    .disabled(!preferences.showPinyin)
                Toggle("Color-code pinyin by tone", isOn: $preferences.showToneColors)
                    .disabled(!preferences.showPinyin)

                // Tone color legend
                if preferences.showPinyin && preferences.showToneColors {
                    ToneColorLegend()
                }
            } header: {
                Text("Pinyin Display")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Learning Settings Tab

private struct LearningSettingsTab: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section {
                Stepper("Daily goal: \(preferences.dailyGoal) cards", value: $preferences.dailyGoal, in: 5...50, step: 5)

                Toggle("Enable spaced repetition", isOn: $preferences.enableSpacedRepetition)

                Toggle("Shuffle new cards", isOn: $preferences.shuffleNewCards)
            } header: {
                Text("Learning Goals")
            }

            Section {
                Toggle("Auto-reveal translation after delay", isOn: $preferences.autoRevealAfterDelay)

                if preferences.autoRevealAfterDelay {
                    HStack {
                        Text("Reveal after")
                        Slider(value: $preferences.autoRevealDelay, in: 1.0...10.0, step: 0.5)
                        Text("\(preferences.autoRevealDelay, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                    }
                }
            } header: {
                Text("Flashcard Behavior")
            }

            Section {
                Toggle("Show learning reminders", isOn: $preferences.showLearningReminders)

                if preferences.showLearningReminders {
                    DatePicker("Reminder time", selection: Binding(
                        get: { preferences.reminderTime },
                        set: { preferences.reminderTime = $0 }
                    ), displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminders")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Speech Settings Tab

private struct SpeechSettingsTab: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Speech rate")
                    Slider(value: $preferences.speechRate, in: 0.1...1.0, step: 0.1)
                    Text(speechRateLabel)
                        .foregroundStyle(.secondary)
                        .frame(width: 60)
                }

                Button("Test Speech") {
                    SpeechService.speak("你好，欢迎使用 MandarinKit", languageCode: "zh-CN")
                }
            } header: {
                Text("Voice")
            }

            Section {
                Toggle("Auto-speak translations", isOn: $preferences.autoSpeak)

                if preferences.autoSpeak {
                    Toggle("Speak source text", isOn: $preferences.speakSource)
                    Toggle("Speak translated text", isOn: $preferences.speakTarget)
                }
            } header: {
                Text("Automatic Speech")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var speechRateLabel: String {
        switch preferences.speechRate {
        case 0.0..<0.3: return "Slow"
        case 0.3..<0.6: return "Normal"
        case 0.6..<0.8: return "Fast"
        default: return "Very Fast"
        }
    }
}

// MARK: - Mobile Settings View (iOS/iPadOS)

#if os(iOS)
struct MobileSettingsView: View {
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        List {
            // General Section
            Section("General") {
                Toggle("Save Translation History", isOn: $preferences.saveTranslationHistory)

                if preferences.saveTranslationHistory {
                    Picker("Max History Entries", selection: $preferences.maxHistoryEntries) {
                        Text("25").tag(25)
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("200").tag(200)
                    }
                }

                Toggle("Confirm Destructive Actions", isOn: $preferences.confirmDestructiveActions)
            }

            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $preferences.appColorScheme) {
                    ForEach(AppColorScheme.allCases) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }

                Picker("Text Size", selection: $preferences.fontSize) {
                    ForEach(FontSizeChoice.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }

                Toggle("Compact Layout", isOn: $preferences.useCompactLayout)
            }

            // Translation Section
            Section("Translation") {
                Picker("Default Direction", selection: $preferences.translationDirectionRaw) {
                    ForEach(TranslationDirection.allCases) { direction in
                        Text(direction.label).tag(direction.rawValue)
                    }
                }

                Toggle("Auto-Translate While Typing", isOn: $preferences.autoTranslate)

                if preferences.autoTranslate {
                    HStack {
                        Text("Delay")
                        Slider(value: $preferences.autoTranslateDelay, in: 0.5...3.0, step: 0.5)
                        Text("\(preferences.autoTranslateDelay, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                    }
                }
            }

            // Pinyin Section
            Section("Pinyin Display") {
                Toggle("Show Pinyin", isOn: $preferences.showPinyin)
                Toggle("Show Tone Marks", isOn: $preferences.showToneMarks)
                    .disabled(!preferences.showPinyin)
                Toggle("Color-Code by Tone", isOn: $preferences.showToneColors)
                    .disabled(!preferences.showPinyin)

                // Tone color legend
                if preferences.showPinyin && preferences.showToneColors {
                    ToneColorLegend()
                }
            }

            // Learning Section
            Section("Learning") {
                Stepper("Daily Goal: \(preferences.dailyGoal) cards",
                       value: $preferences.dailyGoal, in: 5...50, step: 5)

                Toggle("Spaced Repetition", isOn: $preferences.enableSpacedRepetition)
                Toggle("Shuffle New Cards", isOn: $preferences.shuffleNewCards)
                Toggle("Auto-Reveal After Delay", isOn: $preferences.autoRevealAfterDelay)

                if preferences.autoRevealAfterDelay {
                    HStack {
                        Text("Reveal After")
                        Slider(value: $preferences.autoRevealDelay, in: 1.0...10.0, step: 0.5)
                        Text("\(preferences.autoRevealDelay, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                    }
                }
            }

            // Speech Section
            Section("Speech") {
                HStack {
                    Text("Speech Rate")
                    Slider(value: $preferences.speechRate, in: 0.1...1.0, step: 0.1)
                    Text(speechRateLabel)
                        .foregroundStyle(.secondary)
                        .frame(width: 70)
                }

                Button("Test Speech") {
                    SpeechService.speak("你好，欢迎使用 MandarinKit", languageCode: "zh-CN")
                }

                Toggle("Auto-Speak Translations", isOn: $preferences.autoSpeak)

                if preferences.autoSpeak {
                    Toggle("Speak Source Text", isOn: $preferences.speakSource)
                    Toggle("Speak Translated Text", isOn: $preferences.speakTarget)
                }
            }

            // Statistics Section
            Section("Statistics") {
                HStack {
                    Text("Total Translations")
                    Spacer()
                    Text("\(preferences.totalTranslations)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Cards Reviewed")
                    Spacer()
                    Text("\(preferences.totalCardsReviewed)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Current Streak")
                    Spacer()
                    Text("\(preferences.currentStreak) days")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Longest Streak")
                    Spacer()
                    Text("\(preferences.longestStreak) days")
                        .foregroundStyle(.secondary)
                }

                Button("Reset Statistics", role: .destructive) {
                    preferences.resetStats()
                }
            }

            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("2.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var speechRateLabel: String {
        switch preferences.speechRate {
        case 0.0..<0.3: return "Slow"
        case 0.3..<0.6: return "Normal"
        case 0.6..<0.8: return "Fast"
        default: return "Very Fast"
        }
    }
}
#endif

// MARK: - Tone Color Legend

private struct ToneColorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tone Colors")
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                ForEach(PinyinConverter.Tone.allCases, id: \.rawValue) { tone in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tone.color)
                            .frame(width: 10, height: 10)
                        Text("\(tone.rawValue)")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Example with colored pinyin
            HStack(spacing: 4) {
                Text("Example:")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(.tertiary)
                Text(PinyinConverter.coloredPinyin("你好", includeToneMarks: true))
                    .font(.custom("Avenir Next", size: 14))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#if os(macOS)
#Preview("macOS Settings") {
    SettingsView()
}
#else
#Preview("iOS Settings") {
    NavigationStack {
        MobileSettingsView()
            .navigationTitle("Settings")
    }
}
#endif

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/TranslateView.swift
```swift
//
//  TranslateView.swift
//  MandarinKit
//
//  Clean, focused translation view
//

import SwiftUI

#if canImport(Translation)
import Translation
#endif

struct TranslateView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @StateObject private var aiService = AIService.shared

    @State private var inputText: String = ""
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @State private var errorMessage: String?
    @State private var showCopiedFeedback: Bool = false
    @State private var autoDetectedDirection: TranslationDirection?

    @State private var availabilityState: AvailabilityState = .checking
    @State private var aiTip: String?
    @State private var isLoadingTip: Bool = false
    @State private var showTipPopover: Bool = false

    private let textAnalyzer = ChineseTextAnalyzer.shared

    #if canImport(Translation)
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var pendingAction: PendingAction = .none
    @State private var pendingSourceText: String = ""
    #endif

    private var direction: TranslationDirection {
        preferences.translationDirection
    }

    var body: some View {
        VStack(spacing: 0) {
            // Direction toggle
            directionBar

            // Main translation area
            HStack(spacing: 0) {
                // Input side
                inputPane

                Divider()

                // Output side
                outputPane
            }
        }
        .task {
            await checkAvailability()
        }
        .task(id: preferences.translationDirectionRaw) {
            await checkAvailability()
        }
        .onAppear {
            loadSelectedHistoryEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { _ in
            // Small delay to ensure navigation completes before loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadSelectedHistoryEntry()
            }
        }
        #if canImport(Translation)
        .translationTask(translationConfiguration) { session in
            await handleTranslation(session)
        }
        #endif
    }

    // MARK: - Direction Bar

    private var directionBar: some View {
        HStack {
            Picker("", selection: Binding(
                get: { direction },
                set: { preferences.translationDirection = $0 }
            )) {
                ForEach(TranslationDirection.allCases) { dir in
                    Text(dir.label).tag(dir)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    preferences.translationDirection = direction.toggled()
                    let temp = inputText
                    inputText = translatedText
                    translatedText = temp
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.plain)
            .help("Swap languages (⌘R)")

            Spacer()

            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(availabilityState.color)
                    .frame(width: 8, height: 8)
                Text(availabilityState.shortDescription)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Input Pane

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label
            Text(direction.sourceLabel)
                .font(.custom("Avenir Next Demi Bold", size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Text input
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.custom("Avenir Next", size: 20))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .writingToolsBehavior(.complete)

                if inputText.isEmpty {
                    Text(direction.placeholder)
                        .font(.custom("Avenir Next", size: 20))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: inputText) { _, newValue in
                autoDetectLanguage(newValue)
                // Clear AI tip when input changes
                aiTip = nil
            }

            Divider()

            // Input actions
            HStack(spacing: 12) {
                Button {
                    if let text = ClipboardService.paste() {
                        inputText = text
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.custom("Avenir Next", size: 13))
                }
                .buttonStyle(.plain)

                Button {
                    SpeechService.speak(inputText, languageCode: direction.sourceSpeechLanguageCode)
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)

                Button {
                    inputText = ""
                    translatedText = ""
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)

                Spacer()

                Button(action: requestTranslation) {
                    HStack(spacing: 6) {
                        if isTranslating {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Translate")
                            .font(.custom("Avenir Next Demi Bold", size: 13))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isTranslating || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Output Pane

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label
            Text(direction.targetLabel)
                .font(.custom("Avenir Next Demi Bold", size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Translation output
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if translatedText.isEmpty {
                        Text("Translation will appear here")
                            .font(.custom("Avenir Next", size: 18))
                            .foregroundStyle(.tertiary)
                    } else {
                        // Show the translation with pinyin if it's Chinese
                        translationOutput
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            // Output actions
            HStack(spacing: 12) {
                Button {
                    ClipboardService.copy(translatedText)
                    withAnimation {
                        showCopiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopiedFeedback = false
                        }
                    }
                } label: {
                    Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.custom("Avenir Next", size: 13))
                }
                .buttonStyle(.plain)
                .disabled(translatedText.isEmpty)

                Button {
                    SpeechService.speak(translatedText, languageCode: direction.targetSpeechLanguageCode)
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .buttonStyle(.plain)
                .disabled(translatedText.isEmpty)

                // AI Tip button
                if aiService.isAvailable && !translatedText.isEmpty {
                    Button {
                        if aiTip != nil {
                            showTipPopover.toggle()
                        } else {
                            Task { await loadAITip() }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isLoadingTip {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            if aiTip != nil {
                                Text("Tip")
                                    .font(.custom("Avenir Next", size: 11))
                            }
                        }
                        .foregroundStyle(aiTip != nil ? AppTheme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingTip)
                    .popover(isPresented: $showTipPopover) {
                        if let tip = aiTip {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(AppTheme.accent)
                                    Text("Learning Tip")
                                        .font(.custom("Avenir Next Demi Bold", size: 13))
                                }
                                Text(tip)
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: 280)
                        }
                    }
                }

                Spacer()

                // Pinyin toggle (only relevant when Chinese is involved)
                Toggle("Pinyin", isOn: $preferences.showPinyin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.custom("Avenir Next", size: 12))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Translation Output

    @ViewBuilder
    private var translationOutput: some View {
        let chineseText = direction == .englishToChinese ? translatedText : inputText

        VStack(alignment: .leading, spacing: 20) {
            // Main translation (with pinyin if Chinese)
            if direction == .englishToChinese {
                // Translating TO Chinese - show interactive Chinese output with tappable words
                InteractiveChineseText(
                    text: translatedText,
                    showPinyin: preferences.showPinyin,
                    showToneMarks: preferences.showToneMarks,
                    characterFont: .custom("Avenir Next Demi Bold", size: 32),
                    pinyinFont: .custom("Avenir Next", size: 13),
                    spacing: 6
                )
            } else {
                // Translating FROM Chinese - show English translation, but also show annotated source
                Text(translatedText)
                    .font(.custom(preferences.englishTranslationFont, size: preferences.englishTranslationFontSize))
                    .textSelection(.enabled)

                // Also show the Chinese input with pinyin below (interactive)
                if preferences.showPinyin && !chineseText.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source with Pinyin (tap words for details)")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)

                        InteractiveChineseText(
                            text: chineseText,
                            showPinyin: true,
                            showToneMarks: preferences.showToneMarks,
                            characterFont: .custom("Avenir Next Demi Bold", size: 24),
                            pinyinFont: .custom("Avenir Next", size: 11),
                            spacing: 4
                        )
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadSelectedHistoryEntry() {
        guard let entry = historyStore.selectedEntry else { return }

        inputText = entry.source
        translatedText = entry.target
        preferences.translationDirection = entry.direction
        errorMessage = nil

        // Clear the selection so it doesn't reload on every navigation
        historyStore.selectedEntry = nil
    }

    private func requestTranslation() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if availabilityState == .supported {
            errorMessage = "Languages need to be downloaded first. Go to System Settings > General > Language & Region."
            return
        }

        if availabilityState == .unsupported || availabilityState == .unavailable {
            errorMessage = "Translation is not available on this device."
            return
        }

        errorMessage = nil
        isTranslating = true

        #if canImport(Translation)
        pendingSourceText = trimmed
        pendingAction = .translate
        if translationConfiguration == nil {
            translationConfiguration = TranslationSession.Configuration(
                source: direction.sourceLanguage,
                target: direction.targetLanguage
            )
        } else {
            translationConfiguration?.invalidate()
        }
        #else
        translatedText = fallbackTranslation(for: trimmed)
        historyStore.add(source: trimmed, target: translatedText, direction: direction)
        isTranslating = false
        #endif
    }

    private func checkAvailability() async {
        #if canImport(Translation)
        availabilityState = .checking
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: direction.sourceLanguage ?? Locale.Language(identifier: "en"),
            to: direction.targetLanguage
        )
        await MainActor.run {
            availabilityState = AvailabilityState(status: status)
        }
        #else
        availabilityState = .unavailable
        #endif
    }

    #if canImport(Translation)
    private func handleTranslation(_ session: TranslationSession) async {
        guard pendingAction == .translate else { return }

        do {
            let response = try await session.translate(pendingSourceText)
            await MainActor.run {
                translatedText = response.targetText
                historyStore.add(source: pendingSourceText, target: response.targetText, direction: direction)
                isTranslating = false
                pendingAction = .none
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isTranslating = false
                pendingAction = .none
            }
        }
    }
    #endif

    private func autoDetectLanguage(_ text: String) {
        // Only auto-detect if we have enough text to analyze
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            autoDetectedDirection = nil
            return
        }

        let (language, confidence) = textAnalyzer.detectLanguageWithConfidence(trimmed)

        // Only auto-switch if confidence is high enough
        guard confidence > 0.7 else {
            autoDetectedDirection = nil
            return
        }

        let newDirection: TranslationDirection?
        switch language {
        case .chinese:
            newDirection = .chineseToEnglish
        case .english:
            newDirection = .englishToChinese
        default:
            newDirection = nil
        }

        // Only update if different from current and user hasn't manually selected
        if let detected = newDirection, detected != direction {
            autoDetectedDirection = detected
            // Auto-switch direction
            preferences.translationDirection = detected
        } else {
            autoDetectedDirection = nil
        }
    }

    private func loadAITip() async {
        isLoadingTip = true

        let chineseText = direction == .englishToChinese ? translatedText : inputText
        let englishText = direction == .englishToChinese ? inputText : translatedText

        let result = await aiService.getTranslationTip(
            chinese: chineseText,
            english: englishText
        )

        await MainActor.run {
            switch result {
            case .success(let tip):
                aiTip = tip
                showTipPopover = true
            case .failure:
                break
            }
            isLoadingTip = false
        }
    }

    private func fallbackTranslation(for text: String) -> String {
        let lowercased = text.lowercased()
        let englishToChinese: [String: String] = [
            "hello": "你好", "thank you": "谢谢", "goodbye": "再见",
            "good morning": "早上好", "good night": "晚安", "how are you": "你好吗",
            "i love you": "我爱你", "yes": "是", "no": "不"
        ]
        let chineseToEnglish: [String: String] = [
            "你好": "Hello", "谢谢": "Thank you", "再见": "Goodbye",
            "早上好": "Good morning", "晚安": "Good night", "你好吗": "How are you",
            "我爱你": "I love you", "是": "Yes", "不": "No"
        ]

        switch direction {
        case .englishToChinese:
            return englishToChinese[lowercased] ?? "(Translation unavailable)"
        case .chineseToEnglish:
            return chineseToEnglish[text] ?? "(Translation unavailable)"
        }
    }
}

// MARK: - Supporting Types

#if canImport(Translation)
private enum PendingAction {
    case none
    case translate
}
#endif

private enum AvailabilityState: Equatable {
    case checking
    case installed
    case supported
    case unsupported
    case unavailable

    #if canImport(Translation)
    init(status: LanguageAvailability.Status) {
        switch status {
        case .installed: self = .installed
        case .supported: self = .supported
        case .unsupported: self = .unsupported
        @unknown default: self = .unavailable
        }
    }
    #endif

    var shortDescription: String {
        switch self {
        case .checking: return "Checking..."
        case .installed: return "Ready"
        case .supported: return "Download needed"
        case .unsupported: return "Unsupported"
        case .unavailable: return "Unavailable"
        }
    }

    var color: Color {
        switch self {
        case .checking: return .orange
        case .installed: return .green
        case .supported: return .blue
        case .unsupported: return .red
        case .unavailable: return .gray
        }
    }
}

#Preview {
    TranslateView()
        .environmentObject(TranslationHistoryStore())
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/CardContainer.swift
```swift
import SwiftUI

struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 15))
            }

            content
        }
        .padding(16)
        .liquidGlassCard(cornerRadius: 18)
    }
}

#Preview {
    CardContainer(title: "Preview", systemImage: "sparkles") {
        Text("Card content")
    }
    .padding()
    .background(AppBackground())
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/MobileViews.swift
```swift
//
//  MobileViews.swift
//  MandarinKit
//
//  iOS-native versions of all views
//

import SwiftUI

#if os(iOS)

// MARK: - Mobile Saved Terms View

struct MobileSavedTermsView: View {
    @ObservedObject private var store = SavedTermsStore.shared
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var searchText = ""
    @State private var showExportSheet = false
    @State private var selectedTerm: SavedTerm?

    private var filteredTerms: [SavedTerm] {
        if searchText.isEmpty {
            return store.terms
        }
        return store.terms.filter { term in
            term.chinese.localizedCaseInsensitiveContains(searchText) ||
            term.pinyin.localizedCaseInsensitiveContains(searchText) ||
            term.definition.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if store.terms.isEmpty {
                emptyState
            } else {
                termsList
            }
        }
        .searchable(text: $searchText, prompt: "Search vocabulary")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !store.terms.isEmpty {
                    Button {
                        showExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            MobileExportSheet(store: store)
        }
        .sheet(item: $selectedTerm) { term in
            NavigationStack {
                AIEnhancedTermDetail(term: term)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Vocabulary",
            systemImage: "bookmark",
            description: Text("Save words from translations to build your vocabulary list.")
        )
    }

    private var termsList: some View {
        List {
            ForEach(filteredTerms) { term in
                Button {
                    selectedTerm = term
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        // Pinyin
                        Text(term.pinyin)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Chinese
                        Text(term.chinese)
                            .font(.title3)
                            .fontWeight(.semibold)

                        // Definition
                        Text(term.definition)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.remove(term: term)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        SpeechService.speak(term.chinese, languageCode: "zh-CN")
                    } label: {
                        Label("Listen", systemImage: "speaker.wave.2")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Mobile Learn View

struct MobileLearnView: View {
    @ObservedObject private var progressStore = LearningProgressStore.shared
    @ObservedObject private var preferences = UserPreferences.shared
    @StateObject private var aiService = AIService.shared

    @State private var currentCardIndex: Int = 0
    @State private var showAnswer: Bool = false
    @State private var sessionCards: [LearningCard] = []
    @State private var sessionComplete: Bool = false
    @State private var showHintSheet = false
    @State private var currentHint: LearningHintResult?
    @State private var isLoadingHint = false

    private var dueCards: [LearningCard] {
        progressStore.getDueCards(from: LearningDeck.cards)
    }

    private var currentCard: LearningCard? {
        guard currentCardIndex < sessionCards.count else { return nil }
        return sessionCards[currentCardIndex]
    }

    var body: some View {
        Group {
            if sessionComplete {
                sessionCompleteView
            } else if sessionCards.isEmpty {
                emptyState
            } else if let card = currentCard {
                flashcardView(card)
            }
        }
        .onAppear {
            if sessionCards.isEmpty {
                sessionCards = Array(dueCards.prefix(preferences.dailyGoal))
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Cards Due",
            systemImage: "rectangle.stack",
            description: Text("Great job! Check back later for more cards to review.")
        )
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("You reviewed \(sessionCards.count) cards")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Start New Session") {
                sessionCards = Array(dueCards.prefix(preferences.dailyGoal))
                currentCardIndex = 0
                sessionComplete = false
                showAnswer = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(dueCards.isEmpty)
        }
        .padding()
    }

    private func flashcardView(_ card: LearningCard) -> some View {
        VStack(spacing: 0) {
            // Progress
            ProgressView(value: Double(currentCardIndex), total: Double(sessionCards.count))
                .padding(.horizontal)
                .padding(.top)

            Text("\(currentCardIndex + 1) of \(sessionCards.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            // Card
            VStack(spacing: 20) {
                // Chinese text with pinyin
                VStack(spacing: 8) {
                    if preferences.showPinyin {
                        Text(PinyinConverter.convert(card.chinese, includeToneMarks: preferences.showToneMarks))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(card.chinese)
                        .font(.system(size: 36, weight: .bold))
                }

                if showAnswer {
                    Divider()
                        .padding(.horizontal, 40)

                    Text(card.english)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // AI Hint button
                    if aiService.isAvailable {
                        Button {
                            Task { await loadHintForCard(card) }
                        } label: {
                            HStack(spacing: 6) {
                                if isLoadingHint {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text("Need a hint?")
                            }
                            .font(.subheadline)
                        }
                        .foregroundStyle(.tint)
                        .padding(.top, 8)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            // Actions
            if showAnswer {
                ratingButtons(card)
            } else {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showAnswer = true
                    }
                    HapticFeedback.light()
                } label: {
                    Text("Show Answer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showHintSheet) {
            if let hint = currentHint {
                MobileLearningHintSheet(hint: hint)
            }
        }
    }

    private func ratingButtons(_ card: LearningCard) -> some View {
        HStack(spacing: 12) {
            // Again (Hard)
            Button {
                rateCard(card, quality: .hard)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                    Text("Again")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Good
            Button {
                rateCard(card, quality: .good)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.title2)
                    Text("Good")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Easy
            Button {
                rateCard(card, quality: .easy)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                    Text("Easy")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(Color.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func rateCard(_ card: LearningCard, quality: ReviewQuality) {
        let correct = quality.rawValue >= 3
        progressStore.recordReview(cardId: card.id, correct: correct, quality: quality)
        HapticFeedback.medium()

        withAnimation {
            showAnswer = false
            if currentCardIndex + 1 >= sessionCards.count {
                sessionComplete = true
                HapticFeedback.success()
            } else {
                currentCardIndex += 1
            }
        }
    }

    private func loadHintForCard(_ card: LearningCard) async {
        isLoadingHint = true
        let pinyin = PinyinConverter.convert(card.chinese, includeToneMarks: true)
        let result = await aiService.getLearningHint(
            chinese: card.chinese,
            pinyin: pinyin,
            english: card.english
        )

        await MainActor.run {
            switch result {
            case .success(let hint):
                currentHint = hint
                showHintSheet = true
            case .failure:
                break
            }
            isLoadingHint = false
        }
    }
}

// MARK: - Mobile Learning Hint Sheet

private struct MobileLearningHintSheet: View {
    let hint: LearningHintResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Memory Trick") {
                    Text(hint.mnemonic)
                }

                Section("Usage Context") {
                    Text(hint.usageContext)
                }

                Section("Pronunciation Tip") {
                    Text(hint.pronunciationTip)
                }
            }
            .navigationTitle("Learning Hint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Mobile History View

struct MobileHistoryView: View {
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @Binding var selectedTab: Int
    @State private var searchText = ""

    private var filteredEntries: [TranslationHistoryEntry] {
        if searchText.isEmpty {
            return historyStore.entries
        }
        return historyStore.entries.filter { entry in
            entry.source.localizedCaseInsensitiveContains(searchText) ||
            entry.target.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if historyStore.entries.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text("Your translations will appear here.")
                )
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        Button {
                            historyStore.selectedEntry = entry
                            selectedTab = 0 // Navigate to Translate tab
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                // Direction indicator
                                Text(entry.direction.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                // Source
                                Text(entry.source)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                // Target
                                Text(entry.target)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                // Time
                                Text(entry.date, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                historyStore.remove(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .searchable(text: $searchText, prompt: "Search history")
        .toolbar {
            if !historyStore.entries.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        historyStore.clear()
                    } label: {
                        Text("Clear All")
                    }
                }
            }
        }
    }
}

// MARK: - Mobile Phrase Collection View

struct MobilePhraseCollectionView: View {
    @ObservedObject private var store = PhraseCollectionStore.shared
    @State private var selectedCategory: PhraseCategory?

    var body: some View {
        List {
            // Favorites section
            if !store.favoritePhrases.isEmpty {
                Section("Favorites") {
                    ForEach(store.favoritePhrases) { phrase in
                        PhraseRowMobile(phrase: phrase, isFavorite: true)
                    }
                }
            }

            // Categories
            Section("Categories") {
                ForEach(PhraseCategory.allCases) { category in
                    NavigationLink {
                        PhraseCategoryDetailView(category: category)
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .frame(width: 30)
                                .foregroundStyle(.tint)

                            Text(category.rawValue)

                            Spacer()

                            Text("\(category.phrases.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct PhraseCategoryDetailView: View {
    let category: PhraseCategory
    @ObservedObject private var store = PhraseCollectionStore.shared

    var body: some View {
        List {
            ForEach(category.phrases) { phrase in
                PhraseRowMobile(
                    phrase: phrase,
                    isFavorite: store.isFavorite(phrase)
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.rawValue)
    }
}

private struct PhraseRowMobile: View {
    let phrase: Phrase
    let isFavorite: Bool
    @ObservedObject private var store = PhraseCollectionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Pinyin
            Text(phrase.pinyin)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Chinese
            Text(phrase.chinese)
                .font(.body)
                .fontWeight(.medium)

            // English
            Text(phrase.english)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                SpeechService.speak(phrase.chinese, languageCode: "zh-CN")
            } label: {
                Label("Listen", systemImage: "speaker.wave.2")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button {
                store.toggleFavorite(phrase)
            } label: {
                Label(isFavorite ? "Unfavorite" : "Favorite", systemImage: isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
    }
}

// MARK: - Mobile Statistics View

struct MobileStatisticsView: View {
    @ObservedObject private var progressStore = LearningProgressStore.shared
    @ObservedObject private var savedTermsStore = SavedTermsStore.shared
    @ObservedObject private var phraseStore = PhraseCollectionStore.shared
    @ObservedObject private var preferences = UserPreferences.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    private var stats: LearningStats {
        progressStore.getStats()
    }

    var body: some View {
        List {
            // Quick Stats
            Section("Overview") {
                StatRowMobile(title: "Translations", value: "\(historyStore.entries.count)", icon: "character.bubble", color: .blue)
                StatRowMobile(title: "Cards Reviewed", value: "\(stats.totalReviews)", icon: "rectangle.stack", color: .orange)
                StatRowMobile(title: "Vocabulary", value: "\(savedTermsStore.terms.count)", icon: "bookmark", color: .green)
                StatRowMobile(title: "Favorite Phrases", value: "\(phraseStore.favoritePhrases.count)", icon: "star", color: .yellow)
            }

            // Streak
            Section("Streak") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(preferences.currentStreak) days")
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Best")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(preferences.longestStreak) days")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Learning Progress
            Section("Learning Progress") {
                let allCards = LearningDeck.cards
                let masteredCount = progressStore.getMasteredCount(from: allCards)
                let learningCount = progressStore.getLearningCount(from: allCards)
                let totalCards = allCards.count
                let newCount = totalCards - masteredCount - learningCount

                HStack {
                    ProgressLabel(title: "New", count: newCount, color: .blue)
                    Spacer()
                    ProgressLabel(title: "Learning", count: learningCount, color: .orange)
                    Spacer()
                    ProgressLabel(title: "Mastered", count: masteredCount, color: .green)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct StatRowMobile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundStyle(color)

            Text(title)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProgressLabel: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Mobile Export Sheet

struct MobileExportSheet: View {
    @ObservedObject var store: SavedTermsStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: SavedTermsStore.ExportFormat = .csv
    @State private var previewText = ""
    @State private var showCopiedFeedback = false

    var body: some View {
        NavigationStack {
            List {
                Section("Format") {
                    Picker("Export Format", selection: $selectedFormat) {
                        ForEach(SavedTermsStore.ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedFormat) { _, _ in
                        updatePreview()
                    }
                }

                Section("Preview") {
                    Text(previewText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(10)
                }

                Section {
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack {
                            Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            Text(showCopiedFeedback ? "Copied!" : "Copy to Clipboard")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Export Vocabulary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                updatePreview()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func updatePreview() {
        previewText = store.export(format: selectedFormat)
    }

    private func copyToClipboard() {
        let exportedData = store.export(format: selectedFormat)
        UIPasteboard.general.string = exportedData

        withAnimation {
            showCopiedFeedback = true
        }
        HapticFeedback.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}

#endif

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/StatisticsView.swift
```swift
//
//  StatisticsView.swift
//  MandarinKit
//
//  Dashboard showing learning statistics and progress
//

import SwiftUI

struct StatisticsView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @ObservedObject private var progressStore = LearningProgressStore.shared
    @ObservedObject private var savedTermsStore = SavedTermsStore.shared
    @ObservedObject private var phraseStore = PhraseCollectionStore.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Main stats grid
                statsGrid

                // Streak and daily progress
                streakSection

                // Learning progress
                learningProgressSection

                // Activity chart placeholder
                activitySection
            }
            .padding(20)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Text("Track your Mandarin learning journey")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Reset button
            Button {
                preferences.resetStats()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.custom("Avenir Next", size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            StatCard(
                title: "Translations",
                value: "\(preferences.totalTranslations)",
                icon: "character.bubble",
                color: .blue
            )
            .bounceOnAppear(delay: 0.0)

            StatCard(
                title: "Cards Reviewed",
                value: "\(preferences.totalCardsReviewed)",
                icon: "rectangle.stack",
                color: .green
            )
            .bounceOnAppear(delay: 0.05)

            StatCard(
                title: "Vocabulary",
                value: "\(savedTermsStore.terms.count)",
                icon: "bookmark.fill",
                color: .orange
            )
            .bounceOnAppear(delay: 0.1)

            StatCard(
                title: "Favorite Phrases",
                value: "\(phraseStore.favoritePhrases.count)",
                icon: "star.fill",
                color: .yellow
            )
            .bounceOnAppear(delay: 0.15)
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 20) {
            // Current streak
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(preferences.currentStreak)")
                            .font(.custom("Avenir Next Demi Bold", size: 36))
                        Text("Day Streak")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                if preferences.currentStreak > 0 {
                    Text(streakMessage)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.orange.opacity(0.1))
            )

            // Longest streak
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(preferences.longestStreak)")
                            .font(.custom("Avenir Next Demi Bold", size: 36))
                        Text("Best Streak")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(.secondary)
                    }
                }

                if preferences.longestStreak > 0 {
                    Text("Your personal record!")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.yellow.opacity(0.1))
            )

            // Daily goal progress
            VStack(spacing: 12) {
                let stats = progressStore.getStats()
                let progress = min(Double(stats.todayReviewed) / Double(preferences.dailyGoal), 1.0)

                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress >= 1.0 ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(stats.todayReviewed)")
                            .font(.custom("Avenir Next Demi Bold", size: 24))
                        Text("/ \(preferences.dailyGoal)")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                Text("Daily Goal")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.blue.opacity(0.1))
            )
        }
    }

    // MARK: - Learning Progress Section

    private var learningProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learning Progress")
                .font(.custom("Avenir Next Demi Bold", size: 18))

            let stats = progressStore.getStats()
            let allCards = LearningDeck.cards
            let masteredCount = progressStore.getMasteredCount(from: allCards)
            let learningCount = progressStore.getLearningCount(from: allCards)
            let newCount = allCards.count - masteredCount - learningCount

            HStack(spacing: 16) {
                ProgressStatCard(
                    title: "New",
                    count: newCount,
                    total: allCards.count,
                    color: .blue,
                    icon: "plus.circle"
                )

                ProgressStatCard(
                    title: "Learning",
                    count: learningCount,
                    total: allCards.count,
                    color: .orange,
                    icon: "book"
                )

                ProgressStatCard(
                    title: "Mastered",
                    count: masteredCount,
                    total: allCards.count,
                    color: .green,
                    icon: "checkmark.seal"
                )
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Mastered
                        if masteredCount > 0 {
                            Rectangle()
                                .fill(.green)
                                .frame(width: geometry.size.width * CGFloat(masteredCount) / CGFloat(allCards.count))
                        }
                        // Learning
                        if learningCount > 0 {
                            Rectangle()
                                .fill(.orange)
                                .frame(width: geometry.size.width * CGFloat(learningCount) / CGFloat(allCards.count))
                        }
                        // New
                        if newCount > 0 {
                            Rectangle()
                                .fill(.blue.opacity(0.3))
                                .frame(width: geometry.size.width * CGFloat(newCount) / CGFloat(allCards.count))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 8)

                HStack {
                    Text("\(allCards.count) total cards in deck")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if stats.dueCount > 0 {
                        Text("\(stats.dueCount) due for review")
                            .font(.custom("Avenir Next Demi Bold", size: 12))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.custom("Avenir Next Demi Bold", size: 18))

                Spacer()

                if let lastDate = preferences.lastPracticeDate {
                    Text("Last practice: \(lastDate, style: .relative)")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.tertiary)
                }
            }

            // Activity indicators (simplified week view)
            HStack(spacing: 8) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(checkActivityOnDate(date) ? Color.green : Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Text(dayLabel(for: date))
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Helper Properties

    private var weekDates: [Date] {
        (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: -6 + dayOffset, to: Date())
        }
    }

    private var streakMessage: String {
        switch preferences.currentStreak {
        case 1: return "Great start! Keep it up!"
        case 2...6: return "You're building momentum!"
        case 7...13: return "A full week! Amazing!"
        case 14...29: return "Two weeks strong! 💪"
        case 30...59: return "One month! Incredible!"
        case 60...89: return "Two months! You're dedicated!"
        case 90...: return "90+ days! You're a champion! 🏆"
        default: return ""
        }
    }

    private func checkActivityOnDate(_ date: Date) -> Bool {
        guard let lastPractice = preferences.lastPracticeDate else { return false }
        return Calendar.current.isDate(lastPractice, inSameDayAs: date) ||
               Calendar.current.compare(lastPractice, to: date, toGranularity: .day) == .orderedDescending
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)

                Spacer()
            }

            Text(value)
                .font(.custom("Avenir Next Demi Bold", size: 28))

            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Progress Stat Card

private struct ProgressStatCard: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text("\(count)")
                .font(.custom("Avenir Next Demi Bold", size: 24))

            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.secondary)

            Text("\(percentage)%")
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(Double(count) / Double(total) * 100)
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .environmentObject(TranslationHistoryStore())
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/SavedTermsView.swift
```swift
//
//  SavedTermsView.swift
//  MandarinKit
//
//  View for displaying saved vocabulary terms with sortable list
//

import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct SavedTermsView: View {
    @ObservedObject private var store = SavedTermsStore.shared
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var searchText = ""
    @State private var showCopiedFeedback: UUID?
    @State private var hoveredTerm: UUID?
    @State private var viewMode: ViewMode = .list
    @State private var showExportSheet = false
    @State private var exportFormat: SavedTermsStore.ExportFormat = .csv
    @State private var selectedTermForDetail: SavedTerm?

    private enum ViewMode: String, CaseIterable {
        case list, grid

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }

    private var filteredTerms: [SavedTerm] {
        if searchText.isEmpty {
            return store.terms
        }
        return store.terms.filter { term in
            term.chinese.localizedCaseInsensitiveContains(searchText) ||
            term.pinyin.localizedCaseInsensitiveContains(searchText) ||
            term.definition.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            headerBar

            if store.terms.isEmpty {
                emptyState
            } else if filteredTerms.isEmpty {
                noResultsState
            } else {
                switch viewMode {
                case .list:
                    listView
                case .grid:
                    gridView
                }
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.custom("Avenir Next", size: 13))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 200)

            Spacer()

            // View mode toggle
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Term count
            Text("\(store.terms.count)")
                .font(.custom("Avenir Next Demi Bold", size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.5))
                .clipShape(Capsule())

            // Export button
            if !store.terms.isEmpty {
                Button {
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Export vocabulary")
            }

            // Clear all button
            if !store.terms.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.clear()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.7))
                .help("Clear all saved terms")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showExportSheet) {
            ExportVocabularySheet(store: store)
        }
        .sheet(item: $selectedTermForDetail) { term in
            AIEnhancedTermDetail(term: term)
        }
    }

    // MARK: - List View

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredTerms) { term in
                    CompactTermRow(
                        term: term,
                        isHovered: hoveredTerm == term.id,
                        showCopiedFeedback: showCopiedFeedback == term.id,
                        onCopy: { copyTerm(term) },
                        onListen: { SpeechService.speak(term.chinese, languageCode: "zh-CN") },
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.remove(term: term)
                            }
                        },
                        onTap: { selectedTermForDetail = term }
                    )
                    .onHover { isHovered in
                        hoveredTerm = isHovered ? term.id : nil
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 12)
            ], spacing: 12) {
                ForEach(filteredTerms) { term in
                    GridTermCard(
                        term: term,
                        isHovered: hoveredTerm == term.id,
                        showCopiedFeedback: showCopiedFeedback == term.id,
                        onCopy: { copyTerm(term) },
                        onListen: { SpeechService.speak(term.chinese, languageCode: "zh-CN") },
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.remove(term: term)
                            }
                        },
                        onTap: { selectedTermForDetail = term }
                    )
                    .onHover { isHovered in
                        hoveredTerm = isHovered ? term.id : nil
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "bookmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No Saved Terms")
                .font(.custom("Avenir Next Demi Bold", size: 17))

            Text("Tap any word in a translation\nto save it to your vocabulary")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)

            Text("No Results")
                .font(.custom("Avenir Next Demi Bold", size: 15))

            Text("No terms match \"\(searchText)\"")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copyTerm(_ term: SavedTerm) {
        let text = "\(term.chinese) (\(term.pinyin)) - \(term.definition)"
        ClipboardService.copy(text)
        showCopiedFeedback = term.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedFeedback = nil
        }
    }
}

// MARK: - Compact Term Row (List View)

private struct CompactTermRow: View {
    let term: SavedTerm
    let isHovered: Bool
    let showCopiedFeedback: Bool
    let onCopy: () -> Void
    let onListen: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Chinese + Pinyin (left side)
            VStack(alignment: .leading, spacing: 1) {
                Text(term.pinyin)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(.secondary)

                Text(term.chinese)
                    .font(.custom("Avenir Next Demi Bold", size: 22))
            }
            .frame(minWidth: 80, alignment: .leading)

            // Definition (center, expandable)
            VStack(alignment: .leading, spacing: 2) {
                if !term.definition.isEmpty {
                    Text(term.definition)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                // Part of speech + date
                HStack(spacing: 8) {
                    Text(term.partOfSpeech)
                        .font(.custom("Avenir Next", size: 10))
                        .foregroundStyle(partOfSpeechColor)

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Text(relativeDate)
                        .font(.custom("Avenir Next", size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions (right side, shown on hover)
            HStack(spacing: 8) {
                ActionButton(icon: "speaker.wave.2", action: onListen)
                ActionButton(
                    icon: showCopiedFeedback ? "checkmark" : "doc.on.doc",
                    color: showCopiedFeedback ? .green : .secondary,
                    action: onCopy
                )
                ActionButton(icon: "trash", color: .red.opacity(0.7), action: onDelete)
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: term.dateAdded, relativeTo: Date())
    }

    private var partOfSpeechColor: Color {
        switch term.partOfSpeech.lowercased() {
        case "noun": return .blue
        case "verb": return .red
        case "adjective": return .green
        case "adverb": return .orange
        case "pronoun": return .purple
        case "preposition": return .cyan
        case "conjunction": return .mint
        default: return .secondary
        }
    }
}

// MARK: - Grid Term Card

private struct GridTermCard: View {
    let term: SavedTerm
    let isHovered: Bool
    let showCopiedFeedback: Bool
    let onCopy: () -> Void
    let onListen: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Chinese + Actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(term.pinyin)
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(.secondary)

                    Text(term.chinese)
                        .font(.custom("Avenir Next Demi Bold", size: 26))
                }

                Spacer()

                // Actions overlay
                if isHovered {
                    HStack(spacing: 4) {
                        ActionButton(icon: "speaker.wave.2", size: 11, action: onListen)
                        ActionButton(
                            icon: showCopiedFeedback ? "checkmark" : "doc.on.doc",
                            size: 11,
                            color: showCopiedFeedback ? .green : .secondary,
                            action: onCopy
                        )
                        ActionButton(icon: "trash", size: 11, color: .red.opacity(0.7), action: onDelete)
                    }
                }
            }

            // Definition
            if !term.definition.isEmpty {
                Text(term.definition)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)

            // Footer: POS badge + date
            HStack {
                Text(term.partOfSpeech)
                    .font(.custom("Avenir Next", size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(partOfSpeechColor.opacity(0.12))
                    .foregroundStyle(partOfSpeechColor)
                    .clipShape(Capsule())

                Spacer()

                Text(relativeDate)
                    .font(.custom("Avenir Next", size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onTapGesture {
            onTap()
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: term.dateAdded, relativeTo: Date())
    }

    private var partOfSpeechColor: Color {
        switch term.partOfSpeech.lowercased() {
        case "noun": return .blue
        case "verb": return .red
        case "adjective": return .green
        case "adverb": return .orange
        case "pronoun": return .purple
        case "preposition": return .cyan
        case "conjunction": return .mint
        default: return .secondary
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    var size: CGFloat = 12
    var color: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Vocabulary Sheet

private struct ExportVocabularySheet: View {
    @ObservedObject var store: SavedTermsStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: SavedTermsStore.ExportFormat = .csv
    @State private var previewText = ""
    @State private var showCopiedFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Vocabulary")
                    .font(.custom("Avenir Next Demi Bold", size: 18))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 20) {
                // Format picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Format")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .foregroundStyle(.secondary)

                    Picker("Format", selection: $selectedFormat) {
                        ForEach(SavedTermsStore.ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedFormat) { _, _ in
                        updatePreview()
                    }
                }

                // Format description
                HStack(spacing: 8) {
                    Image(systemName: formatIcon)
                        .foregroundStyle(.secondary)
                    Text(formatDescription)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Preview")
                            .font(.custom("Avenir Next Demi Bold", size: 13))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(store.terms.count) terms")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    ScrollView {
                        Text(previewText)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 150)
                    .padding(12)
                    .background(.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Action buttons
                HStack(spacing: 12) {
                    // Copy to clipboard
                    Button {
                        let exportedText = store.export(format: selectedFormat)
                        ClipboardService.copy(exportedText)
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedFeedback = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            Text(showCopiedFeedback ? "Copied!" : "Copy to Clipboard")
                        }
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(showCopiedFeedback ? Color.green : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    #if os(macOS)
                    // Save to file (macOS only)
                    Button {
                        saveToFile()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save File")
                        }
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    #endif
                }
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .onAppear {
            updatePreview()
        }
    }

    private var formatIcon: String {
        switch selectedFormat {
        case .csv: return "tablecells"
        case .anki: return "rectangle.stack"
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        }
    }

    private var formatDescription: String {
        switch selectedFormat {
        case .csv:
            return "Comma-separated values. Compatible with Excel, Google Sheets, and most spreadsheet apps."
        case .anki:
            return "Tab-separated format optimized for Anki flashcard import. Front: Chinese + Pinyin, Back: Definition."
        case .markdown:
            return "Formatted table for documentation, notes, or sharing. Works with any Markdown viewer."
        case .json:
            return "Structured data format. Useful for developers or backing up your vocabulary."
        }
    }

    private func updatePreview() {
        let fullExport = store.export(format: selectedFormat)
        // Show first 500 characters of preview
        if fullExport.count > 500 {
            previewText = String(fullExport.prefix(500)) + "\n..."
        } else {
            previewText = fullExport
        }
    }

    #if os(macOS)
    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "vocabulary.\(selectedFormat.fileExtension)"
        savePanel.title = "Export Vocabulary"
        savePanel.message = "Choose where to save your vocabulary"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let exportedText = store.export(format: selectedFormat)
                try? exportedText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    #endif
}

#Preview {
    SavedTermsView()
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/LearnView.swift
```swift
//
//  LearnView.swift
//  MandarinKit
//
//  Clean, focused flashcard learning view
//

import SwiftUI

struct LearnView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @ObservedObject private var progressStore = LearningProgressStore.shared
    @StateObject private var aiService = AIService.shared

    @State private var currentCardIndex: Int = 0
    @State private var showAnswer: Bool = false
    @State private var sessionCards: [LearningCard] = []
    @State private var sessionComplete = false
    @State private var showHintSheet = false
    @State private var currentHint: LearningHintResult?
    @State private var isLoadingHint = false

    private var allCards: [LearningCard] {
        LearningDeck.cards
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            if sessionCards.isEmpty {
                emptyState
            } else if sessionComplete {
                completionState
            } else {
                // Main flashcard area
                flashcardView
            }
        }
        .onAppear {
            loadSession()
        }
        .sheet(isPresented: $showHintSheet) {
            if let hint = currentHint, let card = currentCard {
                LearningHintSheet(card: card, hint: hint)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                if !sessionCards.isEmpty && !sessionComplete {
                    Text("\(currentCardIndex + 1) of \(sessionCards.count)")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                }

                Spacer()

                let stats = progressStore.getStats()
                Text("\(stats.todayReviewed) reviewed today")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(.secondary)
            }

            if !sessionCards.isEmpty && !sessionComplete {
                ProgressView(value: Double(currentCardIndex), total: Double(sessionCards.count))
                    .tint(AppTheme.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Flashcard View

    private var flashcardView: some View {
        VStack(spacing: 0) {
            Spacer()

            // The card
            VStack(spacing: 24) {
                if let card = currentCard {
                    // Chinese with pinyin - using InteractiveChineseText for tappable words
                    InteractiveChineseText(
                        text: card.chinese,
                        showPinyin: preferences.showPinyin && (showAnswer || !preferences.showPinyin),
                        showToneMarks: preferences.showToneMarks,
                        characterFont: .custom("Avenir Next Demi Bold", size: 48),
                        pinyinFont: .custom("Avenir Next", size: 14),
                        spacing: 8
                    )

                    // Listen button
                    Button {
                        SpeechService.speak(card.chinese, languageCode: "zh-CN")
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Divider()
                        .frame(width: 100)

                    // Answer
                    if showAnswer {
                        VStack(spacing: 12) {
                            Text(card.english)
                                .font(.custom("Avenir Next", size: 24))
                                .multilineTextAlignment(.center)

                            if let notes = card.notes {
                                Text(notes)
                                    .font(.custom("Avenir Next", size: 14))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            // AI Hint Button
                            if aiService.isAvailable {
                                Button {
                                    Task { await loadHintForCard(card) }
                                } label: {
                                    HStack(spacing: 6) {
                                        if isLoadingHint {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text("Need a hint?")
                                    }
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(AppTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingHint)
                                .padding(.top, 8)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showAnswer = true
                            }
                        } label: {
                            Text("Tap to reveal")
                                .font(.custom("Avenir Next", size: 16))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 500)

            Spacer()

            // Rating buttons (only when answer shown)
            if showAnswer {
                ratingButtons
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if !showAnswer {
                withAnimation(.easeOut(duration: 0.2)) {
                    showAnswer = true
                }
            }
        }
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        HStack(spacing: 16) {
            RatingButton(label: "Again", color: .red) {
                recordAndAdvance(quality: .hard)
            }

            RatingButton(label: "Good", color: .blue) {
                recordAndAdvance(quality: .good)
            }

            RatingButton(label: "Easy", color: .green) {
                recordAndAdvance(quality: .easy)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .bounceOnAppear()

            Text("All caught up!")
                .font(.custom("Avenir Next Demi Bold", size: 24))
                .fadeInOnAppear(delay: 0.1)

            Text("No cards due for review right now")
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(.secondary)
                .fadeInOnAppear(delay: 0.2)

            Button {
                HapticFeedback.light()
                sessionCards = allCards.shuffled()
                currentCardIndex = 0
                showAnswer = false
                sessionComplete = false
            } label: {
                Text("Practice All Cards")
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.pressable)
            .fadeInOnAppear(delay: 0.3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Completion State

    private var completionState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
                .bounceOnAppear()

            Text("Session Complete!")
                .font(.custom("Avenir Next Demi Bold", size: 28))
                .fadeInOnAppear(delay: 0.1)

            let stats = progressStore.getStats()
            Text("You've reviewed \(stats.todayReviewed) cards today")
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(.secondary)
                .fadeInOnAppear(delay: 0.2)

            HStack(spacing: 16) {
                Button {
                    HapticFeedback.success()
                    loadSession()
                } label: {
                    Text("Continue")
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.pressable)

                Button {
                    HapticFeedback.light()
                    sessionCards = allCards.shuffled()
                    currentCardIndex = 0
                    showAnswer = false
                    sessionComplete = false
                } label: {
                    Text("Practice All")
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.pressable)
            }
            .fadeInOnAppear(delay: 0.3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var currentCard: LearningCard? {
        guard currentCardIndex >= 0 && currentCardIndex < sessionCards.count else { return nil }
        return sessionCards[currentCardIndex]
    }

    private func loadSession() {
        sessionCards = progressStore.getCardsForReview(from: allCards, limit: 20)
        if sessionCards.isEmpty {
            sessionCards = [] // Keep empty to show empty state
        }
        currentCardIndex = 0
        showAnswer = false
        sessionComplete = false
    }

    private func recordAndAdvance(quality: ReviewQuality) {
        guard let card = currentCard else { return }

        let correct = quality.rawValue >= 3
        progressStore.recordReview(cardId: card.id, correct: correct, quality: quality)

        // Clear any hint when moving to next card
        currentHint = nil

        // Advance to next card
        if currentCardIndex < sessionCards.count - 1 {
            withAnimation(AppAnimation.gentleSpring) {
                currentCardIndex += 1
                showAnswer = false
            }
        } else {
            HapticFeedback.success()
            withAnimation(AppAnimation.standard) {
                sessionComplete = true
            }
        }
    }

    private func loadHintForCard(_ card: LearningCard) async {
        isLoadingHint = true

        // Generate pinyin from Chinese characters
        let pinyin = PinyinConverter.convert(card.chinese, includeToneMarks: true)

        let result = await aiService.getLearningHint(
            chinese: card.chinese,
            pinyin: pinyin,
            english: card.english
        )

        await MainActor.run {
            switch result {
            case .success(let hint):
                currentHint = hint
                showHintSheet = true
            case .failure:
                // Silently fail - the button just won't do anything
                break
            }
            isLoadingHint = false
        }
    }
}

// MARK: - Learning Hint Sheet

private struct LearningHintSheet: View {
    let card: LearningCard
    let hint: LearningHintResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Learning Hints")
                        .font(.custom("Avenir Next Demi Bold", size: 18))
                    Text(card.chinese)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Hints
            VStack(spacing: 16) {
                HintRow(
                    icon: "brain.head.profile",
                    title: "Memory Trick",
                    content: hint.mnemonic,
                    color: .purple
                )

                HintRow(
                    icon: "bubble.left.and.bubble.right",
                    title: "When to Use",
                    content: hint.usageContext,
                    color: .blue
                )

                HintRow(
                    icon: "waveform",
                    title: "Pronunciation",
                    content: hint.pronunciationTip,
                    color: .green
                )
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Got it!")
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 400, height: 450)
        .background(.ultraThinMaterial)
    }
}

private struct HintRow: View {
    let icon: String
    let title: String
    let content: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .foregroundStyle(color)

                Text(content)
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Rating Button

private struct RatingButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            HapticFeedback.medium()
            action()
        } label: {
            Text(label)
                .font(.custom("Avenir Next Demi Bold", size: 15))
                .frame(minWidth: 80)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(AppAnimation.quick) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    LearnView()
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/InteractiveChineseText.swift
```swift
//
//  InteractiveChineseText.swift
//  MandarinKit
//
//  Displays Chinese text with word segmentation and tappable words
//  Uses Natural Language framework for intelligent word boundaries
//

import SwiftUI

#if canImport(Translation)
import Translation
#endif

/// Interactive Chinese text display with tappable words
/// Each word can be tapped to show a detail popover with pinyin, translation, and more
struct InteractiveChineseText: View {
    let text: String
    let showPinyin: Bool
    let showToneMarks: Bool
    var characterFont: Font = .custom("Avenir Next Demi Bold", size: 28)
    var pinyinFont: Font = .custom("Avenir Next", size: 11)
    var spacing: CGFloat = 6
    var characterColor: Color = .primary
    var pinyinColor: Color = .secondary
    var showPartOfSpeechColors: Bool = false
    var showToneColors: Bool? = nil // nil = use preference

    @State private var selectedWord: AnalyzedWord?
    @State private var words: [AnalyzedWord] = []
    @ObservedObject private var preferences = UserPreferences.shared

    private let analyzer = ChineseTextAnalyzer.shared

    /// Whether to show tone colors based on explicit setting or user preference
    private var shouldShowToneColors: Bool {
        showToneColors ?? preferences.showToneColors
    }

    var body: some View {
        WrappingHStack(alignment: .bottom, spacing: spacing) {
            ForEach(words) { word in
                InteractiveWordView(
                    word: word,
                    showPinyin: showPinyin,
                    showToneMarks: showToneMarks,
                    showToneColors: shouldShowToneColors,
                    characterFont: characterFont,
                    pinyinFont: pinyinFont,
                    characterColor: showPartOfSpeechColors ? word.partOfSpeech.color : characterColor,
                    pinyinColor: pinyinColor,
                    isSelected: selectedWord?.id == word.id
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if selectedWord?.id == word.id {
                            selectedWord = nil
                        } else {
                            selectedWord = word
                        }
                    }
                }
                .popover(isPresented: Binding(
                    get: { selectedWord?.id == word.id },
                    set: { if !$0 { selectedWord = nil } }
                )) {
                    WordDetailPopover(word: word, showToneMarks: showToneMarks)
                }
            }
        }
        .onAppear {
            analyzeText()
        }
        .onChange(of: text) { _, _ in
            analyzeText()
        }
    }

    private func analyzeText() {
        // Use Natural Language framework for word segmentation
        words = analyzer.segmentWithPartsOfSpeech(text)
    }
}

// MARK: - Interactive Word View

private struct InteractiveWordView: View {
    let word: AnalyzedWord
    let showPinyin: Bool
    let showToneMarks: Bool
    let showToneColors: Bool
    let characterFont: Font
    let pinyinFont: Font
    let characterColor: Color
    let pinyinColor: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            // Pinyin above
            if showPinyin && word.text.contains(where: { $0.isChineseCharacter }) {
                if showToneColors {
                    // Use colored pinyin
                    Text(PinyinConverter.coloredPinyin(word.text, includeToneMarks: showToneMarks))
                        .font(pinyinFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(pinyinForWord)
                        .font(pinyinFont)
                        .foregroundStyle(pinyinColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else if showPinyin {
                // Spacer to maintain alignment
                Text(" ")
                    .font(pinyinFont)
                    .opacity(0)
            }

            // Word below
            Text(word.text)
                .font(characterFont)
                .foregroundStyle(characterColor)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var pinyinForWord: String {
        PinyinConverter.convert(word.text, includeToneMarks: showToneMarks)
    }
}

// MARK: - Word Detail Popover

private struct WordDetailPopover: View {
    let word: AnalyzedWord
    let showToneMarks: Bool

    @ObservedObject private var savedTermsStore = SavedTermsStore.shared
    @State private var showCopiedFeedback = false
    @State private var showSavedFeedback = false
    @State private var definition: String?
    @State private var isLoadingDefinition = false

    private var isAlreadySaved: Bool {
        savedTermsStore.contains(chinese: word.text)
    }

    #if canImport(Translation)
    @State private var translationConfig: TranslationSession.Configuration?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with word and pinyin
            VStack(alignment: .leading, spacing: 4) {
                Text(word.text)
                    .font(.custom("Avenir Next Demi Bold", size: 32))

                Text(PinyinConverter.convert(word.text, includeToneMarks: showToneMarks))
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Definition section
            if word.text.contains(where: { $0.isChineseCharacter }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Definition")
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(.tertiary)

                    if isLoadingDefinition {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading...")
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(.secondary)
                        }
                    } else if let definition = definition {
                        Text(definition)
                            .font(.custom("Avenir Next", size: 16))
                            .foregroundStyle(.primary)
                    } else {
                        Text("Definition unavailable")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()
            }

            // Part of speech
            HStack(spacing: 6) {
                Circle()
                    .fill(word.partOfSpeech.color)
                    .frame(width: 8, height: 8)
                Text(word.partOfSpeech.displayName)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(.secondary)
            }

            // Character breakdown for multi-character words
            if word.text.count > 1 && word.text.contains(where: { $0.isChineseCharacter }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Characters")
                        .font(.custom("Avenir Next", size: 11))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 12) {
                        ForEach(Array(word.text.enumerated()), id: \.offset) { _, char in
                            if char.isChineseCharacter {
                                VStack(spacing: 2) {
                                    Text(String(char))
                                        .font(.custom("Avenir Next Demi Bold", size: 18))
                                    Text(PinyinConverter.convert(String(char), includeToneMarks: showToneMarks))
                                        .font(.custom("Avenir Next", size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    SpeechService.speak(word.text, languageCode: "zh-CN")
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2")
                        .font(.custom("Avenir Next", size: 12))
                }
                .buttonStyle(.plain)

                Button {
                    ClipboardService.copy(word.text)
                    showCopiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedFeedback = false
                    }
                } label: {
                    Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.custom("Avenir Next", size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                // Save to vocabulary list button
                Button {
                    if !isAlreadySaved {
                        let pinyin = PinyinConverter.convert(word.text, includeToneMarks: showToneMarks)
                        savedTermsStore.add(
                            chinese: word.text,
                            pinyin: pinyin,
                            definition: definition ?? "",
                            partOfSpeech: word.partOfSpeech.displayName
                        )
                        showSavedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showSavedFeedback = false
                        }
                    }
                } label: {
                    Label(
                        isAlreadySaved ? "Saved" : (showSavedFeedback ? "Saved!" : "Save"),
                        systemImage: isAlreadySaved || showSavedFeedback ? "checkmark.circle.fill" : "plus.circle"
                    )
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .foregroundStyle(isAlreadySaved ? .green : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(isAlreadySaved)
            }
        }
        .padding(16)
        .frame(minWidth: 260)
        .onAppear {
            requestDefinition()
        }
        #if canImport(Translation)
        .translationTask(translationConfig) { session in
            await performTranslation(session)
        }
        #endif
    }

    private func requestDefinition() {
        guard word.text.contains(where: { $0.isChineseCharacter }) else { return }

        isLoadingDefinition = true

        #if canImport(Translation)
        // Trigger translation by setting the configuration
        translationConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: "zh-Hans"),
            target: Locale.Language(identifier: "en")
        )
        #else
        isLoadingDefinition = false
        definition = nil
        #endif
    }

    #if canImport(Translation)
    private func performTranslation(_ session: TranslationSession) async {
        do {
            let response = try await session.translate(word.text)
            await MainActor.run {
                definition = response.targetText
                isLoadingDefinition = false
            }
        } catch {
            await MainActor.run {
                definition = nil
                isLoadingDefinition = false
            }
        }
    }
    #endif
}

// MARK: - Convenience Initializers

extension InteractiveChineseText {
    /// Create with default styling for translation output
    static func translation(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> InteractiveChineseText {
        InteractiveChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 32),
            pinyinFont: .custom("Avenir Next", size: 13),
            spacing: 6
        )
    }

    /// Create with smaller styling for inline display
    static func inline(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> InteractiveChineseText {
        InteractiveChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 18),
            pinyinFont: .custom("Avenir Next", size: 9),
            spacing: 4
        )
    }

    /// Create with large styling for flashcard display
    static func card(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> InteractiveChineseText {
        InteractiveChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 48),
            pinyinFont: .custom("Avenir Next", size: 14),
            spacing: 8
        )
    }

    /// Create with part of speech color coding
    static func analyzed(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> InteractiveChineseText {
        InteractiveChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 28),
            pinyinFont: .custom("Avenir Next", size: 11),
            spacing: 6,
            showPartOfSpeechColors: true
        )
    }
}

// MARK: - Preview

#Preview("Interactive Words") {
    VStack(spacing: 30) {
        InteractiveChineseText(
            text: "你好，我叫小明。",
            showPinyin: true,
            showToneMarks: true
        )

        InteractiveChineseText.translation("今天天气很好！")

        InteractiveChineseText.analyzed("我喜欢学习中文。")
    }
    .padding(40)
    .frame(maxWidth: 500)
}

#Preview("Single Word") {
    InteractiveChineseText.card("谢谢")
        .padding(40)
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/MobileTranslateView.swift
```swift
//
//  MobileTranslateView.swift
//  MandarinKit
//
//  Modern iOS 26+ translation view - compact, full-screen, sleek
//

import SwiftUI

#if canImport(Translation)
import Translation
#endif

#if os(iOS)
struct MobileTranslateView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @EnvironmentObject private var historyStore: TranslationHistoryStore

    @State private var inputText: String = ""
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @State private var errorMessage: String?
    @State private var showCopiedFeedback: Bool = false
    @FocusState private var isInputFocused: Bool

    private let textAnalyzer = ChineseTextAnalyzer.shared

    #if canImport(Translation)
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var pendingSourceText: String = ""
    #endif

    private var direction: TranslationDirection {
        preferences.translationDirection
    }

    private var hasInput: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Language selector bar
            languageBar

            Divider()

            // Input section
            inputSection

            Divider()

            // Output section
            outputSection
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            loadSelectedHistoryEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateTo)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadSelectedHistoryEntry()
            }
        }
        #if canImport(Translation)
        .translationTask(translationConfiguration) { session in
            await handleTranslation(session)
        }
        #endif
    }

    // MARK: - Language Bar (Compact)

    private var languageBar: some View {
        HStack(spacing: 0) {
            // Source language
            Button {
                if direction == .chineseToEnglish {
                    swapLanguages()
                }
            } label: {
                Text(direction.sourceLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(direction == .englishToChinese ? Color.accentColor : .primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // Swap button
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Target language
            Button {
                if direction == .englishToChinese {
                    swapLanguages()
                }
            } label: {
                Text(direction.targetLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(direction == .chineseToEnglish ? Color.accentColor : .primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text input
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .focused($isInputFocused)
                    .frame(minHeight: 50, maxHeight: 80)

                if inputText.isEmpty {
                    Text(direction.placeholder)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Action row (compact)
            HStack(spacing: 14) {
                // Paste
                Button {
                    if let text = ClipboardService.paste() {
                        inputText = text
                        HapticFeedback.light()
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.secondary)

                // Speak input
                Button {
                    SpeechService.speak(inputText, languageCode: direction.sourceSpeechLanguageCode)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.secondary)
                .disabled(inputText.isEmpty)

                Spacer()

                // Clear
                if !inputText.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            inputText = ""
                            translatedText = ""
                            errorMessage = nil
                        }
                        HapticFeedback.light()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Translate button (compact)
                Button(action: requestTranslation) {
                    HStack(spacing: 3) {
                        if isTranslating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                        Text(isTranslating ? "..." : "Translate")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(hasInput ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .disabled(!hasInput || isTranslating)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .onChange(of: inputText) { _, newValue in
            autoDetectLanguage(newValue)
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let error = errorMessage {
                    // Error state
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if translatedText.isEmpty {
                    // Empty state
                    VStack(spacing: 6) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 20))
                            .foregroundStyle(.quaternary)
                        Text("Translation appears here")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    // Translation result with interactive words
                    translationResultView
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Translation Result

    @ViewBuilder
    private var translationResultView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Main translation with interactive words
            if direction == .englishToChinese {
                // Chinese result - use InteractiveChineseText for word segmentation
                InteractiveChineseText(
                    text: translatedText,
                    showPinyin: preferences.showPinyin,
                    showToneMarks: preferences.showToneMarks,
                    characterFont: .system(size: 22, weight: .semibold),
                    pinyinFont: .system(size: 10),
                    spacing: 4
                )
            } else {
                // English result
                Text(translatedText)
                    .font(.callout)
                    .textSelection(.enabled)

                // Show original Chinese with interactive words
                if preferences.showPinyin && !inputText.isEmpty {
                    Divider()
                        .padding(.vertical, 4)

                    InteractiveChineseText(
                        text: inputText,
                        showPinyin: true,
                        showToneMarks: preferences.showToneMarks,
                        characterFont: .system(size: 16, weight: .medium),
                        pinyinFont: .system(size: 9),
                        spacing: 3,
                        characterColor: .secondary
                    )
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Actions row (compact, horizontal)
            HStack(spacing: 14) {
                // Copy
                Button {
                    ClipboardService.copy(translatedText)
                    showCopiedFeedback = true
                    HapticFeedback.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedFeedback = false
                    }
                } label: {
                    Label(showCopiedFeedback ? "Copied" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(showCopiedFeedback ? Color.green : Color.accentColor)

                // Speak
                Button {
                    SpeechService.speak(translatedText, languageCode: direction.targetSpeechLanguageCode)
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(Color.accentColor)

                Spacer()

                // Pinyin toggle (horizontal, not wrapped)
                HStack(spacing: 4) {
                    Text("Pinyin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Toggle("", isOn: $preferences.showPinyin)
                        .toggleStyle(.switch)
                        .scaleEffect(0.6)
                        .labelsHidden()
                }
                .fixedSize()
            }
        }
    }

    // MARK: - Actions

    private func swapLanguages() {
        withAnimation(.easeInOut(duration: 0.2)) {
            preferences.translationDirection = direction.toggled()
            let temp = inputText
            inputText = translatedText
            translatedText = temp
        }
        HapticFeedback.light()
    }

    private func loadSelectedHistoryEntry() {
        guard let entry = historyStore.selectedEntry else { return }
        inputText = entry.source
        translatedText = entry.target
        preferences.translationDirection = entry.direction
        errorMessage = nil
        historyStore.selectedEntry = nil
    }

    private func requestTranslation() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isInputFocused = false
        errorMessage = nil
        isTranslating = true
        HapticFeedback.light()

        #if canImport(Translation)
        pendingSourceText = trimmed
        if translationConfiguration == nil {
            translationConfiguration = TranslationSession.Configuration(
                source: direction.sourceLanguage,
                target: direction.targetLanguage
            )
        } else {
            translationConfiguration?.invalidate()
        }
        #else
        translatedText = "(Translation unavailable)"
        isTranslating = false
        #endif
    }

    #if canImport(Translation)
    private func handleTranslation(_ session: TranslationSession) async {
        do {
            let response = try await session.translate(pendingSourceText)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    translatedText = response.targetText
                }
                historyStore.add(source: pendingSourceText, target: response.targetText, direction: direction)
                isTranslating = false
                HapticFeedback.success()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isTranslating = false
                HapticFeedback.error()
            }
        }
    }
    #endif

    private func autoDetectLanguage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        let (language, confidence) = textAnalyzer.detectLanguageWithConfidence(trimmed)
        guard confidence > 0.7 else { return }

        let newDirection: TranslationDirection?
        switch language {
        case .chinese:
            newDirection = .chineseToEnglish
        case .english:
            newDirection = .englishToChinese
        default:
            newDirection = nil
        }

        if let detected = newDirection, detected != direction {
            preferences.translationDirection = detected
        }
    }
}

#Preview {
    NavigationStack {
        MobileTranslateView()
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(TranslationHistoryStore())
}
#endif

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/AnnotatedChineseText.swift
```swift
//
//  AnnotatedChineseText.swift
//  MandarinKit
//
//  Displays Chinese text with pinyin annotations aligned above each character
//

import SwiftUI

/// A view that displays Chinese characters with pinyin annotations positioned above each character
struct AnnotatedChineseText: View {
    let text: String
    let showPinyin: Bool
    let showToneMarks: Bool
    var characterFont: Font = .custom("Avenir Next Demi Bold", size: 28)
    var pinyinFont: Font = .custom("Avenir Next", size: 11)
    var spacing: CGFloat = 4
    var characterColor: Color = .primary
    var pinyinColor: Color = .secondary

    var body: some View {
        if showPinyin {
            WrappingHStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(annotatedCharacters.enumerated()), id: \.offset) { _, item in
                    AnnotatedCharacterView(
                        character: item.character,
                        pinyin: item.pinyin,
                        characterFont: characterFont,
                        pinyinFont: pinyinFont,
                        characterColor: characterColor,
                        pinyinColor: pinyinColor
                    )
                }
            }
        } else {
            Text(text)
                .font(characterFont)
                .foregroundStyle(characterColor)
        }
    }

    private var annotatedCharacters: [AnnotatedCharacter] {
        var result: [AnnotatedCharacter] = []

        for char in text {
            let charString = String(char)

            // Check if it's a Chinese character (CJK Unified Ideographs range)
            if char.isChineseCharacter {
                let pinyin = PinyinConverter.convert(charString, includeToneMarks: showToneMarks)
                result.append(AnnotatedCharacter(character: charString, pinyin: pinyin))
            } else {
                // Non-Chinese characters (punctuation, spaces, etc.) - no pinyin
                result.append(AnnotatedCharacter(character: charString, pinyin: nil))
            }
        }

        return result
    }
}

// MARK: - Annotated Character Model

private struct AnnotatedCharacter {
    let character: String
    let pinyin: String?
}

// MARK: - Single Annotated Character View

private struct AnnotatedCharacterView: View {
    let character: String
    let pinyin: String?
    let characterFont: Font
    let pinyinFont: Font
    let characterColor: Color
    let pinyinColor: Color

    var body: some View {
        VStack(spacing: 2) {
            // Pinyin above
            if let pinyin = pinyin {
                Text(pinyin)
                    .font(pinyinFont)
                    .foregroundStyle(pinyinColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                // Spacer to maintain alignment for non-Chinese characters
                Text(" ")
                    .font(pinyinFont)
                    .opacity(0)
            }

            // Character below
            Text(character)
                .font(characterFont)
                .foregroundStyle(characterColor)
        }
    }
}

// MARK: - Wrapping HStack for multiline support

struct WrappingHStack: Layout {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let position = arrangement.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + rowHeight

        return ArrangementResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: totalHeight)
        )
    }

    private struct ArrangementResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}

// MARK: - Character Extension

extension Character {
    /// Check if a character is a Chinese character (CJK Unified Ideographs)
    var isChineseCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }

        // CJK Unified Ideographs
        if (0x4E00...0x9FFF).contains(scalar.value) { return true }

        // CJK Unified Ideographs Extension A
        if (0x3400...0x4DBF).contains(scalar.value) { return true }

        // CJK Unified Ideographs Extension B
        if (0x20000...0x2A6DF).contains(scalar.value) { return true }

        // CJK Unified Ideographs Extension C
        if (0x2A700...0x2B73F).contains(scalar.value) { return true }

        // CJK Unified Ideographs Extension D
        if (0x2B740...0x2B81F).contains(scalar.value) { return true }

        // CJK Compatibility Ideographs
        if (0xF900...0xFAFF).contains(scalar.value) { return true }

        return false
    }
}

// MARK: - Convenience Initializers

extension AnnotatedChineseText {
    /// Create with default styling for card display
    static func card(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> AnnotatedChineseText {
        AnnotatedChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 36),
            pinyinFont: .custom("Avenir Next", size: 12),
            spacing: 6
        )
    }

    /// Create with smaller styling for inline display
    static func inline(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> AnnotatedChineseText {
        AnnotatedChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 18),
            pinyinFont: .custom("Avenir Next", size: 9),
            spacing: 3
        )
    }

    /// Create with large styling for practice/flashcard display
    static func large(_ text: String, showPinyin: Bool = true, showToneMarks: Bool = true) -> AnnotatedChineseText {
        AnnotatedChineseText(
            text: text,
            showPinyin: showPinyin,
            showToneMarks: showToneMarks,
            characterFont: .custom("Avenir Next Demi Bold", size: 48),
            pinyinFont: .custom("Avenir Next", size: 14),
            spacing: 8
        )
    }
}

// MARK: - Preview

#Preview("Single Character") {
    VStack(spacing: 20) {
        AnnotatedChineseText(
            text: "你好",
            showPinyin: true,
            showToneMarks: true
        )

        AnnotatedChineseText.card("谢谢")

        AnnotatedChineseText.large("中文")

        AnnotatedChineseText.inline("我爱你")
    }
    .padding()
}

#Preview("Sentence") {
    VStack(alignment: .leading, spacing: 20) {
        AnnotatedChineseText(
            text: "你好，我叫小明。",
            showPinyin: true,
            showToneMarks: true,
            characterFont: .custom("Avenir Next Demi Bold", size: 24),
            pinyinFont: .custom("Avenir Next", size: 10)
        )

        AnnotatedChineseText(
            text: "今天天气很好！",
            showPinyin: true,
            showToneMarks: false,
            characterFont: .custom("Avenir Next Demi Bold", size: 24),
            pinyinFont: .custom("Avenir Next", size: 10)
        )
    }
    .padding()
    .frame(maxWidth: 400)
}

#Preview("Without Pinyin") {
    AnnotatedChineseText(
        text: "学习中文",
        showPinyin: false,
        showToneMarks: true
    )
    .padding()
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/AIEnhancedTermDetail.swift
```swift
//
//  AIEnhancedTermDetail.swift
//  MandarinKit
//
//  AI-powered vocabulary term detail view with example sentences and learning hints
//

import SwiftUI

struct AIEnhancedTermDetail: View {
    let term: SavedTerm
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AIService.shared

    @State private var exampleSentences: [ExampleSentenceResult] = []
    @State private var learningHint: LearningHintResult?
    @State private var relatedWords: [RelatedWordResult] = []
    @State private var isLoadingSentences = false
    @State private var isLoadingHints = false
    @State private var isLoadingRelated = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with term info
                termHeader

                Divider()

                // AI Features Section
                if aiService.isAvailable {
                    // Example Sentences
                    exampleSentencesSection

                    Divider()

                    // Learning Hints
                    learningHintsSection

                    Divider()

                    // Related Vocabulary
                    relatedWordsSection
                } else {
                    // AI Unavailable state
                    aiUnavailableState
                }
            }
            .padding(24)
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 500, idealHeight: 600)
        .background(.ultraThinMaterial)
    }

    // MARK: - Term Header

    private var termHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Pinyin
            Text(term.pinyin)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(.secondary)

            // Chinese characters
            Text(term.chinese)
                .font(.custom("Avenir Next Demi Bold", size: 48))

            // Listen button
            Button {
                SpeechService.speak(term.chinese, languageCode: "zh-CN")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Listen")
                }
                .font(.custom("Avenir Next", size: 13))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Definition
            Text(term.definition)
                .font(.custom("Avenir Next", size: 18))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            // Part of speech
            Text(term.partOfSpeech)
                .font(.custom("Avenir Next", size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(partOfSpeechColor.opacity(0.15))
                .foregroundStyle(partOfSpeechColor)
                .clipShape(Capsule())
        }
    }

    // MARK: - Example Sentences Section

    private var exampleSentencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Example Sentences", systemImage: "text.quote")
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                    .foregroundStyle(.secondary)

                Spacer()

                if !exampleSentences.isEmpty {
                    Button {
                        Task { await loadExampleSentences() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingSentences)
                }
            }

            if isLoadingSentences {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating examples...")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if exampleSentences.isEmpty {
                Button {
                    Task { await loadExampleSentences() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate Example Sentences")
                    }
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent.opacity(0.1))
                    .foregroundStyle(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(exampleSentences) { sentence in
                    ExampleSentenceCard(sentence: sentence)
                }
            }
        }
    }

    // MARK: - Learning Hints Section

    private var learningHintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Learning Tips", systemImage: "lightbulb")
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(.secondary)

            if isLoadingHints {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Getting learning tips...")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let hint = learningHint {
                VStack(alignment: .leading, spacing: 16) {
                    // Mnemonic
                    HintCard(
                        icon: "brain.head.profile",
                        title: "Memory Trick",
                        content: hint.mnemonic,
                        color: .purple
                    )

                    // Usage context
                    HintCard(
                        icon: "bubble.left.and.bubble.right",
                        title: "When to Use",
                        content: hint.usageContext,
                        color: .blue
                    )

                    // Pronunciation tip
                    HintCard(
                        icon: "waveform",
                        title: "Pronunciation",
                        content: hint.pronunciationTip,
                        color: .green
                    )
                }
            } else {
                Button {
                    Task { await loadLearningHints() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Get Learning Tips")
                    }
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent.opacity(0.1))
                    .foregroundStyle(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Related Words Section

    private var relatedWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Related Vocabulary", systemImage: "link")
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(.secondary)

            if isLoadingRelated {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding related words...")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if relatedWords.isEmpty {
                Button {
                    Task { await loadRelatedWords() }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Find Related Words")
                    }
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent.opacity(0.1))
                    .foregroundStyle(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(relatedWords) { word in
                        RelatedWordRow(word: word)
                    }
                }
            }
        }
    }

    // MARK: - AI Unavailable State

    private var aiUnavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Apple Intelligence Unavailable")
                .font(.custom("Avenir Next Demi Bold", size: 15))

            Text(aiService.availabilityMessage)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Data Loading

    private func loadExampleSentences() async {
        isLoadingSentences = true
        errorMessage = nil

        // Generate 2 example sentences at different difficulty levels
        var sentences: [ExampleSentenceResult] = []

        for difficulty in [2, 3] {
            let result = await aiService.generateExampleSentence(
                chinese: term.chinese,
                english: term.definition,
                difficultyLevel: difficulty
            )

            switch result {
            case .success(let sentence):
                sentences.append(sentence)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            exampleSentences = sentences
            isLoadingSentences = false
        }
    }

    private func loadLearningHints() async {
        isLoadingHints = true
        errorMessage = nil

        let result = await aiService.getLearningHint(
            chinese: term.chinese,
            pinyin: term.pinyin,
            english: term.definition
        )

        await MainActor.run {
            switch result {
            case .success(let hint):
                learningHint = hint
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            isLoadingHints = false
        }
    }

    private func loadRelatedWords() async {
        isLoadingRelated = true
        errorMessage = nil

        let result = await aiService.suggestRelatedVocabulary(
            chinese: term.chinese,
            english: term.definition,
            count: 4
        )

        await MainActor.run {
            switch result {
            case .success(let words):
                relatedWords = words
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            isLoadingRelated = false
        }
    }

    // MARK: - Helpers

    private var partOfSpeechColor: Color {
        switch term.partOfSpeech.lowercased() {
        case "noun": return .blue
        case "verb": return .red
        case "adjective": return .green
        case "adverb": return .orange
        case "pronoun": return .purple
        case "preposition": return .cyan
        case "conjunction": return .mint
        default: return .secondary
        }
    }
}

// MARK: - Example Sentence Card

private struct ExampleSentenceCard: View {
    let sentence: ExampleSentenceResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chinese
            Text(sentence.chinese)
                .font(.custom("Avenir Next Demi Bold", size: 18))

            // Pinyin
            Text(sentence.pinyin)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(.secondary)

            // English
            Text(sentence.english)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(.primary.opacity(0.8))

            // Actions
            HStack(spacing: 12) {
                // Difficulty badge
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < sentence.difficulty ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                Button {
                    SpeechService.speak(sentence.chinese, languageCode: "zh-CN")
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    ClipboardService.copy(sentence.chinese)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Hint Card

private struct HintCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .foregroundStyle(color)

                Text(content)
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Related Word Row

private struct RelatedWordRow: View {
    let word: RelatedWordResult
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 12) {
            // Chinese
            Text(word.chinese)
                .font(.custom("Avenir Next Demi Bold", size: 16))
                .frame(minWidth: 40)

            // Pinyin
            Text(word.pinyin)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            // English
            Text(word.english)
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)

            // Actions
            Button {
                SpeechService.speak(word.chinese, languageCode: "zh-CN")
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                let text = "\(word.chinese) (\(word.pinyin)) - \(word.english)"
                ClipboardService.copy(text)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopied = false
                }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showCopied ? .green : .secondary)

            // Add to vocabulary
            Button {
                SavedTermsStore.shared.add(
                    chinese: word.chinese,
                    pinyin: word.pinyin,
                    definition: word.english,
                    partOfSpeech: "Unknown"
                )
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    AIEnhancedTermDetail(term: SavedTerm(
        chinese: "你好",
        pinyin: "nǐ hǎo",
        definition: "Hello",
        partOfSpeech: "Interjection"
    ))
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/HistoryView.swift
```swift
//
//  HistoryView.swift
//  MandarinKit
//
//  Clean, focused history view
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: TranslationHistoryStore
    @ObservedObject private var preferences = UserPreferences.shared

    @Binding var selection: SidebarItem

    @State private var searchText: String = ""
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            if historyStore.entries.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .confirmationDialog(
            "Clear History",
            isPresented: $showingClearConfirmation
        ) {
            Button("Clear All", role: .destructive) {
                historyStore.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            TextField("Search history...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            Spacer()

            if !historyStore.entries.isEmpty {
                Text("\(filteredEntries.count) translations")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(.secondary)

                Button {
                    showingClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear history")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No translation history")
                .font(.custom("Avenir Next Demi Bold", size: 18))

            Text("Your translations will appear here")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(.secondary)

            Button {
                selection = .translate
            } label: {
                Text("Start Translating")
                    .font(.custom("Avenir Next Demi Bold", size: 14))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(filteredEntries) { entry in
                HistoryRow(entry: entry) {
                    historyStore.select(entry)
                    selection = .translate
                }
            }
            .onDelete { offsets in
                historyStore.remove(at: offsets)
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Filtered Entries

    private var filteredEntries: [TranslationHistoryEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return historyStore.entries }

        return historyStore.entries.filter { entry in
            entry.source.localizedCaseInsensitiveContains(trimmed) ||
            entry.target.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let entry: TranslationHistoryEntry
    let onSelect: () -> Void

    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                // Source
                Text(entry.source)
                    .font(.custom("Avenir Next Demi Bold", size: 15))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // Target with pinyin if Chinese
                VStack(alignment: .leading, spacing: 2) {
                    if entry.direction == .englishToChinese && preferences.showPinyin {
                        // Chinese output - show pinyin
                        Text(PinyinConverter.convert(entry.target, includeToneMarks: preferences.showToneMarks))
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Text(entry.target)
                        .font(.custom("Avenir Next", size: 14))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)

                    if entry.direction == .chineseToEnglish && preferences.showPinyin {
                        // Chinese input - show pinyin of source
                        Text(PinyinConverter.convert(entry.source, includeToneMarks: preferences.showToneMarks))
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Direction indicator
                HStack(spacing: 4) {
                    Image(systemName: entry.direction == .englishToChinese ? "e.square" : "c.square")
                        .font(.system(size: 10))
                    Text(entry.direction == .englishToChinese ? "EN → ZH" : "ZH → EN")
                        .font(.custom("Avenir Next", size: 11))

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(entry.date, style: .relative)
                        .font(.custom("Avenir Next", size: 11))
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HistoryView(selection: .constant(.history))
        .environmentObject(TranslationHistoryStore())
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/PhraseCollectionView.swift
```swift
//
//  PhraseCollectionView.swift
//  MandarinKit
//
//  View for browsing and learning quick phrase collections
//

import SwiftUI

struct PhraseCollectionView: View {
    @ObservedObject private var store = PhraseCollectionStore.shared
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var selectedCategory: PhraseCategory?
    @State private var searchText = ""
    @State private var showFavoritesOnly = false

    var body: some View {
        NavigationSplitView {
            categorySidebar
        } detail: {
            if let category = selectedCategory {
                CategoryDetailView(category: category, searchText: $searchText)
            } else if showFavoritesOnly {
                FavoritesView(searchText: $searchText)
            } else {
                allCategoriesGrid
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Category Sidebar

    private var categorySidebar: some View {
        List(selection: $selectedCategory) {
            Section {
                Button {
                    selectedCategory = nil
                    showFavoritesOnly = false
                } label: {
                    Label("All Categories", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedCategory == nil && !showFavoritesOnly ? Color.accentColor.opacity(0.15) : Color.clear)

                Button {
                    selectedCategory = nil
                    showFavoritesOnly = true
                } label: {
                    HStack {
                        Label("Favorites", systemImage: "star.fill")
                        Spacer()
                        if !store.favoritePhrases.isEmpty {
                            Text("\(store.favoritePhrases.count)")
                                .font(.custom("Avenir Next", size: 11))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow.opacity(0.2))
                                .foregroundStyle(.yellow)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(showFavoritesOnly ? Color.accentColor.opacity(0.15) : Color.clear)
            }

            Section("Categories") {
                ForEach(PhraseCategory.allCases) { category in
                    HStack {
                        Label(category.rawValue, systemImage: category.icon)
                            .foregroundStyle(category.color)
                        Spacer()
                        Text("\(category.phrases.count)")
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .tag(category)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Phrases")
    }

    // MARK: - All Categories Grid

    private var allCategoriesGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Phrases")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("Essential phrases organized by category")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Category grid
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
                ], spacing: 16) {
                    ForEach(Array(PhraseCategory.allCases.enumerated()), id: \.element.id) { index, category in
                        CategoryCard(category: category) {
                            HapticFeedback.light()
                            withAnimation(AppAnimation.gentleSpring) {
                                selectedCategory = category
                                showFavoritesOnly = false
                            }
                        }
                        .bounceOnAppear(delay: Double(index) * 0.05)
                    }
                }
                .padding(.horizontal, 20)

                // Quick stats
                HStack(spacing: 24) {
                    StatBadge(
                        icon: "character.bubble",
                        value: "\(PhraseCategory.allCases.reduce(0) { $0 + $1.phrases.count })",
                        label: "Total Phrases"
                    )

                    StatBadge(
                        icon: "star.fill",
                        value: "\(store.favoritePhrases.count)",
                        label: "Favorites"
                    )

                    StatBadge(
                        icon: "folder",
                        value: "\(PhraseCategory.allCases.count)",
                        label: "Categories"
                    )
                }
                .padding(20)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: PhraseCategory
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(category.color)
                    Spacer()
                    Text("\(category.phrases.count)")
                        .font(.custom("Avenir Next Demi Bold", size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(category.color.opacity(0.15))
                        .foregroundStyle(category.color)
                        .clipShape(Capsule())
                }

                Text(category.rawValue)
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                    .foregroundStyle(.primary)

                // Preview of first phrase
                if let firstPhrase = category.phrases.first {
                    Text(firstPhrase.chinese)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? category.color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Category Detail View

private struct CategoryDetailView: View {
    let category: PhraseCategory
    @Binding var searchText: String

    @ObservedObject private var store = PhraseCollectionStore.shared
    @ObservedObject private var preferences = UserPreferences.shared

    private var filteredPhrases: [Phrase] {
        if searchText.isEmpty {
            return category.phrases
        }
        return category.phrases.filter { phrase in
            phrase.chinese.localizedCaseInsensitiveContains(searchText) ||
            phrase.pinyin.localizedCaseInsensitiveContains(searchText) ||
            phrase.english.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(category.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.custom("Avenir Next Demi Bold", size: 18))
                        Text("\(category.phrases.count) phrases")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.custom("Avenir Next", size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 200)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            // Phrase list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredPhrases) { phrase in
                        PhraseRow(phrase: phrase)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Favorites View

private struct FavoritesView: View {
    @Binding var searchText: String
    @ObservedObject private var store = PhraseCollectionStore.shared

    private var filteredFavorites: [Phrase] {
        if searchText.isEmpty {
            return store.favoritePhrases
        }
        return store.favoritePhrases.filter { phrase in
            phrase.chinese.localizedCaseInsensitiveContains(searchText) ||
            phrase.pinyin.localizedCaseInsensitiveContains(searchText) ||
            phrase.english.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Favorites")
                            .font(.custom("Avenir Next Demi Bold", size: 18))
                        Text("\(store.favoritePhrases.count) saved")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.custom("Avenir Next", size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 200)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            if store.favoritePhrases.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "star")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No Favorites Yet")
                        .font(.custom("Avenir Next Demi Bold", size: 17))
                    Text("Tap the star on any phrase to save it")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredFavorites) { phrase in
                            PhraseRow(phrase: phrase)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - Phrase Row

private struct PhraseRow: View {
    let phrase: Phrase

    @ObservedObject private var store = PhraseCollectionStore.shared
    @ObservedObject private var preferences = UserPreferences.shared
    @StateObject private var aiService = AIService.shared
    @State private var isHovered = false
    @State private var showCopiedFeedback = false
    @State private var showGrammarSheet = false
    @State private var grammarExplanation: GrammarExplanationResult?
    @State private var isLoadingGrammar = false

    var body: some View {
        HStack(spacing: 16) {
            // Chinese + Pinyin
            VStack(alignment: .leading, spacing: 2) {
                if preferences.showPinyin {
                    if preferences.showToneColors {
                        Text(PinyinConverter.coloredPinyin(phrase.chinese, includeToneMarks: preferences.showToneMarks))
                            .font(.custom("Avenir Next", size: 11))
                    } else {
                        Text(phrase.pinyin)
                            .font(.custom("Avenir Next", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(phrase.chinese)
                    .font(.custom("Avenir Next Demi Bold", size: 20))
            }
            .frame(minWidth: 100, alignment: .leading)

            // English
            Text(phrase.english)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Actions (shown on hover)
            HStack(spacing: 8) {
                // Favorite button
                Button {
                    HapticFeedback.light()
                    withAnimation(AppAnimation.snappySpring) {
                        store.toggleFavorite(phrase)
                    }
                } label: {
                    Image(systemName: store.isFavorite(phrase) ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(store.isFavorite(phrase) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)

                // Listen button
                Button {
                    HapticFeedback.light()
                    SpeechService.speak(phrase.chinese, languageCode: "zh-CN")
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                // Copy button
                Button {
                    HapticFeedback.success()
                    ClipboardService.copy("\(phrase.chinese) (\(phrase.pinyin)) - \(phrase.english)")
                    withAnimation(AppAnimation.quick) {
                        showCopiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(AppAnimation.quick) {
                            showCopiedFeedback = false
                        }
                    }
                } label: {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(showCopiedFeedback ? .green : .secondary)
                }
                .buttonStyle(.plain)

                // Grammar explanation button (AI-powered)
                if aiService.isAvailable {
                    Button {
                        Task { await loadGrammarExplanation() }
                    } label: {
                        if isLoadingGrammar {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "book")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingGrammar)
                    .help("Explain grammar")
                }
            }
            .opacity(isHovered ? 1 : 0.3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showGrammarSheet) {
            if let explanation = grammarExplanation {
                GrammarExplanationSheet(phrase: phrase, explanation: explanation)
            }
        }
    }

    private func loadGrammarExplanation() async {
        isLoadingGrammar = true

        let result = await aiService.explainGrammar(
            chinese: phrase.chinese,
            pinyin: phrase.pinyin,
            english: phrase.english
        )

        await MainActor.run {
            switch result {
            case .success(let explanation):
                grammarExplanation = explanation
                showGrammarSheet = true
            case .failure:
                break
            }
            isLoadingGrammar = false
        }
    }
}

// MARK: - Grammar Explanation Sheet

private struct GrammarExplanationSheet: View {
    let phrase: Phrase
    let explanation: GrammarExplanationResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grammar Breakdown")
                        .font(.custom("Avenir Next Demi Bold", size: 18))
                    Text(phrase.chinese)
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Pattern
            VStack(alignment: .leading, spacing: 8) {
                Label("Pattern", systemImage: "rectangle.3.group")
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .foregroundStyle(.blue)

                Text(explanation.pattern)
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Explanation
            VStack(alignment: .leading, spacing: 8) {
                Label("Explanation", systemImage: "text.book.closed")
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                    .foregroundStyle(.purple)

                Text(explanation.explanation)
                    .font(.custom("Avenir Next", size: 14))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Additional Examples
            if !explanation.additionalExamples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("More Examples", systemImage: "list.bullet")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(explanation.additionalExamples, id: \.self) { example in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundStyle(.green)
                                Text(example)
                                    .font(.custom("Avenir Next", size: 14))
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer()

            // Listen to original phrase
            Button {
                SpeechService.speak(phrase.chinese, languageCode: "zh-CN")
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Listen to Phrase")
                }
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 450, height: 500)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Text(label)
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PhraseCollectionView()
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Views/AppBackground.swift
```swift
import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let accentOpacity = colorScheme == .dark ? 0.16 : 0.22
        let secondaryOpacity = colorScheme == .dark ? 0.18 : 0.25

        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.secondaryAccent.opacity(secondaryOpacity), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .offset(x: -220, y: -180)

            RoundedRectangle(cornerRadius: 140, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(accentOpacity), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 480, height: 320)
                .rotationEffect(.degrees(12))
                .offset(x: 200, y: 220)
        }
        .liquidGlassBackgroundExtension()
        .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/UserPreferences.swift
```swift
//
//  UserPreferences.swift
//  MandarinKit
//
//  Central preferences management for the app
//

import SwiftUI
import Combine

/// Central preferences manager using @AppStorage for persistence
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    // MARK: - General Settings
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showDockIcon") var showDockIcon: Bool = true
    @AppStorage("confirmDestructiveActions") var confirmDestructiveActions: Bool = true

    // MARK: - Appearance
    @AppStorage("appColorScheme") var appColorScheme: AppColorScheme = .system
    @AppStorage("accentColorChoice") var accentColorChoice: AccentColorChoice = .blue
    @AppStorage("fontSize") var fontSize: FontSizeChoice = .medium
    @AppStorage("useCompactLayout") var useCompactLayout: Bool = false
    @AppStorage("englishTranslationFont") var englishTranslationFont: String = "Georgia"
    @AppStorage("englishTranslationFontSize") var englishTranslationFontSize: Double = 24.0

    // MARK: - Translation Settings
    @AppStorage("translationDirection") var translationDirectionRaw: String = TranslationDirection.englishToChinese.rawValue
    @AppStorage("autoTranslate") var autoTranslate: Bool = false
    @AppStorage("autoTranslateDelay") var autoTranslateDelay: Double = 1.0
    @AppStorage("showPinyin") var showPinyin: Bool = true
    @AppStorage("showToneMarks") var showToneMarks: Bool = true
    @AppStorage("showToneColors") var showToneColors: Bool = true
    @AppStorage("saveTranslationHistory") var saveTranslationHistory: Bool = true
    @AppStorage("maxHistoryEntries") var maxHistoryEntries: Int = 50

    // MARK: - Speech Settings
    @AppStorage("speechRate") var speechRate: Double = 0.5
    @AppStorage("autoSpeak") var autoSpeak: Bool = false
    @AppStorage("speakSource") var speakSource: Bool = false
    @AppStorage("speakTarget") var speakTarget: Bool = true

    // MARK: - Learning Settings
    @AppStorage("dailyGoal") var dailyGoal: Int = 10
    @AppStorage("enableSpacedRepetition") var enableSpacedRepetition: Bool = true
    @AppStorage("showLearningReminders") var showLearningReminders: Bool = false
    @AppStorage("reminderTime") var reminderTimeInterval: Double = 32400 // 9:00 AM as seconds from midnight
    @AppStorage("shuffleNewCards") var shuffleNewCards: Bool = true
    @AppStorage("autoRevealAfterDelay") var autoRevealAfterDelay: Bool = false
    @AppStorage("autoRevealDelay") var autoRevealDelay: Double = 3.0

    // MARK: - Stats
    @AppStorage("currentStreak") var currentStreak: Int = 0
    @AppStorage("longestStreak") var longestStreak: Int = 0
    @AppStorage("lastPracticeDate") var lastPracticeDateInterval: Double = 0
    @AppStorage("totalCardsReviewed") var totalCardsReviewed: Int = 0
    @AppStorage("totalTranslations") var totalTranslations: Int = 0

    // MARK: - Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("appVersion") var lastAppVersion: String = ""

    // MARK: - Computed Properties

    var translationDirection: TranslationDirection {
        get { TranslationDirection(rawValue: translationDirectionRaw) ?? .englishToChinese }
        set { translationDirectionRaw = newValue.rawValue }
    }

    var reminderTime: Date {
        get {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            return startOfDay.addingTimeInterval(reminderTimeInterval)
        }
        set {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: newValue)
            reminderTimeInterval = newValue.timeIntervalSince(startOfDay)
        }
    }

    var lastPracticeDate: Date? {
        get {
            lastPracticeDateInterval > 0 ? Date(timeIntervalSince1970: lastPracticeDateInterval) : nil
        }
        set {
            lastPracticeDateInterval = newValue?.timeIntervalSince1970 ?? 0
        }
    }

    // MARK: - Methods

    func recordPracticeSession(cardsReviewed: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = lastPracticeDate.map { Calendar.current.startOfDay(for: $0) }

        if let lastDate = lastDate {
            let daysDiff = Calendar.current.dateComponents([.day], from: lastDate, to: today).day ?? 0
            if daysDiff == 1 {
                currentStreak += 1
            } else if daysDiff > 1 {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        totalCardsReviewed += cardsReviewed
        lastPracticeDate = Date()
    }

    func recordTranslation() {
        totalTranslations += 1
    }

    func resetStats() {
        currentStreak = 0
        longestStreak = 0
        lastPracticeDateInterval = 0
        totalCardsReviewed = 0
        totalTranslations = 0
    }

    private init() {}
}

// MARK: - Preference Enums

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentColorChoice: String, CaseIterable, Identifiable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        }
    }
}

enum FontSizeChoice: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    var scale: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }

    var bodySize: CGFloat { 14 * scale }
    var headlineSize: CGFloat { 15 * scale }
    var titleSize: CGFloat { 18 * scale }
    var largeTitleSize: CGFloat { 30 * scale }
    var chineseCharacterSize: CGFloat { 36 * scale }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/AIService.swift
```swift
//
//  AIService.swift
//  MandarinKit
//
//  Foundation Models integration for intelligent language learning features
//

import Foundation
import SwiftUI
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Service

/// Central service for all AI-powered features using Apple's Foundation Models
@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var availabilityMessage: String = "Checking..."

    private init() {
        checkAvailability()
    }

    private func checkAvailability() {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isAvailable = true
            availabilityMessage = "Apple Intelligence Ready"
        case .unavailable(let reason):
            isAvailable = false
            availabilityMessage = "Apple Intelligence unavailable: \(reason)"
        }
        #else
        isAvailable = false
        availabilityMessage = "Apple Intelligence not available on this device"
        #endif
    }
}

// MARK: - Structured Output Types

#if canImport(FoundationModels)

/// Example sentence generated by the model
@Generable
struct GeneratedSentence {
    @Guide(description: "A natural Chinese sentence using the vocabulary word")
    var chinese: String

    @Guide(description: "Pinyin romanization with tone marks")
    var pinyin: String

    @Guide(description: "English translation of the sentence")
    var english: String

    @Guide(description: "Difficulty level from 1-5, where 1 is beginner and 5 is advanced")
    var difficulty: Int
}

/// Learning hint for flashcard review
@Generable
struct LearningHint {
    @Guide(description: "A helpful mnemonic or memory trick")
    var mnemonic: String

    @Guide(description: "A common usage context or situation")
    var usageContext: String

    @Guide(description: "A tip about pronunciation or tones")
    var pronunciationTip: String
}

/// Grammar explanation for a phrase
@Generable
struct GrammarExplanation {
    @Guide(description: "Brief explanation of the grammar pattern")
    var explanation: String

    @Guide(description: "The grammatical structure or pattern used")
    var pattern: String

    @Guide(description: "Two additional example sentences using the same pattern")
    var additionalExamples: [String]
}

#endif

// MARK: - AI Feature Methods

extension AIService {

    /// Generate example sentences for a vocabulary word
    func generateExampleSentence(
        chinese: String,
        english: String,
        difficultyLevel: Int = 2
    ) async -> Result<ExampleSentenceResult, AIError> {
        #if canImport(FoundationModels)
        guard isAvailable else {
            return .failure(.unavailable(availabilityMessage))
        }

        do {
            let session = LanguageModelSession(instructions: """
                You are a Mandarin Chinese language tutor creating example sentences.
                Generate natural, useful example sentences that help learners understand
                word usage in context. Keep sentences appropriate for the specified difficulty level.
                Use proper tone marks in pinyin (ā, á, ǎ, à, a for neutral).
                """)

            let prompt = """
                Create an example sentence using this vocabulary:
                Chinese word: \(chinese)
                English meaning: \(english)
                Target difficulty: \(difficultyLevel) out of 5

                Make the sentence natural and commonly used in daily conversation.
                """

            let response = try await session.respond(to: prompt, generating: GeneratedSentence.self)

            return .success(ExampleSentenceResult(
                chinese: response.content.chinese,
                pinyin: response.content.pinyin,
                english: response.content.english,
                difficulty: response.content.difficulty
            ))
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
        #else
        return .failure(.unavailable("Foundation Models not available"))
        #endif
    }

    /// Get a learning hint for a flashcard
    func getLearningHint(
        chinese: String,
        pinyin: String,
        english: String
    ) async -> Result<LearningHintResult, AIError> {
        #if canImport(FoundationModels)
        guard isAvailable else {
            return .failure(.unavailable(availabilityMessage))
        }

        do {
            let session = LanguageModelSession(instructions: """
                You are a Mandarin Chinese memory coach helping learners remember vocabulary.
                Create memorable mnemonics, explain usage contexts, and give pronunciation tips.
                Keep hints concise but effective. Focus on practical memorization techniques.
                """)

            let prompt = """
                Help me remember this word:
                Chinese: \(chinese)
                Pinyin: \(pinyin)
                English: \(english)

                Provide a mnemonic, usage context, and pronunciation tip.
                """

            let response = try await session.respond(to: prompt, generating: LearningHint.self)

            return .success(LearningHintResult(
                mnemonic: response.content.mnemonic,
                usageContext: response.content.usageContext,
                pronunciationTip: response.content.pronunciationTip
            ))
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
        #else
        return .failure(.unavailable("Foundation Models not available"))
        #endif
    }

    /// Explain the grammar of a phrase
    func explainGrammar(
        chinese: String,
        pinyin: String,
        english: String
    ) async -> Result<GrammarExplanationResult, AIError> {
        #if canImport(FoundationModels)
        guard isAvailable else {
            return .failure(.unavailable(availabilityMessage))
        }

        do {
            let session = LanguageModelSession(instructions: """
                You are a Mandarin Chinese grammar expert.
                Explain grammatical patterns clearly and provide useful examples.
                Focus on patterns that are commonly used and transferable to other sentences.
                Keep explanations concise but informative.
                """)

            let prompt = """
                Explain the grammar of this phrase:
                Chinese: \(chinese)
                Pinyin: \(pinyin)
                English: \(english)

                Identify the grammatical pattern and provide two more examples using it.
                """

            let response = try await session.respond(to: prompt, generating: GrammarExplanation.self)

            return .success(GrammarExplanationResult(
                explanation: response.content.explanation,
                pattern: response.content.pattern,
                additionalExamples: response.content.additionalExamples
            ))
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
        #else
        return .failure(.unavailable("Foundation Models not available"))
        #endif
    }

    /// Generate a quick translation tip
    func getTranslationTip(
        chinese: String,
        english: String
    ) async -> Result<String, AIError> {
        #if canImport(FoundationModels)
        guard isAvailable else {
            return .failure(.unavailable(availabilityMessage))
        }

        do {
            let session = LanguageModelSession(instructions: """
                You are a helpful Mandarin tutor. Provide one concise, practical tip
                about this translation (pronunciation, tone, cultural context, or usage).
                Keep it to 1-2 sentences maximum.
                """)

            let prompt = "Chinese: \(chinese)\nEnglish: \(english)\nTip:"

            let response = try await session.respond(to: prompt)
            return .success(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
        #else
        return .failure(.unavailable("Foundation Models not available"))
        #endif
    }

    /// Suggest related vocabulary based on context
    func suggestRelatedVocabulary(
        chinese: String,
        english: String,
        count: Int = 3
    ) async -> Result<[RelatedWordResult], AIError> {
        #if canImport(FoundationModels)
        guard isAvailable else {
            return .failure(.unavailable(availabilityMessage))
        }

        do {
            let session = LanguageModelSession(instructions: """
                You are a Mandarin vocabulary coach. Suggest related words that would
                naturally complement the given vocabulary. Focus on words that share
                context, are commonly used together, or build on the same topic.
                Use proper tone marks in pinyin.
                """)

            let prompt = """
                Based on this word:
                Chinese: \(chinese)
                English: \(english)

                Suggest \(count) related vocabulary words that would be useful to learn together.
                Format each as: Chinese | Pinyin | English
                One word per line.
                """

            let response = try await session.respond(to: prompt)
            let lines = response.content.components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            var results: [RelatedWordResult] = []
            for line in lines.prefix(count) {
                let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 3 {
                    results.append(RelatedWordResult(
                        chinese: parts[0],
                        pinyin: parts[1],
                        english: parts[2]
                    ))
                }
            }

            return .success(results)
        } catch {
            return .failure(.generationFailed(error.localizedDescription))
        }
        #else
        return .failure(.unavailable("Foundation Models not available"))
        #endif
    }
}

// MARK: - Result Types (Platform-independent)

struct ExampleSentenceResult: Identifiable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let english: String
    let difficulty: Int
}

struct LearningHintResult {
    let mnemonic: String
    let usageContext: String
    let pronunciationTip: String
}

struct GrammarExplanationResult {
    let explanation: String
    let pattern: String
    let additionalExamples: [String]
}

struct RelatedWordResult: Identifiable {
    let id = UUID()
    let chinese: String
    let pinyin: String
    let english: String
}

// MARK: - Error Types

enum AIError: LocalizedError {
    case unavailable(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "AI features unavailable: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/ChineseTextAnalyzer.swift
```swift
//
//  ChineseTextAnalyzer.swift
//  MandarinKit
//
//  Provides Chinese text analysis using Apple's Natural Language framework
//  including word segmentation, language detection, and parts of speech tagging
//

import Foundation
import NaturalLanguage
import SwiftUI

/// Analyzes Chinese text using Apple's Natural Language framework
final class ChineseTextAnalyzer {

    // MARK: - Singleton

    static let shared = ChineseTextAnalyzer()
    private init() {}

    // MARK: - Word Segmentation

    /// Segments Chinese text into individual words
    /// Chinese has no spaces between words, so this is critical for proper analysis
    func segmentWords(_ text: String) -> [SegmentedWord] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.simplifiedChinese)

        var words: [SegmentedWord] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            words.append(SegmentedWord(text: word, range: range))
            return true
        }

        return words
    }

    /// Segments text and includes parts of speech tags
    func segmentWithPartsOfSpeech(_ text: String) -> [AnalyzedWord] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.simplifiedChinese, range: text.startIndex..<text.endIndex)

        var words: [AnalyzedWord] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .lexicalClass,
                            options: [.omitWhitespace]) { tag, range in
            let word = String(text[range])
            let partOfSpeech = tag.map { PartOfSpeech(from: $0) } ?? .unknown
            words.append(AnalyzedWord(text: word, range: range, partOfSpeech: partOfSpeech))
            return true
        }

        return words
    }

    // MARK: - Language Detection

    /// Detects the dominant language of the given text
    func detectLanguage(_ text: String) -> DetectedLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let language = recognizer.dominantLanguage else {
            return .unknown
        }

        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return .chinese
        case .english:
            return .english
        default:
            return .other(language.rawValue)
        }
    }

    /// Detects language with confidence score
    func detectLanguageWithConfidence(_ text: String) -> (language: DetectedLanguage, confidence: Double) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)

        guard let dominant = recognizer.dominantLanguage,
              let confidence = hypotheses[dominant] else {
            return (.unknown, 0.0)
        }

        let detectedLanguage: DetectedLanguage
        switch dominant {
        case .simplifiedChinese, .traditionalChinese:
            detectedLanguage = .chinese
        case .english:
            detectedLanguage = .english
        default:
            detectedLanguage = .other(dominant.rawValue)
        }

        return (detectedLanguage, confidence)
    }

    // MARK: - Sentence Analysis

    /// Analyzes sentence complexity for learning level estimation
    func analyzeSentence(_ text: String) -> SentenceAnalysis {
        let words = segmentWords(text)
        let characters = text.filter { $0.isChineseCharacter }
        let uniqueCharacters = Set(characters)

        return SentenceAnalysis(
            wordCount: words.count,
            characterCount: characters.count,
            uniqueCharacterCount: uniqueCharacters.count,
            averageWordLength: words.isEmpty ? 0 : Double(characters.count) / Double(words.count),
            estimatedHSKLevel: estimateHSKLevel(uniqueCharacters: uniqueCharacters)
        )
    }

    // MARK: - Private Helpers

    private func estimateHSKLevel(uniqueCharacters: Set<Character>) -> Int {
        // Simple heuristic based on character count
        // In a real app, this would check against HSK vocabulary lists
        let count = uniqueCharacters.count
        switch count {
        case 0...5: return 1
        case 6...15: return 2
        case 16...30: return 3
        case 31...50: return 4
        case 51...80: return 5
        default: return 6
        }
    }
}

// MARK: - Supporting Types

/// A word segment with its position in the original text
struct SegmentedWord: Identifiable {
    let id = UUID()
    let text: String
    let range: Range<String.Index>
}

/// A word with part of speech analysis
struct AnalyzedWord: Identifiable {
    let id = UUID()
    let text: String
    let range: Range<String.Index>
    let partOfSpeech: PartOfSpeech
}

/// Parts of speech categories
enum PartOfSpeech: String {
    case noun
    case verb
    case adjective
    case adverb
    case pronoun
    case preposition
    case conjunction
    case particle
    case number
    case classifier
    case interjection
    case unknown

    init(from tag: NLTag) {
        switch tag {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        case .pronoun: self = .pronoun
        case .preposition: self = .preposition
        case .conjunction: self = .conjunction
        case .particle: self = .particle
        case .number: self = .number
        case .classifier: self = .classifier
        case .interjection: self = .interjection
        default: self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .noun: return "Noun"
        case .verb: return "Verb"
        case .adjective: return "Adjective"
        case .adverb: return "Adverb"
        case .pronoun: return "Pronoun"
        case .preposition: return "Preposition"
        case .conjunction: return "Conjunction"
        case .particle: return "Particle"
        case .number: return "Number"
        case .classifier: return "Classifier"
        case .interjection: return "Interjection"
        case .unknown: return "Unknown"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .noun: return .blue
        case .verb: return .red
        case .adjective: return .green
        case .adverb: return .orange
        case .pronoun: return .purple
        case .preposition: return .cyan
        case .conjunction: return .mint
        case .particle: return .gray
        case .number: return .indigo
        case .classifier: return .pink
        case .interjection: return .yellow
        case .unknown: return .secondary
        }
    }
}

/// Detected language result
enum DetectedLanguage: Equatable {
    case chinese
    case english
    case other(String)
    case unknown

    var isChinese: Bool {
        self == .chinese
    }

    var isEnglish: Bool {
        self == .english
    }
}

/// Sentence analysis results
struct SentenceAnalysis {
    let wordCount: Int
    let characterCount: Int
    let uniqueCharacterCount: Int
    let averageWordLength: Double
    let estimatedHSKLevel: Int

    var complexityDescription: String {
        switch estimatedHSKLevel {
        case 1: return "Beginner"
        case 2: return "Elementary"
        case 3: return "Intermediate"
        case 4: return "Upper Intermediate"
        case 5: return "Advanced"
        default: return "Expert"
        }
    }
}

// Note: Character.isChineseCharacter extension is defined in AnnotatedChineseText.swift

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/TranslationHistoryStore.swift
```swift
import Foundation
import Combine
import SwiftUI

struct TranslationHistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let source: String
    let target: String
    let directionRaw: String
    let date: Date

    init(source: String, target: String, direction: TranslationDirection, date: Date = Date()) {
        self.id = UUID()
        self.source = source
        self.target = target
        self.directionRaw = direction.rawValue
        self.date = date
    }

    var direction: TranslationDirection {
        TranslationDirection(rawValue: directionRaw) ?? .englishToChinese
    }

    var chineseText: String {
        direction == .englishToChinese ? target : source
    }

    var englishText: String {
        direction == .englishToChinese ? source : target
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TranslationHistoryEntry, rhs: TranslationHistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

final class TranslationHistoryStore: ObservableObject {
    @Published private(set) var entries: [TranslationHistoryEntry] = []
    @Published var selectedEntry: TranslationHistoryEntry?

    private let storageKey = "translationHistory"

    private var maxEntries: Int {
        UserPreferences.shared.maxHistoryEntries
    }

    private var shouldSaveHistory: Bool {
        UserPreferences.shared.saveTranslationHistory
    }

    init() {
        load()
    }

    func add(source: String, target: String, direction: TranslationDirection) {
        guard shouldSaveHistory else { return }

        let entry = TranslationHistoryEntry(source: source, target: target, direction: direction)

        // Remove duplicates
        entries.removeAll { $0.source == source && $0.target == target && $0.directionRaw == direction.rawValue }

        // Insert at the beginning
        entries.insert(entry, at: 0)

        // Trim to max entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    func remove(_ entry: TranslationHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        entries.removeAll()
        selectedEntry = nil
        save()
    }

    func select(_ entry: TranslationHistoryEntry) {
        selectedEntry = entry
    }

    func search(_ query: String) -> [TranslationHistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }

        return entries.filter { entry in
            entry.source.localizedCaseInsensitiveContains(trimmed) ||
            entry.target.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func filter(by direction: TranslationDirection) -> [TranslationHistoryEntry] {
        entries.filter { $0.direction == direction }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([TranslationHistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/LiquidGlassHelpers.swift
```swift
import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassCard(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, iOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay(shape.stroke(AppTheme.border, lineWidth: 1))
        } else {
            self
                .background(AppTheme.cardFill, in: shape)
                .overlay(shape.stroke(AppTheme.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    func liquidGlassBackgroundExtension() -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/AnimationHelpers.swift
```swift
//
//  AnimationHelpers.swift
//  MandarinKit
//
//  Shared animation constants and helpers for consistent UI polish
//

import SwiftUI

// MARK: - Animation Constants

enum AppAnimation {
    /// Standard duration for most UI transitions
    static let standard: Animation = .easeInOut(duration: 0.25)

    /// Quick animations for immediate feedback
    static let quick: Animation = .easeOut(duration: 0.15)

    /// Slow animations for emphasis
    static let slow: Animation = .easeInOut(duration: 0.4)

    /// Spring animation for bouncy feel
    static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.7)

    /// Gentle spring for subtle bounces
    static let gentleSpring: Animation = .spring(response: 0.4, dampingFraction: 0.8)

    /// Snappy spring for quick interactions
    static let snappySpring: Animation = .spring(response: 0.25, dampingFraction: 0.75)
}

// MARK: - Haptic Feedback

#if os(iOS)
import UIKit

enum HapticFeedback {
    /// Light impact for subtle feedback
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact for standard interactions
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact for significant actions
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Success notification
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Error notification
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Warning notification
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Selection changed
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#else
enum HapticFeedback {
    static func light() {}
    static func medium() {}
    static func heavy() {}
    static func success() {}
    static func error() {}
    static func warning() {}
    static func selection() {}
}
#endif

// MARK: - View Modifiers

/// Scale effect on press for buttons
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.quick, value: configuration.isPressed)
    }
}

/// Bounce animation on appear
struct BounceOnAppear: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.8)
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(AppAnimation.spring.delay(delay)) {
                    appeared = true
                }
            }
    }
}

/// Slide in from edge on appear
struct SlideInOnAppear: ViewModifier {
    @State private var appeared = false
    let edge: Edge
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(x: xOffset, y: yOffset)
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(AppAnimation.gentleSpring.delay(delay)) {
                    appeared = true
                }
            }
    }

    private var xOffset: CGFloat {
        guard !appeared else { return 0 }
        switch edge {
        case .leading: return -30
        case .trailing: return 30
        default: return 0
        }
    }

    private var yOffset: CGFloat {
        guard !appeared else { return 0 }
        switch edge {
        case .top: return -30
        case .bottom: return 30
        default: return 0
        }
    }
}

/// Fade in on appear
struct FadeInOnAppear: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(AppAnimation.standard.delay(delay)) {
                    appeared = true
                }
            }
    }
}

/// Shimmer loading effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Add bounce animation on appear
    func bounceOnAppear(delay: Double = 0) -> some View {
        modifier(BounceOnAppear(delay: delay))
    }

    /// Add slide-in animation on appear
    func slideInOnAppear(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        modifier(SlideInOnAppear(edge: edge, delay: delay))
    }

    /// Add fade-in animation on appear
    func fadeInOnAppear(delay: Double = 0) -> some View {
        modifier(FadeInOnAppear(delay: delay))
    }

    /// Add shimmer loading effect
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Pressable button style with scale effect
    static var pressable: PressableButtonStyle {
        PressableButtonStyle()
    }
}

// MARK: - Transition Helpers

extension AnyTransition {
    /// Slide and fade transition
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Pop transition (scale up from small)
    static var pop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/PinyinConverter.swift
```swift
import Foundation
import SwiftUI

enum PinyinConverter {

    // MARK: - Basic Conversion

    static func convert(_ text: String, includeToneMarks: Bool) -> String {
        guard !text.isEmpty else { return "" }
        let transformed = text.applyingTransform(.mandarinToLatin, reverse: false) ?? text
        guard !includeToneMarks else { return transformed }
        return transformed.applyingTransform(.stripDiacritics, reverse: false) ?? transformed
    }

    // MARK: - Tone Detection

    /// Represents the four tones of Mandarin Chinese plus neutral tone
    enum Tone: Int, CaseIterable {
        case first = 1   // High level (ˉ): ā, ē, ī, ō, ū, ǖ
        case second = 2  // Rising (ˊ): á, é, í, ó, ú, ǘ
        case third = 3   // Falling-rising (ˇ): ǎ, ě, ǐ, ǒ, ǔ, ǚ
        case fourth = 4  // Falling (ˋ): à, è, ì, ò, ù, ǜ
        case neutral = 5 // Light/neutral tone (no mark)

        /// Standard color associated with this tone for learning
        var color: Color {
            switch self {
            case .first: return Color(red: 0.2, green: 0.5, blue: 0.9)   // Blue
            case .second: return Color(red: 0.2, green: 0.7, blue: 0.3)  // Green
            case .third: return Color(red: 0.9, green: 0.6, blue: 0.1)   // Orange
            case .fourth: return Color(red: 0.9, green: 0.2, blue: 0.2)  // Red
            case .neutral: return Color.secondary                         // Gray
            }
        }

        /// Name of the tone for display
        var displayName: String {
            switch self {
            case .first: return "1st Tone (High)"
            case .second: return "2nd Tone (Rising)"
            case .third: return "3rd Tone (Dipping)"
            case .fourth: return "4th Tone (Falling)"
            case .neutral: return "Neutral Tone"
            }
        }

        /// Unicode tone mark character
        var toneMark: String {
            switch self {
            case .first: return "ˉ"
            case .second: return "ˊ"
            case .third: return "ˇ"
            case .fourth: return "ˋ"
            case .neutral: return ""
            }
        }
    }

    /// Characters that indicate first tone (high level)
    private static let firstToneChars: Set<Character> = ["ā", "ē", "ī", "ō", "ū", "ǖ", "Ā", "Ē", "Ī", "Ō", "Ū", "Ǖ"]

    /// Characters that indicate second tone (rising)
    private static let secondToneChars: Set<Character> = ["á", "é", "í", "ó", "ú", "ǘ", "Á", "É", "Í", "Ó", "Ú", "Ǘ"]

    /// Characters that indicate third tone (falling-rising)
    private static let thirdToneChars: Set<Character> = ["ǎ", "ě", "ǐ", "ǒ", "ǔ", "ǚ", "Ǎ", "Ě", "Ǐ", "Ǒ", "Ǔ", "Ǚ"]

    /// Characters that indicate fourth tone (falling)
    private static let fourthToneChars: Set<Character> = ["à", "è", "ì", "ò", "ù", "ǜ", "À", "È", "Ì", "Ò", "Ù", "Ǜ"]

    /// Detect the tone of a pinyin syllable
    static func detectTone(_ pinyin: String) -> Tone {
        for char in pinyin {
            if firstToneChars.contains(char) { return .first }
            if secondToneChars.contains(char) { return .second }
            if thirdToneChars.contains(char) { return .third }
            if fourthToneChars.contains(char) { return .fourth }
        }
        return .neutral
    }

    /// Get the tone color for a pinyin syllable
    static func toneColor(for pinyin: String) -> Color {
        detectTone(pinyin).color
    }

    // MARK: - Syllable Segmentation

    /// A single pinyin syllable with its tone
    struct PinyinSyllable: Identifiable {
        let id = UUID()
        let text: String
        let tone: Tone

        var color: Color { tone.color }
    }

    /// Split pinyin string into individual syllables with their tones
    static func segment(_ pinyin: String) -> [PinyinSyllable] {
        var syllables: [PinyinSyllable] = []
        var current = ""

        // Simple segmentation - split on spaces and certain boundaries
        for char in pinyin {
            if char.isWhitespace || char == "'" {
                if !current.isEmpty {
                    syllables.append(PinyinSyllable(text: current, tone: detectTone(current)))
                    current = ""
                }
                // Preserve spaces as separate syllables for layout
                if char.isWhitespace {
                    syllables.append(PinyinSyllable(text: String(char), tone: .neutral))
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            syllables.append(PinyinSyllable(text: current, tone: detectTone(current)))
        }

        return syllables
    }

    // MARK: - Attributed String for SwiftUI

    /// Convert pinyin to an AttributedString with tone colors
    static func coloredPinyin(_ text: String, includeToneMarks: Bool = true) -> AttributedString {
        let pinyin = convert(text, includeToneMarks: includeToneMarks)
        let syllables = segment(pinyin)

        var attributed = AttributedString()

        for syllable in syllables {
            var syllableStr = AttributedString(syllable.text)
            if syllable.text.trimmingCharacters(in: .whitespaces).isEmpty == false {
                syllableStr.foregroundColor = syllable.color
            }
            attributed.append(syllableStr)
        }

        return attributed
    }
}

// MARK: - Color Extension for Tone Colors

extension Color {
    /// Standard Mandarin tone colors used in language learning
    static let tone1 = PinyinConverter.Tone.first.color
    static let tone2 = PinyinConverter.Tone.second.color
    static let tone3 = PinyinConverter.Tone.third.color
    static let tone4 = PinyinConverter.Tone.fourth.color
    static let tone5 = PinyinConverter.Tone.neutral.color
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/TranslationDirection.swift
```swift
import Foundation
import SwiftUI

enum TranslationDirection: String, CaseIterable, Identifiable {
    case englishToChinese
    case chineseToEnglish

    var id: String { rawValue }

    var label: String {
        switch self {
        case .englishToChinese:
            return "English → Chinese"
        case .chineseToEnglish:
            return "Chinese → English"
        }
    }

    var sourceLabel: String {
        switch self {
        case .englishToChinese:
            return "English"
        case .chineseToEnglish:
            return "Chinese"
        }
    }

    var targetLabel: String {
        switch self {
        case .englishToChinese:
            return "Chinese"
        case .chineseToEnglish:
            return "English"
        }
    }

    var placeholder: String {
        switch self {
        case .englishToChinese:
            return "Type English text to translate…"
        case .chineseToEnglish:
            return "输入中文以翻译…"
        }
    }

    var accentColor: Color {
        switch self {
        case .englishToChinese:
            return AppTheme.accent
        case .chineseToEnglish:
            return AppTheme.secondaryAccent
        }
    }

    var sourceLanguage: Locale.Language? {
        switch self {
        case .englishToChinese:
            return Locale.Language(identifier: "en")
        case .chineseToEnglish:
            return Locale.Language(identifier: "zh-Hans")
        }
    }

    var targetLanguage: Locale.Language? {
        switch self {
        case .englishToChinese:
            return Locale.Language(identifier: "zh-Hans")
        case .chineseToEnglish:
            return Locale.Language(identifier: "en")
        }
    }

    var sourceSpeechLanguageCode: String {
        switch self {
        case .englishToChinese:
            return "en-US"
        case .chineseToEnglish:
            return "zh-CN"
        }
    }

    var targetSpeechLanguageCode: String {
        switch self {
        case .englishToChinese:
            return "zh-CN"
        case .chineseToEnglish:
            return "en-US"
        }
    }

    func toggled() -> TranslationDirection {
        self == .englishToChinese ? .chineseToEnglish : .englishToChinese
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/IntelligenceCoach.swift
```swift
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum IntelligenceCoach {
    static func translationTip(chinese: String, english: String) async -> Result<String, IntelligenceError> {
        await generateTip(
            chinese: chinese,
            english: english,
            instructions: "You are a Mandarin tutor. Provide one short tip (max 2 sentences) about pronunciation, tone, or usage.",
            prompt: "Chinese: \(chinese)\nEnglish: \(english)\nTip:"
        )
    }

    static func practicePrompt(chinese: String, english: String) async -> Result<String, IntelligenceError> {
        await generateTip(
            chinese: chinese,
            english: english,
            instructions: "You are a Mandarin coach. Provide one short practice prompt or example sentence (max 2 sentences).",
            prompt: "Chinese: \(chinese)\nEnglish: \(english)\nPractice:"
        )
    }

    private static func generateTip(chinese: String, english: String, instructions: String, prompt: String) async -> Result<String, IntelligenceError> {
        guard !chinese.isEmpty, !english.isEmpty else {
            return .failure(.init(message: "Provide both Chinese and English text."))
        }

        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: prompt)
                return .success(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                return .failure(.init(message: error.localizedDescription))
            }
        case .unavailable(let reason):
            return .failure(.init(message: "Apple Intelligence unavailable: \(reason)"))
        }
        #else
        return .failure(.init(message: "Apple Intelligence frameworks are unavailable on this SDK."))
        #endif
    }
}

struct IntelligenceError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/AppTheme.swift
```swift
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum AppTheme {
    static let accent = Color(red: 0.12, green: 0.38, blue: 0.64)
    static let secondaryAccent = Color(red: 0.88, green: 0.49, blue: 0.22)

    #if os(macOS)
    static let backgroundTop = Color(nsColor: .windowBackgroundColor)
    static let backgroundBottom = Color(nsColor: .controlBackgroundColor)
    static let cardFill = Color(nsColor: .textBackgroundColor).opacity(0.92)
    static let border = Color(nsColor: .separatorColor)
    #else
    static let backgroundTop = Color(uiColor: .systemBackground)
    static let backgroundBottom = Color(uiColor: .secondarySystemBackground)
    static let cardFill = Color(uiColor: .tertiarySystemBackground).opacity(0.92)
    static let border = Color(uiColor: .separator)
    #endif

    static let mutedText = Color.secondary
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/ClipboardService.swift
```swift
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ClipboardService {
    static func copy(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    static func paste() -> String? {
        #if os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #else
        return UIPasteboard.general.string
        #endif
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Services/SpeechService.swift
```swift
import AVFoundation

enum SpeechService {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ text: String, languageCode: String?) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        if let languageCode {
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/SavedTerm.swift
```swift
//
//  SavedTerm.swift
//  MandarinKit
//
//  Model for saved vocabulary terms
//

import Foundation
import SwiftUI
import Combine

struct SavedTerm: Identifiable, Codable, Equatable {
    let id: UUID
    let chinese: String
    let pinyin: String
    let definition: String
    let partOfSpeech: String
    let dateAdded: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        chinese: String,
        pinyin: String,
        definition: String,
        partOfSpeech: String,
        dateAdded: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.chinese = chinese
        self.pinyin = pinyin
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.dateAdded = dateAdded
        self.sortOrder = sortOrder
    }
}

// MARK: - Saved Terms Store

final class SavedTermsStore: ObservableObject {
    static let shared = SavedTermsStore()

    @Published var terms: [SavedTerm] = [] {
        didSet {
            save()
        }
    }

    private let saveKey = "savedTerms"

    private init() {
        load()
    }

    // MARK: - Public Methods

    func add(chinese: String, pinyin: String, definition: String, partOfSpeech: String) {
        // Check if already exists
        guard !terms.contains(where: { $0.chinese == chinese }) else { return }

        let newTerm = SavedTerm(
            chinese: chinese,
            pinyin: pinyin,
            definition: definition,
            partOfSpeech: partOfSpeech,
            sortOrder: terms.count
        )
        terms.append(newTerm)
    }

    func remove(at offsets: IndexSet) {
        terms.remove(atOffsets: offsets)
        updateSortOrders()
    }

    func remove(term: SavedTerm) {
        terms.removeAll { $0.id == term.id }
        updateSortOrders()
    }

    func move(from source: IndexSet, to destination: Int) {
        terms.move(fromOffsets: source, toOffset: destination)
        updateSortOrders()
    }

    func contains(chinese: String) -> Bool {
        terms.contains { $0.chinese == chinese }
    }

    func clear() {
        terms.removeAll()
    }

    // MARK: - Export Methods

    /// Export formats supported
    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV"
        case anki = "Anki TSV"
        case markdown = "Markdown"
        case json = "JSON"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .anki: return "txt"
            case .markdown: return "md"
            case .json: return "json"
            }
        }

        var mimeType: String {
            switch self {
            case .csv: return "text/csv"
            case .anki: return "text/plain"
            case .markdown: return "text/markdown"
            case .json: return "application/json"
            }
        }
    }

    /// Export vocabulary to the specified format
    func export(format: ExportFormat) -> String {
        switch format {
        case .csv:
            return exportToCSV()
        case .anki:
            return exportToAnki()
        case .markdown:
            return exportToMarkdown()
        case .json:
            return exportToJSON()
        }
    }

    /// Export to CSV format
    private func exportToCSV() -> String {
        var csv = "Chinese,Pinyin,Definition,Part of Speech,Date Added\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for term in terms {
            let chinese = escapeCSV(term.chinese)
            let pinyin = escapeCSV(term.pinyin)
            let definition = escapeCSV(term.definition)
            let pos = escapeCSV(term.partOfSpeech)
            let date = dateFormatter.string(from: term.dateAdded)

            csv += "\(chinese),\(pinyin),\(definition),\(pos),\(date)\n"
        }

        return csv
    }

    /// Export to Anki-compatible TSV format (tab-separated)
    /// Format: Front (Chinese + Pinyin) \t Back (Definition)
    private func exportToAnki() -> String {
        var tsv = ""

        for term in terms {
            // Front: Chinese with pinyin
            let front = "\(term.chinese)\n\(term.pinyin)"
            // Back: Definition with part of speech
            let back = term.partOfSpeech.isEmpty ? term.definition : "\(term.definition)\n(\(term.partOfSpeech))"

            // Escape tabs and newlines for TSV
            let escapedFront = front.replacingOccurrences(of: "\t", with: " ")
            let escapedBack = back.replacingOccurrences(of: "\t", with: " ")

            tsv += "\(escapedFront)\t\(escapedBack)\n"
        }

        return tsv
    }

    /// Export to Markdown format
    private func exportToMarkdown() -> String {
        var md = "# Vocabulary List\n\n"
        md += "Exported from MandarinKit on \(Date().formatted(date: .long, time: .shortened))\n\n"
        md += "| Chinese | Pinyin | Definition | POS |\n"
        md += "|---------|--------|------------|-----|\n"

        for term in terms {
            let chinese = term.chinese.replacingOccurrences(of: "|", with: "\\|")
            let pinyin = term.pinyin.replacingOccurrences(of: "|", with: "\\|")
            let definition = term.definition.replacingOccurrences(of: "|", with: "\\|")
            let pos = term.partOfSpeech.replacingOccurrences(of: "|", with: "\\|")

            md += "| \(chinese) | \(pinyin) | \(definition) | \(pos) |\n"
        }

        md += "\n---\n*\(terms.count) terms total*\n"

        return md
    }

    /// Export to JSON format
    private func exportToJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(terms),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }

    /// Helper to escape CSV values
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    // MARK: - Private Methods

    private func updateSortOrders() {
        for (index, _) in terms.enumerated() {
            terms[index].sortOrder = index
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(terms) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([SavedTerm].self, from: data) {
            terms = decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/SidebarItem.swift
```swift
import Foundation

/// Sidebar items - core functions plus vocabulary, phrases, and statistics
enum SidebarItem: String, CaseIterable, Identifiable {
    case translate
    case vocabulary
    case phrases
    case learn
    case history
    case statistics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translate: return "Translate"
        case .vocabulary: return "Vocabulary"
        case .phrases: return "Phrases"
        case .learn: return "Learn"
        case .history: return "History"
        case .statistics: return "Statistics"
        }
    }

    var symbol: String {
        switch self {
        case .translate: return "character.bubble"
        case .vocabulary: return "bookmark"
        case .phrases: return "text.bubble"
        case .learn: return "rectangle.stack"
        case .history: return "clock.arrow.circlepath"
        case .statistics: return "chart.bar"
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/PhraseCollection.swift
```swift
//
//  PhraseCollection.swift
//  MandarinKit
//
//  Pre-built phrase collections for quick learning
//

import SwiftUI
import Combine

// MARK: - Phrase Model

struct Phrase: Identifiable, Codable, Equatable {
    let id: UUID
    let chinese: String
    let pinyin: String
    let english: String
    let category: String
    var isFavorite: Bool

    init(id: UUID = UUID(), chinese: String, pinyin: String, english: String, category: String, isFavorite: Bool = false) {
        self.id = id
        self.chinese = chinese
        self.pinyin = pinyin
        self.english = english
        self.category = category
        self.isFavorite = isFavorite
    }
}

// MARK: - Phrase Category

enum PhraseCategory: String, CaseIterable, Identifiable {
    case greetings = "Greetings"
    case basics = "Basics"
    case food = "Food & Dining"
    case travel = "Travel"
    case shopping = "Shopping"
    case numbers = "Numbers"
    case time = "Time & Dates"
    case emergencies = "Emergencies"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .greetings: return "hand.wave"
        case .basics: return "text.bubble"
        case .food: return "fork.knife"
        case .travel: return "airplane"
        case .shopping: return "bag"
        case .numbers: return "number"
        case .time: return "clock"
        case .emergencies: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .greetings: return .blue
        case .basics: return .green
        case .food: return .orange
        case .travel: return .purple
        case .shopping: return .pink
        case .numbers: return .cyan
        case .time: return .indigo
        case .emergencies: return .red
        }
    }

    var phrases: [Phrase] {
        switch self {
        case .greetings:
            return [
                Phrase(chinese: "你好", pinyin: "nǐ hǎo", english: "Hello", category: rawValue),
                Phrase(chinese: "早上好", pinyin: "zǎo shang hǎo", english: "Good morning", category: rawValue),
                Phrase(chinese: "下午好", pinyin: "xià wǔ hǎo", english: "Good afternoon", category: rawValue),
                Phrase(chinese: "晚上好", pinyin: "wǎn shang hǎo", english: "Good evening", category: rawValue),
                Phrase(chinese: "晚安", pinyin: "wǎn ān", english: "Good night", category: rawValue),
                Phrase(chinese: "再见", pinyin: "zài jiàn", english: "Goodbye", category: rawValue),
                Phrase(chinese: "谢谢", pinyin: "xiè xiè", english: "Thank you", category: rawValue),
                Phrase(chinese: "不客气", pinyin: "bú kè qi", english: "You're welcome", category: rawValue),
                Phrase(chinese: "对不起", pinyin: "duì bu qǐ", english: "Sorry", category: rawValue),
                Phrase(chinese: "没关系", pinyin: "méi guān xi", english: "It's okay / No problem", category: rawValue),
                Phrase(chinese: "请", pinyin: "qǐng", english: "Please", category: rawValue),
                Phrase(chinese: "你好吗？", pinyin: "nǐ hǎo ma?", english: "How are you?", category: rawValue),
                Phrase(chinese: "很高兴认识你", pinyin: "hěn gāo xìng rèn shi nǐ", english: "Nice to meet you", category: rawValue),
            ]

        case .basics:
            return [
                Phrase(chinese: "是", pinyin: "shì", english: "Yes / Is", category: rawValue),
                Phrase(chinese: "不是", pinyin: "bú shì", english: "No / Is not", category: rawValue),
                Phrase(chinese: "好", pinyin: "hǎo", english: "Good / OK", category: rawValue),
                Phrase(chinese: "不好", pinyin: "bù hǎo", english: "Not good", category: rawValue),
                Phrase(chinese: "我", pinyin: "wǒ", english: "I / Me", category: rawValue),
                Phrase(chinese: "你", pinyin: "nǐ", english: "You", category: rawValue),
                Phrase(chinese: "他/她", pinyin: "tā", english: "He / She", category: rawValue),
                Phrase(chinese: "我们", pinyin: "wǒ men", english: "We / Us", category: rawValue),
                Phrase(chinese: "什么？", pinyin: "shén me?", english: "What?", category: rawValue),
                Phrase(chinese: "哪里？", pinyin: "nǎ lǐ?", english: "Where?", category: rawValue),
                Phrase(chinese: "什么时候？", pinyin: "shén me shí hou?", english: "When?", category: rawValue),
                Phrase(chinese: "为什么？", pinyin: "wèi shén me?", english: "Why?", category: rawValue),
                Phrase(chinese: "怎么？", pinyin: "zěn me?", english: "How?", category: rawValue),
                Phrase(chinese: "我不懂", pinyin: "wǒ bù dǒng", english: "I don't understand", category: rawValue),
                Phrase(chinese: "请再说一遍", pinyin: "qǐng zài shuō yí biàn", english: "Please say it again", category: rawValue),
            ]

        case .food:
            return [
                Phrase(chinese: "我饿了", pinyin: "wǒ è le", english: "I'm hungry", category: rawValue),
                Phrase(chinese: "我渴了", pinyin: "wǒ kě le", english: "I'm thirsty", category: rawValue),
                Phrase(chinese: "菜单", pinyin: "cài dān", english: "Menu", category: rawValue),
                Phrase(chinese: "点菜", pinyin: "diǎn cài", english: "To order food", category: rawValue),
                Phrase(chinese: "买单", pinyin: "mǎi dān", english: "The bill, please", category: rawValue),
                Phrase(chinese: "好吃", pinyin: "hǎo chī", english: "Delicious", category: rawValue),
                Phrase(chinese: "水", pinyin: "shuǐ", english: "Water", category: rawValue),
                Phrase(chinese: "茶", pinyin: "chá", english: "Tea", category: rawValue),
                Phrase(chinese: "咖啡", pinyin: "kā fēi", english: "Coffee", category: rawValue),
                Phrase(chinese: "米饭", pinyin: "mǐ fàn", english: "Rice", category: rawValue),
                Phrase(chinese: "面条", pinyin: "miàn tiáo", english: "Noodles", category: rawValue),
                Phrase(chinese: "饺子", pinyin: "jiǎo zi", english: "Dumplings", category: rawValue),
                Phrase(chinese: "我吃素", pinyin: "wǒ chī sù", english: "I'm vegetarian", category: rawValue),
                Phrase(chinese: "不要辣", pinyin: "bú yào là", english: "Not spicy, please", category: rawValue),
            ]

        case .travel:
            return [
                Phrase(chinese: "机场", pinyin: "jī chǎng", english: "Airport", category: rawValue),
                Phrase(chinese: "火车站", pinyin: "huǒ chē zhàn", english: "Train station", category: rawValue),
                Phrase(chinese: "地铁", pinyin: "dì tiě", english: "Subway / Metro", category: rawValue),
                Phrase(chinese: "出租车", pinyin: "chū zū chē", english: "Taxi", category: rawValue),
                Phrase(chinese: "酒店", pinyin: "jiǔ diàn", english: "Hotel", category: rawValue),
                Phrase(chinese: "厕所在哪里？", pinyin: "cè suǒ zài nǎ lǐ?", english: "Where is the bathroom?", category: rawValue),
                Phrase(chinese: "我迷路了", pinyin: "wǒ mí lù le", english: "I'm lost", category: rawValue),
                Phrase(chinese: "左", pinyin: "zuǒ", english: "Left", category: rawValue),
                Phrase(chinese: "右", pinyin: "yòu", english: "Right", category: rawValue),
                Phrase(chinese: "直走", pinyin: "zhí zǒu", english: "Go straight", category: rawValue),
                Phrase(chinese: "护照", pinyin: "hù zhào", english: "Passport", category: rawValue),
                Phrase(chinese: "签证", pinyin: "qiān zhèng", english: "Visa", category: rawValue),
            ]

        case .shopping:
            return [
                Phrase(chinese: "多少钱？", pinyin: "duō shǎo qián?", english: "How much?", category: rawValue),
                Phrase(chinese: "太贵了", pinyin: "tài guì le", english: "Too expensive", category: rawValue),
                Phrase(chinese: "便宜一点", pinyin: "pián yi yì diǎn", english: "A bit cheaper", category: rawValue),
                Phrase(chinese: "我要这个", pinyin: "wǒ yào zhè ge", english: "I want this one", category: rawValue),
                Phrase(chinese: "可以试试吗？", pinyin: "kě yǐ shì shi ma?", english: "Can I try it?", category: rawValue),
                Phrase(chinese: "大", pinyin: "dà", english: "Big / Large", category: rawValue),
                Phrase(chinese: "小", pinyin: "xiǎo", english: "Small", category: rawValue),
                Phrase(chinese: "现金", pinyin: "xiàn jīn", english: "Cash", category: rawValue),
                Phrase(chinese: "信用卡", pinyin: "xìn yòng kǎ", english: "Credit card", category: rawValue),
                Phrase(chinese: "收据", pinyin: "shōu jù", english: "Receipt", category: rawValue),
            ]

        case .numbers:
            return [
                Phrase(chinese: "零", pinyin: "líng", english: "0 (zero)", category: rawValue),
                Phrase(chinese: "一", pinyin: "yī", english: "1 (one)", category: rawValue),
                Phrase(chinese: "二", pinyin: "èr", english: "2 (two)", category: rawValue),
                Phrase(chinese: "三", pinyin: "sān", english: "3 (three)", category: rawValue),
                Phrase(chinese: "四", pinyin: "sì", english: "4 (four)", category: rawValue),
                Phrase(chinese: "五", pinyin: "wǔ", english: "5 (five)", category: rawValue),
                Phrase(chinese: "六", pinyin: "liù", english: "6 (six)", category: rawValue),
                Phrase(chinese: "七", pinyin: "qī", english: "7 (seven)", category: rawValue),
                Phrase(chinese: "八", pinyin: "bā", english: "8 (eight)", category: rawValue),
                Phrase(chinese: "九", pinyin: "jiǔ", english: "9 (nine)", category: rawValue),
                Phrase(chinese: "十", pinyin: "shí", english: "10 (ten)", category: rawValue),
                Phrase(chinese: "百", pinyin: "bǎi", english: "100 (hundred)", category: rawValue),
                Phrase(chinese: "千", pinyin: "qiān", english: "1000 (thousand)", category: rawValue),
                Phrase(chinese: "万", pinyin: "wàn", english: "10,000 (ten thousand)", category: rawValue),
            ]

        case .time:
            return [
                Phrase(chinese: "今天", pinyin: "jīn tiān", english: "Today", category: rawValue),
                Phrase(chinese: "明天", pinyin: "míng tiān", english: "Tomorrow", category: rawValue),
                Phrase(chinese: "昨天", pinyin: "zuó tiān", english: "Yesterday", category: rawValue),
                Phrase(chinese: "现在", pinyin: "xiàn zài", english: "Now", category: rawValue),
                Phrase(chinese: "以后", pinyin: "yǐ hòu", english: "Later", category: rawValue),
                Phrase(chinese: "早上", pinyin: "zǎo shang", english: "Morning", category: rawValue),
                Phrase(chinese: "下午", pinyin: "xià wǔ", english: "Afternoon", category: rawValue),
                Phrase(chinese: "晚上", pinyin: "wǎn shang", english: "Evening", category: rawValue),
                Phrase(chinese: "几点了？", pinyin: "jǐ diǎn le?", english: "What time is it?", category: rawValue),
                Phrase(chinese: "星期一", pinyin: "xīng qī yī", english: "Monday", category: rawValue),
                Phrase(chinese: "星期二", pinyin: "xīng qī èr", english: "Tuesday", category: rawValue),
                Phrase(chinese: "周末", pinyin: "zhōu mò", english: "Weekend", category: rawValue),
            ]

        case .emergencies:
            return [
                Phrase(chinese: "救命！", pinyin: "jiù mìng!", english: "Help!", category: rawValue),
                Phrase(chinese: "请帮帮我", pinyin: "qǐng bāng bang wǒ", english: "Please help me", category: rawValue),
                Phrase(chinese: "我需要医生", pinyin: "wǒ xū yào yī shēng", english: "I need a doctor", category: rawValue),
                Phrase(chinese: "医院", pinyin: "yī yuàn", english: "Hospital", category: rawValue),
                Phrase(chinese: "警察", pinyin: "jǐng chá", english: "Police", category: rawValue),
                Phrase(chinese: "我生病了", pinyin: "wǒ shēng bìng le", english: "I'm sick", category: rawValue),
                Phrase(chinese: "我受伤了", pinyin: "wǒ shòu shāng le", english: "I'm injured", category: rawValue),
                Phrase(chinese: "药房", pinyin: "yào fáng", english: "Pharmacy", category: rawValue),
                Phrase(chinese: "火灾", pinyin: "huǒ zāi", english: "Fire", category: rawValue),
                Phrase(chinese: "大使馆", pinyin: "dà shǐ guǎn", english: "Embassy", category: rawValue),
            ]
        }
    }
}

// MARK: - Phrase Collection Store

final class PhraseCollectionStore: ObservableObject {
    static let shared = PhraseCollectionStore()

    @Published var favoritePhrases: [Phrase] = [] {
        didSet { saveFavorites() }
    }

    private let favoritesKey = "favoritePhrases"

    private init() {
        loadFavorites()
    }

    func toggleFavorite(_ phrase: Phrase) {
        if let index = favoritePhrases.firstIndex(where: { $0.chinese == phrase.chinese }) {
            favoritePhrases.remove(at: index)
        } else {
            var newPhrase = phrase
            newPhrase.isFavorite = true
            favoritePhrases.append(newPhrase)
        }
    }

    func isFavorite(_ phrase: Phrase) -> Bool {
        favoritePhrases.contains(where: { $0.chinese == phrase.chinese })
    }

    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoritePhrases) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([Phrase].self, from: data) {
            favoritePhrases = decoded
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/LearningProgress.swift
```swift
//
//  LearningProgress.swift
//  MandarinKit
//
//  Tracks learning progress for flashcards with spaced repetition
//

import Foundation
import Combine

/// Represents the learning progress for a single card
struct CardProgress: Codable, Identifiable {
    let cardId: String
    var masteryLevel: MasteryLevel
    var reviewCount: Int
    var correctCount: Int
    var lastReviewDate: Date?
    var nextReviewDate: Date?
    var easeFactor: Double // For spaced repetition algorithm

    var id: String { cardId }

    var accuracy: Double {
        guard reviewCount > 0 else { return 0 }
        return Double(correctCount) / Double(reviewCount)
    }

    init(cardId: String) {
        self.cardId = cardId
        self.masteryLevel = .new
        self.reviewCount = 0
        self.correctCount = 0
        self.lastReviewDate = nil
        self.nextReviewDate = nil
        self.easeFactor = 2.5 // Default ease factor for SM-2 algorithm
    }

    /// Update progress after a review
    mutating func recordReview(correct: Bool, quality: ReviewQuality) {
        reviewCount += 1
        if correct {
            correctCount += 1
        }
        lastReviewDate = Date()

        // Update mastery level based on accuracy
        updateMasteryLevel()

        // Calculate next review date using simplified SM-2 algorithm
        calculateNextReview(quality: quality)
    }

    private mutating func updateMasteryLevel() {
        switch accuracy {
        case 0..<0.3:
            masteryLevel = .learning
        case 0.3..<0.5:
            masteryLevel = .learning
        case 0.5..<0.7:
            masteryLevel = .familiar
        case 0.7..<0.9:
            masteryLevel = .proficient
        default:
            if reviewCount >= 5 {
                masteryLevel = .mastered
            } else {
                masteryLevel = .proficient
            }
        }
    }

    private mutating func calculateNextReview(quality: ReviewQuality) {
        // Simplified SM-2 spaced repetition
        let q = Double(quality.rawValue)

        // Update ease factor
        easeFactor = max(1.3, easeFactor + 0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))

        // Calculate interval
        let interval: TimeInterval
        if quality.rawValue < 3 {
            // Failed review - review again soon
            interval = 60 * 10 // 10 minutes
        } else {
            switch reviewCount {
            case 1:
                interval = 60 * 60 * 24 // 1 day
            case 2:
                interval = 60 * 60 * 24 * 6 // 6 days
            default:
                let previousInterval = lastReviewDate.map { Date().timeIntervalSince($0) } ?? (60 * 60 * 24)
                interval = previousInterval * easeFactor
            }
        }

        nextReviewDate = Date().addingTimeInterval(interval)
    }
}

/// Mastery levels for learning progress
enum MasteryLevel: String, Codable, CaseIterable {
    case new
    case learning
    case familiar
    case proficient
    case mastered

    var label: String {
        switch self {
        case .new: return "New"
        case .learning: return "Learning"
        case .familiar: return "Familiar"
        case .proficient: return "Proficient"
        case .mastered: return "Mastered"
        }
    }

    var color: String {
        switch self {
        case .new: return "gray"
        case .learning: return "orange"
        case .familiar: return "yellow"
        case .proficient: return "blue"
        case .mastered: return "green"
        }
    }

    var symbol: String {
        switch self {
        case .new: return "circle"
        case .learning: return "circle.bottomhalf.filled"
        case .familiar: return "circle.inset.filled"
        case .proficient: return "checkmark.circle"
        case .mastered: return "checkmark.circle.fill"
        }
    }
}

/// Quality rating for card reviews (used in spaced repetition)
enum ReviewQuality: Int, CaseIterable {
    case blackout = 0      // Complete blackout
    case incorrect = 1     // Incorrect, but recognized answer
    case difficult = 2     // Incorrect, easy to recall
    case hard = 3          // Correct with difficulty
    case good = 4          // Correct with some hesitation
    case easy = 5          // Perfect recall

    var label: String {
        switch self {
        case .blackout: return "Blackout"
        case .incorrect: return "Incorrect"
        case .difficult: return "Difficult"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

/// Manages learning progress for all cards
final class LearningProgressStore: ObservableObject {
    static let shared = LearningProgressStore()

    @Published private(set) var progress: [String: CardProgress] = [:]
    @Published private(set) var todayReviewedCount: Int = 0

    private let storageKey = "learningProgress"
    private let todayCountKey = "todayReviewedCount"
    private let lastResetDateKey = "lastProgressResetDate"

    private init() {
        load()
        resetDailyCountIfNeeded()
    }

    func getProgress(for cardId: String) -> CardProgress {
        progress[cardId] ?? CardProgress(cardId: cardId)
    }

    func recordReview(cardId: String, correct: Bool, quality: ReviewQuality) {
        var cardProgress = getProgress(for: cardId)
        cardProgress.recordReview(correct: correct, quality: quality)
        progress[cardId] = cardProgress
        todayReviewedCount += 1
        save()

        // Update global stats
        UserPreferences.shared.recordPracticeSession(cardsReviewed: 1)
    }

    func getCardsForReview(from cards: [LearningCard], limit: Int = 20) -> [LearningCard] {
        let now = Date()

        // Sort cards by priority: due for review, then new cards
        let sorted = cards.sorted { card1, card2 in
            let p1 = getProgress(for: card1.id)
            let p2 = getProgress(for: card2.id)

            // New cards have lowest priority
            if p1.masteryLevel == .new && p2.masteryLevel != .new {
                return false
            }
            if p1.masteryLevel != .new && p2.masteryLevel == .new {
                return true
            }

            // Cards due for review come first
            let due1 = p1.nextReviewDate ?? .distantPast
            let due2 = p2.nextReviewDate ?? .distantPast

            if due1 <= now && due2 > now {
                return true
            }
            if due1 > now && due2 <= now {
                return false
            }

            return due1 < due2
        }

        return Array(sorted.prefix(limit))
    }

    func getDueCards(from cards: [LearningCard]) -> [LearningCard] {
        let now = Date()
        return cards.filter { card in
            let p = getProgress(for: card.id)
            guard let nextReview = p.nextReviewDate else {
                return p.masteryLevel == .new
            }
            return nextReview <= now
        }
    }

    func getStats() -> LearningStats {
        let allProgress = Array(progress.values)

        let masteryDistribution = Dictionary(grouping: allProgress) { $0.masteryLevel }
            .mapValues { $0.count }

        let totalReviews = allProgress.reduce(0) { $0 + $1.reviewCount }
        let totalCorrect = allProgress.reduce(0) { $0 + $1.correctCount }
        let overallAccuracy = totalReviews > 0 ? Double(totalCorrect) / Double(totalReviews) : 0

        let dueCount = getDueCards(from: LearningDeck.cards).count

        return LearningStats(
            totalCards: progress.count,
            masteryDistribution: masteryDistribution,
            overallAccuracy: overallAccuracy,
            totalReviews: totalReviews,
            todayReviewed: todayReviewedCount,
            dueCount: dueCount
        )
    }

    /// Get count of cards at mastered level
    func getMasteredCount(from cards: [LearningCard]) -> Int {
        cards.filter { card in
            let p = getProgress(for: card.id)
            return p.masteryLevel == .mastered
        }.count
    }

    /// Get count of cards currently being learned (not new, not mastered)
    func getLearningCount(from cards: [LearningCard]) -> Int {
        cards.filter { card in
            let p = getProgress(for: card.id)
            return p.masteryLevel != .new && p.masteryLevel != .mastered
        }.count
    }

    func resetProgress() {
        progress.removeAll()
        todayReviewedCount = 0
        save()
    }

    private func resetDailyCountIfNeeded() {
        let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? .distantPast
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastResetDate) {
            todayReviewedCount = 0
            UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: CardProgress].self, from: data) {
            progress = decoded
        }
        todayReviewedCount = UserDefaults.standard.integer(forKey: todayCountKey)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        UserDefaults.standard.set(todayReviewedCount, forKey: todayCountKey)
    }
}

/// Statistics summary for learning progress
struct LearningStats {
    let totalCards: Int
    let masteryDistribution: [MasteryLevel: Int]
    let overallAccuracy: Double
    let totalReviews: Int
    let todayReviewed: Int
    let dueCount: Int

    func count(for level: MasteryLevel) -> Int {
        masteryDistribution[level] ?? 0
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/LearningCard.swift
```swift
import Foundation

struct LearningCard: Identifiable, Hashable {
    let id: String
    let chinese: String
    let english: String
    let tags: [String]
    let notes: String?

    init(chinese: String, english: String, tags: [String] = [], notes: String? = nil) {
        self.id = chinese
        self.chinese = chinese
        self.english = english
        self.tags = tags
        self.notes = notes
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/LearningDeck.swift
```swift
import Foundation

enum LearningDeck {
    static let cards: [LearningCard] = [
        LearningCard(chinese: "你好", english: "Hello", tags: ["Greeting"], notes: "Friendly greeting."),
        LearningCard(chinese: "谢谢", english: "Thank you", tags: ["Polite"], notes: "Often followed by 你/您."),
        LearningCard(chinese: "对不起", english: "Sorry", tags: ["Polite"]),
        LearningCard(chinese: "没关系", english: "It's okay / No problem", tags: ["Polite"]),
        LearningCard(chinese: "再见", english: "Goodbye", tags: ["Greeting"]),
        LearningCard(chinese: "请问", english: "Excuse me (to ask)", tags: ["Travel"]),
        LearningCard(chinese: "多少钱", english: "How much is it?", tags: ["Shopping"]),
        LearningCard(chinese: "我想要这个", english: "I want this", tags: ["Shopping"]),
        LearningCard(chinese: "卫生间在哪儿", english: "Where is the restroom?", tags: ["Travel"]),
        LearningCard(chinese: "我叫…", english: "My name is…", tags: ["Intro"]),
        LearningCard(chinese: "你叫什么名字", english: "What's your name?", tags: ["Intro"]),
        LearningCard(chinese: "今天", english: "Today", tags: ["Time"]),
        LearningCard(chinese: "明天", english: "Tomorrow", tags: ["Time"]),
        LearningCard(chinese: "我会说一点中文", english: "I can speak a little Chinese", tags: ["Intro"]),
        LearningCard(chinese: "请慢一点", english: "Please speak more slowly", tags: ["Travel"]),
        LearningCard(chinese: "我听不懂", english: "I don't understand", tags: ["Travel"]),
        LearningCard(chinese: "好吃", english: "Delicious", tags: ["Food"]),
        LearningCard(chinese: "我们走吧", english: "Let's go", tags: ["Everyday"])
    ]
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/Shared/Models/Favorite.swift
```swift
//
//  Favorite.swift
//  MandarinKit
//
//  Model and storage for favorite translations and cards
//

import Foundation
import Combine
import SwiftUI

/// A favorited translation entry
struct FavoriteTranslation: Identifiable, Codable, Hashable {
    let id: UUID
    let source: String
    let target: String
    let directionRaw: String
    let dateAdded: Date
    var notes: String?
    var tags: [String]

    init(source: String, target: String, direction: TranslationDirection, notes: String? = nil, tags: [String] = []) {
        self.id = UUID()
        self.source = source
        self.target = target
        self.directionRaw = direction.rawValue
        self.dateAdded = Date()
        self.notes = notes
        self.tags = tags
    }

    init(from historyEntry: TranslationHistoryEntry) {
        self.id = UUID()
        self.source = historyEntry.source
        self.target = historyEntry.target
        self.directionRaw = historyEntry.directionRaw
        self.dateAdded = Date()
        self.notes = nil
        self.tags = []
    }

    var direction: TranslationDirection {
        TranslationDirection(rawValue: directionRaw) ?? .englishToChinese
    }

    var chineseText: String {
        direction == .englishToChinese ? target : source
    }

    var englishText: String {
        direction == .englishToChinese ? source : target
    }
}

/// Manages favorite translations
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var favorites: [FavoriteTranslation] = []
    @Published var selectedFavorite: FavoriteTranslation?

    private let storageKey = "favoriteTranslations"

    private init() {
        load()
    }

    func add(_ favorite: FavoriteTranslation) {
        // Check for duplicates
        guard !favorites.contains(where: { $0.source == favorite.source && $0.target == favorite.target }) else {
            return
        }
        favorites.insert(favorite, at: 0)
        save()
    }

    func addFromHistory(_ entry: TranslationHistoryEntry) {
        let favorite = FavoriteTranslation(from: entry)
        add(favorite)
    }

    func remove(_ favorite: FavoriteTranslation) {
        favorites.removeAll { $0.id == favorite.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    func update(_ favorite: FavoriteTranslation) {
        if let index = favorites.firstIndex(where: { $0.id == favorite.id }) {
            favorites[index] = favorite
            save()
        }
    }

    func isFavorite(source: String, target: String) -> Bool {
        favorites.contains { $0.source == source && $0.target == target }
    }

    func toggleFavorite(source: String, target: String, direction: TranslationDirection) {
        if let existing = favorites.first(where: { $0.source == source && $0.target == target }) {
            remove(existing)
        } else {
            let favorite = FavoriteTranslation(source: source, target: target, direction: direction)
            add(favorite)
        }
    }

    func search(_ query: String) -> [FavoriteTranslation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return favorites }

        return favorites.filter { favorite in
            favorite.source.localizedCaseInsensitiveContains(trimmed) ||
            favorite.target.localizedCaseInsensitiveContains(trimmed) ||
            favorite.notes?.localizedCaseInsensitiveContains(trimmed) == true ||
            favorite.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    func filterByTag(_ tag: String) -> [FavoriteTranslation] {
        favorites.filter { $0.tags.contains(tag) }
    }

    var allTags: [String] {
        Array(Set(favorites.flatMap { $0.tags })).sorted()
    }

    func clear() {
        favorites.removeAll()
        selectedFavorite = nil
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([FavoriteTranslation].self, from: data) {
            favorites = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

```

File: /Users/rogerlin/XCode-Projects/MandarinKit/handoff.md
```md
# Handoff.md - MandarinKit Redesign

**Last Updated (UTC):** 2026-02-10T02:30:00Z
**Status:** In Progress
**Current Focus:** Feature Enhancement & UI Polish Complete

## 1) Request & Context

- **User's request:** The app was getting "too messy and poorly designed." User wanted a clean, intuitive, natural user experience, rebuilt from first principles.
- **Key issues identified:**
  1. Pinyin not showing above characters in TranslateView
  2. Clicking history items didn't load the translation properly
  3. Too many views creating cognitive overload (Dashboard, Practice, Flashcards, Favorites, Pinyin - all separate)
  4. Sidebar sections adding friction
  5. Over-engineered features nobody asked for

## 2) First Principles Analysis

**What does a Mandarin learning app actually need?**
1. **Translate** - English ↔ Chinese with pinyin
2. **Learn** - Review vocabulary with flashcards
3. **History** - Access past translations

That's it. Three core functions. Everything else was noise.

## 3) Changes Made

### Removed (simplified away)
- `DashboardView.swift` - Stats dashboard nobody needed
- `FavoritesView.swift` - Merged functionality into history
- `FlashcardsView.swift` - Merged into LearnView
- `PinyinView.swift` - Pinyin is now always shown in context
- `SidebarSection` enum - No more section headers
- Onboarding flow - Unnecessary friction
- Complex menu commands - Simplified to essentials
- Favorites system - Removed for simplicity

### Simplified Files

**SidebarItem.swift**
- Now just 3 items: `translate`, `learn`, `history`
- No sections, no complexity

**ContentView.swift**
- Clean NavigationSplitView with 3 destinations
- Simple sidebar list without sections
- Removed onboarding, progress indicators, streak badges

**MandarinKitApp.swift**
- Simplified menu commands
- Just essential navigation and translation shortcuts
- Removed 20+ notification names down to 2

### Rewritten Files

**TranslateView.swift** - Complete rewrite
- Clean two-pane layout (input | output)
- Direction toggle bar at top
- **Fixed:** AnnotatedChineseText now properly displays:
  - When translating TO Chinese: shows annotated output
  - When translating FROM Chinese: shows English translation + annotated source below
- **Fixed:** History loading now works via `onAppear` and `onReceive` with proper timing
- Pinyin toggle in output pane footer
- Removed: Intelligence tips, favorites, language status cards

**HistoryView.swift** - Complete rewrite
- Simple search bar header
- Clean list with swipe-to-delete
- Each row shows: source, target, pinyin, direction, relative time
- Tap to load into TranslateView
- Removed: Filters, favorites integration, complex cards

**LearnView.swift** - Complete rewrite
- Clean flashcard interface
- Progress bar at top
- Large centered card with Chinese + pinyin annotation
- Tap to reveal answer
- Rating buttons (Again/Good/Easy) appear after reveal
- Session complete state
- Empty state when no cards due
- Removed: Stats cards, coaching, navigation controls, complex progress tracking

## 4) New App Structure

```
MandarinKit/
├── MandarinKitApp.swift          (Simplified app entry)
├── ContentView.swift             (3-destination navigation)
├── Models/
│   ├── SidebarItem.swift         (3 items only)
│   ├── LearningCard.swift
│   ├── LearningDeck.swift
│   ├── LearningProgress.swift
│   └── Favorite.swift            (kept but unused)
├── Services/
│   ├── UserPreferences.swift
│   ├── TranslationHistoryStore.swift
│   └── ... (other services)
└── Views/
    ├── TranslateView.swift       (REWRITTEN)
    ├── LearnView.swift           (REWRITTEN)
    ├── HistoryView.swift         (REWRITTEN)
    ├── AnnotatedChineseText.swift
    ├── CardContainer.swift
    ├── AppBackground.swift
    ├── AboutView.swift
    └── SettingsView.swift
```

## 5) Key Fixes

### Fix 1: Pinyin Above Characters
The AnnotatedChineseText component was created correctly but wasn't being used properly in TranslateView. Now:
- Translating EN→ZH: Output shows `AnnotatedChineseText` with pinyin above each character
- Translating ZH→EN: Output shows English translation, plus a "Source with Pinyin" section showing the annotated Chinese input

### Fix 2: History Loading
The issue was timing - `selectedEntry` was being cleared before the view could read it. Fixed by:
1. Loading on `onAppear`
2. Also loading on `onReceive(.navigateTo)` with a small delay
3. Clearing `selectedEntry` only after applying it

## 6) Build Status

- **Build:** ✅ Successful
- **Errors:** 0
- **Warnings:** 0

## 7) User Flow (New)

1. **Open app** → Lands on Translate view (not a dashboard)
2. **Translate** → Type/paste, hit translate, see result with pinyin
3. **History** → See past translations, tap to reload any
4. **Learn** → Practice flashcards with spaced repetition

Simple. Focused. Three things done well.

## 8) What Was Preserved

- Translation engine and API integration
- Spaced repetition algorithm
- Settings preferences
- AnnotatedChineseText component
- Speech service
- Pinyin converter
- App theming

## 9) Quality Checklist

- [x] Build succeeds with zero errors
- [x] Pinyin displays above Chinese characters
- [x] History items load into translate view
- [x] Three clear navigation destinations
- [x] No unnecessary complexity
- [x] Clean, focused UI

## 10) Next Phase: Apple API Integration

After the redesign, user requested research into Apple's native APIs and proposals for integration. A comprehensive proposal document has been created at `docs/apple-api-integration-proposals.md` covering:

### Proposed Integrations

1. **Translation Framework** - Replace custom translation service with Apple's on-device Translation API
   - Batch translation for vocabulary lists
   - Language availability management (download offline packs)
   - Translation overlay UI for quick lookups

2. **FoundationModels Framework** - On-device LLM for intelligent features
   - Learning tips generation
   - Example sentence generation (with @Generable for structured output)
   - Grammar explanations
   - Conversation practice with tool calling
   - Adaptive difficulty assessment

3. **Natural Language Framework** - Chinese text analysis
   - Word segmentation (critical for Chinese without spaces)
   - Interactive word lookup (tap any word)
   - Parts of speech tagging
   - Auto language detection
   - Sentence complexity analysis

4. **Apple Intelligence Writing Tools** - Composition assistance
   - Enable Writing Tools on text inputs
   - Writing practice mode

5. **TextKit** - Rich text rendering
   - Ruby annotations for pinyin
   - Tappable text with word detection
   - Tone color coding

### Recommended Priority
Start with Natural Language (word segmentation) and Translation Framework - high impact, moderate effort.

## 11) Updates

- 2026-02-09 03:00: Complete redesign from first principles
  - Removed 4 views (Dashboard, Favorites, Flashcards, Pinyin)
  - Rewrote 3 views (Translate, Learn, History)
  - Simplified sidebar from 7 items to 3
  - Fixed pinyin annotation display
  - Fixed history item loading

- 2026-02-09 04:30: API Integration Research & Proposals
  - Researched Apple's Translation, FoundationModels, Natural Language, Writing Tools, and TextKit APIs
  - Created comprehensive proposals document at `docs/apple-api-integration-proposals.md`
  - Documented 5 major integration areas with code examples
  - Outlined 4-week implementation roadmap
  - Identified technical requirements (macOS 26, entitlements)

- 2026-02-09 05:30: Implemented Natural Language + Translation Framework Integration
  - **New Files Created:**
    - `ChineseTextAnalyzer.swift` - Natural Language framework integration
      - Word segmentation using NLTokenizer
      - Parts of speech tagging using NLTagger
      - Language detection using NLLanguageRecognizer
      - Sentence complexity analysis
    - `InteractiveChineseText.swift` - Tappable word-by-word Chinese text display
      - Uses ChineseTextAnalyzer for intelligent word boundaries
      - Each word is tappable to show a detail popover
      - Popover shows: pinyin, part of speech, character breakdown
      - Listen and copy actions for each word

  - **Updated Files:**
    - `TranslateView.swift` - Now uses InteractiveChineseText instead of AnnotatedChineseText
      - Added auto language detection (switches direction based on input)
      - Chinese output is now word-by-word interactive
    - `LearnView.swift` - Now uses InteractiveChineseText for flashcards
      - Flashcard Chinese text is now tappable for word details

  - **Features Implemented:**
    - ✅ Word segmentation (Chinese text properly split into words)
    - ✅ Parts of speech tagging (color-coded option available)
    - ✅ Auto language detection (>70% confidence threshold)
    - ✅ Interactive word popovers with pinyin, POS, character breakdown
    - ✅ Listen/copy actions per word

  - **Build Status:** ✅ Successful with 0 errors

- 2026-02-10 00:00: Cross-Platform Architecture Implementation (iOS 26 / iPadOS 26)
  - **Objective:** Extend MandarinKit from macOS-only to support iOS 26 and iPadOS 26

  - **Research Completed:**
    - Liquid Glass design system (glassEffect, .buttonStyle(.glass))
    - Translation Framework cross-platform compatibility
    - TabView with .sidebarAdaptable for adaptive navigation
    - UIPasteboard for iOS clipboard operations
    - Human Interface Guidelines for iOS/iPadOS 26
    - Platform conditional compilation (#if os(macOS) / #if os(iOS))

  - **Files Modified for Cross-Platform Support:**
    - `ClipboardService.swift` - Added UIPasteboard support for iOS
      - Uses #if os(macOS) / #else for platform-specific pasteboard APIs
      - NSPasteboard (macOS) → UIPasteboard (iOS)

    - `AppTheme.swift` - Added UIColor support for iOS
      - Platform-conditional color definitions
      - NSColor (macOS) → UIColor (iOS)
      - Same semantic colors across platforms

    - `LiquidGlassHelpers.swift` - Added iOS 26 availability checks
      - Changed `#available(macOS 26.0, *)` to `#available(macOS 26.0, iOS 26.0, *)`
      - Liquid Glass effects work on all platforms in iOS/macOS 26+

    - `MandarinKitApp.swift` - Platform-conditional app structure
      - macOS: MacContentView + NavigationSplitView + Settings scene + menu commands
      - iOS: MobileContentView + TabView with sidebarAdaptable
      - Commands wrapped in #if os(macOS)

    - `ContentView.swift` - Split into platform-specific content views
      - MacContentView: NavigationSplitView with sidebar + Settings button
      - MobileContentView: TabView with 4 tabs + Settings sheet
      - DetailView: Shared component for detail content
      - SidebarItemRow: Shared component for sidebar rows
      - OnboardingView: Made cross-platform with platform-specific frame

    - `SettingsView.swift` - Added MobileSettingsView for iOS
      - macOS: TabView with grouped forms (existing)
      - iOS: List-based settings in a sheet presentation
      - All settings categories: General, Appearance, Translation, Pinyin, Learning, Speech, Statistics, About

  - **Navigation Architecture:**
    - macOS: NavigationSplitView (sidebar + detail)
    - iPadOS: TabView with .sidebarAdaptable (sidebar in landscape, tab bar in portrait)
    - iOS: TabView with .sidebarAdaptable (tab bar navigation)
    - All platforms share the same detail views (TranslateView, SavedTermsView, LearnView, HistoryView)

  - **Platform-Specific Adaptations:**
    - macOS: Menu bar integration, keyboard shortcuts, Settings window
    - iOS/iPadOS: Tab bar navigation, Settings presented as sheet, gear button in toolbar
    - Shared: All core views, models, services, Liquid Glass styling

  - **Build Status:** ✅ Successful with 0 errors (macOS)

  - **Architecture Document:** Created at `docs/cross-platform-architecture.md`
    - Complete analysis of platform-specific code
    - Detailed implementation plan in phases
    - Research references and API documentation
    - Success criteria and quality gates

- 2026-02-09 06:30: Added Vocabulary List, Settings Button, and Font Customization
  - **New Files Created:**
    - `SavedTerm.swift` - Model and store for saved vocabulary terms
      - SavedTerm struct with chinese, pinyin, definition, partOfSpeech, dateAdded, sortOrder
      - SavedTermsStore with add, remove, move, clear operations
      - Persists to UserDefaults
    - `SavedTermsView.swift` - View for displaying saved vocabulary
      - Searchable, sortable list
      - Each row shows pinyin above Chinese characters, definition, part of speech badge
      - Date/time added display
      - Listen, copy, delete actions per item
      - Drag-to-reorder support

  - **Updated Files:**
    - `InteractiveChineseText.swift` - Added "Save" button to word detail popover
      - Shows definition from Translation API
      - Save button adds term to vocabulary list
      - Shows "Saved" indicator if already in list
    - `SidebarItem.swift` - Added "vocabulary" case with bookmark icon
    - `ContentView.swift` - Added Vocabulary to navigation, Settings button at bottom of sidebar
    - `SettingsView.swift` - Added English Translation Font picker
      - 10 font options (Georgia, Palatino, Times New Roman, etc.)
      - Live preview in settings
    - `UserPreferences.swift` - Added englishTranslationFont property (default: Georgia)
    - `TranslateView.swift` - Uses custom font for English translations

  - **Features Implemented:**
    - ✅ Save terms from word popover to vocabulary list
    - ✅ Vocabulary view with sortable, searchable list
    - ✅ Pinyin displayed above Chinese characters in vocabulary
    - ✅ Copy button for each vocabulary item
    - ✅ Date/time added display
    - ✅ Settings button in sidebar
    - ✅ English translation font customization (10 fonts)
    - ✅ Custom font applied to Chinese→English translations

  - **Build Status:** ✅ Successful with 0 errors

- 2026-02-10 01:00: Universal Target Configuration & Shared Folder Structure
  - **Objective:** Configure MandarinKit-Universal target with shared code structure

  - **User Action:** Added multiplatform target "MandarinKit-Universal" with iOS 26.3 and macOS 26.3 minimum deployments

  - **File Structure Reorganization:**
    - Created `MandarinKit/Shared/` folder to house shared code between targets
    - Moved all shared Models (6 files):
      - Favorite.swift, LearningCard.swift, LearningDeck.swift, LearningProgress.swift, SavedTerm.swift, SidebarItem.swift
    - Moved all shared Services (10 files):
      - AppTheme.swift, ChineseTextAnalyzer.swift, ClipboardService.swift, IntelligenceCoach.swift, LiquidGlassHelpers.swift, PinyinConverter.swift, SpeechService.swift, TranslationDirection.swift, TranslationHistoryStore.swift, UserPreferences.swift
    - Moved all shared Views (10 files):
      - AboutView.swift, AnnotatedChineseText.swift, AppBackground.swift, CardContainer.swift, HistoryView.swift, InteractiveChineseText.swift, LearnView.swift, SavedTermsView.swift, SettingsView.swift, TranslateView.swift

  - **Final Project Structure:**
    ```
    MandarinKit/
    ├── MandarinKit/                    (macOS-only target)
    │   ├── MandarinKitApp.swift
    │   ├── ContentView.swift
    │   └── Assets.xcassets
    ├── MandarinKit-Universal/          (iOS + macOS target)
    │   ├── MandarinKit_UniversalApp.swift
    │   ├── ContentView.swift
    │   └── Assets.xcassets
    └── Shared/                         (shared between targets)
        ├── Models/ (6 files)
        ├── Services/ (10 files)
        └── Views/ (10 files)
    ```

  - **Universal Target App Structure:**
    - `MandarinKit_UniversalApp.swift`:
      - Platform-conditional content view (MacContentView vs MobileContentView)
      - macOS-only: Settings scene, menu commands
      - iOS: Settings sheet presentation
    - `ContentView.swift`:
      - `MacContentView`: NavigationSplitView with sidebar
      - `MobileContentView`: TabView with .sidebarAdaptable (4 tabs)
      - `DetailView`: Shared detail content
      - `SidebarItemRow`: Shared sidebar row component
      - Platform-specific previews

  - **Cross-Platform Features:**
    - ✅ MacContentView: NavigationSplitView with Settings button in sidebar
    - ✅ MobileContentView: TabView with .tabViewStyle(.sidebarAdaptable)
    - ✅ Tab-based navigation for iOS (Translate, Vocabulary, Learn, History)
    - ✅ Settings gear button in toolbar for iOS
    - ✅ MobileSettingsView: List-based settings for iOS
    - ✅ Platform-conditional clipboard (NSPasteboard vs UIPasteboard)
    - ✅ Platform-conditional colors (NSColor vs UIColor)
    - ✅ Liquid Glass effects with iOS 26 availability

  - **Build Status:** ✅ Successful with 0 errors, 0 warnings

  - **Next Steps:**
    1. User to add Shared folder to both targets with proper target membership
    2. Build and run on iOS Simulator to verify
    3. Test all features on both platforms
    4. Polish platform-specific UI details

- 2026-02-10 02:30: Feature Enhancement & UI Polish Session
  - **Objective:** Add new features and polish the app for a more enjoyable experience

  - **New Features Implemented:**

    1. **Tone Color Coding for Pinyin**
       - Updated `PinyinConverter.swift` with `Tone` enum and tone detection
       - Added `coloredPinyin()` method returning `AttributedString` with colored tones
       - Tone 1 (ā): Red, Tone 2 (á): Orange, Tone 3 (ǎ): Green, Tone 4 (à): Blue, Neutral: Gray
       - Added `showToneColors` preference in `UserPreferences.swift`
       - Updated `InteractiveChineseText.swift` to support tone colors
       - Added `ToneColorLegend` component to `SettingsView.swift` (macOS and iOS)
       - Toggle in Settings: "Color-code pinyin by tone"

    2. **Quick Phrase Collections**
       - Created `PhraseCollection.swift` with:
         - `Phrase` struct (id, chinese, pinyin, english, category)
         - `PhraseCategory` enum with 8 categories: Greetings, Food & Dining, Travel, Shopping, Numbers, Time & Dates, Directions, Emergency
         - ~100 phrases total across all categories
         - `PhraseCollectionStore` for favorites management (persists to UserDefaults)
       - Created `PhraseCollectionView.swift` (477 lines):
         - NavigationSplitView with category sidebar
         - Category grid view with animated cards
         - Category detail view with phrase list
         - Favorites view for starred phrases
         - PhraseRow with listen, copy, favorite actions
         - StatBadge component for quick stats
       - Added `.phrases` case to `SidebarItem.swift`
       - Added Phrases tab to both macOS and iOS navigation

    3. **Export Vocabulary Feature**
       - Added export methods to `SavedTermsStore`:
         - `exportToCSV()` - Standard CSV format
         - `exportToAnki()` - TSV format compatible with Anki import
         - `exportToMarkdown()` - Markdown table format
         - `exportToJSON()` - JSON array format
       - Added `ExportFormat` enum with all formats
       - Created `ExportVocabularySheet` in `SavedTermsView.swift`:
         - Format picker (CSV, Anki, Markdown, JSON)
         - Live preview of export content
         - Copy to clipboard button
         - Save to file button (macOS only via NSSavePanel)
       - Export button in SavedTermsView header bar

    4. **Study Statistics Dashboard**
       - Created `StatisticsView.swift` (442 lines):
         - Stats grid: Translations, Cards Reviewed, Vocabulary, Favorite Phrases
         - Streak section: Current streak, Best streak, Daily goal progress circle
         - Learning progress section: New/Learning/Mastered counts with progress bar
         - Activity section: 7-day activity view
         - Motivational streak messages
       - Added helper methods to `LearningProgressStore`:
         - `getMasteredCount()` - Count of mastered cards
         - `getLearningCount()` - Count of cards in progress
       - Updated `LearningStats` struct with `dueCount` property
       - Added `.statistics` case to `SidebarItem.swift`
       - Added Statistics tab to both macOS and iOS navigation

    5. **UI Polish with Animations & Haptic Feedback**
       - Created `AnimationHelpers.swift` with:
         - `AppAnimation` enum: standard, quick, slow, spring, gentleSpring, snappySpring
         - `HapticFeedback` enum: light, medium, heavy, success, error, warning, selection
         - `PressableButtonStyle` for scale-on-press effect
         - View modifiers: `bounceOnAppear()`, `slideInOnAppear()`, `fadeInOnAppear()`, `shimmer()`
         - Custom transitions: `slideAndFade`, `scaleAndFade`, `pop`
       - Updated `LearnView.swift`:
         - Added haptic feedback to rating buttons
         - Added bounce animations to empty/completion states
         - Pressable button style for interactive buttons
         - Success haptic on session complete
       - Updated `StatisticsView.swift`:
         - Staggered bounce animations on stat cards
       - Updated `PhraseCollectionView.swift`:
         - Staggered bounce animations on category cards
         - Haptic feedback on favorite, listen, copy actions
         - Animation constants for consistent timing

  - **Files Created:**
    - `Shared/Models/PhraseCollection.swift` - Phrase data model and store
    - `Shared/Views/PhraseCollectionView.swift` - Phrase browsing view
    - `Shared/Views/StatisticsView.swift` - Statistics dashboard
    - `Shared/Services/AnimationHelpers.swift` - Animation utilities

  - **Files Updated:**
    - `Shared/Services/PinyinConverter.swift` - Tone detection and colored pinyin
    - `Shared/Services/UserPreferences.swift` - Added showToneColors preference
    - `Shared/Views/InteractiveChineseText.swift` - Tone color support
    - `Shared/Views/SettingsView.swift` - Tone color legend and toggle
    - `Shared/Views/LearnView.swift` - Animations and haptic feedback
    - `Shared/Views/SavedTermsView.swift` - Export functionality
    - `Shared/Models/SavedTerm.swift` - Export methods
    - `Shared/Models/SidebarItem.swift` - Added phrases and statistics cases
    - `Shared/Models/LearningProgress.swift` - Added dueCount to LearningStats
    - `MandarinKit/ContentView.swift` - Updated for new sidebar items
    - `MandarinKit-Universal/ContentView.swift` - Updated for new sidebar items

  - **Current App Structure (6 main views):**
    - Translate - Translation with interactive Chinese text
    - Vocabulary - Saved terms with export
    - Phrases - Quick phrase collections by category
    - Learn - Flashcard learning with spaced repetition
    - History - Translation history
    - Statistics - Learning statistics dashboard

  - **Build Status:** ✅ Successful with 0 errors

  - **Quality Checklist:**
    - [x] Build succeeds with zero errors
    - [x] Tone colors display correctly in pinyin
    - [x] Phrase collections browsable by category
    - [x] Export vocabulary works for all formats
    - [x] Statistics dashboard shows accurate data
    - [x] Animations are smooth and consistent
    - [x] Haptic feedback on iOS interactions
    - [x] All new features accessible from sidebar/tabs

- 2026-02-10 03:30: Apple Intelligence / Foundation Models Integration
  - **Objective:** Integrate Apple's Foundation Models framework for seamless AI-powered learning features

  - **Research Conducted:**
    - FoundationModels framework (SystemLanguageModel, LanguageModelSession)
    - `@Generable` macro for structured output generation
    - `@Guide` macro for property constraints
    - Writing Tools API (.writingToolsBehavior)
    - Multilingual support (Chinese language supported)

  - **Files Created:**
    - `Shared/Services/AIService.swift` - Central AI service using Foundation Models
      - `AIService` class with availability checking
      - `@Generable` types: GeneratedSentence, LearningHint, GrammarExplanation
      - Methods: generateExampleSentence, getLearningHint, explainGrammar, getTranslationTip, suggestRelatedVocabulary
      - Platform-independent result types
      - Proper error handling with AIError enum

    - `Shared/Views/AIEnhancedTermDetail.swift` - AI-powered vocabulary detail view
      - Example sentence generation with difficulty levels
      - Learning hints (mnemonic, usage context, pronunciation tips)
      - Related vocabulary suggestions with add-to-vocabulary action
      - Visual cards for AI-generated content

  - **Files Updated:**
    - `Shared/Views/SavedTermsView.swift`
      - Added tap handler to open AI-enhanced detail sheet
      - Both list and grid views now open AIEnhancedTermDetail on tap

    - `Shared/Views/LearnView.swift`
      - Added "Need a hint?" button during flashcard review
      - AI-powered learning hints sheet with mnemonic, usage, pronunciation tips
      - LearningHintSheet component for displaying hints
      - HintRow component for styled hint display

    - `Shared/Views/PhraseCollectionView.swift`
      - Added grammar explanation button to phrase rows
      - GrammarExplanationSheet showing pattern, explanation, additional examples
      - AI-generated grammar breakdowns for any phrase

    - `Shared/Views/TranslateView.swift`
      - Enabled Writing Tools on text input (.writingToolsBehavior(.complete))
      - Added AI Tip button after translation
      - Contextual tips about pronunciation, tone, cultural context
      - Tip popover with sparkles icon

  - **AI Features Implemented:**
    1. **Example Sentence Generation** (Vocabulary)
       - Generates natural Chinese sentences using saved vocabulary
       - Includes pinyin, English translation, difficulty rating
       - Multiple sentences at different difficulty levels

    2. **Smart Learning Hints** (Flashcards)
       - Memory tricks/mnemonics for vocabulary
       - Usage context explanations
       - Pronunciation and tone tips
       - Appears during flashcard review when user needs help

    3. **Grammar Explanations** (Phrases)
       - Identifies grammatical patterns in phrases
       - Provides clear explanations
       - Shows additional example sentences using same pattern

    4. **Translation Tips** (Translate)
       - Quick contextual tips after translation
       - Pronunciation, cultural context, or usage notes
       - Non-intrusive popover display

    5. **Related Vocabulary Suggestions** (Vocabulary Detail)
       - Suggests thematically related words
       - One-tap add to vocabulary list
       - Listen and copy actions

    6. **Writing Tools Support** (Translate Input)
       - Full Apple Writing Tools integration
       - Proofreading and rewriting support

  - **Technical Implementation:**
    - Uses `@Generable` macro for structured output (GeneratedSentence, LearningHint, GrammarExplanation)
    - `@Guide` macro for property descriptions to guide generation
    - `respond(to:generating:)` method for typed responses
    - Graceful fallback when Foundation Models unavailable
    - All AI features conditionally compiled with `#if canImport(FoundationModels)`

  - **Build Status:** ✅ Successful with 0 errors

  - **Quality Checklist:**
    - [x] Build succeeds with zero errors
    - [x] AIService properly checks Foundation Models availability
    - [x] Vocabulary detail view shows AI features when available
    - [x] Learning hints appear in flashcard review
    - [x] Grammar explanations work for phrases
    - [x] Translation tips display correctly
    - [x] Writing Tools enabled on translation input
    - [x] Graceful degradation when AI unavailable

- 2026-02-10 04:00: Fixed AppIcon Asset Catalog Error
  - **Issue:** Build failing with "The stickers icon set, app icon set, or icon stack named 'AppIcon' did not have any applicable content."

  - **Root Cause Analysis:**
    - The **MandarinKit** target (not MandarinKit-Universal) has its own Assets.xcassets
    - The MandarinKit/Assets.xcassets/AppIcon.appiconset only contained macOS icons (idiom: mac)
    - The build was targeting iOS (`--platform iphoneos`), which requires iOS icons
    - The asset compiler found no applicable content for iOS platform
    - There's also an Icon Composer file (`mandarinkit.icon`) but the asset catalog was still being processed

  - **Solution:**
    - Added iOS single-source 1024x1024 icons to MandarinKit/Assets.xcassets/AppIcon.appiconset
    - Copied `icon-1024 1.png`, `icon-1024 2.png`, `icon-1024 3.png`, `icon-1024 4.png` from Universal target
    - Updated Contents.json with iOS entries (idiom: universal, platform: ios, size: 1024x1024)
    - Including dark and tinted appearance variants

  - **Files Modified:**
    - `MandarinKit/Assets.xcassets/AppIcon.appiconset/Contents.json` - Added iOS icon entries
    - Copied 4 icon files: icon-1024 1.png, icon-1024 2.png, icon-1024 3.png, icon-1024 4.png

  - **Build Status:** ✅ Successful with 0 errors

  - **Note:** The MandarinKit-Universal target also has its own Assets.xcassets with a similar configuration.
    Both targets now have properly configured app icons for iOS and macOS platforms.

```
</file_contents>
