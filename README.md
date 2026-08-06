<p align="center">
  <img src="SwiftMandarin/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" width="128" height="128" alt="SwiftMandarin App Icon" />
</p>

<h1 align="center">SwiftMandarin</h1>

<p align="center">
  <strong>Your Complete English ⇄ Chinese Learning Companion</strong>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-Hans.md">简体中文</a>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#how-to-use">How to Use</a> •
  <a href="#privacy">Privacy</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20iPadOS%2017%2B%20|%20macOS-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/Swift-6.2-orange" alt="Swift" />
  <img src="https://img.shields.io/badge/SwiftUI-Liquid%20Glass-purple" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

---

## Overview

**SwiftMandarin** is a beautifully designed, native Apple app that combines powerful translation, intelligent vocabulary building, and effective flashcard-based learning into one seamless experience. Built entirely with SwiftUI and Apple's Translation framework, it delivers a premium language-learning experience across iPhone, iPad, and Mac.

It works in **both directions**. An English speaker studying Mandarin and a Mandarin speaker studying English get the same features with the two languages swapped — not a translated menu bar over a one-way app. Pick which one you are in Settings and the whole app re-orients: the word you are studying takes the headline, explanations arrive in the language you already read, and the pronunciation guide switches between pinyin and IPA.

### Why SwiftMandarin?

- **Native Apple Experience**: Built from the ground up with SwiftUI and Apple's Liquid Glass design language
- **Privacy-First**: Core features run entirely on-device—no accounts, no tracking, no required network
- **Intelligent Learning**: Spaced repetition algorithm adapts to your learning pace
- **Optional AI Power**: Bring your own provider—Apple Intelligence (on-device), a local Ollama server, or a cloud model—for word explanations, photo cleanup, and workbook grading
- **Camera & Photo OCR**: Scan textbooks, signs, and worksheets, then translate and study the text
- **Beautiful Visualizations**: GitHub-style activity heatmaps and interactive charts track your progress
- **Cross-Platform**: Seamless experience across iPhone, iPad, and Mac with platform-optimized interfaces
- **Two Learning Directions, Fully Mirrored**: English→中文 and 中文→English are the same app reflected, down to the pronunciation system and which word gets the big font
- **Switchable Bilingual Interface**: The entire app runs in English or Simplified Chinese (简体中文)—flip it anytime from Settings

---

## Features

### 🏠 Home — Your Daily Front Door

- **Open with purpose**: a Home tab greets you with your streak, a daily-goal ring, and exactly what to do next
- **Review Now**: one tap starts a smart session — genuinely due cards plus new cards within your daily budget
- **Word of the Day**: a deterministic daily pick from your own vocabulary, with tone-colored pinyin and one-tap narration
- **Continue Reading**: jump straight back into the last text you were reading
- **First-run welcome**: three screens configure your learning direction, daily goal, and optional AI

### 🗂️ Modern Spaced Repetition (FSRS)

- **FSRS-4.5 scheduler**: the modern successor to SM-2 — per-card stability & difficulty, a real forgetting curve, and honest intervals
- **Interval previews**: every grade button (Again / Hard / Good / Easy) shows exactly when you'll see the card next
- **In-session relearn queue**: missed cards return within the same session until you get them right
- **Daily new-card budget** and a 7-day review forecast after every session
- **Seamless migration**: existing SM-2 progress converts automatically

### 📖 Immersive Reader & AI Story Studio

- **Read anything**: paste, write, or import text into your reading library
- **Tap-to-define**: every word in the current paragraph is interactive with pinyin ruby text
- **AI graded stories**: generate stories at your level that reuse the words you've already saved
- **Per-paragraph translation & read-aloud**, reading progress, and a "~% known" vocabulary-coverage estimate

### 💬 AI Conversation Partner

- **Roleplay real scenes**: café, directions, shopping, introductions, travel, the doctor's office, or free chat
- **Speak or type**: built-in voice input; replies come in the language you're learning
- **Gentle corrections**: the partner flags mistakes in your native language
- **Pinyin & translation reveal** on every message, with one-tap narration

### 🎯 Practice Hub

- **Quiz**: multiple choice from your vocabulary with smart same-part-of-speech distractors
- **Dictation**: listen, type what you hear, and see a character-level diff
- **Tone drills**: train your ear with two-syllable tone-pattern rounds and a personal confusion insight

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
- **Text-to-Speech**: Use Apple's system voices, or opt into MiniMax AI Audio for persistent, reusable Mandarin and English MP3 speech

