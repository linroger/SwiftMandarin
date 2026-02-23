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
        }
        
        #if os(macOS)
        Settings {
            MacOSSettingsView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
                .environment(routeStore)
        }
        #endif
    }
}
