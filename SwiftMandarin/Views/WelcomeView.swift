//
//  WelcomeView.swift
//  SwiftMandarin
//
//  Three-step first-run flow: (1) welcome + learning-direction choice,
//  (2) daily review goal, (3) optional AI features. Paged on iOS,
//  button-driven on macOS. Completion sets "hasCompletedWelcome" so the
//  Home tab never re-presents it.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @AppStorage("dailyGoal") private var dailyGoalSetting = 20

    /// Reading the singleton's properties in `body` registers Observation
    /// dependencies, so direction-card selection updates live.
    private var preferences: AppPreferences { .shared }

    private let goalOptions = [10, 20, 30, 50]

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            TabView(selection: $step) {
                welcomeStep.tag(0)
                goalStep.tag(1)
                aiStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #else
            Group {
                switch step {
                case 0: welcomeStep
                case 1: goalStep
                default: aiStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif

            controls
        }
        .background(SMTheme.pageBackground)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 580)
        #endif
    }

    // MARK: - Step 1: Welcome + direction

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(SMTheme.heroGradient)
                    .padding(.top, 28)

                Text("Welcome to SwiftMandarin")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Translate anything, scan the world around you, read at your level, and remember it all with a few minutes of daily review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose your learning direction")
                        .font(.headline)
                        .padding(.top, 10)
                    directionCard(.englishToMandarin)
                    directionCard(.mandarinToEnglish)
                    bilingualOption
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
    }

    /// Big selectable card for one of the two single-direction modes. The
    /// labels come from `LearnerMode.displayName`, which is deliberately
    /// written in each audience's own language so the choice is readable
    /// before any language preference exists.
    private func directionCard(_ mode: LearnerMode) -> some View {
        let isSelected = preferences.learnerMode == mode
        return Button {
            preferences.learnerMode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.iconName)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(isSelected ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(Color.accentColor)
                Text(verbatim: mode.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .padding(14)
            .background(SMTheme.cardFill, in: RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Smaller tertiary option for studying both languages at once.
    private var bilingualOption: some View {
        let isSelected = preferences.learnerMode == .bilingual
        return Button {
            preferences.learnerMode = .bilingual
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                Text(verbatim: LearnerMode.bilingual.displayName)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Daily goal

    private var goalStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.orange.gradient)
                    .padding(.top, 28)

                Text("Set your daily goal")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Small daily sessions beat marathon cramming. You can change this anytime from Home.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(goalOptions, id: \.self) { goal in
                        goalCard(goal)
                    }
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
    }

    private var effectiveGoal: Int {
        dailyGoalSetting <= 0 ? 20 : dailyGoalSetting
    }

    private func goalCard(_ goal: Int) -> some View {
        let isSelected = effectiveGoal == goal
        return Button {
            dailyGoalSetting = goal
        } label: {
            VStack(spacing: 4) {
                Text("\(goal)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                Text("reviews a day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fitSingleLine()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(SMTheme.cardFill, in: RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Optional AI

    private var aiStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.purple.gradient)
                    .padding(.top, 28)

                Text("Optional AI superpowers")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Word explanations, graded stories, conversation practice, and workbook grading come alive with AI. They work with Apple Intelligence, a local Ollama server, or any cloud key you add later in Settings → AI.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 12) {
                    aiFeatureRow(icon: "text.magnifyingglass", titleKey: "Deep word explanations")
                    aiFeatureRow(icon: "book.pages", titleKey: "Stories at your level")
                    aiFeatureRow(icon: "bubble.left.and.bubble.right", titleKey: "A patient conversation partner")
                    aiFeatureRow(icon: "checkmark.rectangle.stack", titleKey: "Workbook grading")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SMTheme.cardPadding)
                .background(SMTheme.cardFill, in: RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
                .padding(.top, 10)

                Text("No account needed — everything else works without AI.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private func aiFeatureRow(icon: String, titleKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 28)
                .foregroundStyle(Color.purple)
            Text(titleKey)
                .font(.subheadline)
        }
    }

    // MARK: - Navigation controls

    private var controls: some View {
        HStack(spacing: 12) {
            #if os(macOS)
            if step > 0 {
                Button("Back") {
                    withAnimation { step -= 1 }
                }
            }
            Spacer()
            #endif
            primaryButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if step < 2 {
            Button {
                withAnimation { step += 1 }
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    #if os(iOS)
                    .frame(maxWidth: .infinity)
                    #else
                    .padding(.horizontal, 12)
                    #endif
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button {
                UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
                dismiss()
            } label: {
                Text("Start learning")
                    .fontWeight(.semibold)
                    #if os(iOS)
                    .frame(maxWidth: .infinity)
                    #else
                    .padding(.horizontal, 12)
                    #endif
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
