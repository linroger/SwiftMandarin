//
//  TranslateView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import Translation

/// Main translation view - full-screen optimized for iPhone
/// Features:
/// - Bidirectional translation (English ↔ Chinese)
/// - Interactive character analysis with word segmentation
/// - History integration
/// - Quick copy/speak actions
struct TranslateView: View {
    @Environment(TranslationHistoryStore.self) private var historyStore
    @Environment(SavedTermsStore.self) private var savedTermsStore
    
    // Use shared state for persistence across tab switches
    private var sharedState: TranslationState { TranslationState.shared }
    
    @State private var translationConfiguration: TranslationSession.Configuration?
    
    // For word analysis popover - using sheet(item:) pattern to avoid race condition
    // When selectedSegment is set, the sheet automatically shows; when nil, it dismisses
    @State private var selectedSegment: RubySegment?
    
    // Settings
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    @AppStorage("defaultDirection") private var defaultDirectionRawValue: String = TranslationDirection.englishToChinese.rawValue
    @AppStorage("translateOnPaste") private var translateOnPaste: Bool = true
    @AppStorage("copyTranslationAutomatically") private var copyTranslationAutomatically: Bool = false
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true
    
    // Focus state for keyboard dismissal
    @FocusState private var isInputFocused: Bool
    @State private var pendingAutoTranslateTask: Task<Void, Never>?
    @State private var preserveSourceTextDuringProgrammaticUpdate: Bool = false
    
    // State for additional translation when input language mismatches direction
    @State private var additionalTranslation: String = ""
    @State private var isLoadingAdditionalTranslation: Bool = false
    
    // State for AI translation
    @State private var isAITranslating: Bool = false
    @State private var aiTranslationError: String?
    @State private var aiSettings = AIModelSettings.shared
    
    // Track last detected direction to reset configuration when input language changes
    @State private var lastDetectedDirection: TranslationDirection?
    
    // State for live speech translation
    @State private var showLiveSpeechTranslation: Bool = false
    
    // Computed bindings to shared state
    private var sourceText: Binding<String> {
        Binding(
            get: { sharedState.sourceText },
            set: { sharedState.sourceText = $0 }
        )
    }
    
    private var translatedText: String {
        get { sharedState.translatedText }
    }
    
    private var direction: TranslationDirection {
        get { sharedState.direction }
    }
    
    private var isTranslating: Bool {
        get { sharedState.isTranslating }
    }
    
    private var translationError: String? {
        get { sharedState.translationError }
    }
    
    // Store translation context for word definitions
    private var translationContext: String {
        sharedState.direction == .englishToChinese ? sharedState.sourceText : sharedState.translatedText
    }

    private var activeChineseText: String {
        let candidate = detectedChineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        return containsChinese(candidate) ? candidate : ""
    }

