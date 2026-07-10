//
//  HomeView.swift
//  SwiftMandarin
//
//  The Home tab: a daily dashboard that greets the learner, shows today's
//  goal progress, surfaces a deterministic Word of the Day, offers one-tap
//  routes into the app's core flows, and recaps the week and recent saves.
//  Every section is direction-aware (English UI = learning Mandarin, 中文 UI
//  = learning English) via LocalizationManager.learningIsChinese.
//

import SwiftUI

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(LearningProgressStore.self) private var progressStore
    @Environment(LearningActivityStore.self) private var activityStore
    @Environment(\.scenePhase) private var scenePhase

    /// Raw stored goal. 0 / absent means "never set" and falls back to 20.
    @AppStorage("dailyGoal") private var dailyGoalSetting = 20
    @State private var showGoalPicker = false
    @State private var showWelcome = false
    @State private var readerStore = ReaderStore.shared
    @State private var continueReadingTarget: ReaderText?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroHeader
                    continueReadingSlot
                    wordOfTheDaySection
                    quickActionsRow
                    weekSection
                    recentSavesSection
                }
                .padding()
                // Cap the reading width and center it so Home reads as a tidy
                // dashboard on a wide macOS/iPad window instead of a lonely
                // strip hugging the left edge.
                .frame(maxWidth: SMTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(SMTheme.pageBackground)
            .navigationTitle("Home")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(item: $continueReadingTarget) { text in
                ReaderSessionView(text: text)
            }
        }
        .onAppear {
            activityStore.refreshDayRollover()
            progressStore.refreshDailyCounters()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                activityStore.refreshDayRollover()
                progressStore.refreshDailyCounters()
            }
        }
        .task {
            // First-run: let the tab bar settle before presenting the welcome
            // flow so the sheet animates over a fully laid-out Home screen.
            guard !UserDefaults.standard.bool(forKey: "hasCompletedWelcome") else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            showWelcome = true
        }
        .sheet(isPresented: $showWelcome, onDismiss: {
            // Any dismissal counts as completion — including a swipe-away —
            // so the welcome flow never nags on the next return to Home. (The
            // in-flow "Start learning" button also sets this; setting it here
            // makes the gesture stick.)
            UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        }) {
            WelcomeView()
                .localizedSurface()
        }
        .sheet(isPresented: $showGoalPicker) {
            GoalPickerSheet()
                .localizedSurface()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Derived state

    /// Effective daily review goal (stored 0/absent → default 20).
    private var dailyGoal: Int {
        dailyGoalSetting <= 0 ? 20 : dailyGoalSetting
    }

    private var reviewsToday: Int {
        activityStore.reviewsToday
    }

    /// Everything reviewable: the built-in starter deck plus saved vocabulary.
    private var allCards: [LearningCard] {
        LearningDeck.cards + savedTermsStore.terms.map { LearningCard(from: $0) }
    }

    /// What today's session would actually contain: genuinely due reviews
    /// plus new cards within the remaining daily budget. Counting the entire
    /// never-reviewed backlog (thousands for a long-time user) as "due" would
    /// be demoralizing rather than motivating.
    private var dueCount: Int {
        progressStore.pendingReviewCount(from: allCards)
    }

    /// Deterministic per-day index into a pool of `count` items. Hashes
    /// today's date key with FNV-1a instead of `String.hashValue`, which is
    /// seeded per process and would silently pick a different "word of the
    /// day" on every launch. Reading `dayChangeToken` also registers an
    /// observation so the pick rolls over at midnight.
    private func dailyIndex(count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in activityStore.dayChangeToken.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % UInt64(count))
    }

    // MARK: - Greeting header

    private var greetingKey: LocalizedStringKey {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    /// Rotating bilingual flavor line. Deliberately shown verbatim (not run
    /// through the string catalog): each line already pairs the learning
    /// language with the native gloss, so it reads correctly for both
    /// audiences by construction.
    private var flavorLine: String {
        let lines: [String]
        if LocalizationManager.shared.learningIsChinese {
            lines = [
                "每天进步一点点 · A little progress every day",
                "千里之行，始于足下 · Every journey starts with a step",
                "熟能生巧 · Practice makes perfect"
            ]
        } else {
            lines = [
                "A little progress every day · 每天进步一点点",
                "Practice makes perfect · 熟能生巧",
                "Every journey starts with a step · 千里之行，始于足下"
            ]
        }
        return lines[dailyIndex(count: lines.count)]
    }

    /// A single colored hero that greets the learner and shows today's goal
    /// ring plus the primary "Review now" call to action. Combining the
    /// greeting and today's progress into one gradient surface gives Home a
    /// focal point and color instead of a wall of same-tone gray cards.
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingKey)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .fitSingleLine()
                    Text(verbatim: flavorLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 8)
                heroStreakBadge
            }

            HStack(spacing: 18) {
                ZStack {
                    GoalRing(
                        progress: Double(reviewsToday) / Double(dailyGoal),
                        trackColor: .white.opacity(0.28),
                        progressStyle: AnyShapeStyle(Color.white)
                    )
                    Text("\(reviewsToday)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(reviewsToday) of \(dailyGoal) reviews today"))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("\(reviewsToday) of \(dailyGoal) reviews today")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                        Button {
                            showGoalPicker = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Change daily goal"))
                    }

                    Button {
                        AppRouteStore.shared.triggerReview(mode: "due", source: "home")
                    } label: {
                        HStack(spacing: 6) {
                            Text("Review now")
                                .fontWeight(.semibold)
                            if dueCount > 0 {
                                Text("\(dueCount)")
                                    .font(.caption.weight(.bold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.16), in: Capsule())
                            }
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SMTheme.heroGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    /// Streak flame + count styled for the colored hero (translucent white
    /// capsule rather than the material capsule used on plain surfaces).
    private var heroStreakBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .foregroundStyle(activityStore.todayActivity.activityScore > 0 ? Color.orange : Color.white)
            Text("\(activityStore.currentStreak)")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Day streak: \(activityStore.currentStreak)"))
    }

    // MARK: - Continue reading

    /// Card resuming the most recently opened Reader text, pushing straight
    /// into the reading session. Hidden until the library has been used.
    @ViewBuilder var continueReadingSlot: some View {
        if let recent = readerStore.mostRecentlyRead {
            Button {
                continueReadingTarget = recent
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: AppTab.reader.icon)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Color.indigo.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(Color.indigo)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Continue Reading")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        // The user's own title — never a localization key.
                        Text(verbatim: recent.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fitSingleLine()
                        SMProgressBar(progress: recent.progressFraction, tint: .indigo)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(SMTheme.cardPadding)
                .smCardSurface()
                .contentShape(RoundedRectangle(cornerRadius: SMTheme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Word of the Day

    /// Direction-aware display bundle for the daily word.
    private struct DailyWord {
        let headline: String
        let gloss: String
        let pinyin: String?
    }

    /// Deterministic daily pick: the user's own vocabulary once it is big
    /// enough to feel personal (≥ 10 terms), otherwise the starter deck.
    private var dailyWord: DailyWord? {
        let terms = savedTermsStore.terms
        if terms.count >= 10 {
            let term = terms[dailyIndex(count: terms.count)]
            return DailyWord(
                headline: term.headlineText,
                gloss: term.glossText,
                pinyin: term.showsPinyin ? term.pinyin : nil
            )
        }
        let cards = LearningDeck.cards
        guard !cards.isEmpty else { return nil }
        let card = cards[dailyIndex(count: cards.count)]
        if LocalizationManager.shared.learningIsChinese {
            return DailyWord(
                headline: card.chinese,
                gloss: card.english,
                pinyin: card.pinyin ?? PinyinConverter.convert(card.chinese)
            )
        } else {
            // 中文-native learner: English is the headline, Mandarin the
            // gloss, and pinyin is never shown as native furniture.
            return DailyWord(headline: card.english, gloss: card.chinese, pinyin: nil)
        }
    }

    @ViewBuilder
    private var wordOfTheDaySection: some View {
        if let word = dailyWord {
            SMCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Word of the Day", systemImage: "sparkles")
                            .font(.headline)
                        Spacer()
                        Button {
                            SpeechService.speakAuto(word.headline)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Speak"))
                    }

                    Text(word.headline)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)

                    if let pinyin = word.pinyin {
                        Text(PinyinConverter.coloredPinyin(fromPinyin: pinyin))
                            .font(.title3)
                    }

                    if !word.gloss.isEmpty {
                        Text(word.gloss)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Button {
                        AppRouteStore.shared.triggerReview(mode: "due", source: "home")
                    } label: {
                        Label("Practice this word", systemImage: "rectangle.stack.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .glassButtonStyleCompat()
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Quick actions

    private var quickActionsRow: some View {
        SMCard(padding: 12) {
            HStack(spacing: 8) {
                QuickActionButton(icon: AppTab.translate.icon, titleKey: "Translate") {
                    selectedTab = .translate
                }
                QuickActionButton(icon: AppTab.photo.icon, titleKey: "Scan", tint: .indigo) {
                    AppRouteStore.shared.trigger(.openCameraScanner, preferredTab: .photo)
                }
                QuickActionButton(icon: AppTab.study.icon, titleKey: "Study", tint: .purple) {
                    #if os(iOS)
                    selectedTab = .study
                    #else
                    selectedTab = .learn
                    #endif
                }
                QuickActionButton(icon: AppTab.stats.icon, titleKey: "Stats", tint: .teal) {
                    // Deep-link straight to Statistics (inside the Study hub on
                    // iOS, its own sidebar item on macOS) rather than dropping
                    // the user on the hub's root menu.
                    AppRouteStore.shared.openStudy(route: "stats")
                }
            }
        }
    }

    // MARK: - This week

    /// The seven days of the user's current calendar week (respects the
    /// user's first-weekday setting via `dateInterval(of: .weekOfYear)`).
    private var weekDays: [Date] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var weekSection: some View {
        let days = weekDays
        let maxScore = max(1, days.map { activityStore.activity(for: $0).activityScore }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            SMSectionHeader(titleKey: "This Week")
            SMCard {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        dayColumn(day, maxScore: maxScore)
                    }
                }
            }
            HStack(spacing: 12) {
                StatTile(
                    icon: "character.book.closed",
                    iconColor: .blue,
                    value: "\(savedTermsStore.terms.count)",
                    labelKey: "Words saved"
                )
                StatTile(
                    icon: "checkmark.circle",
                    iconColor: .green,
                    value: "\(reviewsToday)",
                    labelKey: "Reviews today"
                )
            }
        }
        // Re-key on day rollover so "today" highlighting always tracks the
        // actual calendar day, even when the app stays open past midnight.
        .id(activityStore.dayChangeToken)
    }

    private func dayColumn(_ date: Date, maxScore: Int) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let score = activityStore.activity(for: date).activityScore
        let fraction = Double(score) / Double(maxScore)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 8, height: 36)
                if score > 0 {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: max(6, 36 * fraction))
                }
            }
            Text(date, format: .dateTime.weekday(.narrow))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(date, format: .dateTime.month(.wide).day()): \(score) activities"))
    }

    // MARK: - Recent saves

    /// The six most recently saved terms, newest first.
    private var recentTerms: [SavedTerm] {
        Array(savedTermsStore.terms.sorted { $0.dateAdded > $1.dateAdded }.prefix(6))
    }

    private var recentSavesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SMSectionHeader(titleKey: "Recent Saves", actionKey: "See All") {
                // Deep-link to the Vocabulary list itself, not the Study hub root.
                AppRouteStore.shared.openStudy(route: "vocabulary")
            }
            if recentTerms.isEmpty {
                SMCard {
                    Text("Words you save will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentTerms) { term in
                            termChip(term)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func termChip(_ term: SavedTerm) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(term.headlineText)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
            if !term.glossText.isEmpty {
                Text(term.glossText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .smCardSurface(cornerRadius: 12)
    }
}

// MARK: - Goal picker sheet

/// Compact picker for the daily review goal (persisted as "dailyGoal").
private struct GoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyGoal") private var dailyGoalSetting = 20

    private let options = [10, 20, 30, 50]

    private var effectiveGoal: Int {
        dailyGoalSetting <= 0 ? 20 : dailyGoalSetting
    }

    var body: some View {
        NavigationStack {
            List(options, id: \.self) { option in
                Button {
                    dailyGoalSetting = option
                    dismiss()
                } label: {
                    HStack {
                        Text("\(option) reviews")
                            .foregroundStyle(.primary)
                        Spacer()
                        if effectiveGoal == option {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Daily Goal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 300, minHeight: 280)
        #endif
    }
}

// MARK: - Preview

#Preview {
    HomeView(selectedTab: .constant(.home))
        .environment(SavedTermsStore.shared)
        .environment(LearningProgressStore.shared)
        .environment(LearningActivityStore.shared)
        .environment(AppRouteStore.shared)
}
