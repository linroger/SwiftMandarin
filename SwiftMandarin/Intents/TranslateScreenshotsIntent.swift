//
//  TranslateScreenshotsIntent.swift
//  SwiftMandarin
//
//  App Intent for translating multiple screenshots
//  Stitches images, performs OCR, and displays translated overlay
//

import Foundation
import AppIntents
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// App Intent for translating screenshots via Shortcuts
struct TranslateScreenshotsIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screenshots"
    
    static var description = IntentDescription(
        "Stitch multiple screenshots together, extract text, and translate to English or Chinese. Perfect for translating long web pages or documents captured as multiple screenshots."
    )
    
    /// Must open the app to display the overlay
    static var openAppWhenRun: Bool = true
    
    // MARK: - Parameters
    
    @Parameter(
        title: "Screenshots",
        description: "One or more screenshots to translate. If multiple images are provided, they will be stitched together with overlapping regions automatically removed.",
        supportedTypeIdentifiers: ["public.image"]
    )
    var images: [IntentFile]
    
    @Parameter(
        title: "Target Language",
        description: "The language to translate the text into.",
        default: .english
    )
    var targetLanguage: ShortcutTargetLanguage
    
    // MARK: - Parameter Summary
    
    static var parameterSummary: some ParameterSummary {
        Summary("Translate \\(\\.$images) to \\(\\.$targetLanguage)")
    }
    
    // MARK: - Perform
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Validate we have images
        guard !images.isEmpty else {
            throw TranslationIntentError.emptyText
        }
        
        #if os(iOS)
        // Load UIImages from IntentFile data
        var uiImages: [UIImage] = []
        
        for file in images {
            let data = file.data
            if let image = UIImage(data: data) {
                uiImages.append(image)
            }
        }
        
        guard !uiImages.isEmpty else {
            throw TranslationIntentError.invalidImages
        }
        
        // Set up the shared store
        let store = ScreenshotTranslationStore.shared
        store.pendingImages = uiImages
        store.targetLanguage = targetLanguage.toScreenshotTargetLanguage
        
        // Trigger the app to show the overlay
        AppRouteStore.shared.trigger(.translateScreenshots, preferredTab: .photo)
        
        // Start processing in background
        Task {
            await store.processScreenshots()
        }
        
        return .result(
            dialog: IntentDialog("Opening translation view for \(uiImages.count) screenshot(s)...")
        )
        #else
        // macOS - load NSImages instead
        var nsImages: [NSImage] = []
        
        for file in images {
            let data = file.data
            if let image = NSImage(data: data) {
                nsImages.append(image)
            }
        }
        
        guard !nsImages.isEmpty else {
            throw TranslationIntentError.invalidImages
        }
        
        // Set up the shared store
        let store = ScreenshotTranslationStore.shared
        store.pendingImages = nsImages
        store.targetLanguage = targetLanguage.toScreenshotTargetLanguage
        
        // Trigger the app to show the overlay
        AppRouteStore.shared.trigger(.translateScreenshots, preferredTab: .photo)
        
        // Start processing in background
        Task {
            await store.processScreenshots()
        }
        
        return .result(
            dialog: IntentDialog("Opening translation view for \(nsImages.count) screenshot(s)...")
        )
        #endif
    }
}

// MARK: - Target Language Enum

enum ShortcutTargetLanguage: String, AppEnum {
    case english
    case chinese
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Target Language")
    }
    
    static var caseDisplayRepresentations: [ShortcutTargetLanguage: DisplayRepresentation] {
        [
            .english: DisplayRepresentation(title: "English", subtitle: "Translate Chinese to English"),
            .chinese: DisplayRepresentation(title: "中文 (Chinese)", subtitle: "Translate English to Chinese")
        ]
    }
    
    var toScreenshotTargetLanguage: ScreenshotTargetLanguage {
        switch self {
        case .english: return .english
        case .chinese: return .chinese
        }
    }
}