<br clear="right"/>

### 🧩 Multimodal Translation

- **Photo Translate**: Pick a photo of a textbook, menu, or sign and SwiftMandarin recognizes and translates the text
- **Live Camera Scanner**: Point your camera at text for real-time on-device recognition (iOS)
- **Language-Aware OCR**: Choose Auto, 中文, English, or Both so Chinese characters are never mangled into Latin gibberish
- **Screenshot Stitching**: Combine multiple screenshots of a long page—overlapping regions are removed automatically—then translate the whole thing
- **AI Photo Cleanup (Optional)**: Route scanned text through your chosen AI provider to fix OCR errors before translation
- **Cleanup Transparency**: When AI cleanup runs you see a badge and can flip back to the original OCR text with one tap; if cleanup can't run, the app tells you instead of failing silently
- **Extract Key Vocabulary**: Pull the most useful words out of any scanned passage and save them with one tap
- **Counts Toward Your Stats**: Photo translations are saved to History and your daily activity, just like typed ones
- **Recorded or Imported Audio**: Record speech or choose an audio file up to 60 seconds, preview it locally, and transcribe it into the same editable source-text workspace
- **Transcribe and Translate**: Run transcription and the existing translation flow in one action while still exposing the transcript for correction
- **Two Transcription Engines**: Apple Speech downloads and uses the on-device model for your chosen language (with visible download progress on first use), or send the clip to the AI provider **you selected**—the pane names the destination in words before anything is uploaded

### 🎙️ Voice Translation

- **Live Speech Translation**: Speak and see your words transcribed and translated in real time
- **Tap-to-Study**: Tap any word in the transcript to open its details and save it
- **Dual-Language Narration**: Hear both the word and its translation read aloud
- **Use Both Sides**: Accepting a spoken translation fills in both the transcript and the result on the Translate tab, and records it to History

### 🤖 AI-Powered Features (Optional, Bring Your Own Provider)

- **Ten Providers, Your Choice**: Apple Intelligence (on-device), a local **Ollama** server, or a cloud model—**OpenAI, Claude, DeepSeek, Doubao, Qwen, Kimi, Zhipu, MiniMax**
- **Rich Word Explanations**: Generate detailed cards with nuances, grammar usage, example sentences, synonyms, and collocations
- **Live Model Lists**: Enter your API key and fetch the provider's available models directly from its API
- **Test Connection & Capability Badges**: One tap verifies your key, endpoint, and model round-trip; badges show whether the provider supports vision (images) and strict JSON mode
- **Secure Key Storage**: API keys are stored in the system **Keychain**, never in plain files or the cloud
- **Optional MiniMax AI Audio**: Refresh your account's live Mandarin/English voice catalog, choose the latest Speech 2.8 model or an older compatible 2.6/02/01 model, route every read-aloud action through MiniMax TTS, persist the generated MP3, replay it without another paid request, and share or export it
- **Batch AI Analysis & Audio**: Analyze missing saved words and optionally pre-generate deduplicated, persistent Mandarin and English MiniMax clips after an exact paid-request/character preflight
- **Auto-Translate New Words**: Opt in and every word you save—from Translate, a photo, the reader, Shortcuts, or an import—is translated and analyzed in the background by your selected provider, so opening it later shows a finished analysis. The queue is deduplicated, capped, resumed after a relaunch, yields to a manual batch run, pauses itself after repeated failures, and never generates paid audio
- **Learner Mode**: Tell the app whether you're an English speaker learning Mandarin, a Mandarin speaker learning English, or both—defaults adapt accordingly
- **Entirely Optional**: Leave AI off and every core feature still works fully on-device

### ✅ AI Workbook Grading

<img align="right" src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-06-07%20at%2023.28.11@2x.png" width="400" alt="Workbook Grading Results" />

- **Photo-Based Grading**: Upload photos of a workbook (and answers, if on a separate sheet) and a vision-capable AI grades every question
- **Per-Question Feedback**: See a ✓/✗ verdict, the correct answer, and a short explanation for each item
- **Honest Errors**: If the model can't read any questions (blank pages, wrong model), you get a clear bilingual error with advice—never a silent "0/0"
- **Read the Full Sentence Aloud**: Every question shows the complete English sentence with a 🔊 button for pronunciation practice
- **Mistake-Aware Vocabulary**: Save wrong-answer words straight to your vocabulary list—each saved entry keeps **both** the correct answer and the answer you wrote (✓ correct · ✗ yours)
- **Custom Instructions**: Add grading notes (e.g. "Grade 3 English vocabulary; be strict about spelling")
- **Flexible Input**: Add pages from Photos, the Files app/Finder, or drag-and-drop

