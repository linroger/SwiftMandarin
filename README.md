<p align="center">
  <img src="SwiftMandarin/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" width="128" height="128" alt="SwiftMandarin App Icon" />
</p>

<h1 align="center">SwiftMandarin</h1>

<p align="center">
  <strong>Your Complete Mandarin Chinese Learning Companion</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#how-to-use">How to Use</a> •
  <a href="#privacy">Privacy</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%20|%20iPadOS%20|%20macOS-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.2-orange" alt="Swift" />
  <img src="https://img.shields.io/badge/SwiftUI-Liquid%20Glass-purple" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## Overview

**SwiftMandarin** is a beautifully designed, native Apple app that combines powerful translation, intelligent vocabulary building, and effective flashcard-based learning into one seamless experience. Built entirely with SwiftUI and Apple's Translation framework, it delivers a premium Mandarin Chinese learning experience across iPhone, iPad, and Mac.

Whether you're a beginner taking your first steps into Mandarin or an advanced learner looking to expand your vocabulary, SwiftMandarin provides all the tools you need to learn Chinese effectively and enjoyably.

### Why SwiftMandarin?

- **Native Apple Experience**: Built from the ground up with SwiftUI and Apple's Liquid Glass design language
- **Privacy-First**: Core features run entirely on-device—no accounts, no tracking, no required network
- **Intelligent Learning**: Spaced repetition algorithm adapts to your learning pace
- **Optional AI Power**: Bring your own provider—Apple Intelligence (on-device), a local Ollama server, or a cloud model—for word explanations, photo cleanup, and workbook grading
- **Camera & Photo OCR**: Scan textbooks, signs, and worksheets, then translate and study the text
- **Beautiful Visualizations**: GitHub-style activity heatmaps and interactive charts track your progress
- **Cross-Platform**: Seamless experience across iPhone, iPad, and Mac with platform-optimized interfaces
- **Switchable Bilingual Interface**: The entire app runs in English or Simplified Chinese (简体中文)—flip it anytime from Settings

---

## Features

### 🔤 Intelligent Translation

<img align="right" src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.24.47@2x.png" width="400" alt="Translation View" />

- **Bidirectional Translation**: Seamlessly translate between English and Chinese using Apple's on-device Translation framework
- **Interactive Word Analysis**: Tap any Chinese word to see:
  - Pinyin pronunciation with tone marks
  - Part of speech classification
  - Individual word translation
  - Quick save, copy, and speak actions
- **Tone-Colored Pinyin**: Visual tone indicators help you master pronunciation:
  - 🔴 First tone (high level)
  - 🟢 Second tone (rising)
  - 🔵 Third tone (dipping)
  - 🟣 Fourth tone (falling)
  - ⚫ Neutral tone
- **Ruby Text Display**: Pinyin displayed elegantly above Chinese characters
- **Auto-Translate Options**: Translate automatically as you type or on paste
- **Text-to-Speech**: Native Chinese pronunciation using Apple's speech synthesis

<br clear="right"/>

### 📷 Photo, Camera & Screenshot Translation

- **Photo Translate**: Pick a photo of a textbook, menu, or sign and SwiftMandarin recognizes and translates the text
- **Live Camera Scanner**: Point your camera at text for real-time on-device recognition (iOS)
- **Language-Aware OCR**: Choose Auto, 中文, English, or Both so Chinese characters are never mangled into Latin gibberish
- **Screenshot Stitching**: Combine multiple screenshots of a long page—overlapping regions are removed automatically—then translate the whole thing
- **AI Photo Cleanup (Optional)**: Route scanned text through your chosen AI provider to fix OCR errors before translation
- **Extract Key Vocabulary**: Pull the most useful words out of any scanned passage and save them with one tap

### 🎙️ Voice Translation

- **Live Speech Translation**: Speak and see your words transcribed and translated in real time
- **Tap-to-Study**: Tap any word in the transcript to open its details and save it
- **Dual-Language Narration**: Hear both the word and its translation read aloud

