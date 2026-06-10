//
//  LiveSpeechTranslationView.swift
//  SwiftMandarin
//
//  Live speech-to-text translation view
//  Captures speech, transcribes it, and translates in real-time
//

import SwiftUI
import Translation

/// Live speech translation view that appears as a sheet/popup
/// Captures speech, transcribes it, and translates to the target language
struct LiveSpeechTranslationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SavedTermsStore.self) private var savedTermsStore
    
    /// The translation direction determines target language
    let translationDirection: TranslationDirection
    
    /// Callback when user wants to use the transcribed text
    let onUseTranscript: (String) -> Void
    
    /// Callback when user wants to use the translated text
    /// Called with `(transcript, translation)` so the caller can show both
    /// sides of the spoken translation, not just the result.
    let onUseTranslation: (String, String) -> Void
    
    // MARK: - State
    
    @State private var speechService = SpeechRecognitionService.shared
    @State private var isRecording = false
    @State private var transcript = ""
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var translationError: String?
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var selectedLanguage: SpeechRecognitionLanguage = .english
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var pulseAnimation = false
    @State private var lastDetectedDirection: TranslationDirection?
    @State private var translationTask: Task<Void, Never>?
    @State private var lastTranslationText: String = ""
    
    // For word analysis
    @State private var selectedSegment: RubySegment?
    
    /// The speech language based on translation direction
    private var defaultSpeechLanguage: SpeechRecognitionLanguage {
        switch translationDirection {
        case .englishToChinese:
            return .english
        case .chineseToEnglish:
            return .chinese
        }
    }
    
    /// Target language for translation
    private var targetLanguage: String {
        translationDirection.targetLanguageName
    }
    
    /// Whether transcribed text contains Chinese characters
    private var transcriptContainsChinese: Bool {
        transcript.contains { $0.isChineseCharacter }
    }
    
    /// Platform-aware background gradient
    private var backgroundGradient: some View {
        #if os(iOS)
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                speechService.isRecording ? Color.red.opacity(0.05) : Color.accentColor.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        #else
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                speechService.isRecording ? Color.red.opacity(0.05) : Color.accentColor.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Language selector header
                    languageSelector
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Recording section - always visible
                            recordingSection
                                .padding(.top, 8)
                            
                            // Transcript section
                            if !transcript.isEmpty || speechService.isRecording {
                                transcriptSection
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Translation section
                            if !translatedText.isEmpty || isTranslating {
                                translationSection
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            
                            // Empty state when not recording and no content
                            if transcript.isEmpty && !speechService.isRecording {
                                emptyState
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Space for action bar
                        .animation(.easeInOut(duration: 0.3), value: transcript.isEmpty)
                        .animation(.easeInOut(duration: 0.3), value: translatedText.isEmpty)
                    }
                    
                    Spacer(minLength: 0)
                }
                
                // Floating action bar at bottom
                VStack {
                    Spacer()
                    if !transcript.isEmpty {
                        actionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: transcript.isEmpty)
            }
            .navigationTitle("Voice Translation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Task {
                            await speechService.stopRecording()
                        }
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if !transcript.isEmpty || !translatedText.isEmpty {
                        Button {
                            withAnimation {
                                clearAll()
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .translationTask(translationConfiguration) { session in
                await performTranslation(session: session)
            }
            .alert("Permission Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #elseif os(macOS)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                    #endif
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(permissionAlertMessage)
            }
            .onAppear {
                selectedLanguage = defaultSpeechLanguage
            }
            .onDisappear {
                Task {
                    await speechService.stopRecording()
                }
            }
        }
        #if os(iOS)
        .sheet(item: $selectedSegment) { segment in
            NavigationStack {
                WordDetailPopover(
                    segment: segment,
                    contextTranslation: transcriptContainsChinese ? translatedText : transcript,
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
        .popover(item: $selectedSegment) { segment in
            WordDetailPopover(
                segment: segment,
                contextTranslation: transcriptContainsChinese ? translatedText : transcript,
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
    
    // MARK: - Language Selector
    
    private var languageSelector: some View {
        HStack(spacing: 12) {
            // Language icon
            Image(systemName: "globe")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            
            Text("Speaking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Language picker as a pill
            Menu {
                ForEach(SpeechRecognitionLanguage.allCases, id: \.self) { language in
                    Button {
                        withAnimation {
                            selectedLanguage = language
                        }
                    } label: {
                        HStack {
                            Text(language.displayName)
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLanguage.displayName)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
            }
            
            Spacer()
            
            // Model download indicator
            if speechService.isModelDownloading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(Int(speechService.downloadProgress * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
            }
        }
    }
    
    // MARK: - Recording Section
    
    private var recordingSection: some View {
        VStack(spacing: 20) {
            // Large microphone button with pulse animation
            ZStack {
                // Outer pulse rings when recording
                if speechService.isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                            .frame(width: 100 + CGFloat(index) * 30, height: 100 + CGFloat(index) * 30)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .opacity(pulseAnimation ? 0 : 0.6)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: pulseAnimation
                            )
                    }
                }
                
                // Main button
                Button {
                    Task {
                        await toggleRecording()
                    }
                } label: {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: speechService.isRecording 
                                        ? [Color.red, Color.red.opacity(0.8)]
                                        : [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .shadow(
                                color: speechService.isRecording ? .red.opacity(0.4) : .accentColor.opacity(0.4),
                                radius: speechService.isRecording ? 16 : 10,
                                y: 4
                            )
                        
                        // Icon
                        Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                            .scaleEffect(speechService.isRecording ? 0.9 : 1.0)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(speechService.isRecording ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speechService.isRecording)
            }
            .frame(height: 160)
            .onAppear {
                pulseAnimation = true
            }
            
            // Status text and indicator
            VStack(spacing: 8) {
                Text(speechService.isRecording ? "Listening..." : "Tap to speak")
                    .font(.headline)
                    .foregroundStyle(speechService.isRecording ? .red : .primary)
                
                if speechService.isRecording {
                    // Waveform-style animation
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red)
                                .frame(width: 4, height: CGFloat.random(in: 8...24))
                                .animation(
                                    .easeInOut(duration: 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.1),
                                    value: speechService.isRecording
                                )
                        }
                    }
                    .frame(height: 24)
                } else {
                    Text("Your speech will be transcribed and translated")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Transcript Section
    
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label("Transcript", systemImage: "text.quote")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !transcript.isEmpty {
                    Button {
                        SpeechService.speak(transcript, languageCode: selectedLanguage.rawValue)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if transcriptContainsChinese {
                    // Chinese transcript - show with pinyin
                    RubyTextView(
                        chineseText: speechService.finalTranscript,
                        englishMeaning: translatedText
                    ) { segment in
                        selectedSegment = segment
                    }
                    
                    // Partial/volatile text in lighter color
                    if !speechService.partialTranscript.isEmpty {
                        Text(speechService.partialTranscript)
                            .font(.title3)
                            .foregroundStyle(.secondary.opacity(0.6))
                            .italic()
                    }
                } else {
                    // English or other transcript
                    if speechService.completeTranscript.isEmpty {
                        Text("Listening...")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        Text(speechService.finalTranscript)
                            .font(.title3)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if !speechService.partialTranscript.isEmpty {
                            Text(speechService.partialTranscript)
                                .font(.title3)
                                .foregroundStyle(.secondary.opacity(0.6))
                                .italic()
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
        }
        .onChange(of: speechService.completeTranscript) { _, newValue in
            transcript = newValue
            // Debounce translation - only trigger when recording stops or after a delay
            debouncedTriggerTranslation()
        }
        .onChange(of: speechService.isRecording) { _, isRecording in
            // When recording stops, trigger final translation
            if !isRecording && !transcript.isEmpty {
                triggerTranslation()
            }
        }
    }
    
    // MARK: - Translation Section
    
    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label("Translation", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Text("→ \(targetLanguage)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                    )
                
                Spacer()
                
                if isTranslating {
                    ProgressView()
                        .controlSize(.small)
                } else if !translatedText.isEmpty {
                    Button {
                        let speakCode = translationDirection == .englishToChinese ? "zh-CN" : "en-US"
                        SpeechService.speak(translatedText, languageCode: speakCode)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if isTranslating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Translating...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                } else if let error = translationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else if !translatedText.isEmpty {
                    if !transcriptContainsChinese {
                        // Translated to Chinese - show with pinyin
                        RubyTextView(
                            chineseText: translatedText,
                            englishMeaning: transcript
                        ) { segment in
                            selectedSegment = segment
                        }
                    } else {
                        // Translated to English
                        Text(translatedText)
                            .font(.title3)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 6) {
                Text("Ready to Listen")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Tap the microphone and start speaking.\nYour words will be transcribed and translated in real-time.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        VStack(spacing: 0) {
            // Glass effect divider
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Use transcript button
                Button {
                    Task { await speechService.stopRecording() }
                    onUseTranscript(transcript)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                        Text("Use Original")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                
                // Use translation button
                Button {
                    Task { await speechService.stopRecording() }
                    onUseTranslation(transcript, translatedText.isEmpty ? transcript : translatedText)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Use Translation")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(translatedText.isEmpty && transcript.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() async {
        if speechService.isRecording {
            await speechService.stopRecording()
        } else {
            do {
                try await speechService.startRecording(language: selectedLanguage)
            } catch let error as SpeechRecognitionError {
                switch error {
                case .notAuthorized:
                    permissionAlertMessage = "Please enable Speech Recognition and Microphone access in Settings to use this feature."
                    showPermissionAlert = true
                default:
                    translationError = error.localizedDescription
                }
            } catch {
                translationError = error.localizedDescription
            }
        }
    }
    
    private func debouncedTriggerTranslation() {
        // Cancel any pending translation task
        translationTask?.cancel()
        
        // Debounce - wait 500ms after last change before translating
        translationTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            
            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                triggerTranslation()
            }
        }
    }
    
    private func triggerTranslation() {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        
        // Skip if text hasn't changed since last translation
        guard trimmedTranscript != lastTranslationText else { return }
        lastTranslationText = trimmedTranscript
        
        // Detect actual language and translate appropriately
        let sourceIsChinese = transcriptContainsChinese
        
        // Create configuration based on detected source language
        let actualDirection: TranslationDirection = sourceIsChinese ? .chineseToEnglish : .englishToChinese
        
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
    
    private func performTranslation(session: TranslationSession) async {
        let sourceSnapshot = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceSnapshot.isEmpty else { return }
        
        await MainActor.run {
            isTranslating = true
            translationError = nil
        }
        
        do {
            let response = try await session.translate(sourceSnapshot)
            await MainActor.run {
                isTranslating = false
                translatedText = response.targetText
            }
        } catch {
            await MainActor.run {
                isTranslating = false
                translationError = "Translation failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func clearAll() {
        translationTask?.cancel()
        transcript = ""
        translatedText = ""
        translationError = nil
        translationConfiguration = nil
        lastDetectedDirection = nil
        lastTranslationText = ""
        speechService.clearTranscripts()
    }
}

// MARK: - Preview

#Preview {
    LiveSpeechTranslationView(
        translationDirection: .englishToChinese,
        onUseTranscript: { _ in },
        onUseTranslation: { _, _ in }
    )
    .environment(SavedTermsStore.shared)
}
