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
    
    // For word analysis popover
    @State private var selectedSegment: RubySegment?
    @State private var showWordPopover: Bool = false
    
    // Settings
    @AppStorage("autoTranslate") private var autoTranslate: Bool = false
    
    // Focus state for keyboard dismissal
    @FocusState private var isInputFocused: Bool
    
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
                    sharedState.direction = sharedState.direction.opposite
                    // Swap texts if both exist
                    if !sharedState.sourceText.isEmpty && !sharedState.translatedText.isEmpty {
                        let temp = sharedState.sourceText
                        sharedState.sourceText = sharedState.translatedText
                        sharedState.translatedText = temp
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
                        sharedState.clear()
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
                    // Only auto-translate if setting is enabled
                    if autoTranslate && !newValue.isEmpty {
                        triggerTranslation()
                    } else if newValue.isEmpty {
                        sharedState.translatedText = ""
                        sharedState.translationError = nil
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
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                if !sharedState.sourceText.isEmpty {
                    Text("\(sharedState.sourceText.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Button {
                        withAnimation {
                            sharedState.clear()
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
            
            // Prominent Translate button (shown when not auto-translating)
            if !sharedState.sourceText.isEmpty && !autoTranslate && sharedState.translatedText.isEmpty && !sharedState.isTranslating {
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
            
            if sharedState.isTranslating {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 8)
            } else {
                Button {
                    triggerTranslation()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .disabled(sharedState.sourceText.isEmpty)
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
                        Image(systemName: savedTermsStore.contains(chinese: sharedState.direction == .englishToChinese ? sharedState.translatedText : sharedState.sourceText) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
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
            } else {
                // Ready to translate state with action button
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    
                    Text("Ready to Translate")
                        .font(.headline)
                    
                    Text(autoTranslate ? "Translation will start automatically" : "Tap the button below to translate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if !autoTranslate {
                        Button {
                            isInputFocused = false
                            triggerTranslation()
                        } label: {
                            Label("Translate Now", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
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
    
    @ViewBuilder
    private var interactiveTranslationView: some View {
        let isChinese = sharedState.direction == .englishToChinese
        let chineseText = isChinese ? sharedState.translatedText : sharedState.sourceText
        let englishText = isChinese ? sharedState.sourceText : sharedState.translatedText
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Show English translation if translating from Chinese
                if !isChinese {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENGLISH")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(sharedState.translatedText)
                            .font(.title3)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Divider()
                }
                
                // Chinese text with interleaved pinyin - always show for both directions
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHINESE (TAP WORDS FOR DETAILS)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    // Ruby text view with pinyin above each character
                    RubyTextView(
                        chineseText: chineseText,
                        englishMeaning: englishText
                    ) { segment in
                        selectedSegment = segment
                        showWordPopover = true
                    }
                }
                
                // Show English below if translating to Chinese
                if isChinese {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ENGLISH")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        Text(sharedState.sourceText)
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
        #if os(iOS)
        .sheet(isPresented: $showWordPopover) {
            if let segment = selectedSegment {
                NavigationStack {
                    WordDetailPopover(
                        segment: segment,
                        contextTranslation: englishText,
                        onSave: { definition in
                            let term = SavedTerm(
                                chinese: segment.text,
                                pinyin: segment.pinyin,
                                definition: definition,
                                partOfSpeech: segment.partOfSpeech.rawValue
                            )
                            if savedTermsStore.contains(chinese: segment.text) {
                                savedTermsStore.remove(term)
                            } else {
                                savedTermsStore.add(term)
                            }
                        },
                        onCopy: {
                            triggerHaptic()
                        },
                        onDismiss: {
                            showWordPopover = false
                        }
                    )
                    .navigationTitle("Word Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showWordPopover = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        #else
        .popover(isPresented: $showWordPopover) {
            if let segment = selectedSegment {
                WordDetailPopover(
                    segment: segment,
                    contextTranslation: englishText,
                    onSave: { definition in
                        let term = SavedTerm(
                            chinese: segment.text,
                            pinyin: segment.pinyin,
                            definition: definition,
                            partOfSpeech: segment.partOfSpeech.rawValue
                        )
                        if savedTermsStore.contains(chinese: segment.text) {
                            savedTermsStore.remove(term)
                        } else {
                            savedTermsStore.add(term)
                        }
                    },
                    onCopy: {},
                    onDismiss: {
                        showWordPopover = false
                    }
                )
                .frame(minWidth: 300, minHeight: 350)
            }
        }
        #endif
    }
    
    // MARK: - Actions
    
    private func triggerTranslation() {
        guard !sharedState.sourceText.isEmpty else { return }
        
        translationConfiguration = TranslationSession.Configuration(
            source: sharedState.direction.sourceLanguage,
            target: sharedState.direction.targetLanguage
        )
    }
    
    private func performTranslation(session: TranslationSession) async {
        sharedState.isTranslating = true
        sharedState.translationError = nil
        
        do {
            let response = try await session.translate(sharedState.sourceText)
            await MainActor.run {
                sharedState.translatedText = response.targetText
                sharedState.isTranslating = false
                
                // Save to history
                historyStore.add(
                    source: sharedState.sourceText,
                    target: sharedState.translatedText,
                    direction: sharedState.direction
                )
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
        sharedState.clear()
    }
    
    private func saveToVocabulary() {
        let chinese = sharedState.direction == .englishToChinese ? sharedState.translatedText : sharedState.sourceText
        let english = sharedState.direction == .englishToChinese ? sharedState.sourceText : sharedState.translatedText
        let pinyin = PinyinConverter.convert(chinese)
        
        let term = SavedTerm(
            chinese: chinese,
            pinyin: pinyin,
            definition: english,
            partOfSpeech: ""
        )
        
        if savedTermsStore.contains(chinese: chinese) {
            savedTermsStore.remove(term)
        } else {
            savedTermsStore.add(term)
        }
        
        triggerHaptic()
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
