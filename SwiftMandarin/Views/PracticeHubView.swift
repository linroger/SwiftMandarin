//
//  PracticeHubView.swift
//  SwiftMandarin
//
//  Entry point for the Practice drills: multiple-choice quiz, dictation,
//  and (for Mandarin learners) tone-pair drills. Each card shows the best
//  round so far and when the drill was last played. Direction-aware: a
//  中文-UI user is learning English, so tone drills are hidden for them.
//

import SwiftUI

struct PracticeHubView: View {
    @State private var activeMode: PracticeMode?

    /// Singletons accessed via computed properties so @Observable tracking
    /// registers on every body evaluation (matches PhrasesView's pattern).
    private var practiceStore: PracticeStore { .shared }
    private var savedTermsStore: SavedTermsStore { .shared }
    private var localization: LocalizationManager { .shared }

    var body: some View {
        // No own NavigationStack: this screen is pushed by the Study hub (iOS)
        // or hosted in the sidebar's detail stack (macOS). Nesting a second
        // stack inside either doubled the navigation bar.
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                modeCards
                if usesMasteredWords {
                    masteredWordsFootnote
                }
                if usesStarterDeck {
                    starterDeckFootnote
                }
            }
            .padding()
        }
        .smPageBackground()
        .navigationTitle("Practice")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .navigationDestination(item: $activeMode) { mode in
            switch mode {
            case .quiz: QuizView()
            case .dictation: DictationView()
            case .toneDrill: TonePairDrillView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Quick rounds that turn your saved words into instinct.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - Mode cards

    private var modeCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeroActionRow(
                icon: "checklist",
                tint: .purple,
                titleKey: "Quiz",
                subtitleKey: subtitle(for: .quiz, description: L("Multiple choice from your vocabulary")),
                badge: badge(for: .quiz)
            ) {
                activeMode = .quiz
            }
            HeroActionRow(
                icon: "ear.and.waveform",
                tint: .orange,
                titleKey: "Dictation",
                subtitleKey: subtitle(for: .dictation, description: L("Listen and type what you hear")),
                badge: badge(for: .dictation)
            ) {
                activeMode = .dictation
            }
            // Tone drills train Mandarin tone perception — meaningless for a
            // 中文-UI user, who is learning English.
            if localization.learningIsChinese {
                HeroActionRow(
                    icon: "waveform.path.ecg",
                    tint: .pink,
                    titleKey: "Tone Drills",
                    subtitleKey: subtitle(for: .toneDrill, description: L("Train your ear for tones")),
                    badge: badge(for: .toneDrill)
                ) {
                    activeMode = .toneDrill
                }
            }
        }
    }

    /// Best round so far, as a compact "8/10" badge.
    private func badge(for mode: PracticeMode) -> String? {
        practiceStore.bestScore(mode: mode)?.scoreText
    }

    /// Fixed drill description plus a second line with the last-played
    /// relative date. Both pieces are localized up front (via `L`), so the
    /// combined runtime string passes through `LocalizedStringKey`'s
    /// identity fallback unchanged.
    private func subtitle(for mode: PracticeMode, description: String) -> LocalizedStringKey {
        guard let last = practiceStore.lastResult(mode: mode) else {
            return LocalizedStringKey(description)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = localization.locale
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: last.date, relativeTo: Date())
        let lastPlayed = String(format: L("Last played %@"), relative)
        return LocalizedStringKey(description + "\n" + lastPlayed)
    }

    // MARK: - Starter-deck footnote

    /// Whether the drills are drawing on words the learner already marked
    /// mastered, because fewer than four are still in progress.
    private var usesMasteredWords: Bool {
        PracticeStore.poolIncludesMasteredWords
    }

    /// Whether the quiz/dictation pool is currently topped up with the
    /// built-in starter deck (fewer than 4 quizzable saved terms in all).
    private var usesStarterDeck: Bool {
        PracticeStore.poolIncludesStarterDeck
    }

    private var masteredWordsFootnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "checkmark.seal")
                .font(.caption)
            Text("Drills use the words you are still learning. Mastered words rejoin while fewer than four are in progress.")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    private var starterDeckFootnote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption)
            Text("Built-in starter phrases fill in while your vocabulary grows.")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Shared round summary

/// End-of-round screen shared by all three drills: score ring, celebration
/// on a ≥90% round, a drill-specific detail section, and a restart button.
struct PracticeRoundSummary<Detail: View>: View {
    let score: Int
    let total: Int
    let onPracticeAgain: () -> Void
    @ViewBuilder var detail: Detail

    private var ratio: Double {
        total > 0 ? Double(score) / Double(total) : 0
    }

    /// Matches the quiz's "9 out of 10" celebration bar across round lengths.
    private var celebrates: Bool {
        total > 0 && ratio >= 0.9
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    GoalRing(progress: ratio, lineWidth: 12, size: 132)
                    VStack(spacing: 2) {
                        Text(verbatim: "\(score)/\(total)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .monospacedDigit()
                        Text("correct")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if celebrates {
                        CelebrationBurst()
                    }
                }
                .padding(.top, 24)

                // if/else rather than a ternary inside Text so each string
                // stays a literal LocalizedStringKey the catalog can extract.
                Group {
                    if celebrates {
                        Text("Outstanding round!")
                    } else {
                        Text("Round complete")
                    }
                }
                .font(.title3.weight(.semibold))

                detail

                Button(action: onPracticeAgain) {
                    Label("Practice again", systemImage: "arrow.counterclockwise")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                }
                .glassProminentButtonStyleCompat()
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PracticeHubView()
            .environment(SavedTermsStore.shared)
    }
}
