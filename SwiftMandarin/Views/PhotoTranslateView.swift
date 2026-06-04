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
import UniformTypeIdentifiers

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
    @Environment(AppRouteStore.self) private var routeStore
    
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
    @State private var showPhotoFiles: Bool = false
    
    // Camera scanner
    @State private var showCameraScanner: Bool = false
    @State private var capturedText: String = ""
    
    // Screenshot translation overlay
    @State private var showScreenshotTranslation: Bool = false
    
    // Word detail - English
    @State private var selectedEnglishWord: AnalyzedEnglishWord?
    // Word detail - Chinese (using RubySegment)
    @State private var selectedChineseSegment: RubySegment?
    
    // Translation
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var isTranslating: Bool = false
    
    // Settings
    @State private var showGrammarPoints: Bool = true
    @State private var prefs = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared

    // AI structured vocabulary extraction
    @State private var extractedVocab: [ExtractedVocabItem] = []
    @State private var isExtractingVocab: Bool = false

    // Workbook grading (tucked-away feature)
    @State private var showWorkbookGrading: Bool = false
    
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
                        // Scan language override — the user-facing fix for
                        // "cannot switch languages" in the photo pipeline.
                        Picker("识别语言 · Scan Language", selection: Binding(
                            get: { prefs.photoScanLanguage },
                            set: { prefs.photoScanLanguage = $0 }
                        )) {
                            ForEach(PhotoScanLanguage.allCases) { lang in
                                Label(lang.displayName, systemImage: lang.iconName).tag(lang)
                            }
                        }

                        // AI cleanup toggle (concern C).
                        Toggle("AI 清理识别文字 · AI Cleanup", isOn: Binding(
                            get: { aiSettings.aiPhotoCleanupEnabled },
                            set: { aiSettings.aiPhotoCleanupEnabled = $0 }
                        ))

                        Divider()

                        // Tucked-away workbook grading feature.
                        Button {
                            showWorkbookGrading = true
                        } label: {
                            Label("作业批改 · Grade Workbook", systemImage: "checkmark.rectangle.stack")
                        }

                        Divider()

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
            .sheet(isPresented: $showScreenshotTranslation) {
                TranslatedScreenshotOverlayView()
                    .environment(ScreenshotTranslationStore.shared)
            }
            .sheet(isPresented: $showWorkbookGrading) {
                WorkbookGradingView()
                    .environment(savedTermsStore)
            }
            .fileImporter(isPresented: $showPhotoFiles, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                Task {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else { return }
                    await MainActor.run { selectedImageData = data }
                    await processImageData(data)
                }
            }
            .task(id: routeStore.pendingAction?.id) {
                applyPendingRouteAction()
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
                
                // Photo picker (Photos library)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("照片", systemImage: "photo.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                // File picker (Files app / Finder)
                Button {
                    showPhotoFiles = true
                } label: {
                    Label("文件", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            // Scan-language selector + re-recognize. Lets the user force
            // Chinese/English recognition and re-run OCR on the same image.
            HStack(spacing: 12) {
                Menu {
                    Picker("识别语言", selection: Binding(
                        get: { prefs.photoScanLanguage },
                        set: { prefs.photoScanLanguage = $0 }
                    )) {
                        ForEach(PhotoScanLanguage.allCases) { lang in
                            Label(lang.displayName, systemImage: lang.iconName).tag(lang)
                        }
                    }
                } label: {
                    Label("识别语言: \(prefs.photoScanLanguage.displayName)",
                          systemImage: prefs.photoScanLanguage.iconName)
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                if selectedImageData != nil {
                    Button {
                        Task { await reRecognizeCurrentImage() }
                    } label: {
                        Label("重新识别", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isProcessing)
                }

                if aiSettings.aiPhotoCleanupEnabled {
                    Label("AI", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.purple.opacity(0.12)))
                }
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
        // Drag & drop an image onto the input area to scan it.
        .onDrop(of: [.image], isTargeted: nil, perform: handlePhotoDrop)
    }

    private func handlePhotoDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            return false
        }
        Task {
            guard let data = await PhotoTranslateView.loadDroppedImage(provider) else { return }
            await MainActor.run { selectedImageData = data }
            await processImageData(data)
        }
        return true
    }

    private static func loadDroppedImage(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
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

            // AI structured vocabulary extraction (concern B/C — model API
            // responses linked into the app via structured output).
            aiVocabExtractButton
            aiVocabResultsSection
        }
    }

    /// Button that asks the configured AI provider for structured key vocabulary.
    @ViewBuilder
    private var aiVocabExtractButton: some View {
        if aiSettings.isAnyProviderAvailable {
            Button {
                Task { await extractVocabulary() }
            } label: {
                HStack {
                    if isExtractingVocab { ProgressView().controlSize(.small) }
                    Label(isExtractingVocab ? "AI 提取中…" : "AI 提取重点词汇",
                          systemImage: "sparkles.rectangle.stack")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isExtractingVocab || !hasResults)
        }
    }

    /// Renders the structured vocabulary items returned by the model.
    @ViewBuilder
    private var aiVocabResultsSection: some View {
        if !extractedVocab.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("AI 重点词汇", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("\(extractedVocab.count) 个词")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(extractedVocab) { item in
                    VStack(spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.term)
                                    .font(.body)
                                    .fontWeight(.medium)
                                if !item.reading.isEmpty {
                                    Text(item.reading)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.meaning)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider()
                    }
                }

                Button {
                    saveExtractedVocab()
                } label: {
                    Label("保存全部到词汇本", systemImage: "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
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
                Task {
                    await saveAllChineseWordsToVocabulary()
                }
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

    private func containsChinese(_ text: String) -> Bool {
        text.contains { $0.isChineseCharacter }
    }

    private func applyPendingRouteAction() {
        guard let action = routeStore.pendingAction else { return }
        switch action.kind {
        case .openCameraScanner:
            #if os(iOS)
            showCameraScanner = true
            #endif
        case .translateScreenshots:
            showScreenshotTranslation = true
        default:
            break
        }
        routeStore.clearPendingAction()
    }
    
    // MARK: - Actions
    
    private func loadAndProcessImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw RecognitionError.invalidImage
            }
            await MainActor.run { selectedImageData = data }
            await processImageData(data)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    /// Re-run OCR on the most recently selected image using the current scan
    /// language / AI-cleanup settings. Lets users "switch languages" on the
    /// same photo without re-picking it.
    private func reRecognizeCurrentImage() async {
        guard let data = selectedImageData else { return }
        await processImageData(data)
    }

    /// OCR an image's data, optionally run AI cleanup, then analyze/translate.
    private func processImageData(_ data: Data) async {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }

        do {
            let scanLanguage = AppPreferences.shared.photoScanLanguage
            let result = try await PhotoTextRecognitionService.shared.recognizeText(from: data, scanLanguage: scanLanguage)

            var textToProcess = result.cleanedText
            var languageHint: DetectedLanguage? = result.language

            // Concern C: route OCR output (and image, for vision-capable
            // providers) through the selected AI model for cleanup/structuring.
            if AIModelSettings.shared.aiPhotoCleanupEnabled, AIModelSettings.shared.isAnyProviderAvailable {
                if let cleaned = try? await AIWordExplanationService.shared.cleanupRecognizedText(
                    result.fullText,
                    imageData: data,
                    hintedLanguage: result.language
                ), !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textToProcess = cleaned
                    languageHint = nil  // re-detect on the AI-cleaned text
                }
            }

            await MainActor.run { sourceText = textToProcess }
            await processText(textToProcess, knownLanguage: languageHint)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
    
    private func processText(_ text: String, knownLanguage: DetectedLanguage? = nil) async {
        guard !text.isEmpty else { return }

        await MainActor.run {
            isProcessing = true
            errorMessage = nil
            // Clear previous results
            analyzedSentences = []
            cleanedChineseText = ""
            chineseTranslation = ""
            extractedVocab = []
        }

        // Determine language first (prefer the OCR-provided detection), using
        // the robust CJK-ratio-first detector so Chinese is never lost.
        let language = knownLanguage ?? ChineseTextAnalyzer.shared.detectLanguageRobust(text)

        if language.isChinese {
            // Chinese: clean with the Chinese-aware cleaner (no English regex).
            let cleaned = TextRecognitionResult.cleanChineseText([text])
            await MainActor.run {
                detectedLanguage = .chinese
                cleanedChineseText = cleaned
                isProcessing = false
            }
        } else {
            // English (or other scripts → treated as English): sentence cleanup.
            let cleaned = cleanTextForProcessing(text)
            let sentences = EnglishTextAnalyzer.shared.analyzeSentences(cleaned)
            await MainActor.run {
                detectedLanguage = .english
                analyzedSentences = sentences
                isProcessing = false
            }
        }
    }

    /// Clean English text for processing - removes line breaks that split sentences
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

                let chinese = (word.translation ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !chinese.isEmpty, containsChinese(chinese) else { continue }
                
                let term = SavedTerm(
                    chinese: chinese,
                    pinyin: PinyinConverter.convert(chinese),
                    definition: word.lemma.caseInsensitiveCompare(word.text) == .orderedSame ? word.text : "\(word.text) (\(word.lemma))",
                    partOfSpeech: word.partOfSpeech.englishName
                )
                
                if !savedTermsStore.contains(chinese: term.chinese) {
                    savedTermsStore.add(term)
                }
            }
        }
    }
    
    /// Save all Chinese words from the analysis to vocabulary
    private func saveAllChineseWordsToVocabulary() async {
        let analyzedWords = ChineseTextAnalyzer.shared.segmentWithPartsOfSpeech(cleanedChineseText)
        let meaningfulWords = analyzedWords.filter { word in
            let trimmed = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard trimmed.contains(where: { $0.isChineseCharacter }) else { return false }
            return !savedTermsStore.contains(chinese: trimmed)
        }

        guard !meaningfulWords.isEmpty else { return }

        do {
            let uniqueWordTexts = meaningfulWords.reduce(into: [String]()) { result, word in
                if !result.contains(word.text) {
                    result.append(word.text)
                }
            }

            let translations = try await WordTranslationService.shared.translateBatch(uniqueWordTexts, sourceIsChinese: true)

            for word in meaningfulWords {
                let definition = translations[word.text]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !definition.isEmpty else { continue }

                let term = SavedTerm(
                    chinese: word.text,
                    pinyin: PinyinConverter.convert(word.text),
                    definition: definition,
                    partOfSpeech: word.partOfSpeech.displayName
                )

                if !savedTermsStore.contains(chinese: term.chinese) {
                    savedTermsStore.add(term)
                }
            }
        } catch {
            errorMessage = "逐词保存失败: \(error.localizedDescription)"
        }
    }
    
    /// Ask the configured AI provider for structured key vocabulary from the
    /// recognized passage and surface it in the UI.
    private func extractVocabulary() async {
        let sourceIsChinese = detectedLanguage.isChinese
        let text = sourceIsChinese
            ? cleanedChineseText
            : analyzedSentences.map { $0.text }.joined(separator: " ")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        await MainActor.run {
            isExtractingVocab = true
            errorMessage = nil
        }

        do {
            let items = try await AIWordExplanationService.shared.extractVocabulary(
                fromPhotoText: text,
                imageData: selectedImageData,
                sourceIsChinese: sourceIsChinese
            )
            await MainActor.run {
                extractedVocab = items
                isExtractingVocab = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "AI 词汇提取失败: \(error.localizedDescription)"
                isExtractingVocab = false
            }
        }
    }

    /// Save AI-extracted vocabulary to the vocabulary book (Chinese-keyed).
    private func saveExtractedVocab() {
        let sourceIsChinese = detectedLanguage.isChinese
        for item in extractedVocab {
            let chinese: String
            let pinyin: String
            let definition: String
            if sourceIsChinese {
                chinese = item.term
                pinyin = item.reading.isEmpty ? PinyinConverter.convert(item.term) : item.reading
                definition = item.meaning
            } else {
                // English passage: the Chinese side is the item's meaning.
                chinese = item.meaning
                pinyin = PinyinConverter.convert(item.meaning)
                definition = item.term
            }

            let trimmed = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.contains(where: { $0.isChineseCharacter }) else { continue }
            guard !savedTermsStore.contains(chinese: trimmed) else { continue }

            savedTermsStore.add(SavedTerm(
                chinese: trimmed,
                pinyin: pinyin,
                definition: definition,
                partOfSpeech: "phrase"
            ))
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
        capturedText = ""
        selectedPhoto = nil
        selectedImageData = nil
        selectedEnglishWord = nil
        selectedChineseSegment = nil
        errorMessage = nil
        isProcessing = false
        isTranslating = false
        translationConfiguration = nil
        extractedVocab = []
        isExtractingVocab = false
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
        .environment(AppRouteStore.shared)
}
