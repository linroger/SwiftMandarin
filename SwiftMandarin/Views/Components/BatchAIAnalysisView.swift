//
//  BatchAIAnalysisView.swift
//  SwiftMandarin
//
//  Settings UI for the background batch AI word-analysis. The controls are
//  factored into `BatchAIAnalysisControls` (a set of `Section`s) so the exact
//  same UI embeds in the iOS Settings push-screen and the macOS Settings tab.
//  All state lives in `BatchExplanationController.shared`, so the progress bar,
//  live count, and Cancel button keep working and stay current when the user
//  leaves and returns to this screen while a run is in progress.
//

import SwiftUI

// MARK: - Reusable controls (Sections)

/// The batch-analysis controls as a group of `Section`s, embeddable in any
/// `Form`/`List`. Observes the shared controller for live progress.
struct BatchAIAnalysisControls: View {
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @State private var controller = BatchExplanationController.shared
    @State private var settings = AIModelSettings.shared

    private var totalSaved: Int { savedTermsStore.terms.count }
    private var providerAvailable: Bool { settings.isAnyProviderAvailable }

    var body: some View {
        // Compute the unprocessed count ONCE per render and thread it through;
        // recomputing it per subview would multiply the cache scan on every
        // progress tick during a batch.
        let remaining = controller.remainingCount(from: savedTermsStore.terms)
        return Group {
            overviewSection(remaining: remaining)
            batchSizeSection
            actionSection(remaining: remaining)
        }
    }

    // MARK: Overview

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
        } header: {
            Text("Batch AI Analysis")
        } footer: {
            Text("Analyze every saved word with the current AI model. Only words that haven't been analyzed yet are processed, and each result is saved so opening that word later is instant.")
        }
    }

    // MARK: Batch size

    private var batchSizeSection: some View {
        Section {
            Stepper(value: $settings.batchConcurrency, in: AIModelSettings.batchConcurrencyRange) {
                LabeledContent("Words in Parallel") {
                    Text("\(settings.batchConcurrency)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(controller.isRunning)
        } header: {
            Text("Parallelism")
        } footer: {
            Text("How many words to analyze at the same time. Higher is faster but more likely to hit a cloud provider's rate limits. Changes apply to the next run.")
        }
    }

    // MARK: Action / progress

    @ViewBuilder
    private func actionSection(remaining: Int) -> some View {
        Section {
            if controller.isRunning {
                progressContent
                Button(role: .destructive) {
                    controller.cancel()
                } label: {
                    Label("Cancel", systemImage: "stop.circle")
                }
            } else {
                startButton(remaining: remaining)
                lastRunSummary
            }
        } footer: {
            actionFooter
        }
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analyzing…")
                .font(.subheadline)

            // Determinate bar (value in 0...1). Kept label-free to avoid the
            // initializer where a trailing closure binds to `total`.
            ProgressView(value: controller.progress)

            HStack(spacing: 12) {
                Label("\(controller.generated)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if controller.failed > 0 {
                    Label("\(controller.failed)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("\(controller.processed) / \(controller.total)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
    }

    private func startButton(remaining: Int) -> some View {
        Button {
            controller.start(concurrency: settings.batchConcurrency)
        } label: {
            Label(
                remaining > 0 ? "Analyze \(remaining) Words" : "All Words Analyzed",
                systemImage: "sparkles"
            )
            .fitSingleLine()
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(remaining == 0 || !providerAvailable)
    }

    /// A one-line summary of the most recently completed/cancelled run, shown
    /// until the next run starts. `nil` while idle or running.
    @ViewBuilder
    private var lastRunSummary: some View {
        switch controller.status {
        case let .finished(generated, failed, _) where generated > 0 || failed > 0:
            Label {
                if failed > 0 {
                    Text("Analyzed \(generated), \(failed) failed")
                } else {
                    Text("Analyzed \(generated) words")
                }
            } icon: {
                Image(systemName: failed > 0 ? "checkmark.circle.badge.questionmark" : "checkmark.circle.fill")
                    .foregroundStyle(failed > 0 ? .orange : .green)
            }
            .font(.subheadline)
        case let .cancelled(generated):
            Label("Cancelled after \(generated)", systemImage: "stop.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionFooter: some View {
        if !providerAvailable {
            Text("No AI provider is available. Configure one in Settings → AI to analyze words.")
                .foregroundStyle(.orange)
        } else if controller.isRunning {
            Text("Running in the background using \(settings.effectiveProvider.displayName). You can leave this screen — the analysis keeps going and you'll see the live count when you return.")
        } else if let error = controller.lastErrorMessage {
            Text("Last error: \(error)")
                .foregroundStyle(.secondary)
        } else {
            Text("Using \(settings.effectiveProvider.displayName).")
        }
    }
}

// MARK: - Standalone screen (iOS push / generic)

/// Full-screen wrapper used as a navigation destination (iOS Settings hub).
struct BatchAIAnalysisView: View {
    var body: some View {
        Form {
            BatchAIAnalysisControls()
        }
        .navigationTitle("Batch AI Analysis")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Compact live status row (for the More hub)

/// A trailing accessory that shows live batch progress, so the user sees a run
/// is still going even from the Settings list root. Renders nothing when idle.
struct BatchAIAnalysisStatusBadge: View {
    @State private var controller = BatchExplanationController.shared

    var body: some View {
        if controller.isRunning {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("\(controller.processed)/\(controller.total)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BatchAIAnalysisView()
            .environment(SavedTermsStore.shared)
    }
}
