//
//  WorkbookQuestionBankView.swift
//  SwiftMandarin
//
//  The Photo tab's review-question database. Lists questions saved from graded
//  workbooks (and AI-generated practice), lets the learner read them aloud,
//  delete them, and generate fresh practice questions modeled on what they have
//  studied. Kept entirely within the Photo tab per the feature design.
//

import SwiftUI

struct WorkbookQuestionBankView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bank = WorkbookQuestionBankStore.shared
    @State private var filter: BankFilter = .all
    @State private var showGenerator = false
    @State private var showClearConfirm = false

    enum BankFilter: String, CaseIterable, Identifiable {
        case all, fromWorkbook, generated
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .all: return "All"
            case .fromWorkbook: return "Workbook"
            case .generated: return "Generated"
            }
        }
    }

    private var filtered: [WorkbookQuestion] {
        switch filter {
        case .all: return bank.questions
        case .fromWorkbook: return bank.questions.filter { !$0.isGenerated }
        case .generated: return bank.questions.filter { $0.isGenerated }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bank.questions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Review Bank")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showGenerator = true
                    } label: {
                        Label("Generate", systemImage: "sparkles")
                    }
                    .disabled(bank.questions.isEmpty)
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    if !bank.questions.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(Text("Clear All"))
                    }
                }
                #endif
            }
            .sheet(isPresented: $showGenerator) {
                ReviewQuestionGeneratorView()
                    .localizedSurface()
            }
            .confirmationDialog("Clear the review bank?",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear all", role: .destructive) { bank.clear() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(BankFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }

            Section {
                if filtered.isEmpty {
                    Text("No questions in this filter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { question in
                        BankQuestionRow(question: question)
                    }
                    .onDelete { offsets in
                        // Map filtered offsets back to store removal by id.
                        let ids = offsets.map { filtered[$0].id }
                        for id in ids {
                            if let q = bank.questions.first(where: { $0.id == id }) { bank.remove(q) }
                        }
                    }
                }
            } header: {
                Text("\(filtered.count) questions")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        // Rows stay system List rows (no per-row glass); the page backdrop
        // shows through around them.
        .scrollContentBackground(.hidden)
        .smPageBackground()
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Review Bank is empty", systemImage: "tray")
        } description: {
            Text("Grade a workbook, then tap “Add to Bank” on a question to save it here for review and to generate fresh practice.")
        } actions: {
            Button("Done") { dismiss() }
                .glassProminentButtonStyleCompat()
        }
        .smPageBackground()
    }
}

// MARK: - Bank Question Row

private struct BankQuestionRow: View {
    let question: WorkbookQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Provenance + correctness badge.
                Image(systemName: badgeSymbol)
                    .foregroundStyle(badgeColor)
                    .font(.subheadline)
                    .accessibilityLabel(Text(badgeLabel))

