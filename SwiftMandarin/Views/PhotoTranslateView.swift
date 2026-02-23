//
//  PhotoTranslateView.swift
//  SwiftMandarin
//
//  Photo translation view for scanning and translating text
//  Supports both English → Chinese and Chinese → English translation
//

import SwiftUI
import PhotosUI
import Translation
import NaturalLanguage

// MARK: - DetectedLanguage Extension for Photo Translation UI

extension DetectedLanguage {
    /// Display name for UI
    var displayName: String {
        switch self {
        case .english: return "英文"
        case .chinese: return "中文"
        case .unknown, .other: return "未知"
        }
    }
    
    /// Icon for language badge
    var icon: String {
        switch self {
        case .english: return "e.circle.fill"
        case .chinese: return "character.textbox"
        case .unknown, .other: return "questionmark.circle"
        }
    }
}

/// Main view for photo-based translation
struct PhotoTranslateView: View {
    @Environment(SavedTermsStore.self) private var savedTermsStore
    
    // State
    @State private var sourceText: String = ""
    @State private var cleanedChineseText: String = ""             // Cleaned Chinese text for RubyTextView
    @State private var analyzedSentences: [AnalyzedSentence] = []  // For English text
    @State private var chineseTranslation: String = ""             // Full Chinese → English translation
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var detectedLanguage: DetectedLanguage = .unknown
    
    // Photo picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
    // Camera scanner
    @State private var showCameraScanner: Bool = false
    @State private var capturedText: String = ""
    
    // Word detail - English
    @State private var selectedEnglishWord: AnalyzedEnglishWord?
    // Word detail - Chinese (using RubySegment)
    @State private var selectedChineseSegment: RubySegment?
    
    // Translation
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var isTranslating: Bool = false
    
    // Settings
    @State private var showGrammarPoints: Bool = true
    
