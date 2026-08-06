//
//  BatchAIAnalysisView.swift
//  SwiftMandarin
//
//  Shared macOS/iOS/iPadOS controls for independent AI-analysis and
//  persistent MiniMax-audio batch queues.
//

import SwiftUI

struct BatchAIAnalysisControls: View {
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var controller = BatchExplanationController.shared
    @State private var autoAnalysis = AutoAnalysisCoordinator.shared
    @State private var settings = AIModelSettings.shared
    @State private var preferences = AppPreferences.shared
    @State private var generatedAudio = GeneratedSpeechStore.shared

    @State private var generateAudio = false
    @State private var audioScope: BatchAudioScope = .bothLanguages
    @State private var isPreparing = false
    @State private var pendingPlan: BatchRunPlan?
    @State private var preparationError: String?
    @State private var showingSavedAudioLibrary = false

    private var totalSaved: Int { savedTermsStore.terms.count }
    private var providerAvailable: Bool { settings.isAnyProviderAvailable }
    private var miniMaxKeyAvailable: Bool {
        !settings.apiKey(for: .minimax)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        let remaining = controller.remainingCount(from: savedTermsStore.terms)
        Group {
            overviewSection(remaining: remaining)
            automaticSection
            parallelismSection
            outputSection
            actionSection(remaining: remaining)
        }
        .task {
            await generatedAudio.refresh()
            // Opening this screen is the moment a user has just finished
            // configuring a provider, so retry anything the queue parked.
            autoAnalysis.kick()
        }
        .sheet(item: $pendingPlan) { plan in
            BatchAudioPreflightView(
                plan: plan,
                onStart: {
                    pendingPlan = nil
                    controller.start(plan: plan, concurrency: settings.batchConcurrency)
                },
                onCancel: { pendingPlan = nil }
            )
            .localizedSurface()
        }
        .sheet(isPresented: $showingSavedAudioLibrary) {
            GeneratedAudioLibraryView()
                .localizedSurface()
        }
        .alert("Batch Preparation Failed", isPresented: preparationErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(preparationError ?? String(localized: "The batch plan could not be prepared.", bundle: .appLanguage))
        }
    }

