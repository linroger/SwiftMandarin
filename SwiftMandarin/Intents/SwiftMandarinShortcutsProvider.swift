//
//  SwiftMandarinShortcutsProvider.swift
//  SwiftMandarin
//
//  The App Shortcuts Siri offers without setup. Apple allows ten per app, and
//  all ten are used, so adding one means retiring one: "Translate
//  Screenshots" lost its phrases (it needs images Siri cannot supply by voice
//  and stays available as a Shortcuts action) to make room for "Explain Word".
//

import AppIntents

struct SwiftMandarinShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        // The direction is a parameter of the phrase, resolved through the
        // enum's synonyms ("to Chinese", "to English"); the old literal
        // "Translate to Chinese" phrases launched the intent with Auto.
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Translate \(\.$direction) with \(.applicationName)",
                "Translate text in \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "character.bubble"
        )
        AppShortcut(
            intent: TranslateClipboardIntent(),
            phrases: [
                "Translate my clipboard with \(.applicationName)",
                "Translate copied text with \(.applicationName)"
            ],
            shortTitle: "Translate Clipboard",
            systemImageName: "doc.on.clipboard"
        )
        AppShortcut(
            intent: SpeakTranslationIntent(),
            phrases: [
                "Speak a translation with \(.applicationName)",
                "Say it in \(.applicationName)"
            ],
            shortTitle: "Speak",
            systemImageName: "speaker.wave.2"
        )
        AppShortcut(
            intent: ExplainWordIntent(),
            // Only an AppEnum or AppEntity may appear inside a phrase, so the
            // word itself is asked for after the phrase is spoken.
            phrases: [
                "Explain a word with \(.applicationName)",
                "Explain a word in \(.applicationName)"
            ],
            shortTitle: "Explain Word",
            systemImageName: "text.magnifyingglass"
        )
        AppShortcut(
            intent: SaveVocabularyTermIntent(),
            phrases: [
                "Save a word to \(.applicationName)",
                "Add a word to my \(.applicationName) vocabulary"
            ],
            shortTitle: "Save Word",
            systemImageName: "bookmark"
        )
        // Offered on both platforms: the phrase catalog is shared, and a phrase
        // that exists only on iOS is flagged as unused by the macOS build. On
        // macOS the intent opens the Multimodal workspace, where a photo can
        // be scanned instead of the live camera.
        AppShortcut(
            intent: OpenCameraScannerIntent(),
            phrases: [
                "Scan text with \(.applicationName)",
                "Open live text in \(.applicationName)"
            ],
            shortTitle: "Live Scanner",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: StartReviewIntent(),
            phrases: [
                "Review due cards in \(.applicationName)",
                "Start a review in \(.applicationName)"
            ],
            shortTitle: "Start Review",
            systemImageName: "brain.head.profile"
        )
        AppShortcut(
            intent: GetLearningStatsIntent(),
            phrases: [
                "Show my learning streak in \(.applicationName)",
                "Show my learning stats in \(.applicationName)"
            ],
            shortTitle: "Stats",
            systemImageName: "chart.bar"
        )
        AppShortcut(
            intent: GetRandomPhraseIntent(),
            phrases: [
                "Give me a practice phrase from \(.applicationName)",
                "Random phrase from \(.applicationName)"
            ],
            shortTitle: "Random Phrase",
            systemImageName: "quote.bubble"
        )
        AppShortcut(
            intent: LookupVocabularyIntent(),
            phrases: [
                "Look up a word in \(.applicationName)",
                "Search my \(.applicationName) vocabulary"
            ],
            shortTitle: "Look Up Word",
            systemImageName: "magnifyingglass"
        )
    }
}
