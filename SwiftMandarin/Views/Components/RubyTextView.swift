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

    /// Build a segment from an AI-identified word. The model supplies the word
    /// boundary, pinyin, part of speech, and an English meaning. Pinyin falls
    /// back to the local converter if the model omitted it; the meaning is kept
    /// in `translation` so the detail popover can show it without a re-lookup.
    init(aiWord: IdentifiedWord) {
        self.text = aiWord.word
        let trimmedPinyin = aiWord.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        self.pinyin = trimmedPinyin.isEmpty ? PinyinConverter.convert(aiWord.word) : trimmedPinyin
        self.partOfSpeech = PartOfSpeech(aiLabel: aiWord.partOfSpeech)
        let trimmedMeaning = aiWord.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        self.translation = trimmedMeaning.isEmpty ? nil : trimmedMeaning
    }
    
    /// Check if segment is valid for display (has actual content)
    var isValidForDisplay: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Whether this segment is punctuation (should be displayed inline without ruby annotation)
    var isPunctuation: Bool {
        partOfSpeech.isPunctuation || 
        (!text.contains(where: { $0.isChineseCharacter || $0.isLetter }))
    }
}

/// Interactive ruby text view that displays Chinese characters with pinyin above
/// Tapping on a word/character shows a popup with details
struct RubyTextView: View {
    let chineseText: String
    let englishMeaning: String
    /// Pre-computed segments from the AI. When non-empty these are used
    /// verbatim (proper word boundaries, pinyin, meaning); when nil/empty the
    /// view falls back to local NLTokenizer segmentation.
    let aiSegments: [RubySegment]?
    let onWordTap: ((RubySegment) -> Void)?

    @State private var segments: [RubySegment] = []

    init(chineseText: String, englishMeaning: String = "", aiSegments: [RubySegment]? = nil, onWordTap: ((RubySegment) -> Void)? = nil) {
        self.chineseText = chineseText
        self.englishMeaning = englishMeaning
        self.aiSegments = aiSegments
        self.onWordTap = onWordTap
    }

    /// Stable, Equatable token so `onChange` re-segments when AI results arrive
    /// asynchronously even though `chineseText` itself hasn't changed.
    private var aiSegmentsToken: String {
        (aiSegments ?? []).map(\.text).joined(separator: "\u{1F}")
    }

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(segments.filter { $0.isValidForDisplay }) { segment in
                if segment.isPunctuation {
                    // Display punctuation inline without ruby annotation
                    PunctuationView(text: segment.text)
                } else {
                    RubyWordView(segment: segment) {
                        onWordTap?(segment)
                    }
                }
            }
        }
        .onAppear {
            updateSegments()
        }
        .onChange(of: chineseText) { _, _ in
            updateSegments()
        }
        .onChange(of: aiSegmentsToken) { _, _ in
            updateSegments()
        }
    }

    private func updateSegments() {
        // Prefer AI-identified word boundaries when available; otherwise fall
        // back to local segmentation.
        if let aiSegments, !aiSegments.isEmpty {
            segments = aiSegments
        } else {
            let analyzed = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(chineseText)
            segments = analyzed.map { RubySegment(from: $0) }
        }
    }
}

/// Inline punctuation display (no ruby annotation)
/// Aligns with the baseline of Chinese characters by adding a ghost line
/// matching wherever the pinyin row sits in regular RubyWordViews.
struct PunctuationView: View {
    let text: String

    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"

    var body: some View {
        VStack(spacing: 2) {
            if showPinyin && pinyinPosition == "above" {
                ghostPinyinLine
            }

            // Punctuation aligned with Chinese characters
            Text(text)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            if showPinyin && pinyinPosition == "below" {
                ghostPinyinLine
            }
        }
        .padding(.vertical, 4)
    }

    /// Empty space matching the pinyin line height in RubyWordView.
    private var ghostPinyinLine: some View {
        Text(" ")
            .font(.caption)
            .opacity(0)
    }
}

/// Individual word with pinyin rendered around the character(s) according to
/// the user's Appearance settings (show/hide, above/below/inline, tone colors).
struct RubyWordView: View {
    let segment: RubySegment
    let action: () -> Void

    @State private var isHovered: Bool = false

    @AppStorage("showPinyin") private var showPinyin: Bool = true
    @AppStorage("pinyinPosition") private var pinyinPosition: String = "above"
    @AppStorage("toneColors") private var toneColors: Bool = true