<br clear="right"/>

### 📚 Vocabulary Management

- **Smart Saving**: Save words from translations, phrases, or word details with one tap
- **Flexible Organization**: Sort vocabulary by date added, alphabetical order, or pinyin
- **Powerful Search**: Find words by Chinese characters, pinyin, or English definition
- **Continuous Browsing**: On iPhone and iPad, swipe through adjacent word details—or use Previous/Next controls—without returning to the list; navigation follows the current search and sort order
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

- **Complete Record**: Translations from typing, photos, live speech, and Shortcuts are all saved automatically (optional)
- **Search & Filter**: Full-text search plus a direction filter (EN → 中 / 中 → EN)
- **Quick Restore**: Tap any history item to restore it to the translator
- **Powerful Actions**:
  - Restore translation
  - Reverse translate direction
  - Duplicate entry
  - Copy to clipboard
  - Delete individual items, or clear all (with confirmation)

### ⚙️ Customizable Settings

- **Language & Learning**:
  - Learner mode (English→中, 中→English, or bilingual) — re-orients the whole app, including the interface language
  - App language toggle (English / 中文), kept in sync with the learner mode
  - Dual-language narration (studied language first, native gloss second)
  - Pinyin display options (position, tone colors) appear only for a Mandarin learner — a native Mandarin reader has nothing to configure there
- **AI Provider**:
  - Pick a provider, enter an API key, fetch live model lists, and test the connection end-to-end
  - See at a glance whether the provider supports vision (images) and JSON mode
  - Toggle AI photo cleanup
- **AI Audio**:
  - Enable or disable MiniMax speech globally without changing individual Speak buttons
  - Choose API region and either the latest Speech 2.8 model or an older compatible model; refresh friendly Mandarin and English voice names live from the selected MiniMax account while retaining the last public catalog offline
  - Preview each language through MiniMax itself—without a misleading system-voice fallback—and manage, replay, share, export, or delete saved MP3 files
  - In Batch AI Analysis & Audio, choose the learning language or both languages, review exact new-request and character counts, then generate cache-first audio without automatic playback
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
  - Pinyin position: above, below, or inline with the characters
  - Tone color coding
  - Text size adjustment
- **Data Management**:
  - Import / export vocabulary (CSV, JSON, TXT)
  - Clear vocabulary
  - Clear history
  - Reset learning progress

### 🔄 Two Learning Directions

Choose **Settings → I am a…** and the app re-orients around you. The interface language *is* your native language, so the two settings stay in sync — picking 中文母语者学英语 switches the interface to 中文 and the study material to English in one gesture.

|                          | English speaker learning 中文 | Mandarin speaker learning English |
| ------------------------ | ----------------------------- | --------------------------------- |
| Interface                 | English                       | 简体中文                           |
| Vocabulary headline       | 中文 word, large              | English word, large               |
| Secondary line            | English gloss, small          | 中文 gloss, small                  |
| Pronunciation guide       | Pinyin with tone colors       | IPA with primary stress (`/kəˈmɪt/`) |
| AI explanations written in | English                       | 简体中文                           |
| Tappable word-by-word text | Chinese, pinyin above         | English word chips                |
| Read aloud                 | Mandarin leads                | English leads                     |
| Tone drills                | Available                     | Hidden (nothing to train)         |

Nothing is a stripped-down version of the other: the reverse direction gets the same depth of word-building explanation, the same worked examples, and the same read-aloud coverage — with the pronunciation system, fonts, and prompt language swapped to match.

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
2. Open `SwiftMandarin-4.2.0-macOS.dmg`
3. Drag `SwiftMandarin.app` to your Applications folder
4. Launch SwiftMandarin from Applications

> **Note**: If macOS Gatekeeper shows a warning, right-click the app, select **Open**, then confirm.

### Build from Source

**Requirements:**
- Xcode 26+
- Swift 6.2+
- iOS 17.0+ / macOS 26.2+ (deployment targets)

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

