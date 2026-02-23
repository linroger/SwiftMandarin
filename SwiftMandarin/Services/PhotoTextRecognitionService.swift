//
//  PhotoTextRecognitionService.swift
//  SwiftMandarin
//
//  Photo OCR service using Apple Vision framework
//  Recognizes text in images for translation
//

import Foundation
import Vision
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Result of text recognition from an image
struct RecognizedTextBlock: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

/// Combined recognition result
struct TextRecognitionResult: Sendable {
    let blocks: [RecognizedTextBlock]
    let fullText: String
    let cleanedText: String  // Text with line breaks cleaned up for sentence processing
    let language: String?
    
    var isEmpty: Bool { blocks.isEmpty }
    
    init(blocks: [RecognizedTextBlock]) {
        self.blocks = blocks
        self.fullText = blocks.map { $0.text }.joined(separator: "\n")
        self.cleanedText = TextRecognitionResult.cleanTextForSentences(blocks.map { $0.text }.joined(separator: " "))
        self.language = nil
    }
    
    /// Clean OCR text to properly join sentences split by line breaks
    /// This is important for textbook scanning where sentences may span multiple lines
    private static func cleanTextForSentences(_ text: String) -> String {
        var result = text
        
        // Replace multiple whitespace/newlines with single space
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Fix common OCR issues where sentences are split by line breaks
        // Pattern: lowercase letter followed by newline/space followed by lowercase letter (likely mid-sentence)
        // Keep line breaks after sentence-ending punctuation
        
        // First, normalize all whitespace to single spaces
        result = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        // Fix hyphenated words split across lines (e.g., "com- municate" -> "communicate")
        result = result.replacingOccurrences(of: "- ", with: "")
        
        // Ensure proper spacing after punctuation
        result = result.replacingOccurrences(of: "\\.([A-Z])", with: ". $1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\?([A-Z])", with: "? $1", options: .regularExpression)
        result = result.replacingOccurrences(of: "!([A-Z])", with: "! $1", options: .regularExpression)
        
        // Clean up multiple spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Errors that can occur during text recognition
enum RecognitionError: LocalizedError {
    case invalidImage
    case recognitionFailed(String)
    case noTextFound
    case unsupportedPlatform
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片"
        case .recognitionFailed(let message):
            return "识别失败: \(message)"
        case .noTextFound:
            return "未找到文字"
        case .unsupportedPlatform:
            return "当前平台不支持此功能"
        }
    }
}

/// Service for recognizing text in images using Vision framework
@Observable
@MainActor
final class PhotoTextRecognitionService {
    
    static let shared = PhotoTextRecognitionService()
    
    /// Current recognition state
    var isProcessing: Bool = false
    var lastError: String?
    var lastResult: TextRecognitionResult?
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Recognize text in a CGImage
    func recognizeText(in cgImage: CGImage) async throws -> TextRecognitionResult {
        isProcessing = true
        lastError = nil
        
        defer { isProcessing = false }
        
        do {
            let blocks = try await performRecognition(cgImage: cgImage)
            
            if blocks.isEmpty {
                throw RecognitionError.noTextFound
            }
            
            let result = TextRecognitionResult(blocks: blocks)
            lastResult = result
            return result
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    #if canImport(UIKit)
    /// Recognize text in a UIImage
    func recognizeText(in image: UIImage) async throws -> TextRecognitionResult {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }
        return try await recognizeText(in: cgImage)
    }
    #endif
    
    #if canImport(AppKit)
    /// Recognize text in an NSImage
    func recognizeText(in image: NSImage) async throws -> TextRecognitionResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw RecognitionError.invalidImage
        }
        return try await recognizeText(in: cgImage)
    }
    #endif
    
    /// Recognize text from image data
    func recognizeText(from data: Data) async throws -> TextRecognitionResult {
        #if canImport(UIKit)
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw RecognitionError.invalidImage
        }
        #endif
        
        return try await recognizeText(in: cgImage)
    }
    
    // MARK: - Private Methods
    
    private func performRecognition(cgImage: CGImage) async throws -> [RecognizedTextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: RecognitionError.recognitionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                    // Get the top candidate for each observation
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    
                    return RecognizedTextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                
                continuation.resume(returning: blocks)
            }
            
            // Configure for accurate recognition
            request.recognitionLevel = .accurate
            
            // Prioritize English for textbook scanning
            request.recognitionLanguages = ["en-US", "en-GB", "zh-Hans", "zh-Hant"]
            
            // Enable language correction for better accuracy
            request.usesLanguageCorrection = true
            
            // Use revision 3 for best accuracy (iOS 16+)
            if #available(iOS 16.0, macOS 13.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: RecognitionError.recognitionFailed(error.localizedDescription))
            }
        }
    }
    
    /// Clear the last result and error
    func reset() {
        lastResult = nil
        lastError = nil
    }
}
