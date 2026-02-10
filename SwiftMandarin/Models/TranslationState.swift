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
    var direction: TranslationDirection = .englishToChinese
    var isTranslating: Bool = false
    var translationError: String?
    
    private init() {}
    
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