    private var activeEnglishText: String {
        detectedEnglishText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveActiveTerm: Bool {
        !activeChineseText.isEmpty && !activeEnglishText.isEmpty
    }

    private var isActiveTermSaved: Bool {
        canSaveActiveTerm && savedTermsStore.contains(chinese: activeChineseText)
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Direction toggle
                        directionToggle
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Source input section
                        sourceInputSection
                            .frame(minHeight: geometry.size.height * 0.35)
                        
                        // Divider with swap button
                        swapDivider
                        
                        // Translation output section
                        translationOutputSection
                            .frame(minHeight: geometry.size.height * 0.35)
                        
                        Spacer(minLength: 20)
                    }
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping outside text editor
                    isInputFocused = false
                }
            }
            .task {
                applyDefaultDirectionIfNeeded()
            }
            .navigationTitle("Translate")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        clearAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(!sharedState.hasContent)
                }
            }
            .translationTask(translationConfiguration) { session in
                await performTranslation(session: session)
            }
            .sheet(isPresented: $showLiveSpeechTranslation) {
                LiveSpeechTranslationView(
                    translationDirection: sharedState.direction,
                    onUseTranscript: { transcript in
                        // Set the transcript as source text
                        sharedState.sourceText = transcript
                        // Trigger translation if auto-translate is off
                        if !autoTranslate {
                            triggerTranslation()
                        }
                    },
                    onUseTranslation: { transcript, translation in
                        // Show both sides so the source text stays in sync
                        // with what was actually spoken.
                        let transcriptIsChinese = transcript.contains { $0.isChineseCharacter }
                        let direction: TranslationDirection = transcriptIsChinese ? .chineseToEnglish : .englishToChinese
                        preserveCurrentTranslationDuringSourceUpdate {
                            sharedState.direction = direction
                            sharedState.sourceText = transcript
                            sharedState.translatedText = translation
                        }
                        // Spoken translations join history/stats like typed ones.
                        if transcript != translation {
                            handleCompletedTranslation(source: transcript, target: translation, direction: direction)
                        }
                    }
                )
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #else
                .frame(minWidth: 500, minHeight: 600)
                #endif
                .localizedSurface()
            }
        }
    }
    
    // MARK: - Direction Toggle
    
    private var directionToggle: some View {
        HStack(spacing: 16) {
            Text(sharedState.direction.sourceLanguageName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    preserveCurrentTranslationDuringSourceUpdate {
                        additionalTranslation = ""
                        translationConfiguration = nil
                        lastDetectedDirection = nil
                        sharedState.translationError = nil
                        aiTranslationError = nil
                        
                        sharedState.direction = sharedState.direction.opposite
                        // Swap texts if both exist
                        if !sharedState.sourceText.isEmpty && !sharedState.translatedText.isEmpty {
                            let temp = sharedState.sourceText
                            sharedState.sourceText = sharedState.translatedText
                            sharedState.translatedText = temp
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            
            Text(sharedState.direction.targetLanguageName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    
    // MARK: - Source Input Section
    
    private var sourceInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sharedState.direction.sourceLanguageName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if !sharedState.sourceText.isEmpty {
                    Button {
                        clearAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            TextEditor(text: sourceText)
                .font(.title3)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal)
                .focused($isInputFocused)
                .overlay(alignment: .topLeading) {
                    if sharedState.sourceText.isEmpty {
                        Text(sharedState.direction.placeholder)
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: sharedState.sourceText) { oldValue, newValue in
                    pendingAutoTranslateTask?.cancel()

                    // Only auto-translate if setting is enabled
                    if !preserveSourceTextDuringProgrammaticUpdate && oldValue != newValue {
                        sharedState.translatedText = ""
                        sharedState.translationError = nil
                        additionalTranslation = ""
                        aiTranslationError = nil
                    }

                    if newValue.isEmpty {
                        // Reset configuration when text is cleared to ensure next translation triggers
                        translationConfiguration = nil
                        sharedState.translatedText = ""
                        sharedState.translationError = nil
                        additionalTranslation = ""
                    } else if autoTranslate {
                        scheduleAutoTranslation(for: newValue)
                    }
                }
            
            // Source text actions
            HStack(spacing: 12) {
                if !sharedState.sourceText.isEmpty {
                    Button {
                        SpeechService.speak(sharedState.sourceText, languageCode: sharedState.direction.sourceSpeechCode)
                    } label: {
                        Label("Speak", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button {
                    if let pastedText = ClipboardService.paste(), !pastedText.isEmpty {
                        sharedState.sourceText = pastedText
                        if translateOnPaste {
                            isInputFocused = false
                            triggerTranslation()
                        }
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Microphone button for live speech translation
                Button {
                    isInputFocused = false
                    showLiveSpeechTranslation = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
                .accessibilityLabel(Text("Live speech translation"))
                .help("Speak and translate in real time")
                
                Spacer()
                
                if !sharedState.sourceText.isEmpty {
                    Text("\(sharedState.sourceText.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Button {
                        withAnimation {
                            clearAll()
                        }
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
            
            // Prominent Translate buttons (shown when not auto-translating)
            if !sharedState.sourceText.isEmpty && !autoTranslate && sharedState.translatedText.isEmpty && !sharedState.isTranslating && !isAITranslating {
                VStack(spacing: 8) {
                    // Standard Translation API button
                    Button {
                        isInputFocused = false
                        triggerTranslation()
                    } label: {
                        Label("Translate", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // AI translation button (Apple Intelligence, Ollama, or cloud provider)
                    if aiSettings.isAnyProviderAvailable {
                        Button {
                            isInputFocused = false
                            Task { await triggerAITranslation() }
                        } label: {
                            Label {
                                Text("Translate with \(aiSettings.effectiveProvider.displayName)")
                                    .fitSingleLine()
                            } icon: {
                                ProviderIcon(provider: aiSettings.effectiveProvider, size: 18)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Swap Divider
    
    private var swapDivider: some View {
        HStack {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
            
            if sharedState.isTranslating || isAITranslating {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 8)
            } else {
                HStack(spacing: 12) {
                    // Standard translate button
                    Button {
                        triggerTranslation()
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(sharedState.sourceText.isEmpty)
                    .help("Translate with Apple Translation")
                    
                    // AI translate button (any configured provider)
                    if aiSettings.isAnyProviderAvailable {
                        Button {
                            Task { await triggerAITranslation() }
                        } label: {
                            ProviderIcon(provider: aiSettings.effectiveProvider, size: 22)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(sharedState.sourceText.isEmpty)
                        .help("Translate with \(aiSettings.effectiveProvider.displayName)")
                    }
                }
            }
            
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
    
    // MARK: - Translation Output Section
    
    private var translationOutputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(sharedState.direction.targetLanguageName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if !sharedState.translatedText.isEmpty {
                    Button {
                        saveToVocabulary()
                    } label: {
                        Image(systemName: isActiveTermSaved ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveActiveTerm)
                }
            }
            .padding(.horizontal)
            
            // Interactive translation display
            if !sharedState.translatedText.isEmpty {
                interactiveTranslationView
            } else if sharedState.sourceText.isEmpty {
                ContentUnavailableView {
                    Label("Enter Text", systemImage: "character.cursor.ibeam")
                } description: {
                    Text("Type or paste text above to translate")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = sharedState.translationError {
                ContentUnavailableView {
                    Label("Translation Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        sharedState.translationError = nil
                        triggerTranslation()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sharedState.isTranslating {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Translating...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Make sure language packs are downloaded in Settings → General → Language & Region")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isAITranslating {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Translating with \(aiSettings.effectiveProvider.displayName)…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(aiSettings.effectiveProvider.isCloud
                         ? "Using your configured AI provider"
                         : "Using on-device AI for translation")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Ready to translate state with action button
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    
                    Text("Ready to Translate")
                        .font(.headline)
                    
                    Text(autoTranslate ? "Translation will start automatically" : "Tap a button below to translate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if !autoTranslate {
                        VStack(spacing: 10) {
                            Button {
                                isInputFocused = false
                                triggerTranslation()
                            } label: {
                                Label("Translate Now", systemImage: "arrow.right.circle.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            if aiSettings.isAnyProviderAvailable {
                                Button {
                                    isInputFocused = false
                                    Task { await triggerAITranslation() }
                                } label: {
                                    Label {
                                        Text("Use \(aiSettings.effectiveProvider.displayName)")
                                            .fitSingleLine()
                                    } icon: {
                                        ProviderIcon(provider: aiSettings.effectiveProvider, size: 18)
                                    }
                                    .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            
            // Translation actions
            if !sharedState.translatedText.isEmpty {
                HStack(spacing: 16) {
                    Button {
                        SpeechService.speak(sharedState.translatedText, languageCode: sharedState.direction.targetSpeechCode)
                    } label: {
                        Label("Speak", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        ClipboardService.copy(sharedState.translatedText)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Interactive Translation View
    
    /// Helper to detect if text contains Chinese characters
    private func containsChinese(_ text: String) -> Bool {
        text.contains { $0.isChineseCharacter }
    }
    
    /// Whether input language mismatches the expected source language
    private var inputLanguageMismatch: Bool {
        let sourceIsChinese = containsChinese(sharedState.sourceText)
        if sharedState.direction == .chineseToEnglish {
            // Expected Chinese input, but got English
            return !sourceIsChinese && !sharedState.sourceText.isEmpty
        } else {
            // Expected English input, but got Chinese
            return sourceIsChinese && !sharedState.sourceText.isEmpty
        }
    }
    
    /// Determine which text is Chinese based on actual content detection
    private var detectedChineseText: String {
        let sourceIsChinese = containsChinese(sharedState.sourceText)
        let translatedIsChinese = containsChinese(sharedState.translatedText)
        
        // If we have an additional translation (from mismatch scenario), use it
        if inputLanguageMismatch && !additionalTranslation.isEmpty {
            if containsChinese(additionalTranslation) {
                return additionalTranslation
            }
        }
        
        if sourceIsChinese && !translatedIsChinese {
            return sharedState.sourceText
        } else if !sourceIsChinese && translatedIsChinese {
            return sharedState.translatedText
        } else if sourceIsChinese && translatedIsChinese {
            return sharedState.direction == .englishToChinese ? sharedState.translatedText : sharedState.sourceText
        } else {
            // Neither is Chinese - use additional translation if available
            if !additionalTranslation.isEmpty && containsChinese(additionalTranslation) {
                return additionalTranslation
            }
            return sharedState.direction == .englishToChinese ? sharedState.translatedText : sharedState.sourceText
        }
    }
    
    /// Determine which text is English based on actual content detection
    private var detectedEnglishText: String {
        let sourceIsChinese = containsChinese(sharedState.sourceText)
        let translatedIsChinese = containsChinese(sharedState.translatedText)
        
        // If we have an additional translation (from mismatch scenario), use it
        if inputLanguageMismatch && !additionalTranslation.isEmpty {
            if !containsChinese(additionalTranslation) {
                return additionalTranslation
            }
        }
        
        if sourceIsChinese && !translatedIsChinese {
            return sharedState.translatedText
        } else if !sourceIsChinese && translatedIsChinese {
            return sharedState.sourceText
        } else if sourceIsChinese && translatedIsChinese {
            return sharedState.direction == .englishToChinese ? sharedState.sourceText : sharedState.translatedText
        } else {
            // Neither is Chinese - the source is likely English
            // Use additional translation for Chinese if available
            if !additionalTranslation.isEmpty && !containsChinese(additionalTranslation) {
                return additionalTranslation
            }
            return sharedState.sourceText
        }
    }
    
    /// Whether to show English section first (when source was Chinese)
    private var showEnglishFirst: Bool {
        containsChinese(sharedState.sourceText) && !containsChinese(sharedState.translatedText)
    }
    
    /// Fetch additional translation when input language mismatches direction
    private func fetchAdditionalTranslation() async {
        guard inputLanguageMismatch else {
            additionalTranslation = ""
            return
        }
        
        isLoadingAdditionalTranslation = true
        
        do {
            let sourceIsChinese = containsChinese(sharedState.sourceText)
            if sourceIsChinese {
                // Input is Chinese but direction was EN→CN, translate to English
                additionalTranslation = try await WordTranslationService.shared.translateToEnglish(sharedState.sourceText)
            } else {
                // Input is English but direction was CN→EN, translate to Chinese
                additionalTranslation = try await WordTranslationService.shared.translateToChinese(sharedState.sourceText)
            }
        } catch {
            print("Additional translation error: \(error)")
            additionalTranslation = ""
        }
        
        isLoadingAdditionalTranslation = false
    }
    
    @ViewBuilder
    private var interactiveTranslationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Show English first if the source was Chinese (CN→EN scenario)
                if showEnglishFirst {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENGLISH")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(detectedEnglishText)
                            .font(.title3)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Divider()
                }
                
                // Chinese text with interleaved pinyin - always show
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHINESE (TAP WORDS FOR DETAILS)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    if isLoadingAdditionalTranslation && inputLanguageMismatch {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Getting Chinese translation...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Ruby text view with pinyin above each character
                        RubyTextView(
                            chineseText: detectedChineseText,
                            englishMeaning: detectedEnglishText
                        ) { segment in
                            selectedSegment = segment
                        }
                    }
                }
                
                // Show English below if it wasn't shown above
                if !showEnglishFirst {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENGLISH")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(detectedEnglishText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal)
        .task(id: sharedState.translatedText) {
            // Fetch additional translation when translated text changes and there's a mismatch
            await fetchAdditionalTranslation()
        }
        #if os(iOS)
        // Using sheet(item:) eliminates race condition - sheet only shows when item is non-nil
        // and the item is guaranteed to be available when the sheet content is built
        .sheet(item: $selectedSegment) { segment in
            NavigationStack {
                WordDetailPopover(
                    segment: segment,
                    contextTranslation: detectedEnglishText,
                    onSave: { definition in
                        let term = SavedTerm(
                            chinese: segment.text,
                            pinyin: segment.pinyin,
                            definition: definition,
                            partOfSpeech: segment.partOfSpeech.rawValue
                        )
                        if !savedTermsStore.contains(chinese: segment.text) {
                            savedTermsStore.add(term)
                        }
                    },
                    onCopy: {
                        triggerHaptic()
                    },
                    onDismiss: {
                        selectedSegment = nil
                    }
                )
                .navigationTitle("Word Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            selectedSegment = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .localizedSurface()
        }
        #else
        // Using popover(item:) eliminates race condition on macOS
        .popover(item: $selectedSegment) { segment in
            WordDetailPopover(
                segment: segment,
                contextTranslation: detectedEnglishText,
                onSave: { definition in
                    let term = SavedTerm(
                        chinese: segment.text,
                        pinyin: segment.pinyin,
                        definition: definition,
                        partOfSpeech: segment.partOfSpeech.rawValue
                    )
                    if !savedTermsStore.contains(chinese: segment.text) {
                        savedTermsStore.add(term)
                    }
                },
                onCopy: {},
                onDismiss: {
                    selectedSegment = nil
                }
            )
            .frame(minWidth: 300, minHeight: 350)
            .localizedSurface()
        }
        #endif
    }
    
    // MARK: - Actions
    
    /// Determines the actual translation direction based on detected input language
    /// According to the translation logic table:
    /// - Input EN → Output ZH (regardless of setting)
    /// - Input ZH → Output EN (regardless of setting)
    private var detectedTranslationDirection: TranslationDirection {
        let sourceIsChinese = containsChinese(sharedState.sourceText)
        // If input is Chinese, translate to English; if input is English, translate to Chinese
        return sourceIsChinese ? .chineseToEnglish : .englishToChinese
    }
    
    private func triggerTranslation() {
        let trimmedSource = sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else { return }
        
        // Detect actual input language and use appropriate translation direction
        // This ensures: EN input → ZH output, ZH input → EN output
        let actualDirection = detectedTranslationDirection
        
        // Apple's recommended pattern for triggering translations:
        // - First time: Create a new configuration
        // - When detected direction changes: Create new configuration
        // - Otherwise: Call invalidate() on existing configuration
        if translationConfiguration == nil || lastDetectedDirection != actualDirection {
            // Create new configuration based on detected language
            lastDetectedDirection = actualDirection
            translationConfiguration = TranslationSession.Configuration(
                source: actualDirection.sourceLanguage,
                target: actualDirection.targetLanguage
            )
        } else {
            // Subsequent translation with same direction - invalidate to re-trigger
            translationConfiguration?.invalidate()
        }
    }
    
    private func triggerAITranslation() async {
        let sourceSnapshot = sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let directionSnapshot = sharedState.direction
        guard !sourceSnapshot.isEmpty else { return }
        
        isAITranslating = true
        aiTranslationError = nil
        sharedState.translationError = nil
        
        do {
            // Detect actual input language (not based on setting)
            // EN input → ZH output, ZH input → EN output
            let sourceIsChinese = containsChinese(sourceSnapshot)
            
            let translation = try await AIWordExplanationService.shared.translateWithProvider(
                sourceSnapshot,
                sourceIsChinese: sourceIsChinese
            )
            
            guard sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == sourceSnapshot,
                  sharedState.direction == directionSnapshot else {
                isAITranslating = false
                return
            }

            sharedState.translatedText = translation
            isAITranslating = false
            handleCompletedTranslation(source: sourceSnapshot, target: translation, direction: directionSnapshot)
        } catch {
            isAITranslating = false
            sharedState.translationError = "AI Translation failed: \(error.localizedDescription)"
            print("AI Translation error: \(error)")
        }
    }
    
    private func performTranslation(session: TranslationSession) async {
        let sourceSnapshot = sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let directionSnapshot = sharedState.direction

        sharedState.isTranslating = true
        sharedState.translationError = nil
        
        do {
            let response = try await session.translate(sourceSnapshot)
            await MainActor.run {
                sharedState.isTranslating = false

                guard sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == sourceSnapshot,
                      sharedState.direction == directionSnapshot else {
                    return
                }

                sharedState.translatedText = response.targetText
                handleCompletedTranslation(source: sourceSnapshot, target: response.targetText, direction: directionSnapshot)
            }
        } catch {
            await MainActor.run {
                sharedState.isTranslating = false
                // Provide user-friendly error message
                let errorDescription = error.localizedDescription
                if errorDescription.contains("language") || errorDescription.contains("unavailable") {
                    sharedState.translationError = "Language pack not available. Please download it in Settings → General → Language & Region → Preferred Languages."
                } else {
                    sharedState.translationError = "Translation failed: \(errorDescription)"
                }
                print("Translation error: \(error)")
            }
        }
    }
    
    private func clearAll() {
        pendingAutoTranslateTask?.cancel()
        // Reset the translation configuration to ensure next translation triggers properly
        translationConfiguration = nil
        lastDetectedDirection = nil
        additionalTranslation = ""
        aiTranslationError = nil
        sharedState.clear()
    }
    
    private func saveToVocabulary() {
        let chinese = activeChineseText
        let english = activeEnglishText
        guard !chinese.isEmpty, !english.isEmpty else { return }
        let pinyin = PinyinConverter.convert(chinese)
        
        let term = SavedTerm(
            chinese: chinese,
            pinyin: pinyin,
            definition: english,
            partOfSpeech: ""
        )

        if savedTermsStore.contains(chinese: chinese) {
            savedTermsStore.remove(chinese: chinese)
        } else {
            savedTermsStore.add(term)
        }
        
        triggerHaptic()
    }

    private func applyDefaultDirectionIfNeeded() {
        guard !sharedState.hasContent,
              let storedDirection = TranslationDirection(rawValue: defaultDirectionRawValue) else {
            return
        }
        sharedState.direction = storedDirection
    }

    private func scheduleAutoTranslation(for text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        pendingAutoTranslateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled,
                  sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedText else {
                return
            }
            triggerTranslation()
        }
    }

    private func handleCompletedTranslation(source: String, target: String, direction: TranslationDirection) {
        guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if saveToHistoryAutomatically {
            historyStore.add(source: source, target: target, direction: direction)
        }

        if copyTranslationAutomatically {
            ClipboardService.copy(target)
        }
    }

    private func preserveCurrentTranslationDuringSourceUpdate(_ updates: () -> Void) {
        preserveSourceTextDuringProgrammaticUpdate = true
        updates()
        DispatchQueue.main.async {
            preserveSourceTextDuringProgrammaticUpdate = false
        }
    }
    
    private func triggerHaptic() {
        #if os(iOS)
        let hapticEnabled = UserDefaults.standard.bool(forKey: "hapticFeedback")
        if hapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        #endif
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Preview

#Preview {
    TranslateView()
        .environment(SavedTermsStore.shared)
        .environment(TranslationHistoryStore.shared)
        .environment(LearningProgressStore.shared)
}
