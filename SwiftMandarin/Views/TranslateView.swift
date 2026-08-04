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
    
    // Version-agnostic holder for the Apple Translation configuration so the
    // view can deploy to iOS 17 (where TranslationSession doesn't exist).
    @State private var translationConfiguration = TranslationConfigurationBox()
    
    // For word analysis popover - using sheet(item:) pattern to avoid race condition
    // When selectedSegment is set, the sheet automatically shows; when nil, it dismisses
    @State private var selectedSegment: RubySegment?

    // The English-side counterpart, used when the learner is a Mandarin
    // speaker studying English and the English pane is the tappable one.
    @State private var selectedEnglishWord: AnalyzedEnglishWord?
    
    // Settings
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    @AppStorage("defaultDirection") private var defaultDirectionRawValue: String = TranslationDirection.persistedDefault.rawValue
    @AppStorage("translateOnPaste") private var translateOnPaste: Bool = true
    @AppStorage("copyTranslationAutomatically") private var copyTranslationAutomatically: Bool = false
    @AppStorage("saveToHistoryAutomatically") private var saveToHistoryAutomatically: Bool = true
    
    // Focus state for keyboard dismissal
    @FocusState private var isInputFocused: Bool
    @State private var pendingAutoTranslateTask: Task<Void, Never>?
    @State private var preserveSourceTextDuringProgrammaticUpdate: Bool = false

    // Debounced persistence of the in-progress draft, so an unfinished
    // translation survives an app relaunch (state only lives across tab
    // switches otherwise).
    @State private var draftSaveTask: Task<Void, Never>?
    private static let draftKey = "translationDraft"
    
    // State for additional translation when input language mismatches direction
    @State private var additionalTranslation: String = ""
    @State private var isLoadingAdditionalTranslation: Bool = false
    
    // State for AI translation
    @State private var aiTranslationTask: Task<Void, Never>?
    @State private var isAITranslating: Bool = false
    @State private var aiTranslationError: String?
    @State private var aiSettings = AIModelSettings.shared

    // Study notes that arrive in the same structured response as an AI
    // translation. Apple's on-device Translation API returns none, so that
    // path offers an explicit "Explain" action instead of paying for a second
    // model call the learner didn't ask for.
    @State private var translationNotes: AITranslationResult?
    @State private var notesSourceSnapshot: String = ""
    @State private var isFetchingNotes: Bool = false
    @State private var notesTask: Task<Void, Never>?
    @State private var notesError: String?

    // State for AI word/phrase identification (powers the tap-to-learn view
    // with proper word boundaries when a translation comes from an AI provider)
    @State private var aiSegments: [RubySegment] = []
    @State private var isIdentifyingWords: Bool = false
    @State private var wordIdentificationTask: Task<Void, Never>?
    @State private var wordIdGeneration: Int = 0
    
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
                restoreDraftIfNeeded()
                applyDefaultDirectionIfNeeded()
            }
            // Persist the draft (debounced) whenever any of its parts change.
            .onChange(of: sharedState.sourceText) { _, _ in scheduleDraftSave() }
            .onChange(of: sharedState.translatedText) { _, _ in scheduleDraftSave() }
            .onChange(of: sharedState.direction) { _, _ in scheduleDraftSave() }
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
            .background {
                // Apple Translation runs on iOS 18+/macOS 15+; on iOS 17 the
                // translate actions route to the configured AI provider.
                if #available(iOS 18.0, macOS 15.0, *) {
                    TranslationTaskHost(box: translationConfiguration) { session in
                        await performTranslation(session: session)
                    }
                }
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
                        // Identify words in the Chinese side for the tap-to-learn view.
                        startWordIdentification(for: activeChineseText)
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
                        translationConfiguration.clear()
                        lastDetectedDirection = nil
                        sharedState.translationError = nil
                        aiTranslationError = nil
                        // The swapped text invalidates any AI segmentation.
                        wordIdentificationTask?.cancel()
                        aiSegments = []
                        isIdentifyingWords = false

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
            .glassButtonStyleCompat()
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
                        // Stale word identification no longer matches the input.
                        wordIdentificationTask?.cancel()
                        aiSegments = []
                        isIdentifyingWords = false
                        // Notes describe the old source; drop them with it.
                        clearNotes()
                    }

                    if newValue.isEmpty {
                        // Reset configuration when text is cleared to ensure next translation triggers
                        translationConfiguration.clear()
                        sharedState.translatedText = ""
                        sharedState.translationError = nil
                        additionalTranslation = ""
                    } else if autoTranslate && !preserveSourceTextDuringProgrammaticUpdate {
                        // Programmatic updates (draft restore, live-speech
                        // results) arrive with their translation already set —
                        // re-translating them would waste a request and
                        // double-count history/stats.
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
                            startAITranslation()
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
                            startAITranslation()
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
                                    startAITranslation()
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

            translationNotesSection
        }
    }

    // MARK: - Translation Notes Section

    @ViewBuilder
    private var translationNotesSection: some View {
        if let notes = currentNotes {
            TranslationNotesView(
                result: notes,
                onSave: { saveKeyTerm($0) },
                isSaved: { savedTermsStore.contains(chinese: $0.term) }
            )
            .padding(.horizontal)
            .padding(.top, 4)
        } else if canExplainTranslation {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    fetchTranslationNotes()
                } label: {
                    HStack(spacing: 6) {
                        if isFetchingNotes {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "lightbulb")
                        }
                        Text(isFetchingNotes ? "Explaining…" : "Explain this translation")
                            .fitSingleLine()
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isFetchingNotes)

                if let notesError {
                    Text(notesError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
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
    
    /// Whether the native-language pane sits above the studied-language one.
    ///
    /// A Mandarin speaker never needs this: their studied pane is the English
    /// one, so it already leads. For an English speaker the order follows the
    /// content — English goes on top only when it is the answer they asked
    /// for, i.e. when the source was Chinese — which is what this screen has
    /// always done.
    private var showsNativePaneFirst: Bool {
        guard learningContext.interactiveReaderIsChinese else { return false }
        return containsChinese(sharedState.sourceText) && !containsChinese(sharedState.translatedText)
    }

    /// The direction this screen is teaching. Everything below keys off it:
    /// which pane gets word-by-word annotation and taps, which text is fed to
    /// word identification, and which reading system is shown.
    private var learningContext: LearningContext { LearningContext.current }

    /// The English text, tokenized for the tappable word grid. Local
    /// segmentation is enough here — English word boundaries are unambiguous,
    /// so unlike Chinese this needs no model call to look right.
    private var englishWords: [AnalyzedEnglishWord] {
        EnglishTextAnalyzer.shared.analyzeWords(detectedEnglishText)
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
    
    /// Section headings, hoisted out of the view body as explicitly typed
    /// `LocalizedStringKey`s. A literal written inline inside a ternary is
    /// ambiguous between `Text`'s localizing and verbatim initializers, and
    /// Xcode's string extractor does not reliably pull it into the catalog —
    /// so each branch is stated as a key here instead.
    private var studiedPaneHeading: LocalizedStringKey {
        learningContext.interactiveReaderIsChinese
            ? "CHINESE (TAP WORDS FOR DETAILS)"
            : "ENGLISH (TAP WORDS FOR DETAILS)"
    }

    private var nativePaneHeading: LocalizedStringKey {
        learningContext.interactiveReaderIsChinese ? "ENGLISH" : "CHINESE"
    }

    private var pendingTranslationLabel: LocalizedStringKey {
        learningContext.interactiveReaderIsChinese
            ? "Getting Chinese translation..."
            : "Getting English translation..."
    }

    /// The word-by-word pane for the language being studied: Chinese with
    /// pinyin ruby for an English speaker, English word chips for a Mandarin
    /// speaker. Both are tappable and open the matching word-detail surface.
    @ViewBuilder
    private var studiedLanguagePane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(studiedPaneHeading)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if isIdentifyingWords {
                    ProgressView()
                        .controlSize(.small)
                    Text("Identifying words…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if isLoadingAdditionalTranslation && inputLanguageMismatch {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(pendingTranslationLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if learningContext.interactiveReaderIsChinese {
                // Ruby text view with pinyin above each character. When the
                // AI has identified word boundaries they drive the
                // segmentation; otherwise it falls back to local tokenizing.
                RubyTextView(
                    chineseText: detectedChineseText,
                    englishMeaning: detectedEnglishText,
                    aiSegments: aiSegments.isEmpty ? nil : aiSegments
                ) { segment in
                    selectedSegment = segment
                }
            } else {
                EnglishRubyTextView(
                    words: englishWords,
                    showTranslations: false
                ) { word in
                    selectedEnglishWord = word
                }
            }
        }
    }

    /// The plain, unannotated pane for the language the learner already reads.
    @ViewBuilder
    private func nativeLanguagePane(prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(nativePaneHeading)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(learningContext.interactiveReaderIsChinese ? detectedEnglishText : detectedChineseText)
                .font(prominent ? .title3 : .body)
                .fontWeight(prominent ? .medium : .regular)
                .foregroundStyle(prominent ? .primary : .secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var interactiveTranslationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showsNativePaneFirst {
                    nativeLanguagePane(prominent: true)
                    Divider()
                }

                studiedLanguagePane

                if !showsNativePaneFirst {
                    Divider()
                    nativeLanguagePane(prominent: false)
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
        // The English-side word detail, used when the English pane is the
        // tappable one. `EnglishWordDetailSheet` already leads with whichever
        // side the learner is studying, so it serves both directions.
        #if os(iOS)
        .sheet(item: $selectedEnglishWord) { word in
            EnglishWordDetailSheet(word: word)
                .localizedSurface()
        }
        #else
        .popover(item: $selectedEnglishWord) { word in
            EnglishWordDetailSheet(word: word)
                .frame(minWidth: 320, minHeight: 380)
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
        
        guard #available(iOS 18.0, macOS 15.0, *) else {
            // iOS 17: no on-device Translation API — use the AI provider.
            startAITranslation()
            return
        }

        // Apple's recommended pattern for triggering translations:
        // - First time: Create a new configuration
        // - When detected direction changes: Create new configuration
        // - Otherwise: Call invalidate() on existing configuration
        if translationConfiguration.isNil || lastDetectedDirection != actualDirection {
            // Create new configuration based on detected language
            lastDetectedDirection = actualDirection
            translationConfiguration.set(
                source: actualDirection.sourceLanguage,
                target: actualDirection.targetLanguage
            )
        } else {
            // Subsequent translation with same direction - invalidate to re-trigger
            translationConfiguration.invalidate()
        }
    }
    
    /// Start AI translation, cancelling any in-flight request first so
    /// rapid taps can't pile up racing tasks.
    private func startAITranslation() {
        aiTranslationTask?.cancel()
        aiTranslationTask = Task { await triggerAITranslation() }
    }

    private func triggerAITranslation() async {
        let sourceSnapshot = sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceSnapshot.isEmpty else { return }

        isAITranslating = true
        aiTranslationError = nil
        sharedState.translationError = nil

        do {
            // Detect actual input language (not based on the UI toggle).
            // EN input → ZH output, ZH input → EN output. History must record
            // the direction that actually happened, not what the toggle said.
            let sourceIsChinese = containsChinese(sourceSnapshot)
            let actualDirection: TranslationDirection = sourceIsChinese ? .chineseToEnglish : .englishToChinese

            let result = try await AIWordExplanationService.shared.translateDetailedWithProvider(
                sourceSnapshot,
                sourceIsChinese: sourceIsChinese
            )
            let translation = result.translation

            // Only guard against a stale source text; the UI toggle is irrelevant
            // because the direction is derived from the (unchanged) source content.
            guard sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == sourceSnapshot else {
                isAITranslating = false
                return
            }

            sharedState.translatedText = translation
            // The notes rode along in the same response — no extra round trip.
            applyNotes(result, for: sourceSnapshot)
            isAITranslating = false
            handleCompletedTranslation(source: sourceSnapshot, target: translation, direction: actualDirection)
            // Have the AI identify the words/phrases in the Chinese side so the
            // tap-to-learn view uses real word boundaries, not NLTokenizer.
            startWordIdentification(for: activeChineseText)
        } catch {
            isAITranslating = false
            sharedState.translationError = "AI Translation failed: \(error.localizedDescription)"
            print("AI Translation error: \(error)")
        }
    }

    // MARK: - Translation Notes

    /// Whether the notes panel can be offered for the current translation.
    private var canExplainTranslation: Bool {
        !sharedState.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && aiSettings.isAnyProviderAvailable
    }

    /// Notes are only shown while they still describe the visible source.
    private var currentNotes: AITranslationResult? {
        guard let translationNotes,
              notesSourceSnapshot == sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines),
              translationNotes.hasNotes else { return nil }
        return translationNotes
    }

    private func applyNotes(_ result: AITranslationResult, for source: String) {
        translationNotes = result
        notesSourceSnapshot = source
        notesError = nil
    }

    private func clearNotes() {
        notesTask?.cancel()
        notesTask = nil
        isFetchingNotes = false
        translationNotes = nil
        notesSourceSnapshot = ""
        notesError = nil
    }

    /// Fetch notes for a translation that came from Apple's on-device
    /// Translation API, which returns none. Kept behind an explicit tap so the
    /// default, free, on-device path never silently bills a provider.
    private func fetchTranslationNotes() {
        let sourceSnapshot = sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceSnapshot.isEmpty, aiSettings.isAnyProviderAvailable else { return }

        notesTask?.cancel()
        notesError = nil
        isFetchingNotes = true
        notesTask = Task {
            do {
                let result = try await AIWordExplanationService.shared.translateDetailedWithProvider(
                    sourceSnapshot,
                    sourceIsChinese: containsChinese(sourceSnapshot)
                )
                try Task.checkCancellation()
                guard sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == sourceSnapshot else { return }
                applyNotes(result, for: sourceSnapshot)
                if !result.hasNotes {
                    notesError = String(localized: "This passage didn't need any notes — nothing in it is unusual.", bundle: .appLanguage)
                }
            } catch is CancellationError {
                // A newer request replaced this one.
            } catch {
                guard sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == sourceSnapshot else { return }
                notesError = error.localizedDescription
            }
            isFetchingNotes = false
            notesTask = nil
        }
    }

    private func saveKeyTerm(_ term: AITranslationKeyTerm) {
        let headword = term.term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !headword.isEmpty, !savedTermsStore.contains(chinese: headword) else { return }
        let headwordIsChinese = headword.contains { $0.isChineseCharacter }
        // The model supplies pinyin for a Chinese headword and IPA for an
        // English one, so the reading is worth keeping either way — blanking it
        // for English left a Mandarin speaker with no pronunciation at all.
        // `SavedTerm.showsPhonetic` re-validates it before rendering, so a
        // model that ignored the contract cannot poison the field.
        let pinyin = headwordIsChinese
            ? (term.reading.isEmpty ? PinyinConverter.convert(headword) : term.reading)
            : term.reading
        savedTermsStore.add(SavedTerm(
            chinese: headword,
            pinyin: pinyin,
            definition: term.meaning,
            partOfSpeech: "phrase"
        ))
        triggerHaptic()
    }

    /// Ask the configured AI provider to identify the words/phrases in the
    /// Chinese text, then feed them to the interactive ruby view. Cancels any
    /// in-flight identification first. Silently falls back to local
    /// segmentation (empty `aiSegments`) when no provider is available or the
    /// request fails — the feature is additive, never blocking.
    private func startWordIdentification(for chineseText: String) {
        wordIdentificationTask?.cancel()
        aiSegments = []

        // These segments only ever drive the Chinese ruby view. A Mandarin
        // speaker studying English reads the English pane instead, whose word
        // boundaries `EnglishTextAnalyzer` resolves locally — so skip the
        // model call rather than paying for segmentation nothing will render.
        guard learningContext.interactiveReaderIsChinese else {
            isIdentifyingWords = false
            return
        }

        let trimmed = chineseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, aiSettings.isAnyProviderAvailable else {
            isIdentifyingWords = false
            return
        }

        // Generation guard: only the latest request may flip the spinner off,
        // so a superseded request's completion can't hide an in-flight one.
        wordIdGeneration += 1
        let generation = wordIdGeneration
        isIdentifyingWords = true
        wordIdentificationTask = Task {
            let identified: [IdentifiedWord]?
            do {
                identified = try await WordIdentificationService.shared.identifyWords(in: trimmed)
            } catch {
                // Local segmentation remains in place; just log.
                print("Word identification error: \(error)")
                identified = nil
            }

            // A newer request superseded this one — it now owns the spinner and
            // results, so this stale completion must not touch either.
            guard generation == wordIdGeneration else { return }
            // This is the current request: always stop the spinner, even when
            // the result is dropped below (otherwise it could spin forever).
            isIdentifyingWords = false

            // Apply segments only if they're non-empty and the visible Chinese
            // text hasn't moved on (e.g. a mismatch fetch replaced it).
            guard !Task.isCancelled,
                  let identified, !identified.isEmpty,
                  activeChineseText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else {
                return
            }
            aiSegments = identified.map { RubySegment(aiWord: $0) }
        }
    }
    
    @available(iOS 18.0, macOS 15.0, *)
    private func performTranslation(session: TranslationSession) async {
        let sourceSnapshot = sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

        sharedState.isTranslating = true
        sharedState.translationError = nil
        // Apple Translation uses local word segmentation, so drop any AI
        // segments from a previous AI translation of this text.
        wordIdentificationTask?.cancel()
        aiSegments = []
        isIdentifyingWords = false

        do {
            let response = try await session.translate(sourceSnapshot)
            await MainActor.run {
                sharedState.isTranslating = false

                // Only guard against a stale source text, not the UI toggle.
                guard sharedState.sourceText.trimmingCharacters(in: .whitespacesAndNewlines) == sourceSnapshot else {
                    return
                }

                // Record the direction actually performed, derived from the source content.
                let sourceIsChinese = containsChinese(sourceSnapshot)
                let actualDirection: TranslationDirection = sourceIsChinese ? .chineseToEnglish : .englishToChinese

                sharedState.translatedText = response.targetText
                handleCompletedTranslation(source: sourceSnapshot, target: response.targetText, direction: actualDirection)
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
        aiTranslationTask?.cancel()
        wordIdentificationTask?.cancel()
        // Reset the translation configuration to ensure next translation triggers properly
        translationConfiguration.clear()
        lastDetectedDirection = nil
        additionalTranslation = ""
        aiTranslationError = nil
        aiSegments = []
        isIdentifyingWords = false
        clearNotes()
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

    // MARK: - Draft Persistence

    /// Restore the last persisted draft, but only when the editor is empty —
    /// live content (including a restore from History) always wins.
    private func restoreDraftIfNeeded() {
        guard !sharedState.hasContent,
              let draft = PersistentCodableStore.load(TranslationDraft.self, key: Self.draftKey),
              !draft.isEmpty else { return }
        // Programmatic restore: keep the source-text onChange from wiping the
        // restored translation.
        preserveCurrentTranslationDuringSourceUpdate {
            sharedState.direction = draft.direction
            sharedState.sourceText = draft.source
            sharedState.translatedText = draft.translated
        }
    }

    /// Persist the current draft, debounced 1s so keystrokes don't hammer
    /// UserDefaults. Clearing is persisted immediately so a cleared draft
    /// can't resurrect if the app quits inside the debounce window.
    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        let draft = TranslationDraft(
            source: sharedState.sourceText,
            translated: sharedState.translatedText,
            direction: sharedState.direction
        )
        guard !draft.isEmpty else {
            PersistentCodableStore.save(draft, key: Self.draftKey)
            return
        }
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            PersistentCodableStore.save(
                TranslationDraft(
                    source: sharedState.sourceText,
                    translated: sharedState.translatedText,
                    direction: sharedState.direction
                ),
                key: Self.draftKey
            )
        }
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
        // The Settings toggle defaults to ON, so an unset key must read as
        // true (`bool(forKey:)` would return false until the user ever
        // touches the toggle).
        let hapticEnabled = (UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool) ?? true
        if hapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        #endif
    }
}

// MARK: - Translation Draft

/// Snapshot of the in-progress translation persisted to UserDefaults so an
/// unfinished draft survives an app relaunch.
private struct TranslationDraft: Codable {
    var source: String
    var translated: String
    var direction: TranslationDirection

    var isEmpty: Bool {
        source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
