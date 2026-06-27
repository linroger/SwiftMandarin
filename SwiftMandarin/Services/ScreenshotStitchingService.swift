//
//  ScreenshotStitchingService.swift
//  SwiftMandarin
//
//  Service for stitching multiple screenshots into a single vertical image
//  with automatic overlap detection and removal
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Result of stitching multiple screenshots
struct StitchedImageResult: Sendable {
    #if canImport(UIKit)
    let image: UIImage
    #elseif canImport(AppKit)
    let image: NSImage
    #endif
    
    /// Y-positions where original images were joined (in final image coordinates)
    let pageBreaks: [CGFloat]
    
    /// Heights of each original image before stitching
    let originalHeights: [CGFloat]
    
    /// Detected overlap heights between consecutive images
    let overlapHeights: [Int]
    
    /// Total height of the stitched image
    var totalHeight: CGFloat {
        #if canImport(UIKit)
        return image.size.height
        #elseif canImport(AppKit)
        return image.size.height
        #endif
    }
}

/// Service for stitching multiple screenshots into one continuous image
@MainActor
final class ScreenshotStitchingService {
    
    static let shared = ScreenshotStitchingService()
    
    /// Configuration for overlap detection
    struct Configuration: Sendable {
        /// Maximum overlap to search for (in pixels)
        var maxOverlapPixels: Int = 300
        
        /// Minimum overlap to consider valid
        var minOverlapPixels: Int = 20
        
        /// Similarity threshold for matching (0.0-1.0)
        var similarityThreshold: Float = 0.90
        
        /// Width of the comparison strip (center portion of image)
        var comparisonStripWidthRatio: CGFloat = 0.6
        
        /// Row sampling interval for faster comparison
        var rowSampleInterval: Int = 2
    }
    
    var configuration = Configuration()
    
    private init() {}
    
    // MARK: - Public Methods
    
    #if canImport(UIKit)
    /// Stitch multiple UIImages into one vertical image, removing overlaps
    func stitch(images: [UIImage]) async -> StitchedImageResult {
        guard !images.isEmpty else {
            // Return empty result
            return StitchedImageResult(
                image: UIImage(),
                pageBreaks: [],
                originalHeights: [],
                overlapHeights: []
            )
        }
        
        guard images.count > 1 else {
            // Single image, no stitching needed
            return StitchedImageResult(
                image: images[0],
                pageBreaks: [],
                originalHeights: [images[0].size.height],
                overlapHeights: []
            )
        }
        
        // Calculate overlaps between consecutive images
        var overlapHeights: [Int] = []
        for i in 0..<(images.count - 1) {
            let overlap = await findOverlapHeight(
                topImage: images[i],
                bottomImage: images[i + 1]
            )
            overlapHeights.append(overlap)
        }
        
        // Calculate total height and page breaks
        var totalHeight: CGFloat = 0
        var pageBreaks: [CGFloat] = []
        let originalHeights = images.map { $0.size.height }
        
        for (index, image) in images.enumerated() {
            if index == 0 {
                totalHeight += image.size.height
            } else {
                let overlap = CGFloat(overlapHeights[index - 1])
                pageBreaks.append(totalHeight)
                totalHeight += image.size.height - overlap
            }
        }
        
        // Use the width of the first image
        let width = images[0].size.width
        
        // Create the stitched image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))
        
        let stitchedImage = renderer.image { context in
            var yOffset: CGFloat = 0
            
            for (index, image) in images.enumerated() {
                if index == 0 {
                    // Draw first image fully
                    image.draw(at: CGPoint(x: 0, y: yOffset))
                    yOffset += image.size.height
                } else {
                    // Skip the overlapping portion at the top
                    let overlap = CGFloat(overlapHeights[index - 1])
                    let cropRect = CGRect(
                        x: 0,
                        y: overlap,
                        width: image.size.width,
                        height: image.size.height - overlap
                    )
                    
                    if let cgImage = image.cgImage,
                       let croppedCGImage = cgImage.cropping(to: cropRect) {
                        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
                        croppedImage.draw(at: CGPoint(x: 0, y: yOffset))
                        yOffset += croppedImage.size.height
                    }
                }
            }
        }
        
        return StitchedImageResult(
            image: stitchedImage,
            pageBreaks: pageBreaks,
            originalHeights: originalHeights,
            overlapHeights: overlapHeights
        )
    }
    #endif
    
