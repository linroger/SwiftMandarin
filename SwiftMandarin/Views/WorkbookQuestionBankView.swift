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
            case .all: return "全部 · All"
            case .fromWorkbook: return "作业 · Workbook"
            case .generated: return "生成 · Generated"
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
            .navigationTitle("题库 · Review Bank")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showGenerator = true
                    } label: {
                        Label("生成 · Generate", systemImage: "sparkles")
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
                    }
                }
                #endif
            }
            .sheet(isPresented: $showGenerator) {
                ReviewQuestionGeneratorView()
                    .localizedSurface()
            }
            .confirmationDialog("清空题库 · Clear the review bank?",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空 · Clear all", role: .destructive) { bank.clear() }
                Button("取消 · Cancel", role: .cancel) { }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                Picker("筛选 · Filter", selection: $filter) {
                    ForEach(BankFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }

            Section {
                if filtered.isEmpty {
                    Text("此筛选下没有题目 · No questions in this filter")
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
                Text("\(filtered.count) 题 · \(filtered.count) questions")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("题库为空 · Review Bank is empty", systemImage: "tray")
        } description: {
            Text("批改作业后，点「加入题库」把题目保存到这里，以便日后复习和生成新练习。\nGrade a workbook, then tap “Add to Bank” on a question to save it here for review and to generate fresh practice.")
        } actions: {
            Button("完成 · Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
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
            .navigationTitle("生成练习 · Generate Practice")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var providerBanner: some View {
        if aiSettings.isAnyProviderAvailable {
            Label("由 \(aiSettings.effectiveProvider.displayName) 生成 · Powered by \(aiSettings.effectiveProvider.displayName)",
                  systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.green)
                .fitSingleLine()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("未配置 AI · No AI provider configured", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Text("在「设置 → AI」中配置一个 AI 提供方即可生成练习题。\nConfigure an AI provider in Settings → AI to generate questions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper(value: $count, in: 1...20) {
                Text("题目数量 · Questions: \(count)")
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("分类标签（可选）· Subject tag (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Unit 3 / 动词时态", text: $subject)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("自定义提示（可选）· Custom instructions (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. focus on past tense; keep them short.",
                          text: $instructions, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
            }

            Text("将根据题库中的 \(bank.questions.count) 道题生成新题（侧重错题）。\nNew questions are modeled on your \(bank.questions.count) saved questions, focusing on ones you missed.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.background).shadow(color: .black.opacity(0.05), radius: 8, y: 4))
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            Label(isGenerating ? "生成中…" : (generated.isEmpty ? "生成练习 · Generate" : "重新生成 · Regenerate"),
                  systemImage: "sparkles")
                .fitSingleLine()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canGenerate)
    }

    private var progress: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large)
            Text("正在生成练习题…")
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
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
    }

    private var resultsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(generated.count) 道新题 · \(generated.count) new questions")
                    .font(.headline)
                Spacer()
                Button {
                    saveAll()
                } label: {
                    Label("全部保存 · Save all", systemImage: "tray.and.arrow.down.fill")
                        .font(.subheadline)
                        .fitSingleLine()
                }
                .buttonStyle(.bordered)
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
                    errorMessage = String(localized: "The model returned no questions. Try again or adjust the instructions.")
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
                    Label(isRevealed ? "隐藏答案 · Hide" : "显示答案 · Show answer",
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
                    Label(isSaved ? "已保存 · Saved" : "保存 · Save",
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
        .background(RoundedRectangle(cornerRadius: 14).fill(.background).shadow(color: .black.opacity(0.05), radius: 6, y: 3))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}