### 🤖 AI-Powered Features (Optional, Bring Your Own Provider)

- **Ten Providers, Your Choice**: Apple Intelligence (on-device), a local **Ollama** server, or a cloud model—**OpenAI, Claude, DeepSeek, Doubao, Qwen, Kimi, Zhipu, MiniMax**
- **Rich Word Explanations**: Generate detailed cards with nuances, grammar usage, example sentences, synonyms, and collocations
- **Live Model Lists**: Enter your API key and fetch the provider's available models directly from its API
- **Secure Key Storage**: API keys are stored in the system **Keychain**, never in plain files or the cloud
- **Learner Mode**: Tell the app whether you're an English speaker learning Mandarin, a Mandarin speaker learning English, or both—defaults adapt accordingly
- **Entirely Optional**: Leave AI off and every core feature still works fully on-device

### ✅ AI Workbook Grading

<img align="right" src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-06-07%20at%2023.28.11@2x.png" width="400" alt="Workbook Grading Results" />

- **Photo-Based Grading**: Upload photos of a workbook (and answers, if on a separate sheet) and a vision-capable AI grades every question
- **Per-Question Feedback**: See a ✓/✗ verdict, the correct answer, and a short explanation for each item
- **Read the Full Sentence Aloud**: Every question shows the complete English sentence with a 🔊 button for pronunciation practice
- **Mistake-Aware Vocabulary**: Save wrong-answer words straight to your vocabulary list—each saved entry keeps **both** the correct answer and the answer you wrote (✓ correct · ✗ yours)
- **Custom Instructions**: Add grading notes (e.g. "Grade 3 English vocabulary; be strict about spelling")
- **Flexible Input**: Add pages from Photos, the Files app/Finder, or drag-and-drop

<br clear="right"/>

### 📚 Vocabulary Management

- **Smart Saving**: Save words from translations, phrases, or word details with one tap
- **Flexible Organization**: Sort vocabulary by date added, alphabetical order, or pinyin
- **Powerful Search**: Find words by Chinese characters, pinyin, or English definition
- **Rich Word Details**: View complete information for each saved term:
  - Chinese characters
  - Pinyin with tones
  - English definition
  - Part of speech
  - Date saved
- **Export Options**: Share your vocabulary as CSV, JSON, or plain text for backup or use in other apps

### 🧠 Spaced Repetition Learning

<img align="right" src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.50@2x.png" width="400" alt="Learn View" />

- **Adaptive Algorithm**: SM-2 based spaced repetition schedules reviews at optimal intervals
- **Multiple Card Sources**:
  - Built-in deck with common vocabulary
  - Your saved vocabulary
  - Combined deck for comprehensive review
- **Study Modes**:
  - All Cards: Review everything
  - Due for Review: Focus on cards scheduled for today
  - New Cards: Learn vocabulary you haven't seen
  - Difficult: Practice challenging words
- **Mastery Tracking**: Five mastery levels from New to Mastered
- **Keyboard Navigation** (macOS/iPad): Use arrow keys to navigate and spacebar to flip cards

<br clear="right"/>

### 📊 Progress Analytics

<img align="right" src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.25.06@2x.png" width="400" alt="Statistics View" />

- **GitHub-Style Activity Heatmap**: Visualize your daily learning activity over the past year
- **Interactive Donut Charts**:
  - Mastery Progress: See distribution across learning stages
  - Vocabulary by Type: Breakdown by part of speech (nouns, verbs, adjectives, etc.)
  - Tap segments to highlight and see detailed counts
- **Stacked Bar Charts**: Track words learned daily by part of speech
- **Key Metrics Dashboard**:
  - Current and best learning streaks
  - Total words saved
  - Cards studied
  - Reviews completed
  - Daily averages
- **Platform-Adaptive Design**: Optimized layouts for iPhone (6 months), iPad, and Mac (full year)

<br clear="right"/>

### 💬 Common Phrases