    private func overviewSection(remaining: Int) -> some View {
        Section {
            LabeledContent("Saved Words") {
                Text("\(totalSaved)").foregroundStyle(.secondary)
            }
            LabeledContent("Analyzed") {
                Text("\(max(0, totalSaved - remaining))").foregroundStyle(.secondary)
            }
            LabeledContent("Needs Analysis") {
                Text("\(remaining)")
                    .foregroundStyle(remaining > 0 ? .primary : .secondary)
                    .fontWeight(remaining > 0 ? .semibold : .regular)
            }
            LabeledContent("Saved AI Audio") {
                Text("\(generatedAudio.records.count)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Batch AI Analysis & Audio")
        } footer: {
            Text("Analyze missing saved words and optionally prepare persistent MiniMax pronunciation audio. Existing analyses and matching audio are reused.")
        }
    }

    /// Automatic analysis of newly saved words — the opt-in, always-running
    /// sibling of the reviewed batch. It shares the explanation cache with the
    /// batch, so whichever gets to a word first spares the other the work.
    private var automaticSection: some View {
        Section {
            Toggle("Auto-Translate New Words", isOn: $settings.autoAnalyzeNewTerms)

            if settings.autoAnalyzeNewTerms {
                LabeledContent("Queued") {
                    Text("\(autoAnalysis.outstandingCount)")
                        .monospacedDigit()
                        .foregroundStyle(autoAnalysis.outstandingCount > 0 ? .primary : .secondary)
                }
                LabeledContent("Analyzed Automatically") {
                    Text("\(autoAnalysis.analyzedCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                automaticStatusRow

                if autoAnalysis.rejectedByCapacity > 0 {
                    Label("\(autoAnalysis.rejectedByCapacity) words were not queued because the queue was full. Run the batch below to analyze them.", systemImage: "tray.full")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if autoAnalysis.isPaused {
                    Button {
                        autoAnalysis.resumeAfterFailures()
                    } label: {
                        Label("Resume Automatic Analysis", systemImage: "play.circle")
                    }
                }

                if autoAnalysis.outstandingCount > 0 {
                    Button(role: .destructive) {
                        autoAnalysis.clearQueue()
                    } label: {
                        Label("Clear Automatic Queue", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("Automatic Analysis")
        } footer: {
            automaticFooter
        }
    }

    @ViewBuilder
    private var automaticStatusRow: some View {
        switch autoAnalysis.status {
        case .analyzing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                if let word = autoAnalysis.currentWord, !word.isEmpty {
                    Text("Analyzing \(word)…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Analyzing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .waitingForProvider:
            Label("Waiting for an AI provider. Configure one in Settings → AI.", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .waitingForBatch:
            Label("Waiting for the reviewed batch run to finish.", systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .pausedAfterFailures:
            VStack(alignment: .leading, spacing: 4) {
                Label("Paused after repeated failures.", systemImage: "pause.circle")
                    .foregroundStyle(.orange)
                if let error = autoAnalysis.lastErrorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        case .idle:
            if let word = autoAnalysis.lastAnalyzedWord, !word.isEmpty {
                Text("Last analyzed: \(word)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var automaticFooter: some View {
        if settings.autoAnalyzeNewTerms {
            Text("Every word or phrase you save is translated and analyzed in the background by \(settings.effectiveProvider.displayName), so opening it later shows a finished analysis. Results go into the same store as a batch run, and no audio is ever generated automatically.")
        } else {
            Text("Turn this on to translate and analyze each word as you save it, instead of running a batch later. Words already saved are not analyzed — use the batch run for those.")
        }
    }

    private var parallelismSection: some View {
        Section {
            Stepper(value: $settings.batchConcurrency, in: AIModelSettings.batchConcurrencyRange) {
                LabeledContent("Analyses in Parallel") {
                    Text("\(settings.batchConcurrency)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(controller.isRunning)
        } header: {
            Text("Parallelism")
        } footer: {
            Text("This controls AI analysis only. MiniMax audio uses at most two workers and starts no more than one new request per second to reduce rate-limit errors.")
        }
    }

    private var outputSection: some View {
        Section {
            Toggle("Generate MiniMax Audio", isOn: $generateAudio)
                .disabled(controller.isRunning)

            if generateAudio {
                Picker("Audio Languages", selection: $audioScope) {
                    ForEach(BatchAudioScope.allCases) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
                .disabled(controller.isRunning)

                LabeledContent("Speech Model") {
                    Text(preferences.aiAudioModel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if audioScope == .bothLanguages || LocalizationManager.shared.learningIsChinese {
                    LabeledContent("Mandarin Voice") {
                        Text(preferences.aiAudioChineseVoice)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if audioScope == .bothLanguages || !LocalizationManager.shared.learningIsChinese {
                    LabeledContent("English Voice") {
                        Text(preferences.aiAudioEnglishVoice)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if !miniMaxKeyAvailable {
                    Label("Add a MiniMax API key in AI Audio settings.", systemImage: "key.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Output")
        } footer: {
            if generateAudio {
                Text("Before any new paid speech requests begin, a confirmation shows exact cache misses and characters. Spoken terms are sent to MiniMax; generated MP3s remain in the Saved Audio library for playback and export.")
            } else {
                Text("Audio generation is off. This run will only create missing AI analyses.")
            }
        }
    }

    @ViewBuilder
    private func actionSection(remaining: Int) -> some View {
        Section {
            if controller.isRunning {
                progressContent
                Button(role: .destructive) {
                    controller.cancel()
                } label: {
                    Label("Cancel Batch", systemImage: "stop.circle")
                }
            } else {
                startButton(remaining: remaining)
                lastRunSummary
            }
        } footer: {
            actionFooter(remaining: remaining)
        }
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if controller.analysisTotal > 0 {
                progressLane(
                    title: "AI Analysis",
                    value: controller.analysisProgress,
                    processed: controller.analysisProcessed,
                    total: controller.analysisTotal
                )
            }

            if controller.audioTotal > 0 {
                progressLane(
                    title: "MiniMax Audio",
                    value: controller.audioProgress,
                    processed: controller.audioProcessed,
                    total: controller.audioTotal
                )
            }

            HStack(spacing: 12) {
                Label("\(controller.analysesGenerated + controller.audioGenerated)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("\(controller.analysesGenerated + controller.audioGenerated) newly completed")
                if controller.audioCached > 0 {
                    Label("\(controller.audioCached)", systemImage: "bolt.fill")
                        .foregroundStyle(.blue)
                        .accessibilityLabel("\(controller.audioCached) audio clips already saved")
                }
                let failures = controller.analysesFailed + controller.audioFailed
                if failures > 0 {
                    Label("\(failures)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("\(failures) failed")
                }
                Spacer()
            }
            .font(.caption)

            if let word = controller.lastWord, !word.isEmpty {
                Text("Last: \(word)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Batch progress details")
    }

    private func progressLane(
        title: LocalizedStringKey,
        value: Double,
        processed: Int,
        total: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(processed) / \(total)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: value)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue("\(processed) of \(total) complete")
    }

    private func startButton(remaining: Int) -> some View {
        Button {
            prepareAndStart()
        } label: {
            HStack(spacing: 8) {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Preparing batch")
                }
                Label(startTitle(remaining: remaining), systemImage: generateAudio ? "waveform.badge.plus" : "sparkles")
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canStart(remaining: remaining))
    }

    private func canStart(remaining: Int) -> Bool {
        guard !isPreparing, totalSaved > 0 else { return false }
        if remaining > 0, !providerAvailable { return false }
        if generateAudio, !miniMaxKeyAvailable { return false }
        return remaining > 0 || generateAudio
    }

    private func startTitle(remaining: Int) -> LocalizedStringKey {
        if isPreparing { return "Preparing Batch…" }
        if generateAudio {
            return remaining > 0 ? "Review Analysis & Audio Batch" : "Review Audio Batch"
        }
        return remaining > 0 ? "Analyze \(remaining) Words" : "All Words Analyzed"
    }

    private func prepareAndStart() {
        guard !isPreparing else { return }
        isPreparing = true
        preparationError = nil
        Task { @MainActor in
            defer { isPreparing = false }
            do {
                let plan = try await controller.preparePlan(
                    from: savedTermsStore.terms,
                    includeAudio: generateAudio,
                    audioScope: audioScope
                )
                if generateAudio {
                    pendingPlan = plan
                } else {
                    controller.start(plan: plan, concurrency: settings.batchConcurrency)
                }
            } catch {
                preparationError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var lastRunSummary: some View {
        switch controller.status {
        case let .finished(summary):
            summaryContent(summary, outcome: .finished)
        case let .cancelled(summary):
            summaryContent(summary, outcome: .cancelled)
        case let .failed(summary):
            summaryContent(summary, outcome: .failed)
        default:
            EmptyView()
        }
    }

    private enum SummaryOutcome {
        case finished
        case cancelled
        case failed
    }

    @ViewBuilder
    private func summaryContent(
        _ summary: BatchRunSummary,
        outcome: SummaryOutcome
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            runSummary(summary, outcome: outcome)
            if summary.audioGenerated > 0 || summary.audioCached > 0 {
                Button {
                    showingSavedAudioLibrary = true
                } label: {
                    Label("Manage Saved Audio", systemImage: "music.note.list")
                }
            }
        }
    }

    private func runSummary(
        _ summary: BatchRunSummary,
        outcome: SummaryOutcome
    ) -> some View {
        let failures = summary.analysesFailed + summary.audioFailed
        let unattempted = summary.analysesUnattempted + summary.audioUnattempted
        let title: LocalizedStringKey
        let symbol: String
        let iconColor: Color
        switch outcome {
        case .finished:
            title = "Batch Complete"
            symbol = failures > 0 ? "checkmark.circle.badge.questionmark" : "checkmark.circle.fill"
            iconColor = failures > 0 ? .orange : .green
        case .cancelled:
            title = "Batch Cancelled"
            symbol = "stop.circle"
            iconColor = .secondary
        case .failed:
            title = "Batch Stopped"
            symbol = "exclamationmark.octagon.fill"
            iconColor = .red
        }
        return Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)
                Text("Analyses \(summary.analysesGenerated) · Audio \(summary.audioGenerated) new, \(summary.audioCached) saved · Failed \(failures) · Not attempted \(unattempted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(iconColor)
        }
    }

    @ViewBuilder
    private func actionFooter(remaining: Int) -> some View {
        if remaining > 0, !providerAvailable {
            Text("No AI provider is available. Configure one in Settings → AI to analyze words.")
                .foregroundStyle(.orange)
        } else if generateAudio, !miniMaxKeyAvailable {
            Text("A MiniMax API key is required for batch audio. Add it in AI Audio settings.")
                .foregroundStyle(.orange)
        } else if controller.isRunning {
            Text("You may leave this screen while the app remains active. Completed analyses and audio files are saved immediately; cancelling keeps finished work.")
        } else if let error = controller.lastErrorMessage {
            Text("Last error: \(error)")
                .foregroundStyle(.secondary)
        } else {
            Text("Analysis uses \(settings.effectiveProvider.displayName). MiniMax audio is opt-in and cache-first.")
        }
    }

    private var preparationErrorBinding: Binding<Bool> {
        Binding(
            get: { preparationError != nil },
            set: { if !$0 { preparationError = nil } }
        )
    }
}

private struct BatchAudioPreflightView: View {
    let plan: BatchRunPlan
    let onStart: () -> Void
    let onCancel: () -> Void

    private var audioPlan: BatchAudioPlan? { plan.audioPlan }

    var body: some View {
        NavigationStack {
            Form {
                Section("Work to Perform") {
                    LabeledContent("AI Analyses", value: "\(plan.analysisCount)")
                    LabeledContent("New MiniMax Clips", value: "\(plan.newAudioCount)")
                    LabeledContent("Already Saved", value: "\(plan.cachedAudioCount)")
                    LabeledContent("Characters Sent", value: "\(plan.totalNewAudioCharacters)")
                    if let audioPlan {
                        LabeledContent("Mandarin Clips", value: "\(audioPlan.newMandarinClipCount)")
                        LabeledContent("English Clips", value: "\(audioPlan.newEnglishClipCount)")
                    }
                }

                if let audioPlan {
                    Section("MiniMax Snapshot") {
                        // The content-closure form rather than `value:`, so the
                        // scope name goes through `Text`'s localizing initializer
                        // and follows the in-app language like the row's label.
                        LabeledContent("Languages") {
                            Text(audioPlan.scope.displayName)
                        }
                        LabeledContent("Speech Model", value: configuration?.model ?? "—")
                        if let mandarinVoice {
                            LabeledContent("Mandarin Voice", value: mandarinVoice)
                        }
                        if let englishVoice {
                            LabeledContent("English Voice", value: englishVoice)
                        }
                        Link(destination: pricingURL) {
                            Label("View MiniMax Speech Pricing", systemImage: "arrow.up.right.square")
                        }
                    }
                }

                Section {
                    Label("Up to \(plan.newAudioCount) new paid MiniMax requests will start. Matching saved clips are excluded, duplicate terms are deduplicated, and charges may apply.", systemImage: "creditcard")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Review Batch")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #elseif os(macOS)
            .formStyle(.grouped)
            .frame(minWidth: 440, minHeight: 470)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Batch", action: onStart)
                        .disabled(!plan.hasWork)
                }
            }
        }
    }

    private var configuration: MiniMaxSpeechConfiguration? {
        audioPlan?.allTargets.first?.identity.configuration
    }

    private var mandarinVoice: String? {
        audioPlan?.allTargets.first(where: \.isMandarin)?.identity.configuration.voiceID
    }

    private var englishVoice: String? {
        audioPlan?.allTargets.first(where: { !$0.isMandarin })?.identity.configuration.voiceID
    }

    private let pricingURL = URL(string: "https://platform.minimax.io/docs/guides/pricing-speech")!
}

struct BatchAIAnalysisView: View {
    var body: some View {
        Form {
            BatchAIAnalysisControls()
        }
        .navigationTitle("Batch AI Analysis & Audio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct BatchAIAnalysisStatusBadge: View {
    @State private var controller = BatchExplanationController.shared
    @State private var autoAnalysis = AutoAnalysisCoordinator.shared

    var body: some View {
        if controller.isRunning {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                Text("\(controller.processed)/\(controller.total)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Batch progress")
            .accessibilityValue("\(controller.processed) of \(controller.total) complete")
        } else if autoAnalysis.isEnabled, autoAnalysis.outstandingCount > 0 {
            // The automatic queue works without anyone pressing anything, so the
            // hub row is where a stalled or paused queue becomes visible.
            HStack(spacing: 6) {
                if autoAnalysis.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: autoAnalysis.isPaused ? "pause.circle" : "clock")
                        .foregroundStyle(autoAnalysis.isPaused ? .orange : .secondary)
                        .accessibilityHidden(true)
                }
                Text("\(autoAnalysis.outstandingCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Automatic analysis queue")
            .accessibilityValue("\(autoAnalysis.outstandingCount) words waiting")
        }
    }
}

#Preview {
    NavigationStack {
        BatchAIAnalysisView()
            .environment(SavedTermsStore.shared)
    }
}
