//
//  ContentView.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI

/// Main navigation container using TabView with sidebarAdaptable style
/// - iOS: Bottom tab bar (5 tabs)
/// - iPadOS: Floating tab bar that morphs to sidebar
/// - macOS: NavigationSplitView with sidebar
struct ContentView: View {
    @State private var selectedTab: AppTab = .translate
    
    var body: some View {
        #if os(macOS)
        MacOSContentView(selectedTab: $selectedTab)
        #else
        iOSContentView(selectedTab: $selectedTab)
        #endif
    }
}

// MARK: - App Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case translate
    case history
    case vocabulary
    case learn
    case phrases
    case more
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .translate: return "Translate"
        case .history: return "History"
        case .vocabulary: return "Vocabulary"
        case .learn: return "Learn"
        case .phrases: return "Phrases"
        case .more: return "More"
        }
    }
    
    var icon: String {
        switch self {
        case .translate: return "character.bubble"
        case .history: return "clock"
        case .vocabulary: return "text.book.closed"
        case .learn: return "brain.head.profile"
        case .phrases: return "quote.bubble"
        case .more: return "ellipsis.circle"
        }
    }
}

// MARK: - iOS/iPadOS Navigation

struct iOSContentView: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.translate.title, systemImage: AppTab.translate.icon, value: .translate) {
                TranslateView()
            }
            
            Tab(AppTab.history.title, systemImage: AppTab.history.icon, value: .history) {
                HistoryTabView(selectedTab: $selectedTab)
            }
            
            Tab(AppTab.vocabulary.title, systemImage: AppTab.vocabulary.icon, value: .vocabulary) {
                VocabularyView()
            }
            
            Tab(AppTab.learn.title, systemImage: AppTab.learn.icon, value: .learn) {
                LearnView()
            }
            
            Tab(AppTab.phrases.title, systemImage: AppTab.phrases.icon, value: .phrases) {
                PhrasesView()
            }
            
            Tab(AppTab.more.title, systemImage: AppTab.more.icon, value: .more) {
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
                Label(tab.title, systemImage: tab.icon)
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
        case .history:
            HistoryTabView(selectedTab: $selectedTab)
        case .vocabulary:
            VocabularyView()
        case .learn:
            LearnView()
        case .phrases:
            PhrasesView()
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
}
