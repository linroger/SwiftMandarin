//
//  SwiftMandarinApp.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI
import AppIntents

@main
struct SwiftMandarinApp: App {
    // Shared stores for app-wide state using @Observable
    @State private var savedTermsStore = SavedTermsStore.shared
    @State private var historyStore = TranslationHistoryStore.shared
    @State private var learningStore = LearningProgressStore.shared
    @State private var activityStore = LearningActivityStore.shared
    @State private var routeStore = AppRouteStore.shared
    // Drives the in-app English ⇄ 中文 language switch. Accessing the singleton
    // here also applies the saved language to Bundle.main before the first view.
    @State private var localization = LocalizationManager.shared

    #if os(macOS)
    // Menu-bar quick translate. The Settings toggle writes this key; binding it
    // through `isInserted` adds/removes the status item live.
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    #endif

    init() {
        // Ensures app shortcuts are registered and entity-backed parameters are refreshed.
        SwiftMandarinShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
                .environment(routeStore)
                // Switch UI language live: format with the chosen locale and
                // rebuild the tree so every localized string re-resolves.
                .environment(\.locale, localization.locale)
                .id(localization.language)
        }

        #if os(macOS)
        Settings {
            MacOSSettingsView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
                .environment(routeStore)
                .environment(\.locale, localization.locale)
                .id(localization.language)
        }

        // Quick translate from the menu bar — always available, even when the
        // main window is closed. Window style so the panel keeps focus while
        // the user types.
        MenuBarExtra(isInserted: $showInMenuBar) {
            MenuBarTranslateView()
                .environment(\.locale, localization.locale)
                .id(localization.language)
        } label: {
            Image(systemName: "character.bubble")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