### Using the Multimodal Workspace

1. Open the **Multimodal** tab and choose **Image** or **Audio**
2. For an image, add it from Photos, Files/Finder, drag-and-drop, or the live camera scanner; then choose the scan language and translate the recognized text
3. For audio, record or import a supported clip up to 60 seconds, choose the spoken language, then use **Transcribe to Editor** or **Translate Audio**
4. Review or correct the transcript in the existing editor; direct audio translation also runs the normal translation flow after filling that editor
5. For grading, open **Workbook Grading** from the Multimodal toolbar, add workbook pages and optional instructions, then tap **Grade**

> Image OCR works without AI. Audio transcription uses Apple's Speech framework and may use Apple services when on-device recognition is unavailable. Translation, AI photo cleanup, and workbook grading use the translation/provider configuration described in Settings.

### Switching the App Language

1. Open **Settings** (the More tab on iOS, or ⌘, on Mac) and find **Language**
2. Choose **English** or **中文**—the entire interface switches immediately

---

## Technical Details

### Architecture

- **SwiftUI**: 100% SwiftUI with the Liquid Glass design system on OS 26+ (graceful material fallbacks down to iOS 17), across iOS / iPadOS / macOS / visionOS
- **Translation**: Apple Translation framework (on-device, privacy-preserving) on iOS 18+/macOS, with an AI-provider fallback that keeps every translation feature working on iOS 17
- **AI (optional)**: A 10-provider abstraction—Apple Foundation Models, Ollama, and OpenAI-compatible / Anthropic cloud APIs via `URLSession`—for explanations, photo cleanup, and grading
- **OCR**: Vision framework with language-aware recognition (`PhotoTextRecognitionService`)
- **Speech**: AVFoundation for system speech, recording, and playback; optional MiniMax `/v1/t2a_v2` speech persisted as local MP3; Speech framework for live and file transcription
- **NLP**: NaturalLanguage framework for Chinese segmentation and lexical analysis
- **Localization**: String Catalog (`Localizable.xcstrings`, 600+ keys, fully bilingual) + a `LocalizationManager` that swaps the active `.lproj` bundle for the in-app language toggle
- **Storage**: UserDefaults + Codable locally, with automatic last-known-good backups so corrupted data never silently wipes your vocabulary, history, or progress; API keys in the system Keychain
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
- **Local Storage by Default**: Vocabulary, history, progress, imported/recorded working audio, and generated AI Audio files are stored in the app's local container unless you export them
- **On-Device Translation**: Apple Translation framework processes text on-device
- **No Tracking**: No analytics, no telemetry, no third-party tracking SDKs
- **Offline Core**: Translation, vocabulary, flashcards, phrases, stats, and on-device OCR work fully offline (after downloading language packs)
- **AI Is Opt-In**: Cloud AI features are disabled until *you* choose a provider and add a key. Apple Intelligence and Ollama run locally; cloud providers receive only the text or image you submit. When MiniMax AI Audio is enabled, the text you ask the app to speak is sent to MiniMax. API keys remain in the Keychain and are transmitted only to the configured provider.

Your learning journey is yours alone.

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 17.0+          |
| iPadOS   | 17.0+          |
| macOS    | 26.2+          |

**Feature availability by iOS version** — the app adapts to what each OS release provides:

| Capability | iOS 17 | iOS 18 – 25 | iOS 26+ |
|---|---|---|---|
| Translation (Translate / Photo / Live Speech tabs) | Via your configured AI provider | Apple on-device translation | Apple on-device translation |
| Word-tap lookups, screenshot & Shortcuts translation | Via AI provider | Via AI provider | Apple on-device translation |
| Live speech transcription | ✓ (SFSpeechRecognizer) | ✓ (SFSpeechRecognizer) | ✓ (SpeechAnalyzer, fully on-device) |
| Apple Intelligence provider | — | — | ✓ |
| Cloud AI providers, Ollama, OCR, vocabulary, flashcards, stats, phrases | ✓ | ✓ | ✓ |
| Liquid Glass design / sidebar-adaptable tab bar | Material fallback / classic tab bar | Material fallback / ✓ | ✓ / ✓ |

**Language Packs** (iOS 18+/macOS): For on-device translation, download the English-Chinese language pack in System Settings > General > Language & Region > Translation Languages. On iOS 17, configure an AI provider in Settings → AI instead.

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