- **Practical Categories**: Essential phrases organized by situation:
  - Greetings & Social
  - Basic Expressions
  - Travel & Transportation
  - Dining & Food
  - Shopping & Bargaining
  - Directions & Navigation
  - Emergency & Help
  - Time & Numbers
- **Full Phrase Details**: See Chinese, pinyin, and English for each phrase
- **Quick Actions**: Speak, copy, or save any phrase instantly
- **Search Functionality**: Find phrases by Chinese, pinyin, or English

### 🕐 Translation History

- **Complete Record**: All translations saved automatically (optional)
- **Smart Grouping**: Organized by Today, Yesterday, This Week, and Earlier
- **Quick Restore**: Tap any history item to restore it to the translator
- **Powerful Actions**:
  - Restore translation
  - Reverse translate direction
  - Duplicate entry
  - Copy to clipboard
  - Delete individual items or clear all

### ⚙️ Customizable Settings

- **Language & Learning**:
  - App language toggle (English / 中文)
  - Learner mode (English→中, 中→English, or bilingual)
  - Dual-language narration
- **AI Provider**:
  - Pick a provider, enter an API key, fetch live model lists, and test the connection
  - Toggle AI photo cleanup
- **Translation Preferences**:
  - Auto-translate toggle
  - Translate on paste
  - Default translation direction
  - Photo scan language (Auto / 中文 / English / Both)
- **Output Options**:
  - Auto-copy to clipboard
  - History saving toggle
- **Display Settings**:
  - Show/hide pinyin
  - Tone color coding
  - Text size adjustment
- **Data Management**:
  - Import / export vocabulary (CSV, JSON, TXT)
  - Clear vocabulary
  - Clear history
  - Reset learning progress

### 🌐 Localization

- **Full Bilingual Support**: The complete interface—every tab, screen, sheet, and alert—is available in English and Simplified Chinese (简体中文)
- **In-App Language Toggle**: Switch the whole app between the English and Mandarin versions anytime from **Settings → Language**, independent of your device language and with no relaunch
- **Smart Default**: On first launch the app follows your device's language preference
- **Native Terminology**: Translations were reviewed for accuracy, consistency, and natural phrasing (formal 您, consistent vocabulary, preserved formatting)

---

## Screenshots

### macOS

Experience SwiftMandarin's full power on your Mac with a spacious sidebar navigation and comprehensive data visualizations.

<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.24.47@2x.png" width="45%" alt="macOS - Translate View" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.25.06@2x.png" width="45%" alt="macOS - Statistics View" />
</p>
<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.25.12@2x.png" width="45%" alt="macOS - Learn View" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.56@2x.png" width="45%" alt="macOS - Phrases View" />
</p>
<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-06-07%20at%2023.28.05@2x.png" width="45%" alt="macOS - AI Workbook Grading (upload)" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-06-07%20at%2023.28.11@2x.png" width="45%" alt="macOS - AI Workbook Grading (results with read-aloud)" />
</p>

### iPhone

A mobile-optimized experience with compact layouts and intuitive tab navigation.

<p align="center">
  <img src="Screenshots/iOS%20Screenshots/IMG_9055.PNG" width="24%" alt="iPhone - Translate" />
  <img src="Screenshots/iOS%20Screenshots/IMG_9056.PNG" width="24%" alt="iPhone - Statistics" />
  <img src="Screenshots/iOS%20Screenshots/IMG_9057.PNG" width="24%" alt="iPhone - Learn" />
  <img src="Screenshots/iOS%20Screenshots/IMG_8532.PNG" width="24%" alt="iPhone - Vocabulary" />
</p>

### iPad

The best of both worlds—spacious layouts with adaptive sidebar navigation.

<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0588.PNG" width="45%" alt="iPad - Translate" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0589.PNG" width="45%" alt="iPad - Vocabulary" />
</p>
<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0590.PNG" width="45%" alt="iPad - Learn" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0591.PNG" width="45%" alt="iPad - Phrases" />
</p>