    #if canImport(AppKit)
    /// Stitch multiple NSImages into one vertical image, removing overlaps
    func stitch(images: [NSImage]) async -> StitchedImageResult {
        guard !images.isEmpty else {
            return StitchedImageResult(
                image: NSImage(),
                pageBreaks: [],
                originalHeights: [],
                overlapHeights: []
            )
        }
        
        guard images.count > 1 else {
            return StitchedImageResult(
                image: images[0],
                pageBreaks: [],
                originalHeights: [images[0].size.height],
                overlapHeights: []
            )
        }
        
        // Calculate overlaps between consecutive images
        var overlapHeights: [Int] = []
        for i in 0..<(images.count - 1) {
            let overlap = await findOverlapHeight(
                topImage: images[i],
                bottomImage: images[i + 1]
            )
            overlapHeights.append(overlap)
        }
        
        // Calculate total height and page breaks
        var totalHeight: CGFloat = 0
        var pageBreaks: [CGFloat] = []
        let originalHeights = images.map { $0.size.height }
        
        for (index, image) in images.enumerated() {
            if index == 0 {
                totalHeight += image.size.height
            } else {
                let overlap = CGFloat(overlapHeights[index - 1])
                pageBreaks.append(totalHeight)
                totalHeight += image.size.height - overlap
            }
        }
        
        let width = images[0].size.width
        
        // Create the stitched image
        let stitchedImage = NSImage(size: NSSize(width: width, height: totalHeight))
        stitchedImage.lockFocus()
        
        var yOffset: CGFloat = totalHeight // Start from top (NSImage coordinates are flipped)
        
        for (index, image) in images.enumerated() {
            if index == 0 {
                yOffset -= image.size.height
                image.draw(at: NSPoint(x: 0, y: yOffset), from: .zero, operation: .copy, fraction: 1.0)
            } else {
                let overlap = CGFloat(overlapHeights[index - 1])
                let drawHeight = image.size.height - overlap
                yOffset -= drawHeight
                
                let sourceRect = NSRect(x: 0, y: 0, width: image.size.width, height: drawHeight)
                let destRect = NSRect(x: 0, y: yOffset, width: image.size.width, height: drawHeight)
                image.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
            }
        }
        
        stitchedImage.unlockFocus()
        
        return StitchedImageResult(
            image: stitchedImage,
            pageBreaks: pageBreaks,
            originalHeights: originalHeights,
            overlapHeights: overlapHeights
        )
    }
    #endif
    
    // MARK: - Private Methods
    
    #if canImport(UIKit)
    /// Find the overlap height between two vertically adjacent images
    private func findOverlapHeight(topImage: UIImage, bottomImage: UIImage) async -> Int {
        guard let topCG = topImage.cgImage,
              let bottomCG = bottomImage.cgImage else {
            return 0
        }
        
        return await findOverlapHeight(topCG: topCG, bottomCG: bottomCG)
    }
    #endif
    
    #if canImport(AppKit)
    /// Find the overlap height between two vertically adjacent images
    private func findOverlapHeight(topImage: NSImage, bottomImage: NSImage) async -> Int {
        guard let topCG = topImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let bottomCG = bottomImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        
        return await findOverlapHeight(topCG: topCG, bottomCG: bottomCG)
    }
    #endif
    
