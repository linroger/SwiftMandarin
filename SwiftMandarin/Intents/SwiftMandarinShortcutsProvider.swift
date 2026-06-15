//
//  SwiftMandarinShortcutsProvider.swift
//  SwiftMandarin
//

import AppIntents

struct SwiftMandarinShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Translate to Chinese with \(.applicationName)",
                "Translate to English with \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "character.bubble"
        )
        AppShortcut(
            intent: TranslateClipboardIntent(),
            phrases: [
                "Translate clipboard with \(.applicationName)",
                "Translate copied text with \(.applicationName)"
            ],
            shortTitle: "Translate Clipboard",
            systemImageName: "doc.on.clipboard"
        )
        AppShortcut(
            intent: SpeakTranslationIntent(),
            phrases: [
                "Speak translation with \(.applicationName)",
                "Speak translation in \(.applicationName)"
            ],
            shortTitle: "Speak",
            systemImageName: "speaker.wave.2"
        )
        AppShortcut(
            intent: SaveVocabularyTermIntent(),
            phrases: [
                "Save to \(.applicationName) vocabulary",
                "Add to \(.applicationName) vocabulary"
            ],
            shortTitle: "Save Word",
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: OpenCameraScannerIntent(),
            phrases: [
                "Open live text in \(.applicationName)",
                "Scan text with \(.applicationName)"
            ],
            shortTitle: "Live Scanner",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: StartReviewIntent(),
            phrases: [
                "Review due cards in \(.applicationName)",
                "Start review in \(.applicationName)"
            ],
            shortTitle: "Start Review",
            systemImageName: "brain.head.profile"
        )
        AppShortcut(
            intent: GetLearningStatsIntent(),
            phrases: [
                "Learning stats in \(.applicationName)",
                "Mandarin streak in \(.applicationName)"
            ],
            shortTitle: "Stats",
            systemImageName: "chart.bar"
        )
        AppShortcut(
            intent: GetRandomPhraseIntent(),
            phrases: [
                "Random Chinese phrase in \(.applicationName)",
                "Give me a phrase in \(.applicationName)"
            ],
            shortTitle: "Random Phrase",
            systemImageName: "quote.bubble"
        )
        AppShortcut(
            intent: LookupVocabularyIntent(),
            phrases: [
                "Find in \(.applicationName)",
                "Lookup vocabulary in \(.applicationName)"
            ],
            shortTitle: "Find Word",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: TranslateScreenshotsIntent(),
            phrases: [
                "Translate screenshots with \(.applicationName)",
                "Translate images with \(.applicationName)",
                "OCR translate with \(.applicationName)"
            ],
            shortTitle: "Translate Screenshots",
            systemImageName: "doc.text.image"
        )
    }
}
