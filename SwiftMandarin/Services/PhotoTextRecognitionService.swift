//
//  PhotoTextRecognitionService.swift
//  SwiftMandarin
//
//  Photo OCR service using Apple Vision framework.
//  Recognizes text in images for translation, with configurable
//  recognition language so Chinese text is no longer mangled by an
//  English-first recognizer.
//

import Foundation
import Vision
import ImageIO
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
    let cleanedText: String  // Text cleaned for downstream processing (language-aware)
    let language: DetectedLanguage?

    var isEmpty: Bool { blocks.isEmpty }

    init(blocks: [RecognizedTextBlock], scanLanguage: PhotoScanLanguage = .auto) {
        self.blocks = blocks
        let texts = blocks.map { $0.text }
        self.fullText = texts.joined(separator: "\n")

        // Honor an explicit user-selected scan language; only auto-detect for
        // the auto/bilingual modes. Without this, ambiguous OCR output (e.g.
        // pinyin-heavy text) could override the user's explicit 中文 choice
        // and route it through the English cleaner.
        let detected: DetectedLanguage
        switch scanLanguage {
        case .chinese:
            detected = .chinese
        case .english:
            detected = .english
        case .auto, .bilingual:
            detected = ChineseTextAnalyzer.shared.detectLanguageRobust(texts.joined(separator: "\n"))
        }
        self.language = blocks.isEmpty ? nil : detected

        if detected.isChinese {
            self.cleanedText = TextRecognitionResult.cleanChineseText(texts)
        } else {
            self.cleanedText = TextRecognitionResult.cleanTextForSentences(texts.joined(separator: " "))
        }
    }

    /// Clean English OCR text: join sentences split by line breaks, fix
    /// hyphenation, normalize spacing around punctuation.
    static func cleanTextForSentences(_ text: String) -> String {
        var result = text

        // Normalize all whitespace to single spaces.
        result = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Fix hyphenated words split across lines (e.g., "com- municate").
        result = result.replacingOccurrences(of: "- ", with: "")

        // Ensure proper spacing after sentence punctuation.
        result = result.replacingOccurrences(of: "\\.([A-Z])", with: ". $1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\?([A-Z])", with: "? $1", options: .regularExpression)
        result = result.replacingOccurrences(of: "!([A-Z])", with: "! $1", options: .regularExpression)

        // Clean up multiple spaces.
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clean Chinese OCR text: Chinese has no inter-word spaces, so remove the
    /// spurious whitespace OCR inserts between Han characters while preserving
    /// spaces around embedded Latin words/numbers.
    static func cleanChineseText(_ blocks: [String]) -> String {
        let joined = blocks.joined(separator: "\n")
        let despaced = removeWhitespaceBetweenCJK(joined)
        // Collapse any remaining whitespace runs (between Latin tokens) to one space.
        let collapsed = despaced.replacingOccurrences(of: "[ \\t\\n]+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Remove whitespace runs that sit between two Han characters.
    private static func removeWhitespaceBetweenCJK(_ s: String) -> String {
        let chars = Array(s)
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                // Consume the whole whitespace run.
                var j = i
                while j < chars.count, chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r" {
                    j += 1
                }
                let prev = out.last
                let next = j < chars.count ? chars[j] : nil
                if let prev, let next, prev.isChineseCharacter, next.isChineseCharacter {
                    // Drop whitespace entirely between Han characters.
                } else {
                    out.append(" ")
                }
                i = j
            } else {
                out.append(c)
                i += 1
            }
        }
        return String(out)
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

    /// Recognize text in a CGImage with a configurable scan language.
    func recognizeText(
        in cgImage: CGImage,
        scanLanguage: PhotoScanLanguage = .auto,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> TextRecognitionResult {
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        do {
            let blocks = try await performRecognition(
                cgImage: cgImage,
                languages: scanLanguage.recognitionLanguages,
                useLanguageCorrection: scanLanguage.usesLanguageCorrection,
                orientation: orientation
            )

            if blocks.isEmpty {
                throw RecognitionError.noTextFound
            }

            let result = TextRecognitionResult(blocks: blocks, scanLanguage: scanLanguage)
            lastResult = result
            return result
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    #if canImport(UIKit)
    /// Recognize text in a UIImage, honoring its orientation.
    func recognizeText(in image: UIImage, scanLanguage: PhotoScanLanguage = .auto) async throws -> TextRecognitionResult {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }
        return try await recognizeText(
            in: cgImage,
            scanLanguage: scanLanguage,
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
    }
    #endif

    #if canImport(AppKit)
    /// Recognize text in an NSImage.
    func recognizeText(in image: NSImage, scanLanguage: PhotoScanLanguage = .auto) async throws -> TextRecognitionResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw RecognitionError.invalidImage
        }
        return try await recognizeText(in: cgImage, scanLanguage: scanLanguage, orientation: .up)
    }
    #endif

    /// Recognize text from image data, honoring embedded EXIF orientation.
    func recognizeText(from data: Data, scanLanguage: PhotoScanLanguage = .auto) async throws -> TextRecognitionResult {
        let orientation = PhotoTextRecognitionService.orientation(from: data)
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

        return try await recognizeText(in: cgImage, scanLanguage: scanLanguage, orientation: orientation)
    }

    // MARK: - Private Methods

    private func performRecognition(
        cgImage: CGImage,
        languages: [String],
        useLanguageCorrection: Bool,
        orientation: CGImagePropertyOrientation
    ) async throws -> [RecognizedTextBlock] {
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
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: blocks)
            }

            // Configure for accurate recognition.
            request.recognitionLevel = .accurate

            // Caller-supplied recognition languages (Chinese-first by default),
            // so Chinese text is recognized correctly rather than coerced to English.
            request.recognitionLanguages = languages

            // Language correction is an English model that corrupts Chinese OCR,
            // so it is enabled only when appropriate for the scan language.
            request.usesLanguageCorrection = useLanguageCorrection

            // Use revision 3 for best accuracy (iOS 16+ / macOS 13+).
            if #available(iOS 16.0, macOS 13.0, *) {
                request.revision = VNRecognizeTextRequestRevision3
            }

            // Honor image orientation so rotated photos OCR correctly.
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: RecognitionError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    /// Read EXIF orientation from raw image data.
    private static func orientation(from data: Data) -> CGImagePropertyOrientation {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = (props[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value,
              let orientation = CGImagePropertyOrientation(rawValue: raw) else {
            return .up
        }
        return orientation
    }

    /// Clear the last result and error
    func reset() {
        lastResult = nil
        lastError = nil
    }
}

#if canImport(UIKit)
private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
