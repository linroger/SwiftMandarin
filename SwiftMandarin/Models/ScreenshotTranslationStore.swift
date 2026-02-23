//
//  ScreenshotTranslationStore.swift
//  SwiftMandarin
//
//  Shared state store for screenshot translation feature
//  Manages the flow from image input through translation to display
//

import Foundation
import SwiftUI
import Translation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A translated text block with position information
struct TranslatedTextBlock: Identifiable, Sendable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    /// Bounding box in normalized coordinates (0-1) from Vision
    let boundingBox: CGRect
    /// Confidence score from OCR
    let confidence: Float
}

/// Target language for translation
enum ScreenshotTargetLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"
    
    var localeLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

/// Processing state for the translation workflow
enum ScreenshotProcessingState: Equatable, Sendable {
    case idle
    case stitching
    case recognizingText
    case translating
    case completed
    case error(String)
    
    var isProcessing: Bool {
        switch self {
        case .stitching, .recognizingText, .translating:
            return true
        default:
            return false
        }
    }
    
    var statusMessage: String {
        switch self {
        case .idle:
            return "Ready"
        case .stitching:
            return "Stitching screenshots..."
        case .recognizingText:
            return "Recognizing text..."
        case .translating:
            return "Translating..."
        case .completed:
            return "Complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

/// Observable store for screenshot translation state
@Observable
@MainActor
final class ScreenshotTranslationStore {
    
    static let shared = ScreenshotTranslationStore()
    
    // MARK: - Input State
    
    #if canImport(UIKit)
    /// Pending images to process (set by App Intent)
    var pendingImages: [UIImage]?
    #elseif canImport(AppKit)
    /// Pending images to process (set by App Intent)
    var pendingImages: [NSImage]?
    #endif
    
    /// Target language for translation
    var targetLanguage: ScreenshotTargetLanguage = .english
    
    // MARK: - Processing State
    
    /// Current processing state
    var state: ScreenshotProcessingState = .idle
    
    // MARK: - Output State
    
    /// Result of image stitching
    var stitchedResult: StitchedImageResult?
    
    /// OCR results sorted in reading order
    var recognizedBlocks: [RecognizedTextBlock]?
    
    /// Translated text blocks
    var translatedBlocks: [TranslatedTextBlock]?
    
    /// Combined translated text in reading order
    var fullTranslatedText: String {
        translatedBlocks?.map { $0.translatedText }.joined(separator: "\n\n") ?? ""
    }
    
    /// Combined original text in reading order
    var fullOriginalText: String {
        recognizedBlocks?.map { $0.text }.joined(separator: "\n\n") ?? ""
    }
    
    // MARK: - Computed Properties
    
    var hasContent: Bool {
        translatedBlocks != nil && !(translatedBlocks?.isEmpty ?? true)
    }
    
    var hasError: Bool {
        if case .error = state {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = state {
            return message
        }
        return nil
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Process pending screenshots: stitch, OCR, and translate
    func processScreenshots() async {
        guard let images = pendingImages, !images.isEmpty else {
            state = .error("No images to process")
            return
        }
        
        state = .stitching
        
        do {
            // Step 1: Stitch images
            let stitched = await ScreenshotStitchingService.shared.stitch(images: images)
            stitchedResult = stitched
            
            state = .recognizingText
            
            // Step 2: OCR
            let ocrResult = try await PhotoTextRecognitionService.shared.recognizeText(in: stitched.image)
            
            // Sort blocks in reading order (top-to-bottom, left-to-right)
            let sortedBlocks = sortInReadingOrder(ocrResult.blocks)
            recognizedBlocks = sortedBlocks
            
            state = .translating
            
            // Step 3: Translate
            let translated = try await translateBlocks(sortedBlocks)
            translatedBlocks = translated
            
            state = .completed
            
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    /// Clear all state
    func clear() {
        pendingImages = nil
        stitchedResult = nil
        recognizedBlocks = nil
        translatedBlocks = nil
        state = .idle
    }
    
    /// Reset to process new images
    func reset() {
        stitchedResult = nil
        recognizedBlocks = nil
        translatedBlocks = nil
        state = .idle
    }
    
    // MARK: - Private Methods
    
    /// Sort text blocks in reading order
    private func sortInReadingOrder(_ blocks: [RecognizedTextBlock]) -> [RecognizedTextBlock] {
        // Vision coordinates: origin at bottom-left, Y increases upward
        // We want top-to-bottom reading order
        
        // Group blocks by approximate Y position (rows)
        let rowThreshold: CGFloat = 0.02 // 2% of image height
        
        var rows: [[RecognizedTextBlock]] = []
        var currentRow: [RecognizedTextBlock] = []
        var currentRowY: CGFloat = -1
        
        // Sort by Y (descending, so top items come first)
        let sortedByY = blocks.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        
        for block in sortedByY {
            let blockY = block.boundingBox.maxY
            
            if currentRowY < 0 {
                // First block
                currentRowY = blockY
                currentRow = [block]
            } else if abs(blockY - currentRowY) <= rowThreshold {
                // Same row
                currentRow.append(block)
            } else {
                // New row
                if !currentRow.isEmpty {
                    // Sort current row by X (left-to-right)
                    rows.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                }
                currentRowY = blockY
                currentRow = [block]
            }
        }
        
        // Don't forget the last row
        if !currentRow.isEmpty {
            rows.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
        }
        
        // Flatten rows into final ordered list
        return rows.flatMap { $0 }
    }
    
    /// Translate text blocks using Translation framework
    private func translateBlocks(_ blocks: [RecognizedTextBlock]) async throws -> [TranslatedTextBlock] {
        guard !blocks.isEmpty else { return [] }
        
        // Combine all text for batch translation
        // Use a delimiter that won't appear in normal text
        let delimiter = "\n§§§\n"
        let combinedText = blocks.map { $0.text }.joined(separator: delimiter)
        
        // Translate using the system Translation framework
        let translatedCombined = try await translateText(combinedText)
        
        // Split back into individual translations
        let translatedTexts = translatedCombined.components(separatedBy: delimiter)
        
        // Map back to blocks
        var result: [TranslatedTextBlock] = []
        for (index, block) in blocks.enumerated() {
            let translatedText = index < translatedTexts.count ? translatedTexts[index].trimmingCharacters(in: .whitespacesAndNewlines) : block.text
            
            result.append(TranslatedTextBlock(
                originalText: block.text,
                translatedText: translatedText,
                boundingBox: block.boundingBox,
                confidence: block.confidence
            ))
        }
        
        return result
    }
    
    /// Translate text using Apple's Translation framework
    private func translateText(_ text: String) async throws -> String {
        // Use the same translation approach as elsewhere in the app
        // This leverages TranslationSession for on-device translation
        
        let sourceLanguage: Locale.Language
        let targetLang = targetLanguage.localeLanguage
        
        // Detect source language - if targeting English, source is likely Chinese and vice versa
        if targetLanguage == .english {
            sourceLanguage = Locale.Language(identifier: "zh-Hans")
        } else {
            sourceLanguage = Locale.Language(identifier: "en")
        }
        
        // Create translation session using installed languages
        let session = try await TranslationSession(
            installedSource: sourceLanguage,
            target: targetLang
        )
        
        let response = try await session.translate(text)
        return response.targetText
    }
}