    /// Core overlap detection. The CPU-heavy pixel scan (and the full-image
    /// pixel-buffer allocation it needs) runs off the main actor so large
    /// screenshots don't stall the UI; only the Sendable `Configuration` and the
    /// (Sendable) CGImages are captured across the boundary.
    private func findOverlapHeight(topCG: CGImage, bottomCG: CGImage) async -> Int {
        let config = configuration
        return await Task.detached(priority: .userInitiated) {
            Self.computeOverlapHeight(topCG: topCG, bottomCG: bottomCG, configuration: config)
        }.value
    }

    nonisolated private static func computeOverlapHeight(
        topCG: CGImage,
        bottomCG: CGImage,
        configuration: Configuration
    ) -> Int {
        let topHeight = topCG.height
        let bottomHeight = bottomCG.height
        let width = min(topCG.width, bottomCG.width)

        // Calculate the center strip to compare
        let stripStart = Int(CGFloat(width) * (1.0 - configuration.comparisonStripWidthRatio) / 2.0)
        let stripEnd = Int(CGFloat(width) * (1.0 + configuration.comparisonStripWidthRatio) / 2.0)

        // Get pixel data for both images, along with each buffer's true stride.
        guard let top = getPixelData(from: topCG),
              let bottom = getPixelData(from: bottomCG) else {
            return 0
        }

        let topData = top.bytes
        let bottomData = bottom.bytes
        let bytesPerPixel = 4
        // Use the stride of the buffer we actually rendered (tightly packed,
        // 4 * width), NOT the source CGImage's `bytesPerRow`, which may include
        // row padding and would mis-index this buffer.
        let topBytesPerRow = top.bytesPerRow
        let bottomBytesPerRow = bottom.bytesPerRow

        var bestOverlap = 0
        var bestSimilarity: Float = 0

        // Search for the best overlap
        let maxOverlap = min(configuration.maxOverlapPixels, min(topHeight, bottomHeight) / 2)

        for overlap in stride(from: configuration.minOverlapPixels, to: maxOverlap, by: configuration.rowSampleInterval) {
            var matchingPixels = 0
            var totalPixels = 0

            // Compare rows
            for row in stride(from: 0, to: overlap, by: configuration.rowSampleInterval) {
                let topRow = topHeight - overlap + row
                let bottomRow = row

                for col in stride(from: stripStart, to: stripEnd, by: 2) {
                    let topOffset = topRow * topBytesPerRow + col * bytesPerPixel
                    let bottomOffset = bottomRow * bottomBytesPerRow + col * bytesPerPixel

                    guard topOffset + 2 < topData.count,
                          bottomOffset + 2 < bottomData.count else {
                        continue
                    }

                    // Compare RGB values (ignore alpha)
                    let rDiff = abs(Int(topData[topOffset]) - Int(bottomData[bottomOffset]))
                    let gDiff = abs(Int(topData[topOffset + 1]) - Int(bottomData[bottomOffset + 1]))
                    let bDiff = abs(Int(topData[topOffset + 2]) - Int(bottomData[bottomOffset + 2]))

                    // Consider pixels matching if color difference is small
                    if rDiff < 30 && gDiff < 30 && bDiff < 30 {
                        matchingPixels += 1
                    }
                    totalPixels += 1
                }
            }

            guard totalPixels > 0 else { continue }

            let similarity = Float(matchingPixels) / Float(totalPixels)

            if similarity > bestSimilarity && similarity >= configuration.similarityThreshold {
                bestSimilarity = similarity
                bestOverlap = overlap
            }
        }

        return bestOverlap
    }

    /// Extract raw pixel data from a CGImage, returning both the tightly-packed
    /// RGBA buffer and the exact stride (`bytesPerRow`) it was rendered with so
    /// callers index rows correctly regardless of the source image's padding.
    nonisolated private static func getPixelData(from image: CGImage) -> (bytes: [UInt8], bytesPerRow: Int)? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixelData,
                  width: width,
                  height: height,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return (bytes: pixelData, bytesPerRow: bytesPerRow)
    }
}
