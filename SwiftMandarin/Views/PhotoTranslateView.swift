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

nonisolated private struct PhotoEnglishTranslationSnapshot: Sendable {
    nonisolated struct Word: Sendable {
        let sentenceIndex: Int
        let wordIndex: Int
        let lemma: String
        let shouldTranslate: Bool
    }

    let requestID: UUID
    let sourceTexts: [String]
    let words: [Word]
}

nonisolated private struct MultimodalAudioTranslationFailure: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
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
    
    // Translation (box keeps the iOS 18-only configuration type out of the
    // stored-property layout so the view deploys to iOS 17)
    @State private var translationConfiguration = TranslationConfigurationBox()
    @State private var isTranslating: Bool = false
    
    // Settings
    @State private var showGrammarPoints: Bool = true
    @State private var prefs = AppPreferences.shared
    @State private var aiSettings = AIModelSettings.shared
    @State private var inputMode: MultimodalInputMode = .imageAndText

    // AI structured vocabulary extraction
    @State private var extractedVocab: [ExtractedVocabItem] = []
    @State private var isExtractingVocab: Bool = false

    // Workbook grading (tucked-away feature) + its review bank and history,
    // all kept within the Photo tab.
    @State private var showWorkbookGrading: Bool = false
    @State private var showQuestionBank: Bool = false
    @State private var showGradingHistory: Bool = false

    // AI cleanup transparency: keep the raw OCR text so the user can compare
    // or revert, and surface a notice when cleanup was skipped or failed.
    @State private var rawOCRText: String = ""
    @State private var aiCleanupApplied: Bool = false
    @State private var cleanupNotice: LocalizedStringKey?

    // In-flight processing tasks, cancelled when superseded so rapid photo
    // re-selection can't pile up stale work that overwrites newer results.
    @State private var photoProcessingTask: Task<Void, Never>?
    @State private var textProcessingTask: Task<Void, Never>?
    @State private var inputProcessingRequestID: UUID?
    @State private var aiFallbackTranslationTask: Task<Void, Never>?
    @State private var englishTranslationRequestID: UUID?
    @State private var chineseTranslationTask: Task<Void, Never>?
    @State private var chineseTranslationRequestID: UUID?

    // History (translations made here count like the Translate tab's)
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true
    
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

                    // AI-cleanup transparency: warn when cleanup was skipped,
                    // and let the user flip back to the unmodified OCR text.
                    if let notice = cleanupNotice {
                        cleanupNoticeBanner(notice)
                    } else if aiCleanupApplied {
                        cleanedTextBadge
                    }

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
            .navigationTitle("Multimodal")
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

                        // Workbook suite — grade pages, review the question
                        // bank, and revisit past graded workbooks. All kept in
                        // the Photo tab.
                        Section("作业 · Workbook") {
                            Button {
                                showWorkbookGrading = true
                            } label: {
                                Label("作业批改 · Grade Workbook", systemImage: "checkmark.rectangle.stack")
                            }
                            Button {
                                showQuestionBank = true
                            } label: {
                                Label("复习题库 · Review Bank", systemImage: "tray.full")
                            }
                            Button {
                                showGradingHistory = true
                            } label: {
                                Label("批改历史 · Grading History", systemImage: "clock.arrow.circlepath")
                            }
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
                    .localizedSurface()
            }
            .sheet(item: $selectedEnglishWord) { word in
                EnglishWordDetailSheet(word: word)
                    .localizedSurface()
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
                .localizedSurface()
            }
            .sheet(isPresented: $showScreenshotTranslation) {
                TranslatedScreenshotOverlayView()
                    .environment(ScreenshotTranslationStore.shared)
                    .localizedSurface()
            }
            .sheet(isPresented: $showWorkbookGrading) {
                WorkbookGradingView()
                    .environment(savedTermsStore)
                    .localizedSurface()
            }
            .sheet(isPresented: $showQuestionBank) {
                WorkbookQuestionBankView()
                    .localizedSurface()
            }
            .sheet(isPresented: $showGradingHistory) {
                WorkbookGradingHistoryView()
                    .localizedSurface()
            }
            .fileImporter(isPresented: $showPhotoFiles, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                let requestID = beginInputProcessingRequest()
                Task {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    guard let data = try? Data(contentsOf: url) else { return }
                    try? Task.checkCancellation()
                    guard commitIfCurrent(requestID, operation: {
                        selectedImageData = data
                    }) else { return }
                    await processImageData(data, requestID: requestID)
                }
            }
            .task(id: routeStore.pendingAction?.id) {
                applyPendingRouteAction()
            }
            .onChange(of: capturedText) { _, newValue in
                if !newValue.isEmpty {
                    // Cancel BOTH in-flight pipelines: a photo task finishing
                    // late must not overwrite this newer camera capture.
                    photoProcessingTask?.cancel()
                    textProcessingTask?.cancel()
                    let requestID = beginInputProcessingRequest()
                    sourceText = newValue
                    textProcessingTask = Task {
                        await processText(newValue, requestID: requestID)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                photoProcessingTask?.cancel()
                textProcessingTask?.cancel()
                let requestID = beginInputProcessingRequest()
                photoProcessingTask = Task {
                    await loadAndProcessImage(newValue, requestID: requestID)
                }
            }
            .background {
                // Apple Translation runs on iOS 18+/macOS 15+; on iOS 17 the
                // sentence translation routes through the AI provider instead.
                if #available(iOS 18.0, macOS 15.0, *) {
                    TranslationTaskHost(box: translationConfiguration) { session in
                        await translateSentences(session: session)
                    }
                }
            }
        }
    }
    
    // MARK: - AI Cleanup Transparency

    /// Warning banner shown when AI cleanup was requested but didn't run.
    private func cleanupNoticeBanner(_ notice: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                cleanupNotice = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
    }

    /// Badge shown when AI cleanup modified the OCR text, with a one-tap
    /// revert to the original recognition result.
    private var cleanedTextBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text("AI cleaned the scanned text")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Use original text") {
                revertToRawOCRText()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.purple.opacity(0.08)))
    }

    /// Restore the unmodified OCR text and re-run analysis on it.
    private func revertToRawOCRText() {
        guard !rawOCRText.isEmpty else { return }
        let requestID = beginInputProcessingRequest()
        aiCleanupApplied = false
        sourceText = rawOCRText
        textProcessingTask?.cancel()
        textProcessingTask = Task {
            await processText(rawOCRText, requestID: requestID)
        }
    }

    // MARK: - Input Section

    /// Icon-over-text label for a source-picker button. A vertical layout gives
    /// the (often long, localized) title the button's full width, so it stays on
    /// one line instead of wrapping letter-by-letter when three buttons share a
    /// narrow iPhone row.
    private func sourceButtonLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(.subheadline)
                .fitSingleLine(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var inputSection: some View {
        VStack(spacing: 16) {
            Picker("Input Type", selection: $inputMode) {
                ForEach(MultimodalInputMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Multimodal input type")

            if inputMode == .imageAndText {
                // Image input buttons
                HStack(spacing: 12) {
                    #if os(iOS)
                    if CameraScannerView.isSupported {
                        Button {
                            showCameraScanner = true
                        } label: {
                            sourceButtonLabel("相机扫描", systemImage: "camera.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!CameraScannerView.isAvailable)
                    }
                    #endif

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        sourceButtonLabel("照片", systemImage: "photo.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showPhotoFiles = true
                    } label: {
                        sourceButtonLabel("文件", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
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
                        Label(
                            "识别语言: " + prefs.photoScanLanguage.displayName,
                            systemImage: prefs.photoScanLanguage.iconName
                        )
                        .font(.caption)
                        .fitSingleLine()
                    }
                    .menuStyle(.borderlessButton)

                    Spacer()

                    if selectedImageData != nil {
                        Button {
                            let requestID = beginInputProcessingRequest()
                            Task {
                                await reRecognizeCurrentImage(requestID: requestID)
                            }
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
            } else {
                MultimodalAudioInputView { transcript, language, action in
                    try await handleAudioInputResult(
                        transcript,
                        recognitionLanguage: language,
                        action: action
                    )
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
                        let requestID = beginInputProcessingRequest()
                        Task {
                            await processText(sourceText, requestID: requestID)
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
        guard inputMode == .imageAndText else { return false }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            return false
        }
        let requestID = beginInputProcessingRequest()
        Task {
            guard let data = await PhotoTranslateView.loadDroppedImage(provider) else { return }
            guard commitIfCurrent(requestID, operation: {
                selectedImageData = data
            }) else { return }
            await processImageData(data, requestID: requestID)
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
                        .fitSingleLine()
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
                        .fitSingleLine()
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
                    .fitSingleLine()
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
                let requestID = beginInputProcessingRequest()
                Task {
                    await processText(sourceText, requestID: requestID)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Multimodal Translation", systemImage: "waveform.and.magnifyingglass")
        } description: {
            Text("Scan an image, enter text, or switch to Audio to record or upload speech.\nSupports English ↔ Chinese transcription and translation.")
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
        // Clear only the actions this view actually handles. A `.startReview`
        // belongs to the Learn view, so leaving it pending lets that view
        // consume it instead of having it silently dropped here.
        switch action.kind {
        case .openCameraScanner:
            #if os(iOS)
            showCameraScanner = true
            #endif
            routeStore.clearPendingAction()
        case .translateScreenshots:
            showScreenshotTranslation = true
            routeStore.clearPendingAction()
        case .startReview, .openStudyRoute:
            break
        }
    }

    // MARK: - Actions

    private func beginInputProcessingRequest() -> UUID {
        let requestID = UUID()
        inputProcessingRequestID = requestID
        return requestID
    }

    @discardableResult
    private func commitIfCurrent(
        _ requestID: UUID,
        operation: () -> Void
    ) -> Bool {
        guard inputProcessingRequestID == requestID, !Task.isCancelled else {
            return false
        }
        operation()
        return true
    }

    /// Reuses the same editor, analysis, and language-specific translation
    /// paths as typed or OCR text. The transcript is committed to the editor
    /// before translation starts so learners can always inspect and correct it.
    private func handleAudioInputResult(
        _ transcript: String,
        recognitionLanguage: SpeechRecognitionLanguage,
        action: MultimodalAudioAction
    ) async throws {
        guard !transcript.isEmpty, !Task.isCancelled else { return }

        // An audio result is newer than any in-flight photo/OCR work and must
        // not be overwritten when an older image task completes.
        photoProcessingTask?.cancel()
        textProcessingTask?.cancel()
        let requestID = beginInputProcessingRequest()
        aiFallbackTranslationTask?.cancel()
        englishTranslationRequestID = nil
        chineseTranslationTask?.cancel()
        chineseTranslationTask = nil
        chineseTranslationRequestID = nil
        isTranslating = false
        sourceText = transcript
        rawOCRText = ""
        aiCleanupApplied = false
        cleanupNotice = nil

        let knownLanguage: DetectedLanguage = recognitionLanguage == .english
            ? .english
            : .chinese
        await processText(
            transcript,
            knownLanguage: knownLanguage,
            requestID: requestID
        )
        try Task.checkCancellation()

        guard action == .translateAudio,
              !Task.isCancelled,
              inputProcessingRequestID == requestID else { return }
        if knownLanguage == .english {
            triggerTranslation()
            guard let translationRequestID = englishTranslationRequestID else {
                throw MultimodalAudioTranslationFailure(
                    message: String(localized: "Translation failed.")
                )
            }
            try await waitForAudioTranslationCompletion(
                inputRequestID: requestID,
                translationRequestID: translationRequestID,
                language: .english
            )
            guard analyzedSentences.contains(where: {
                !($0.translation ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) else {
                throw MultimodalAudioTranslationFailure(
                    message: errorMessage ?? String(localized: "Translation failed.")
                )
            }
        } else {
            triggerChineseTranslation()
            guard let translationRequestID = chineseTranslationRequestID else {
                throw MultimodalAudioTranslationFailure(
                    message: String(localized: "Translation failed.")
                )
            }
            try await waitForAudioTranslationCompletion(
                inputRequestID: requestID,
                translationRequestID: translationRequestID,
                language: .chinese
            )
            guard !chineseTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MultimodalAudioTranslationFailure(
                    message: errorMessage ?? String(localized: "Translation failed.")
                )
            }
        }
    }

    /// Keeps the audio operation's progress and Cancel control alive through
    /// the parent-owned translation. Cancelling the child task invalidates the
    /// matching translation request so late provider results cannot commit.
    private func waitForAudioTranslationCompletion(
        inputRequestID: UUID,
        translationRequestID: UUID,
        language: DetectedLanguage
    ) async throws {
        do {
            while true {
                try Task.checkCancellation()
                guard self.inputProcessingRequestID == inputRequestID else {
                    throw CancellationError()
                }
                let isActive = language == .english
                    ? englishTranslationRequestID == translationRequestID
                    : chineseTranslationRequestID == translationRequestID
                if !isActive { return }
                try await Task.sleep(for: .milliseconds(50))
            }
        } catch {
            if language == .english,
               englishTranslationRequestID == translationRequestID {
                aiFallbackTranslationTask?.cancel()
                aiFallbackTranslationTask = nil
                englishTranslationRequestID = nil
            } else if language == .chinese,
                      chineseTranslationRequestID == translationRequestID {
                chineseTranslationTask?.cancel()
                chineseTranslationTask = nil
                chineseTranslationRequestID = nil
            }
            if englishTranslationRequestID == nil,
               chineseTranslationRequestID == nil {
                isTranslating = false
            }
            throw error
        }
    }
    
    private func loadAndProcessImage(
        _ item: PhotosPickerItem?,
        requestID: UUID
    ) async {
        guard inputProcessingRequestID == requestID,
              !Task.isCancelled else { return }
        guard let item else {
            _ = commitIfCurrent(requestID) {
                isProcessing = false
            }
            return
        }

        guard commitIfCurrent(requestID, operation: {
            aiFallbackTranslationTask?.cancel()
            aiFallbackTranslationTask = nil
            englishTranslationRequestID = nil
            isTranslating = false
            if chineseTranslationRequestID != nil {
                chineseTranslationTask?.cancel()
                chineseTranslationTask = nil
                chineseTranslationRequestID = nil
                isTranslating = false
            }
            isProcessing = true
            errorMessage = nil
        }) else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw RecognitionError.invalidImage
            }
            try Task.checkCancellation()
            guard commitIfCurrent(requestID, operation: {
                selectedImageData = data
            }) else { return }
            await processImageData(data, requestID: requestID)
        } catch is CancellationError {
            _ = commitIfCurrent(requestID) {
                isProcessing = false
            }
        } catch {
            _ = commitIfCurrent(requestID) {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    /// Re-run OCR on the most recently selected image using the current scan
    /// language / AI-cleanup settings. Lets users "switch languages" on the
    /// same photo without re-picking it.
    private func reRecognizeCurrentImage(requestID: UUID) async {
        guard let data = selectedImageData,
              inputProcessingRequestID == requestID else { return }
        await processImageData(data, requestID: requestID)
    }

    /// OCR an image's data, optionally run AI cleanup, then analyze/translate.
    private func processImageData(_ data: Data, requestID: UUID) async {
        guard commitIfCurrent(requestID, operation: {
            isProcessing = true
            errorMessage = nil
            cleanupNotice = nil
            aiCleanupApplied = false
        }) else { return }

        do {
            let scanLanguage = AppPreferences.shared.photoScanLanguage
            let result = try await PhotoTextRecognitionService.shared.recognizeText(from: data, scanLanguage: scanLanguage)
            guard !Task.isCancelled,
                  inputProcessingRequestID == requestID else {
                return
            }

            var textToProcess = result.cleanedText
            var languageHint: DetectedLanguage? = result.language
            // The pre-AI-cleanup baseline ("original" for the revert button):
            // the locally cleaned OCR text — exactly what the user would have
            // gotten with AI cleanup turned off.
            guard commitIfCurrent(requestID, operation: {
                rawOCRText = result.cleanedText
            }) else { return }

            // Concern C: route OCR output (and image, for vision-capable
            // providers) through the selected AI model for cleanup/structuring.
            // The user is told when cleanup was skipped or failed, instead of
            // silently falling back to the raw text.
            if AIModelSettings.shared.aiPhotoCleanupEnabled {
                do {
                    if let cleaned = try await AIWordExplanationService.shared.cleanupRecognizedText(
                        result.fullText,
                        imageData: data,
                        hintedLanguage: result.language
                    ), !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        textToProcess = cleaned
                        languageHint = nil  // re-detect on the AI-cleaned text
                        guard commitIfCurrent(requestID, operation: {
                            aiCleanupApplied = true
                        }) else { return }
                    } else {
                        guard commitIfCurrent(requestID, operation: {
                            cleanupNotice = "AI cleanup is unavailable — showing the original scanned text"
                        }) else { return }
                    }
                } catch {
                    guard !Task.isCancelled,
                          commitIfCurrent(requestID, operation: {
                        cleanupNotice = "AI cleanup failed — showing the original scanned text"
                    }) else { return }
                }
            }
            guard !Task.isCancelled else { return }

            guard commitIfCurrent(requestID, operation: {
                sourceText = textToProcess
            }) else { return }
            await processText(
                textToProcess,
                knownLanguage: languageHint,
                requestID: requestID
            )
        } catch is CancellationError {
            _ = commitIfCurrent(requestID) {
                isProcessing = false
            }
        } catch {
            _ = commitIfCurrent(requestID) {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
    
    private func processText(
        _ text: String,
        knownLanguage: DetectedLanguage? = nil,
        requestID: UUID
    ) async {
        guard !text.isEmpty,
              !Task.isCancelled,
              inputProcessingRequestID == requestID else { return }

        guard commitIfCurrent(requestID, operation: {
            aiFallbackTranslationTask?.cancel()
            aiFallbackTranslationTask = nil
            englishTranslationRequestID = nil
            isTranslating = false
            if chineseTranslationRequestID != nil {
                chineseTranslationTask?.cancel()
                chineseTranslationTask = nil
                chineseTranslationRequestID = nil
                isTranslating = false
            }
            isProcessing = true
            errorMessage = nil
            // Clear previous results
            analyzedSentences = []
            cleanedChineseText = ""
            chineseTranslation = ""
            extractedVocab = []
        }) else { return }

        // Determine language first (prefer the OCR-provided detection), using
        // the robust CJK-ratio-first detector so Chinese is never lost.
        let language = knownLanguage ?? ChineseTextAnalyzer.shared.detectLanguageRobust(text)
        guard !Task.isCancelled,
              inputProcessingRequestID == requestID else { return }

        if language.isChinese {
            // Chinese: clean with the Chinese-aware cleaner (no English regex).
            let cleaned = TextRecognitionResult.cleanChineseText([text])
            _ = commitIfCurrent(requestID) {
                detectedLanguage = .chinese
                cleanedChineseText = cleaned
                isProcessing = false
            }
        } else {
            // English (or other scripts → treated as English): sentence cleanup.
            let cleaned = cleanTextForProcessing(text)
            let sentences = EnglishTextAnalyzer.shared.analyzeSentences(cleaned)
            _ = commitIfCurrent(requestID) {
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
        let sourceTexts = analyzedSentences.map(\.text)
        guard !sourceTexts.isEmpty else { return }

        aiFallbackTranslationTask?.cancel()
        let requestID = UUID()
        englishTranslationRequestID = requestID

        guard #available(iOS 18.0, macOS 15.0, *) else {
            // iOS 17: no on-device Translation API — translate the sentences
            // through the configured AI provider instead.
            aiFallbackTranslationTask = Task {
                await translateSentencesWithAIFallback(
                    requestID: requestID,
                    sourceTexts: sourceTexts
                )
            }
            return
        }

        if translationConfiguration.isNil {
            translationConfiguration.set(
                source: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: "zh-Hans")
            )
        } else {
            translationConfiguration.invalidate()
        }
    }

    /// iOS 17 path: per-sentence translation via the AI provider (word-level
    /// translations are fetched lazily when a word is tapped). One failing
    /// sentence doesn't abort the rest; an error is shown only when nothing
    /// could be translated.
    private func translateSentencesWithAIFallback(
        requestID: UUID,
        sourceTexts: [String]
    ) async {
        await MainActor.run {
            guard isCurrentEnglishTranslation(requestID, sourceTexts: sourceTexts) else { return }
            isTranslating = true
        }

        var lastError: Error?
        var translations: [Int: String] = [:]

        for (index, text) in sourceTexts.enumerated() {
            guard !Task.isCancelled else { return }

            do {
                let translation = try await WordTranslationService.shared.translate(text, sourceIsChinese: false)
                try Task.checkCancellation()
                guard await MainActor.run(body: {
                    isCurrentEnglishTranslation(requestID, sourceTexts: sourceTexts)
                }) else { return }
                translations[index] = translation
                await MainActor.run {
                    guard isCurrentEnglishTranslation(requestID, sourceTexts: sourceTexts),
                          index < analyzedSentences.count else { return }
                    analyzedSentences[index].translation = translation
                }
            } catch is CancellationError {
                return
            } catch {
                lastError = error
            }
        }

        await MainActor.run {
            guard isCurrentEnglishTranslation(requestID, sourceTexts: sourceTexts) else { return }
            if translations.isEmpty, let lastError {
                errorMessage = "翻译失败: \(lastError.localizedDescription)"
            } else if saveToHistoryAutomatically {
                let translatedIndexes = translations.keys.sorted()
                let fullSource = translatedIndexes.map { sourceTexts[$0] }.joined(separator: " ")
                let fullTarget = translatedIndexes.compactMap { translations[$0] }.joined(separator: " ")
                if !fullSource.isEmpty, !fullTarget.isEmpty {
                    TranslationHistoryStore.shared.add(
                        source: fullSource,
                        target: fullTarget,
                        direction: .englishToChinese
                    )
                }
            }
            englishTranslationRequestID = nil
            aiFallbackTranslationTask = nil
            isTranslating = false
        }
    }

    private func isCurrentEnglishTranslation(
        _ requestID: UUID,
        sourceTexts: [String]
    ) -> Bool {
        englishTranslationRequestID == requestID
            && analyzedSentences.map(\.text) == sourceTexts
    }
    
    /// Trigger Chinese → English translation
    private func triggerChineseTranslation() {
        let source = cleanedChineseText
        guard !source.isEmpty else { return }

        chineseTranslationTask?.cancel()
        let requestID = UUID()
        chineseTranslationRequestID = requestID
        isTranslating = true

        chineseTranslationTask = Task {
            do {
                // Translate the full text from Chinese to English
                let translation = try await WordTranslationService.shared.translateToEnglish(source)
                try Task.checkCancellation()

                await MainActor.run {
                    guard chineseTranslationRequestID == requestID,
                          cleanedChineseText == source else { return }
                    chineseTranslation = translation
                    // Photo translations count toward history/stats like the
                    // Translate tab's (respecting the same preference).
                    if saveToHistoryAutomatically {
                        TranslationHistoryStore.shared.add(
                            source: source,
                            target: translation,
                            direction: .chineseToEnglish
                        )
                    }
                    chineseTranslationRequestID = nil
                    chineseTranslationTask = nil
                    isTranslating = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard chineseTranslationRequestID == requestID else { return }
                    chineseTranslationRequestID = nil
                    chineseTranslationTask = nil
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    guard chineseTranslationRequestID == requestID else { return }
                    errorMessage = "翻译失败: \(error.localizedDescription)"
                    chineseTranslationRequestID = nil
                    chineseTranslationTask = nil
                    isTranslating = false
                }
            }
        }
    }
    
    @available(iOS 18.0, macOS 15.0, *)
    private func translateSentences(session: TranslationSession) async {
        guard let snapshot = await MainActor.run(body: { () -> PhotoEnglishTranslationSnapshot? in
            guard let requestID = englishTranslationRequestID else { return nil }
            let sourceTexts = analyzedSentences.map(\.text)
            let words = analyzedSentences.enumerated().flatMap { sentenceIndex, sentence in
                sentence.words.enumerated().map { wordIndex, word in
                    PhotoEnglishTranslationSnapshot.Word(
                        sentenceIndex: sentenceIndex,
                        wordIndex: wordIndex,
                        lemma: word.lemma,
                        shouldTranslate: word.partOfSpeech != .determiner
                            && word.partOfSpeech != .particle
                    )
                }
            }
            isTranslating = true
            return PhotoEnglishTranslationSnapshot(
                requestID: requestID,
                sourceTexts: sourceTexts,
                words: words
            )
        }) else { return }

        var sentenceTranslations: [Int: String] = [:]
        var wordTranslations: [(sentenceIndex: Int, wordIndex: Int, translation: String)] = []

        do {
            for (index, text) in snapshot.sourceTexts.enumerated() {
                let response = try await session.translate(text)
                try Task.checkCancellation()
                guard await MainActor.run(body: {
                    isCurrentEnglishTranslation(
                        snapshot.requestID,
                        sourceTexts: snapshot.sourceTexts
                    )
                }) else { return }
                sentenceTranslations[index] = response.targetText
                await MainActor.run {
                    guard isCurrentEnglishTranslation(
                        snapshot.requestID,
                        sourceTexts: snapshot.sourceTexts
                    ), index < analyzedSentences.count else { return }
                    analyzedSentences[index].translation = response.targetText
                }
            }

            for word in snapshot.words where word.shouldTranslate {
                let response = try await session.translate(word.lemma)
                try Task.checkCancellation()
                guard await MainActor.run(body: {
                    isCurrentEnglishTranslation(
                        snapshot.requestID,
                        sourceTexts: snapshot.sourceTexts
                    )
                }) else { return }
                wordTranslations.append(
                    (word.sentenceIndex, word.wordIndex, response.targetText)
                )
            }

            await MainActor.run {
                guard isCurrentEnglishTranslation(
                    snapshot.requestID,
                    sourceTexts: snapshot.sourceTexts
                ) else { return }

                for (sentenceIndex, wordIndex, translation) in wordTranslations {
                    if sentenceIndex < analyzedSentences.count,
                       wordIndex < analyzedSentences[sentenceIndex].words.count {
                        analyzedSentences[sentenceIndex].words[wordIndex].translation = translation
                    }
                }

                if saveToHistoryAutomatically {
                    let translatedIndexes = sentenceTranslations.keys.sorted()
                    let fullSource = translatedIndexes
                        .map { snapshot.sourceTexts[$0] }
                        .joined(separator: " ")
                    let fullTarget = translatedIndexes
                        .compactMap { sentenceTranslations[$0] }
                        .joined(separator: " ")
                    if !fullSource.isEmpty, !fullTarget.isEmpty {
                        TranslationHistoryStore.shared.add(
                            source: fullSource,
                            target: fullTarget,
                            direction: .englishToChinese
                        )
                    }
                }
                englishTranslationRequestID = nil
                isTranslating = false
            }
        } catch is CancellationError {
            await MainActor.run {
                guard englishTranslationRequestID == snapshot.requestID else { return }
                englishTranslationRequestID = nil
                isTranslating = false
            }
        } catch {
            await MainActor.run {
                guard isCurrentEnglishTranslation(
                    snapshot.requestID,
                    sourceTexts: snapshot.sourceTexts
                ) else { return }
                if !Task.isCancelled {
                    errorMessage = "翻译失败: \(error.localizedDescription)"
                }
                englishTranslationRequestID = nil
                isTranslating = false
            }
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

    /// Save AI-extracted vocabulary to the vocabulary book. The extracted
    /// TERM is the study item (it is in the passage's language — the one the
    /// user is reading to learn), so it becomes the headword whichever
    /// language it is in; the meaning (written in the user's native language)
    /// becomes the gloss. Pinyin only applies to Chinese headwords.
    private func saveExtractedVocab() {
        for item in extractedVocab {
            let headword = item.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !headword.isEmpty else { continue }
            guard !savedTermsStore.contains(chinese: headword) else { continue }

            let headwordIsChinese = headword.contains { $0.isChineseCharacter }
            let pinyin = headwordIsChinese
                ? (item.reading.isEmpty ? PinyinConverter.convert(headword) : item.reading)
                : ""

            savedTermsStore.add(SavedTerm(
                chinese: headword,
                pinyin: pinyin,
                definition: item.meaning.trimmingCharacters(in: .whitespacesAndNewlines),
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
        photoProcessingTask?.cancel()
        textProcessingTask?.cancel()
        inputProcessingRequestID = nil
        aiFallbackTranslationTask?.cancel()
        aiFallbackTranslationTask = nil
        englishTranslationRequestID = nil
        chineseTranslationTask?.cancel()
        chineseTranslationTask = nil
        chineseTranslationRequestID = nil
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
        translationConfiguration.clear()
        extractedVocab = []
        isExtractingVocab = false
        rawOCRText = ""
        aiCleanupApplied = false
        cleanupNotice = nil
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