    var body: some View {
        Button(action: action) {
            wordLayout
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

    @ViewBuilder
    private var wordLayout: some View {
        if !showPinyin {
            characterText
        } else {
            switch pinyinPosition {
            case "below":
                VStack(spacing: 2) {
                    characterText
                    pinyinText
                }
            case "inline":
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    characterText
                    pinyinText
                }
            default:  // "above"
                VStack(spacing: 2) {
                    pinyinText
                    characterText
                }
            }
        }
    }

    private var pinyinText: some View {
        Text(segment.pinyin)
            .font(.caption)
            .foregroundStyle(toneColors ? pinyinColor : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var characterText: some View {
        Text(segment.text)
            .font(.title2)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
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
/// Always displays: Chinese word, pinyin, and English definition
/// Handles both Chinese and English input words
struct WordDetailPopover: View {
    let segment: RubySegment
    let contextTranslation: String  // Full sentence translation for context
    let onSave: (String) -> Void    // Pass the word definition when saving
    let onCopy: () -> Void
    let onDismiss: () -> Void
    
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var prefs = AppPreferences.shared
    @State private var showCopiedFeedback: Bool = false
    @State private var englishDefinition: String = ""
    @State private var chineseWord: String = ""
    @State private var pinyinText: String = ""
    @State private var isLoadingTranslation: Bool = true
    @State private var translationError: String?
    
    /// Check if the segment text contains Chinese characters
    private var segmentIsChinese: Bool {
        segment.text.contains { $0.isChineseCharacter }
    }

    /// The learning-language side leads (中文 UI → English headline, Chinese
    /// gloss, English narration first; English UI → Chinese headline with
    /// pinyin, English gloss, Mandarin narration first).
    private var learningChinese: Bool { LocalizationManager.shared.learningIsChinese }

    /// The learning-language text — what gets the headline, primary
    /// narration, and the plain Copy button.
    private var headlineWord: String { learningChinese ? chineseWord : englishDefinition }

    private var isSaved: Bool {
        savedTermsStore.contains(chinese: chineseWord.isEmpty ? segment.text : chineseWord)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Large display — the learning-language side of the word
            VStack(spacing: 4) {
                if isLoadingTranslation {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    if learningChinese {
                        Text(pinyinText)
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text(chineseWord)
                            .font(.system(size: 56, weight: .medium))
                    } else {
                        Text(englishDefinition)
                            .font(.system(size: 40, weight: .medium))
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                            .multilineTextAlignment(.center)
                    }

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
            }

            Divider()

            // Definition section — the native-language gloss
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
                    Text(learningChinese ? englishDefinition : chineseWord)
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)

            Divider()

            // Action buttons — learning-language narration first
            HStack(spacing: 12) {
                if learningChinese {
                    Button {
                        SpeechService.speakChinese(chineseWord)
                    } label: {
                        Label("中文", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingTranslation || chineseWord.isEmpty)

                    // Native-language narration (dual narration).
                    if prefs.dualNarration {
                        Button {
                            SpeechService.speakEnglish(englishDefinition)
                        } label: {
                            Label("EN", systemImage: "speaker.wave.2")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoadingTranslation || englishDefinition.isEmpty)
                    }
                } else {
                    Button {
                        SpeechService.speakEnglish(englishDefinition)
                    } label: {
                        Label("EN", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingTranslation || englishDefinition.isEmpty)

                    if prefs.dualNarration {
                        Button {
                            SpeechService.speakChinese(chineseWord)
                        } label: {
                            Label("中文", systemImage: "speaker.wave.2")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoadingTranslation || chineseWord.isEmpty)
                    }
                }

                Button {
                    ClipboardService.copy(headlineWord)
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
                .disabled(isLoadingTranslation || headlineWord.isEmpty)
                
                Button {
                    // Pass the word-specific translation when saving
                    let definition = englishDefinition.isEmpty ? contextTranslation : englishDefinition
                    onSave(definition)
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.bordered)
                .tint(isSaved ? .green : nil)
                .disabled(isLoadingTranslation || isSaved)
            }
            
            // Copy-everything button (pinyin included only when the user is
            // learning Chinese — it is a learner aid, not native furniture)
            Button {
                let definition = englishDefinition.isEmpty ? contextTranslation : englishDefinition
                let fullText = learningChinese
                    ? "\(chineseWord) (\(pinyinText))\n\(definition)"
                    : "\(englishDefinition)\n\(chineseWord)"
                ClipboardService.copy(fullText)
                showCopiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopiedFeedback = false
                }
            } label: {
                Label(learningChinese ? "Copy with Pinyin" : "Copy All", systemImage: "doc.on.doc.fill")
                    .fitSingleLine()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingTranslation)
        }
        .padding()
        .frame(minWidth: 280)
        .task {
            await fetchWordDetails()
        }
    }
    
    /// Fetch the translation details for this word
    /// Always produces: Chinese word, pinyin, and English definition
    private func fetchWordDetails() async {
        isLoadingTranslation = true
        translationError = nil
        
        do {
            if segmentIsChinese {
                // Input is Chinese: use as-is for Chinese, translate to English for definition
                chineseWord = segment.text
                pinyinText = segment.pinyin

                // Prefer the AI-identified meaning (already contextual) so the
                // popover opens instantly without a second translation call.
                if let aiMeaning = segment.translation, !aiMeaning.isEmpty {
                    englishDefinition = aiMeaning
                } else {
                    let translation = try await WordTranslationService.shared.translateToEnglish(segment.text)
                    englishDefinition = translation
                }
            } else {
                // Input is English: translate to Chinese, get pinyin, use original as definition
                englishDefinition = segment.text
                
                let chineseTranslation = try await WordTranslationService.shared.translateToChinese(segment.text)
                chineseWord = chineseTranslation
                pinyinText = PinyinConverter.convert(chineseTranslation)
            }
            
            await MainActor.run {
                isLoadingTranslation = false
            }
        } catch {
            await MainActor.run {
                // If translation fails, use what we have
                translationError = "Could not translate word"
                if segmentIsChinese {
                    chineseWord = segment.text
                    pinyinText = segment.pinyin
                    englishDefinition = contextTranslation
                } else {
                    englishDefinition = segment.text
                    chineseWord = contextTranslation.isEmpty ? segment.text : contextTranslation
                    pinyinText = PinyinConverter.convert(chineseWord)
                }
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
