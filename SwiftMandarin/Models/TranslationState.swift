//
//  TranslationState.swift
//  SwiftMandarin
//
//  Shared state for translation that persists across tab switches
//

import SwiftUI
import Observation

/// Shared translation state that persists across tab switches
/// This allows users to switch tabs and return to their translation
@Observable
final class TranslationState {
    static let shared = TranslationState()
    
    var sourceText: String = ""
    var translatedText: String = ""
    var direction: TranslationDirection
    var isTranslating: Bool = false
    var translationError: String?

    /// Start on the direction the learner mode implies, rather than always
    /// English→Chinese: a Mandarin speaker studying English opens Translate
    /// on 中→EN. `AppPreferences` seeds this key at launch, so the fall-back
    /// below only matters if this singleton is touched first; it derives the
    /// same answer from the persisted interface language.
    private init() {
        let stored = UserDefaults.standard.string(forKey: "defaultDirection")
            .flatMap(TranslationDirection.init(rawValue:))
        self.direction = stored ?? .persistedDefault
    }
    
    /// Restore from a history entry
    func restore(from entry: TranslationHistoryEntry) {
        sourceText = entry.source
        translatedText = entry.target
        direction = entry.direction
        translationError = nil
        isTranslating = false
    }
    
    /// Clear all translation state
    func clear() {
        sourceText = ""
        translatedText = ""
        translationError = nil
        isTranslating = false
    }
    
    /// Check if there's content to display
    var hasContent: Bool {
        !sourceText.isEmpty || !translatedText.isEmpty
    }
}