                VStack(alignment: .leading, spacing: 4) {
                    if !question.question.isEmpty {
                        Text(question.question)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    if !question.correctAnswer.isEmpty {
                        Text("✓ \(question.correctAnswer)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if !question.isGenerated, !question.wasCorrect, !question.studentAnswer.isEmpty {
                        Text("✗ \(question.studentAnswer)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if question.hasVocab {
                        Text("📖 \(question.vocabTerm)\(question.vocabMeaning.isEmpty ? "" : " · \(question.vocabMeaning)")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !question.explanation.isEmpty {
                        Text(question.explanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 4)

                if !question.spokenSentence.isEmpty {
                    Button {
                        SpeechService.speakAuto(question.spokenSentence)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Read aloud"))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var badgeSymbol: String {
        if question.isGenerated { return "sparkles" }
        return question.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var badgeColor: Color {
        if question.isGenerated { return .purple }
        return question.wasCorrect ? .green : .red
    }

    /// What the badge means, for VoiceOver (the symbol alone is silent).
    private var badgeLabel: LocalizedStringKey {
        if question.isGenerated { return "Generated" }
        return question.wasCorrect ? "Correct" : "Incorrect"
    }
}

// MARK: - Review Question Generator

/// Generates fresh practice questions from the saved bank and lets the learner
/// reveal answers, hear them, and save the keepers back into the bank.
struct ReviewQuestionGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bank = WorkbookQuestionBankStore.shared
    @State private var aiSettings = AIModelSettings.shared

    @State private var count: Int = 8
    @State private var instructions: String = ""
    @State private var subject: String = ""
    @State private var isGenerating = false
    @State private var generated: [GeneratedReviewQuestion] = []
    @State private var revealed: Set<UUID> = []
    @State private var savedIDs: Set<UUID> = []
    @State private var errorMessage: String?

    private var canGenerate: Bool {
        !bank.questions.isEmpty && aiSettings.isAnyProviderAvailable && !isGenerating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    providerBanner
                    optionsCard
                    generateButton

                    if isGenerating { progress }
                    if let errorMessage { errorBox(errorMessage) }
                    if !generated.isEmpty { resultsSection }
                }
                .padding()
            }
            .smPageBackground()
            .navigationTitle("Generate Practice")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var providerBanner: some View {
        if aiSettings.isAnyProviderAvailable {
            Label("Powered by \(aiSettings.effectiveProvider.displayName)",
                  systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.green)
                .fitSingleLine()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("No AI provider configured", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("Configure an AI provider in Settings → AI to generate questions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffectCompat(cornerRadius: 12, tint: Color.orange.opacity(0.25))
        }
    }

    /// The generate button's title, hoisted so each branch is a plain key.
    private var generateButtonTitle: LocalizedStringKey {
        if isGenerating { return "Generating…" }
        return generated.isEmpty ? "Generate" : "Regenerate"
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper(value: $count, in: 1...20) {
                Text("Questions: \(count)")
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Subject tag (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Unit 3 / verb tenses", text: $subject)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Custom instructions (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. focus on past tense; keep them short.",
                          text: $instructions, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }

            Text("New questions are modeled on your \(bank.questions.count) saved questions, focusing on ones you missed.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .smCardSurface(cornerRadius: 16)
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            Label(generateButtonTitle, systemImage: "sparkles")
                .fitSingleLine()
                .frame(maxWidth: .infinity)
        }
        .glassProminentButtonStyleCompat()
        .controlSize(.large)
        .disabled(!canGenerate)
    }

    private var progress: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("Generating practice questions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorBox(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassEffectCompat(cornerRadius: 12, tint: Color.red.opacity(0.2))
    }

    private var resultsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(generated.count) new questions")
                    .font(.headline)
                Spacer()
                Button {
                    saveAll()
                } label: {
                    Label("Save all", systemImage: "tray.and.arrow.down.fill")
                        .font(.subheadline)
                        .fitSingleLine()
                }
                .glassButtonStyleCompat()
                .controlSize(.small)
            }

            ForEach(generated) { question in
                GeneratedQuestionCard(
                    question: question,
                    isRevealed: revealed.contains(question.id),
                    isSaved: savedIDs.contains(question.id),
                    onToggleReveal: {
                        if revealed.contains(question.id) { revealed.remove(question.id) }
                        else { revealed.insert(question.id) }
                    },
                    onSave: { save(question) }
                )
            }
        }
    }

    // MARK: - Actions

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        let source = bank.questions
        let wanted = count
        let custom = instructions
        do {
            let questions = try await AIWordExplanationService.shared.generateReviewQuestions(
                from: source, count: wanted, customInstructions: custom.isEmpty ? nil : custom
            )
            await MainActor.run {
                generated = questions
                revealed = []
                savedIDs = []
                isGenerating = false
                if questions.isEmpty {
                    errorMessage = String(localized: "The model returned no questions. Try again or adjust the instructions.", bundle: .appLanguage)
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    private func save(_ question: GeneratedReviewQuestion) {
        let tag = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = bank.add(WorkbookQuestion(generated: question, subject: tag))
        _ = savedIDs.insert(question.id)
    }

    private func saveAll() {
        for question in generated { save(question) }
    }
}

// MARK: - Generated Question Card

private struct GeneratedQuestionCard: View {
    let question: GeneratedReviewQuestion
    let isRevealed: Bool
    let isSaved: Bool
    let onToggleReveal: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.prompt)
                .font(.body)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRevealed {
                if !question.answer.isEmpty {
                    Text("✓ \(question.answer)")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
                if !question.fullSentence.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(question.fullSentence)
                            .font(.subheadline)
                        Spacer(minLength: 4)
                        Button {
                            SpeechService.speakAuto(question.spokenSentence)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Read aloud"))
                    }
                }
                if !question.explanation.isEmpty {
                    Text(question.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button {
                    onToggleReveal()
                } label: {
                    Label(isRevealed ? "Hide answer" : "Show answer",
                          systemImage: isRevealed ? "eye.slash" : "eye")
                        .font(.caption)
                        .fitSingleLine()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    onSave()
                } label: {
                    Label(isSaved ? "Saved" : "Save",
                          systemImage: isSaved ? "tray.full.fill" : "tray.and.arrow.down")
                        .font(.caption)
                        .fitSingleLine()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isSaved)
            }
        }
        .padding()
        // Solid, not glass: up to 20 of these stack on the page, so they stay
        // opaque cards and their small buttons stay bordered.
        .smSolidCardSurface(cornerRadius: 14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}
