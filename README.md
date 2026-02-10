# SwiftMandarin

A modern Apple-platform Mandarin Chinese learning and translation app built with SwiftUI and Apple Translation.

SwiftMandarin combines translation, pinyin-aware reading support, vocabulary building, and flashcard practice in one app for iPhone, iPad, and Mac.

## Highlights

- Bidirectional translation: English <-> Chinese using Apple's Translation framework.
- Interactive Chinese output: tap words to see pinyin, part of speech, and per-word translation.
- Tone-colored pinyin rendering for faster pronunciation recognition.
- Translation history with restore, reverse-translate, duplicate, reorder, and quick copy actions.
- Vocabulary manager with search, sorting, details, export, and text-to-speech.
- Flashcard learning with spaced repetition and mastery tracking.
- Phrasebook grouped by practical categories (greetings, travel, dining, and more).
- Cross-platform experience for iOS/iPadOS and macOS, with platform-appropriate navigation.

## Platform Requirements

- Xcode: 26+
- Swift: 6.2+
- Deployment targets:
  - iOS 26.2+
  - macOS 26.2+
- Apple Translation language packs installed for translation directions you use

## Install

### Option 1: Install via DMG (recommended for Mac users)

1. Download the latest DMG from the [Releases](https://github.com/linroger/SwiftMandarin/releases).
2. Open `SwiftMandarin-2.0-macOS.dmg`.
3. Drag `SwiftMandarin.app` into `Applications`.
4. Launch SwiftMandarin from Applications.

If Gatekeeper warns on first launch, right-click the app, choose **Open**, then confirm.

### Option 2: Build and run from source

```bash
git clone https://github.com/linroger/SwiftMandarin.git
cd SwiftMandarin
open SwiftMandarin.xcodeproj
```

In Xcode:
1. Select the `SwiftMandarin` scheme.
2. Pick a destination (`iPhone`, `iPad`, or `My Mac`).
3. Build and run.

Or build via CLI:

```bash
xcodebuild -project SwiftMandarin.xcodeproj -scheme SwiftMandarin -configuration Debug -destination 'platform=macOS' build
```

## How to Use

### 1. Translate

- Enter or paste text in the source panel.
- Toggle direction with the arrow switch (`English -> Chinese` or `Chinese -> English`).
- Tap **Translate** (or enable auto-translate in settings).
- Use action buttons to speak, copy, clear, or save translation.

### 2. Explore Chinese Output

- In Chinese output mode, words are displayed with pinyin above each segment.
- Tap any word to open details:
  - pinyin
  - part of speech
  - per-word translation
  - save/copy/speak actions

### 3. Build Vocabulary

- Save words from Translate, Phrase details, or word popovers.
- In **Vocabulary**:
  - search and sort by date/alphabetical/pinyin
  - open term detail sheets
  - export terms as CSV, JSON, or plain text

### 4. Review History

- Open **History** for previous translations.
- Tap an entry to restore it to Translate.
- Use swipe/context actions to delete, duplicate, reverse-translate, and copy.

### 5. Practice with Flashcards

- Open **Learn**.
- Choose built-in deck, vocabulary deck, or combined deck.
- Flip cards, rate recall quality, and let spaced repetition schedule reviews.

### 6. Use Common Phrases

- Browse **Phrases** by category.
- Search by Chinese, pinyin, or English.
- Tap a phrase to speak, copy, or save.

### 7. Configure Settings

- Translation behavior (auto-translate, translate-on-paste, default direction)
- Output behavior (auto-copy, history)
- Display preferences (pinyin, tone colors, text size)
- Data management (clear vocabulary/history/progress)

## Architecture Overview

- `SwiftMandarin/Views/`: feature views (Translate, History, Vocabulary, Learn, Phrases, More)
- `SwiftMandarin/Services/`: translation-adjacent services (speech, clipboard, pinyin conversion, text analysis)
- `SwiftMandarin/Models/`: persistent data and stores (`SavedTermsStore`, `TranslationHistoryStore`, `LearningProgressStore`)

Key implementation details:
- Shared translation state across tabs (`TranslationState.shared`)
- Persistence via `UserDefaults` + Codable models
- Chinese segmentation and lexical tagging via `NaturalLanguage`
- TTS via `AVFoundation`

## Screenshots

### macOS

<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.15@2x.png" width="46%" alt="macOS - Translate view" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.44@2x.png" width="46%" alt="macOS - Vocabulary view" />
</p>
<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.50@2x.png" width="46%" alt="macOS - Learn view" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.56@2x.png" width="46%" alt="macOS - Phrases view" />
</p>

### iPhone (horizontal gallery)

Swipe/scroll horizontally to browse the iPhone screenshots:

<table>
  <tr>
    <td><img src="Screenshots/iOS%20Screenshots/IMG_8529.PNG" width="220" alt="iPhone screenshot 1" /></td>
    <td><img src="Screenshots/iOS%20Screenshots/IMG_8530.PNG" width="220" alt="iPhone screenshot 2" /></td>
    <td><img src="Screenshots/iOS%20Screenshots/IMG_8531.PNG" width="220" alt="iPhone screenshot 3" /></td>
    <td><img src="Screenshots/iOS%20Screenshots/IMG_8532.PNG" width="220" alt="iPhone screenshot 4" /></td>
    <td><img src="Screenshots/iOS%20Screenshots/IMG_8533.PNG" width="220" alt="iPhone screenshot 5" /></td>
    <td><img src="Screenshots/iOS%20Screenshots/IMG_8534.PNG" width="220" alt="iPhone screenshot 6" /></td>
  </tr>
</table>

### iPadOS

<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0588.PNG" width="46%" alt="iPad screenshot 1" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0589.PNG" width="46%" alt="iPad screenshot 2" />
</p>
<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0590.PNG" width="46%" alt="iPad screenshot 3" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0591.PNG" width="46%" alt="iPad screenshot 4" />
</p>
<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0592.PNG" width="46%" alt="iPad screenshot 5" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0593.PNG" width="46%" alt="iPad screenshot 6" />
</p>
<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0594.PNG" width="46%" alt="iPad screenshot 7" />
</p>

## Privacy and Data

- Translation history, vocabulary, and learning progress are stored locally using `UserDefaults`.
- No custom backend is required for core app functionality.
- Apple Translation availability and language packs are managed by the system.

## Packaging (Maintainers)

Build and package a macOS DMG:

```bash
xcodebuild -project SwiftMandarin.xcodeproj -scheme SwiftMandarin -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData clean build

mkdir -p dist/dmg/SwiftMandarin
cp -R build/DerivedData/Build/Products/Release/SwiftMandarin.app dist/dmg/SwiftMandarin/
ln -s /Applications dist/dmg/SwiftMandarin/Applications

hdiutil create -volname "SwiftMandarin" -srcfolder dist/dmg/SwiftMandarin -ov -format UDZO dist/SwiftMandarin-2.0-macOS.dmg
```

