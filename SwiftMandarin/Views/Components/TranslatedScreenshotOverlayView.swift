//
//  TranslatedScreenshotOverlayView.swift
//  SwiftMandarin
//
//  Full-screen overlay view for displaying translated screenshot content
//  Shows all translated text in reading order with scrollable interface
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Main overlay view for translated screenshot content
struct TranslatedScreenshotOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScreenshotTranslationStore.self) private var store
    
    /// Show original text alongside translations
    @State private var showOriginalText = false
    
    /// Show the stitched image preview
    @State private var showImagePreview = false
    
    /// Text size adjustment
    @State private var textSizeMultiplier: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            Group {
                if store.state.isProcessing {
                    processingView
                } else if store.hasError {
                    errorView
                } else if store.hasContent {
                    contentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Translation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        store.clear()
                        dismiss()
                    }
                }
                
                if store.hasContent {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Toggle(isOn: $showOriginalText) {
                                Label("Show Original Text", systemImage: "text.alignleft")
                            }
                            
                            Toggle(isOn: $showImagePreview) {
                                Label("Show Image Preview", systemImage: "photo")
                            }
                            
                            Divider()
                            
                            Menu {
                                Button("Small") { textSizeMultiplier = 0.85 }
                                Button("Normal") { textSizeMultiplier = 1.0 }
                                Button("Large") { textSizeMultiplier = 1.15 }
                                Button("Extra Large") { textSizeMultiplier = 1.3 }
                            } label: {
                                Label("Text Size", systemImage: "textformat.size")
                            }
                            
                            Divider()
                            
                            Button {
                                copyAllText()
                            } label: {
                                Label("Copy All Text", systemImage: "doc.on.doc")
                            }
                            
                            Button {
                                speakText()
                            } label: {
                                Label("Read Aloud", systemImage: "speaker.wave.2")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Stats header
                statsHeader
                
                // Optional image preview
                if showImagePreview, let stitched = store.stitchedResult {
                    imagePreviewSection(stitched)
                }
                
                // Translated text blocks
                if let blocks = store.translatedBlocks {
                    ForEach(blocks) { block in
                        TranslatedBlockCard(
                            block: block,
                            showOriginal: showOriginalText,
                            textSizeMultiplier: textSizeMultiplier
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var statsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Translated Content")
                    .font(.headline)
                
                if let blocks = store.translatedBlocks {
                    Text("\(blocks.count) text blocks • \(store.fullTranslatedText.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Target language badge
            Text(store.targetLanguage.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.15))
                )
                .foregroundStyle(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private func imagePreviewSection(_ stitched: StitchedImageResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stitched Image")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !stitched.overlapHeights.isEmpty {
                    Text("\(stitched.overlapHeights.count) overlaps removed")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            #if canImport(UIKit)
            Image(uiImage: stitched.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            #endif
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            
            VStack(spacing: 8) {
                Text(store.state.statusMessage)
                    .font(.headline)
                
                Text(processingDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var processingDescription: String {
        switch store.state {
        case .stitching:
            return "Combining screenshots and removing overlapping regions..."
        case .recognizingText:
            return "Extracting text from the combined image..."
        case .translating:
            return "Translating to \(store.targetLanguage.displayName)..."
        default:
            return ""
        }
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        ContentUnavailableView {
            Label("Translation Failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(store.errorMessage ?? "An unknown error occurred")
        } actions: {
            Button("Try Again") {
                Task {
                    store.reset()
                    await store.processScreenshots()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Content", systemImage: "doc.text.image")
        } description: {
            Text("Select screenshots to translate using the Shortcuts app or share sheet")
        }
    }
    
    // MARK: - Actions
    
    private func copyAllText() {
        let text = showOriginalText
            ? store.translatedBlocks?.map { "\($0.originalText)\n→ \($0.translatedText)" }.joined(separator: "\n\n") ?? ""
            : store.fullTranslatedText
        
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
    
    private func speakText() {
        // Voice follows the translated text's actual language (the target
        // language can be either, depending on the user's native language).
        SpeechService.speakAuto(store.fullTranslatedText)
    }
}

// MARK: - Translated Block Card

struct TranslatedBlockCard: View {
    let block: TranslatedTextBlock
    let showOriginal: Bool
    let textSizeMultiplier: CGFloat
    
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original text (if enabled)
            if showOriginal {
                Text(block.originalText)
                    .font(.system(size: 14 * textSizeMultiplier))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                Divider()
            }
            
            // Translated text
            Text(block.translatedText)
                .font(.system(size: 16 * textSizeMultiplier))
                .textSelection(.enabled)
            
            // Actions
            HStack {
                // Confidence indicator
                if block.confidence < 0.8 {
                    Label("Low confidence", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                // Copy button
                Button {
                    copyBlock()
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
    
    private func copyBlock() {
        let text = showOriginal
            ? "\(block.originalText)\n→ \(block.translatedText)"
            : block.translatedText
        
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        
        isCopied = true
        
        // Reset after a delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }
}

// MARK: - Preview

#Preview {
    TranslatedScreenshotOverlayView()
        .environment(ScreenshotTranslationStore.shared)
}
