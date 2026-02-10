//
//  SwiftMandarinApp.swift
//  SwiftMandarin
//
//  Created by Roger Lin on 2/11/26.
//

import SwiftUI

@main
struct SwiftMandarinApp: App {
    // Shared stores for app-wide state using @Observable
    @State private var savedTermsStore = SavedTermsStore.shared
    @State private var historyStore = TranslationHistoryStore.shared
    @State private var learningStore = LearningProgressStore.shared
    @State private var activityStore = LearningActivityStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
        }
        
        #if os(macOS)
        Settings {
            MacOSSettingsView()
                .environment(savedTermsStore)
                .environment(historyStore)
                .environment(learningStore)
                .environment(activityStore)
        }
        #endif
    }
}
