//
//  RubyTextView.swift
//  SwiftMandarin
//
//  Ruby text display for Chinese characters with pinyin annotations
//  Displays pinyin directly above each character/word segment
//

import SwiftUI

/// A word segment with its pinyin displayed above the character
struct RubySegment: Identifiable {
    let id = UUID()
    let text: String
    let pinyin: String
    let partOfSpeech: PartOfSpeech
    
    /// Translated meaning (fetched asynchronously)
    var translation: String?
    
    init(from analyzedWord: AnalyzedWord) {
        self.text = analyzedWord.text
        self.pinyin = PinyinConverter.convert(analyzedWord.text)
        self.partOfSpeech = analyzedWord.partOfSpeech
        self.translation = nil
    }
    
    /// Check if segment is valid for display (has actual content)
    var isValidForDisplay: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.contains(where: { $0.isChineseCharacter || $0.isLetter })
    }
}

/// Interactive ruby text view that displays Chinese characters with pinyin above
/// Tapping on a word/character shows a popup with details
struct RubyTextView: View {
    let chineseText: String
    let englishMeaning: String
    let onWordTap: ((RubySegment) -> Void)?
    
    @State private var segments: [RubySegment] = []
    
    init(chineseText: String, englishMeaning: String = "", onWordTap: ((RubySegment) -> Void)? = nil) {
        self.chineseText = chineseText
        self.englishMeaning = englishMeaning
        self.onWordTap = onWordTap
    }
    
    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(segments.filter { $0.isValidForDisplay }) { segment in
                RubyWordView(segment: segment) {
                    onWordTap?(segment)
                }
            }
        }
        .onAppear {
            updateSegments()
        }
        .onChange(of: chineseText) { _, _ in
            updateSegments()
        }
    }
    
    private func updateSegments() {
        let analyzed = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(chineseText)
        segments = analyzed.map { RubySegment(from: $0) }
    }
}

/// Individual word with pinyin above the character(s)
struct RubyWordView: View {
    let segment: RubySegment
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                // Pinyin above
                Text(segment.pinyin)
                    .font(.caption)
                    .foregroundStyle(pinyinColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                // Chinese character(s) below
                Text(segment.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(segment.partOfSpeech.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    /// Color for pinyin based on tone
    private var pinyinColor: Color {
        // Get the first tone mark to determine color
        let pinyin = segment.pinyin.lowercased()
        
        if pinyin.contains("ā") || pinyin.contains("ē") || pinyin.contains("ī") || pinyin.contains("ō") || pinyin.contains("ū") || pinyin.contains("ǖ") {
            return .red // First tone
        } else if pinyin.contains("á") || pinyin.contains("é") || pinyin.contains("í") || pinyin.contains("ó") || pinyin.contains("ú") || pinyin.contains("ǘ") {
            return .orange // Second tone
        } else if pinyin.contains("ǎ") || pinyin.contains("ě") || pinyin.contains("ǐ") || pinyin.contains("ǒ") || pinyin.contains("ǔ") || pinyin.contains("ǚ") {
            return .green // Third tone
        } else if pinyin.contains("à") || pinyin.contains("è") || pinyin.contains("ì") || pinyin.contains("ò") || pinyin.contains("ù") || pinyin.contains("ǜ") {
            return .blue // Fourth tone
        } else {
            return .secondary // Neutral tone
        }
    }
}

/// Detailed popup view for a selected word
/// Fetches the actual translation of the word using Translation API
struct WordDetailPopover: View {
    let segment: RubySegment
    let contextTranslation: String  // Full sentence translation for context
    let onSave: (String) -> Void    // Pass the word definition when saving
    let onCopy: () -> Void
    let onDismiss: () -> Void
    
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var showCopiedFeedback: Bool = false
    @State private var wordTranslation: String = ""
    @State private var isLoadingTranslation: Bool = true
    @State private var translationError: String?
    
    private var isSaved: Bool {
        savedTermsStore.contains(chinese: segment.text)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Large character display
            VStack(spacing: 4) {
                Text(segment.pinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text(segment.text)
                    .font(.system(size: 56, weight: .medium))
                
                // Part of speech badge
                Text(segment.partOfSpeech.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(segment.partOfSpeech.color)
                    )
            }
            
            Divider()
            
            // Definition section - shows actual word translation
            VStack(alignment: .leading, spacing: 8) {
                Text("Definition")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                if isLoadingTranslation {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Translating...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let error = translationError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                        
                        // Fallback to context if available
                        if !contextTranslation.isEmpty {
                            Text("Context: \(contextTranslation)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(wordTranslation)
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Action buttons
            HStack(spacing: 16) {
                Button {
                    SpeechService.speakChinese(segment.text)
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
                
                Button {
                    ClipboardService.copy(segment.text)
                    showCopiedFeedback = true
                    onCopy()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedFeedback = false
                    }
                } label: {
                    Label(showCopiedFeedback ? "Copied!" : "Copy", systemImage: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .tint(showCopiedFeedback ? .green : nil)
                
                Button {
                    // Pass the word-specific translation when saving
                    let definition = wordTranslation.isEmpty ? contextTranslation : wordTranslation
                    onSave(definition)
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)
                .tint(isSaved ? .green : nil)
                .disabled(isLoadingTranslation)
            }
            
            // Copy with pinyin button
            Button {
                let definition = wordTranslation.isEmpty ? contextTranslation : wordTranslation
                let fullText = "\(segment.text) (\(segment.pinyin))\n\(definition)"
                ClipboardService.copy(fullText)
                showCopiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopiedFeedback = false
                }
            } label: {
                Label("Copy with Pinyin", systemImage: "doc.on.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingTranslation)
        }
        .padding()
        .frame(minWidth: 280)
        .task {
            await fetchWordTranslation()
        }
    }
    
    /// Fetch the translation for this specific word using Translation API
    private func fetchWordTranslation() async {
        isLoadingTranslation = true
        translationError = nil
        
        do {
            // Translate the specific word from Chinese to English
            let translation = try await WordTranslationService.shared.translateToEnglish(segment.text)
            
            await MainActor.run {
                wordTranslation = translation
                isLoadingTranslation = false
            }
        } catch {
            await MainActor.run {
                // If translation fails, use context as fallback
                translationError = "Could not translate word"
                wordTranslation = contextTranslation
                isLoadingTranslation = false
            }
            print("Word translation error for '\(segment.text)': \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        RubyTextView(
            chineseText: "你好世界",
            englishMeaning: "Hello World"
        ) { segment in
            print("Tapped: \(segment.text)")
        }
        
        RubyTextView(
            chineseText: "我喜欢学习中文",
            englishMeaning: "I like to study Chinese"
        )
    }
    .padding()
    .environment(SavedTermsStore.shared)
}
