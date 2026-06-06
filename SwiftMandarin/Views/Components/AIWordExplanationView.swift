//
//  AIWordExplanationView.swift
//  SwiftMandarin
//
//  A reusable view component that displays AI-generated word explanations
//  using either Apple Intelligence or Ollama based on user settings
//

import SwiftUI

/// A view that displays a detailed AI-generated explanation for a Mandarin word
struct AIWordExplanationView: View {
    let word: String
    let pinyin: String
    let context: String?
    
    @State private var explanation: WordExplanationResult?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var expandedSections: Set<String> = ["definition", "examples"]
    
    private let aiService = AIWordExplanationService.shared
    private let aiSettings = AIModelSettings.shared
    
    /// Check if any AI provider is available
    private var isAnyProviderAvailable: Bool {
        aiSettings.isAnyProviderAvailable
    }
    
    /// Get the current provider name for display
    private var currentProviderName: String {
        aiSettings.effectiveProvider.displayName
    }
    
    var body: some View {
        Group {
            if !isAnyProviderAvailable {
                unavailableView
            } else if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let explanation = explanation {
                explanationContent(explanation)
            } else {
                generateButton
            }
        }
    }
    
    // MARK: - Unavailable State
    
    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("AI Not Available")
                .font(.headline)
            
            Text("Enable Apple Intelligence or connect to Ollama in Settings to use AI features.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            
            Text("Generating explanation...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Using \(currentProviderName)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error State
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            
            Text("Could not generate explanation")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await generateExplanation() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Generate Button
    
    private var generateButton: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)
            
            ProviderIcon(provider: aiSettings.effectiveProvider, size: 40)
                .foregroundStyle(.blue)
            
            Text("Get a detailed explanation of this word including nuances, grammar usage, examples, and more.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task { await generateExplanation() }
            } label: {
                Label("Explain with \(currentProviderName)", systemImage: "sparkles")
                    .fitSingleLine()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Explanation Content
    
    @ViewBuilder
    private func explanationContent(_ explanation: WordExplanationResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI badge header
            HStack {
                ProviderIcon(provider: aiSettings.effectiveProvider, size: 16)
                    .foregroundStyle(.blue)
                Text(currentProviderName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                Spacer()
                Button {
                    Task { await generateExplanation() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.blue.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Definition Section
                    collapsibleSection(
                        title: "Definition",
                        icon: "text.book.closed",
                        id: "definition"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            if !explanation.partOfSpeech.isEmpty {
                                Text(explanation.partOfSpeech)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.blue))
                            }
                            
                            Text(explanation.definition)
                                .font(.body)
                        }
                    }
                    
                    // Nuances Section
                    if !explanation.nuances.isEmpty {
                        collapsibleSection(
                            title: "Nuances & Context",
                            icon: "lightbulb",
                            id: "nuances"
                        ) {
                            Text(explanation.nuances)
                                .font(.callout)
                        }
                    }
                    
                    // Grammar Usage Section
                    if !explanation.grammarUsage.isEmpty {
                        collapsibleSection(
                            title: "Grammar Usage",
                            icon: "text.alignleft",
                            id: "grammar"
                        ) {
                            Text(explanation.grammarUsage)
                                .font(.callout)
                        }
                    }
                    
                    // Usage Contexts Section
                    if !explanation.usageContexts.isEmpty {
                        collapsibleSection(
                            title: "When to Use",
                            icon: "bubble.left.and.bubble.right",
                            id: "contexts"
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(explanation.usageContexts, id: \.self) { context in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                        Text(context)
                                            .font(.callout)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Example Sentences Section
                    if !explanation.exampleSentences.isEmpty {
                        collapsibleSection(
                            title: "Examples",
                            icon: "text.quote",
                            id: "examples"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(explanation.exampleSentences) { sentence in
                                    exampleSentenceRow(sentence)
                                }
                            }
                        }
                    }
                    
                    // Synonyms Section
                    if !explanation.synonyms.isEmpty {
                        collapsibleSection(
                            title: "Synonyms",
                            icon: "equal.circle",
                            id: "synonyms"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(explanation.synonyms) { synonym in
                                    relatedWordRow(synonym, tint: .blue)
                                }
                            }
                        }
                    }
                    
                    // Antonyms Section
                    if !explanation.antonyms.isEmpty {
                        collapsibleSection(
                            title: "Antonyms",
                            icon: "arrow.left.arrow.right",
                            id: "antonyms"
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(explanation.antonyms) { antonym in
                                    relatedWordRow(antonym, tint: .orange)
                                }
                            }
                        }
                    }
                    
                    // Common Collocations Section
                    if !explanation.commonCollocations.isEmpty {
                        collapsibleSection(
                            title: "Common Phrases",
                            icon: "text.badge.plus",
                            id: "collocations"
                        ) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(explanation.commonCollocations) { collocation in
                                    collocationRow(collocation)
                                }
                            }
                        }
                    }
                    
                    // Learning Tip Section
                    if !explanation.learningTip.isEmpty {
                        collapsibleSection(
                            title: "Learning Tip",
                            icon: "graduationcap",
                            id: "tip"
                        ) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text(explanation.learningTip)
                                    .font(.callout)
                                    .italic()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.yellow.opacity(0.1))
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Section Components
    
    @ViewBuilder
    private func collapsibleSection<Content: View>(
        title: String,
        icon: String,
        id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedSections.contains(id) {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: expandedSections.contains(id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            
            if expandedSections.contains(id) {
                content()
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func exampleSentenceRow(_ sentence: ExampleSentenceResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sentence.chinese)
                .font(.body)
                .fontWeight(.medium)
            
            Text(PinyinConverter.coloredPinyin(fromPinyin: sentence.pinyin))
                .font(.caption)
            
            Text(sentence.english)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }
    
    private func relatedWordRow(_ word: RelatedWordResult, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(word.chinese)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(word.pinyin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(word.meaning)
                    .font(.caption)
                    .foregroundStyle(tint)
            }
            
            if !word.difference.isEmpty {
                Text(word.difference)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func collocationRow(_ collocation: CollocationResult) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(collocation.chinese)
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text(collocation.pinyin)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(collocation.english)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func generateExplanation() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use the unified provider method that routes to Apple Intelligence or Ollama
            explanation = try await aiService.generateExplanationWithProvider(
                for: word,
                pinyin: pinyin,
                context: context
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Compact AI Button for List Rows

/// A small button that can be added to vocabulary rows to trigger AI explanation
struct AIExplainButton: View {
    let word: String
    let pinyin: String
    let onTap: () -> Void
    
    @State private var isAvailable: Bool = true
    
    private var provider: AIProvider {
        AIModelSettings.shared.effectiveProvider
    }

    private var providerName: String {
        AIModelSettings.shared.effectiveProvider.displayName
    }

    var body: some View {
        Button(action: onTap) {
            ProviderIcon(provider: provider, size: 16)
                .foregroundStyle(isAvailable ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .help(isAvailable ? "Explain with \(providerName)" : "AI not available")
        .onAppear {
            isAvailable = AIModelSettings.shared.isAppleIntelligenceAvailable || OllamaService.shared.isConnected
        }
    }
}

// MARK: - Preview

#Preview {
    AIWordExplanationView(
        word: "学习",
        pinyin: "xuéxí",
        context: nil
    )
    .frame(width: 400, height: 600)
}
