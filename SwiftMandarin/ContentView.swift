//
//  ContentView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import AppIntents

/// Main navigation container using TabView with sidebarAdaptable style
/// - iOS: Bottom tab bar (5 tabs)
/// - iPadOS: Floating tab bar that morphs to sidebar
/// - macOS: NavigationSplitView with sidebar
struct ContentView: View {
    @Environment(AppRouteStore.self) private var routeStore
    @Environment(\.scenePhase) private var scenePhase
    
    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { routeStore.selectedTab },
            set: { routeStore.selectedTab = $0 }
        )
    }
    
    var body: some View {
        contentView
            .onAppear {
                SwiftMandarinShortcutsProvider.updateAppShortcutParameters()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    SwiftMandarinShortcutsProvider.updateAppShortcutParameters()
                }
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        #if os(macOS)
        MacOSContentView(selectedTab: selectedTabBinding)
        #else
        iOSContentView(selectedTab: selectedTabBinding)
        #endif
    }
}

// MARK: - App Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case translate
    case photo
    case reader
    case study
    case practice
    case conversation
    case history
    case vocabulary
    case learn
    case phrases
    case stats
    case more

    var id: String { rawValue }

    /// Localized tab title. Using a `LocalizedStringKey` literal (rather than a
    /// plain `String`) means SwiftUI resolves it through the active language
    /// bundle, so tab labels switch with the in-app language toggle.
    var titleKey: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .translate: return "Translate"
        case .photo: return "Photo"
        case .reader: return "Reader"
        case .study: return "Study"
        case .practice: return "Practice"
        case .conversation: return "Conversation"
        case .history: return "History"
        case .vocabulary: return "Vocabulary"
        case .learn: return "Learn"
        case .phrases: return "Phrases"
        case .stats: return "Stats"
        case .more: return "More"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .translate: return "character.bubble"
        case .photo: return "camera.viewfinder"
        case .reader: return "book.pages"
        case .study: return "graduationcap.fill"
        case .practice: return "checklist"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .history: return "clock"
        case .vocabulary: return "text.book.closed"
        case .learn: return "brain.head.profile"
        case .phrases: return "quote.bubble"
        case .stats: return "chart.bar.fill"
        case .more: return "ellipsis.circle"
        }
    }
}

// MARK: - iOS/iPadOS Navigation

struct iOSContentView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
        }
    }

    /// iOS 18+: `Tab` builder with the sidebar-adaptable style (floating tab
    /// bar that morphs into a sidebar on iPad).
    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.titleKey, systemImage: AppTab.home.icon, value: .home) {
                HomeView(selectedTab: $selectedTab)
            }

            Tab(AppTab.translate.titleKey, systemImage: AppTab.translate.icon, value: .translate) {
                TranslateView()
            }

            Tab(AppTab.photo.titleKey, systemImage: AppTab.photo.icon, value: .photo) {
                PhotoTranslateView()
            }

            // Study is the hub for Learn / Practice / Conversation / Reader /
            // Vocabulary / Phrases / History / Stats — the tab bar stays at
            // five items so iOS never adds its own system "More".
            Tab(AppTab.study.titleKey, systemImage: AppTab.study.icon, value: .study) {
                StudyHubView(selectedTab: $selectedTab)
            }

            Tab(AppTab.more.titleKey, systemImage: AppTab.more.icon, value: .more) {
                MoreView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    /// iOS 17: classic tab bar (extra tabs collect under the system
    /// "More" item on iPhone).
    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label(AppTab.home.titleKey, systemImage: AppTab.home.icon) }
                .tag(AppTab.home)

            TranslateView()
                .tabItem { Label(AppTab.translate.titleKey, systemImage: AppTab.translate.icon) }
                .tag(AppTab.translate)

            PhotoTranslateView()
                .tabItem { Label(AppTab.photo.titleKey, systemImage: AppTab.photo.icon) }
                .tag(AppTab.photo)

            // Study is the hub for Learn / Practice / Conversation / Reader /
            // Vocabulary / Phrases / History / Stats (see modernTabView).
            StudyHubView(selectedTab: $selectedTab)
                .tabItem { Label(AppTab.study.titleKey, systemImage: AppTab.study.icon) }
                .tag(AppTab.study)

            MoreView()
                .tabItem { Label(AppTab.more.titleKey, systemImage: AppTab.more.icon) }
                .tag(AppTab.more)
        }
    }
}

// MARK: - macOS Navigation

#if os(macOS)
struct MacOSContentView: View {
    @Binding var selectedTab: AppTab

    /// Sidebar sections. `more` (iOS settings hub) and `study` (iOS hub for
    /// what the sidebar already lists directly) are intentionally absent.
    private static let toolTabs: [AppTab] = [.translate, .photo]
    private static let studyTabs: [AppTab] = [.learn, .practice, .conversation, .reader]
    private static let libraryTabs: [AppTab] = [.vocabulary, .phrases, .history, .stats]

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label(AppTab.home.titleKey, systemImage: AppTab.home.icon)
                    .tag(AppTab.home)

                Section("Translate") {
                    ForEach(Self.toolTabs) { tab in
                        Label(tab.titleKey, systemImage: tab.icon).tag(tab)
                    }
                }
                Section("Study") {
                    ForEach(Self.studyTabs) { tab in
                        Label(tab.titleKey, systemImage: tab.icon).tag(tab)
                    }
                }
                Section("Library") {
                    ForEach(Self.libraryTabs) { tab in
                        Label(tab.titleKey, systemImage: tab.icon).tag(tab)
                    }
                }
            }
            .navigationTitle("SwiftMandarin")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailView
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        // Use SettingsLink for proper macOS Settings integration
                        SettingsLink {
                            Image(systemName: "gear")
                        }
                        .help("Settings (⌘,)")
                    }
                }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .home:
            HomeView(selectedTab: $selectedTab)
        case .translate:
            TranslateView()
        case .photo:
            PhotoTranslateView()
        case .reader:
            ReaderView()
        case .study:
            // Not in the sidebar; routing fallback lands on Home.
            HomeView(selectedTab: $selectedTab)
        case .practice:
            PracticeHubView()
        case .conversation:
            ConversationView()
        case .history:
            HistoryTabView(selectedTab: $selectedTab)
        case .vocabulary:
            VocabularyView()
        case .learn:
            LearnView()
        case .phrases:
            PhrasesView()
        case .stats:
            StatsView()
        case .more:
            // This shouldn't be reachable on macOS, but provide fallback
            Text("Use ⌘, or the gear button to open Settings")
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SavedTermsStore.shared)
        .environment(TranslationHistoryStore.shared)
        .environment(LearningProgressStore.shared)
        .environment(LearningActivityStore.shared)
        .environment(AppRouteStore.shared)
}
