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
    case translate
    case photo
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
        case .translate: return "Translate"
        case .photo: return "Photo"
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
        case .translate: return "character.bubble"
        case .photo: return "camera.viewfinder"
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
        TabView(selection: $selectedTab) {
            Tab(AppTab.translate.titleKey, systemImage: AppTab.translate.icon, value: .translate) {
                TranslateView()
            }

            Tab(AppTab.photo.titleKey, systemImage: AppTab.photo.icon, value: .photo) {
                PhotoTranslateView()
            }

            Tab(AppTab.history.titleKey, systemImage: AppTab.history.icon, value: .history) {
                HistoryTabView(selectedTab: $selectedTab)
            }

            Tab(AppTab.vocabulary.titleKey, systemImage: AppTab.vocabulary.icon, value: .vocabulary) {
                VocabularyView()
            }

            Tab(AppTab.learn.titleKey, systemImage: AppTab.learn.icon, value: .learn) {
                LearnView()
            }

            Tab(AppTab.phrases.titleKey, systemImage: AppTab.phrases.icon, value: .phrases) {
                PhrasesView()
            }

            Tab(AppTab.stats.titleKey, systemImage: AppTab.stats.icon, value: .stats) {
                StatsView()
            }

            Tab(AppTab.more.titleKey, systemImage: AppTab.more.icon, value: .more) {
                MoreView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

// MARK: - macOS Navigation

#if os(macOS)
struct MacOSContentView: View {
    @Binding var selectedTab: AppTab
    
    /// Filter out "More" tab on macOS since Settings is in menu bar
    private var macOSTabs: [AppTab] {
        AppTab.allCases.filter { $0 != .more }
    }
    
    var body: some View {
        NavigationSplitView {
            List(macOSTabs, selection: $selectedTab) { tab in
                Label(tab.titleKey, systemImage: tab.icon)
                    .tag(tab)
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
        case .translate:
            TranslateView()
        case .photo:
            PhotoTranslateView()
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