---

## Installation

### App Store (Recommended)

Download SwiftMandarin from the [App Store](https://apps.apple.com/app/swiftmandarin) for iPhone, iPad, and Mac.

### macOS DMG Installer

1. Download the latest DMG from [Releases](https://github.com/linroger/SwiftMandarin/releases)
2. Open `SwiftMandarin-2.0-macOS.dmg`
3. Drag `SwiftMandarin.app` to your Applications folder
4. Launch SwiftMandarin from Applications

> **Note**: If macOS Gatekeeper shows a warning, right-click the app, select **Open**, then confirm.

### Build from Source

**Requirements:**
- Xcode 26+
- Swift 6.2+
- iOS 26.2+ / macOS 26.2+

```bash
# Clone the repository
git clone https://github.com/linroger/SwiftMandarin.git
cd SwiftMandarin

# Open in Xcode
open SwiftMandarin.xcodeproj
```

In Xcode:
1. Select the `SwiftMandarin` scheme
2. Choose your target device (iPhone, iPad, or My Mac)
3. Press ⌘R to build and run

**CLI Build:**
```bash
xcodebuild -project SwiftMandarin.xcodeproj -scheme SwiftMandarin -configuration Release -destination 'platform=macOS' build
```

---

## How to Use

### Getting Started

1. **Launch SwiftMandarin** on your iPhone, iPad, or Mac
2. **Enter text** in the source panel on the Translate tab
3. **Tap Translate** or enable auto-translate for instant results
4. **Tap any Chinese word** to see pinyin, definition, and save options

### Building Your Vocabulary

1. While translating, tap any Chinese word to open details
2. Tap **Save** to add it to your vocabulary
3. Access saved words anytime in the **Vocabulary** tab
4. Use search and sort to find specific words quickly

### Learning with Flashcards

1. Go to the **Learn** tab
2. Choose your card source (Built-in, Vocabulary, or All)
3. Select a study mode based on your goals
4. Tap cards to flip, then rate your recall
5. The algorithm will schedule optimal review times

### Tracking Progress

1. Visit the **Stats** tab to see your learning analytics
2. Check your current streak and aim to maintain it
3. Review the activity heatmap to identify patterns
4. Tap chart segments for detailed breakdowns

### Using Phrases

1. Open the **Phrases** tab
2. Browse categories or search for specific phrases
3. Tap any phrase to hear pronunciation
4. Save useful phrases to your vocabulary for later study

### Scanning Photos & Workbooks

1. Open the **Photo** tab and add an image (Photos, Files/Finder, drag-and-drop, or the live camera scanner)
2. Pick the scan language if needed, then read and translate the recognized text
3. For grading, open the **Workbook Grading** tool from the Photo tab's toolbar
4. Add the workbook pages (and a separate answer sheet only if needed), optionally add custom instructions, then tap **Grade**
5. Review each question, tap 🔊 to hear the full English sentence, and save wrong-answer words to your vocabulary

> Photo translation and on-device OCR work without AI. AI photo cleanup and workbook grading require an AI provider configured in **Settings → AI**.

### Switching the App Language

1. Open **Settings** (the More tab on iOS, or ⌘, on Mac) and find **Language**
2. Choose **English** or **中文**—the entire interface switches immediately

---

## Technical Details

### Architecture

- **SwiftUI**: 100% SwiftUI with Liquid Glass design system, across iOS / iPadOS / macOS / visionOS
- **Translation**: Apple Translation framework (on-device, privacy-preserving)
- **AI (optional)**: A 10-provider abstraction—Apple Foundation Models, Ollama, and OpenAI-compatible / Anthropic cloud APIs via `URLSession`—for explanations, photo cleanup, and grading
- **OCR**: Vision framework with language-aware recognition (`PhotoTextRecognitionService`)
- **Speech**: AVFoundation for text-to-speech; Speech framework for live transcription
- **NLP**: NaturalLanguage framework for Chinese segmentation and lexical analysis
- **Localization**: String Catalog (`Localizable.xcstrings`) + a `LocalizationManager` that swaps the active `.lproj` bundle for the in-app language toggle
- **Storage**: UserDefaults + Codable locally; API keys in the system Keychain
- **App Intents / Shortcuts**: Translate, look up vocabulary, start a review, scan, and more from Siri & Shortcuts

### File Structure

```
SwiftMandarin/
├── Views/
│   ├── TranslateView.swift          # Main translation interface
│   ├── PhotoTranslateView.swift     # Photo / OCR translation
│   ├── WorkbookGradingView.swift    # AI workbook grading
│   ├── HistoryTabView.swift         # Translation history
│   ├── VocabularyView.swift         # Saved words management
│   ├── LearnView.swift              # Flashcard learning
│   ├── PhrasesView.swift            # Common phrases
│   ├── StatsView.swift              # Analytics dashboard
│   ├── MacOSSettingsView.swift      # Settings (macOS)
│   ├── MoreView.swift               # Settings hub (iOS)
│   └── Components/                  # Camera scanner, live speech, AI cards, etc.
├── Models/
│   ├── SavedTerm.swift              # Vocabulary model
│   ├── AIModelSettings.swift        # AI providers & per-provider config
│   ├── AppPreferences.swift         # Learner mode, scan language, narration
│   ├── LocalizationManager.swift    # In-app language switch
│   ├── LearningCard.swift           # Flashcard model
│   └── TranslationHistory.swift     # History model
├── Services/
│   ├── CloudAIService.swift         # Cloud AI (OpenAI-compatible + Anthropic)
│   ├── AIWordExplanationService.swift # Explanations, vocab extraction, grading
│   ├── PhotoTextRecognitionService.swift # Vision OCR
│   ├── KeychainHelper.swift         # Secure API-key storage
│   ├── PinyinConverter.swift        # Pinyin conversion
│   ├── SpeechService.swift          # Text-to-speech
│   ├── ChineseTextAnalyzer.swift    # NLP analysis
│   └── ClipboardService.swift       # Clipboard handling
├── Intents/                         # App Intents / Siri Shortcuts
└── Localizable.xcstrings            # English + Simplified Chinese strings
```

---

## Privacy

SwiftMandarin is designed with privacy as a core principle:

- **No Account Required**: Use all features without signing up
- **Local Storage Only**: All your data (vocabulary, history, progress) is stored locally on your device
- **On-Device Translation**: Apple Translation framework processes text on-device
- **No Tracking**: No analytics, no telemetry, no third-party tracking SDKs
- **Offline Core**: Translation, vocabulary, flashcards, phrases, stats, and on-device OCR work fully offline (after downloading language packs)
- **AI Is Opt-In**: Cloud AI features are disabled until *you* choose a provider and add a key. Apple Intelligence and Ollama run locally; cloud providers receive only the text or image you submit, and your API keys are stored in the Keychain—never transmitted anywhere except to the provider you configured.

Your learning journey is yours alone.

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 26.2+          |
| iPadOS   | 26.2+          |
| macOS    | 26.2+          |

**Language Packs**: For translation to work, download the English-Chinese language pack in System Settings > General > Language & Region > Translation Languages.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/linroger/SwiftMandarin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/linroger/SwiftMandarin/discussions)

---

## License

SwiftMandarin is available under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Apple Translation, Vision, Speech, and NaturalLanguage frameworks
- Apple Foundation Models for on-device AI
- [ollama-swift](https://github.com/mattt/ollama-swift) for local model access
- Optional, user-configured AI providers (OpenAI, Anthropic, DeepSeek, Doubao, Qwen, Kimi, Zhipu, MiniMax)
- The SwiftUI team for Liquid Glass and modern UI components
- The open-source community for inspiration and best practices

---

<p align="center">
  <strong>Learn Mandarin. The Apple Way.</strong>
</p>

<p align="center">
  Made with ❤️ using SwiftUI
</p>
