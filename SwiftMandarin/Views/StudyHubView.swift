//
//  StudyHubView.swift
//  SwiftMandarin
//
//  The Study tab (iOS): one hub for every learning surface — flashcard
//  review, practice drills, AI conversation, the reader, and the library
//  (vocabulary, phrases, history, stats). On macOS these destinations are
//  sidebar items instead, so this hub is iOS-only in practice, but it
//  compiles everywhere for safety.
//

import SwiftUI

/// Push destinations inside the Study hub. Raw values match the strings used
/// by `AppRouteStore.openStudy(route:)` so Home deep-links resolve here.
enum StudyRoute: String, Hashable {
    case learn
    case practice
    case conversation
    case reader
    case vocabulary
    case phrases
    case history
    case stats
}

struct StudyHubView: View {
    @Binding var selectedTab: AppTab
    @Environment(AppRouteStore.self) private var routeStore
    @Environment(SavedTermsStore.self) private var savedTermsStore
    @Environment(LearningProgressStore.self) private var progressStore
    @State private var path: [StudyRoute] = []
    @State private var localization = LocalizationManager.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    reviewHero
                    practiceSection
                    librarySection
                }
                .padding()
            }
            .background(SMTheme.pageBackground)
            .navigationTitle("Study")
            .navigationDestination(for: StudyRoute.self) { route in
                switch route {
                case .learn: LearnView()
                case .practice: PracticeHubView()
                case .conversation: ConversationView()
                case .reader: ReaderView()
                case .vocabulary: VocabularyView()
                case .phrases: PhrasesView()
                case .history: HistoryTabView(selectedTab: $selectedTab)
                case .stats: StatsView()
                }
            }
        }
        // A Siri/Home "start review" action, or a Home deep-link into a
        // specific library screen, routes to this tab on iOS; push the matching
        // destination so the pending action is consumed exactly as it would be
        // if these were top-level tabs.
        .onChange(of: routeStore.pendingAction?.id, initial: true) { _, _ in
            switch routeStore.pendingAction?.kind {
            case .startReview:
                if path.last != .learn { path.append(.learn) }
            case .openStudyRoute(let raw):
                if let route = StudyRoute(rawValue: raw), path.last != route {
                    path.append(route)
                }
                // This hub is the terminal consumer of a study-route deep link
                // (unlike startReview, which LearnView clears), so clear it here.
                routeStore.clearPendingAction()
            default:
                break
            }
        }
    }

    // MARK: - Review hero

    /// Everything the SRS can review today: the built-in starter deck plus
    /// every saved vocabulary term.
    private var allCards: [LearningCard] {
        LearningDeck.cards + savedTermsStore.terms.map { LearningCard(from: $0) }
    }

    private var dueCount: Int {
        progressStore.pendingReviewCount(from: allCards)
    }

    private var reviewHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HeroActionRow(
                icon: AppTab.learn.icon,
                tint: .accentColor,
                titleKey: "Review",
                subtitleKey: dueCount > 0 ? "Cards are waiting for you" : "All caught up — great work",
                badge: dueCount > 0 ? "\(dueCount)" : nil
            ) {
                path.append(.learn)
            }
        }
    }

    // MARK: - Practice & immersion

    /// Tone drills are Mandarin-only and `PracticeHubView` hides that card for
    /// a Mandarin speaker, so the summary must not promise a drill that will
    /// not be there. Typed explicitly rather than written inline: a literal
    /// inside a ternary is ambiguous between the localizing and verbatim
    /// initializers, and Xcode's extractor does not reliably catalog it.
    private var practiceSubtitle: LocalizedStringKey {
        localization.learningIsChinese
            ? "Quizzes, dictation, and tone drills"
            : "Quizzes and dictation"
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SMSectionHeader(titleKey: "Practice & Immersion")
            HeroActionRow(
                icon: AppTab.practice.icon,
                tint: .purple,
                titleKey: "Practice",
                subtitleKey: practiceSubtitle
            ) {
                path.append(.practice)
            }
            HeroActionRow(
                icon: AppTab.conversation.icon,
                tint: .teal,
                titleKey: "Conversation",
                subtitleKey: "Roleplay real dialogues with an AI partner"
            ) {
                path.append(.conversation)
            }
            HeroActionRow(
                icon: AppTab.reader.icon,
                tint: .indigo,
                titleKey: "Reader",
                subtitleKey: "Read stories and articles at your level"
            ) {
                path.append(.reader)
            }
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SMSectionHeader(titleKey: "Library")
            SMCard(padding: 6) {
                VStack(spacing: 0) {
                    libraryRow(.vocabulary, route: .vocabulary)
                    Divider().padding(.leading, 46)
                    libraryRow(.phrases, route: .phrases)
                    Divider().padding(.leading, 46)
                    libraryRow(.history, route: .history)
                    Divider().padding(.leading, 46)
                    libraryRow(.stats, route: .stats)
                }
            }
        }
    }

    private func libraryRow(_ tab: AppTab, route: StudyRoute) -> some View {
        Button {
            path.append(route)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.body)
                    .frame(width: 30)
                    .foregroundStyle(Color.accentColor)
                Text(tab.titleKey)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
