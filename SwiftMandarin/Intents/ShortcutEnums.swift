//
//  ShortcutEnums.swift
//  SwiftMandarin
//

import Foundation
import AppIntents

enum ShortcutTranslationDirection: String, AppEnum {
    case auto
    case englishToChinese
    case chineseToEnglish

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Translation Direction")
    }

    static var caseDisplayRepresentations: [ShortcutTranslationDirection: DisplayRepresentation] {
        // Synonyms are what let Siri resolve "Translate to Chinese with
        // SwiftMandarin": the App Shortcut phrase carries this parameter, and
        // without them the two spoken directions both ran as Auto.
        [
            .auto: DisplayRepresentation(title: "Auto", synonyms: ["automatically", "auto-detect"]),
            .englishToChinese: DisplayRepresentation(
                title: "English → Chinese",
                synonyms: ["to Chinese", "into Chinese", "English to Chinese", "to Mandarin"]
            ),
            .chineseToEnglish: DisplayRepresentation(
                title: "Chinese → English",
                synonyms: ["to English", "into English", "Chinese to English"]
            )
        ]
    }
}

enum ShortcutSpeakTarget: String, AppEnum {
    case translated
    case source

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Speak")
    }

    static var caseDisplayRepresentations: [ShortcutSpeakTarget: DisplayRepresentation] {
        [
            .translated: DisplayRepresentation(title: "Translated Text"),
            .source: DisplayRepresentation(title: "Original Text")
        ]
    }
}

enum ShortcutReviewMode: String, AppEnum {
    case all
    case due
    case new
    case difficult

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Review Mode")
    }

    static var caseDisplayRepresentations: [ShortcutReviewMode: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "All Cards"),
            .due: DisplayRepresentation(title: "Due for Review"),
            .new: DisplayRepresentation(title: "New Cards"),
            .difficult: DisplayRepresentation(title: "Difficult")
        ]
    }
}

enum ShortcutCardSource: String, AppEnum {
    case builtin
    case vocabulary
    case combined

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Card Source")
    }

    static var caseDisplayRepresentations: [ShortcutCardSource: DisplayRepresentation] {
        [
            .builtin: DisplayRepresentation(title: "Built-in Deck"),
            .vocabulary: DisplayRepresentation(title: "My Vocabulary"),
            .combined: DisplayRepresentation(title: "All Cards")
        ]
    }
}

enum ShortcutStatsRange: String, AppEnum {
    case today
    case last7Days
    case last30Days
    case allTime

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Stats Range")
    }

    static var caseDisplayRepresentations: [ShortcutStatsRange: DisplayRepresentation] {
        [
            .today: DisplayRepresentation(title: "Today"),
            .last7Days: DisplayRepresentation(title: "Last 7 Days"),
            .last30Days: DisplayRepresentation(title: "Last 30 Days"),
            .allTime: DisplayRepresentation(title: "All Time")
        ]
    }
}

enum ShortcutPhraseCategory: String, AppEnum {
    case greetings
    case commonExpressions
    case questions
    case dining
    case travel
    case numbers
    case time
    case any

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Phrase Category")
    }

    static var caseDisplayRepresentations: [ShortcutPhraseCategory: DisplayRepresentation] {
        [
            .greetings: DisplayRepresentation(title: "Greetings"),
            .commonExpressions: DisplayRepresentation(title: "Common Expressions"),
            .questions: DisplayRepresentation(title: "Questions"),
            .dining: DisplayRepresentation(title: "Dining"),
            .travel: DisplayRepresentation(title: "Travel"),
            .numbers: DisplayRepresentation(title: "Numbers"),
            .time: DisplayRepresentation(title: "Time"),
            .any: DisplayRepresentation(title: "Any")
        ]
    }
}