    /// Check if we have any results to display
    private var hasResults: Bool {
        !analyzedSentences.isEmpty || !cleanedChineseText.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Input section
                    inputSection
                    
                    // Results section - show based on detected language
                    if hasResults {
                        resultsSection
                    } else if isProcessing {
                        processingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("拍照翻译")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if detectedLanguage == .english {
                            Toggle("显示语法知识点", isOn: $showGrammarPoints)
                            Divider()
                        }
                        
                        Button(role: .destructive) {
                            clearAll()
                        } label: {
                            Label("清除内容", systemImage: "trash")
                        }
                        .disabled(sourceText.isEmpty && !hasResults)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showCameraScanner) {
                CameraScannerSheet(capturedText: $capturedText)
            }
            .sheet(item: $selectedEnglishWord) { word in
                EnglishWordDetailSheet(word: word)
            }
            .sheet(item: $selectedChineseSegment) { segment in
                WordDetailPopover(
                    segment: segment,
                    contextTranslation: chineseTranslation,
                    onSave: { definition in
                        saveChineseWord(segment, definition: definition)
                    },
                    onCopy: { },
                    onDismiss: { selectedChineseSegment = nil }
                )
            }
            .onChange(of: capturedText) { _, newValue in
                if !newValue.isEmpty {
                    sourceText = newValue
                    Task {
                        await processText(newValue)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    await loadAndProcessImage(newValue)
                }
            }
            .translationTask(translationConfiguration) { session in
                await translateSentences(session: session)
            }
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 16) {
            // Input buttons
            HStack(spacing: 12) {
                #if os(iOS)
                // Camera button - only show if device supports scanning
                if CameraScannerView.isSupported {
                    Button {
                        showCameraScanner = true
                    } label: {
                        Label("相机扫描", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!CameraScannerView.isAvailable)
                }
                #endif
                
                // Photo picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("选择图片", systemImage: "photo.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            // Text input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("输入中文或英文文本")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Show detected language
                    if detectedLanguage != .unknown {
                        Label(detectedLanguage.displayName, systemImage: detectedLanguage.icon)
                            .font(.caption)
                            .foregroundStyle(detectedLanguage == .english ? .blue : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(detectedLanguage == .english ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                            )
                    }
                }
                
                TextEditor(text: $sourceText)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(alignment: .topLeading) {
                        if sourceText.isEmpty {
                            Text("输入或粘贴文字内容（支持中英文）...")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    }
                
                HStack {
                    Button {
                        if let pastedText = ClipboardService.paste(), !pastedText.isEmpty {
                            sourceText = pastedText
                        }
                    } label: {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    if !sourceText.isEmpty {
                        Text("\(sourceText.count) 字符")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        Task {
                            await processText(sourceText)
                        }
                    } label: {
                        Label("分析翻译", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(sourceText.isEmpty || isProcessing)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            // Show different results based on detected language
            if detectedLanguage == .english {
                englishResultsSection
            } else if detectedLanguage == .chinese {
                chineseResultsSection
            }
        }
    }
    
    /// Results section for English text (English → Chinese)
    private var englishResultsSection: some View {
        VStack(spacing: 16) {
            // Summary
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text("分析结果")
                            .font(.headline)
                        Label("英文→中文", systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    Text("\(analyzedSentences.count) 个句子, \(totalEnglishWordCount) 个单词")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    triggerTranslation()
                } label: {
                    Label(isTranslating ? "翻译中..." : "翻译全部", systemImage: "translate")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTranslating)
            }
            
            // Sentences
            ForEach(Array(analyzedSentences.enumerated()), id: \.element.id) { index, sentence in
                SentenceCard(
                    sentence: sentence,
                    showGrammarPoints: showGrammarPoints,
                    onWordTap: { word in
                        selectedEnglishWord = word
                    }
                )
            }
            
            // Save all words button
            Button {
                saveAllEnglishWordsToVocabulary()
            } label: {
                Label("保存所有单词到词汇本", systemImage: "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    /// Results section for Chinese text (Chinese → English)
    private var chineseResultsSection: some View {
        VStack(spacing: 16) {
            // Summary
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text("分析结果")
                            .font(.headline)
                        Label("中文→英文", systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("\(cleanedChineseText.count) 个字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    triggerChineseTranslation()
                } label: {
                    Label(isTranslating ? "翻译中..." : "翻译全部", systemImage: "translate")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTranslating)
            }
            
            // Full translation card
            if !chineseTranslation.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("英文翻译")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(chineseTranslation)
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Button {
                        SpeechService.speakEnglish(chineseTranslation)
                    } label: {
                        Label("朗读英文", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            
            // Word-by-word analysis using existing RubyTextView
            VStack(alignment: .leading, spacing: 12) {
                Text("逐词分析")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                RubyTextView(
                    chineseText: cleanedChineseText,
                    englishMeaning: chineseTranslation,
                    onWordTap: { segment in
                        selectedChineseSegment = segment
                    }
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            
            // Save all words button
            Button {
                saveAllChineseWordsToVocabulary()
            } label: {
                Label("保存所有词汇到词汇本", systemImage: "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Helper Views
    
    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("正在处理...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("处理失败", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Button("重试") {
                Task {
                    await processText(sourceText)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("拍照翻译", systemImage: "camera.viewfinder")
        } description: {
            Text("拍摄或选择图片，自动识别文字并翻译\n支持中文↔英文双向翻译")
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Computed Properties
    
    private var totalEnglishWordCount: Int {
        analyzedSentences.reduce(0) { $0 + $1.words.count }
    }
    
    // MARK: - Actions
    
    private func loadAndProcessImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw RecognitionError.invalidImage
            }
            
            selectedImageData = data
            let result = try await PhotoTextRecognitionService.shared.recognizeText(from: data)
            
            await MainActor.run {
                // Show cleaned text (with line breaks removed) for better readability
                sourceText = result.cleanedText
            }
            
            // Process the cleaned text for proper sentence detection
            await processText(result.cleanedText)
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
    
    private func processText(_ text: String) async {
        guard !text.isEmpty else { return }
        
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            // Clear previous results
            analyzedSentences = []
            cleanedChineseText = ""
            chineseTranslation = ""
        }
        
        // Clean the text first to handle any line breaks from manual input
        let cleanedText = cleanTextForProcessing(text)
        
        // Detect language
        let language = detectLanguage(cleanedText)
        
        await MainActor.run {
            detectedLanguage = language
        }
        
        if language == .english {
            // English text - analyze sentences and words
            let sentences = EnglishTextAnalyzer.shared.analyzeSentences(cleanedText)
            await MainActor.run {
                analyzedSentences = sentences
                isProcessing = false
            }
        } else if language == .chinese {
            // Chinese text - store cleaned text for RubyTextView to analyze
            await MainActor.run {
                cleanedChineseText = cleanedText
                isProcessing = false
            }
        } else {
            // Unknown language - try English first
            let sentences = EnglishTextAnalyzer.shared.analyzeSentences(cleanedText)
            await MainActor.run {
                analyzedSentences = sentences
                detectedLanguage = .english
                isProcessing = false
            }
        }
    }
    
    /// Detect the primary language of the text
    private func detectLanguage(_ text: String) -> DetectedLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let dominantLanguage = recognizer.dominantLanguage else {
            return .unknown
        }
        
        switch dominantLanguage {
        case .english:
            return .english
        case .simplifiedChinese, .traditionalChinese:
            return .chinese
        default:
            // Check if it contains significant Chinese characters
            let chineseCharCount = text.unicodeScalars.filter { 
                (0x4E00...0x9FFF).contains($0.value) || // CJK Unified Ideographs
                (0x3400...0x4DBF).contains($0.value)    // CJK Extension A
            }.count
            
            if chineseCharCount > text.count / 3 {
                return .chinese
            }
            return .english
        }
    }
    
    /// Clean text for processing - removes line breaks that split sentences
    private func cleanTextForProcessing(_ text: String) -> String {
        var result = text
        
        // Replace multiple whitespace/newlines with single space
        result = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        // Fix hyphenated words split across lines
        result = result.replacingOccurrences(of: "- ", with: "")
        
        // Ensure proper spacing after punctuation
        result = result.replacingOccurrences(of: "\\.([A-Z])", with: ". $1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\?([A-Z])", with: "? $1", options: .regularExpression)
        result = result.replacingOccurrences(of: "!([A-Z])", with: "! $1", options: .regularExpression)
        
        // Clean up multiple spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Trigger English → Chinese translation
    private func triggerTranslation() {
        guard !analyzedSentences.isEmpty else { return }
        
        if translationConfiguration == nil {
            translationConfiguration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "zh-Hans")
            )
        } else {
            translationConfiguration?.invalidate()
        }
    }
    
    /// Trigger Chinese → English translation
    private func triggerChineseTranslation() {
        guard !cleanedChineseText.isEmpty else { return }
        
        Task {
            await MainActor.run {
                isTranslating = true
            }
            
            do {
                // Translate the full text from Chinese to English
                let translation = try await WordTranslationService.shared.translateToEnglish(cleanedChineseText)
                
                await MainActor.run {
                    chineseTranslation = translation
                }
            } catch {
                await MainActor.run {
                    errorMessage = "翻译失败: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isTranslating = false
            }
        }
    }
    
    private func translateSentences(session: TranslationSession) async {
        await MainActor.run {
            isTranslating = true
        }
        
        do {
            // Capture a snapshot of sentences to translate
            let sentenceCount = await MainActor.run { analyzedSentences.count }
            
            // Translate each sentence
            for i in 0..<sentenceCount {
                // Safely get the sentence text
                let sentenceText = await MainActor.run { 
                    i < analyzedSentences.count ? analyzedSentences[i].text : nil 
                }
                guard let text = sentenceText else { continue }
                
                let response = try await session.translate(text)
                await MainActor.run {
                    if i < analyzedSentences.count {
                        analyzedSentences[i].translation = response.targetText
                    }
                }
            }
            
            // Translate individual words - collect all words first
            var wordTranslations: [(sentenceIndex: Int, wordIndex: Int, translation: String)] = []
            
            for i in 0..<sentenceCount {
                let wordCount = await MainActor.run { 
                    i < analyzedSentences.count ? analyzedSentences[i].words.count : 0 
                }
                
                for j in 0..<wordCount {
                    // Safely get word info
                    let wordInfo = await MainActor.run { () -> (lemma: String, partOfSpeech: EnglishPartOfSpeech)? in
                        guard i < analyzedSentences.count, j < analyzedSentences[i].words.count else { return nil }
                        let word = analyzedSentences[i].words[j]
                        return (word.lemma, word.partOfSpeech)
                    }
                    
                    guard let info = wordInfo else { continue }
                    
                    // Skip common words like "the", "a", "is"
                    if info.partOfSpeech != .determiner && info.partOfSpeech != .particle {
                        let response = try await session.translate(info.lemma)
                        wordTranslations.append((i, j, response.targetText))
                    }
                }
            }
            
            // Apply all word translations at once on main actor
            await MainActor.run {
                for (sentenceIndex, wordIndex, translation) in wordTranslations {
                    if sentenceIndex < analyzedSentences.count,
                       wordIndex < analyzedSentences[sentenceIndex].words.count {
                        analyzedSentences[sentenceIndex].words[wordIndex].translation = translation
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "翻译失败: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isTranslating = false
        }
    }
    
    /// Save all English words from the analysis to vocabulary
    private func saveAllEnglishWordsToVocabulary() {
        for sentence in analyzedSentences {
            for word in sentence.words {
                // Skip common function words
                guard word.partOfSpeech != .determiner,
                      word.partOfSpeech != .particle,
                      word.partOfSpeech != .conjunction else { continue }
                
                let term = SavedTerm(
                    chinese: word.translation ?? word.lemma,
                    pinyin: "",
                    definition: word.text,
                    partOfSpeech: word.partOfSpeech.englishName
                )
                
                if !savedTermsStore.contains(chinese: term.chinese) {
                    savedTermsStore.add(term)
                }
            }
        }
    }
    
    /// Save all Chinese words from the analysis to vocabulary
    private func saveAllChineseWordsToVocabulary() {
        // Analyze the Chinese text to get individual words
        let words = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(cleanedChineseText)
        
        for word in words {
            // Skip punctuation and whitespace
            if word.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            if word.text.unicodeScalars.allSatisfy({ CharacterSet.punctuationCharacters.contains($0) }) {
                continue
            }
            
            let pinyin = PinyinConverter.convert(word.text)
            let term = SavedTerm(
                chinese: word.text,
                pinyin: pinyin,
                definition: chineseTranslation.isEmpty ? word.text : chineseTranslation,
                partOfSpeech: word.partOfSpeech.displayName
            )
            
            if !savedTermsStore.contains(chinese: term.chinese) {
                savedTermsStore.add(term)
            }
        }
    }
    
    /// Save a single Chinese word to vocabulary
    private func saveChineseWord(_ segment: RubySegment, definition: String) {
        let term = SavedTerm(
            chinese: segment.text,
            pinyin: segment.pinyin,
            definition: definition,
            partOfSpeech: segment.partOfSpeech.displayName
        )
        
        if !savedTermsStore.contains(chinese: term.chinese) {
            savedTermsStore.add(term)
        }
    }
    
    private func clearAll() {
        sourceText = ""
        analyzedSentences = []
        cleanedChineseText = ""
        chineseTranslation = ""
        detectedLanguage = .unknown
        selectedPhoto = nil
        selectedImageData = nil
        errorMessage = nil
        translationConfiguration = nil
    }
}

// MARK: - Sentence Card

struct SentenceCard: View {
    let sentence: AnalyzedSentence
    let showGrammarPoints: Bool
    let onWordTap: (AnalyzedEnglishWord) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Sentence type badge
            HStack {
                Label(sentence.type.rawValue, systemImage: sentence.type.icon)
                    .font(.caption)
                    .foregroundStyle(sentenceTypeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(sentenceTypeColor.opacity(0.1))
                    )
                
                Spacer()
                
                Button {
                    SpeechService.speakEnglish(sentence.text)
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Original sentence
            Text(sentence.text)
                .font(.title3)
                .fontWeight(.medium)
            
            // Translation
            if let translation = sentence.translation {
                Text(translation)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Word-by-word analysis
            Text("逐词释义")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            EnglishRubyTextView(
                words: sentence.words,
                showTranslations: true,
                onWordTap: onWordTap
            )
            
            // Grammar points
            if showGrammarPoints && !sentence.grammarPoints.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("语法知识点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(sentence.grammarPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            
                            Text(point)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
    
    private var sentenceTypeColor: Color {
        switch sentence.type {
        case .declarative: return .blue
        case .question: return .orange
        case .exclamation: return .pink
        case .imperative: return .purple
        case .negative: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    PhotoTranslateView()
        .environment(SavedTermsStore.shared)
}
